import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_theme_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  tearDown(() async => Hive.close());
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('themeMode', () {
    test('defaults to system', () {
      expect(storage.themeMode, ThemeMode.system);
    });

    test('setThemeMode persists light', () async {
      await storage.setThemeMode(ThemeMode.light);
      expect(storage.themeMode, ThemeMode.light);
    });

    test('setThemeMode persists dark', () async {
      await storage.setThemeMode(ThemeMode.dark);
      expect(storage.themeMode, ThemeMode.dark);
    });

    test('setThemeMode persists system', () async {
      await storage.setThemeMode(ThemeMode.dark);
      await storage.setThemeMode(ThemeMode.system);
      expect(storage.themeMode, ThemeMode.system);
    });
  });

  group('colorSeed', () {
    test('defaults to violet 0xFF6750A4', () {
      expect(storage.colorSeed, const Color(0xFF6750A4));
    });

    test('setColorSeed persists color', () async {
      await storage.setColorSeed(const Color(0xFF006874));
      expect(storage.colorSeed, const Color(0xFF006874));
    });
  });

  group('clearAll', () {
    test('resets themeMode to system default', () async {
      await storage.setThemeMode(ThemeMode.dark);
      await storage.clearAll();
      expect(storage.themeMode, ThemeMode.system);
    });

    test('resets colorSeed to violet default', () async {
      await storage.setColorSeed(const Color(0xFF006874));
      await storage.clearAll();
      expect(storage.colorSeed, const Color(0xFF6750A4));
    });

    test('resets currency to USD', () async {
      await storage.setCurrency('EUR');
      await storage.clearAll();
      expect(storage.currency, 'USD');
    });

    test('resets onboarding flag', () async {
      await storage.setOnboardingComplete();
      await storage.clearAll();
      expect(storage.isOnboardingComplete, isFalse);
    });
  });
}
