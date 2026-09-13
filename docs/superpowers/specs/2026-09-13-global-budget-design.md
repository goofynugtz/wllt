# Global Budget Design
Date: 2026-09-13

## Overview

A global monthly spending cap, set once, that per-category budgets ([[2026-05-18-budget-design]]) allocate out of. Category budgets may not sum past the global cap. Surfaced via a new "Budgets" tab and a tap-through from the home screen's overview card. No changes to how individual category budgets are edited (still `CategoryDetailScreen`).

---

## Data Model — reuse, no schema change

Global budget is stored as an ordinary `Budget` row with a sentinel `categoryId`, in the same Hive `'budgets'` box category budgets already use.

```dart
class BudgetProvider {
  static const String globalBudgetId = '__global__';

  Budget? get globalBudget => budgetFor(globalBudgetId);

  // All real (non-sentinel) category budgets.
  List<Budget> get categoryBudgets =>
      _budgets.where((b) => b.categoryId != globalBudgetId).toList();

  Future<void> setGlobalBudget(double amount) => setBudget(
      Budget(categoryId: globalBudgetId, amount: amount, period: BudgetPeriod.monthly));

  Future<void> deleteGlobalBudget() => deleteBudget(globalBudgetId);

  // Weekly budgets normalized to a monthly figure for cap math.
  static double monthlyEquivalent(Budget b) =>
      b.period == BudgetPeriod.weekly ? b.amount * 4.33 : b.amount;
}
```

No changes to `Budget`, `StorageService`, or the Hive box. `Budget.budgets` (the static dev-mode seed list) is untouched — the sentinel is only ever added at runtime through the provider.

Existing code that reads `budgetProvider.budgets` (currently none outside `BudgetProvider` itself) is unaffected; new UI code must use `categoryBudgets` to avoid rendering the sentinel as a category row.

---

## Allocation cap

Enforced in `category_detail_screen.dart`'s `_BudgetBottomSheetState`, at save time:

1. `global = budgetProvider.globalBudget` — if null, no cap, unchanged behavior.
2. `otherAllocated = sum(monthlyEquivalent(b) for b in categoryBudgets if b.categoryId != this category)`.
3. `remaining = global.amount - otherAllocated`.
4. `newMonthlyEquiv = period == weekly ? amount * 4.33 : amount`.
5. If `newMonthlyEquiv > remaining`: Save button disabled, inline error text `"Only ₹{remaining} left of global budget"` shown under the amount field.

Editing an existing budget naturally excludes its own prior value (filtered out by category id in step 2).

---

## New screen — `lib/screens/budgets_screen.dart`

Takes `selectedMonth` (same as `HomeScreen`/`TransactionsScreen`).

**Global budget card** (top)
- Set: amount, this-month total spend (all expense categories, currency-converted same as home screen), progress bar (red past 100%, same convention as category bars).
- Unset: "Set a monthly budget" CTA.
- Tap → small bottom sheet, amount field only (no period selector — global is always monthly), Save / Remove.

**Category allocations list**
- One row per active expense category: icon, name, allocated amount (or "No budget set"), spent this month, mini progress bar where allocated.
- Row tap → `Navigator.push(CategoryDetailScreen(category: cat))` — editing stays where it already lives.
- Footer line: unallocated remainder = `global.amount - sum(monthlyEquivalent(categoryBudgets))`, hidden if no global budget set.

---

## Nav wiring — `layout_screen.dart`

- Tab order becomes: Home, History, **Budgets**, Accounts, Settings.
- `_navItems`: new entry `NavItem(icon: LucideIcons.pieChart, label: 'Budgets')` at index 2.
- `_buildPages()`: insert `BudgetsScreen(selectedMonth: _selectedMonth)` at index 2.
- Title array (`_buildTopHeader`): `['', 'Transactions', 'Budgets', 'Accounts', 'Settings']`.
- `showMonthPicker`: `_currentIndex <= 2` (was `<= 1`).
- `_buildFab()`: index 4 (Settings) → `null`; index 3 (Accounts) → add-account FAB; index 2 (Budgets) → `null` (no FAB — it's a dashboard, not an add-transaction surface); else (0, 1) → add-transaction FAB.

---

## Home screen tap-through — `home_screen.dart`

- New `onNavigateToBudgets` callback prop, wired by `LayoutScreen` to `_navigateToTab(2)`.
- The budget-bar block inside `_buildBalanceCard` (both the "has budget" progress bar and the "No budgets configured" hint) wrapped in a `GestureDetector` calling it — tappable in either state.
- `Helpers.monthlyBudget` const usages (4 call sites) replaced with `context.watch<BudgetProvider>().globalBudget?.amount`. `hasBudget` becomes `globalAmount != null && globalAmount > 0` — the existing "No budgets configured" branch (currently dead code, since the const was always > 0) becomes reachable.
- `Helpers.monthlyBudget` const deleted — those 4 call sites were its only references repo-wide.

---

## Out of scope

- `insight_facts.dart`'s `budgetLimits` map, which reads the static `Budget.budgets` seed list rather than live provider data — pre-existing inconsistency, untouched here.
- Notifications on exceeding the global cap or a category allocation.
- Budget history/trend across past months.
- Envelope-style redistribution when one category budget changes.
- Widget tests for the new `BudgetsScreen` — repo's existing test suite (`test/`) covers providers/services/models, not widget trees for screens like this; this plan adds a provider-level test (`BudgetProvider` cap math) and leaves screen-level verification to `flutter analyze` + manual run.
