# SMS Parsing — Design Spec

**Date:** 2026-05-23
**Scope:** Deterministic SMS parsing pipeline only. LLM fallback is out of scope — covered in `2026-05-23-local-llm-design.md`.

---

## Overview

Read bank SMS messages, extract transaction data (merchant, amount, type), and surface them in a review queue accessed via the notification bell icon in `layout_screen.dart`. Users review, edit inline, and confirm or dismiss each item before it becomes a `Transaction`.

**Entry points:**
- **Android background scan** — WorkManager periodic task reads SMS inbox
- **Android share target** — user shares SMS text from any app (Messages, etc.) via Intent filter
- **iOS Share Extension** — user shares SMS from Messages app into the app
- **iOS Paste & Parse fallback** — manual paste in inbox panel (only if Share Extension is not feasible)

All entry points feed the same Dart parsing pipeline.

---

## Architecture

```
Entry points
  Android WorkManager scan ─┐
  Android Intent share      ├──→ SmsReader (platform boundary)
  iOS Share Extension       ─┘
                               ↓
                            SmsValidator   ← fraud / sender verification
                               ↓ safe | suspicious | blocked
                            SmsFilter      ← drop OTPs, promos, non-financial
                               ↓
                            SmsParser      ← regex engine → ParsedSmsResult?
                               ↓
                            SmsRulesEngine ← merchant → categoryId
                               ↓
                            SmsPendingStore ← dedup + Hive persistence
                               ↓
                            SmsProvider    ← ChangeNotifier, exposes queue to UI
                               ↓
                            SmsInboxSheet  ← bell icon → bottom sheet
                               ↓
                            SmsPendingCard ← inline edit, swipe confirm/dismiss
                               ↓
                            TransactionProvider.addTransaction()
```

### New files

```
lib/models/pending_sms_transaction.dart
lib/services/sms_reader.dart
lib/services/sms_validator.dart
lib/services/sms_filter.dart
lib/services/sms_parser.dart
lib/services/sms_rules_engine.dart
lib/services/sms_pending_store.dart
lib/providers/sms_provider.dart
lib/widgets/sms_inbox_sheet.dart
lib/widgets/sms_pending_card.dart
ios/SmsShareExtension/               ← new iOS app extension target (Swift)
```

### Modified files (share target)

```
android/app/src/main/AndroidManifest.xml   ← add intent-filter for text/plain share
pubspec.yaml                               ← add receive_sharing_intent plugin
```

Android share target requires no new native directory — the `intent-filter` in `AndroidManifest.xml` plus the `receive_sharing_intent` Flutter plugin handles receiving shared text in Dart. iOS requires a new native extension target (`ios/SmsShareExtension/`) because iOS Share Extensions run in a separate process outside the main app.

---

## Data Model

```dart
enum SmsVerdict { safe, suspicious, blocked }

class PendingSmsTransaction {
  final String id;             // SMS system ID (Android) or SHA-256(body+date) (iOS)
  final String rawSms;         // original body — kept for LLM fallback hookup
  final String? merchant;      // parsed merchant name → transactionTitle
  final double? amount;
  final TransactionType type;  // debit → expense, credit → income
  final String? categoryId;    // from SmsRulesEngine; null = user picks
  final String? accountHint;   // bank name string, best-effort account match
  final DateTime parsedAt;
  final bool isUnparsed;       // true → placeholder title, misc expense button
  final SmsVerdict verdict;    // safe | suspicious (blocked are never stored)
}
```

Stored in Hive box `sms_pending`. Blocked messages are dropped before reaching the store.

---

## SmsReader

Platform-specific only. Produces raw `(sender, body, smsId, timestamp)` tuples. No parsing logic here.

**Android — WorkManager background scan:**
- Periodic task via `flutter_workmanager`, minimum interval 15 minutes
- Constraint: `NetworkType.not_required`, low priority (no foreground service, no persistent notification)
- On each run: reads SMS inbox since last scan timestamp (persisted in Hive key `sms_last_scan_ts`)
- First run: scans last 30 days
- Uses SMS content provider (`content://sms/inbox`)

