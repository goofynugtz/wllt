import 'package:flutter/material.dart';
import '../services/exchange_rate_service.dart';
import '../services/storage_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _demoMode = false;

  AppSettingsProvider(this._storage);

  /// Session-only demo flag — never persisted. Set to true to show dummy data
  /// without requiring auth (used for marketing iframe embeds).
  bool get demoMode => _demoMode;
  void setDemoMode(bool value) {
    if (_demoMode == value) return;
    _demoMode = value;
    notifyListeners();
  }

  ThemeMode get themeMode => _storage.themeMode;
  Color     get colorSeed => _storage.colorSeed;
  bool      get devMode   => _storage.devMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setColorSeed(Color color) async {
    await _storage.setColorSeed(color);
    notifyListeners();
  }

  Future<void> setDevMode(bool value) async {
    await _storage.setDevMode(value);
    if (value) await ExchangeRateService.instance.seedDevModeRates();
    notifyListeners();
  }

  /// Clears all Hive boxes + SharedPreferences and notifies listeners so
  /// the MaterialApp Consumer rebuilds with default theme immediately.
  Future<void> resetAllData() async {
    await _storage.clearAll();
    notifyListeners();
  }
}
