import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const String _userPrefsBox    = 'user_prefs';
  static const String _categoriesBox   = 'active_categories';
  static const String _transactionsBox = 'transactions';
  static const String _accountsBox     = 'accounts';

  static const String keyCurrency           = 'currency';
  static const String keyAuthMode           = 'auth_mode';
  static const String keyGoogleUid          = 'google_uid';
  static const String keyGoogleEmail        = 'google_email';
  static const String keyCategories         = 'categories';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyThemeMode          = 'theme_mode';
  static const String keyColorSeed          = 'color_seed';
  static const String keyDevMode            = 'dev_mode';

  late Box _userPrefs;
  late Box _categories;
  late Box _transactions;
  late Box _accounts;
  late SharedPreferences _prefs;

  Future<void> init() async {
    _userPrefs    = await Hive.openBox(_userPrefsBox);
    _categories   = await Hive.openBox(_categoriesBox);
    _transactions = await Hive.openBox(_transactionsBox);
    _accounts     = await Hive.openBox(_accountsBox);
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Onboarding ────────────────────────────────────────────────────────
  bool get isOnboardingComplete =>
      _prefs.getBool(keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete() =>
      _prefs.setBool(keyOnboardingComplete, true);

  // ── Currency ──────────────────────────────────────────────────────────
  String get currency =>
      (_userPrefs.get(keyCurrency) as String?) ?? 'USD';

  Future<void> setCurrency(String code) =>
      _userPrefs.put(keyCurrency, code);

  // ── Auth ──────────────────────────────────────────────────────────────
  String get authMode =>
      (_userPrefs.get(keyAuthMode) as String?) ?? 'offline';

  Future<void> setAuthMode(String mode) =>
      _userPrefs.put(keyAuthMode, mode);

  String? get googleUid =>
      _userPrefs.get(keyGoogleUid) as String?;

  String? get googleEmail =>
      _userPrefs.get(keyGoogleEmail) as String?;

  Future<void> setGoogleCredentials({
    required String uid,
    required String email,
  }) async {
    await _userPrefs.put(keyGoogleUid, uid);
    await _userPrefs.put(keyGoogleEmail, email);
  }

  // ── Theme mode ────────────────────────────────────────────────────────
  ThemeMode get themeMode {
    switch (_userPrefs.get(keyThemeMode) as String?) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final val = switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
    return _userPrefs.put(keyThemeMode, val);
  }

  // ── Color seed ────────────────────────────────────────────────────────
  Color get colorSeed {
    final raw = _userPrefs.get(keyColorSeed) as int?;
    return raw != null ? Color(raw) : const Color(0xFF6750A4);
  }

  Future<void> setColorSeed(Color color) =>
      _userPrefs.put(keyColorSeed, color.toARGB32());

  // ── Dev mode ──────────────────────────────────────────────────────────
  bool get devMode => kReleaseMode ? false : ((_userPrefs.get(keyDevMode) as bool?) ?? false);

  Future<void> setDevMode(bool value) => _userPrefs.put(keyDevMode, value);

  // ── Transactions ──────────────────────────────────────────────────────
  List<Transaction> getTransactions() {
    return _transactions.values
        .map((v) => Transaction.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<void> saveTransaction(Transaction tx) =>
      _transactions.put(tx.id, tx.toJson());

  Future<void> deleteTransaction(String id) => _transactions.delete(id);

  // ── Accounts ──────────────────────────────────────────────────────────
  List<Account> getAccounts() {
    return _accounts.values
        .map((v) => Account.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<void> saveAccount(Account account) =>
      _accounts.put(account.id, account.toJson());

  Future<void> deleteAccount(String id) => _accounts.delete(id);

  // ── Reset ─────────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    await _userPrefs.clear();
    await _categories.clear();
    await _transactions.clear();
    await _accounts.clear();
    await _prefs.remove(keyOnboardingComplete);
  }

  // ── Active category IDs ───────────────────────────────────────────────
  List<String> get activeCategories {
    final raw = _categories.get(keyCategories);
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }

  Future<void> setActiveCategories(List<String> ids) =>
      _categories.put(keyCategories, ids);

  // ── Custom categories ─────────────────────────────────────────────────
  static const String _customCategoriesKey = 'custom_categories_v1';

  List<Category> getCustomCategories() {
    final raw = _categories.get(_customCategoriesKey);
    if (raw == null) return [];
    return (raw as List)
        .map((v) => Category.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<void> saveCustomCategory(Category category) {
    final existing = getCustomCategories();
    final updated = [
      ...existing.where((c) => c.id != category.id),
      category,
    ];
    return _categories.put(
      _customCategoriesKey,
      updated.map((c) => c.toJson()).toList(),
    );
  }

  Future<void> deleteCustomCategory(String id) {
    final existing = getCustomCategories();
    final updated = existing.where((c) => c.id != id).toList();
    return _categories.put(
      _customCategoriesKey,
      updated.map((c) => c.toJson()).toList(),
    );
  }
}
