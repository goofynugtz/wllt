import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/insight_adapter.dart';

void main() {
  Future<String> goodInfer(String p) async => '  Your restaurant spend is over budget.  ';
  Future<String> throwInfer(String p) async => throw Exception('fail');

  const totals = {'restaurant': 4200.0, 'groceries': 2800.0};
  const budgets = {'restaurant': 3000.0};

  test('returns trimmed insight text', () async {
    final result = await InsightAdapter.generate(
      categoryTotals: totals,
      budgetLimits: budgets,
      income: 85000,
      infer: goodInfer,
    );
    expect(result, equals('Your restaurant spend is over budget.'));
  });

  test('returns null when infer throws', () async {
    final result = await InsightAdapter.generate(
      categoryTotals: totals,
      budgetLimits: budgets,
      income: 85000,
      infer: throwInfer,
    );
    expect(result, isNull);
  });
}
