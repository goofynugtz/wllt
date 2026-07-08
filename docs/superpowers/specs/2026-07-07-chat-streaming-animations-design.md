# Chat streaming animations — design

## Problem

`InsightChatScreen` waits for the full model reply before showing anything: a
static "Thinking…" fade bubble, then the whole message appears at once.
`flutter_gemma` 0.16.1 exposes real token streaming
(`InferenceModelSession.getResponseAsync() → Stream<String>`, delta chunks),
which `AiService`/`ChatAdapter` don't use yet. This adds a bouncing-dots
typing indicator and a real-time, typewriter-paced reveal of the reply as
tokens arrive.

## Architecture

```
AiService.inferStream()      → Stream<String>            (raw token deltas)
        ↓
ChatAdapter.generateStream() → Stream<ChatStreamEvent>
    - ChatStreamText(safeText)     // growing marker-safe prefix
    - ChatStreamDone(ChatReply?)   // final parsed result
        ↓
InsightChatScreen: dots bubble → streaming bubble (catch-up typewriter) → final bubble
```

Per turn: user sends → dots bubble (bouncing, no label) until the first token
arrives → dots swap to a streaming bubble whose text grows in typewriter
cadence → on `ChatStreamDone`, the bubble snaps to the final parsed text,
fades in the ACTION chip if present, and becomes a normal `_MessageBubble`.
Errors produce the same error bubble + retry affordance as today.

## AiService

Add:

```dart
Stream<String> inferStream(String prompt, {double temperature = 0.1, int maxTokens = 60})
```

Mirrors `infer()`: creates a session, `addQueryChunk`, then
`yield* session.getResponseAsync()`, closing the session in a `finally`
block. Dart runs `finally` in an `async*` generator both on natural
completion and on subscription cancellation, so popping the chat screen
mid-stream still closes the session (no leak).

Timeout: `.timeout(const Duration(seconds: 10))` applied to the stream. This
is a per-chunk idle timeout (resets on every emitted chunk), unlike today's
single 10s cap on the whole `infer()` future — a live-but-slow generation no
longer needs to fit in 10s total, only each gap between tokens does.

`infer()` is unchanged; `insight_adapter.dart` and `summary_adapter.dart`
keep using it as-is.

`lib/platform/gemma_web.dart` (web stub) gets a matching no-op:

```dart
Stream<String> getResponseAsync() async* {}
```

## ChatAdapter

Prompt-building is extracted from the current `generate()` into a shared
private helper (facts block, history trimming to `_charBudget`, Gemma
multi-turn formatting — logic unchanged).

New public surface:

```dart
typedef InferStreamFn = Stream<String> Function(String prompt);

sealed class ChatStreamEvent {}
class ChatStreamText extends ChatStreamEvent {
  final String text; // growing, marker-safe prefix
  ChatStreamText(this.text);
}
class ChatStreamDone extends ChatStreamEvent {
  final ChatReply? reply; // null on empty/failed reply, same contract as today
  ChatStreamDone(this.reply);
}

Stream<ChatStreamEvent> generateStream({
  required List<String> facts,
  required List<ChatTurn> history,
  required String userMessage,
  required InferStreamFn inferStream,
});
```

This **replaces** `generate()` (its only caller, `InsightChatScreen`, moves
to the streaming API — no dual code path).

### Incremental safe-reveal

As raw chunks arrive they're appended to a buffer. On each chunk, the
"safe" prefix length is recomputed:

- **Full marker match** — if the buffer contains a full stop marker
  (`<end_of_turn>`, `<start_of_turn>`, `\nUser:`, `\nCoach:`) *or* the
  `action:` marker, everything from that point on is never part of the
  visible conversational text — the safe prefix freezes there. Only a
  **stop marker** means the reply itself is known-complete (nothing after
  it is real): that cancels the underlying `inferStream` subscription
  immediately. The `action:` marker does *not* end the stream — the action
  body keeps streaming in after it (invisibly, until finalization); it only
  caps how far the visible conversational text grows.
- **Partial match hold-back** — if the tail of the buffer is a prefix of
  any watched string (e.g. buffer ends in `<end_of`, or `acti`, or — at the
  very start of the reply only — `coa`), those trailing characters are
  withheld from the safe prefix until they either resolve into a full match
  (handled above) or diverge (become safe to reveal).
- **Leading `coach:` strip** — applies only while the buffer so far is a
  prefix of `coach:` and at position 0, matching `_parse`'s existing
  startsWith-only behavior (mid-reply "coach:" text is never stripped).
- A `ChatStreamText` event is emitted only when the safe prefix has grown
  since the last emission.

On early-cancel (full marker matched), natural stream completion, or an
error/timeout from `inferStream`, `generateStream` finalizes by calling the
existing, already-tested `_parse` on the complete raw buffer and emits a
single terminal `ChatStreamDone(reply)`. The incremental logic only controls
what is *shown* while streaming — correctness of the final result always
comes from `_parse`, unchanged.

## UI (`InsightChatScreen`)

- `_generating bool` becomes a 3-state phase: `idle` / `thinking` /
  `streaming`.
- `_ThinkingBubble` is replaced by a bouncing 3-dot indicator (staggered
  vertical bounce per dot, no text label), shown during `thinking` (before
  the first token).
- New `_StreamingBubble`, shown during `streaming`: holds `_targetText`
  (latest `ChatStreamText.text`) and `_displayedText`. A
  `Timer.periodic(~16ms)` advances `_displayedText` toward `_targetText` at
  a ~40 chars/sec baseline cadence; if the backlog
  (`_targetText.length - _displayedText.length`) exceeds ~60 characters, the
  reveal rate increases proportionally so the display never lags generation
  by more than ~0.5s. No trailing cursor.
- On `ChatStreamDone`: ticker stops, `_displayedText` snaps to the final
  `reply.text`, and the message is appended to `_messages` as today (normal
  `_MessageBubble`, ACTION chip fades in via existing chip widget).
- `dispose()` cancels both the stream subscription and the reveal ticker.
- Error path unchanged: `ChatStreamDone(null)` → error bubble with retry;
  retry re-invokes `generateStream`.

## Testing

- `test/ai/chat_adapter_test.dart`: the 12 existing cases are ported to
  drive `generateStream` with a fake `InferStreamFn` (emits a scripted list
  of chunks), asserting on the terminal `ChatStreamDone.reply` — same
  coverage as today's `generate()` tests.
- New cases: safe text withheld while the buffer tail is an ambiguous
  marker prefix (e.g. ends in `<end_of`); safe text revealed once a
  near-match diverges and turns out not to be a marker; stream is cancelled
  early once a stop marker fully resolves; leading `coach:` is held back
  then stripped from the streamed text (not just the final parse).
- `AiService.inferStream` is not unit-testable in isolation (native FFI),
  same as the existing `infer()` — verified manually in the running app.
- UI is verified manually: dots → streaming → final bubble, catch-up
  behavior on bursty token arrival, error + retry, and screen-pop
  mid-stream (no leak/crash).
