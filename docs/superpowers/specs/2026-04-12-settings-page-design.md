# Settings Page — Design Spec
**Date:** 2026-04-12
**Status:** Approved

---

## Overview

Add a Settings screen as a 5th tab in the bottom navigation bar. The screen lets users control app theme (light/system/dark), color scheme (8 presets), currency preference, and categories — all changes apply live. A destructive "Reset all data" action is also provided.

---

## Architecture

### New files

**`lib/providers/app_settings_provider.dart`**
- `AppSettingsProvider extends ChangeNotifier`
- Fields: `ThemeMode themeMode`, `Color colorSeed`
- Methods: `setThemeMode(ThemeMode)`, `setColorSeed(Color)`
- Initialises from `StorageService` in constructor; defaults to `ThemeMode.system` and `Color(0xFF6750A4)` (Violet) if no saved value
- Persists to `StorageService` on every change

### Modified files

**`lib/services/storage_service.dart`**
- New key `keyThemeMode` — stores `'light' | 'dark' | 'system'` string in Hive `_userPrefs` box
- New key `keyColorSeed` — stores color as `int` in Hive `_userPrefs` box
- New getters: `ThemeMode get themeMode`, `Color get colorSeed`
- New setters: `setThemeMode(String)`, `setColorSeed(int)`

**`lib/theme/app_theme.dart`**
- Add `static ThemeData darkTheme({String fontFamily})` — mirrors `lightTheme` with `Brightness.dark` and dark surface colors
- Add `static ThemeData fromSeed(Color seed, Brightness brightness)` — generates a `ThemeData` via `ColorScheme.fromSeed(seedColor: seed, brightness: brightness)`; used by `WalletApp` at runtime

**`lib/main.dart`**
- `AppSettingsProvider` added to `MultiProvider`
- `WalletApp.build` wrapped in `Consumer<AppSettingsProvider>`
- `MaterialApp` receives `theme: AppTheme.fromSeed(seed, Brightness.light)`, `darkTheme: AppTheme.fromSeed(seed, Brightness.dark)`, `themeMode: settings.themeMode`

**`lib/screens/layout_screen.dart`**
- `_screens` list gains `const SettingsScreen()` as 5th element
- `_navItems` gains `NavItem(icon: LucideIcons.settings, label: 'Settings')`
- `_buildFab()` returns `null` for index 4 (no FAB on Settings)

---

## Settings Screen — `lib/screens/settings_screen.dart`

Single `StatelessWidget` consuming `AppSettingsProvider` and `UserPreferencesProvider`. Uses `CustomScrollView` + `SliverList` for smooth scroll.

### Header
- Non-card, inline with scroll
- Left: purple circular icon container (settings gear icon, 40×40, `surfaceColor` bg)
- Center: "Settings" (22px medium) + "WLLT v1.0.0" subtitle (12px, `textTertiary`)
- Right: pill badge — amber bg `#FFF8E1`, amber border `rgba(245,158,11,0.3)`, reads `authMode` from `UserPreferencesProvider` to show "Offline" or "Online"

### Section: APPEARANCE
Label: `"APPEARANCE"` in `trackingWide` style, 20px horizontal padding.

`SettingsCard` (white, radius 16, shadow `0 1 8 rgba(0,0,0,0.07)`):
- Row: purple icon chip (palette icon) + "App theme" label + current mode subtitle (e.g. "Always light")
- Below: `ThemeModeToggle` — pill-shaped container (`borderRadius: 16`, bg `Color(0xFFE8E0EC)`) with 3 equal segments: Light / System / Dark. Selected segment: white card with shadow. Unselected: transparent. Each segment has a small Lucide icon (sun / monitor / moon) + label.

### Section: COLOR SCHEME
Label: `"COLOR SCHEME"`.

`SettingsCard`:
- Header row: purple icon chip (colored circle preview of active seed) + "Color scheme" label + subtitle showing name + " · Light palette" or " · Dark palette"
- 4×2 swatch grid. Each swatch: 56×56 rounded container (radius 16). Selected: gradient overlay + white checkmark icon + drop shadow. Unselected: flat `containerColor` background + solid `onContainerColor` dot.

