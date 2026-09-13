# Global Budget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single global monthly spending cap that category budgets allocate out of, surfaced through a new "Budgets" tab and a tap-through from the home screen's overview card.

**Architecture:** The global budget is stored as an ordinary `Budget` row with a sentinel `categoryId` (`'__global__'`) in the existing `budgets` Hive box — no new storage, no schema change. `BudgetProvider` grows a handful of pure functions (`globalBudget`, `categoryBudgets`, `monthlyEquivalent`, `remainingGlobalBudget`) that both the new Budgets screen and the existing per-category budget sheet call into for the allocation-cap check.

**Tech Stack:** Flutter, Provider (`ChangeNotifier`), Hive (existing `budgets` box), `flutter_test` (existing suite convention — see `test/providers/app_settings_provider_test.dart`).

**Spec:** `docs/superpowers/specs/2026-09-13-global-budget-design.md`

## Global Constraints

- No new Hive boxes, no changes to `Budget.toJson`/`fromJson`, no changes to `Budget.budgets` (the static dev-mode seed list).
- Global budget's `categoryId` sentinel is exactly `BudgetProvider.globalBudgetId` (`'__global__'`) — never hardcode the string literal outside `budget_provider.dart`.
- Weekly → monthly normalization factor is `4.33`, defined once as `BudgetProvider.monthlyEquivalent`.
- Global budget period is always `BudgetPeriod.monthly` — the global-budget edit sheet has no period selector.
- No new packages/dependencies.
- This repo's screens have no widget-test precedent (only `test/widgets/category_filter_sheet_test.dart` exists and doesn't pump a full screen) — new screens are verified via `flutter analyze` plus manual run, not new widget-test scaffolding. Pure logic (`BudgetProvider` additions) does get real `flutter test` unit tests, matching `test/providers/app_settings_provider_test.dart`'s pattern.

---

### Task 1: BudgetProvider — global budget + allocation math

**Files:**
- Modify: `lib/providers/budget_provider.dart`
- Test: `test/providers/budget_provider_test.dart` (new file)

**Interfaces:**
- Produces (used by Tasks 2 and 3):
  - `static const String BudgetProvider.globalBudgetId = '__global__'`
  - `Budget? BudgetProvider.globalBudget` (getter)
  - `List<Budget> BudgetProvider.categoryBudgets` (getter — excludes the sentinel)
  - `static double BudgetProvider.monthlyEquivalent(Budget b)`
  - `double BudgetProvider.remainingGlobalBudget({String excludingCategoryId = ''})` — returns `double.infinity` when no global budget is set
  - `Future<void> BudgetProvider.setGlobalBudget(double amount)`
  - `Future<void> BudgetProvider.deleteGlobalBudget()`

- [ ] **Step 1: Write the failing test**

