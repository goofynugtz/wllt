import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_storage_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  tearDown(() async => Hive.close());

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('onboarding flag', () {
    test('isOnboardingComplete is false by default', () {
      expect(storage.isOnboardingComplete, isFalse);
    });

    test('setOnboardingComplete persists true', () async {
      await storage.setOnboardingComplete();
      expect(storage.isOnboardingComplete, isTrue);
    });
  });

  group('feedback auto shown flag', () {
    test('feedbackAutoShown is false by default', () {
      expect(storage.feedbackAutoShown, isFalse);
    });

    test('setFeedbackAutoShown persists true', () async {
      await storage.setFeedbackAutoShown();
      expect(storage.feedbackAutoShown, isTrue);
    });
  });

  group('currency', () {
    test('defaults to USD', () {
      expect(storage.currency, 'USD');
    });

    test('setCurrency persists the code', () async {
      await storage.setCurrency('INR');
      expect(storage.currency, 'INR');
    });
  });

  group('auth mode', () {
    test('defaults to offline', () {
      expect(storage.authMode, 'offline');
    });

    test('setAuthMode persists the mode', () async {
      await storage.setAuthMode('google');
      expect(storage.authMode, 'google');
    });
  });

  group('google credentials', () {
    test('googleUid is null by default', () {
      expect(storage.googleUid, isNull);
    });

    test('setGoogleCredentials persists uid and email', () async {
      await storage.setGoogleCredentials(uid: 'uid_abc', email: 'test@gmail.com');
      expect(storage.googleUid, 'uid_abc');
      expect(storage.googleEmail, 'test@gmail.com');
    });
  });

  group('active categories', () {
    test('returns empty list by default', () {
      expect(storage.activeCategories, isEmpty);
    });

    test('setActiveCategories persists the list', () async {
      await storage.setActiveCategories(['shopping', 'transport', 'groceries']);
      expect(storage.activeCategories, ['shopping', 'transport', 'groceries']);
    });
  });
}
