import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/insight_card.dart';

class InsightService {
  final FirebaseFirestore _db;
  final String _uid;

  InsightService({required FirebaseFirestore db, required String uid})
      : _db = db,
        _uid = uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('insights');

  Future<InsightCard?> getThisWeek(String weekKey) async {
    try {
      final snap = await _col.doc(weekKey).get();
      if (!snap.exists || snap.data() == null) return null;
      return InsightCard.fromFirestore(snap);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(InsightCard card) async {
    try {
      await _col.doc(card.weekKey).set(card.toJson());
    } catch (_) {}
  }

  Future<void> deleteCard(String weekKey) async {
    try {
      await _col.doc(weekKey).delete();
    } catch (_) {}
  }
}
