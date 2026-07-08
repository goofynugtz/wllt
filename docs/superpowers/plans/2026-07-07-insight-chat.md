# Insight Chat + Suggested Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tap the AI weekly insight card to open an on-device LLM chat seeded with spending facts; save suggestion replies to a persistent device-local "Suggested Actions" checklist card on the home screen.

**Architecture:** Stateless chat — every turn rebuilds the full prompt (facts + trimmed history + new message) and runs through the existing `AiService.infer` session-per-call pattern. Suggestion replies are detected by an `ACTION:` prefix the model is instructed to emit. Actions persist in a new Hive box behind a `ChangeNotifier` provider.

**Tech Stack:** Flutter, provider, Hive (`hive_flutter`), flutter_gemma (Gemma 3 1B int4, on-device), lucide_icons.

**Spec:** `docs/superpowers/specs/2026-07-07-insight-chat-design.md`

## Global Constraints

- **NO git operations by agents.** The user handles all staging, commits, and branching. Never run `git add`/`git commit`. Where a plan step would normally commit, stop and report instead.
- Chat is mobile-only: entry gated on `!kIsWeb && AiProvider.isReady && _aiInsights.isNotEmpty`. The web build must keep compiling (no `flutter_gemma` imports in widgets shared with web — `InsightChatScreen` imports `AiService`, which already has a web stub via conditional import, so this is satisfied).
- Suggested Actions are device-only (Hive box `suggested_actions`). No Firestore sync.
- Chat state is ephemeral — screen-local only, discarded on pop.
- Model context raised `512 → 1024` tokens in exactly one place: `AiService.initModel`.
- All chat prompt text uses the Gemma turn format: `<start_of_turn>user\n…<end_of_turn>\n<start_of_turn>model\n`.
- Run tests with `flutter test <path>` and static analysis with `flutter analyze` from repo root `D:\Projects\Prototypes\HireAlrt\mobile\wllt`.
- Project lint style: no trailing-comment noise, match existing file idioms (see `lib/ai/insight_adapter.dart`, `lib/providers/ai_provider.dart`).

---

### Task 1: `SuggestedAction` model

**Files:**
- Create: `lib/models/suggested_action.dart`
- Test: `test/models/suggested_action_test.dart`

**Interfaces:**
- Consumes: nothing (leaf model).
- Produces: `SuggestedAction({required String id, required String text, required DateTime createdAt, bool done = false})`, `copyWith({bool? done})`, `String encode()`, `factory SuggestedAction.decode(String)`. Tasks 2, 4, 5 use these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/models/suggested_action_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/models/suggested_action.dart';

