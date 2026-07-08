import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/insight_facts.dart';
import 'package:wllt/models/models.dart';

Transaction tx(
  String id,
  String title,
  String categoryId,
  double amount,
  DateTime date, {
  TransactionType type = TransactionType.expense,
}) =>
    Transaction(
      id: id,
      transactionTitle: title,
      categoryId: categoryId,
      amount: amount,
      type: type,
      date: date,
      account: 'a1',
      tags: const [],
    );

void main() {
  final asOf = DateTime(2026, 7, 15);

  test('detects monthly recurring subscription', () {
    final facts = InsightFacts.compute(
      transactions: [
        tx('n1', 'Netflix', 'movies', 649, DateTime(2026, 5, 18)),
        tx('n2', 'Netflix', 'movies', 649, DateTime(2026, 6, 18)),
        tx('n3', 'Netflix', 'movies', 649, DateTime(2026, 7, 18)),
      ],
      asOf: asOf,
      currencySymbol: '₹',
    );
    expect(facts.recurring, hasLength(1));
    expect(facts.recurring.first.title, 'Netflix');
    expect(facts.factLines.join('\n'), contains('Recurring subscriptions'));
  });

  test('frequent same-month orders are not recurring', () {
    final facts = InsightFacts.compute(
      transactions: [
        tx('s1', 'Swiggy', 'restaurant', 300, DateTime(2026, 7, 2)),
        tx('s2', 'Swiggy', 'restaurant', 350, DateTime(2026, 7, 9)),
        tx('s3', 'Swiggy', 'restaurant', 320, DateTime(2026, 7, 14)),
      ],
      asOf: asOf,
      currencySymbol: '₹',
    );
    expect(facts.recurring, isEmpty);
  });

  test('rent is excluded from cancellable recurring charges', () {
    final facts = InsightFacts.compute(
      transactions: [
        tx('r1', 'House Rent', 'home', 19000, DateTime(2026, 6, 1)),
        tx('r2', 'House Rent', 'home', 19000, DateTime(2026, 7, 1)),
      ],
      asOf: asOf,
      currencySymbol: '₹',
    );
    expect(facts.recurring, isEmpty);
  });

  test('flags month-over-month spike with counts', () {
    final facts = InsightFacts.compute(
      transactions: [
        tx('p1', 'Zomato', 'restaurant', 400, DateTime(2026, 6, 10)),
        tx('c1', 'Zomato', 'restaurant', 600, DateTime(2026, 7, 5)),
        tx('c2', 'Swiggy', 'restaurant', 500, DateTime(2026, 7, 10)),
      ],
      asOf: asOf,
      currencySymbol: '₹',
    );
    final line = facts.factLines
        .firstWhere((l) => l.contains('jumped'), orElse: () => '');
    expect(line, contains('Restaurant'));
    expect(line, contains('+175%'));
    expect(line, contains('2 transactions'));
  });

  test('flags budget overshoot', () {
    final facts = InsightFacts.compute(
      transactions: [
        tx('c1', 'Zomato', 'restaurant', 3400, DateTime(2026, 7, 5)),
      ],
      asOf: asOf,
      currencySymbol: '₹',
      budgetLimits: const {'restaurant': 3000},
    );
    expect(
      facts.factLines.join('\n'),
      contains('Restaurant is over budget'),
    );
  });

  test('totals, income, and name-keyed categories for asOf month only', () {
    final facts = InsightFacts.compute(
      transactions: [
        tx('i1', 'Salary', 'savings', 85000, DateTime(2026, 7, 1),
            type: TransactionType.income),
        tx('c1', 'D-Mart', 'groceries', 2000, DateTime(2026, 7, 5)),
        tx('old', 'D-Mart', 'groceries', 9999, DateTime(2026, 5, 5)),
      ],
      asOf: asOf,
      currencySymbol: '₹',
    );
    expect(facts.income, 85000);
    expect(facts.totalSpent, 2000);
    expect(facts.categoryTotals, {'Groceries': 2000});
  });

  test('empty month yields no summary material', () {
    final facts = InsightFacts.compute(
      transactions: [
        tx('old', 'D-Mart', 'groceries', 500, DateTime(2025, 1, 5)),
      ],
      asOf: asOf,
      currencySymbol: '₹',
    );
    expect(facts.categoryTotals, isEmpty);
    expect(facts.factLines, isEmpty);
  });
}
