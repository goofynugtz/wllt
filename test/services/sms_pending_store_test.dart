import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wllt/services/sms_pending_store.dart';
import 'package:wllt/models/pending_sms_transaction.dart';
import 'package:wllt/models/models.dart';

PendingSmsTransaction _make(String id, {bool isUnparsed = false}) =>
    PendingSmsTransaction(
      id: id,
      rawSms: 'Rs.100 debited',
      amount: 100,
      type: TransactionType.expense,
      parsedAt: DateTime.now(),
      isUnparsed: isUnparsed,
      verdict: SmsVerdict.safe,
    );

void main() {
  late Directory tempDir;
  late SmsPendingStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    store = SmsPendingStore();
    await store.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('SmsPendingStore', () {
    test('starts empty', () {
      expect(store.all, isEmpty);
    });

    test('adds item', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      expect(store.all.length, 1);
      expect(store.all.first.id, 'id1');
    });

    test('dedup returns new_message for unknown', () {
      expect(store.checkDuplicate(null, 'newhash'), DedupResult.newMessage);
    });

    test('dedup detects duplicate by contentHash in pending', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      expect(store.checkDuplicate(null, 'hash1'), DedupResult.duplicatePending);
    });

    test('dedup detects confirmed by contentHash', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      await store.confirm('id1');
      expect(store.checkDuplicate(null, 'hash1'), DedupResult.duplicateConfirmed);
    });

    test('dismiss removes item', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      await store.dismiss('id1');
      expect(store.all, isEmpty);
    });

    test('update replaces item fields', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      await store.update('id1', _make('id1').copyWith(merchant: 'Zomato'));
      expect(store.all.first.merchant, 'Zomato');
    });

    test('lastScanTs is null initially', () {
      expect(store.lastScanTs, isNull);
    });

    test('setLastScanTs persists', () async {
      final ts = DateTime(2026, 5, 23);
      await store.setLastScanTs(ts);
      expect(store.lastScanTs, ts);
    });
  });
}
