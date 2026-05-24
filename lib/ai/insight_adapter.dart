import 'categorization_adapter.dart' show InferFn;

class InsightAdapter {
  InsightAdapter._();

  static Future<String?> generate({
    required Map<String, double> categoryTotals,
    required Map<String, double> budgetLimits,
    required double income,
    required InferFn infer,
  }) async {
    final lines = categoryTotals.entries.map((e) {
      final budget = budgetLimits[e.key];
      if (budget != null && budget > 0) {
        final pct = ((e.value / budget - 1) * 100).round();
        final sign = pct >= 0 ? '+$pct%' : '$pct%';
        return '${e.key} ₹${e.value.toStringAsFixed(0)} (budget ₹${budget.toStringAsFixed(0)} $sign)';
      }
      return '${e.key} ₹${e.value.toStringAsFixed(0)}';
    }).join(', ');

    final prompt = '<start_of_turn>user\n'
        'One actionable spending insight, max 2 sentences.\n'
        '$lines\n'
        '<end_of_turn>\n'
        '<start_of_turn>model\n';

    try {
      final raw = await infer(prompt);
      return raw.trim();
    } catch (_) {
      return null;
    }
  }
}
