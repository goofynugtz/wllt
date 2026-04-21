# Settings — Currency Sheet & Premium Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the full-screen currency picker with a bottom sheet and add a Premium section (with a popup sheet) to the settings screen.

**Architecture:** All new code lives in `settings_screen.dart` as private widgets. `_CurrencySheet` wraps the currency picker logic in a `showModalBottomSheet`. `_PremiumSheet` is a separate modal bottom sheet with a gradient header and feature list. No new files, no provider changes.

**Tech Stack:** Flutter, Provider, `lucide_icons`, `country_flags`, existing `UserPreferencesProvider`, existing `CurrencyInfo` model from `lib/data/currencies.dart`.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/screens/settings_screen.dart` | Modify | Add `_CurrencySheet`, `_SheetCurrencyRow`, `_PremiumSheet`, `_PremiumFeatureRow`; update scroll view and tap handlers |
| `lib/screens/currency_picker_screen.dart` | Read-only | Reference for `_CurrencyRow` visual logic — **do not modify** |

---

### Task 1: Add `_SheetCurrencyRow` widget

`_CurrencyRow` in `currency_picker_screen.dart` is private. Inline a visually identical `_SheetCurrencyRow` in `settings_screen.dart`.

**Files:**
- Modify: `lib/screens/settings_screen.dart` — append at bottom of file

- [ ] **Step 1: Append `_SheetCurrencyRow` to `settings_screen.dart`**

Add after the last class in the file (after `_ColorSwatch`):

```dart
// ── Currency sheet row ────────────────────────────────────────────────────────

class _SheetCurrencyRow extends StatelessWidget {
  final CurrencyInfo currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _SheetCurrencyRow({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CountryFlag.fromCountryCode(
              currency.countryCode,
              height: 24,
              width: 34,
              shape: const RoundedRectangle(4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${currency.code} · ${currency.symbol} · ${currency.country}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.check,
                  size: 14,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add missing imports to `settings_screen.dart`**

At the top of the file, add these imports (after existing imports):

```dart
import 'package:country_flags/country_flags.dart';
import '../data/currencies.dart';
```

- [ ] **Step 3: Hot-reload and confirm no compile errors**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: no errors

---

### Task 2: Add `_CurrencySheet` stateful widget

**Files:**
- Modify: `lib/screens/settings_screen.dart` — append after `_SheetCurrencyRow`

- [ ] **Step 1: Append `_CurrencySheet` to `settings_screen.dart`**

```dart
// ── Currency bottom sheet ─────────────────────────────────────────────────────

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet();

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  String _query = '';
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = context.read<UserPreferencesProvider>().currency;
  }

  List<CurrencyInfo> get _filtered {
    if (_query.isEmpty) return kCurrencies;
    final q = _query.toLowerCase();
    return kCurrencies
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _select(String code) async {
    setState(() => _selectedCode = code);
    await context.read<UserPreferencesProvider>().setCurrency(code);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Currency',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search currencies...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.searchX,
                          size: 36,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No results for "$_query"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return _SheetCurrencyRow(
                        currency: c,
                        isSelected: c.code == _selectedCode,
                        onTap: () => _select(c.code),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: no errors

---

### Task 3: Wire currency sheet into settings

Replace the `Navigator.push` call in `_buildPreferencesCard`.

**Files:**
- Modify: `lib/screens/settings_screen.dart:318-325` (the Currency `_SettingsTappableRow` `onTap`)

- [ ] **Step 1: Update the Currency row's `onTap` in `_buildPreferencesCard`**

Find this block (around line 318):
```dart
_SettingsTappableRow(
  icon: LucideIcons.dollarSign,
  label: 'Currency',
  value: prefs.currency,
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CurrencyPickerScreen()),
  ),
),
```

Replace with:
```dart
_SettingsTappableRow(
  icon: LucideIcons.dollarSign,
  label: 'Currency',
  value: prefs.currency,
  onTap: () => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<UserPreferencesProvider>(),
      child: const _CurrencySheet(),
    ),
  ),
),
```

- [ ] **Step 2: Remove now-unused import of `CurrencyPickerScreen` if settings screen is the only caller**

Check if `CurrencyPickerScreen` is still imported in `settings_screen.dart`. If so, keep the import (it doesn't hurt). Only remove if Dart analyzer warns "unused import".

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: no errors (import warning acceptable to address)

- [ ] **Step 3: Hot-reload and manually verify**

- Tap "Currency" in Settings → bottom sheet opens from bottom ✓
- Search for "USD" → list filters ✓
- Tap a currency → sheet closes, value updates in row ✓

---

### Task 4: Add `_PremiumFeatureRow` widget

**Files:**
- Modify: `lib/screens/settings_screen.dart` — append after `_CurrencySheet`

- [ ] **Step 1: Append `_PremiumFeatureRow`**

```dart
// ── Premium feature row ───────────────────────────────────────────────────────

class _PremiumFeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;

