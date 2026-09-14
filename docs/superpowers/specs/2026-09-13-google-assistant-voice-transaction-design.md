# Google Assistant Voice-to-Transaction — Design Spec

**Date:** 2026-09-13
**Scope:** Sub-project 1 of 2 (Alexa integration is a separate future spec — different stack entirely: cloud skill + Lambda/webhook + OAuth account linking, vs. this being purely on-device). Android only.

---

## Context

User asks: speak a purchase, have it land as a transaction. Two platform realities shaped this:

1. **No third-party Assistant NLU exists for this.** Google retired Conversational Actions in 2023; the remaining Built-in Intent (BII) catalog has nothing for expense logging. So Assistant cannot itself parse "I spent 200 on coffee" into structured fields — no API surface for that.
2. **The buildable version:** an Android App Shortcut voice-triggers a deep link that opens the app directly into a listening mic UI; the app's own STT + parser does the extraction and saves. This is what every finance app's "Assistant integration" actually is today.

The app already has a *fake* version of the in-app half of this: `VoiceInputForm` in `lib/widgets/add_expense_sheet.dart:1535` — hardcoded transcript, hardcoded parsed chips, `Confirm & Save` calls only `Navigator.pop()` (never saves). It's dead code — not instantiated anywhere, not reachable in the live app. This spec wires it for real and adds the Assistant-triggered entry path on top.

---

## Components

### 1. `VoiceCaptureService` (new — `lib/services/voice_capture_service.dart`)

Wraps `speech_to_text` (new dep). Requests `RECORD_AUDIO` via existing `permission_handler` dep. Exposes `Future<bool> start({required void Function(String) onResult})` / `stop()`. Permission denial and "no speech detected" are reported through the same callback path as a null/empty result — no separate error channel, `VoiceInputForm` already has stages for idle/listening/parsed and gains one more: `error`.

### 2. `PurchaseTranscriptParser` (new — `lib/services/purchase_transcript_parser.dart`)

Regex tiers, sibling to and reusing the amount-parsing helpers in `sms_parser.dart`. Patterns cover `"spent/paid <amount> on/at/for <merchant>"` and the reverse order. Returns `{amount, merchant}` or `null` if no amount match — amount is the only required field; no amount means no confident parse, full stop (surfaced as error stage, user retakes or backs out to manual entry).

v1 is expense-only — a spoken purchase is definitionally an expense; income/transfer via voice is out of scope (see Out of Scope).

### 3. `PurchaseTranscriptAdapter` (new — `lib/ai/purchase_transcript_adapter.dart`)

Gemma JSON-extraction fallback when regex returns `null`, modeled directly on the existing `SmsParserAdapter` (`lib/ai/sms_parser_adapter.dart`) — same `InferFn` signature, same prompt shape:

```
<start_of_turn>user
Extract a purchase from this spoken transcript as JSON.
Transcript: "..."
Reply with only: {"merchant":"...","amount":0.0}
Unknown fields use null.
<end_of_turn>
<start_of_turn>model
```

Same defensive parsing as `SmsParserAdapter.parse`: `jsonDecode`, bail to `null` on any throw or non-positive amount. No category/account in this prompt — see below.

### 4. Category resolution — reused, not reinvented

Once `{amount, merchant}` is in hand (from either tier), category resolves exactly like the SMS pipeline already does:
`SmsRulesEngine.categorize(merchant)` first (merchant-keyword lookup); if that misses and AI is available, `CategorizationAdapter.suggest(merchant: ..., availableCategories: ..., infer: aiInfer)`. If both miss, category stays unresolved — shown as an unselected category chip, same as today's unparsed-SMS UI. No new category-guessing logic anywhere.

Date is always `DateTime.now()` — voice entry logs an immediate purchase, never backdated. Account resolves the same way `ManualEntryForm` resolves a default account when none is explicitly picked.

### 5. `VoiceInputForm` — wired for real

Replace the `Future.delayed` simulation in `_startListening()`:
`VoiceCaptureService.start()` → transcript → `PurchaseTranscriptParser.parse()` → if `null`, `PurchaseTranscriptAdapter.parse()` (only when `aiInfer` available; otherwise straight to error stage) → category resolution (§4) → build `Transaction` → chips reflect real values, not hardcoded ones.

