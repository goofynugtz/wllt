import 'categorization_adapter.dart' show InferFn;

class SummaryAdapter {
  SummaryAdapter._();

  static Future<String?> generate({
    required String month,
    required double income,
    required Map<String, double> categoryTotals,
    required double totalSpent,
    required InferFn infer,
  }) async {
    final breakdown = categoryTotals.entries
        .map((e) => '${e.key} ₹${e.value.toStringAsFixed(0)}')
        .join(' · ');

    final prompt = '<start_of_turn>user\n'
        '2-3 sentence monthly spending summary.\n'
        '$month · Income ₹${income.toStringAsFixed(0)}\n'
        '$breakdown\n'
        'Total spent: ₹${totalSpent.toStringAsFixed(0)}\n'
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