  const _PremiumFeatureRow({
    required this.icon,
    required this.label,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            height: 19,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: no errors

---

### Task 5: Add `_PremiumSheet` widget

**Files:**
- Modify: `lib/screens/settings_screen.dart` — append after `_PremiumFeatureRow`

- [ ] **Step 1: Define the trial constant near the top of the file**

Add after the `_kColorSchemes` const (around line 77), before `class SettingsScreen`:

```dart
// Trial end date — static placeholder until subscription backend is wired
const _kTrialEndDate = DateTime(2026, 5, 14);
```

- [ ] **Step 2: Append `_PremiumSheet`**

```dart
// ── Premium upgrade sheet ─────────────────────────────────────────────────────

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet();

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1130), Color(0xFF4F378B), Color(0xFF7A65C4)],
  );

  @override
  Widget build(BuildContext context) {
    final daysLeft = _kTrialEndDate.difference(DateTime.now()).inDays;
    final trialLabel = daysLeft > 0
        ? '$daysLeft days left in your free trial.'
        : 'Your free trial has ended.';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header
            SizedBox(
              height: 184,
              child: Stack(
                children: [
                  // Gradient background
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(gradient: _gradient),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    right: -22,
                    top: -40,
                    child: Container(
                      width: 176,
                      height: 176,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -32,
                    top: 31,
                    child: Container(
                      width: 208,
                      height: 208,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    left: 24,
                    top: 24,
                    right: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            LucideIcons.wallet,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'WLLT Premium',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trialLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0x99FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "WHAT'S INCLUDED",
                    style: AppTheme.trackingWide.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PremiumFeatureRow(
                    icon: LucideIcons.scanLine,
                    label: 'Bill & receipt scanning with AI',
                    badge: 'Most used',
                  ),
                  const SizedBox(height: 12),
                  const _PremiumFeatureRow(
                    icon: LucideIcons.lightbulb,
                    label: 'Smart insights & spend predictions',
                  ),
                  const SizedBox(height: 12),
                  const _PremiumFeatureRow(
                    icon: LucideIcons.barChart2,
                    label: 'Advanced analytics & export',
                  ),
                  const SizedBox(height: 12),
                  const _PremiumFeatureRow(
                    icon: LucideIcons.tag,
                    label: 'Unlimited categories & budgets',
                  ),
                  const SizedBox(height: 12),
                  const _PremiumFeatureRow(
                    icon: LucideIcons.volumeX,
                    label: 'No ads',
                  ),
                  const SizedBox(height: 20),
                  // Pricing card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cancel any time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$4.99',
                              style: TextStyle(
                                fontSize: 22,
                                letterSpacing: -0.55,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              'per month',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.onSurface,
                        foregroundColor: Theme.of(context).colorScheme.surface,
                        shape: const StadiumBorder(),
                        elevation: 4,
                      ),
                      icon: const Icon(LucideIcons.arrowRight, size: 18),
                      label: const Text(
                        'Upgrade Now — \$4.99/mo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: no errors

---

### Task 6: Wire premium section into `SettingsScreen`

Add `_showPremiumSheet` method and `_buildPremiumCard` builder, then insert the section in the scroll view.

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add `_showPremiumSheet` and `_buildPremiumCard` to `SettingsScreen`**

Inside the `SettingsScreen` class body, add these two methods after `_buildPreferencesCard`:

```dart
void _showPremiumSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PremiumSheet(),
  );
}

Widget _buildPremiumCard(BuildContext context) {
  final daysLeft = _kTrialEndDate.difference(DateTime.now()).inDays;
  return _SettingsCard(
    child: Column(
      children: [
        _SettingsTappableRow(
          icon: LucideIcons.sparkles,
          label: 'WLLT Premium',
          value: '${daysLeft}d left',
          onTap: () => _showPremiumSheet(context),
        ),
        Divider(
          height: 0.5,
          color: Theme.of(context).colorScheme.outlineVariant,
          indent: 16,
          endIndent: 16,
        ),
        const _SettingsReadOnlyRow(
          icon: LucideIcons.scanLine,
          label: 'Bill scanning',
          value: 'Available',
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Insert the Premium section in the `build` scroll view**

In `SettingsScreen.build`, find the block that builds the "Preferences" section and ends before "Account & Data":

```dart
SliverToBoxAdapter(child: _buildSectionLabel(context, 'Preferences')),
const SliverToBoxAdapter(child: SizedBox(height: 8)),
SliverToBoxAdapter(child: _buildPreferencesCard(context, prefs)),
const SliverToBoxAdapter(child: SizedBox(height: 24)),
SliverToBoxAdapter(child: _buildSectionLabel(context, 'Account & Data')),
```

Replace with:

```dart
SliverToBoxAdapter(child: _buildSectionLabel(context, 'Preferences')),
const SliverToBoxAdapter(child: SizedBox(height: 8)),
SliverToBoxAdapter(child: _buildPreferencesCard(context, prefs)),
const SliverToBoxAdapter(child: SizedBox(height: 24)),
SliverToBoxAdapter(child: _buildSectionLabel(context, 'Premium')),
const SliverToBoxAdapter(child: SizedBox(height: 8)),
SliverToBoxAdapter(child: _buildPremiumCard(context)),
const SliverToBoxAdapter(child: SizedBox(height: 24)),
SliverToBoxAdapter(child: _buildSectionLabel(context, 'Account & Data')),
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: no errors

- [ ] **Step 4: Hot-reload and manually verify**

**Currency sheet:**
- Settings → tap "Currency" → bottom sheet slides up ✓
- Search works ✓  
- Selecting a currency closes sheet and updates row value ✓

**Premium section:**
- "PREMIUM" section label visible between Preferences and Account & Data ✓
- Row 1: "WLLT Premium" + "Xd left" badge ✓
- Row 2: "Bill scanning" + "Available" (read-only, no chevron) ✓

**Premium sheet:**
- Tap "WLLT Premium" row → sheet slides up ✓
- Gradient purple header with wallet icon, title, trial label ✓
- Feature list with "Most used" badge on first item ✓
- Monthly pricing card with border ✓
- "Upgrade Now" CTA button ✓
- Close button (✕) dismisses sheet ✓
- Dark mode: gradient stays, body adapts to `colorScheme.surface` ✓

---

## Self-Review

**Spec coverage:**
- ✅ Currency: bottom sheet with search + list
- ✅ Premium section: label, tappable row with daysLeft, read-only bill scanning row
- ✅ Premium popup: gradient header, feature list, pricing card, CTA, close button
- ✅ `_kTrialEndDate` static constant

**Placeholder scan:** None found.

**Type consistency:**
- `_kTrialEndDate` defined in Task 5 Step 1, referenced in `_PremiumSheet.build` (Task 5 Step 2) and `_buildPremiumCard` (Task 6 Step 1) — consistent ✓
- `_PremiumFeatureRow` defined in Task 4, used in Task 5 — consistent ✓
- `_SheetCurrencyRow` defined in Task 1, used in Task 2 — consistent ✓
- `_CurrencySheet` defined in Task 2, called in Task 3 — consistent ✓
- `_PremiumSheet` defined in Task 5, called in Task 6 — consistent ✓
