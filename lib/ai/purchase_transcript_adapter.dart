import 'dart:convert';
import 'categorization_adapter.dart' show InferFn;

class PurchaseParseResult {
  final String? merchant;
  final double amount;

  const PurchaseParseResult({required this.merchant, required this.amount});
}

/// Gemma JSON-extraction fallback for [PurchaseTranscriptParser] misses,
/// modeled directly on [SmsParserAdapter] (lib/ai/sms_parser_adapter.dart) —
/// same prompt shape, same defensive parsing.
class PurchaseTranscriptAdapter {
  PurchaseTranscriptAdapter._();

  static Future<PurchaseParseResult?> parse({
    required String transcript,
    required InferFn infer,
  }) async {
    final prompt = '<start_of_turn>user\n'
        'Extract a purchase from this spoken transcript as JSON.\n'
        'Transcript: "$transcript"\n'
        'Reply with only: {"merchant":"...","amount":0.0}\n'
        'Unknown fields use null.\n'
        '<end_of_turn>\n'
        '<start_of_turn>model\n';

    try {
      final raw = await infer(prompt);
      final json = jsonDecode(raw.trim()) as Map<String, dynamic>;
      final amountRaw = json['amount'];
      if (amountRaw == null) return null;
      final amount = (amountRaw as num).toDouble();
      if (amount <= 0) return null;
      return PurchaseParseResult(
        merchant: json['merchant'] as String?,
        amount: amount,
      );
    } catch (_) {
      return null;
    }
  }
}
