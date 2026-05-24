import 'dart:convert';
import 'categorization_adapter.dart' show InferFn;

class SmsParseResult {
  final String? merchant;
  final double amount;
  final String type; // 'debit' | 'credit'

  const SmsParseResult({
    required this.merchant,
    required this.amount,
    required this.type,
  });
}

class SmsParserAdapter {
  SmsParserAdapter._();

  static Future<SmsParseResult?> parse({
    required String rawSms,
    required InferFn infer,
  }) async {
    final prompt = '<start_of_turn>user\n'
        'Extract transaction from this SMS as JSON.\n'
        'SMS: "$rawSms"\n'
        'Reply with only: {"merchant":"...","amount":0.0,"type":"debit|credit"}\n'
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
      final type = json['type'] as String? ?? 'debit';
      if (type != 'debit' && type != 'credit') return null;
      return SmsParseResult(
        merchant: json['merchant'] as String?,
        amount: amount,
        type: type,
      );
    } catch (_) {
      return null;
    }
  }
}
