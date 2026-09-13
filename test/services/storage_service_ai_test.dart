import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_ai_test_');
    Hive.init(tempDir.path);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async => Hive.close());
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  test('aiEnabled defaults to false', () async {
    final storage = StorageService();
    await storage.init();
    expect(storage.aiEnabled, false);
  });

  test('setAiEnabled persists value', () async {
    final storage = StorageService();
    await storage.init();
    await storage.setAiEnabled(true);
    expect(storage.aiEnabled, true);
    await storage.setAiEnabled(false);
    expect(storage.aiEnabled, false);
  });

  test('activeModel defaults to null and persists once set', () async {
    final storage = StorageService();
    await storage.init();
    expect(storage.activeModel, null);
    await storage.setActiveModel({
      'url': 'https://pub-xyz.r2.dev/gemma3-1b-it-int4.task',
      'displayName': 'Gemma 3 1B',
      'sizeLabel': '600.00 MB',
    });
    expect(storage.activeModel, {
      'url': 'https://pub-xyz.r2.dev/gemma3-1b-it-int4.task',
      'displayName': 'Gemma 3 1B',
      'sizeLabel': '600.00 MB',
    });
  });
}
