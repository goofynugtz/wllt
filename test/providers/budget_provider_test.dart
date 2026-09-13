import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/models/models.dart';
import 'package:wllt/providers/budget_provider.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;
  late BudgetProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_budget_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    provider = BudgetProvider(storage, devMode: false);
  });

  tearDown(() async {
    await storage.clearAll();
    await Hive.close();
  });
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('global budget', () {
    test('is null until set', () {
      expect(provider.globalBudget, isNull);
    });

    test('setGlobalBudget stores it and notifies', () async {
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.setGlobalBudget(30000);
      expect(provider.globalBudget?.amount, 30000);
      expect(provider.globalBudget?.period, BudgetPeriod.monthly);
      expect(notified, isTrue);
    });

    test('does not appear in categoryBudgets', () async {
      await provider.setGlobalBudget(30000);
      await provider.setBudget(
          const Budget(categoryId: 'groceries', amount: 5000, period: BudgetPeriod.monthly));
      final ids = provider.categoryBudgets.map((b) => b.categoryId);
      expect(ids, contains('groceries'));
      expect(ids, isNot(contains(BudgetProvider.globalBudgetId)));
    });

    test('deleteGlobalBudget removes it', () async {
      await provider.setGlobalBudget(30000);
      await provider.deleteGlobalBudget();
      expect(provider.globalBudget, isNull);
    });
  });

  group('monthlyEquivalent', () {
    test('passes monthly amounts through unchanged', () {
      const b = Budget(categoryId: 'x', amount: 1000, period: BudgetPeriod.monthly);
      expect(BudgetProvider.monthlyEquivalent(b), 1000);
    });

    test('scales weekly amounts by 4.33', () {
      const b = Budget(categoryId: 'x', amount: 1000, period: BudgetPeriod.weekly);
      expect(BudgetProvider.monthlyEquivalent(b), closeTo(4330, 0.01));
    });
  });

  group('remainingGlobalBudget', () {
    test('is infinite when no global budget set', () {
      expect(provider.remainingGlobalBudget(), double.infinity);
    });

    test('subtracts allocated category budgets from the global amount', () async {
      await provider.setGlobalBudget(10000);
      await provider.setBudget(
          const Budget(categoryId: 'groceries', amount: 4000, period: BudgetPeriod.monthly));
      await provider.setBudget(
          const Budget(categoryId: 'transport', amount: 1000, period: BudgetPeriod.weekly));
      // 10000 - 4000 - (1000 * 4.33) = 1670
      expect(provider.remainingGlobalBudget(), closeTo(1670, 0.01));
    });

    test('excludes the given category from the allocated sum', () async {
      await provider.setGlobalBudget(10000);
      await provider.setBudget(
          const Budget(categoryId: 'groceries', amount: 4000, period: BudgetPeriod.monthly));
      expect(provider.remainingGlobalBudget(excludingCategoryId: 'groceries'), 10000);
    });
  });
}