Create `test/providers/budget_provider_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wllt/models/models.dart';
import 'package:wllt/providers/budget_provider.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;
  late BudgetProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_budget_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    storage = StorageService();
    await storage.init();
    provider = BudgetProvider(storage, devMode: false);
  });

  tearDown(() async => Hive.close());
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('global budget', () {
    test('is null until set', () {
      expect(provider.globalBudget, isNull);
    });

    test('setGlobalBudget stores it and notifies', () async {
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.setGlobalBudget(30000);
      expect(provider.globalBudget?.amount, 30000);
      expect(provider.globalBudget?.period, BudgetPeriod.monthly);
      expect(notified, isTrue);
    });

    test('does not appear in categoryBudgets', () async {
      await provider.setGlobalBudget(30000);
      await provider.setBudget(
          const Budget(categoryId: 'groceries', amount: 5000, period: BudgetPeriod.monthly));
      final ids = provider.categoryBudgets.map((b) => b.categoryId);
      expect(ids, contains('groceries'));
      expect(ids, isNot(contains(BudgetProvider.globalBudgetId)));
    });

    test('deleteGlobalBudget removes it', () async {
      await provider.setGlobalBudget(30000);
      await provider.deleteGlobalBudget();
      expect(provider.globalBudget, isNull);
    });
  });

  group('monthlyEquivalent', () {
    test('passes monthly amounts through unchanged', () {
      const b = Budget(categoryId: 'x', amount: 1000, period: BudgetPeriod.monthly);
      expect(BudgetProvider.monthlyEquivalent(b), 1000);
    });

    test('scales weekly amounts by 4.33', () {
      const b = Budget(categoryId: 'x', amount: 1000, period: BudgetPeriod.weekly);
      expect(BudgetProvider.monthlyEquivalent(b), closeTo(4330, 0.01));
    });
  });

  group('remainingGlobalBudget', () {
    test('is infinite when no global budget set', () {
      expect(provider.remainingGlobalBudget(), double.infinity);
    });

    test('subtracts allocated category budgets from the global amount', () async {
      await provider.setGlobalBudget(10000);
      await provider.setBudget(
          const Budget(categoryId: 'groceries', amount: 4000, period: BudgetPeriod.monthly));
      await provider.setBudget(
          const Budget(categoryId: 'transport', amount: 1000, period: BudgetPeriod.weekly));
      // 10000 - 4000 - (1000 * 4.33) = 1670
      expect(provider.remainingGlobalBudget(), closeTo(1670, 0.01));
    });

    test('excludes the given category from the allocated sum', () async {
      await provider.setGlobalBudget(10000);
      await provider.setBudget(
          const Budget(categoryId: 'groceries', amount: 4000, period: BudgetPeriod.monthly));
      expect(provider.remainingGlobalBudget(excludingCategoryId: 'groceries'), 10000);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/budget_provider_test.dart`
Expected: FAIL to compile — `globalBudget`, `categoryBudgets`, `monthlyEquivalent`, `remainingGlobalBudget`, `setGlobalBudget`, `deleteGlobalBudget`, `globalBudgetId` don't exist yet.

- [ ] **Step 3: Implement the provider additions**

Replace the full contents of `lib/providers/budget_provider.dart` with:

