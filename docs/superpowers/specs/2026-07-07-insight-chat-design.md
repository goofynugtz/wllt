# Insight Chat + Suggested Actions — Design

Date: 2026-07-07
Status: Approved (pending user spec review)

## Summary

Tapping the AI weekly insight card on the home screen opens a chat page where
the user talks to the on-device LLM (Gemma 3 1B via flutter_gemma) about their
spending, seeded with the same pre-computed facts that generated the insight.
Assistant replies that contain a concrete saving suggestion carry a
"Save as action" button; saved items form a persistent, device-local
"Suggested Actions" checklist rendered as a card on the home screen.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| How suggestions get saved | Save button on assistant bubbles, shown only on messages that are actual suggestions (LLM may also ask clarifying questions — those get no button) |
| Where checklist lives | Card on home screen, below the AI insight row |
| Checked-item lifecycle | Strikethrough, stays in place; X to dismiss (permanent delete); card hides when list empty |
| Chat persistence | Ephemeral per visit — fresh chat each open; saved actions are the durable output |
| Gating | Insight card tappable only when `AiProvider.isReady` (mobile + Pro + model loaded). Web / non-Pro / AI-off: card stays a plain display card as today |
| Architecture | Approach A: stateless prompt rebuild per turn via existing `AiService.infer`; suggestion detection via `ACTION:` marker prefix the model is instructed to emit |

## Constraints

- Gemma 3 1B int4, MediaPipe LlmInference. Model currently loaded with
  `maxTokens: 512` (total context); this design raises it to 1024.
- `AiService.infer` creates and closes a session per call — chat rebuilds the
  full prompt every turn (facts + trimmed history + new message).
- 10 s inference timeout already enforced in `AiService.infer`.
- Web build has no local model (`gemma_web.dart` stub) — chat is mobile-only.
- No cloud sync for actions — checklist is device-only (Hive).

## New files

### `lib/ai/chat_adapter.dart`
Pure adapter, same shape as `InsightAdapter`/`SummaryAdapter` (injected
`InferFn`, no service imports).

```dart
class ChatReply {
  final String text;         // conversational part; may be empty
  final String? actionText;  // ACTION suggestion parsed from anywhere in reply
  bool get isSuggestion;     // actionText != null
}

class ChatAdapter {
  static Future<ChatReply?> generate({
    required List<String> facts,          // InsightFacts.factLines
    required List<ChatTurn> history,      // prior turns, oldest first
    required String userMessage,
    required InferFn infer,
  });
}
```

Prompt (Gemma **multi-turn** format, rebuilt every send — no "User:"/"Coach:"
name labels anywhere, so the 1B model has nothing to echo back):

```
<start_of_turn>user
You are a personal finance coach chatting with the user. User's spending facts:
- <fact lines>
Rules: Speak directly to the user in plain sentences — never start your
reply with a name or label. Max 3 sentences. Cite exact amounts from the
facts. If you recommend one concrete saving action, put it on a final line
starting with "ACTION:". If you need more info, just ask a question instead.
<end_of_turn>
<start_of_turn>model|user   ← trimmed history as real alternating turns
<turn text><end_of_turn>
…
<start_of_turn>user
<userMessage>
<end_of_turn>
<start_of_turn>model
```

- `infer` called with `temperature: 0.4, maxTokens: 150`.
- History trimming: char-count heuristic (~4 chars/token), drop oldest turns
  until facts + history + message fit ~700-token budget.
- Reply parse (in order): truncate at hallucinated turn tokens or
  `User:`/`Coach:` dialogue continuations → strip an echoed leading
  `Coach:` label → split at case-insensitive `action:` **anywhere** in the
  reply: text before = conversational bubble, text after = `actionText`
  rendered as a separate save chip. Both empty or exception → `null`
  (caller shows error bubble).

### `lib/models/suggested_action.dart`

```dart
class SuggestedAction {
  final String id;        // millisecondsSinceEpoch as string
  final String text;
  final DateTime createdAt;
  final bool done;
  // toJson/fromJson — stored as JSON string in Hive
}
```

