# Local LLM Integration — Design Spec

**Date:** 2026-05-23  
**Model:** Gemma 3 1B (via `flutter_gemma`)  
**Gate:** Premium / Family / Team plan only  
**Constraint:** Zero network calls during inference — fully on-device

---

## Overview

Embed an on-device LLM (Gemma 3 1B) as an opt-in premium feature. The LLM enhances existing flows — it never replaces deterministic logic, only handles cases deterministic approaches miss or supplements them with natural language output.

**Use cases:**
1. Smart categorization — suggest category when adding a transaction
2. SMS parsing fallback — when regex rules find no match
3. Monthly narrative summary — human-readable spending recap
4. Spending insights — periodic actionable tips (not financial advice)

**Voice command (Google Assistant → transaction)** is a future entry point into the same categorization pipeline — no separate LLM work needed.

---

## Architecture

```
UI (settings toggle, feature surfaces)
        ↓
AiProvider (ChangeNotifier) — model state, download progress, isPro gate
        ↓
AiService (singleton) — model lifecycle: download, init, raw inference
        ↓
flutter_gemma → Gemma 3 1B on-device
        ↓
Feature Adapters (stateless, pure Dart)
  ├── CategorizationAdapter
  ├── SmsParserAdapter
  ├── InsightAdapter
  └── SummaryAdapter
```

### AiService

Singleton (mirrors `ExchangeRateService` pattern). Responsibilities:
- Download model to app documents directory
- Initialize / re-initialize model weights
- Expose `infer(prompt) → Future<String>` — raw inference only
- Nothing feature-specific

### AiProvider

`ChangeNotifier`, added to `main.dart` provider tree. Exposes:
- `AiModelState` enum: `notDownloaded | downloading | ready | error`
- `downloadProgress` (0.0–1.0)
- `isEnabled` (persisted to Hive via `StorageService`)
- Always checks `SubscriptionProvider.isPro` before any action

### Feature Adapters

Pure Dart, stateless. Each adapter:
- Takes typed domain input
- Formats a prompt
- Calls `AiService.infer()`
- Validates and parses output
- Returns typed result or `null` on failure

Callers treat `null` as "AI unavailable" and fall back silently.

### New Files

```
lib/services/ai_service.dart
lib/providers/ai_provider.dart
lib/ai/categorization_adapter.dart
lib/ai/sms_parser_adapter.dart
lib/ai/insight_adapter.dart
lib/ai/summary_adapter.dart
lib/ai/feedback_store.dart
```

---

## Compute & Latency Framework

Gemma 3 1B (Q4): ~1–3s inference on mid-range Android, ~500ms flagship.

| Feature | Approach | LLM role | On critical path? |
|---|---|---|---|
| Smart categorization | Merchant lookup first | Fallback for unknown merchants | No — async suggestion |
| SMS parsing | Regex/rules first | Fallback for unmatched patterns | No — background |
| Monthly summary | — | Full generation, once/month | No — background |
| Insights | — | Weekly background generation | No — async |
| Anomaly nudge text | Math trigger | Template string (no LLM needed) | — |
| Voice command parsing | Google Assistant NLU | Same categorization pipeline | No |

**Rule:** LLM never blocks UI hot path. All inference runs in `compute()` isolate.

---

## Settings Integration

New **"Experimental Labs"** section in `settings_screen.dart`, between "Premium" and "Account & Data". Renders only when `subscription.isPro`.

### UI States

**Model not downloaded:**
```
EXPERIMENTAL LABS
┌──────────────────────────────────────────────┐
│ 🧪  AI Features                    [toggle] │
│     Gemma 3 1B · ~600 MB                    │
└──────────────────────────────────────────────┘
```

**Downloading:**
```
┌──────────────────────────────────────────────┐
│ 🧪  AI Features                [disabled]   │
│     Gemma 3 1B · ~600 MB                    │
├──────────────────────────────────────────────┤
│ 📥  Downloading…                      43%   │
│     Wi-Fi recommended                       │
└──────────────────────────────────────────────┘
```

**Ready:**
```
┌──────────────────────────────────────────────┐
│ 🧪  AI Features                    [toggle] │
│     Gemma 3 1B · ~600 MB                    │
├──────────────────────────────────────────────┤
│ 🤖  AI Model                         Ready  │
│     Running on-device                       │
└──────────────────────────────────────────────┘
```

### Toggle ON Flow

