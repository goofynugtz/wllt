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
