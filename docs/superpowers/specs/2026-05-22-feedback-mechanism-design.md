# Feedback Mechanism — Design Spec
Date: 2026-05-22

## Goal
Collect user sentiment subtly and non-disruptively. Positive users get routed to App Store rating; negative users submit written feedback captured in Firestore for developer review.

---

## Triggers

### Contextual (automatic, once only)
Guarded by `feedback_auto_shown` bool in SharedPreferences. Once shown, never auto-prompts again.

1. **Transaction milestone** — after the 10th transaction is logged
2. **Insight milestone** — first time user taps the Category Breakdown card on Home screen

Whichever fires first sets the flag. Both checks happen in `LayoutScreen`.

### Manual
"Send Feedback" row in Settings → About card. Always available, ignores the `feedback_auto_shown` flag.

---

## Sheet UI

### Step 1 — Sentiment
- Drag handle (36×4 pill, `borderRadius 2`, matches profile sheet)
- Headline: "Enjoying WLLT?" (18px, `onSurface`)
- Subtext: "Takes one tap" (13px, `onSurfaceVariant`)
- Two equal-width buttons side by side:
  - Left: `LucideIcons.thumbsUp` + label "Loving it" — `primaryContainer` background
  - Right: `LucideIcons.thumbsDown` + label "Not really" — `surfaceContainerHighest` background
- Tapping "Loving it": dismiss sheet → call `FeedbackService.requestReview()`
- Tapping "Not really": `AnimatedSwitcher` transitions to Step 2

### Step 2 — Text feedback (negative path)
- Same drag handle
- Headline: "What can we do better?" (18px, `onSurface`)
- Subtext: "Goes directly to the developer" (13px, `onSurfaceVariant`)
- Multiline `TextField`, min 3 lines, hint "Tell us what's on your mind…"
- "Send Feedback" full-width primary button → calls `FeedbackService.submitFeedback()`
- "Skip" text button — dismisses without writing to Firestore

---

## Architecture

### New files
| File | Purpose |
|------|---------|
| `lib/widgets/feedback_sheet.dart` | Sheet widget — handles both steps via internal `AnimatedSwitcher` |
| `lib/services/feedback_service.dart` | `submitFeedback()` → Firestore, `requestReview()` → `in_app_review` |

### Modified files
| File | Change |
|------|--------|
| `lib/services/storage_service.dart` | Add `feedbackAutoShown` bool getter + `setFeedbackAutoShown()` |
| `lib/screens/settings_screen.dart` | Add "Send Feedback" `_SettingsTappableRow` in About card |
| `lib/screens/layout_screen.dart` | Milestone checks — tx count listener + insight milestone callback |
| `lib/screens/home_screen.dart` | Pass insight milestone callback for CategoryBreakdown tap |
| `pubspec.yaml` | Add `in_app_review` package |

---

## Data

### SharedPreferences
- Key: `feedback_auto_shown` (bool, default `false`)
- Set to `true` after first contextual prompt fires

### Firestore collection: `feedback`
```
feedback/{auto-id}
  message:    String      // user's written feedback
  userId:     String      // prefs.googleUid ?? 'offline'
  trigger:    String      // 'manual' | 'transaction_milestone' | 'insight_milestone'
  platform:   String      // 'ios' | 'android'
  appVersion: String      // '1.0.0'
  createdAt:  Timestamp   // FieldValue.serverTimestamp()
```

### FeedbackService API
```dart
static Future<void> submitFeedback({
  required String message,
  required String trigger,
  required String userId,
}) async { ... }

static Future<void> requestReview() async { ... }
```

---

## Milestone check logic (LayoutScreen)

```
Consumer<TransactionProvider>
  if txCount == 10 && !storage.feedbackAutoShown
    → storage.setFeedbackAutoShown(true)
    → showFeedbackSheet(trigger: 'transaction_milestone')

onCategoryBreakdownTap (passed to HomeScreen):
  if !storage.feedbackAutoShown
    → storage.setFeedbackAutoShown(true)
    → await showFeedbackSheet(trigger: 'insight_milestone')
  → then navigate to CategoryBreakdownScreen
```

---

## Out of scope
- Time-based triggers
- Star rating input (native OS dialog handles rating UX)
- Analytics events beyond Firestore records
