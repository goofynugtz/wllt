# Chat Streaming Animations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static "Thinking…" bubble and all-at-once reply in `InsightChatScreen` with a bouncing-dots typing indicator followed by a real-time, typewriter-paced reveal of the model's reply as tokens actually stream in.

**Architecture:** `AiService.inferStream()` wraps `flutter_gemma`'s `InferenceModelSession.getResponseAsync()` (`Stream<String>` of raw token deltas). `ChatAdapter.generateStream()` consumes that stream, incrementally computing a marker-safe visible prefix (holding back partial `<end_of_turn>`/`ACTION:`/`Coach:` matches so they never flash on screen) and emitting `ChatStreamText` events, terminated by one `ChatStreamDone(ChatReply?)` whose result is always produced by the existing, already-tested `_parse` on the full raw buffer. `InsightChatScreen` drives a 3-state phase (`idle`/`thinking`/`streaming`): bouncing dots until the first safe token, then a catch-up typewriter ticker reveals the growing text, then a normal message bubble on completion.

**Tech Stack:** Flutter/Dart 3.11, `flutter_gemma` ^0.16.0, `flutter_test`.

## Global Constraints

- Dart SDK `^3.11.4` — sealed classes and record types (`({String, bool})`) are available and used below.
- `ChatAdapter.generateStream()` replaces `ChatAdapter.generate()` entirely (its only caller is `InsightChatScreen`) — no dual code path.
- `AiService.infer()` (non-streaming) stays untouched — `insight_adapter.dart` and `summary_adapter.dart` keep using it.
- Idle timeout on the inference stream: 10 seconds (per-chunk, resets on every emitted chunk) — via `.timeout(const Duration(seconds: 10))` on the `Stream<String>`.
- Typewriter reveal cadence: ~40 chars/sec baseline; if the backlog (`target.length - displayed.length`) exceeds 60 characters, the reveal rate increases so the backlog drains in ~500ms. Tick interval: 16ms. No trailing cursor.
- Typing indicator: 3 bouncing dots, no text label — replaces the current "Thinking…" fade bubble entirely.
- Only real stop markers (`<end_of_turn>`, `<start_of_turn>`, `\nUser:`, `\nCoach:`) may trigger early stream cancellation. The `ACTION:` marker caps how far the visible conversational text grows but must **not** cancel the stream — the action body keeps streaming in after it.

---

### Task 1: AiService token streaming

**Files:**
- Modify: `lib/services/ai_service.dart`
- Modify: `lib/platform/gemma_web.dart`

**Interfaces:**
- Produces: `Stream<String> AiService.inferStream(String prompt, {double temperature = 0.1, int maxTokens = 60})` — used by Task 3 (`InsightChatScreen`) via a `Stream<String> Function(String)` closure matching `ChatAdapter.InferStreamFn` from Task 2.
- Consumes: nothing new (mirrors existing `infer()`/`AiService.instance`/`_model` fields already in the file).

This task is native-FFI code with no unit-test surface (same as the existing untested `infer()`) — verified via `flutter analyze` here and manually end-to-end in Task 3.

- [ ] **Step 1: Add the `dart:async` import**

In `lib/services/ai_service.dart`, change line 1 from:

```dart
import 'package:flutter/foundation.dart';
```

to:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
```

- [ ] **Step 2: Add `inferStream()` after `infer()`**

In `lib/services/ai_service.dart`, insert this new method immediately after the closing `}` of `infer()` (currently line 97) and before the `deleteModel()` doc comment:

```dart

  /// Streams inference for [prompt] one raw token delta at a time. Creates
  /// and closes a session per call, same as [infer]. [temperature]:
  /// randomness (0.1 = deterministic, 0.4 = creative). Times out (throwing
  /// TimeoutException) if no chunk arrives within 10s — this is a per-chunk
  /// idle timeout, not a cap on total reply time.
  Stream<String> inferStream(
    String prompt, {
    double temperature = 0.1,
    int maxTokens = 60,
  }) async* {
    final model = _model;
    if (model == null) {
      throw StateError('AiService: model not initialized — call initModel() first');
    }

    final session = await model.createSession(
      temperature: temperature,
      topK: 1,
      randomSeed: 1,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      yield* session.getResponseAsync().timeout(const Duration(seconds: 10));
    } finally {
      await session.close();
    }
  }
