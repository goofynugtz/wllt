# Onboarding Flow Design

**Date:** 2026-04-05  
**Status:** Approved  

---

## Overview

A 3-screen first-launch onboarding flow for WLLT. Shown only once (gated by a `shared_preferences` flag). Collects auth mode, default currency, and active categories. Preferences are stored in Hive locally and synced to Firestore when the user signs in with Google.

---

## Navigation & Startup

`main.dart` becomes async. On cold start:

1. Initialize Hive and open boxes
2. Read `shared_preferences` key `onboarding_complete` (bool, default false)
3. If `false` → render `OnboardingFlow`
4. If `true` → render `LayoutScreen` directly

```
App Start
  ├─ onboarding_complete == false → OnboardingFlow (PageView, 3 pages)
  └─ onboarding_complete == true  → LayoutScreen
```

`OnboardingFlow` wraps 3 screens in a `PageController`. Navigation:
- Forward: explicit calls to `pageController.nextPage()`
- Back: back button on pages 2 & 3 calls `pageController.previousPage()`
- Completion: Page 3 "Get Started" sets `onboarding_complete = true`, then `Navigator.pushReplacement` to `LayoutScreen`

No `go_router` used in the onboarding flow — it is self-contained.

---

## New File Structure

```
lib/
  screens/
    onboarding/
      onboarding_flow.dart             ← PageView + PageController
      onboarding_page1_screen.dart     ← Welcome + Auth choice
      onboarding_page2_screen.dart     ← Currency picker
      onboarding_page3_screen.dart     ← Category selector
  services/
    auth_service.dart                  ← google_sign_in wrapper
    storage_service.dart               ← Hive read/write abstraction
    sync_service.dart                  ← Firestore ↔ Hive sync
  providers/
    user_preferences_provider.dart     ← ChangeNotifier wrapping Hive
```

---

## Packages

Add to `pubspec.yaml`:

```yaml
shared_preferences: ^2.3.0
hive: ^2.2.3
hive_flutter: ^1.1.0
google_sign_in: ^6.2.0
firebase_core: ^3.6.0
firebase_auth: ^5.3.0
cloud_firestore: ^5.4.0
```

Platform config required:
- Android: `google-services.json` in `android/app/`
- iOS: `GoogleService-Info.plist` in `ios/Runner/`
- Firebase project with Firestore and Google Sign-In enabled

---

## Data & Storage

### shared_preferences

| Key | Type | Purpose |
|-----|------|---------|
| `onboarding_complete` | `bool` | Has user completed onboarding? |

### Hive Boxes

**Box: `user_prefs`** (plain `Map<String, dynamic>`)

| Key | Type | Example |
|-----|------|---------|
| `currency` | `String` | `"INR"` |
| `auth_mode` | `String` | `"google"` or `"offline"` |
| `google_uid` | `String?` | Firebase Auth UID (from `firebase_auth`, not raw Google ID) |
| `google_email` | `String?` | `"user@gmail.com"` |

**Box: `active_categories`**

| Key | Type | Example |
|-----|------|---------|
| `categories` | `List<String>` | `["shopping", "transport", ...]` |

No type adapters required — all plain primitives and lists.

### Firestore (signed-in users only)

Document path: `users/{uid}/preferences`

```json
{
  "currency": "INR",
  "categories": ["shopping", "transport", "groceries"],
  "updatedAt": "<Timestamp>"
}
```

### Sync Strategy

- `SyncService` is only instantiated when `auth_mode == "google"`
- On Google sign-in: push current Hive state to Firestore immediately
- `SyncService` attaches a `snapshots()` listener — remote changes update Hive and notify `UserPreferencesProvider`
- On any local write: write Hive first, then Firestore (fire-and-forget, no await blocking UI)
- Offline users: Hive only, `SyncService` never starts

---

## UI Design

### Shared Visual Language

- Background: `Color(0xFFFFF3F0)` at 91% opacity over white (warm blush)
- Primary accent: `#6750A4`
- Typography: Inter (system sans-serif fallback); Archia used only in existing screens
- Bottom pill buttons: `#1D1B20` background, white text, `BorderRadius.circular(50)`

---

### Page 1 — Welcome & Auth

**Top half:**
- Centered purple gradient rounded square icon (wallet icon, white)
- "WLLT" heading (38px, tracking -0.76)
- "Track your expenses, master your money." subtitle (16px, muted `#6B6572`)

**Bottom panel** (white card, rounded top `36px`, shadow):
- "GET STARTED" label — uppercase, 13px, muted, letter-spaced
- **"Continue with Google"** button — white bg, border `#E8E0EC`, shadow, Google logo icon left, chevron right. Disabled when checkbox unticked.
- Divider: `──── or ────`
- **"Continue without account"** button — `#F5EFF7` bg, `#6750A4` text, offline icon left, chevron right. Disabled when checkbox unticked.
- **Checkbox row**: `Checkbox` (purple) + tappable text "I agree to the Terms of Service and Privacy Policy" with Terms and Privacy Policy styled as `#6750A4` inline links.

