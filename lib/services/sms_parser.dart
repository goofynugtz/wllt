import '../models/models.dart';

class ParsedSmsResult {
  final double amount;
  final TransactionType type;
  final String? merchant;
  final String? accountHint;
  final DateTime? txDate;

  const ParsedSmsResult({
    required this.amount,
    required this.type,
    this.merchant,
    this.accountHint,
    this.txDate,
  });
}

class SmsParser {
  // Tier 1: HDFC — "Rs.349 debited from a/c XX1234 on UPI to ZOMATO"
  static final _hdfcPattern = RegExp(
    r"(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited).*?(?:UPI\s+to|for)\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|Bal|Avl|Available|\n|$)",
    caseSensitive: false,
  );

  // Tier 2: ICICI — "Acct XX1234 debited for Rs 520; Info: Swiggy"
  static final _iciciPattern = RegExp(
    r"(?:debited|credited)\s+for\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?Info:\s*([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|Avl|$)",
    caseSensitive: false,
  );

  // Tier 3: SBI — "A/c XXXX1234 is debited Rs.1,850 for BESCOM"
  static final _sbiPattern = RegExp(
    r"(?:a\/c|account)\s+\w+\s+is\s+(debited|credited)\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+on\s+[A-Za-z0-9\-\/]+\s+for\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|Avl|$)",
    caseSensitive: false,
  );

  // Tier 4: Generic bank — "INR 1,240 debited from Axis Bank A/c for DMart"
  static final _genericBankPattern = RegExp(
    r"(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited)\s+from\s+[A-Za-z\s]+(?:Bank|A\/c|Acct)[A-Za-z0-9\s]*for\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|Bal|$)",
    caseSensitive: false,
  );

  // Tier 5: Generic UPI — "₹349 paid to Zomato via UPI"
  static final _upiPattern = RegExp(
    r"(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:paid|sent)\s+to\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)\s+(?:via|using|through)\s+UPI",
    caseSensitive: false,
  );

  // Tier 6: Generic debit/credit (amount + type only, no merchant)
  static final _genericPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited)',
    caseSensitive: false,
  );

  static const _senderHints = {
    'HDFCBK': 'HDFC', 'ICICIB': 'ICICI', 'SBIINB': 'SBI',
    'AXISBK': 'Axis', 'KOTAKB': 'Kotak', 'PNBSMS': 'PNB',
    'CANBNK': 'Canara', 'BOIIND': 'Bank of India', 'INDBNK': 'Indian Bank',
    'YESBNK': 'Yes Bank', 'IDFCBK': 'IDFC', 'RBLBNK': 'RBL',
  };

  static ParsedSmsResult? parse(String sender, String body) {
    final accountHint = _senderHints[sender.toUpperCase()];

    final m1 = _hdfcPattern.firstMatch(body);
    if (m1 != null) {
      final amount = _parseAmount(m1.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: _typeFrom(m1.group(2)!),
          merchant: _cleanMerchant(m1.group(3)),
          accountHint: accountHint,
        );
      }
    }

    final m2 = _iciciPattern.firstMatch(body);
    if (m2 != null) {
      final amount = _parseAmount(m2.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: _typeFromBody(body),
          merchant: _cleanMerchant(m2.group(2)),
          accountHint: accountHint,
        );
      }
    }

    final m3 = _sbiPattern.firstMatch(body);
    if (m3 != null) {
      final amount = _parseAmount(m3.group(2)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: _typeFrom(m3.group(1)!),
          merchant: _cleanMerchant(m3.group(3)),
          accountHint: accountHint,
        );
      }
    }

    final m4 = _genericBankPattern.firstMatch(body);
    if (m4 != null) {
      final amount = _parseAmount(m4.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: _typeFrom(m4.group(2)!),
          merchant: _cleanMerchant(m4.group(3)),
          accountHint: accountHint,
        );
      }
    }

    final m5 = _upiPattern.firstMatch(body);
    if (m5 != null) {
      final amount = _parseAmount(m5.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: TransactionType.expense,
          merchant: _cleanMerchant(m5.group(2)),
          accountHint: accountHint,
        );
      }
    }

    final m6 = _genericPattern.firstMatch(body);
    if (m6 != null) {
      final amount = _parseAmount(m6.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: _typeFrom(m6.group(2)!),
          accountHint: accountHint,
        );
      }
    }

    return null;
  }

  static double? _parseAmount(String raw) =>
      double.tryParse(raw.replaceAll(',', '').trim());

  static TransactionType _typeFrom(String keyword) =>
      keyword.toLowerCase() == 'credited' ? TransactionType.income : TransactionType.expense;

  static TransactionType _typeFromBody(String body) {
    final lower = body.toLowerCase();
    return lower.contains('credited') || lower.contains('received')
        ? TransactionType.income
        : TransactionType.expense;
  }

  static String? _cleanMerchant(String? raw) {
    if (raw == null) return null;
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
