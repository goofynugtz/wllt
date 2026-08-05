# SMS LLM Fallback Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When regex-based SMS parsing (`SmsParser.parse`) fails, the existing LLM fallback (`SmsParserAdapter`) should also populate `account` (picked from the user's real account names) and `category` (via the existing `CategorizationAdapter`), not just `merchant`/`amount`/`type`.

**Architecture:** `SmsParserAdapter.parse` gains an `availableAccounts` param and an `account` result field, validated by exact membership in that list (same defensive pattern `CategorizationAdapter` already uses for category IDs). `SmsProvider.processRawSms` passes the user's account display names in, and — only when regex failed — calls the existing `CategorizationAdapter.suggest` as a second fallback when `SmsRulesEngine` finds no category hit.

**Tech Stack:** Dart, Flutter, `flutter_test`.

## Global Constraints

- LLM involvement (account + category fallback) fires ONLY when `SmsParser.parse()` returned `null`. Regex success must continue to skip all LLM calls — zero behavior change for already-working SMS formats.
- `account` returned by the LLM must be validated as an exact, case-sensitive member of the `availableAccounts` list passed in; anything else becomes `null`. Never trust free-form LLM output as an identifier.
- `category` fallback only triggers when `SmsRulesEngine.categorize` found nothing AND a merchant string exists AND `aiInfer` is available — it must not override an existing rules-engine hit.
- No new provider-level test harness — `sms_provider.dart` has no existing test file, and this codebase tests AI fallbacks at the adapter unit level (see `test/ai/sms_parser_adapter_test.dart`, `test/ai/categorization_adapter_test.dart`). Stay in that pattern.
- Per project convention: do not run `git` commands. Each task below ends with a checkpoint instead of a commit step — the user commits.

---

### Task 1: Extend `SmsParserAdapter` with account extraction

**Files:**
- Modify: `lib/ai/sms_parser_adapter.dart` (whole file, currently 49 lines)
- Test: `test/ai/sms_parser_adapter_test.dart` (append to existing file)

**Interfaces:**
- Produces: `SmsParseResult.account` (`String?`), `SmsParserAdapter.parse({required String rawSms, required InferFn infer, List<String> availableAccounts = const []})` — same return type `Future<SmsParseResult?>` as before, `infer` param unchanged.
- Consumes: nothing new — `InferFn` typedef already imported from `categorization_adapter.dart`.

- [ ] **Step 1: Write the failing tests**

Append to `test/ai/sms_parser_adapter_test.dart` (inside the existing `void main() { ... }`, after the last test, before the closing `}`):

```dart
  Future<String> accountMatchInfer(String p) async =>
      '{"merchant":"Zomato","amount":349.0,"type":"debit","account":"HDFC Savings"}';
  Future<String> accountMismatchInfer(String p) async =>
      '{"merchant":"Zomato","amount":349.0,"type":"debit","account":"Random Bank"}';

  test('includes account when LLM returns one from the provided list', () async {
    final result = await SmsParserAdapter.parse(
      rawSms: sms,
      infer: accountMatchInfer,
      availableAccounts: ['HDFC Savings', 'ICICI Credit Card'],
    );
    expect(result, isNotNull);
    expect(result!.account, equals('HDFC Savings'));
  });

  test('returns null account when LLM output is not in the provided list', () async {
    final result = await SmsParserAdapter.parse(
      rawSms: sms,
      infer: accountMismatchInfer,
      availableAccounts: ['HDFC Savings', 'ICICI Credit Card'],
    );
    expect(result, isNotNull);
    expect(result!.account, isNull);
  });

  test('returns null account when no availableAccounts provided', () async {
    final result = await SmsParserAdapter.parse(
      rawSms: sms,
      infer: accountMatchInfer,
    );
    expect(result, isNotNull);
    expect(result!.account, isNull);
  });
```

Note: `accountMatchInfer`/`accountMismatchInfer` and the three tests must be declared at the same level as the existing `goodInfer` etc. — inside `main()`, before the closing brace. `sms` is the existing top-level-in-`main()` const already defined in the file.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ai/sms_parser_adapter_test.dart`
Expected: FAIL — compile error, `The named parameter 'availableAccounts' isn't defined` / `The getter 'account' isn't defined for the type 'SmsParseResult'`.

- [ ] **Step 3: Implement `account` support**

Replace the full contents of `lib/ai/sms_parser_adapter.dart`:

```dart
import 'dart:convert';
import 'categorization_adapter.dart' show InferFn;

class SmsParseResult {
  final String? merchant;
  final double amount;
  final String type; // 'debit' | 'credit'
  final String? account;

  const SmsParseResult({
    required this.merchant,
    required this.amount,
    required this.type,
    this.account,
  });
}

class SmsParserAdapter {
  SmsParserAdapter._();

