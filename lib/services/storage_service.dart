import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _userPrefsBox = 'user_prefs';
  static const String _categoriesBox = 'active_categories';

  static const String keyCurrency = 'currency';
  static const String keyAuthMode = 'auth_mode';
  static const String keyGoogleUid = 'google_uid';
  static const String keyGoogleEmail = 'google_email';
  static const String keyCategories = 'categories';
  static const String keyOnboardingComplete = 'onboarding_complete';

  late Box _userPrefs;
  late Box _categories;
  late SharedPreferences _prefs;

  Future<void> init() async {
    _userPrefs = await Hive.openBox(_userPrefsBox);
    _categories = await Hive.openBox(_categoriesBox);
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

  // ── Categories ────────────────────────────────────────────────────────
  List<String> get activeCategories {
    final raw = _categories.get(keyCategories);
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }

  Future<void> setActiveCategories(List<String> ids) =>
      _categories.put(keyCategories, ids);
}
