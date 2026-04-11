import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class UserPreferencesProvider extends ChangeNotifier {
  final StorageService _storage;
  SyncService? _syncService;

  UserPreferencesProvider(this._storage);

  String get currency => _storage.currency;
  List<String> get activeCategories => _storage.activeCategories;
  String get authMode => _storage.authMode;
  String? get googleUid => _storage.googleUid;

  Future<void> setAuthMode(String mode) async {
    await _storage.setAuthMode(mode);
    notifyListeners();
  }

  /// Call after successful Google sign-in to store credentials and start sync.
  Future<void> setGoogleUser({
    required String uid,
    required String email,
  }) async {
    await _storage.setGoogleCredentials(uid: uid, email: email);
    _setupSync(uid);
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    await _storage.setCurrency(code);
    _syncService?.syncPreferences();
    notifyListeners();
  }

  Future<void> setCategories(List<String> ids) async {
    await _storage.setActiveCategories(ids);
    _syncService?.syncPreferences();
    notifyListeners();
  }

  Future<void> completeOnboarding() =>
      _storage.setOnboardingComplete();

  void _setupSync(String uid) {
    _syncService?.dispose();
    _syncService = SyncService(
      firestore: FirebaseFirestore.instance,
      storage: _storage,
      uid: uid,
    );
    _syncService!.startListening();
    _syncService!.remoteChanges.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _syncService?.dispose();
    super.dispose();
  }
}