### `lib/providers/suggested_actions_provider.dart`
`ChangeNotifier` over Hive box `suggested_actions` (String box, one JSON per
action keyed by id). API: `List<SuggestedAction> get actions`,
`add(String text)` (no-op when identical text already exists — dedupe),
`toggleDone(String id)`, `remove(String id)`, `bool contains(String text)`.
Box opened lazily on first use (same pattern as `ai_cache`). Registered in
`main.dart`.

### `lib/screens/insight_chat_screen.dart`
Constructor: `InsightChatScreen({required String insightText, required
List<String> factLines})`.

- AppBar: "Insight Chat".
- Message list: assistant bubbles left (surfaceContainerHighest, like insight
  card), user bubbles right (primaryContainer). First assistant bubble = the
  weekly insight text (no save button — it is the insight, not a suggestion).
- Suggestion bubbles: "Save as action" button under text → on tap writes via
  provider, flips to disabled "Saved ✓". If identical text already saved,
  renders "Saved ✓" from the start (`provider.contains`).
- Input row pinned at bottom; send button disabled while generating; animated
  "thinking…" assistant bubble during inference.
- State is screen-local only (ephemeral chat) — pop discards everything.

### `lib/widgets/suggested_actions_card.dart`
Home-screen card, `_SectionCard` visual style, 20 px side margins, title
"Suggested Actions" + clipboard-check icon.

- Row per action: checkbox + text. Checked → strikethrough + muted color +
  X button (dismiss = `remove`). Unchecked sorted newest first; checked sink
  to bottom.
- Card renders on all platforms (data is local); hidden entirely when list
  empty.

## Changed files

- `lib/screens/home_screen.dart`
  - `_AiInsightCard` (weekly insight, non-demo) wrapped in tap handler when
    `context.watch<AiProvider>().isReady` && `!kIsWeb` && a real generated
    insight exists (`_aiInsights.isNotEmpty`; the dev-mode placeholder row
    "No AI insight for this period…" is never tappable): pushes
    `InsightChatScreen` with current insight text + freshly computed
    `InsightFacts.compute(...).factLines` (same inputs as generation:
    all transactions, `asOf: DateTime.now()`, current currency symbol,
    budget limits).
  - `SuggestedActionsCard` rendered below the AI insight row.
- `lib/main.dart` — register `SuggestedActionsProvider`.
- `lib/services/ai_service.dart` — `getActiveModel(maxTokens: 512)` → `1024`
  (chat prompt + 150-token replies need headroom; summary/insight paths
  unaffected).

## Error handling

- `ChatAdapter.generate` returns `null` (inference threw / timed out / empty):
  assistant error bubble "Couldn't think of a reply. Try again." with a retry
  affordance that re-sends the last user message.
- Screen popped mid-inference: result discarded via `mounted` check.
- Model disabled while chat open: next send fails → same error bubble. Entry
  gating (`isReady`) prevents new sessions.
- Marker misformatted by the 1B model: reply renders as plain bubble without
  save button — accepted failure mode (user can still read the advice).

## Testing

Existing patterns: fake `InferFn` (`test/ai/insight_adapter_test.dart`),
temp-dir Hive (`test/services/storage_service_ai_test.dart`).

- `test/ai/chat_adapter_test.dart`
  - `ACTION: cancel Netflix` → text stripped, `isSuggestion: true`
  - lowercase/mixed-case marker accepted
  - no marker → `isSuggestion: false`
  - empty reply / throwing infer → `null`
  - long history → oldest turns dropped, prompt within budget, facts and
    newest turn always present
- `test/providers/suggested_actions_provider_test.dart`
  - add / toggleDone / remove
  - duplicate text add is a no-op
  - actions survive provider re-instantiation (persistence)

## Out of scope

- Cloud/Firestore sync of actions (device-only by decision)
- Web chat (no local model)
- Persisting chat history
- Notifications/reminders for actions
- Monthly-summary card tap (weekly insight card only)