**Android — Share target:**
- App registers `intent-filter` for `android.intent.action.SEND` with `text/plain` MIME type
- Received text is passed directly into the pipeline as a single raw SMS body
- `smsId` = SHA-256 hash of body (no system ID available from intent)

**iOS — Share Extension:**
- New app extension target `SmsShareExtension`
- Receives `NSExtensionItem` with `kUTTypePlainText` attachment
- Writes raw text to App Group shared container
- Main app reads from shared container on next launch or extension URL callback

**iOS — Paste & Parse fallback (only if Share Extension is infeasible):**
- Text input field in `SmsInboxSheet` header
- User pastes copied SMS, taps Parse
- Passes body through same pipeline entry point

---

## SmsValidator

Runs before `SmsFilter`. Returns `SmsVerdict`.

**`blocked` — drop silently:**
- Sender is a raw phone number (not an alphanumeric ID) — Indian bank transactional SMS use TRAI/DLT-registered 6-char alpha sender IDs (e.g. `HDFCBK`, `ICICIB`)
- Body contains phishing signals alongside financial claim: "click here", URLs (`http`/`https`), "enter OTP", "share your PIN/password"
- Body describes a future/requested payment rather than a completed transaction (imperative verbs: "please pay", "send money to")

**`suspicious` — pass through with warning banner on card:**
- Sender ID typo-squats a known bank ID (Levenshtein edit distance ≤ 2 from any allowlist entry, e.g. `HDFCB`, `HD-FCB`)
- Sender ID matches alphanumeric bank ID format but is not in the known allowlist
- Body contains urgency language (`immediately`, `account will be blocked`, `act now`, `last chance`) alongside an amount claim
- Amount exceeds ₹5,00,000 — flags unusually large transaction for user attention

**`safe`:**
- Sender ID is an exact match in the known bank sender ID allowlist
- Body matches a known bank SMS pattern closely

Known allowlist (initial set, extensible):
`HDFCBK`, `ICICIB`, `SBIINB`, `AXISBK`, `KOTAKB`, `PNBSMS`, `CANBNK`, `BOIIND`, `INDBNK`, `YESBNK`, `IDFCBK`, `SCBINB`, `CSBBNK`, `FEDBKM`, `RBLBNK`

---

## SmsFilter

Runs after `SmsValidator` (on `safe` and `suspicious` messages only). Returns `bool`.

**Keep if:**
- Sender matches known bank sender ID allowlist (secondary check, belt-and-suspenders), OR
- Body contains financial keywords: `debited`, `credited`, `spent`, `paid`, `received`, `transferred`, `INR`, `Rs.`, `₹`, `a/c`, `acct`, `UPI`, `NEFT`, `IMPS`, `RTGS`

**Drop if:**
- Body matches OTP pattern: `/\b\d{4,8}\b.*\b(OTP|one.time|password|verification)\b/i`
- Body matches promo pattern: `/\b(offer|discount|cashback|win|reward|lucky|congratulations)\b/i` AND no amount pattern present

---

## SmsParser

Pure Dart. Returns `ParsedSmsResult?` — null means no regex matched → `isUnparsed = true`.

```dart
class ParsedSmsResult {
  final double amount;
  final TransactionType type;   // debit → expense, credit → income
  final String? merchant;
  final String? accountHint;    // e.g. "HDFC", "ICICI"
  final DateTime? txDate;
}
```

**Amount normalization:** strip commas, parse to `double`. Keywords `debited`, `spent`, `paid` → `expense`; `credited`, `received`, `refund` → `income`.

**Regex tier order (first match wins):**

