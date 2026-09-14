# Google Assistant Voice-to-Transaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user speak a purchase ("spent 200 on coffee at Third Wave") and have it saved as a real transaction — via an in-app mic button today, and via a Google Assistant / Android App Shortcut voice trigger that opens the app straight into listening mode.

**Architecture:** Wire the existing but 100%-fake `VoiceInputForm` widget to a real speech-to-text capture service and a two-tier parser (regex first, on-device Gemma fallback), reusing the app's existing category-resolution and `TransactionProvider.addTransaction` save path. Layer an Android App Shortcut + custom-scheme deep link on top so Assistant can launch straight into that same form with listening auto-started.

**Tech Stack:** Flutter/Dart, `speech_to_text` (new), `app_links` (new), existing `permission_handler`, `provider`, on-device Gemma via `AiService`/`flutter_gemma` (existing).

**Spec:** `docs/superpowers/specs/2026-09-13-google-assistant-voice-transaction-design.md`

## Global Constraints

- Android only — no iOS work in this plan (Google Assistant App Actions/Shortcuts have no iOS equivalent).
- No backend/Cloud Functions — every write goes through the existing client-side `TransactionProvider.addTransaction` (local Hive `StorageService` + Firestore mirror via `CloudDataService`), same as manual entry.
- AI (Gemma) involvement is enhancement-only, gated behind `AiProvider.isReady` (`state == AiModelState.ready && _isPro` — already bundles the Pro-subscription check). Never block a save on AI availability.
- New transaction `id` uses the existing convention: `DateTime.now().millisecondsSinceEpoch.toString()`.
- New dependencies: `speech_to_text: ^7.4.0`, `app_links: ^7.0.0` (both dry-run-resolved against this repo's existing constraints — confirmed compatible).
- v1 is expense-only (voice-logged purchases are always `TransactionType.expense`); date is always `DateTime.now()` (no backdating via voice).
- Git stays read-only for the assistant executing this plan unless the human running it says otherwise — write the commits into the plan as instructed steps, but do not run `git commit`/`git add` yourself if your own configuration forbids mutating git state. Flag this instead of silently skipping.

---

### Task 1: Add `speech_to_text` and `app_links` dependencies

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `speech_to_text` package (class `SpeechToText`, used by Task 4) and `app_links` package (class `AppLinks`, used by Task 7) available to the project.

- [ ] **Step 1: Add the dependencies**

In `pubspec.yaml`, under the existing `# Auth & Cloud` block (after `in_app_review: ^2.0.9`), add:

```yaml
  # Voice-to-transaction entry
  speech_to_text: ^7.4.0
  app_links: ^7.0.0
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: completes with no version-resolution errors (already dry-run-verified compatible with this repo's exact lockfile).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add speech_to_text and app_links dependencies"
```

---

### Task 2: `PurchaseTranscriptParser` — regex extraction

**Files:**
- Create: `lib/services/purchase_transcript_parser.dart`
- Test: `test/services/purchase_transcript_parser_test.dart`

**Interfaces:**
- Produces: `class ParsedPurchase { final double amount; final String? merchant; }` and `class PurchaseTranscriptParser { static ParsedPurchase? parse(String transcript); }` — consumed by Task 5 (`VoiceInputForm`).

- [ ] **Step 1: Write the failing tests**

Create `test/services/purchase_transcript_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/services/purchase_transcript_parser.dart';

void main() {
  group('PurchaseTranscriptParser', () {
    test('parses "spent <amount> at <merchant>"', () {
      final r = PurchaseTranscriptParser.parse('spent 450 at Swiggy');
      expect(r, isNotNull);
      expect(r!.amount, 450.0);
      expect(r.merchant, 'Swiggy');
    });

    test('parses "paid <amount> on <merchant>" (no "at")', () {
      final r = PurchaseTranscriptParser.parse('paid 1240 on groceries');
      expect(r, isNotNull);
      expect(r!.amount, 1240.0);
      expect(r.merchant, 'groceries');
    });

    test('prefers "at" merchant over an earlier "on" in the same transcript', () {
      final r = PurchaseTranscriptParser.parse('spent 200 on coffee at Third Wave');
      expect(r, isNotNull);
      expect(r!.amount, 200.0);
      expect(r.merchant, 'Third Wave');
    });

    test('handles ₹ symbol and comma-formatted amount', () {
      final r = PurchaseTranscriptParser.parse('spent ₹1,240 at D-Mart');
      expect(r, isNotNull);
      expect(r!.amount, 1240.0);
      expect(r.merchant, 'D-Mart');
    });

    test('amount with no merchant marker returns null merchant, not null result', () {
      final r = PurchaseTranscriptParser.parse('I spent 90 today');
      expect(r, isNotNull);
      expect(r!.amount, 90.0);
      expect(r.merchant, isNull);
    });

    test('no amount at all returns null', () {
      final r = PurchaseTranscriptParser.parse('bought coffee at Third Wave');
      expect(r, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/purchase_transcript_parser_test.dart`
Expected: FAIL — `package:wllt/services/purchase_transcript_parser.dart` doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/services/purchase_transcript_parser.dart`:

```dart
class ParsedPurchase {
  final double amount;
  final String? merchant;

  const ParsedPurchase({required this.amount, this.merchant});
}

/// Regex-only extraction of a spoken purchase ("spent 200 on coffee at Third
/// Wave") into amount + merchant. No amount match means no confident parse —
/// callers fall back to [PurchaseTranscriptAdapter] (Gemma) or surface an
/// error. Assumes the speech-to-text engine already normalizes spoken
/// numbers to digits (true for both Android's on-device and cloud
/// recognizers) — no word-to-number parsing here.
class PurchaseTranscriptParser {
  static final _amountPattern = RegExp(
    r'(?:spent|paid|cost)\s+(?:rs\.?|inr|rupees|₹)?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  // Tried in this order — "at" is the most specific merchant marker in
  // natural speech ("spent 200 on coffee at Third Wave" — the merchant is
  // "Third Wave", not "coffee"), so it wins when both are present.
  static final _atMerchant =
      RegExp(r"\bat\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,40})$", caseSensitive: false);
  static final _onMerchant =
      RegExp(r"\bon\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,40})$", caseSensitive: false);
  static final _forMerchant =
      RegExp(r"\bfor\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,40})$", caseSensitive: false);

  static ParsedPurchase? parse(String transcript) {
    final amountMatch = _amountPattern.firstMatch(transcript);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) return null;

    final merchant = _atMerchant.firstMatch(transcript)?.group(1) ??
        _onMerchant.firstMatch(transcript)?.group(1) ??
        _forMerchant.firstMatch(transcript)?.group(1);

    return ParsedPurchase(amount: amount, merchant: merchant?.trim());
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/purchase_transcript_parser_test.dart`
Expected: PASS (6/6).

- [ ] **Step 5: Commit**

```bash
git add lib/services/purchase_transcript_parser.dart test/services/purchase_transcript_parser_test.dart
git commit -m "feat: add regex parser for spoken purchase transcripts"
```

---

### Task 3: `PurchaseTranscriptAdapter` — Gemma fallback

**Files:**
- Create: `lib/ai/purchase_transcript_adapter.dart`
- Test: `test/ai/purchase_transcript_adapter_test.dart`

**Interfaces:**
- Consumes: `typedef InferFn = Future<String> Function(String prompt)` from `lib/ai/categorization_adapter.dart` (existing).
- Produces: `class PurchaseParseResult { final String? merchant; final double amount; }` and `class PurchaseTranscriptAdapter { static Future<PurchaseParseResult?> parse({required String transcript, required InferFn infer}); }` — consumed by Task 5.

- [ ] **Step 1: Write the failing tests**

Create `test/ai/purchase_transcript_adapter_test.dart` (mirrors `test/ai/sms_parser_adapter_test.dart`'s existing style):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/purchase_transcript_adapter.dart';

void main() {
  Future<String> goodInfer(String p) async =>
      '{"merchant":"Third Wave","amount":200.0}';
  Future<String> noMerchantInfer(String p) async =>
      '{"merchant":null,"amount":90.0}';
  Future<String> badJsonInfer(String p) async => 'not valid json';
  Future<String> negativeAmountInfer(String p) async =>
      '{"merchant":"X","amount":-10.0}';
  Future<String> nullAmountInfer(String p) async =>
      '{"merchant":"X","amount":null}';
  Future<String> throwInfer(String p) async => throw Exception('fail');

  const transcript = 'spent two hundred on coffee at third wave';

  test('parses a valid transcript', () async {
    final result =
        await PurchaseTranscriptAdapter.parse(transcript: transcript, infer: goodInfer);
    expect(result, isNotNull);
    expect(result!.merchant, equals('Third Wave'));
    expect(result.amount, equals(200.0));
  });

  test('handles a null merchant', () async {
    final result = await PurchaseTranscriptAdapter.parse(
        transcript: transcript, infer: noMerchantInfer);
    expect(result, isNotNull);
    expect(result!.merchant, isNull);
    expect(result.amount, equals(90.0));
  });

  test('returns null on invalid JSON', () async {
    final result =
        await PurchaseTranscriptAdapter.parse(transcript: transcript, infer: badJsonInfer);
    expect(result, isNull);
  });

  test('returns null on negative amount', () async {
    final result = await PurchaseTranscriptAdapter.parse(
        transcript: transcript, infer: negativeAmountInfer);
    expect(result, isNull);
  });

  test('returns null on null amount', () async {
    final result = await PurchaseTranscriptAdapter.parse(
        transcript: transcript, infer: nullAmountInfer);
    expect(result, isNull);
  });

  test('returns null when infer throws', () async {
    final result =
        await PurchaseTranscriptAdapter.parse(transcript: transcript, infer: throwInfer);
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ai/purchase_transcript_adapter_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/ai/purchase_transcript_adapter.dart`:

```dart
import 'dart:convert';
import 'categorization_adapter.dart' show InferFn;

class PurchaseParseResult {
  final String? merchant;
  final double amount;

  const PurchaseParseResult({required this.merchant, required this.amount});
}

/// Gemma JSON-extraction fallback for [PurchaseTranscriptParser] misses,
/// modeled directly on [SmsParserAdapter] (lib/ai/sms_parser_adapter.dart) —
/// same prompt shape, same defensive parsing.
class PurchaseTranscriptAdapter {
  PurchaseTranscriptAdapter._();

  static Future<PurchaseParseResult?> parse({
    required String transcript,
    required InferFn infer,
  }) async {
    final prompt = '<start_of_turn>user\n'
        'Extract a purchase from this spoken transcript as JSON.\n'
        'Transcript: "$transcript"\n'
        'Reply with only: {"merchant":"...","amount":0.0}\n'
        'Unknown fields use null.\n'
        '<end_of_turn>\n'
        '<start_of_turn>model\n';

    try {
      final raw = await infer(prompt);
      final json = jsonDecode(raw.trim()) as Map<String, dynamic>;
      final amountRaw = json['amount'];
      if (amountRaw == null) return null;
      final amount = (amountRaw as num).toDouble();
      if (amount <= 0) return null;
      return PurchaseParseResult(
        merchant: json['merchant'] as String?,
        amount: amount,
      );
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ai/purchase_transcript_adapter_test.dart`
Expected: PASS (6/6).

- [ ] **Step 5: Commit**

```bash
git add lib/ai/purchase_transcript_adapter.dart test/ai/purchase_transcript_adapter_test.dart
git commit -m "feat: add Gemma fallback adapter for purchase transcript parsing"
```

---

### Task 4: `VoiceCaptureService` — speech-to-text wrapper

**Files:**
- Create: `lib/services/voice_capture_service.dart`

**Interfaces:**
- Consumes: `SpeechToText` (package `speech_to_text`), `Permission.microphone` (package `permission_handler`, already a project dependency).
- Produces: `enum VoiceCaptureError { permissionDenied, notAvailable, noMatch }` and `class VoiceCaptureService { VoiceCaptureService({SpeechToText? speech}); Future<bool> start({required void Function(String transcript) onFinalResult, required void Function(VoiceCaptureError error) onError}); void stop(); }` — consumed by Task 5.

No automated test for this file — see note in Step 2. This mirrors existing convention: `Permission.sms.status`/`.request()` calls in `layout_screen.dart` and `settings_screen.dart` are likewise untested (mocking a `permission_handler` platform call would require introducing a DI abstraction nothing else in this codebase has, purely for test coverage).

- [ ] **Step 1: Implement**

Create `lib/services/voice_capture_service.dart`:

```dart
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceCaptureError { permissionDenied, notAvailable, noMatch }

/// Thin wrapper around `speech_to_text`: requests mic permission, starts a
/// single-utterance listen, and reports the final transcript or a typed
/// error. [speech] is constructor-injectable for the same reason other
/// services in this codebase take their platform dependency in the
/// constructor, even though no test exercises it today (see Task 4 note).
class VoiceCaptureService {
  final SpeechToText _speech;

  VoiceCaptureService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  Future<bool> start({
    required void Function(String transcript) onFinalResult,
    required void Function(VoiceCaptureError error) onError,
  }) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      onError(VoiceCaptureError.permissionDenied);
      return false;
    }

    final available = await _speech.initialize(
      onError: (_) => onError(VoiceCaptureError.notAvailable),
    );
    if (!available) {
      onError(VoiceCaptureError.notAvailable);
      return false;
    }

    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) {
          onError(VoiceCaptureError.noMatch);
        } else {
          onFinalResult(words);
        }
      },
    );
    return true;
  }

  void stop() => _speech.stop();
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/voice_capture_service.dart`
Expected: no errors. (Real listening behavior is real-device-only — see spec's Testing section; not claimed as tested here.)

- [ ] **Step 3: Commit**

```bash
git add lib/services/voice_capture_service.dart
git commit -m "feat: add VoiceCaptureService wrapping speech_to_text"
```

---

### Task 5: Wire `VoiceInputForm` for real + add mic entry point

**Files:**
- Modify: `lib/widgets/add_expense_sheet.dart`
  - `AddTransactionPage` / `_AddTransactionPageState` (lines 27-241)
  - `VoiceInputForm` / `_VoiceInputFormState` (lines 1535-1754)

**Interfaces:**
- Consumes: `PurchaseTranscriptParser.parse` (Task 2), `PurchaseTranscriptAdapter.parse` (Task 3), `VoiceCaptureService`/`VoiceCaptureError` (Task 4), `SmsRulesEngine.categorize(String? merchant)` (existing, `lib/services/sms_rules_engine.dart`), `CategorizationAdapter.suggest({required merchant, required availableCategories, required infer})` (existing, `lib/ai/categorization_adapter.dart`), `AiProvider.isReady` (existing, `lib/providers/ai_provider.dart`), `AccountProvider.accounts` (existing), `TransactionProvider.addTransaction`/`.deleteTransaction` (existing, `lib/providers/transaction_provider.dart`).
- Produces: `AddTransactionPage(method: ..., editTransaction: ..., startInVoiceMode: bool = false)` — the `startInVoiceMode` param is consumed by Task 7's deep-link handler.

This is the biggest task in the plan — it's one deliverable (a working, savable voice tab) even though it touches many lines, because none of the pieces are independently testable/shippable (a wired capture service with no save path, or a save path with no real transcript, are both useless in isolation).

- [ ] **Step 1: Add `startInVoiceMode` to `AddTransactionPage` and a header mic button**

In `lib/widgets/add_expense_sheet.dart`, modify the `AddTransactionPage` widget (around line 27):

```dart
class AddTransactionPage extends StatefulWidget {
  final AddTransactionMethod method;
  final Transaction? editTransaction;
  final bool startInVoiceMode;

  const AddTransactionPage({
    super.key,
    required this.method,
    this.editTransaction,
    this.startInVoiceMode = false,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}
```

In `_AddTransactionPageState` (around line 41), add voice-mode state:

```dart
class _AddTransactionPageState extends State<AddTransactionPage> {
  static const _methods = [
    AddTransactionMethod.expense,
    AddTransactionMethod.income,
    AddTransactionMethod.transfer,
  ];
  static const _labels = ['Expense', 'Income', 'Transfer'];

  late AddTransactionMethod _method;
  late final PageController _methodController;
  bool _isScrollerPressed = false;
  late bool _voiceMode;
```

In `initState` (around line 53), initialize it:

```dart
  @override
  void initState() {
    super.initState();
    _voiceMode = widget.startInVoiceMode;
    final tx = widget.editTransaction;
```

(the rest of `initState` is unchanged — keep the existing `_method`/`_methodController` assignment below this line).

In `build()` (around line 90-104, the header `Row` that currently shows the method scroller on the left and delete/close on the right), replace the left-hand `Row` content so it shows either the method scroller (normal) or a "Voice" label + back arrow (voice mode), and add a mic button to the right-hand `Row` when not editing and not already in voice mode:

```dart
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: _voiceMode
                        ? [
                            IconButton(
                              onPressed: () => setState(() => _voiceMode = false),
                              icon: Icon(LucideIcons.chevronLeft, color: cs.onSurface),
                              padding: EdgeInsets.zero,
                            ),
                            Text(
                              'Voice entry',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]
                        : [
                            Text(
                              isEdit ? 'Edit ' : 'Add ',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            _buildMethodScroller(context),
                          ],
                  ),
                  Row(
                    children: [
                      if (!isEdit && !_voiceMode) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => setState(() => _voiceMode = true),
                            icon: Icon(LucideIcons.mic, size: 13, color: cs.onSecondaryContainer),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isEdit) ...[
```

(the existing delete-button block already starts with `if (isEdit) ...[` — leave it and the close button below it exactly as-is, just insert the new mic block immediately before it, inside the same outer `Row`).

Finally, in `_buildFormContent()` (around line 223), check voice mode first:

```dart
  Widget _buildFormContent() {
    if (_voiceMode) {
      return VoiceInputForm(autoStart: widget.startInVoiceMode);
    }
    switch (_method) {
      case AddTransactionMethod.expense:
        return ManualEntryForm(
          key: const ValueKey('expense'),
          initialType: TransactionType.expense,
          editTransaction: widget.editTransaction,
        );
      case AddTransactionMethod.income:
        return ManualEntryForm(
          key: const ValueKey('income'),
          initialType: TransactionType.income,
          editTransaction: widget.editTransaction,
        );
      case AddTransactionMethod.transfer:
        return const TransferForm();
    }
  }
```

- [ ] **Step 2: Rewrite `VoiceInputForm` to do real capture, parsing, and saving**

Replace the entire `VoiceInputForm`/`_VoiceInputFormState`/`VoiceStage` block (lines 1535-1754 — everything from `class VoiceInputForm extends StatefulWidget` through the `enum VoiceStage { idle, listening, parsed }` line, but stopping before `class TransferForm`) with:

```dart
class VoiceInputForm extends StatefulWidget {
  final bool autoStart;

  const VoiceInputForm({super.key, this.autoStart = false});

  @override
  State<VoiceInputForm> createState() => _VoiceInputFormState();
}

class _VoiceInputFormState extends State<VoiceInputForm>
    with SingleTickerProviderStateMixin {
  VoiceStage _stage = VoiceStage.idle;
  String _transcribed = '';
  String _errorMessage = '';
  double? _amount;
  String? _merchant;
  String? _categoryId;
  late AnimationController _controller;
  final VoiceCaptureService _capture = VoiceCaptureService();
  Timer? _autoPopTimer;
  Transaction? _savedTx;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoPopTimer?.cancel();
    _capture.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [8, 16, 26, 12, 22, 10, 20, 14, 8, 24, 12, 18]
                  .asMap()
                  .entries
                  .map((entry) {
                    return Container(
                      width: 3,
                      height: _stage == VoiceStage.listening
                          ? entry.value.toDouble()
                          : 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.incomeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            switch (_stage) {
              VoiceStage.idle => 'Tap the mic to speak',
              VoiceStage.listening => 'Listening…',
              VoiceStage.parsed => "Got it! Here's what I heard:",
              VoiceStage.saved => 'Saved!',
              VoiceStage.error => _errorMessage,
            },
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (_transcribed.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _transcribed,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (_stage == VoiceStage.parsed || _stage == VoiceStage.saved) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildChip('₹${_amount?.toStringAsFixed(0) ?? '0'}',
                    const Color(0xFFe8f5e9), const Color(0xFF1a5c2a)),
                _buildChip(
                  _categoryId != null ? Category.getById(_categoryId!).name : 'Uncategorized',
                  const Color(0xFFfff3e0),
                  const Color(0xFF8a4a00),
                ),
                _buildChip('Today', const Color(0xFFe3f2fd), const Color(0xFF0d47a1)),
                if (_merchant != null)
                  _buildChip(_merchant!, const Color(0xFFf3e5f5), const Color(0xFF6a1b9a)),
              ],
            ),
          ],
          const Spacer(),
          if (_stage == VoiceStage.idle || _stage == VoiceStage.error)
            GestureDetector(
              onTap: _startListening,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.mic, size: 24, color: Colors.white),
              ),
            )
          else if (_stage == VoiceStage.listening)
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppTheme.expenseColor, shape: BoxShape.circle),
              child: const Icon(LucideIcons.mic, size: 24, color: Colors.white),
            )
          else if (_stage == VoiceStage.parsed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _retake,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Retake',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Confirm & Save', style: TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ),
              ],
            )
          else if (_stage == VoiceStage.saved)
            TextButton(
              onPressed: _undo,
              child: const Text('Undo'),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 12, color: textColor)),
    );
  }

  void _retake() {
    setState(() {
      _stage = VoiceStage.idle;
      _transcribed = '';
      _amount = null;
      _merchant = null;
      _categoryId = null;
    });
  }

  Future<void> _startListening() async {
    setState(() => _stage = VoiceStage.listening);
    await _capture.start(
      onFinalResult: _handleTranscript,
      onError: _handleCaptureError,
    );
  }

  void _handleCaptureError(VoiceCaptureError error) {
    if (!mounted) return;
    setState(() {
      _stage = VoiceStage.error;
      _errorMessage = switch (error) {
        VoiceCaptureError.permissionDenied => 'Microphone access needed — check app settings',
        VoiceCaptureError.notAvailable => "Couldn't make that out — try again",
        VoiceCaptureError.noMatch => "Didn't catch that — try again",
      };
    });
  }

  Future<void> _handleTranscript(String transcript) async {
    if (!mounted) return;
    setState(() => _transcribed = '"$transcript"');

    var parsed = PurchaseTranscriptParser.parse(transcript);
    if (parsed == null) {
      final aiProvider = context.read<AiProvider>();
      if (aiProvider.isReady) {
        final aiResult = await PurchaseTranscriptAdapter.parse(
          transcript: transcript,
          infer: (p) => AiService.instance.infer(p, temperature: 0.1, maxTokens: 60),
        );
        if (aiResult != null) {
          parsed = ParsedPurchase(amount: aiResult.amount, merchant: aiResult.merchant);
        }
      }
    }

    if (!mounted) return;
    if (parsed == null) {
      setState(() {
        _stage = VoiceStage.error;
        _errorMessage = "Couldn't make that out — try again";
      });
      return;
    }

    String? categoryId = SmsRulesEngine.categorize(parsed.merchant);
    if (categoryId == null && parsed.merchant != null) {
      final aiProvider = context.read<AiProvider>();
      if (aiProvider.isReady) {
        final prefs = context.read<UserPreferencesProvider>();
        final categoryIds = prefs.activeCategories.isNotEmpty
            ? prefs.activeCategories
            : Category.categories.map((c) => c.id).toList();
        categoryId = await CategorizationAdapter.suggest(
          merchant: parsed.merchant!,
          availableCategories: categoryIds,
          infer: (p) => AiService.instance.infer(p, temperature: 0.1, maxTokens: 10),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _amount = parsed.amount;
      _merchant = parsed.merchant;
      _categoryId = categoryId;
      _stage = VoiceStage.parsed;
    });

    if (widget.autoStart) {
      await _confirmAndSave();
    }
  }

  Transaction _buildTransaction() {
    final accounts = context.read<AccountProvider>().accounts;
    final account = accounts.isNotEmpty ? accounts.first : null;
    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transactionTitle: _merchant ?? 'Voice entry',
      categoryId: _categoryId ?? '',
      amount: _amount ?? 0,
      type: TransactionType.expense,
      date: DateTime.now(),
      account: account?.id ?? '',
      tags: const [],
      baseCurrency: account?.baseCurrency ?? 'USD',
    );
  }

  Future<void> _confirmAndSave() async {
    final tx = _buildTransaction();
    await context.read<TransactionProvider>().addTransaction(tx);
    if (!mounted) return;

    if (widget.autoStart) {
      setState(() {
        _savedTx = tx;
        _stage = VoiceStage.saved;
      });
      _autoPopTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _undo() async {
    _autoPopTimer?.cancel();
    final tx = _savedTx;
    if (tx != null) {
      await context.read<TransactionProvider>().deleteTransaction(tx.id);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

enum VoiceStage { idle, listening, parsed, saved, error }
```

- [ ] **Step 3: Add the new imports**

At the top of `lib/widgets/add_expense_sheet.dart`, add (alongside the existing imports):

```dart
import 'dart:async';
import '../services/purchase_transcript_parser.dart';
import '../services/voice_capture_service.dart';
import '../ai/purchase_transcript_adapter.dart';
import '../services/sms_rules_engine.dart';
```

(`CategorizationAdapter`, `AiProvider`, `AiService`, `AccountProvider`, `TransactionProvider`, `UserPreferencesProvider`, `Category`, `Transaction`, `TransactionType` are already imported in this file for `ManualEntryForm`'s existing AI-suggestion code — no new import needed for those.)

- [ ] **Step 4: Manual verification (no automated test — see Task 4 rationale, same applies here: this is UI + live mic + live Gemma)**

Run: `flutter analyze lib/widgets/add_expense_sheet.dart`
Expected: no errors.

On a real Android device (or emulator with a virtual microphone routed to a test audio source): open Add Transaction, tap the new mic icon in the header, tap the big mic circle, speak "spent two hundred on coffee at Third Wave", confirm the parsed chips look right, tap Confirm & Save, confirm the transaction appears in the transactions list with today's date and the right amount.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/add_expense_sheet.dart
git commit -m "feat: wire VoiceInputForm to real capture, parsing, and save"
```

---

### Task 6: Android App Shortcut + deep-link manifest wiring

**Files:**
- Create: `android/app/src/main/res/xml/shortcuts.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: the `wllt://voice-add` URI, which Task 7's `app_links` listener consumes.

- [ ] **Step 1: Create the shortcut definition**

Create `android/app/src/main/res/xml/shortcuts.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut
        android:shortcutId="voice_add_transaction"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/shortcut_add_expense_short"
        android:shortcutLongLabel="@string/shortcut_add_expense_long">
        <intent
            android:action="android.intent.action.VIEW"
            android:targetPackage="${applicationId}"
            android:targetClass="${applicationId}.MainActivity"
            android:data="wllt://voice-add" />
    </shortcut>
</shortcuts>
```

- [ ] **Step 2: Add the shortcut labels**

Create `android/app/src/main/res/values/strings.xml` (it doesn't exist yet in this project) with:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="shortcut_add_expense_short">Add expense</string>
    <string name="shortcut_add_expense_long">Add an expense by voice</string>
</resources>
```

- [ ] **Step 3: Wire the shortcut and the deep link into the manifest**

In `android/app/src/main/AndroidManifest.xml`:

Add the permission, alongside the existing `<uses-permission>` block at the top (after `READ_SMS`):

```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Inside the `<activity android:name=".MainActivity" ...>` block, add the shortcuts meta-data (as a sibling of the existing `io.flutter.embedding.android.NormalTheme` meta-data) and a new intent-filter for the deep link (as a sibling of the existing MAIN/LAUNCHER and SEND intent-filters):

```xml
            <meta-data
              android:name="android.app.shortcuts"
              android:resource="@xml/shortcuts" />
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="wllt" android:host="voice-add" />
            </intent-filter>
```

- [ ] **Step 4: Manual verification**

Run: `flutter build apk --debug` (or `flutter run` on a connected Android device/emulator)
Expected: builds successfully.

On a real device: long-press the app icon and confirm an "Add expense" shortcut appears; tapping it should cold/warm-start the app (deep-link handling itself lands in Task 7 — until then, expect the app to just open normally with no crash).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/res/xml/shortcuts.xml android/app/src/main/res/values/strings.xml android/app/src/main/AndroidManifest.xml
git commit -m "feat: add Android App Shortcut and deep-link intent-filter for voice add"
```

---

### Task 7: `app_links` wiring in `main.dart` — catch the deep link

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AddTransactionPage(startInVoiceMode: true)` (Task 5), `wllt://voice-add` (Task 6), `AppLinks` (package `app_links`).

- [ ] **Step 1: Add a navigator key and the `app_links` import**

In `lib/main.dart`, add to the imports:

```dart
import 'package:app_links/app_links.dart';
import 'widgets/add_expense_sheet.dart';
import 'screens/layout_screen.dart' show AddTransactionMethod;
```

Add a module-level navigator key (near the top of the file, alongside other top-level declarations, before `void main()`):

```dart
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
```

Attach it to `MaterialApp` in `_ThemedAppState.build()` (the `MaterialApp(` call around line 259):

```dart
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'WLLT',
```

- [ ] **Step 2: Listen for the deep link**

In `_ThemedAppState`, add the subscription field alongside the existing ones:

```dart
  StreamSubscription<User?>? _authSub;
  StreamSubscription? _sharingSubscription;
  StreamSubscription<Uri>? _appLinksSubscription;
  final AppLinks _appLinks = AppLinks();
```

In `initState()`, after the existing `receive_sharing_intent` block (after the `ReceiveSharingIntent.instance.getInitialMedia().then(...)` call, before the `WidgetsBinding.instance.addPostFrameCallback` block), add:

```dart
    if (!kIsWeb) {
      _appLinksSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) _handleDeepLink(uri);
      });
    }
```

Add the handler method, next to `_handleSharedText`:

```dart
  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'wllt' || uri.host != 'voice-add') return;
    if (FirebaseAuth.instance.currentUser == null) return;
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionPage(
          method: AddTransactionMethod.expense,
          startInVoiceMode: true,
        ),
      ),
    );
  }
```

Cancel the subscription in `dispose()`, alongside the existing ones:

```dart
  @override
  void dispose() {
    _authSub?.cancel();
    _sharingSubscription?.cancel();
    _appLinksSubscription?.cancel();
    super.dispose();
  }
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/main.dart`
Expected: no errors.

- [ ] **Step 4: Manual verification (real Android device)**

With Tasks 5-7 all in place: trigger the "Add expense" App Shortcut (long-press icon, or say "Hey Google, add expense in wllt" if a matching Assistant Routine/shortcut phrase is set up). Confirm: app opens directly into the voice form with listening already started (mic circle shows the "listening" color without an extra tap), speaking a purchase saves it automatically, and the saved/undo state appears and auto-dismisses after ~3 seconds unless Undo is tapped. Also confirm: triggering the shortcut while signed out does nothing harmful (no crash, deep link silently ignored per the `currentUser == null` guard in Step 2).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: handle wllt://voice-add deep link, launch voice entry auto-started"
```

---

## Self-Review Notes

- **Spec coverage:** every component in the spec (`VoiceCaptureService`, `PurchaseTranscriptParser`, `PurchaseTranscriptAdapter`, category reuse via `SmsRulesEngine`/`CategorizationAdapter`, wired `VoiceInputForm`, manual-vs-auto save fork with Undo, App Shortcut + deep link, sign-in guard) has a task. The spec's "manual in-app mic tap" entry point is realized as the new header mic button + `_voiceMode` toggle (Task 5, Step 1) — a mechanism the spec didn't lock down explicitly, decided here to avoid touching the `AddTransactionMethod` enum and its three existing switch sites across `layout_screen.dart` and `add_expense_sheet.dart`.
- **Placeholder scan:** no TBD/TODO; every step has real code.
- **Type consistency:** `ParsedPurchase` (Task 2) is reused as the common shape both the regex parser and the Gemma adapter's result get normalized into (Task 5, `_handleTranscript`) — checked against both call sites. `VoiceCaptureError` (Task 4) enum members match exactly what `_handleCaptureError` (Task 5) switches over.
- **Not testable in this repo's CI:** real STT transcription accuracy, mic permission flow, App Shortcut registration, Assistant voice trigger, cold-start deep-link routing — all flagged as manual/real-device verification in Tasks 4, 5, 6, 7 rather than claimed as automated-tested.
