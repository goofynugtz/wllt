# Budget Feature Design
Date: 2026-05-18

## Overview

Per-category spending budgets with monthly or weekly periods. Users set a limit from inside the category detail screen. The app shows a progress bar (spent vs limit) that turns red when over budget. No notifications. Resets clean each period.

---

## Data Model

### `BudgetPeriod` enum

```dart
enum BudgetPeriod { monthly, weekly }
```

### `Budget` class (extends existing)

```dart
class Budget {
  final String categoryId;
  final double amount;
  final BudgetPeriod period; // NEW — replaces legacy `budget` field name
}
```

- `toJson`: serializes `period` as `'monthly'` or `'weekly'`
- `fromJson`: deserializes with fallback to `BudgetPeriod.monthly` if field absent (backward compat with existing dummy data)
- Existing `Budget.budgets` static dummy list: all entries get `period: BudgetPeriod.monthly`
- The old field name `budget` is renamed to `amount` for clarity

---

## Storage

New Hive box: `'budgets'`

Key: `categoryId` (String) → one budget per category, upsert semantics.

Methods added to `StorageService`:

```dart
static const String _budgetsBox = 'budgets';

List<Budget> getBudgets()
Future<void> saveBudget(Budget budget)     // put(categoryId, budget.toJson())
Future<void> deleteBudget(String categoryId) // delete(categoryId)
```

Box opened in `StorageService.init()`. No data migration — box starts empty; users set budgets fresh.

`clearAll()` also clears the budgets box.

---

## BudgetProvider

New `ChangeNotifier` at `lib/providers/budget_provider.dart`.

```dart
class BudgetProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _devMode;
  late List<Budget> _budgets;

  BudgetProvider(this._storage, {required bool devMode});

  List<Budget> get budgets
  Budget? budgetFor(String categoryId)
  Future<void> setBudget(Budget budget)      // upsert + notifyListeners
  Future<void> deleteBudget(String categoryId)

  // Computes spend for the category's current period window
  double spentInPeriod(String categoryId, List<Transaction> txs)
}
```

### `spentInPeriod` logic

- Fetch `budget = budgetFor(categoryId)`. If null, return 0.
- Filter `txs` to: `type == expense`, `categoryId` matches.
- **monthly**: `date.year == now.year && date.month == now.month`
- **weekly**: `date >= startOfCurrentWeek && date <= endOfCurrentWeek` (Monday–Sunday, derived from `DateTime.now()`)
- Sum `amount` of filtered transactions. Return total.

Dev mode: `_budgets` initialized from `Budget.budgets` static list. Real mode: from `_storage.getBudgets()`.

Registered in `main.dart` via `MultiProvider` alongside `TransactionProvider` and `AccountProvider`.

---

## UI — CategoryDetailScreen

### Budget status bar

Shown in the category header when `budgetProvider.budgetFor(category.id) != null`.

Layout:
```
[spent label]        [limit label]
[━━━━━━━━━━━░░░░]   (LinearProgressIndicator)
"₹1,200 of ₹3,000 this month"
```

- Progress value: `min(spent / limit, 1.0)` (clamped so bar never exceeds 100%)
- Color: `colorScheme.primary` when under budget, `colorScheme.error` when `spent >= limit`
- Period label: `"this month"` or `"this week"`

### Budget chip

Positioned below the header row, above the transaction list.

- **No budget set**: chip reads `"+ Set budget"` with a subtle outline style
- **Budget exists**: chip reads `"₹X / month"` or `"₹X / week"`, filled style using category accent color
- Tapping either opens the budget bottom sheet

### Budget bottom sheet

`showModalBottomSheet` — not a new route/screen.

Contents:
1. **Amount field** — `TextField` with `TextInputType.numberWithOptions(decimal: true)`, pre-filled if editing
2. **Period toggle** — `SegmentedButton` with two segments: `Monthly` / `Weekly`
3. **Save button** — calls `budgetProvider.setBudget(...)`, closes sheet
4. **"Remove budget" text button** — visible only when editing an existing budget; calls `budgetProvider.deleteBudget(...)`, closes sheet

Validation: amount must be > 0 to enable Save.

---

## Wire-up

`main.dart`:
- Open `'budgets'` Hive box in `StorageService.init()`
- Add `ChangeNotifierProvider<BudgetProvider>` to `MultiProvider`
- `BudgetProvider` depends on `StorageService` and `devMode` — same pattern as `TransactionProvider`

`CategoryDetailScreen`:
- `context.watch<BudgetProvider>()` for reactive updates
- `context.watch<TransactionProvider>()` already present — pass `.transactions` to `spentInPeriod`

---

## Out of scope

- Budget history / trend over past periods
- Push notifications on overspend
- Budget rollover
- Per-account budgets
- Budgets screen / overview across all categories
