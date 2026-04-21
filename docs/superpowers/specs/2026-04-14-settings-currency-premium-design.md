# Settings — Currency Bottom Sheet & Premium Section

**Date**: 2026-04-14  
**Scope**: Two additions to `lib/screens/settings_screen.dart` and one new private widget in the same file.

---

## 1. Currency Bottom Sheet

### Problem
Currency picker currently navigates to a full-screen `CurrencyPickerScreen`. Figma specifies it should pop up from the bottom instead.

### Solution
Replace the `Navigator.push` in `_buildPreferencesCard` with a `showModalBottomSheet` call. Extract picker logic into a private `_CurrencySheet` stateful widget inside `settings_screen.dart`.

### Behaviour
- `showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`
- `DraggableScrollableSheet` not required — `isScrollControlled` + `maxChildSize` is enough
- `borderRadius: BorderRadius.vertical(top: Radius.circular(24))`
- Background: `colorScheme.surface`
- Sheet height: not constrained (natural content height, max ~75% screen)

### Content layout (top → bottom)
1. Drag handle — centered, 40×4 rounded pill, `onSurfaceVariant` with 0.4 opacity
2. Title row — "Currency" (15px, `onSurface`) with 16px horizontal padding, 20px vertical
3. Search `TextField` — same style as existing `CurrencyPickerScreen`, `borderRadius(16)`
4. `Expanded` → `ListView.builder` of `_CurrencyRow` items (same widget, reused as-is)

### State
Identical to existing `CurrencyPickerScreen`:
- `_query` string, `_selectedCode` initialised from provider
- `_select(code)` sets currency on provider then calls `Navigator.of(context).pop()`

### Files touched
- `lib/screens/settings_screen.dart` — add `_CurrencySheet`, update tap handler
- `lib/screens/currency_picker_screen.dart` — no changes (kept for potential future use)

---

## 2. Premium Section Row in Settings

### Position
After the "Preferences" section, before the "Account & Data" section.

### Layout
```
SectionLabel: "PREMIUM"
_SettingsCard:
  _SettingsTappableRow:
    icon:    LucideIcons.sparkles
    label:   "WLLT Premium"
    value:   "${daysLeft}d left"    ← computed from static trial end date
    onTap:   _showPremiumSheet(context)
  Divider (outlineVariant, indent/endIndent: 16)
  _SettingsReadOnlyRow:
    icon:    LucideIcons.scanLine
    label:   "Bill scanning"
    value:   "Available"
```

### Data
- `daysLeft` is computed locally: `const _kTrialEndDate = DateTime(2026, 5, 14)` → `_kTrialEndDate.difference(DateTime.now()).inDays`
- No new provider or persistence required

---

## 3. Premium Popup Sheet

### Trigger
`_showPremiumSheet(BuildContext context)` — top-level method on `SettingsScreen`.

### Mechanism
`showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`, `backgroundColor: Colors.transparent`

### Widget: `_PremiumSheet` (private `StatelessWidget`)

#### Structure
```
ClipRRect (borderRadius: vertical top 32)
└── ColoredBox (colorScheme.surface)
    ├── Gradient Header (fixed height ~184px)
    │   ├── Decorative circles (rgba white 0.05)
    │   ├── Close button — top-right 32×32 circle (rgba white 0.15), LucideIcons.x
    │   ├── 56×56 wallet icon container (rgba white 0.2, borderRadius 16)
    │   ├── "WLLT Premium" — 24px, white, tracking -0.6
    │   └── "30 days left in your free trial." — 13px, white 60%
    └── SingleChildScrollView (padding: 24h, 20v)
        ├── "WHAT'S INCLUDED" label — AppTheme.trackingWide, onSurfaceVariant
        ├── Column of 5 _PremiumFeatureRow items (gap 12):
        │     [scanLine]   "Bill & receipt scanning with AI"   + "Most used" badge
        │     [lightbulb]  "Smart insights & spend predictions"
        │     [barChart2]  "Advanced analytics & export"
        │     [tag]        "Unlimited categories & budgets"
        │     [volume2Off] "No ads"
        ├── SizedBox(20)
        ├── Pricing card — Container with border (2px, colorScheme.primary),
        │   borderRadius 16, dark bg (surfaceContainerHighest):
        │     Row:
        │       Left col: "Monthly" (16px onSurface) + "Cancel any time" (12px onSurfaceVariant)
        │       Right col: "$4.99" (22px, colorScheme.primary, tracking -0.55) + "per month" (11px)
        ├── SizedBox(12)
        └── CTA button — full-width pill (56px tall), bg = colorScheme.onSurface,
              LucideIcons.arrowRight (18px, colorScheme.surface) + "Upgrade Now — $4.99/mo"
              (15px, colorScheme.surface)
```

#### `_PremiumFeatureRow` (private `StatelessWidget`)
Props: `icon`, `label`, `badge` (optional String).
- 32×32 icon container (colorScheme.secondaryContainer, borderRadius 14)
- Label text (14px, onSurface)
- Optional badge: small pill (colorScheme.primaryContainer, 19px tall) with label text (10px, onPrimaryContainer)

### Gradient
`LinearGradient(begin: topLeft, end: bottomRight, colors: [Color(0xFF1A1130), Color(0xFF4F378B), Color(0xFF7A65C4)])`

---

## Implementation Notes

- All new widgets are private (underscore-prefixed) and live in `settings_screen.dart`
- No new files needed
- No changes to providers, routes, or other screens
- `_CurrencySheet` can reuse `_CurrencyRow` from `currency_picker_screen.dart` by importing it — or inline a minimal version. Prefer importing to avoid duplication.
- The `CurrencyPickerScreen` class is **not deleted** — importing `_CurrencyRow` from it requires it to be public. Since `_CurrencyRow` is currently private (underscore), inline a `_SheetCurrencyRow` in `settings_screen.dart` using the same visual logic.
