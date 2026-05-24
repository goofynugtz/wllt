import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/summary_adapter.dart';

void main() {
  Future<String> goodInfer(String p) async =>
      '  In April you spent ₹31,914 — 37% of income.  ';
  Future<String> throwInfer(String p) async => throw Exception('fail');

  test('returns trimmed summary text', () async {
    final result = await SummaryAdapter.generate(
      month: 'April 2026',
      income: 85000,
      categoryTotals: {'home': 19000.0, 'groceries': 4570.0},
      totalSpent: 31914,
      infer: goodInfer,
    );
    expect(result, equals('In April you spent ₹31,914 — 37% of income.'));
  });

  test('returns null when infer throws', () async {
    final result = await SummaryAdapter.generate(
      month: 'April 2026',
      income: 85000,
      categoryTotals: {},
      totalSpent: 0,
      infer: throwInfer,
    );
    expect(result, isNull);
  });
}
