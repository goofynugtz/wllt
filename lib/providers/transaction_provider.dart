import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class TransactionProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _devMode;

  late List<Transaction> _transactions;

  TransactionProvider(this._storage, {required bool devMode}) : _devMode = devMode {
    _transactions = _devMode
        ? List<Transaction>.from(Transaction.dummyData)
        : _storage.getTransactions();
  }

  List<Transaction> get transactions => List.unmodifiable(_transactions);

  void reloadIfNeeded(bool newDevMode) {
    if (_devMode == newDevMode) return;
    _devMode = newDevMode;
    _transactions = _devMode
        ? List<Transaction>.from(Transaction.dummyData)
        : _storage.getTransactions();
    notifyListeners();
  }

  Future<void> addTransaction(Transaction tx) async {
    if (!_devMode) await _storage.saveTransaction(tx);
    _transactions.insert(0, tx);
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction tx) async {
    if (!_devMode) await _storage.saveTransaction(tx);
    final idx = _transactions.indexWhere((t) => t.id == tx.id);
    if (idx != -1) _transactions[idx] = tx;
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    if (!_devMode) await _storage.deleteTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