```

- [ ] **Step 3: Add the matching web stub method**

Read `lib/platform/gemma_web.dart` first to confirm current line numbers, then add `import 'dart:async';` as the new line 1 (pushing the existing `// Web stub...` comment down), and add this method to the `Session` class, immediately after `getResponse()`:

```dart
  Stream<String> getResponseAsync() async* {}
```

The full `Session` class in `lib/platform/gemma_web.dart` should read:

```dart
class Session {
  Session._();
  Future<void> addQueryChunk(Message message) async {}
  Future<String> getResponse() async => '';
  Stream<String> getResponseAsync() async* {}
  Future<void> close() async {}
}
```

- [ ] **Step 4: Verify with static analysis**

Run: `flutter analyze lib/services/ai_service.dart lib/platform/gemma_web.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/ai_service.dart lib/platform/gemma_web.dart
git commit -m "feat: add AiService.inferStream for token-by-token inference"
```

---

### Task 2: ChatAdapter streaming with marker-safe incremental reveal

**Files:**
- Modify: `lib/ai/chat_adapter.dart`
- Modify: `test/ai/chat_adapter_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1 (tests use fake `InferStreamFn` closures; production wiring to `AiService.inferStream` happens in Task 3).
- Produces:
  - `typedef InferStreamFn = Stream<String> Function(String prompt);`
  - `sealed class ChatStreamEvent {}`
  - `class ChatStreamText extends ChatStreamEvent { final String text; }`
  - `class ChatStreamDone extends ChatStreamEvent { final ChatReply? reply; }`
  - `static Stream<ChatStreamEvent> ChatAdapter.generateStream({required List<String> facts, required List<ChatTurn> history, required String userMessage, required InferStreamFn inferStream})`
  - `ChatTurn` and `ChatReply` classes are unchanged (same fields as today).
  - Used by Task 3.

- [ ] **Step 1: Replace the test file with the streaming-based test suite**

Replace the full contents of `test/ai/chat_adapter_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/chat_adapter.dart';

/// Emits [text] one character at a time, simulating token-by-token
/// streaming from the model.
Stream<String> _charStream(String text) => Stream.fromIterable(text.split(''));

/// Runs [ChatAdapter.generateStream] to completion and returns the final
/// parsed reply from its terminal [ChatStreamDone] event.
Future<ChatReply?> _run({
  required List<String> facts,
  required List<ChatTurn> history,
  required String userMessage,
  required InferStreamFn inferStream,
}) async {
  final events = await ChatAdapter.generateStream(
    facts: facts,
    history: history,
    userMessage: userMessage,
    inferStream: inferStream,
  ).toList();
  expect(events, isNotEmpty);
  expect(events.last, isA<ChatStreamDone>());
  return (events.last as ChatStreamDone).reply;
}

