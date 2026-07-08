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
}