| Tier | Target | Example |
|---|---|---|
| 1 | HDFC debit/credit | `Rs.349.00 debited from a/c XX4242 on UPI to ZOMATO` |
| 2 | ICICI debit/credit | `Rs 520.00 debited from ICICI Bank A/c ...for SWIGGY` |
| 3 | SBI | `Your A/c XXXX1234 debited for Rs.1850 ...BESCOM` |
| 4 | Axis / Kotak / PNB / others | Bank-specific patterns |
| 5 | Generic UPI | `₹349 paid to Zomato via UPI` |
| 6 | Generic debit/credit | `/(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s*(debited|credited)/i` |

If no tier matches → return `null`.

---

## SmsRulesEngine

Pure Dart. Two-tier lookup, first hit wins. Returns `categoryId?`.

**Tier 1 — Exact/partial merchant name match (~150 top Indian merchants):**

| Merchants | Category |
|---|---|
| Zomato, Swiggy, Blinkit (food), EatFit | `restaurant` |
| Uber Eats, Swiggy Instamart | `groceries` |
| BigBasket, DMart, Blinkit, Zepto, JioMart | `groceries` |
| Amazon, Flipkart, Myntra, Meesho, Nykaa, Ajio | `shopping` |
| Uber, Ola, Rapido, BMTC, BEST, DTC, Metro | `transport` |
| Netflix, Hotstar, Amazon Prime, Inox, PVR, BookMyShow | `movies` |
| BESCOM, MSEB, TPDDL, Jio, Airtel, Vi, BSNL, ACT | `utilities` |
| Apollo Pharmacy, Practo, PharmEasy, 1mg, Medline | `doctor` |
| Blue Tokai, Starbucks, Cafe Coffee Day, Third Wave | `coffee` |
| Decathlon, Cure.fit, Gold's Gym, Cult.fit | `fitness` |
| MakeMyTrip, Goibibo, Cleartrip, IRCTC, IndiGo, Air India | `travel` |
| Byju's, Unacademy, Coursera, Udemy | `education` |

**Tier 2 — Keyword fallback on merchant string:**

| Keyword in merchant | Category |
|---|---|
| pharmacy, clinic, hospital, medical, health | `doctor` |
| cafe, coffee | `coffee` |
| gym, fitness, yoga, sports | `fitness` |
| school, college, university, course, institute | `education` |
| hotel, resort, airbnb, oyo | `travel` |
| recharge, broadband, internet, dth | `phone` |
| salary, stipend | `savings` (income) |
| refund, cashback | `savings` (income) |

If neither tier matches → returns `null`.

`SmsRulesEngine.categorize()` returns a **category hint** string (e.g. `'restaurant'`, `'groceries'`), not a category ID. Users create their own categories — no built-in category IDs are assumed to exist. `SmsProvider` resolves the hint against the user's active categories at runtime:

1. Exact name match: `category.name.toLowerCase() == hint`
2. Contains match: `category.name.toLowerCase().contains(hint)` or `hint.contains(category.name.toLowerCase())`
3. No active category matches → `categoryId = null`

A hint that matches no active category silently yields `null`; the card shows an empty category chip row and the user picks manually.

---

## Account Matching

Best-effort, low priority. `accountHint` from `SmsParser` (e.g. `"HDFC"`, `"ICICI"`) is compared against user's `AccountProvider.accounts` via `displayName.contains(hint)` case-insensitive check.

- Exactly one match → pre-fill account field on card
- Zero or multiple matches → account field left blank, user picks
- No match failure blocks the flow

---

## Deduplication

`SmsPendingStore` maintains two Hive sets:

1. **`processedIds`** — SMS system IDs processed by Android background scanner
2. **`contentHashes`** — SHA-256 of normalized body text (lowercased, whitespace-collapsed)

**On any new message (background scan or shared):**
1. Compute `contentHash = SHA-256(normalize(body))`
2. Check `processedIds` (if Android smsId available) and `contentHashes`
3. Hit in either set:
   - If message is already in pending queue (not yet confirmed) → surface existing card (scroll to it, briefly highlight)
   - If already confirmed → show `"Already captured"` toast, drop silently