void main() {
  const facts = [
    'Recurring subscriptions: Netflix ₹649 (₹649/month total)',
    'Top category: Groceries ₹8,200 (41% of ₹20,000 total)',
  ];

  test('splits mid-reply ACTION into text and actionText', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'How can I save money?',
      inferStream: (p) => _charStream(
          'You spend a lot on subscriptions. ACTION: Cancel Netflix to save ₹649/month.'),
    );
    expect(reply, isNotNull);
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'You spend a lot on subscriptions.');
    expect(reply.actionText, 'Cancel Netflix to save ₹649/month.');
  });

  test('reply that is only an action yields empty text', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) =>
          _charStream('ACTION: Cancel Netflix to save ₹649/month.'),
    );
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, isEmpty);
    expect(reply.actionText, 'Cancel Netflix to save ₹649/month.');
  });

  test('marker match is case-insensitive and trims whitespace', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) =>
          _charStream('Try this.  action:   cap groceries at ₹7,000  '),
    );
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'Try this.');
    expect(reply.actionText, 'cap groceries at ₹7,000');
  });

  test('strips echoed leading Coach: label', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'why is my spend high?',
      inferStream: (p) =>
          _charStream('Coach: Groceries drive most of your spending.'),
    );
    expect(reply!.isSuggestion, isFalse);
    expect(reply.text, 'Groceries drive most of your spending.');
  });

  test('strips Coach: label and still parses action', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream(
          'Coach: You overspend on food. ACTION: Set a ₹7,000 grocery cap'),
    );
    expect(reply!.text, 'You overspend on food.');
    expect(reply.actionText, 'Set a ₹7,000 grocery cap');
  });

  test('truncates hallucinated dialogue continuation', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) =>
          _charStream('Cut your coffee spend.\nUser: okay\nCoach: great!'),
    );
    expect(reply!.text, 'Cut your coffee spend.');
    expect(reply.isSuggestion, isFalse);
  });

  test('truncates at hallucinated turn tokens', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream(
          'Nice month overall!<end_of_turn>\n<start_of_turn>user\nthanks'),
    );
    expect(reply!.text, 'Nice month overall!');
  });

  test('reply without marker is not a suggestion', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'why is my spend high?',
      inferStream: (p) => _charStream('Which category do you want to cut first?'),
    );
    expect(reply!.isSuggestion, isFalse);
    expect(reply.actionText, isNull);
    expect(reply.text, 'Which category do you want to cut first?');
  });

  test('returns null on empty reply', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('   '),
    );
    expect(reply, isNull);
  });

  test('returns null on marker with empty body', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('ACTION:'),
    );
    expect(reply, isNull);
  });

  test('returns null when infer stream throws', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => Stream<String>.error(Exception('timeout')),
    );
    expect(reply, isNull);
  });

  test('prompt uses Gemma multi-turn format without name labels', () async {
    String? seen;
    await _run(
      facts: facts,
      history: const [
        ChatTurn(isUser: false, text: 'Earlier coach reply'),
        ChatTurn(isUser: true, text: 'What about groceries?'),
      ],
      userMessage: 'And subscriptions?',
      inferStream: (p) {
        seen = p;
        return _charStream('ok');
      },
    );
    expect(seen, startsWith('<start_of_turn>user\n'));
    expect(seen, endsWith('<start_of_turn>model\n'));
    expect(seen, contains('Netflix ₹649'));
    expect(seen, contains('"ACTION:"'));
    expect(seen,
        contains('<start_of_turn>model\nEarlier coach reply<end_of_turn>'));
    expect(seen,
        contains('<start_of_turn>user\nWhat about groceries?<end_of_turn>'));
    expect(seen, contains('<start_of_turn>user\nAnd subscriptions?'));
    expect(seen, isNot(contains('Coach:')));
    expect(seen, isNot(contains('User says:')));
  });

  test('drops oldest history turns to fit budget, keeps newest', () async {
    final filler = 'x' * 200;
    final history = <ChatTurn>[
      for (var i = 0; i < 50; i++)
        ChatTurn(isUser: i.isEven, text: 'turn$i $filler'),
    ];
    String? seen;
    await _run(
      facts: facts,
      history: history,
      userMessage: 'latest question',
      inferStream: (p) {
        seen = p;
        return _charStream('ok');
      },
    );
    expect(seen, isNot(contains('turn0 ')));
    expect(seen, contains('turn49 '));
    expect(seen, contains('Netflix ₹649'));
    expect(seen, contains('latest question'));
    expect(seen!.length, lessThan(4000));
  });

  // --- Incremental safe-reveal behavior ---

  test('reveals text immediately, growing with each chunk', () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Cut back on takeout.'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    expect(texts, isNotEmpty);
    for (var i = 1; i < texts.length; i++) {
      expect(texts[i].length, greaterThanOrEqualTo(texts[i - 1].length));
    }
    expect(texts.last, 'Cut back on takeout.');
  });

  test('withholds an ambiguous ACTION prefix until it resolves', () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Spend less. ACTION: cut coffee'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    for (final t in texts) {
      expect(t, isNot(contains('ACTI')));
    }
    expect(texts.last, 'Spend less.');
  });

  test('reveals a near-match that turns out not to be a marker', () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Actually you are doing fine.'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    expect(texts.last, 'Actually you are doing fine.');
  });

  test('stops listening once a stop marker resolves', () async {
    var pulled = 0;
    Stream<String> chars() async* {
      for (final ch in 'Nice month!<end_of_turn>MORE'.split('')) {
        pulled++;
        yield ch;
      }
    }

    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => chars(),
    ).toList();

    expect((events.last as ChatStreamDone).reply!.text, 'Nice month!');
    // The generator was cancelled once <end_of_turn> resolved — it never
    // got to yield the trailing "MORE".
    expect(pulled, lessThan('Nice month!<end_of_turn>MORE'.length));
  });

  test('holds back leading Coach: label while streaming, not just at the end',
      () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Coach: Groceries drive your spend.'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    for (final t in texts) {
      expect(t.toLowerCase(), isNot(contains('coach')));
    }
    expect(texts.last, 'Groceries drive your spend.');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/ai/chat_adapter_test.dart`
Expected: compile error — `generateStream`, `ChatStreamEvent`, `ChatStreamText`, `ChatStreamDone`, `InferStreamFn` are not defined yet (the old `generate()`/`InferFn` are still in `lib/ai/chat_adapter.dart`).

- [ ] **Step 3: Replace `lib/ai/chat_adapter.dart`**

Replace the full contents of `lib/ai/chat_adapter.dart` with:

```dart
/// One prior exchange in the ephemeral insight chat, oldest first.
class ChatTurn {
  final bool isUser;
  final String text;
  const ChatTurn({required this.isUser, required this.text});
}

