# Budget Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-category spending budgets (monthly or weekly) with a progress bar and edit chip in CategoryDetailScreen.

**Architecture:** Extend the `Budget` model with a `BudgetPeriod` enum and persistence via a new Hive box. A new `BudgetProvider` (proxy-provider pattern, mirrors `TransactionProvider`) manages CRUD. `CategoryDetailScreen` replaces its static `Budget.budgets` lookup with the provider and gains a chip + bottom sheet for setting/editing budgets.

**Tech Stack:** Flutter, Hive (existing), Provider (existing), Material 3 `SegmentedButton`, `showModalBottomSheet`

---

## File Map

| Action | File |
|--------|------|
| Modify | `lib/models/models.dart` |
| Modify | `lib/services/storage_service.dart` |
| Create | `lib/providers/budget_provider.dart` |
| Modify | `lib/main.dart` |
| Modify | `lib/screens/category_detail_screen.dart` |

---

## Task 1: Extend Budget model

**Files:**
- Modify: `lib/models/models.dart:860-873`

### What changes
- Add `BudgetPeriod` enum above the `Budget` class
- Rename field `budget` → `amount`
- Add `period` field
- Add `toJson` / `fromJson`
- Update the static `Budget.budgets` dummy list

- [ ] **Step 1: Replace the Budget class in `lib/models/models.dart`**

Find and replace the entire `Budget` class block (lines 860–873):

```dart
// BEFORE:
class Budget {
  final String categoryId;
  final double budget;

  const Budget({required this.categoryId, required this.budget});

  static const List<Budget> budgets = [
    Budget(categoryId: 'restaurant', budget: 3000),
    Budget(categoryId: 'groceries', budget: 5000),
    Budget(categoryId: 'transport', budget: 2000),
    Budget(categoryId: 'movies', budget: 2000),
    Budget(categoryId: 'shopping', budget: 5000),
    Budget(categoryId: 'utilities', budget: 2500),
  ];
}
```

```dart
// AFTER (replace the whole block):
enum BudgetPeriod { monthly, weekly }

class Budget {
  final String categoryId;
  final double amount;
  final BudgetPeriod period;

  const Budget({
    required this.categoryId,
    required this.amount,
    required this.period,
  });

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'amount': amount,
    'period': period.name,
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    categoryId: json['categoryId'] as String,
    amount: (json['amount'] as num).toDouble(),
    period: BudgetPeriod.values.firstWhere(
      (p) => p.name == json['period'],
      orElse: () => BudgetPeriod.monthly,
    ),
  );

  static const List<Budget> budgets = [
    Budget(categoryId: 'restaurant', amount: 3000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'groceries',  amount: 5000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'transport',  amount: 2000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'movies',     amount: 2000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'shopping',   amount: 5000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'utilities',  amount: 2500, period: BudgetPeriod.monthly),
  ];
}
```

- [ ] **Step 2: Verify app still compiles**

Run:
```
flutter analyze lib/models/models.dart
```
Expected: no errors. If `budget.budget` references appear in other files, they will be caught here and fixed in Task 5.

---

## Task 2: Extend StorageService with budgets box

**Files:**
- Modify: `lib/services/storage_service.dart`

- [ ] **Step 1: Add box field and key constant**

After line `late Box _accounts;` add:
```dart
late Box _budgets;
```

After `static const String _accountsBox = 'accounts';` add:
```dart
static const String _budgetsBox = 'budgets';
```

- [ ] **Step 2: Open the box in `init()`**

Inside `init()`, after `_accounts = await Hive.openBox(_accountsBox);` add:
```dart
_budgets = await Hive.openBox(_budgetsBox);
```

- [ ] **Step 3: Add CRUD methods**

Add after the `deleteAccount` method:
```dart
// ── Budgets ───────────────────────────────────────────────────────────
List<Budget> getBudgets() {
  return _budgets.values
      .map((v) => Budget.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList();
}

Future<void> saveBudget(Budget budget) =>
    _budgets.put(budget.categoryId, budget.toJson());

Future<void> deleteBudget(String categoryId) => _budgets.delete(categoryId);
```

- [ ] **Step 4: Clear budgets in `clearAll()`**

Inside `clearAll()`, add:
```dart
await _budgets.clear();
```

- [ ] **Step 5: Verify**

```
flutter analyze lib/services/storage_service.dart
```
Expected: no errors.

---

## Task 3: Create BudgetProvider

