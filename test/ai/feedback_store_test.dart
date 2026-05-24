import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wllt/ai/feedback_store.dart';
import 'dart:io';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('lookup returns null for unknown merchant', () async {
    final store = FeedbackStore();
    await store.init();
    expect(store.lookup('unknown merchant'), isNull);
  });

  test('recordCorrection persists and lookup returns it', () async {
    final store = FeedbackStore();
    await store.init();
    await store.recordCorrection(
      merchant: 'Blue Tokai',
      aiSuggested: 'coffee',
      userChose: 'restaurant',
    );
    expect(store.lookup('blue tokai'), equals('restaurant'));
  });

  test('lookup is case-insensitive', () async {
    final store = FeedbackStore();
    await store.init();
    await store.recordCorrection(
      merchant: 'SWIGGY',
      aiSuggested: 'restaurant',
      userChose: 'food',
    );
    expect(store.lookup('swiggy'), equals('food'));
    expect(store.lookup('Swiggy'), equals('food'));
  });
}