/// A parsed model reply. [text] is the conversational part (may be empty
/// when the whole reply was an action); [actionText] is the concrete saving
/// suggestion split out from an "ACTION:" marker anywhere in the reply.
class ChatReply {
  final String text;
  final String? actionText;
  const ChatReply({required this.text, this.actionText});

  bool get isSuggestion => actionText != null;
}

/// Produces a stream of raw model token deltas for [prompt], as
/// [AiService.inferStream] does.
typedef InferStreamFn = Stream<String> Function(String prompt);

/// Events emitted by [ChatAdapter.generateStream], oldest first, always
/// terminated by exactly one [ChatStreamDone].
sealed class ChatStreamEvent {}

/// The growing, marker-safe prefix of the reply's conversational text. Each
/// event's [text] is a superset of the previous event's — safe to render
/// directly, it never shrinks or exposes a partial marker (the one
/// exception is a single trailing-whitespace trim the instant a marker
/// resolves, matching the final parsed text).
class ChatStreamText extends ChatStreamEvent {
  final String text;
  ChatStreamText(this.text);
}

/// Terminal event. [reply] is null when the model produced nothing usable
/// or inference failed — caller shows an error bubble with retry.
class ChatStreamDone extends ChatStreamEvent {
  final ChatReply? reply;
  ChatStreamDone(this.reply);
}

class ChatAdapter {
  ChatAdapter._();

  static const _marker = 'action:';
  static const _coachLabel = 'coach:';

  /// ~700 tokens at ~4 chars/token for the facts + history + message block.
  /// The model context is 1024; this leaves room for the rule text and the
  /// reply.
  static const _charBudget = 2800;

  /// The model tends to continue the dialogue past its own turn; anything
  /// after these markers is hallucinated conversation, not the reply. Only
  /// these — not [_marker] — signal the reply itself has ended.
  static const _stopMarkers = [
    '<end_of_turn>',
    '<start_of_turn>',
    '\nUser:',
    '\nCoach:',
  ];

  /// Strings watched for partial-match hold-back at the tail of the safe
  /// prefix, so a marker never flashes on screen mid-character.
  static final _watchStrings = [..._stopMarkers, _marker];

  /// Runs one chat turn as a stream of events: zero or more [ChatStreamText]
  /// (a growing, marker-safe prefix of the reply) followed by exactly one
  /// [ChatStreamDone]. Rebuilds the full prompt every call (stateless —
  /// AiService uses one session per inference) in Gemma's multi-turn format,
  /// so the model never sees name labels it could echo back.
  static Stream<ChatStreamEvent> generateStream({
    required List<String> facts,
    required List<ChatTurn> history,
    required String userMessage,
    required InferStreamFn inferStream,
  }) async* {
    final prompt = _buildPrompt(
      facts: facts,
      history: history,
      userMessage: userMessage,
    );

    final buffer = StringBuffer();
    var lastVisible = '';
    ChatReply? reply;
    try {
      await for (final chunk in inferStream(prompt)) {
        buffer.write(chunk);
        final raw = buffer.toString();
        final seen = _visibleFrom(raw);
        if (seen.visible != lastVisible) {
          lastVisible = seen.visible;
          yield ChatStreamText(lastVisible);
        }
        if (seen.complete) {
          reply = _parse(raw);
          break;
        }
      }
      reply ??= _parse(buffer.toString());
    } catch (_) {
      reply = null;
    }
    yield ChatStreamDone(reply);
  }