**Save behavior forks on entry point:**
- **Manual in-app mic tap** (user opened the sheet deliberately): keeps today's tap-through — `Confirm & Save` button, calls `context.read<TransactionProvider>().addTransaction(tx)`.
- **Assistant-triggered** (see §6): no button tap available — auto-saves immediately on successful parse via the same `addTransaction(tx)` call, then shows a save confirmation with an Undo action (calls `deleteTransaction`) instead of a confirm button. This is the "auto-commit" behavior agreed on; the Undo affordance is the safety net for a misheard amount/merchant.

### 6. Android App Shortcut + deep link (the Assistant glue)

- `android/app/src/main/res/xml/shortcuts.xml`: one static shortcut, short label "Add expense", intent → `MainActivity` with data URI `wllt://voice-add`. Declared via `<meta-data android:name="android.app.shortcuts">` in `AndroidManifest.xml`. This is what makes "Hey Google, add expense in wllt" (or a user-recorded Assistant Routine phrase mapped to the shortcut) work — no Actions-on-Google console submission, no review process; static App Shortcuts + Assistant is a stable, always-available mechanism.
- Manifest: add `RECORD_AUDIO` permission; add a `VIEW`/`BROWSABLE` intent-filter for the `wllt://voice-add` scheme so the deep link resolves even outside the shortcut path (e.g. a future widget or Routine action pointing at the URI directly).
- Flutter: add `app_links` (new dep) + a `GlobalKey<NavigatorState>` on `MaterialApp` (none exists today — `main.dart` currently has no navigator key). On receiving `wllt://voice-add` (cold or warm start), push `AddTransactionPage` pre-set to the voice tab and immediately invoke `_startListening()` — user speaks the instant the app appears, no extra tap.
- Not signed in when triggered → route to sign-in instead of the voice form; resume voice-add is out of scope for v1 (user re-triggers the shortcut after signing in).

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Mic permission denied | Error stage in `VoiceInputForm`: "Microphone access needed" + button to open app settings. |
| No speech detected / empty transcript | Error stage, "Didn't catch that" + retake. |
| Regex parse fails, no `aiInfer` available (AI not downloaded/ready) | Error stage, "Couldn't make that out" + retake or fall through to manual entry tab. |
| Regex fails, Gemma fallback also fails/throws | Same as above — `PurchaseTranscriptAdapter.parse` swallows and returns `null`, same contract as `SmsParserAdapter`. |
| Category unresolved | Not an error — transaction saves uncategorized, chip shown unselected, same as existing unparsed-SMS convention. |
| Assistant-triggered, not signed in | Redirect to sign-in, voice form not shown. |
| Assistant-triggered, save succeeds | Undo snackbar, N seconds, calls `deleteTransaction` on tap. |

AI is enhancement-only throughout, never blocking — identical guarantee to the existing SMS LLM fallback (`docs/superpowers/specs/2026-07-10-sms-llm-fallback-design.md`).

---

## Testing

- `test/services/purchase_transcript_parser_test.dart` — regex cases (amount-before-merchant, amount-after, no-amount-returns-null), mirroring `sms_parser.dart`'s existing test conventions.
- `test/ai/purchase_transcript_adapter_test.dart` — mocked `InferFn`: valid JSON, malformed JSON, non-positive amount, throwing infer — same shape as `sms_parser_adapter_test.dart`.
- **Not verifiable by automated test, real Android device required:** actual STT accuracy, `RECORD_AUDIO` permission flow, App Shortcut registration/voice trigger, deep-link cold-start routing. These will be called out as manually-verified, not claimed as tested, when implementation lands.

---

## Out of Scope

- Alexa integration — separate spec, separate stack (cloud skill, Lambda/webhook, OAuth account linking to Firebase Auth), no code overlap with this one beyond the shared `Transaction` model and `TransactionProvider.addTransaction`.
- Income/transfer via voice — v1 is expense-only; "spoke about a purchase" is the ask, a refund/income phrasing would need its own parser tier and wasn't asked for.
- iOS — Google Assistant App Actions/Shortcuts are an Android mechanism; no iOS equivalent path exists for this trigger.
- Resuming a pending voice-add after a forced sign-in detour.
- Multi-turn correction ("no, I meant 500 not 50") — retake-from-scratch only, matching the existing SMS pending-card UX (edit fields after the fact, not mid-parse).
