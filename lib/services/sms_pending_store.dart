import 'package:hive_flutter/hive_flutter.dart';
import '../models/pending_sms_transaction.dart';

enum DedupResult { newMessage, duplicatePending, duplicateConfirmed }

class SmsPendingStore {
  static const _pendingBox = 'sms_pending';
  static const _metaBox = 'sms_meta';
  static const _processedIdsKey = 'processed_ids';
  static const _contentHashesKey = 'content_hashes';
  static const _confirmedHashesKey = 'confirmed_hashes';
  static const _idHashMapKey = 'id_hash_map';
  static const _lastScanTsKey = 'sms_last_scan_ts';

  late Box _pending;
  late Box _meta;

  Future<void> init() async {
    _pending = await Hive.openBox(_pendingBox);
    _meta = await Hive.openBox(_metaBox);
  }

  List<PendingSmsTransaction> get all => _pending.values
      .map((v) => PendingSmsTransaction.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList()
    ..sort((a, b) => b.parsedAt.compareTo(a.parsedAt));

  DedupResult checkDuplicate(String? smsId, String contentHash) {
    final pendingHashes = _getSet(_contentHashesKey);
    final confirmedHashes = _getSet(_confirmedHashesKey);
    final processedIds = _getSet(_processedIdsKey);

    if (confirmedHashes.contains(contentHash)) return DedupResult.duplicateConfirmed;
    if (smsId != null && processedIds.contains(smsId)) {
      return pendingHashes.contains(contentHash)
          ? DedupResult.duplicatePending
          : DedupResult.duplicateConfirmed;
    }
    if (pendingHashes.contains(contentHash)) return DedupResult.duplicatePending;
    return DedupResult.newMessage;
  }

  Future<void> add(
    PendingSmsTransaction item, {
    required String? smsId,
    required String contentHash,
  }) async {
    await _pending.put(item.id, item.toJson());
    final hashes = _getSet(_contentHashesKey)..add(contentHash);
    await _meta.put(_contentHashesKey, hashes.toList());
    final idHashMap = _getMap(_idHashMapKey)..[item.id] = contentHash;
    await _meta.put(_idHashMapKey, idHashMap);
    if (smsId != null) {
      final ids = _getSet(_processedIdsKey)..add(smsId);
      await _meta.put(_processedIdsKey, ids.toList());
    }
  }

  Future<void> confirm(String id) async {
    if (_pending.get(id) == null) return;
    await _pending.delete(id);
    final idHashMap = _getMap(_idHashMapKey);
    final hash = idHashMap.remove(id);
    await _meta.put(_idHashMapKey, idHashMap);
    if (hash != null) {
      final pendingHashes = _getSet(_contentHashesKey)..remove(hash);
      await _meta.put(_contentHashesKey, pendingHashes.toList());
      final confirmedHashes = _getSet(_confirmedHashesKey)..add(hash);
      await _meta.put(_confirmedHashesKey, confirmedHashes.toList());
    }
  }

  Future<void> dismiss(String id) async {
    await _pending.delete(id);
    final idHashMap = _getMap(_idHashMapKey)..remove(id);
    await _meta.put(_idHashMapKey, idHashMap);
  }

  Future<void> update(String id, PendingSmsTransaction updated) async {
    await _pending.put(id, updated.toJson());
  }

  DateTime? get lastScanTs {
    final raw = _meta.get(_lastScanTsKey) as String?;
    return raw != null ? DateTime.parse(raw) : null;
  }

  Future<void> setLastScanTs(DateTime ts) async {
    await _meta.put(_lastScanTsKey, ts.toIso8601String());
  }

  Set<String> _getSet(String key) {
    final raw = _meta.get(key);
    if (raw == null) return {};
    return (raw as List).cast<String>().toSet();
  }

  Map<String, String> _getMap(String key) {
    final raw = _meta.get(key);
    if (raw == null) return {};
    return Map<String, String>.from(raw as Map);
  }
}