  static String _buildPrompt({
    required List<String> facts,
    required List<ChatTurn> history,
    required String userMessage,
  }) {
    final factBlock = facts.map((f) => '- $f').join('\n');

    // Drop oldest turns until facts + history + message fit the budget.
    final kept = List<ChatTurn>.from(history);
    int turnsLength() => kept.fold(0, (s, t) => s + t.text.length);
    while (kept.isNotEmpty &&
        factBlock.length + turnsLength() + userMessage.length > _charBudget) {
      kept.removeAt(0);
    }

    final prompt = StringBuffer()
      ..write('<start_of_turn>user\n')
      ..write('You are a personal finance coach chatting with the user. '
          "User's spending facts:\n"
          '$factBlock\n'
          'Rules: Speak directly to the user in plain sentences — never '
          'start your reply with a name or label. Max 3 sentences. Cite '
          'exact amounts from the facts. If you recommend one concrete '
          'saving action, put it on a final line starting with "ACTION:". '
          'If you need more info, just ask a question instead.\n');
    if (kept.isEmpty) {
      prompt.write('$userMessage\n<end_of_turn>\n<start_of_turn>model\n');
    } else {
      prompt.write('<end_of_turn>\n');
      for (final t in kept) {
        prompt.write('<start_of_turn>${t.isUser ? 'user' : 'model'}\n'
            '${t.text}<end_of_turn>\n');
      }
      prompt.write('<start_of_turn>user\n$userMessage\n<end_of_turn>\n'
          '<start_of_turn>model\n');
    }
    return prompt.toString();
  }

  /// Safe-to-render visible text for the raw buffer accumulated so far, and
  /// whether the reply itself is now known-complete (a stop marker fully
  /// matched, so anything further is hallucinated continuation — safe to
  /// stop listening). [_marker] ("action:") caps how far [visible] grows
  /// but does *not* mark completion — the action body keeps streaming in
  /// after it.
  static ({String visible, bool complete}) _visibleFrom(String raw) {
    final t = raw.trimLeft();
    final lower = t.toLowerCase();
    var start = 0;
    if (lower.startsWith(_coachLabel)) {
      start = _coachLabel.length;
      while (start < t.length && t[start] == ' ') {
        start++;
      }
    } else if (_coachLabel.startsWith(lower)) {
      // Buffer so far is a strict prefix of "coach:" — could still become
      // the echoed label. Nothing safe to show yet.
      return (visible: '', complete: false);
    }

    final rest = t.substring(start);
    var stopCut = rest.length;
    for (final stop in _stopMarkers) {
      final i = rest.indexOf(stop);
      if (i != -1 && i < stopCut) stopCut = i;
    }
    final actionIdx = rest.toLowerCase().indexOf(_marker);
    final cut = actionIdx != -1 && actionIdx < stopCut ? actionIdx : stopCut;

    final region = rest.substring(0, cut);
    final hold = _holdback(region);
    final visible = region.substring(0, region.length - hold);

    // Once cut is pinned by either kind of marker, region can never grow
    // again — safe to trim trailing whitespace to match the final parse.
    final frozen = cut < rest.length;
    final complete = stopCut < rest.length;
    return (
      visible: frozen ? visible.trimRight() : visible,
      complete: complete,
    );
  }

  /// Longest suffix of [region] that is a strict prefix of any watched
  /// marker string — withheld because it might still grow into a full
  /// match on the next chunk.
  static int _holdback(String region) {
    var hold = 0;
    for (final watch in _watchStrings) {
      final caseSensitive = watch != _marker;
      final hay = caseSensitive ? region : region.toLowerCase();
      final needle = caseSensitive ? watch : watch.toLowerCase();
      final maxLen = (needle.length - 1).clamp(0, hay.length);
      for (var k = maxLen; k > hold; k--) {
        if (hay.substring(hay.length - k) == needle.substring(0, k)) {
          hold = k;
          break;
        }
      }
    }
    return hold;
  }

