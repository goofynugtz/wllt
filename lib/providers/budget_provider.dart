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
      _budgets.where((b) => b.categoryId == categoryId).firstOrNull;

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