4. No hit → process through pipeline, add to pending store, store hash and id

---

## SmsProvider

`ChangeNotifier`, added to `main.dart` provider tree alongside existing providers.

```dart
class SmsProvider extends ChangeNotifier {
  List<PendingSmsTransaction> get pending;  // unconfirmed items
  int get pendingCount;                      // badge value

  Future<void> confirm(String id);   // → TransactionProvider.addTransaction()
  Future<void> dismiss(String id);   // removes from queue
  Future<void> update(String id, {  // inline edits from card
    String? merchant,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
  });
  Future<void> runScan();            // triggered by WorkManager or share handler
}
```

---

## UI

### Bell icon badge (`layout_screen.dart`)

Bell icon (`LucideIcons.bell`) in `_buildTopHeader` gets a red badge count overlay when `smsProvider.pendingCount > 0`. Badge disappears when queue is empty.

### SmsInboxSheet

Bottom sheet opened on bell tap. Matches existing sheet pattern (`RoundedRectangleBorder`, `isScrollControlled: true`).

- Header: `"SMS Transactions"` + pending count chip
- Scrollable list of `SmsPendingCard` widgets
- Empty state: `"No new transactions from SMS"`
- iOS Paste & Parse fallback (if Share Extension infeasible): text input field + Parse button in header

### SmsPendingCard

Inline-editable card. Four rows + action row:

```
┌─────────────────────────────────────────────────┐
│  ₹ 349                    [Expense ↕ / Income]  │  row 1: amount (tap → inline edit) + type toggle
│─────────────────────────────────────────────────│
│  Zomato                                         │  row 2: title TextField (single line, 15px)
│─────────────────────────────────────────────────│
│  [🛍 44px] [🍽] [☕] [🚗] [🛒] ...  (h-scroll)  │  row 3: category chips, 44px circles, no labels
│─────────────────────────────────────────────────│
│  [HDFC 44px] [ICICI] [Cash]        (h-scroll)  │  row 4: Pay With chips, 44px height
│─────────────────────────────────────────────────│
│  [✕ Dismiss]                    [✓ Confirm]    │  row 5: action buttons
└─────────────────────────────────────────────────┘
```

- `Dismissible` widget: swipe right → confirm, swipe left → dismiss
- Buttons are non-swipe fallback for the same actions
- Category chips: 44px circles (vs 64px in `add_expense_sheet`), 20px icon, no label text
- Account chips: 44px height (vs 56px), font sizes scaled down ~2pt; same `AnimatedSize` expand pattern

**Parsed card with no matched category** (`isUnparsed = false`, `categoryId == null`):
- Category chip row shown with nothing pre-selected
- Confirm button available — user may confirm without selecting a category; transaction saved with null `categoryId` (uncategorized)
- No "Add as misc expense" button shown

**Unparsed card** (`isUnparsed = true`):
- Title field pre-filled with `"We don't know what this was for"` (dimmed placeholder style)
- Category and account still editable
- Confirm button replaced with `"+ Add as misc expense"`

**"Add as misc expense" behaviour:**
1. Check if a category with `id = 'misc'` exists in the user's active categories (built-in or custom)
2. If not → auto-create a custom `Category(id: 'misc', name: 'Misc', lucideIcon: LucideIcons.package, color: '#9E9E9E', bg: '#F5F5F5')` via `StorageService.saveCustomCategory()`, then add `'misc'` to the user's active category list
3. Show a one-time snackbar: `"A 'Misc' category was created for unrecognized transactions"`
4. Confirm transaction with `categoryId = 'misc'`

The auto-created misc category appears in the user's category list and can be renamed, recoloured, or deleted like any other custom category.

**Suspicious card** (`verdict = suspicious`):
- Red warning strip above row 1:
  `"⚠ Could not verify sender. Confirm only if you recognise this transaction."`
- All fields still editable; user retains full control

---

## Background Service (Android)

