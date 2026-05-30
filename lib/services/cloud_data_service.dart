import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/models.dart';

/// Firestore-backed persistence for transactions and accounts.
///
/// On web this is the sole storage layer.
/// On mobile (Google auth) writes are mirrored here for cloud backup / cross-device sync.
class CloudDataService {
  final FirebaseFirestore _db;
  final String _uid;

  CloudDataService({required FirebaseFirestore db, required String uid})
      : _db = db,
        _uid = uid;

  // ── Transactions ────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _db.collection('users').doc(_uid).collection('transactions');

  Future<List<Transaction>> loadTransactions() async {
    try {
      final snap = await _txCol.orderBy('date', descending: true).get();
      return snap.docs
          .map((d) => Transaction.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTransaction(Transaction tx) async {
    try {
      await _txCol.doc(tx.id).set(tx.toJson());
    } catch (_) {}
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _txCol.doc(id).delete();
    } catch (_) {}
  }

  // ── Accounts ────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _accCol =>
      _db.collection('users').doc(_uid).collection('accounts');

  Future<List<Account>> loadAccounts() async {
    try {
      final snap = await _accCol.get();
      return snap.docs
          .map((d) => Account.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccount(Account account) async {
    try {
      await _accCol.doc(account.id).set(account.toJson());
    } catch (_) {}
  }

  Future<void> deleteAccount(String id) async {
    try {
      await _accCol.doc(id).delete();
    } catch (_) {}
  }
}