**Files:**
- Create: `lib/providers/budget_provider.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class BudgetProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _devMode;
  late List<Budget> _budgets;

  BudgetProvider(this._storage, {required bool devMode}) : _devMode = devMode {
    _budgets = _devMode
        ? List<Budget>.from(Budget.budgets)
        : _storage.getBudgets();
  }

  List<Budget> get budgets => List.unmodifiable(_budgets);

  Budget? budgetFor(String categoryId) =>
      _budgets.cast<Budget?>().firstWhere(
        (b) => b?.categoryId == categoryId,
        orElse: () => null,
      );

  Future<void> setBudget(Budget budget) async {
    if (!_devMode) await _storage.saveBudget(budget);
    _budgets.removeWhere((b) => b.categoryId == budget.categoryId);
    _budgets.add(budget);
    notifyListeners();
  }

  Future<void> deleteBudget(String categoryId) async {
    if (!_devMode) await _storage.deleteBudget(categoryId);
    _budgets.removeWhere((b) => b.categoryId == categoryId);
    notifyListeners();
  }

  void reloadIfNeeded(bool newDevMode) {
    if (_devMode == newDevMode) return;
    _devMode = newDevMode;
    _budgets = _devMode
        ? List<Budget>.from(Budget.budgets)
        : _storage.getBudgets();
    notifyListeners();
  }
}
```

- [ ] **Step 2: Verify**

```
flutter analyze lib/providers/budget_provider.dart
```
Expected: no errors.

---

## Task 4: Register BudgetProvider in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import**

After `import 'providers/account_provider.dart';` add:
```dart
import 'providers/budget_provider.dart';
```

- [ ] **Step 2: Add to MultiProvider**

Inside `MultiProvider.providers`, after the `AccountProvider` proxy provider block, add:
```dart
ChangeNotifierProxyProvider<AppSettingsProvider, BudgetProvider>(
  create: (_) => BudgetProvider(storage, devMode: storage.devMode),
  update: (_, settings, prev) => prev!..reloadIfNeeded(settings.devMode),
),
```

- [ ] **Step 3: Verify full app compiles**

```
flutter analyze lib/main.dart
```
Expected: no errors.

---

## Task 5: Update CategoryDetailScreen

**Files:**
- Modify: `lib/screens/category_detail_screen.dart`

### Overview of changes
1. Add import for `BudgetProvider`
2. Remove static `Budget.budgets` lookup; replace with provider
3. Compute `budgetSpent` with currency conversion + period logic
4. Update progress bar: use `budget.amount`, add period label, red on over-budget
5. Remove "No budget set · edit to add one" fallback text (chip handles CTA)
6. Add budget chip (Set / Edit) after "Spent so far" card
7. Add `_BudgetBottomSheet` private widget at end of file

- [ ] **Step 1: Add import for BudgetProvider**

At the top of the file, after existing provider imports, add:
```dart
import '../providers/budget_provider.dart';
```

- [ ] **Step 2: Replace static budget lookup with provider**

Find (around line 162):
```dart
    final budget = Budget.budgets.cast<Budget?>().firstWhere(
          (b) => b?.categoryId == _category.id,
          orElse: () => null,
        );
```

Replace with:
```dart
    final budgetProvider = context.watch<BudgetProvider>();
    final budget = budgetProvider.budgetFor(_category.id);
```

- [ ] **Step 3: Add `budgetSpent` computation**

Directly after the two lines added in Step 2, add:
```dart
    double budgetSpent = 0;
    if (budget != null) {
      final now = DateTime.now();
      if (budget.period == BudgetPeriod.monthly) {
        final currentMonthTxs = _monthTransactions(allTransactions, now.year, now.month);
        budgetSpent = currentMonthTxs.fold(
          0.0,
          (sum, t) => sum + _converted(t, currencyCode, convertHistory),
        );
      } else {
        final weekStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        budgetSpent = allTransactions
            .where((t) =>
                t.categoryId == _category.id &&
                t.type == TransactionType.expense &&
                !t.date.isBefore(weekStart) &&
                t.date.isBefore(weekEnd))
            .fold(0.0, (sum, t) => sum + _converted(t, currencyCode, convertHistory));
      }
    }
```

- [ ] **Step 4: Update the progress bar block inside "Spent so far" card**

Find:
```dart
                        if (budget != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (totalSpent / budget.budget).clamp(0.0, 1.0),
                              backgroundColor: _accentColor.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(_accentColor),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$currencySymbol${totalSpent.toStringAsFixed(0)} of $currencySymbol${budget.budget.toStringAsFixed(0)} budget',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ] else
                          Text(
                            'No budget set · edit to add one',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
```

