import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/cloud_data_service.dart';
import '../services/storage_service.dart';

class AccountProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _devMode;
  CloudDataService? _cloud;

  late List<Account> _accounts;

  AccountProvider(
    this._storage, {
    required bool devMode,
    String? cloudUid,
  }) : _devMode = devMode {
    if (kIsWeb && cloudUid != null) {
      _cloud = CloudDataService(
        db: FirebaseFirestore.instance,
        uid: cloudUid,
      );
      _accounts = [];
      _cloud!.loadAccounts().then((list) {
        _accounts = list;
        notifyListeners();
      });
    } else {
      _accounts = _devMode
          ? List<Account>.from(Account.dummyData)
          : _storage.getAccounts();
    }
  }

  List<Account> get accounts => List.unmodifiable(_accounts);

  void reloadIfNeeded(bool newDevMode) {
    if (_devMode == newDevMode) return;
    _devMode = newDevMode;
    if (_devMode) {
      _accounts = List<Account>.from(Account.dummyData);
      notifyListeners();
    } else if (!kIsWeb || _cloud == null) {
      _accounts = _storage.getAccounts();
      notifyListeners();
    }
  }

  void setCloudUid(String uid) {
    if (_cloud != null || _devMode) return;
    _cloud = CloudDataService(db: FirebaseFirestore.instance, uid: uid);
    if (kIsWeb) {
      _cloud!.loadAccounts().then((list) {
        _accounts = list;
        notifyListeners();
      });
    }
  }

  Future<void> addAccount(Account account) async {
    if (!_devMode) {
      if (!kIsWeb) await _storage.saveAccount(account);
      if (kIsWeb) {
        await _cloud?.saveAccount(account);
      } else {
        _cloud?.saveAccount(account);
      }
    }
    _accounts.add(account);
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    if (!_devMode) {
      if (!kIsWeb) await _storage.saveAccount(account);
      if (kIsWeb) {
        await _cloud?.saveAccount(account);
      } else {
        _cloud?.saveAccount(account);
      }
    }
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx != -1) _accounts[idx] = account;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    if (!_devMode) {
      if (!kIsWeb) await _storage.deleteAccount(id);
      if (kIsWeb) {
        await _cloud?.deleteAccount(id);
      } else {
        _cloud?.deleteAccount(id);
      }
    }
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}
