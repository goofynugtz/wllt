import 'categorization_adapter.dart' show InferFn;

class SummaryAdapter {
  SummaryAdapter._();

  /// Generates a 2-3 sentence monthly summary. [categoryTotals] should be
  /// keyed by display name; [facts] are optional pre-computed highlight lines
  /// (see InsightFacts) that let the model mention concrete changes.
  static Future<String?> generate({
    required String month,
    required double income,
    required Map<String, double> categoryTotals,
    required double totalSpent,
    List<String> facts = const [],
    String currencySymbol = '₹',
    required InferFn infer,
  }) async {
    final breakdown = categoryTotals.entries
        .map((e) => '${e.key} $currencySymbol${e.value.toStringAsFixed(0)}')
        .join(' · ');

    final factBlock = facts.isEmpty
        ? ''
        : 'Notable:\n${facts.map((f) => '- $f').join('\n')}\n';

    final prompt = '<start_of_turn>user\n'
        'Write a 2-3 sentence spending summary for $month. '
        'Mention the top category and the most notable change. No advice.\n'
        'Income $currencySymbol${income.toStringAsFixed(0)} · '
        'Total spent $currencySymbol${totalSpent.toStringAsFixed(0)}\n'
        '$breakdown\n'
        '$factBlock'
        '<end_of_turn>\n'
        '<start_of_turn>model\n';

    try {
      final raw = await infer(prompt);
      final text = raw.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }
}