void main() {
  test('encode/decode roundtrip preserves all fields', () {
    final action = SuggestedAction(
      id: '1751900000000',
      text: 'Cancel Netflix to save ₹649/month',
      createdAt: DateTime(2026, 7, 7, 10, 30),
      done: true,
    );
    final decoded = SuggestedAction.decode(action.encode());
    expect(decoded.id, action.id);
    expect(decoded.text, action.text);
    expect(decoded.createdAt, action.createdAt);
    expect(decoded.done, isTrue);
  });

  test('done defaults to false', () {
    final action = SuggestedAction(
      id: '1',
      text: 'x',
      createdAt: DateTime(2026, 1, 1),
    );
    expect(action.done, isFalse);
  });

  test('copyWith flips done and keeps identity', () {
    final action = SuggestedAction(
      id: '1',
      text: 'x',
      createdAt: DateTime(2026, 1, 1),
    );
    final toggled = action.copyWith(done: true);
    expect(toggled.done, isTrue);
    expect(toggled.id, '1');
    expect(toggled.text, 'x');
    expect(toggled.createdAt, action.createdAt);
  });

  test('decode tolerates missing optional fields', () {
    final decoded = SuggestedAction.decode(
        '{"id":"7","text":"hello","createdAt":"2026-07-07T00:00:00.000"}');
    expect(decoded.done, isFalse);
    expect(decoded.text, 'hello');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/suggested_action_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'wllt/models/suggested_action.dart'` (file does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `lib/models/suggested_action.dart`:

```dart
import 'dart:convert';

/// One saved LLM suggestion in the "Suggested Actions" checklist.
/// Stored device-only as a JSON string in the `suggested_actions` Hive box.
class SuggestedAction {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool done;

  const SuggestedAction({
    required this.id,
    required this.text,
    required this.createdAt,
    this.done = false,
  });

  SuggestedAction copyWith({bool? done}) => SuggestedAction(
        id: id,
        text: text,
        createdAt: createdAt,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'done': done,
      };

  factory SuggestedAction.fromJson(Map<String, dynamic> json) =>
      SuggestedAction(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        done: json['done'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  factory SuggestedAction.decode(String source) =>
      SuggestedAction.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/suggested_action_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Checkpoint**

Run: `flutter analyze lib/models/suggested_action.dart`
Expected: No issues found. Do NOT commit — report task complete; the user commits.

---

### Task 2: `SuggestedActionsProvider`

**Files:**
- Create: `lib/providers/suggested_actions_provider.dart`
- Test: `test/providers/suggested_actions_provider_test.dart`

**Interfaces:**
- Consumes: `SuggestedAction` from Task 1 (`encode()`, `decode()`, `copyWith(done:)`).
- Produces: `SuggestedActionsProvider` extends `ChangeNotifier` with
  `Future<void> init()`, `List<SuggestedAction> get actions` (sorted newest
  first by `createdAt`), `bool contains(String text)`,
  `Future<void> add(String text)` (dedupe: no-op when identical text exists),
  `Future<void> toggleDone(String id)`, `Future<void> remove(String id)`.
  Tasks 4, 5, 6 use these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/providers/suggested_actions_provider_test.dart` (temp-dir Hive pattern from `test/services/storage_service_ai_test.dart`):

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wllt/providers/suggested_actions_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_actions_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('suggested_actions');
    await Hive.close();
  });

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  test('starts empty', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    expect(p.actions, isEmpty);
  });

  test('add stores action with text and done=false', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('Cancel Netflix to save ₹649/month');
    expect(p.actions, hasLength(1));
    expect(p.actions.first.text, 'Cancel Netflix to save ₹649/month');
    expect(p.actions.first.done, isFalse);
  });

  test('add with duplicate text is a no-op', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('same text');
    await p.add('same text');
    expect(p.actions, hasLength(1));
    expect(p.contains('same text'), isTrue);
    expect(p.contains('other'), isFalse);
  });

  test('toggleDone flips and persists', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('do a thing');
    final id = p.actions.first.id;
    await p.toggleDone(id);
    expect(p.actions.first.done, isTrue);
    await p.toggleDone(id);
    expect(p.actions.first.done, isFalse);
  });

  test('remove deletes the action', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('to be removed');
    await p.remove(p.actions.first.id);
    expect(p.actions, isEmpty);
  });

  test('actions survive provider re-instantiation', () async {
    final p1 = SuggestedActionsProvider();
    await p1.init();
    await p1.add('persist me');
    await p1.toggleDone(p1.actions.first.id);

    final p2 = SuggestedActionsProvider();
    await p2.init();
    expect(p2.actions, hasLength(1));
    expect(p2.actions.first.text, 'persist me');
    expect(p2.actions.first.done, isTrue);
  });

  test('notifies listeners on mutations', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    var notified = 0;
    p.addListener(() => notified++);
    await p.add('a');
    await p.toggleDone(p.actions.first.id);
    await p.remove(p.actions.first.id);
    expect(notified, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/suggested_actions_provider_test.dart`
Expected: FAIL — package resolve error (provider file does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `lib/providers/suggested_actions_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/suggested_action.dart';

/// Device-local "Suggested Actions" checklist saved from insight chat.
/// One JSON string per action in the `suggested_actions` Hive box, keyed
/// by the action id.
class SuggestedActionsProvider extends ChangeNotifier {
  static const _boxName = 'suggested_actions';

  Box<String>? _box;
  List<SuggestedAction> _actions = [];

  /// Newest first.
  List<SuggestedAction> get actions => List.unmodifiable(_actions);

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    _reload(notify: false);
  }

  void _reload({bool notify = true}) {
    final box = _box;
    if (box == null) return;
    _actions = box.values.map(SuggestedAction.decode).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (notify) notifyListeners();
  }

  bool contains(String text) => _actions.any((a) => a.text == text);

  Future<void> add(String text) async {
    if (contains(text)) return;
    final now = DateTime.now();
    final action = SuggestedAction(
      id: now.millisecondsSinceEpoch.toString(),
      text: text,
      createdAt: now,
    );
    await _box?.put(action.id, action.encode());
    _reload();
  }

  Future<void> toggleDone(String id) async {
    final idx = _actions.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final updated = _actions[idx].copyWith(done: !_actions[idx].done);
    await _box?.put(id, updated.encode());
    _reload();
  }

  Future<void> remove(String id) async {
    await _box?.delete(id);
    _reload();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/suggested_actions_provider_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Checkpoint**

Run: `flutter analyze lib/providers/suggested_actions_provider.dart`
Expected: No issues found. Do NOT commit — user commits.

---

### Task 3: `ChatAdapter`

**Files:**
- Create: `lib/ai/chat_adapter.dart`
- Test: `test/ai/chat_adapter_test.dart`

**Interfaces:**
- Consumes: `InferFn` typedef from `lib/ai/categorization_adapter.dart` (`typedef InferFn = Future<String> Function(String prompt);`).
- Produces:
  - `class ChatTurn { final bool isUser; final String text; const ChatTurn({required this.isUser, required this.text}); }`
  - `class ChatReply { final String text; final bool isSuggestion; }`
  - `static Future<ChatReply?> ChatAdapter.generate({required List<String> facts, required List<ChatTurn> history, required String userMessage, required InferFn infer})`
  Task 4 uses these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/ai/chat_adapter_test.dart` (fake-`InferFn` pattern from `test/ai/insight_adapter_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/chat_adapter.dart';

void main() {
  const facts = [
    'Recurring subscriptions: Netflix ₹649 (₹649/month total)',
    'Top category: Groceries ₹8,200 (41% of ₹20,000 total)',
  ];

  test('strips ACTION: marker and flags suggestion', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'How can I save money?',
      infer: (p) async => 'ACTION: Cancel Netflix to save ₹649/month.',
    );
    expect(reply, isNotNull);
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'Cancel Netflix to save ₹649/month.');
  });

  test('marker match is case-insensitive and trims whitespace', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => '  action:   cap groceries at ₹7,000  ',
    );
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'cap groceries at ₹7,000');
  });

  test('reply without marker is not a suggestion', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'why is my spend high?',
      infer: (p) async => 'Which category do you want to cut first?',
    );
    expect(reply!.isSuggestion, isFalse);
    expect(reply.text, 'Which category do you want to cut first?');
  });

  test('returns null on empty reply', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => '   ',
    );
    expect(reply, isNull);
  });

  test('returns null on marker with empty body', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => 'ACTION:',
    );
    expect(reply, isNull);
  });

  test('returns null when infer throws', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => throw Exception('timeout'),
    );
    expect(reply, isNull);
  });

  test('prompt contains facts, rules, and user message', () async {
    String? seen;
    await ChatAdapter.generate(
      facts: facts,
      history: const [ChatTurn(isUser: false, text: 'Earlier coach reply')],
      userMessage: 'What about groceries?',
      infer: (p) async {
        seen = p;
        return 'ok';
      },
    );
    expect(seen, contains('Netflix ₹649'));
    expect(seen, contains('start your reply with "ACTION:"'));
    expect(seen, contains('Coach: Earlier coach reply'));
    expect(seen, contains('User says: What about groceries?'));
    expect(seen, startsWith('<start_of_turn>user\n'));
    expect(seen, endsWith('<start_of_turn>model\n'));
  });

  test('drops oldest history turns to fit budget, keeps newest', () async {
    final filler = 'x' * 200;
    final history = <ChatTurn>[
      for (var i = 0; i < 50; i++)
        ChatTurn(isUser: i.isEven, text: 'turn$i $filler'),
    ];
    String? seen;
    await ChatAdapter.generate(
      facts: facts,
      history: history,
      userMessage: 'latest question',
      infer: (p) async {
        seen = p;
        return 'ok';
      },
    );
    expect(seen, isNot(contains('turn0 ')));
    expect(seen, contains('turn49 '));
    expect(seen, contains('Netflix ₹649'));
    expect(seen, contains('latest question'));
    expect(seen!.length, lessThan(4000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ai/chat_adapter_test.dart`
Expected: FAIL — package resolve error (adapter file does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `lib/ai/chat_adapter.dart`:

```dart
import 'categorization_adapter.dart' show InferFn;

/// One prior exchange in the ephemeral insight chat.
class ChatTurn {
  final bool isUser;
  final String text;
  const ChatTurn({required this.isUser, required this.text});
}

/// A model reply; [isSuggestion] is true when the model marked it as a
/// concrete saving action (ACTION: prefix, stripped from [text]).
class ChatReply {
  final String text;
  final bool isSuggestion;
  const ChatReply({required this.text, required this.isSuggestion});
}

class ChatAdapter {
  ChatAdapter._();

  static const _marker = 'action:';

  /// ~700 tokens at ~4 chars/token for the facts + history + message block.
  /// The model context is 1024; this leaves room for the rule text and a
  /// 150-token reply.
  static const _charBudget = 2800;

  /// Runs one chat turn. Rebuilds the full prompt every call (stateless —
  /// AiService uses one session per inference). Returns null when the model
  /// produced nothing usable or inference failed; caller shows an error
  /// bubble with retry.
  static Future<ChatReply?> generate({
    required List<String> facts,
    required List<ChatTurn> history,
    required String userMessage,
    required InferFn infer,
  }) async {
    final factBlock = facts.map((f) => '- $f').join('\n');

    // Drop oldest turns until facts + history + message fit the budget.
    final kept = List<ChatTurn>.from(history);
    String historyBlock() => kept
        .map((t) => '${t.isUser ? 'User' : 'Coach'}: ${t.text}')
        .join('\n');
    while (kept.isNotEmpty &&
        factBlock.length + historyBlock().length + userMessage.length >
            _charBudget) {
      kept.removeAt(0);
    }
    final convo =
        kept.isEmpty ? '' : 'Conversation so far:\n${historyBlock()}\n';

    final prompt = '<start_of_turn>user\n'
        'You are a personal finance coach. User\'s spending facts:\n'
        '$factBlock\n'
        'Rules: Max 3 sentences. Cite exact amounts from facts. If you give '
        'a concrete saving action, start your reply with "ACTION:". If you '
        'need more info, just ask a question instead.\n'
        '$convo'
        'User says: $userMessage\n'
        '<end_of_turn>\n'
        '<start_of_turn>model\n';

    try {
      final raw = (await infer(prompt)).trim();
      if (raw.isEmpty) return null;
      if (raw.toLowerCase().startsWith(_marker)) {
        final text = raw.substring(_marker.length).trim();
        if (text.isEmpty) return null;
        return ChatReply(text: text, isSuggestion: true);
      }
      return ChatReply(text: raw, isSuggestion: false);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ai/chat_adapter_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Checkpoint**

Run: `flutter analyze lib/ai/chat_adapter.dart`
Expected: No issues found. Do NOT commit — user commits.

---

### Task 4: `InsightChatScreen`

**Files:**
- Create: `lib/screens/insight_chat_screen.dart`

**Interfaces:**
- Consumes: `ChatAdapter.generate`, `ChatTurn`, `ChatReply` (Task 3); `SuggestedActionsProvider.add/contains` (Task 2); `AiService.instance.infer` (existing).
- Produces: `InsightChatScreen({super.key, required String insightText, required List<String> factLines})` — pushed by Task 6.

No unit test (UI-only; logic already covered in Tasks 2–3). Verified by `flutter analyze` here and the full suite + manual run in Task 6.

- [ ] **Step 1: Write the screen**

Create `lib/screens/insight_chat_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../ai/chat_adapter.dart';
import '../providers/suggested_actions_provider.dart';
import '../services/ai_service.dart';

/// Ephemeral chat with the on-device model about the current weekly insight.
/// Seeded with the insight text and the fact lines that generated it. All
/// state is screen-local — popping discards the conversation; saved actions
/// are the durable output.
class InsightChatScreen extends StatefulWidget {
  final String insightText;
  final List<String> factLines;

  const InsightChatScreen({
    super.key,
    required this.insightText,
    required this.factLines,
  });

  @override
  State<InsightChatScreen> createState() => _InsightChatScreenState();
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final bool isSuggestion;
  final bool isError;

  const _ChatMessage({
    required this.isUser,
    required this.text,
    this.isSuggestion = false,
    this.isError = false,
  });
}

class _InsightChatScreenState extends State<InsightChatScreen> {
  final _messages = <_ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _generating = false;
  String? _lastUserMessage;

  @override
  void initState() {
    super.initState();
    // The tapped insight opens the conversation. Not saveable — it is the
    // insight itself, not a suggestion.
    _messages.add(_ChatMessage(isUser: false, text: widget.insightText));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ChatTurn> get _historyForModel => [
        for (final m in _messages)
          if (!m.isError) ChatTurn(isUser: m.isUser, text: m.text),
      ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _generating) return;
    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
    });
    await _generate(text);
  }

  /// Re-runs generation for the last user message after an error bubble.
  Future<void> _retry() async {
    final text = _lastUserMessage;
    if (text == null || _generating) return;
    setState(() {
      _messages.removeWhere((m) => m.isError);
    });
    await _generate(text);
  }

  Future<void> _generate(String userMessage) async {
    _lastUserMessage = userMessage;
    // History for the model excludes the message being answered — it goes
    // into the prompt's "User says:" slot instead.
    final history = _historyForModel
        .sublist(0, _historyForModel.length - 1);
    setState(() => _generating = true);
    _scrollToBottom();

    final reply = await ChatAdapter.generate(
      facts: widget.factLines,
      history: history,
      userMessage: userMessage,
      infer: (p) =>
          AiService.instance.infer(p, temperature: 0.4, maxTokens: 150),
    );

    if (!mounted) return;
    setState(() {
      _generating = false;
      _messages.add(reply == null
          ? const _ChatMessage(
              isUser: false,
              text: "Couldn't think of a reply. Try again.",
              isError: true,
            )
          : _ChatMessage(
              isUser: false,
              text: reply.text,
              isSuggestion: reply.isSuggestion,
            ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insight Chat')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length + (_generating ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _ThinkingBubble();
                  return _MessageBubble(
                    message: _messages[i],
                    onRetry: _messages[i].isError ? _retry : null,
                  );
                },
              ),
            ),
            _buildInputRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask about your spending…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _generating ? null : _send,
            icon: const Icon(LucideIcons.send, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: message.isError
              ? Border.all(color: scheme.error.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13,
                color: isUser
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
              ),
            ),
            if (message.isSuggestion) ...[
              const SizedBox(height: 8),
              _SaveActionButton(text: message.text),
            ],
            if (message.isError && onRetry != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onRetry,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.refreshCw, size: 12, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SaveActionButton extends StatelessWidget {
  final String text;

  const _SaveActionButton({required this.text});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestedActionsProvider>();
    final saved = provider.contains(text);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: saved
          ? null
          : () => context.read<SuggestedActionsProvider>().add(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: saved
              ? scheme.surfaceContainerHigh
              : scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? LucideIcons.check : LucideIcons.bookmarkPlus,
              size: 12,
              color: saved ? scheme.onSurfaceVariant : scheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              saved ? 'Saved ✓' : 'Save as action',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: saved ? scheme.onSurfaceVariant : scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FadeTransition(
          opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
          child: Text(
            'Thinking…',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analysis passes**

Run: `flutter analyze lib/screens/insight_chat_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Checkpoint**

Do NOT commit — user commits.

---

### Task 5: `SuggestedActionsCard` home-screen widget

**Files:**
- Create: `lib/widgets/suggested_actions_card.dart`

**Interfaces:**
- Consumes: `SuggestedActionsProvider.actions/toggleDone/remove` (Task 2).
- Produces: `const SuggestedActionsCard({super.key})` — self-margined
  (20 px sides, 12 px bottom, matching home sections), renders
  `SizedBox.shrink()` when the list is empty. Placed by Task 6.

- [ ] **Step 1: Write the widget**

Create `lib/widgets/suggested_actions_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/suggested_action.dart';
import '../providers/suggested_actions_provider.dart';

/// Home-screen checklist of suggestions saved from insight chat.
/// Unchecked newest-first, checked sink to the bottom (struck through,
/// dismissible via X). Hidden entirely when the list is empty.
class SuggestedActionsCard extends StatelessWidget {
  const SuggestedActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestedActionsProvider>();
    final actions = provider.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    final pending = actions.where((a) => !a.done).toList();
    final done = actions.where((a) => a.done).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.clipboardCheck,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Suggested Actions',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final action in pending) _ActionRow(action: action),
          for (final action in done) _ActionRow(action: action),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final SuggestedAction action;

  const _ActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.read<SuggestedActionsProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.toggleDone(action.id),
            child: Icon(
              action.done ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 18,
              color: action.done ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => provider.toggleDone(action.id),
              child: Text(
                action.text,
                style: TextStyle(
                  fontSize: 12,
                  color: action.done
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  decoration:
                      action.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          if (action.done) ...[
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => provider.remove(action.id),
              child: Icon(
                LucideIcons.x,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analysis passes**

Run: `flutter analyze lib/widgets/suggested_actions_card.dart`
Expected: No issues found.

- [ ] **Step 3: Checkpoint**

Do NOT commit — user commits.

---

### Task 6: Wiring — provider registration, context bump, home-screen tap + card

**Files:**
- Modify: `lib/main.dart` (provider list, ~line 137)
- Modify: `lib/services/ai_service.dart:64`
- Modify: `lib/screens/home_screen.dart` (imports; build method AI-row block ~lines 558–582; `_AiInsightRow`/`_AiInsightCard` classes ~lines 1495–1647)

**Interfaces:**
- Consumes: `SuggestedActionsProvider` (Task 2), `InsightChatScreen` (Task 4), `SuggestedActionsCard` (Task 5), existing `InsightFacts.compute`, `AiProvider.isReady`.
- Produces: end-to-end feature.

- [ ] **Step 1: Register provider in `main.dart`**

Add import at top with the other provider imports:

```dart
import 'providers/suggested_actions_provider.dart';
```

In the `MultiProvider` providers list (after the `AiProvider` entry, before `ExchangeRateService`), add:

```dart
ChangeNotifierProvider(
  create: (_) => SuggestedActionsProvider()..init(),
),
```

- [ ] **Step 2: Bump model context in `ai_service.dart`**

In `initModel()` change:

```dart
_model = await FlutterGemma.getActiveModel(maxTokens: 512);
```

to:

```dart
// 1024: chat prompt (facts + trimmed history) plus a 150-token reply
// needs more headroom than the one-shot summary/insight prompts.
_model = await FlutterGemma.getActiveModel(maxTokens: 1024);
```

- [ ] **Step 3: Wire home screen**

In `lib/screens/home_screen.dart`:

3a. Add imports (with the existing screen/widget imports):

```dart
import '../screens/insight_chat_screen.dart';
import '../widgets/suggested_actions_card.dart';
```

3b. Add an `_openInsightChat` method to `_HomeScreenState` (near `_pickAiDate`). It recomputes facts exactly like `_generateAiContent` so chat sees the same data the insight was generated from:

```dart
/// Opens the ephemeral insight chat. Facts are recomputed with the same
/// inputs the insight generation uses, so the model talks about the data
/// behind the card the user tapped.
void _openInsightChat() {
  if (_aiInsights.isEmpty) return;
  final allTx = context.read<TransactionProvider>().transactions;
  final prefs = context.read<UserPreferencesProvider>();
  final currencySymbol = kCurrencies
      .firstWhere((c) => c.code == prefs.currency,
          orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
      .symbol;
  final facts = InsightFacts.compute(
    transactions: allTx,
    asOf: DateTime.now(),
    currencySymbol: currencySymbol,
    budgetLimits: {for (final b in Budget.budgets) b.categoryId: b.amount},
  );
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => InsightChatScreen(
        insightText: _aiInsights.first,
        factLines: facts.factLines,
      ),
    ),
  );
}
```

3c. In `build()`, next to the existing `showAiDevPicker` computation, add:

```dart
// Chat entry: on-device model ready (mobile + Pro + AI on) and a real
// generated insight showing. Web and the dev placeholder never open chat.
final canOpenInsightChat =
    !kIsWeb && context.watch<AiProvider>().isReady && _aiInsights.isNotEmpty;
```

Note: `build()` already calls `context.watch<AiProvider>()` inside the `showAiDevPicker` expression, which is gated by `settings.devMode`. Hoist a single watch above both uses so the provider is watched once:

```dart
final aiReady = context.watch<AiProvider>().isReady;
final showAiDevPicker = !kIsWeb && settings.devMode && aiReady;
final canOpenInsightChat = !kIsWeb && aiReady && _aiInsights.isNotEmpty;
```

3d. Pass the tap through the insight row. In the build method's AI weekly insights block, change the real-insight branch only (`else if (_aiInsights.isNotEmpty)`):

```dart
else if (_aiInsights.isNotEmpty)
  _AiInsightRow(
    insights: _aiInsights,
    onDismiss: _webInsightWeekKey != null ? _dismissWebInsight : null,
    onPickDate: showAiDevPicker ? _pickAiDate : null,
    onTap: canOpenInsightChat ? _openInsightChat : null,
  )
```

The generating branch and dev-placeholder branch get no `onTap`.

3e. Add `onTap` to `_AiInsightRow` and forward it to every `_AiInsightCard` it builds:

```dart
class _AiInsightRow extends StatelessWidget {
  final List<String> insights;
  final VoidCallback? onDismiss;
  final VoidCallback? onPickDate;
  final VoidCallback? onTap;
  const _AiInsightRow({
    required this.insights,
    this.onDismiss,
    this.onPickDate,
    this.onTap,
  });
```

In both `_AiInsightCard(...)` constructions inside `_AiInsightRow.build`, add `onTap: onTap,` (for the multi-insight list builder, add it on every card: `onTap: onTap,`).

3f. Add `onTap` to `_AiInsightCard` and wrap its `Container` in a `GestureDetector`:

```dart
class _AiInsightCard extends StatelessWidget {
  final String text;
  final int maxLines;
  final VoidCallback? onDismiss;
  final VoidCallback? onPickDate;
  final VoidCallback? onTap;
  const _AiInsightCard({
    required this.text,
    required this.maxLines,
    this.onDismiss,
    this.onPickDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // ... existing Container unchanged ...
      ),
    );
  }
}
```

The inner calendar/X `GestureDetector`s sit higher in the hit-test order, so the dev picker and dismiss still work.

3g. Render the checklist card. In the build method's Column, directly after the AI weekly insights block (after the final `else if (showAiDevPicker) ... _AiInsightRow(...)` branch closes) and before the Recent-transactions `Padding`, add:

```dart
// ── Suggested Actions checklist ───────────────────────────────
const SuggestedActionsCard(),
```

(`SuggestedActionsCard` self-margins and collapses to `SizedBox.shrink()` when empty — no conditional wrapper needed.)

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: All tests pass, including the new `suggested_action_test.dart`, `suggested_actions_provider_test.dart`, `chat_adapter_test.dart` and all pre-existing tests.

- [ ] **Step 5: Analyze whole project**

Run: `flutter analyze`
Expected: No new issues (baseline: whatever the repo showed before this feature — compare if unsure).

- [ ] **Step 6: Manual verification (dev device)**

1. Run app on Android device/emulator with Pro + AI enabled and model downloaded.
2. Home: tap weekly insight card → chat opens, first bubble = insight text.
3. Send "how do I save money?" → thinking bubble → reply; if reply is a suggestion, "Save as action" shows.
4. Save one → button flips to "Saved ✓". Pop to home → "Suggested Actions" card shows item.
5. Check item → strikethrough + X appears; X removes it; card hides when empty.
6. Web build sanity: `flutter build web` compiles; insight card on web not tappable.

Report results to user. Do NOT commit — user commits.

---

## Self-review notes

- Spec coverage: model (T1), provider/storage (T2), adapter+prompt+marker (T3), chat screen UX/error/retry/ephemeral (T4), home card lifecycle (T5), gating + facts recompute + context bump + registration (T6). Out-of-scope items untouched.
- `maxTokens: 150` passed to `infer` is currently unused by `AiService.infer` (parameter accepted but not forwarded to the session) — pre-existing behavior, unchanged here; replies bound by the 1024 model context. Left as-is deliberately (fixing it touches the summary/insight paths too).
- Type names consistent across tasks: `SuggestedAction`, `SuggestedActionsProvider`, `ChatTurn`, `ChatReply`, `ChatAdapter.generate`, `InsightChatScreen(insightText:, factLines:)`, `SuggestedActionsCard`.