Color definitions (name / seed / containerColor / onContainerColor):
| Name    | Seed        | Container   | On container |
|---------|-------------|-------------|--------------|
| Violet  | `#6750A4`   | `#EDE7F6`   | `#6750A4`    |
| Rose    | `#B5264C`   | `#FFD9E2`   | `#B5264C`    |
| Ocean   | `#006874`   | `#A2EFF8`   | `#006874`    |
| Sage    | `#386A20`   | `#B3F397`   | `#386A20`    |
| Amber   | `#7D5700`   | `#FFDEA3`   | `#7D5700`    |
| Crimson | `#9C3425`   | `#FFDAD5`   | `#9C3425`    |
| Indigo  | `#3951AD`   | `#DCE2FF`   | `#3951AD`    |
| Forest  | `#256156`   | `#A0F0E3`   | `#256156`    |

### Section: PREFERENCES
Label: `"PREFERENCES"`.

`SettingsCard` with two rows separated by a `Divider` (color `borderColor`, height 0.5):
- **Currency row**: icon chip (currency/coin icon) + "Currency" label + right-aligned current currency code in `textTertiary` + chevron. Taps → `Navigator.push` to currency picker.
- **Categories row**: icon chip (tag icon) + "Categories" label + right-aligned count (e.g. "28 categories") + chevron. Taps → `Navigator.push(CategoriesScreen())`.

### Section: ACCOUNT & DATA
Label: `"ACCOUNT & DATA"`.

`SettingsCard` with two rows:
- **Sync mode row**: icon chip (sync icon) + "Sync mode" label + right-aligned `authMode` value ("Offline" / "Google") — read-only, no chevron, no tap action.
- **Reset all data row**: red icon chip (`rgba(179,38,30,0.12)` bg, red trash icon) + "Reset all data" in `Color(0xFFB3261E)` + chevron. Taps → `showDialog` confirmation with title "Reset all data?", message "This will permanently delete all your transactions, accounts, and preferences. This cannot be undone.", Cancel + Reset (red) buttons. On confirm: clear both Hive boxes (`user_prefs` and `active_categories`) + clear `SharedPreferences` key `onboarding_complete`, then call `Navigator.pushAndRemoveUntil` to `OnboardingFlow`.

### Section: ABOUT
Label: `"ABOUT"`.

Single card with horizontal layout:
- Left: 56×56 rounded icon tile with gradient (`#3B2977 → #6750A4`, angle 135°) + white wallet icon
- Right: "WLLT: Expense Tracker" (17px), "Version 1.0.0" (12px, `textTertiary`), "Built with ♥ using Flutter" (11px, `Color(0xFFCAC4D0)`)

---

## Data Flow

```
User taps theme segment
  → AppSettingsProvider.setThemeMode(ThemeMode)
  → StorageService.setThemeMode(string)   [Hive persist]
  → notifyListeners()
  → Consumer<AppSettingsProvider> in WalletApp rebuilds
  → MaterialApp themeMode updates
  → App repaints instantly
```

Same flow for color seed. Currency and categories reuse existing provider methods + existing screens. Reset all data clears Hive then navigates to onboarding.

---

## Reused / Extracted Screens

- **Currency picker**: The picker logic lives inside `OnboardingPage2Screen` (tightly coupled to `onNext`/`onBack` callbacks). It must be extracted into a new standalone `CurrencyPickerScreen` that can be pushed from both Settings and onboarding. The `_CurrencyRow` widget and `_filtered` list logic move to this new file; `OnboardingPage2Screen` delegates to it.
- **Categories**: existing `CategoriesScreen` — push directly.

Files added: `lib/screens/currency_picker_screen.dart`.

---

## Out of Scope

- Sync mode toggle / Google sign-in flow (read-only display only)
- Notifications preferences
- Export / import data