Replace with:
```dart
                        if (budget != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (budgetSpent / budget.amount).clamp(0.0, 1.0),
                              backgroundColor: _accentColor.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(
                                budgetSpent >= budget.amount ? cs.error : _accentColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$currencySymbol${budgetSpent.toStringAsFixed(0)} of $currencySymbol${budget.amount.toStringAsFixed(0)} ${budget.period == BudgetPeriod.monthly ? 'this month' : 'this week'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: budgetSpent >= budget.amount
                                  ? cs.error
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
```

- [ ] **Step 5: Add the budget chip after "Spent so far" card**

Find:
```dart
                  const SizedBox(height: 12),

                  // 3 mini stat cards
```

Insert before those lines:
```dart
                  const SizedBox(height: 10),

                  // Budget chip
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => _BudgetBottomSheet(
                        category: _category,
                        existing: budget,
                        budgetProvider: budgetProvider,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: budget != null
                            ? _accentColor.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: budget != null ? _accentColor : cs.outlineVariant,
                        ),
                      ),
                      child: Text(
                        budget != null
                            ? '$currencySymbol${budget.amount.toStringAsFixed(0)} / ${budget.period == BudgetPeriod.monthly ? 'month' : 'week'}'
                            : '+ Set budget',
                        style: TextStyle(
                          fontSize: 13,
                          color: budget != null ? _accentColor : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3 mini stat cards
```

- [ ] **Step 6: Add `_BudgetBottomSheet` widget**

After the closing `}` of the `_CategoryHeroDelegate` class (at the very end of the file), add:

```dart
// ── Budget Bottom Sheet ────────────────────────────────────────────────────

class _BudgetBottomSheet extends StatefulWidget {
  final Category category;
  final Budget? existing;
  final BudgetProvider budgetProvider;

  const _BudgetBottomSheet({
    required this.category,
    required this.existing,
    required this.budgetProvider,
  });

  @override
  State<_BudgetBottomSheet> createState() => _BudgetBottomSheetState();
}

class _BudgetBottomSheetState extends State<_BudgetBottomSheet> {
  late final TextEditingController _amountCtrl;
  late BudgetPeriod _period;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.amount.toStringAsFixed(0)
          : '',
    );
    _period = widget.existing?.period ?? BudgetPeriod.monthly;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final v = double.tryParse(_amountCtrl.text);
    return v != null && v > 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null ? 'Edit Budget' : 'Set Budget',
            style: TextStyle(fontSize: 18, color: cs.onSurface),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Limit amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<BudgetPeriod>(
            segments: const [
              ButtonSegment(
                value: BudgetPeriod.monthly,
                label: Text('Monthly'),
              ),
              ButtonSegment(
                value: BudgetPeriod.weekly,
                label: Text('Weekly'),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave
                  ? () {
                      widget.budgetProvider.setBudget(Budget(
                        categoryId: widget.category.id,
                        amount: double.parse(_amountCtrl.text),
                        period: _period,
                      ));
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('Save'),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  widget.budgetProvider.deleteBudget(widget.category.id);
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: cs.error),
                child: const Text('Remove budget'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Verify full project compiles**

```
flutter analyze lib/
```
Expected: no errors.

- [ ] **Step 8: Smoke test on device/emulator**

1. Open any category detail screen in dev mode — budget bar + chip should appear (pre-populated from `Budget.budgets` static list)
2. Tap chip — bottom sheet opens with pre-filled amount and Monthly selected
3. Change amount, switch to Weekly, tap Save — chip updates to "₹X / week"
4. Tap chip again — "Remove budget" button visible
5. Open a category with no budget in static list (e.g. Education) — chip shows "+ Set budget", no progress bar
6. Set a budget for it — bar appears, chip updates
7. Spend > limit in dev mode for a category — bar turns red

---

## Self-Review

**Spec coverage:**
- ✅ Budget set inside category detail screen (chip + bottom sheet)
- ✅ User chooses monthly or weekly per-category (SegmentedButton)
- ✅ No notifications — visual only (progress bar + red color)
- ✅ Resets clean each period — `budgetSpent` computed fresh from current-period transactions
- ✅ Budget persisted to Hive (real mode) / static list (dev mode)
- ✅ `clearAll()` clears budgets box

**Placeholder scan:** None found — all steps have complete code.

**Type consistency:**
- `Budget.amount` used consistently across all tasks (renamed from `budget`)
- `BudgetPeriod` enum used in model, provider, and screen uniformly
- `budgetProvider.budgetFor()` return type is `Budget?` — nullability handled in all call sites
- `_BudgetBottomSheet` receives `BudgetProvider` directly (not via context) to work inside modal sheet