- Package: `flutter_workmanager`
- Task name: `sms_scan_task`
- Frequency: periodic, 15-minute minimum (WorkManager enforced floor)
- Constraints: none (runs on any network state, any battery state)
- NOT a foreground service — no persistent notification
- On completion: updates Hive `sms_last_scan_ts`, notifies `SmsProvider` via `ValueNotifier` or `isolate → main thread` callback

---

## iOS Share Extension

- New Xcode target: `SmsShareExtension`
- Type: `Share Extension` (`NSExtension` with `NSExtensionPointIdentifier = com.apple.share-services`)
- Accepts: `NSExtensionActivationSupportsText = true`
- On activation: reads `kUTTypePlainText` from `NSExtensionItem`, writes to App Group shared `UserDefaults`
- Main app: reads from App Group on launch (or via custom URL scheme callback), clears after read
- App Group ID: `group.<bundle-id>.sms`

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| SMS permission denied (Android) | Bell icon hidden when `Permission.sms.isPermanentlyDenied`. Settings screen has an "SMS Transaction Detection" toggle. Toggling on: requests permission if status is `undetermined`/`denied`; calls `openAppSettings()` if `permanentlyDenied`. Toggling off: hides bell, stops WorkManager task. |
| WorkManager task killed by OS | WorkManager reschedules automatically on next opportunity. No user action needed. |
| Share Extension not available (iOS) | Fall back to Paste & Parse text field in `SmsInboxSheet` header. |
| Regex finds no match | `isUnparsed = true`. Card shows placeholder title + misc expense button. `rawSms` kept for future LLM fallback. |
| Amount parse fails (e.g. currency symbol only) | `isUnparsed = true`. Same as above. |
| Duplicate shared SMS (already captured) | `"Already captured"` toast if confirmed. Existing pending card surfaced if still in queue. |
| Suspicious sender | Card shown with warning banner. User decides. Never auto-blocked. |
| Fraudulent sender (blocked verdict) | Dropped silently before reaching store. No toast, no card. |

---

## Permissions

**Android (`AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />  <!-- share target only -->
```
Runtime permission request shown on first tap of bell icon (not on app launch).

**Settings screen — SMS Transaction Detection toggle (Android):**
- Reads `Permission.sms.status` on open; toggle reflects current state
- Toggle **on**: call `Permission.sms.request()`. If result is `granted` → start WorkManager scan. If `permanentlyDenied` → `openAppSettings()` and show message `"Enable SMS permission in app settings"`. If `denied` → show snackbar `"SMS permission is required"`.
- Toggle **off**: cancel WorkManager task, persist `smsFeatureEnabled = false` in `UserPreferencesProvider`. Bell icon hidden immediately.
- Bell icon in `layout_screen.dart` is hidden when Android and (`Permission.sms.isPermanentlyDenied` OR `!smsFeatureEnabled`). Status checked via `FutureBuilder<PermissionStatus>` on widget build.

**iOS:** No SMS read permission on iOS — Share Extension receives only what the user explicitly forwards. No `Privacy - SMS Usage Description` needed.

---

## Dependencies

```yaml
# pubspec.yaml additions
flutter_workmanager: ^0.x.x        # Android background tasks
receive_sharing_intent: ^2.x.x     # Android + iOS share target (text/plain)
crypto: ^3.x.x                     # SHA-256 for content hashing
```

`receive_sharing_intent` handles Android Intent share in Dart. iOS Share Extension is implemented natively in Swift (no Flutter package needed in the extension target itself).

---

## Out of Scope

- LLM fallback for unmatched SMS — covered in `2026-05-23-local-llm-design.md` (`SmsParserAdapter`)
- Real-time SMS broadcast receiver (foreground or background push on message receive)
- SMS from non-Indian banks or non-INR formats
- Bulk "Accept all" action in the review queue
- Editing transaction after it has been confirmed (use existing transaction edit flow)
- Android SMS permission on devices running Android 14+ with restricted SMS access (deferred)
