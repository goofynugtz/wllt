import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class SyncService {
  final FirebaseFirestore _firestore;
  final StorageService _storage;
  final String _uid;

  final _remoteChanges = StreamController<void>.broadcast();

  /// Emits whenever a remote Firestore change has been applied to Hive.
  Stream<void> get remoteChanges => _remoteChanges.stream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  SyncService({
    required FirebaseFirestore firestore,
    required StorageService storage,
    required String uid,
  })  : _firestore = firestore,
        _storage = storage,
        _uid = uid;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('preferences')
      .doc('data');

  /// Starts a real-time Firestore listener.
  /// Remote changes are written to Hive and broadcast via [remoteChanges].
  void startListening() {
    _sub = _doc.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data()!;

      final remoteCurrency = data['currency'] as String?;
      if (remoteCurrency != null) {
        await _storage.setCurrency(remoteCurrency);
      }

      final rawCats = data['categories'];
      if (rawCats is List) {
        await _storage.setActiveCategories(rawCats.cast<String>());
      }

      _remoteChanges.add(null);
    });
  }

  /// Pushes current Hive state to Firestore.
  Future<void> pushToFirestore() => _doc.set({
        'currency': _storage.currency,
        'categories': _storage.activeCategories,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Called after any local write. Fire-and-forget — does not block the UI.
  void syncPreferences() {
    pushToFirestore();
  }

  void dispose() {
    _sub?.cancel();
    _remoteChanges.close();
  }
}
