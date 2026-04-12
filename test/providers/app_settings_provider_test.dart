import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/providers/app_settings_provider.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;
  late AppSettingsProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_appsettings_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    provider = AppSettingsProvider(storage);
  });

  tearDown(() async => Hive.close());
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('initial state', () {
    test('themeMode defaults to system', () {
      expect(provider.themeMode, ThemeMode.system);
    });

    test('colorSeed defaults to violet', () {
      expect(provider.colorSeed, const Color(0xFF6750A4));
    });
  });

  group('setThemeMode', () {
    test('updates themeMode and notifies listeners', () async {
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, isTrue);
    });
  });

  group('setColorSeed', () {
    test('updates colorSeed and notifies listeners', () async {
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.setColorSeed(const Color(0xFF006874));
      expect(provider.colorSeed, const Color(0xFF006874));
      expect(notified, isTrue);
    });
  });

  group('resetAllData', () {
    test('clears storage and notifies listeners', () async {
      await provider.setThemeMode(ThemeMode.dark);
      await provider.setColorSeed(const Color(0xFF006874));
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.resetAllData();
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.colorSeed, const Color(0xFF6750A4));
      expect(notified, isTrue);
    });
  });
}