  static Future<SmsParseResult?> parse({
    required String rawSms,
    required InferFn infer,
    List<String> availableAccounts = const [],
  }) async {
    final accountsBlock = availableAccounts.isEmpty
        ? ''
        : 'Accounts: ${availableAccounts.join(', ')}\n'
            'If the SMS matches one of these accounts, set "account" to its exact name, else null.\n';

    final prompt = '<start_of_turn>user\n'
        'Extract transaction from this SMS as JSON.\n'
        'SMS: "$rawSms"\n'
        '$accountsBlock'
        'Reply with only: {"merchant":"...","amount":0.0,"type":"debit|credit","account":"..."}\n'
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
      final type = json['type'] as String? ?? 'debit';
      if (type != 'debit' && type != 'credit') return null;
      final rawAccount = json['account'] as String?;
      final account = availableAccounts.contains(rawAccount) ? rawAccount : null;
      return SmsParseResult(
        merchant: json['merchant'] as String?,
        amount: amount,
        type: type,
        account: account,
      );
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ai/sms_parser_adapter_test.dart`
Expected: PASS — all tests (original 6 + new 3) green.

- [ ] **Checkpoint:** Task complete. Files touched: `lib/ai/sms_parser_adapter.dart`, `test/ai/sms_parser_adapter_test.dart`. Do not commit — leave staged/unstaged for the user.

---

### Task 2: Wire account + category AI fallback into `SmsProvider`

**Files:**
- Modify: `lib/providers/sms_provider.dart:18` (import), `lib/providers/sms_provider.dart:55-115` (`processRawSms`)

**Interfaces:**
- Consumes: `SmsParserAdapter.parse(..., availableAccounts: List<String>)` and `SmsParseResult.account` from Task 1. `CategorizationAdapter.suggest({required String merchant, required List<String> availableCategories, required InferFn infer})` — existing, already used identically in `lib/widgets/add_expense_sheet.dart:1422-1426`, returns `Future<String?>` (a validated category ID or `null`).
- Produces: no new public interface — `processRawSms`'s signature is unchanged (`aiInfer` was already optional); only its internal behavior changes.

- [ ] **Step 1: Widen the `categorization_adapter.dart` import**

In `lib/providers/sms_provider.dart`, change line 18 from:

```dart
import '../ai/categorization_adapter.dart' show InferFn;
```

to:

```dart
import '../ai/categorization_adapter.dart';
```

(This still exposes the `InferFn` typedef used throughout the file — `show InferFn` was just restricting to it; now `CategorizationAdapter` is also visible.)

- [ ] **Step 2: Rewrite `processRawSms` to gate AI fallback on `regexFailed` and wire account + category**

Replace the body of `processRawSms` (currently `lib/providers/sms_provider.dart:55-115`) with:

```dart
  Future<ProcessResult> processRawSms(
    String sender,
    String body,
    String? smsId, {
    InferFn? aiInfer,
  }) async {
    final contentHash = _hashBody(body);
    final dedup = _store.checkDuplicate(smsId, contentHash);
    if (dedup == DedupResult.duplicateConfirmed) return ProcessResult.alreadyCaptured;
    if (dedup == DedupResult.duplicatePending) {
      final existing = pending.firstWhereOrNull((p) => p.rawSms == body);
      if (existing != null) {
        _highlightedId = existing.id;
        notifyListeners();
      }
      return ProcessResult.alreadyPending;
    }

    final verdict = SmsValidator.validate(sender, body);
    if (verdict == SmsVerdict.blocked) return ProcessResult.blocked;

    if (!SmsFilter.isFinancial(sender, body)) return ProcessResult.filtered;

    ParsedSmsResult? parsed = SmsParser.parse(sender, body);
    final regexFailed = parsed == null;

    // If deterministic parse failed and AI is available, try AI parsing —
    // covers merchant/amount/type plus, now, account.
    if (regexFailed && aiInfer != null) {
      final aiResult = await SmsParserAdapter.parse(
        rawSms: body,
        infer: aiInfer,
        availableAccounts: _accounts.accounts.map((a) => a.displayName).toList(),
      );
      if (aiResult != null) {
        parsed = ParsedSmsResult(
          merchant: aiResult.merchant,
          amount: aiResult.amount,
          type: aiResult.type == 'credit' ? TransactionType.income : TransactionType.expense,
          accountHint: aiResult.account,
        );
      }
    }

    final hint = SmsRulesEngine.categorize(parsed?.merchant);
    var categoryId = hint != null ? _resolveCategoryId(hint) : null;

    // Rules engine missed and we already had to invoke AI for extraction
    // (regex failed) — let AI suggest a category too.
    if (categoryId == null && regexFailed && parsed?.merchant != null && aiInfer != null) {
      final categoryIds = _prefs.activeCategories.isNotEmpty
          ? _prefs.activeCategories
          : Category.categories.map((c) => c.id).toList();
      categoryId = await CategorizationAdapter.suggest(
        merchant: parsed!.merchant!,
        availableCategories: categoryIds,
        infer: aiInfer,
      );
    }

    final accountHint = parsed?.accountHint ?? _hintFromSender(sender);

    final item = PendingSmsTransaction(
      id: smsId ?? contentHash,
      rawSms: body,
      merchant: parsed?.merchant,
      amount: parsed?.amount,
      type: parsed?.type ?? TransactionType.expense,
      categoryId: categoryId,
      accountHint: accountHint,
      parsedAt: DateTime.now(),
      isUnparsed: parsed == null,
      verdict: verdict,
    );

    await _store.add(item, smsId: smsId, contentHash: contentHash);
    notifyListeners();
    return ProcessResult.added;
  }
```

- [ ] **Step 3: Static-check the file**

Run: `flutter analyze lib/providers/sms_provider.dart lib/ai/sms_parser_adapter.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run the full test suite to confirm no regressions**

Run: `flutter test`
Expected: PASS — every existing test (including `test/ai/sms_parser_adapter_test.dart` from Task 1, `test/ai/categorization_adapter_test.dart`, `test/services/sms_parser_test.dart`) still green. There is no `sms_provider_test.dart` to run specifically (see Global Constraints) — this wiring is exercised only through the two independently-tested adapters it calls.

- [ ] **Checkpoint:** Task complete. Files touched: `lib/providers/sms_provider.dart`. Do not commit — leave staged/unstaged for the user.

---

### Task 3: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!` (or only pre-existing issues unrelated to this change — compare against output before Task 1 if unsure).

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Checkpoint:** Implementation complete. Summarize for the user: `lib/ai/sms_parser_adapter.dart`, `test/ai/sms_parser_adapter_test.dart`, `lib/providers/sms_provider.dart` changed. User reviews and commits.