  static ChatReply? _parse(String raw) {
    var text = raw.trim();

    for (final stop in _stopMarkers) {
      final i = text.indexOf(stop);
      if (i != -1) text = text.substring(0, i).trim();
    }

    // Strip an echoed leading speaker label.
    if (text.toLowerCase().startsWith(_coachLabel)) {
      text = text.substring(_coachLabel.length).trim();
    }

    // Split out the ACTION suggestion wherever it appears. toLowerCase is
    // length-preserving here, so the index maps back onto the original.
    final idx = text.toLowerCase().indexOf(_marker);
    String? actionText;
    if (idx != -1) {
      final body = text.substring(idx + _marker.length).trim();
      actionText = body.isEmpty ? null : body;
      text = text.substring(0, idx).trim();
    }

    if (text.isEmpty && actionText == null) return null;
    return ChatReply(text: text, actionText: actionText);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/ai/chat_adapter_test.dart`
Expected: all tests pass (`+21: All tests passed!` or similar — 15 ported + 6 new).

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze lib/ai/chat_adapter.dart test/ai/chat_adapter_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/ai/chat_adapter.dart test/ai/chat_adapter_test.dart
git commit -m "feat: stream chat replies with marker-safe incremental reveal"
```

---

### Task 3: Streaming animations in InsightChatScreen

**Files:**
- Modify: `lib/screens/insight_chat_screen.dart`

**Interfaces:**
- Consumes: `AiService.instance.inferStream(String, {double temperature, int maxTokens})` (Task 1), `ChatAdapter.generateStream(...)`, `ChatStreamEvent`/`ChatStreamText`/`ChatStreamDone`, `ChatTurn`, `ChatReply` (Task 2).
- Produces: no new public interface — this is the leaf UI consumer.

No new automated tests — this is UI polish with no existing widget-test coverage for this screen (verified manually, per the design spec).

- [ ] **Step 1: Replace `lib/screens/insight_chat_screen.dart`**

Replace the full contents of `lib/screens/insight_chat_screen.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Concrete saving suggestion parsed out of the reply; rendered as a
  /// separate save chip under the conversational text.
  final String? actionText;
  final bool isError;

  const _ChatMessage({
    required this.isUser,
    required this.text,
    this.actionText,
    this.isError = false,
  });
}

/// Where the in-flight reply is: not generating, waiting for the first
/// token (dots), or actively revealing streamed text.
enum _Phase { idle, thinking, streaming }

class _InsightChatScreenState extends State<InsightChatScreen> {
  final _messages = <_ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  _Phase _phase = _Phase.idle;
  String? _lastUserMessage;

  // Typewriter reveal: the model-safe text known so far ([_targetText]) vs.
  // what's currently on screen ([_displayedText]); a ticker advances the
  // latter toward the former at a capped, catch-up-aware pace.
  String _targetText = '';
  String _displayedText = '';
  Timer? _revealTimer;
  StreamSubscription<ChatStreamEvent>? _streamSub;

  static const _tick = Duration(milliseconds: 16);
  static const _baseCharsPerSecond = 40.0;
  static const _catchUpBacklogChars = 60;
  static const _catchUpDurationMs = 500;

  @override
  void initState() {
    super.initState();
    // The tapped insight opens the conversation. Not saveable — it is the
    // insight itself, not a suggestion.
    _messages.add(_ChatMessage(isUser: false, text: widget.insightText));
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _revealTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// History for the prompt. Recombines a parsed-out action with its text so
  /// the model sees its own prior suggestions in the format it produced them.
  List<ChatTurn> get _historyForModel => [
        for (final m in _messages)
          if (!m.isError)
            ChatTurn(
              isUser: m.isUser,
              text: m.actionText == null
                  ? m.text
                  : m.text.isEmpty
                      ? 'ACTION: ${m.actionText}'
                      : '${m.text}\nACTION: ${m.actionText}',
            ),
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

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _phase != _Phase.idle) return;
    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
    });
    _generate(text);
  }

  /// Re-runs generation for the last user message after an error bubble.
  void _retry() {
    final text = _lastUserMessage;
    if (text == null || _phase != _Phase.idle) return;
    setState(() {
      _messages.removeWhere((m) => m.isError);
    });
    _generate(text);
  }

  void _generate(String userMessage) {
    _lastUserMessage = userMessage;
    // History for the model excludes the message being answered — it goes
    // into the prompt's final user turn instead.
    final turns = _historyForModel;
    final history = turns.sublist(0, turns.length - 1);

    setState(() {
      _phase = _Phase.thinking;
      _targetText = '';
      _displayedText = '';
    });
    _scrollToBottom();

    final stream = ChatAdapter.generateStream(
      facts: widget.factLines,
      history: history,
      userMessage: userMessage,
      inferStream: (p) =>
          AiService.instance.inferStream(p, temperature: 0.4, maxTokens: 150),
    );

    _streamSub = stream.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ChatStreamText(:final text):
          setState(() {
            if (_phase == _Phase.thinking) _phase = _Phase.streaming;
            _targetText = text;
          });
          _revealTimer ??= Timer.periodic(_tick, _onRevealTick);
          _scrollToBottom();
        case ChatStreamDone(:final reply):
          _revealTimer?.cancel();
          _revealTimer = null;
          setState(() {
            _phase = _Phase.idle;
            _messages.add(reply == null
                ? const _ChatMessage(
                    isUser: false,
                    text: "Couldn't think of a reply. Try again.",
                    isError: true,
                  )
                : _ChatMessage(
                    isUser: false,
                    text: reply.text,
                    actionText: reply.actionText,
                  ));
          });
          _scrollToBottom();
      }
    });
  }

  void _onRevealTick(Timer t) {
    if (_displayedText.length >= _targetText.length) return;
    final backlog = _targetText.length - _displayedText.length;
    final charsPerSecond = backlog > _catchUpBacklogChars
        ? backlog * 1000 / _catchUpDurationMs
        : _baseCharsPerSecond;
    final charsThisTick =
        (charsPerSecond * _tick.inMilliseconds / 1000).ceil().clamp(1, backlog);
    setState(() {
      _displayedText =
          _targetText.substring(0, _displayedText.length + charsThisTick);
    });
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
                itemCount: _messages.length + (_phase == _Phase.idle ? 0 : 1),
                itemBuilder: (context, i) {
                  if (i == _messages.length) {
                    return _phase == _Phase.thinking || _displayedText.isEmpty
                        ? const _ThinkingDots()
                        : _StreamingBubble(text: _displayedText);
                  }
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
              inputFormatters: [LengthLimitingTextInputFormatter(400)],
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
            onPressed: _phase == _Phase.idle ? _send : null,
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
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  color: isUser
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            if (message.actionText != null) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              _ActionChip(text: message.actionText!),
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

/// The parsed ACTION suggestion as its own tappable element: shows the
/// action text with a save affordance; tapping anywhere on it saves.
class _ActionChip extends StatelessWidget {
  final String text;

  const _ActionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestedActionsProvider>();
    final saved = provider.contains(text);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: saved
          ? null
          : () => context.read<SuggestedActionsProvider>().add(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: saved
              ? scheme.surfaceContainerHigh
              : scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: saved
                ? scheme.outlineVariant.withValues(alpha: 0.5)
                : scheme.primary.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              saved ? LucideIcons.check : LucideIcons.bookmarkPlus,
              size: 14,
              color: saved ? scheme.onSurfaceVariant : scheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: saved ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              saved ? 'Saved ✓' : 'Save',
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

/// Live preview of the reply while it's still streaming in: same shape as
/// a non-user [_MessageBubble] but no action chip or retry affordance —
/// those only make sense once the reply is finalized.
class _StreamingBubble extends StatelessWidget {
  final String text;

  const _StreamingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Bouncing 3-dot "typing" indicator shown while waiting for the first
/// token of a reply.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Stagger each dot by a third of the cycle; bounce via a
                // triangle wave so the motion eases up and back down.
                final t = (_controller.value + i / 3) % 1.0;
                final bounce = (t < 0.5 ? t : 1 - t) * 2; // 0..1..0
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -4 * bounce),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze lib/screens/insight_chat_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite to confirm no regressions**

Run: `flutter test`
Expected: all tests pass (no test targets this screen directly, so this only guards against accidental breakage elsewhere).

- [ ] **Step 4: Manual verification**

Run the app (`flutter run -d chrome` or a connected device) and open Insight Chat from a weekly insight. Verify:
- Sending a message shows 3 bouncing dots (no "Thinking…" text) until the first safe token arrives.
- Reply text grows smoothly, character by character, without any `<end_of_turn>`, `ACTION:`, or `Coach:` fragment ever flashing on screen.
- If the reply includes a save suggestion, the ACTION chip only appears after the text finishes streaming in, not before.
- If the reply is action-only (no conversational text), dots stay visible until the chip appears — no empty bubble flashes.
- The message list auto-scrolls to keep the growing bubble visible.
- Triggering an error path (e.g. temporarily force a throw in `inferStream`, or turn off airplane-mode/model to hit the model-not-initialized `StateError`) still shows the error bubble with a working Retry.
- Popping the screen while a reply is mid-stream does not crash or throw in the console (dispose cancels cleanly).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/insight_chat_screen.dart
git commit -m "feat: animate insight chat with typing dots and typewriter reveal"
```