```dart
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class BudgetProvider extends ChangeNotifier {
  /// Sentinel categoryId under which the single global budget is stored —
  /// reuses the existing per-category Budget row/box instead of new storage.
  static const String globalBudgetId = '__global__';

  final StorageService _storage;
  bool _devMode;
  late List<Budget> _budgets;

  BudgetProvider(this._storage, {required bool devMode}) : _devMode = devMode {
    _budgets = _devMode
        ? List<Budget>.from(Budget.budgets)
        : _storage.getBudgets();
  }

  List<Budget> get budgets => List.unmodifiable(_budgets);

  /// Real category budgets — excludes the global-budget sentinel row.
  List<Budget> get categoryBudgets =>
      _budgets.where((b) => b.categoryId != globalBudgetId).toList();

  Budget? get globalBudget => budgetFor(globalBudgetId);

  Budget? budgetFor(String categoryId) =>
      _budgets.where((b) => b.categoryId == categoryId).firstOrNull;

  /// Converts a budget's amount to a monthly figure — weekly budgets are
  /// scaled by the average weeks per month (52/12 ≈ 4.33) so they compare
  /// against a monthly global cap.
  static double monthlyEquivalent(Budget b) =>
      b.period == BudgetPeriod.weekly ? b.amount * 4.33 : b.amount;

  /// Global budget minus every category budget's monthly-equivalent amount,
  /// optionally excluding one category (the one currently being edited, so
  /// its own prior allocation doesn't count against itself).
  /// Returns [double.infinity] when no global budget is set — callers treat
  /// that as "uncapped".
  double remainingGlobalBudget({String excludingCategoryId = ''}) {
    final global = globalBudget;
    if (global == null) return double.infinity;
    final allocated = categoryBudgets
        .where((b) => b.categoryId != excludingCategoryId)
        .fold(0.0, (sum, b) => sum + monthlyEquivalent(b));
    return global.amount - allocated;
  }

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

  Future<void> setGlobalBudget(double amount) => setBudget(
      Budget(categoryId: globalBudgetId, amount: amount, period: BudgetPeriod.monthly));

  Future<void> deleteGlobalBudget() => deleteBudget(globalBudgetId);

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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/budget_provider_test.dart`
Expected: PASS, all groups green.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/budget_provider.dart test/providers/budget_provider_test.dart
git commit -m "feat: add global budget and allocation-cap math to BudgetProvider"
```

---

### Task 2: Budgets screen

**Files:**
- Create: `lib/screens/budgets_screen.dart`

**Interfaces:**
- Consumes: `BudgetProvider.globalBudget`, `.categoryBudgets`, `.budgetFor(id)`, `.remainingGlobalBudget()`, `.setGlobalBudget(amount)`, `.deleteGlobalBudget()`, `BudgetProvider.monthlyEquivalent(Budget)` (all from Task 1); `Helpers.getExpenseCategories`, `Helpers.formatAmount`, `Helpers.convertAmount` (existing, `lib/utils/helpers.dart`); `CategoryIconBadge` (existing, `lib/widgets/category_icon_badge.dart`); `CategoryDetailScreen` (existing, `lib/screens/category_detail_screen.dart`); `kCurrencies` (existing, `lib/data/currencies.dart`); `ExchangeRateService.instance.getCachedSnapshot` (existing).
- Produces (used by Task 5): `class BudgetsScreen extends StatelessWidget` with constructor `BudgetsScreen({required DateTime selectedMonth})`.

- [ ] **Step 1: Write the screen**

Create `lib/screens/budgets_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/currencies.dart';
import '../models/models.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
import 'category_detail_screen.dart';

class BudgetsScreen extends StatelessWidget {
  final DateTime selectedMonth;

