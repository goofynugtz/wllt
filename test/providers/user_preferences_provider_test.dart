import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wllt/services/storage_service.dart';
import 'package:wllt/providers/user_preferences_provider.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorage;
  late UserPreferencesProvider provider;

  setUp(() {
    mockStorage = MockStorageService();
    provider = UserPreferencesProvider(mockStorage);
  });

  group('UserPreferencesProvider', () {
    test('currency delegates to StorageService', () {
      when(() => mockStorage.currency).thenReturn('GBP');
      expect(provider.currency, 'GBP');
    });

    test('setCurrency writes to storage and notifies listeners', () async {
      when(() => mockStorage.setCurrency(any())).thenAnswer((_) async {});
      when(() => mockStorage.currency).thenReturn('INR');

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setCurrency('INR');

      verify(() => mockStorage.setCurrency('INR')).called(1);
      expect(notifyCount, 1);
    });

    test('activeCategories delegates to StorageService', () {
      when(() => mockStorage.activeCategories)
          .thenReturn(['shopping', 'transport']);
      expect(provider.activeCategories, ['shopping', 'transport']);
    });

    test('setCategories writes to storage and notifies listeners', () async {
      when(() => mockStorage.setActiveCategories(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.activeCategories).thenReturn(['shopping']);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setCategories(['shopping']);

      verify(() => mockStorage.setActiveCategories(['shopping'])).called(1);
      expect(notifyCount, 1);
    });

    test('authMode delegates to StorageService', () {
      when(() => mockStorage.authMode).thenReturn('google');
      expect(provider.authMode, 'google');
    });
  });
}
