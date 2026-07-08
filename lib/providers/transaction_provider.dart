import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/cloud_data_service.dart';
import '../services/storage_service.dart';

class TransactionProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _devMode;
  CloudDataService? _cloud;

  late List<Transaction> _transactions;

  TransactionProvider(
    this._storage, {
    required bool devMode,
    String? cloudUid,
  }) : _devMode = devMode {
    if (kIsWeb && cloudUid != null) {
      _cloud = CloudDataService(
        db: FirebaseFirestore.instance,
        uid: cloudUid,
      );
      _transactions = [];
      _cloud!.loadTransactions().then((list) {
        _transactions = list;
        notifyListeners();
      });
    } else {
      _transactions = _devMode
          ? List<Transaction>.from(Transaction.dummyData)
          : _storage.getTransactions();
    }
  }

  List<Transaction> get transactions => List.unmodifiable(_transactions);

  void reloadIfNeeded(bool newDevMode) {
    if (_devMode == newDevMode) return;
    _devMode = newDevMode;
    if (_devMode) {
      _transactions = List<Transaction>.from(Transaction.dummyData);
      notifyListeners();
    } else if (!kIsWeb || _cloud == null) {
      _transactions = _storage.getTransactions();
      notifyListeners();
    }
  }

  /// On web: loads from Firestore and replaces the transaction list.
  /// On mobile: enables write-through to Firestore without overwriting Hive data.
  void setCloudUid(String uid) {
    if (_cloud != null || _devMode) return;
    _cloud = CloudDataService(db: FirebaseFirestore.instance, uid: uid);
    if (kIsWeb) {
      _cloud!.loadTransactions().then((list) {
        _transactions = list;
        notifyListeners();
      });
    }
  }

  Future<void> addTransaction(Transaction tx) async {
    if (!_devMode) {
      if (!kIsWeb) await _storage.saveTransaction(tx);
      if (kIsWeb) {
        await _cloud?.saveTransaction(tx);
      } else {
        _cloud?.saveTransaction(tx); // fire-and-forget mirror on mobile
      }
    }
    _transactions.insert(0, tx);
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction tx) async {
    if (!_devMode) {
      if (!kIsWeb) await _storage.saveTransaction(tx);
      if (kIsWeb) {
        await _cloud?.saveTransaction(tx);
      } else {
        _cloud?.saveTransaction(tx);
      }
    }
    final idx = _transactions.indexWhere((t) => t.id == tx.id);
    if (idx != -1) _transactions[idx] = tx;
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    if (!_devMode) {
      if (!kIsWeb) await _storage.deleteTransaction(id);
      if (kIsWeb) {
        await _cloud?.deleteTransaction(id);
      } else {
        _cloud?.deleteTransaction(id);
      }
    }
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
