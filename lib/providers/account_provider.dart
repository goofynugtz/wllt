import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class AccountProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _devMode;

  late List<Account> _accounts;

  AccountProvider(this._storage, {required bool devMode}) : _devMode = devMode {
    _accounts = _devMode
        ? List<Account>.from(Account.dummyData)
        : _storage.getAccounts();
  }

  List<Account> get accounts => List.unmodifiable(_accounts);

  void reloadIfNeeded(bool newDevMode) {
    if (_devMode == newDevMode) return;
    _devMode = newDevMode;
    _accounts = _devMode
        ? List<Account>.from(Account.dummyData)
        : _storage.getAccounts();
    notifyListeners();
  }

  Future<void> addAccount(Account account) async {
    if (!_devMode) await _storage.saveAccount(account);
    _accounts.add(account);
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    if (!_devMode) await _storage.saveAccount(account);
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx != -1) _accounts[idx] = account;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    if (!_devMode) await _storage.deleteAccount(id);
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}
