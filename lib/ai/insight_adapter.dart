import 'categorization_adapter.dart' show InferFn;

class InsightAdapter {
  InsightAdapter._();

  /// Generates one actionable saving suggestion from pre-computed [facts]
  /// (see InsightFacts). Returns null when there is nothing to say or
  /// inference fails.
  static Future<String?> generate({
    required List<String> facts,
    required InferFn infer,
  }) async {
    if (facts.isEmpty) return null;

    final prompt = '<start_of_turn>user\n'
        'You are a personal finance coach. Spending facts:\n'
        '${facts.map((f) => '- $f').join('\n')}\n'
        'Point out the single biggest saving opportunity and one concrete '
        'action (e.g. cancel a subscription, cap a category). '
        'Cite exact amounts from the facts. Max 2 sentences.\n'
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