1. User taps toggle
2. Confirmation bottom sheet (matches app's sheet pattern):
   - Title: "Download AI Model (~600 MB)"
   - Body: "Runs fully on-device. No data leaves your phone. Wi-Fi recommended."
   - Actions: Cancel / Download
3. Confirm → `AiProvider.enableAndDownload()`
4. Toggle disabled (non-interactive) during download
5. Progress row appears, updates live
6. Success: state → `ready`
7. Failure: toast error, toggle resets to off

### Toggle OFF Flow

1. Confirmation bottom sheet: "Delete downloaded model? (~600 MB freed)"
2. Confirm → `AiProvider.disable()` → delete model file → state → `notDownloaded`

---

## Feature Integration Points

### 1. Smart Categorization — `add_expense_sheet.dart`

```
User types merchant name
    ↓ debounce 500ms
FeedbackStore lookup (user corrections) → hit? use it, done
    ↓ miss
Deterministic merchant→category map (~150 top Indian merchants) → hit? use it, done
    ↓ miss
CategorizationAdapter.suggest(merchant, availableCategories)
    ↓
AI-suggested category tile gets subtle pulse animation (glow ring, 1–2 cycles)
```

**Accept:** User taps the animated tile → normal selection, animation stops.

**Dismiss:** User taps any other tile → that tile selected AND:
```dart
FeedbackStore.recordCorrection(
  merchant: "Blue Tokai",
  aiSuggested: "coffee",
  userChose: "restaurant",
)
```

**FeedbackStore** — Hive box. Stores `merchant → correctCategory` correction map. Checked before AI on every subsequent call for that merchant. User never sees same wrong suggestion twice.

### 2. SMS Parsing Fallback — `SmsService` (future)

Deterministic regex runs first. On no match:
```dart
final result = await SmsParserAdapter.parse(rawSms);
// null → SMS logged as unparsed, user prompted manually
```

### 3. Monthly Summary — `home_screen.dart`

- Generated once per month, cached in Hive key `ai_summary_YYYY_MM`
- Triggered: first app open of new month, model `ready`
- Runs in `compute()` isolate
- Shown as collapsible card above recent transactions
- Input to adapter: category totals + income for the month (not raw transaction list)

### 4. Insights — `home_screen.dart`

- Generated weekly, cached in Hive key `ai_insights_YYYY_WW`
- Up to 3 insights stored, shown as horizontally scrollable cards
- Stale insights (>14 days) auto-cleared
- Input: 3 months category totals + budget limits (aggregated, not raw)

### Guard Pattern (used at every call site)

```dart
if (!aiProvider.isReady || !subscription.isPro) return;
```

---

## Prompt Design

All prompts use Gemma chat template (`<start_of_turn>user` / `<end_of_turn>`).  
All inference runs in `compute()` isolate.  
Prompts never include raw transaction lists — only aggregated totals (token efficiency + privacy).

### CategorizationAdapter

```
<start_of_turn>user
Classify this merchant into one category.
Merchant: "Blue Tokai"
Categories: shopping, restaurant, coffee, groceries, transport, utilities,
  movies, fitness, education, home, phone, gifts, travel, work, savings
Reply with only the category id.
<end_of_turn>
<start_of_turn>model
coffee
```

- temperature: `0.1`
- max_tokens: `10`
- Validate: output must match a known category ID, else return `null`

### SmsParserAdapter

```
<start_of_turn>user
Extract transaction from this SMS as JSON.
SMS: "Rs.349.00 debited from a/c XX4242 for UPI to ZOMATO. Bal: Rs.12,450"
Reply with only: {"merchant":"...","amount":0.0,"type":"debit|credit"}
Unknown fields use null.
<end_of_turn>
<start_of_turn>model
{"merchant":"Zomato","amount":349.0,"type":"debit"}
```

- temperature: `0.1`
- max_tokens: `60`
- Validate: JSON must parse + amount must be a positive number, else return `null`

### InsightAdapter

```
<start_of_turn>user
One actionable spending insight, max 2 sentences.
restaurant ₹4,200 (budget ₹3,000 +40%), groceries ₹2,800, shopping ₹6,200
Last month restaurant: ₹2,900
<end_of_turn>
<start_of_turn>model
Your restaurant spend is ₹1,200 over budget — 40% higher than last month...
```

- temperature: `0.4` (variety across weekly runs)
- max_tokens: `80`
- No structural validation — plain text, trim whitespace

### SummaryAdapter

```
<start_of_turn>user
2-3 sentence monthly spending summary.
April 2026 · Income ₹85,000
home ₹19,000 · groceries ₹4,570 · restaurant ₹3,410 · shopping ₹1,890 · utilities ₹1,750
Total spent: ₹31,914
<end_of_turn>
<start_of_turn>model
In April you spent ₹31,914 — 37% of income...
```

- temperature: `0.3`
- max_tokens: `120`

---

## Error Handling

### Download Errors

| Scenario | Behaviour |
|---|---|
| No internet | Toast: "No connection. Try again later." Toggle resets off. |
| Interrupted mid-download | Partial file deleted. State → `notDownloaded`. User re-toggles to retry. |
| Storage full | Toast: "Not enough storage (~600 MB needed)." Toggle resets off. |
| Corrupt download (checksum fail) | Delete file, state → `error`, retry option shown in settings row. |

### Inference Errors

| Scenario | Behaviour |
|---|---|
| Timeout >10s | Adapter returns `null`. Feature skips AI silently. |
| Model not loaded | `AiService.infer()` throws. Adapter catches → `null`. |
| Bad output / parse fail | Adapter validates → `null`. Caller uses fallback. |

No AI error ever surfaces as a crash or blocking UI. AI is always enhancement layer.

### Cold-Start Lifecycle

```
AiProvider.init() on app launch
  ├── isPro? No → skip
  └── isPro? Yes
        ├── isEnabled=false → state = notDownloaded
        └── isEnabled=true
              ├── model file exists → init model → state = ready
              └── model file missing → reset isEnabled=false, state = notDownloaded
```

Model init (~2–4s) runs in background. UI not blocked.

### Memory Management

- Model stays loaded while app is foregrounded (flutter_gemma manages this)
- Background: flutter_gemma releases weights automatically
- Re-foreground: `AiService` lazy re-inits transparently before next inference call

### Premium Revoked Mid-Session

```
SubscriptionProvider.isPro → false
  → AiProvider suspends all inference
  → Model file NOT deleted (user may resubscribe)
  → AI features disappear from UI via isPro guard
```

---

## Dependencies

Add to `pubspec.yaml`:
```yaml
flutter_gemma: ^0.x.x   # Google's official Gemma on-device package
```

Model file (~600 MB) downloaded post-install to app documents directory. Not bundled in APK/IPA.

---

## Out of Scope

- Natural language query interface ("chat with your data")
- Financial advice or investment suggestions
- Cloud/hybrid inference fallback
- Model fine-tuning or on-device training
- Android-only vs iOS parity — validate `flutter_gemma` iOS support before shipping iOS