  const BudgetsScreen({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final allTx = context.watch<TransactionProvider>().transactions;
    final budgetProvider = context.watch<BudgetProvider>();
    final prefs = context.watch<UserPreferencesProvider>();
    context.watch<ExchangeRateService>(); // rebuild when new rates arrive

    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == displayCurrency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;

    double resolveAmount(Transaction t) {
      if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
      final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
      return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
    }

    final monthTx = allTx.where((t) =>
        t.date.month == selectedMonth.month && t.date.year == selectedMonth.year);

    double spentFor(String? categoryId) => monthTx
        .where((t) =>
            t.type == TransactionType.expense &&
            (categoryId == null || t.categoryId == categoryId))
        .fold(0.0, (s, t) => s + resolveAmount(t));

    final totalSpent = spentFor(null);
    final global = budgetProvider.globalBudget;
    final activeIds = prefs.activeCategories.toSet();
    final categories = Helpers.getExpenseCategories(activeIds: activeIds);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _GlobalBudgetCard(
            amount: global?.amount,
            spent: totalSpent,
            currencySymbol: currencySymbol,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => _GlobalBudgetSheet(
                existing: global,
                budgetProvider: budgetProvider,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('CATEGORY ALLOCATIONS', style: AppTheme.trackingWide),
          const SizedBox(height: 10),
          ...categories.map((cat) {
            final budget = budgetProvider.budgetFor(cat.id);
            final allocated =
                budget != null ? BudgetProvider.monthlyEquivalent(budget) : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryAllocationTile(
                category: cat,
                allocated: allocated,
                spent: spentFor(cat.id),
                currencySymbol: currencySymbol,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: cat)),
                ),
              ),
            );
          }),
          if (global != null) ...[
            const SizedBox(height: 4),
            Text(
              '${Helpers.formatAmount(budgetProvider.remainingGlobalBudget(), currencySymbol)} unallocated',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Global budget card ────────────────────────────────────────────────────

class _GlobalBudgetCard extends StatelessWidget {
  final double? amount;
  final double spent;
  final String currencySymbol;
  final VoidCallback onTap;

  const _GlobalBudgetCard({
    required this.amount,
    required this.spent,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBudget = amount != null && amount! > 0;
    final pct = hasBudget ? (spent / amount! * 100).clamp(0.0, 100.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MONTHLY BUDGET',
                style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            if (hasBudget) ...[
              Text(Helpers.formatAmount(spent, currencySymbol),
                  style: TextStyle(fontSize: 28, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text('of ${Helpers.formatAmount(amount!, currencySymbol)} this month',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: pct >= 100 ? cs.error : cs.primary,
                ),
              ),
            ] else ...[
              Text('Set a monthly budget', style: TextStyle(fontSize: 16, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Tap to set a spending cap for the month',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlobalBudgetSheet extends StatefulWidget {
  final Budget? existing;
  final BudgetProvider budgetProvider;

  const _GlobalBudgetSheet({required this.existing, required this.budgetProvider});

  @override
  State<_GlobalBudgetSheet> createState() => _GlobalBudgetSheetState();
}

class _GlobalBudgetSheetState extends State<_GlobalBudgetSheet> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amount = double.tryParse(_amountCtrl.text);
    final canSave = amount != null && amount > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing != null ? 'Edit Monthly Budget' : 'Set Monthly Budget',
              style: TextStyle(fontSize: 18, color: cs.onSurface)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Monthly limit',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave
                  ? () {
                      FocusScope.of(context).unfocus();
                      widget.budgetProvider.setGlobalBudget(amount!);
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
                  FocusScope.of(context).unfocus();
                  widget.budgetProvider.deleteGlobalBudget();
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

// ── Category allocation row ───────────────────────────────────────────────

class _CategoryAllocationTile extends StatelessWidget {
  final Category category;
  final double? allocated;
  final double spent;
  final String currencySymbol;
  final VoidCallback onTap;

  const _CategoryAllocationTile({
    required this.category,
    required this.allocated,
    required this.spent,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBudget = allocated != null && allocated! > 0;
    final pct = hasBudget ? (spent / allocated! * 100).clamp(0.0, 100.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Row(
          children: [
            CategoryIconBadge(category: category, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  if (hasBudget)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 5,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: pct >= 100 ? cs.error : cs.primary,
                      ),
                    )
                  else
                    Text('No budget set', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Helpers.formatAmount(spent, currencySymbol),
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                if (hasBudget)
                  Text('of ${Helpers.formatAmount(allocated!, currencySymbol)}',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles clean**

Run: `flutter analyze lib/screens/budgets_screen.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/screens/budgets_screen.dart
git commit -m "feat: add Budgets screen with global budget card and category allocations"
```

---

### Task 3: Allocation cap in the category budget sheet

**Files:**
- Modify: `lib/screens/category_detail_screen.dart:598-609` (call site) and `:1052-1163` (`_BudgetBottomSheet`/`_BudgetBottomSheetState`)

**Interfaces:**
- Consumes: `BudgetProvider.remainingGlobalBudget({excludingCategoryId})`, `BudgetProvider.monthlyEquivalent` (Task 1).

- [ ] **Step 1: Thread `currencySymbol` into the sheet at the call site**

In `lib/screens/category_detail_screen.dart`, find (around line 605):

```dart
              builder: (_) => _BudgetBottomSheet(
                category: _category,
                existing: budget,
                budgetProvider: budgetProvider,
              ),
```

Replace with:

```dart
              builder: (_) => _BudgetBottomSheet(
                category: _category,
                existing: budget,
                budgetProvider: budgetProvider,
                currencySymbol: currencySymbol,
              ),
```

(`currencySymbol` is already computed earlier in this build method, at line 334.)

- [ ] **Step 2: Add the cap check to `_BudgetBottomSheet`**

Replace the full `_BudgetBottomSheet` + `_BudgetBottomSheetState` classes (currently lines 1052–1164) with:

```dart
class _BudgetBottomSheet extends StatefulWidget {
  final Category category;
  final Budget? existing;
  final BudgetProvider budgetProvider;
  final String currencySymbol;

  const _BudgetBottomSheet({
    required this.category,
    required this.existing,
    required this.budgetProvider,
    required this.currencySymbol,
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
      text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '',
    );
    _period = widget.existing?.period ?? BudgetPeriod.monthly;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final enteredAmount = double.tryParse(_amountCtrl.text);
    final monthlyEquiv = enteredAmount == null
        ? null
        : (_period == BudgetPeriod.weekly ? enteredAmount * 4.33 : enteredAmount);
    final remaining = widget.budgetProvider
        .remainingGlobalBudget(excludingCategoryId: widget.category.id);
    final overCap = monthlyEquiv != null && remaining.isFinite && monthlyEquiv > remaining;
    final canSave = enteredAmount != null && enteredAmount > 0 && !overCap;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (overCap) ...[
            const SizedBox(height: 6),
            Text(
              'Only ${Helpers.formatAmount(remaining, widget.currencySymbol)} left of global budget',
              style: TextStyle(fontSize: 12, color: cs.error),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<BudgetPeriod>(
            segments: const [
              ButtonSegment(value: BudgetPeriod.monthly, label: Text('Monthly')),
              ButtonSegment(value: BudgetPeriod.weekly, label: Text('Weekly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave
                  ? () {
                      FocusScope.of(context).unfocus();
                      widget.budgetProvider.setBudget(Budget(
                        categoryId: widget.category.id,
                        amount: enteredAmount!,
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
                  FocusScope.of(context).unfocus();
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

Note: `Helpers` is already imported in this file (line 13), so `Helpers.formatAmount` needs no new import.

- [ ] **Step 3: Verify it compiles clean**

Run: `flutter analyze lib/screens/category_detail_screen.dart`
Expected: "No issues found!"

- [ ] **Step 4: Manual verification**

Run the app in dev mode (`flutter run`, dev mode on). Dev-seed category budgets sum to ₹19,500/month (`restaurant` 3000 + `groceries` 5000 + `transport` 2000 + `movies` 2000 + `shopping` 5000 + `utilities` 2500, all monthly — see `Budget.budgets` in `lib/models/models.dart`). Since there's no global-budget UI reachable yet at this point in the plan, set one temporarily via a debug breakpoint/print calling `context.read<BudgetProvider>().setGlobalBudget(20000)`, or skip to after Task 5 and use the real Budgets screen — then:
- Open a category with no existing budget (e.g. Coffee), try amount `1000` monthly → Save disabled, "Only ₹500 left of global budget" shown (20000 − 19500 = 500).
- Try amount `400` → Save enabled, saves fine.
- Switch an existing category's budget to Weekly with a large amount → cap check uses the ×4.33 monthly-equivalent, not the raw weekly figure.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/category_detail_screen.dart
git commit -m "feat: enforce global-budget allocation cap on category budgets"
```

---

### Task 4: Home screen — real global budget + tap-through

**Files:**
- Modify: `lib/screens/home_screen.dart` (import, constructor, `build`, `_buildBalanceCard`)
- Modify: `lib/utils/helpers.dart:11-12` (delete unused const)

**Interfaces:**
- Consumes: `BudgetProvider.globalBudget` (Task 1).
- Produces (used by Task 5): `HomeScreen` gains a new named constructor parameter `VoidCallback? onNavigateToBudgets`.

- [ ] **Step 1: Add the import and constructor field**

In `lib/screens/home_screen.dart`, add near the other provider imports (after line 22, `import '../providers/transaction_provider.dart';`):

```dart
import '../providers/budget_provider.dart';
```

In the `HomeScreen` widget class, add a field alongside the existing callbacks (after `onCategoryBreakdownTap`):

```dart
  final VoidCallback? onNavigateToBudgets;
```

and add it to the constructor parameter list:

```dart
    this.onNavigateToBudgets,
```

- [ ] **Step 2: Read the global budget in `build()`**

Find (around line 336):

```dart
    context.watch<ExchangeRateService>(); // rebuild when new rates arrive
```

Add directly after it:

```dart
    final globalBudgetAmount = context.watch<BudgetProvider>().globalBudget?.amount;
```

- [ ] **Step 3: Replace `Helpers.monthlyBudget` in the percentage calcs**

Find (around line 393-394):

```dart
    final budgetPct =
        (totalExpense / Helpers.monthlyBudget * 100).clamp(0.0, 100.0);
```

Replace with:

```dart
    final budgetPct = (globalBudgetAmount != null && globalBudgetAmount > 0)
        ? (totalExpense / globalBudgetAmount * 100).clamp(0.0, 100.0)
        : 0.0;
```

Find (around line 445-446):

```dart
    double pct(double exp) =>
        (exp / Helpers.monthlyBudget * 100).clamp(0.0, 100.0);
```

Replace with:

```dart
    double pct(double exp) => (globalBudgetAmount != null && globalBudgetAmount > 0)
        ? (exp / globalBudgetAmount * 100).clamp(0.0, 100.0)
        : 0.0;
```

- [ ] **Step 4: Pass the amount into all three `_buildBalanceCard` calls**

Find the three calls inside the sliding-strip `Stack` (around lines 516, 523, 530):

```dart
                                  child: _buildBalanceCard(prevExp, pct(prevExp), prevInc, currencySymbol, month: prevMonth),
```
```dart
                                  child: _buildBalanceCard(totalExpense, budgetPct, totalIncome, currencySymbol),
```
```dart
                                  child: _buildBalanceCard(nextExp, pct(nextExp), nextInc, currencySymbol, month: nextMonth),
```

Replace with:

```dart
                                  child: _buildBalanceCard(prevExp, pct(prevExp), prevInc, currencySymbol, month: prevMonth, monthlyBudgetAmount: globalBudgetAmount),
```
```dart
                                  child: _buildBalanceCard(totalExpense, budgetPct, totalIncome, currencySymbol, monthlyBudgetAmount: globalBudgetAmount, onBudgetTap: widget.onNavigateToBudgets),
```
```dart
                                  child: _buildBalanceCard(nextExp, pct(nextExp), nextInc, currencySymbol, month: nextMonth, monthlyBudgetAmount: globalBudgetAmount),
```

Only the current (center) card gets `onBudgetTap` — the prev/next cards are drag previews of other months, not the tappable "overview card" the feature targets.

- [ ] **Step 5: Update `_buildBalanceCard`'s signature and budget section**

Find (around line 649-659):

```dart
  Widget _buildBalanceCard(
    double totalExpense,
    double budgetPct,
    double totalIncome,
    String currencySymbol, {
    DateTime? month,
  }) {
    final m = month ?? widget.selectedMonth;
    final monthName = Helpers.months[m.month - 1];
    final year = m.year;
    final hasBudget = Helpers.monthlyBudget > 0;
```

Replace with:

```dart
  Widget _buildBalanceCard(
    double totalExpense,
    double budgetPct,
    double totalIncome,
    String currencySymbol, {
    DateTime? month,
    double? monthlyBudgetAmount,
    VoidCallback? onBudgetTap,
  }) {
    final m = month ?? widget.selectedMonth;
    final monthName = Helpers.months[m.month - 1];
    final year = m.year;
    final hasBudget = monthlyBudgetAmount != null && monthlyBudgetAmount > 0;
```

Find the budget section (around lines 745-802):

```dart
                    // Budget section
                    if (hasBudget) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget ${Helpers.formatAmount(Helpers.monthlyBudget, currencySymbol)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          Text(
                            '${budgetPct.round()}% used',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: budgetPct / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: budgetPct > 85
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No budgets configured',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Edit categories to set monthly budgets',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
```

Replace with:

```dart
                    // Budget section — tappable through to the Budgets tab
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBudgetTap,
                      child: hasBudget
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Budget ${Helpers.formatAmount(monthlyBudgetAmount!, currencySymbol)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    Text(
                                      '${budgetPct.round()}% used',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: budgetPct / 100,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: budgetPct > 85
                                            ? AppTheme.warningColor
                                            : AppTheme.successColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No budgets configured',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to set a monthly budget',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                    ),
```

- [ ] **Step 6: Delete the now-unused constant**

In `lib/utils/helpers.dart`, remove lines 11-12:

```dart
  /// Default total monthly spending budget (INR).
  static const double monthlyBudget = 30000;

```

- [ ] **Step 7: Verify it compiles clean**

Run: `flutter analyze lib/screens/home_screen.dart lib/utils/helpers.dart`
Expected: "No issues found!" (confirms no other file still references `Helpers.monthlyBudget`).

- [ ] **Step 8: Commit**

```bash
git add lib/screens/home_screen.dart lib/utils/helpers.dart
git commit -m "feat: drive home screen budget bar from the real global budget"
```

---

### Task 5: Nav wiring — Budgets tab

**Files:**
- Modify: `lib/screens/layout_screen.dart`

**Interfaces:**
- Consumes: `BudgetsScreen` (Task 2), `HomeScreen.onNavigateToBudgets` (Task 4).

- [ ] **Step 1: Import the new screen**

Add near the other screen imports (after line 14, `import '../screens/home_screen.dart';`):

```dart
import '../screens/budgets_screen.dart';
```

- [ ] **Step 2: Add the nav item**

Find (line 455-460):

```dart
  final List<NavItem> _navItems = [
    const NavItem(icon: LucideIcons.layoutDashboard, label: 'Home'),
    const NavItem(icon: LucideIcons.arrowLeftRight, label: 'History'),
    const NavItem(icon: LucideIcons.wallet, label: 'Accounts'),
    const NavItem(icon: LucideIcons.settings, label: 'Settings'),
  ];
```

Replace with:

```dart
  final List<NavItem> _navItems = [
    const NavItem(icon: LucideIcons.layoutDashboard, label: 'Home'),
    const NavItem(icon: LucideIcons.arrowLeftRight, label: 'History'),
    const NavItem(icon: LucideIcons.pieChart, label: 'Budgets'),
    const NavItem(icon: LucideIcons.wallet, label: 'Accounts'),
    const NavItem(icon: LucideIcons.settings, label: 'Settings'),
  ];
```

- [ ] **Step 3: Insert the page and wire the home-screen callback**

Find (line 567-578):

```dart
  List<Widget> _buildPages() => [
    HomeScreen(
      selectedMonth: _selectedMonth,
      onMonthChanged: _changeMonth,
      onNavigateToHistory: () => _navigateToTab(1),
      pageScrollEnabled: _pageScrollEnabled,
      onCategoryBreakdownTap: _handleCategoryBreakdownTap,
    ),
    TransactionsScreen(selectedMonth: _selectedMonth),
    const AccountsScreen(),
    const SettingsScreen(),
  ];
```

Replace with:

```dart
  List<Widget> _buildPages() => [
    HomeScreen(
      selectedMonth: _selectedMonth,
      onMonthChanged: _changeMonth,
      onNavigateToHistory: () => _navigateToTab(1),
      onNavigateToBudgets: () => _navigateToTab(2),
      pageScrollEnabled: _pageScrollEnabled,
      onCategoryBreakdownTap: _handleCategoryBreakdownTap,
    ),
    TransactionsScreen(selectedMonth: _selectedMonth),
    BudgetsScreen(selectedMonth: _selectedMonth),
    const AccountsScreen(),
    const SettingsScreen(),
  ];
```

- [ ] **Step 4: Update the title array and month-picker range**

Find (line 157-158):

```dart
    final showMonthPicker = _currentIndex <= 1;
```

Replace with:

```dart
    final showMonthPicker = _currentIndex <= 2;
```

Find (line 192-198):

```dart
        : Text(
            const [
              '',
              'Transactions',
              'Accounts',
              'Settings',
            ][_currentIndex],
```

Replace with:

```dart
        : Text(
            const [
              '',
              'Transactions',
              'Budgets',
              'Accounts',
              'Settings',
            ][_currentIndex],
```

- [ ] **Step 5: Update the FAB index logic**

Find (line 428-453):

```dart
  Widget? _buildFab() {
    // Settings — no FAB
    if (_currentIndex == 3) return null;

    // Accounts — navigate to add account
    if (_currentIndex == 2) {
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 8,
        child: Icon(LucideIcons.plus, size: 24, color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    // Home + Transactions — directly open add transaction
    return FloatingActionButton(
      onPressed: () => _handleAddTransaction(AddTransactionMethod.expense),
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 8,
      child: Icon(LucideIcons.plus, size: 24, color: Theme.of(context).colorScheme.onPrimary),
    );
  }
```

Replace with:

```dart
  Widget? _buildFab() {
    // Settings — no FAB
    if (_currentIndex == 4) return null;

    // Budgets — no FAB; it's a dashboard, not a transaction-entry surface
    if (_currentIndex == 2) return null;

    // Accounts — navigate to add account
    if (_currentIndex == 3) {
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 8,
        child: Icon(LucideIcons.plus, size: 24, color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    // Home + Transactions — directly open add transaction
    return FloatingActionButton(
      onPressed: () => _handleAddTransaction(AddTransactionMethod.expense),
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 8,
      child: Icon(LucideIcons.plus, size: 24, color: Theme.of(context).colorScheme.onPrimary),
    );
  }
```

- [ ] **Step 6: Verify it compiles clean**

Run: `flutter analyze lib/screens/layout_screen.dart`
Expected: "No issues found!"

- [ ] **Step 7: Full manual end-to-end QA**

Run: `flutter run` (dev mode on, so the seed category budgets from `Budget.budgets` are present).

1. Bottom nav shows 5 tabs in order Home, History, Budgets, Accounts, Settings; Budgets icon is the pie-chart.
2. Home tab: budget bar reads "No budgets configured" (no global budget set yet) — tap it → lands on the Budgets tab.
3. Budgets tab: "Set a monthly budget" card at top; tap → sheet → enter `20000` → Save. Card now shows spend/₹20,000 with a progress bar. Category allocation rows below show the dev-seed budgets (Restaurant ₹3,000, Groceries ₹5,000, etc.) each with their own mini progress bar, and unbudgeted categories say "No budget set". Footer shows "₹500 unallocated" (20000 − 19500).
4. Tap a category row → opens `CategoryDetailScreen` for that category (existing screen, unchanged).
5. In that category's budget sheet, try to set an amount that would push allocations past ₹20,000 → Save disabled, "Only ₹X left of global budget" shown; reduce it → Save re-enables.
6. Back on Home: budget bar now shows the real 20000 figure, percentage, and color-coded progress bar; tapping it still navigates to Budgets.
7. Swipe Home's month strip to an adjacent month — prev/next cards show the same global budget figure (it isn't month-specific) and are not tap-navigable (only the center card is).
8. Budgets tab respects the top month picker (swap month, spend figures update) same as Home/History.
9. Remove the global budget via the sheet's "Remove budget" → Home reverts to "No budgets configured" / tap-to-set state, category cap check goes back to uncapped.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/layout_screen.dart
git commit -m "feat: add Budgets tab to bottom navigation"
```