**Behaviour:**
- Both buttons disabled (opacity 0.4) until checkbox is ticked
- Tapping "Continue without account": save `auth_mode = "offline"` to Hive, show snackbar *"Offline mode — your data won't be backed up to the cloud."*, advance to page 2
- Tapping "Continue with Google": trigger `AuthService.signInWithGoogle()` — this calls `google_sign_in` to get a `GoogleSignInAccount`, then uses its credentials to sign into `firebase_auth` via `signInWithCredential()`, obtaining a Firebase `User`. On success save `auth_mode = "google"`, Firebase `user.uid` as `google_uid`, `user.email` as `google_email` to Hive, advance to page 2

---

### Page 2 — Currency

**Top bar:** back chevron + 3-segment progress bar (2 of 3 filled, `#6750A4` / `#E8E0EC`) + "2 of 3" label

**Content:**
- Heading: "What's your currency?" (26px, tracking -0.65)
- Auto-detect subtitle: "We detected 🇮🇳 INR based on your region." — locale derived from `Platform.localeName`, mapped to currency. No GPS or location permission required.
- If `auth_mode == "offline"`: yellow pill chip "Offline mode · No cloud backup" (`#FFF8E1` bg, `#92400E` text, warning icon)
- Search field (white card, rounded `16px`, shadow) — filters currency list live (by name, code, or country)
- **Selected currency card**: purple border `#6750A4`, `#F5EFF7` bg, flag emoji + name + `CODE · symbol`, "Selected" pill badge
- **Scrollable list**: each row — flag emoji + currency name (bold 15px) + `CODE · symbol · Country` (muted 12px) + purple checkmark circle when selected
- "Continue →" dark pill button pinned at bottom — always enabled once a currency is selected (default is auto-detected)

**Behaviour:**
- Tapping a row updates selection and scrolls selected card to top
- On Continue: save `currency` to Hive, advance to page 3

---

### Page 3 — Categories

**Top bar:** back chevron + 3-segment progress bar (all 3 filled) + "3 of 3" label

**Content:**
- Heading: "Choose your categories" (26px)
- Subtitle: "Select the categories you use most. You can always add or remove them later."
- Counter row: "X selected" (bold count, muted label) + "Select all" text button (`#6750A4`)
- 2-column `GridView` of category chips

**Category chip states:**
- **Selected**: white card, shadow, full-color icon circle, black category name, small colored check badge top-right corner
- **Unselected**: semi-transparent white card, `#E8E0EC` border, 25%-opacity icon circle, `#9E99A3` grey name text

**Default selection:** first 8 categories pre-selected on entry.

**"✦ Get Started" pill button** (dark bg) pinned at bottom:
- Disabled (opacity 0.4) if 0 categories selected
- On tap: save `categories` list to Hive, set `onboarding_complete = true` in `shared_preferences`, if `auth_mode == "google"` trigger initial `SyncService.pushToFirestore()`, then `Navigator.pushReplacement` to `LayoutScreen`

---

## Category List Replacement

`Category.categories` in `models.dart` is replaced with these 18 categories:

| ID | Name | Icon Source | Color |
|----|------|-------------|-------|
| `shopping` | Shopping | `assets/icons/categories/shopping.svg` | `#EBA9A9` |
| `restaurant` | Restaurant | `lucide_icons` (UtensilsCrossed) | `#E2B932` |
| `work` | Work | `lucide_icons` (Briefcase) | `#74A1DB` |
| `doctor` | Doctor | `lucide_icons` (Stethoscope) | `#9D85E5` |
| `coffee` | Coffee | `lucide_icons` (Coffee) | `#70C01F` |
| `movies` | Movies | `lucide_icons` (Film) | `#86D9BC` |
| `transport` | Transport | `assets/icons/categories/transport.svg` | `#8FC9E2` |
| `groceries` | Groceries | `assets/icons/categories/groceries.svg` | `#F4A261` |
| `utilities` | Utilities | `assets/icons/categories/utilities.svg` | `#E76F51` |
| `music` | Music | `lucide_icons` (Music) | `#2A9D8F` |
| `travel` | Travel | `lucide_icons` (Plane) | `#FFB703` |
| `fitness` | Fitness | `lucide_icons` (Dumbbell) | `#C77FFF` |
| `education` | Education | `assets/icons/categories/education.svg` | `#06D6A0` |
| `savings` | Savings | `assets/icons/categories/savings.svg` | `#FB8500` |
| `home` | Home | `lucide_icons` (Home) | `#FF6B6B` |
| `phone` | Phone | `lucide_icons` (Smartphone) | `#4CC9F0` |
| `internet` | Internet | `lucide_icons` (Wifi) | `#A8DADC` |
| `gifts` | Gifts | `lucide_icons` (Gift) | `#E63946` |

The `Category` model gains an `isLucideIcon` bool and a `lucideIconData` field to support both SVG and Lucide rendering paths.

---

## UserPreferencesProvider

`ChangeNotifier` exposed via `Provider` at the root of the widget tree (in `main.dart`). Exposes:

- `String currency` — used by transaction formatters throughout the app
- `List<String> activeCategories` — used to filter category pickers
- `String authMode`
- `Future<void> setCurrency(String code)`
- `Future<void> setCategories(List<String> ids)`

The rest of the app reads currency from this provider instead of hardcoding `"₹"`.

---

## Error Handling

- Google Sign-In failure (user cancels, network error): stay on Page 1, show snackbar with error message
- Firestore write failure: silently retry on next app launch (Hive is already written, data is not lost)
- Currency auto-detect failure (unknown locale): default to USD, no crash
