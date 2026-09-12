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
    r"(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited).*?(?:UPI\s+to|for)\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|;|Bal|Avl|Available|\n|$)",
    caseSensitive: false,
  );

  // Tier 1b: HDFC UPI "Sent" — "Sent Rs.577.00\nFrom HDFC Bank A/C *7897\nTo
  // 13 DHABHA\nOn 23/08/26". No debited/credited verb, so it needs its own
  // pattern rather than reusing _hdfcPattern.
  static final _hdfcSentPattern = RegExp(
    r"Sent\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+From\s+[\s\S]*?\s+To\s+"
    r"([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|;|,|\s+On\s+\d|\n|$)",
    caseSensitive: false,
  );

  // Tier 2: ICICI — "Acct XX1234 debited for Rs 520; Info: Swiggy"
  static final _iciciPattern = RegExp(
    r"(?:debited|credited)\s+for\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?Info:\s*([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|;|Avl|$)",
    caseSensitive: false,
  );

  // Tier 3: SBI — "A/c XXXX1234 is debited Rs.1,850 for BESCOM"
  static final _sbiPattern = RegExp(
    r"(?:a\/c|account)\s+\w+\s+is\s+(debited|credited)\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+on\s+[A-Za-z0-9\-\/]+\s+for\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|;|Avl|$)",
    caseSensitive: false,
  );

  // Tier 4: Generic bank, amount-first — covers most banks regardless of exact
  // account phrasing: "INR 1,240 debited from Axis Bank A/c for DMart",
  // "Rs.500 withdrawn from A/c XX1234 at ATM Sector18", "Rs 500 debited from
  // A/c XX1234 towards Electricity Bill". Skips over whatever sits between the
  // verb and the merchant instead of requiring literal "Bank/A/c/Acct" tokens,
  // so odd bank-specific phrasing doesn't break the match. "to" is excluded
  // when it precedes an account/card reference so "credited to a/c XX1234"
  // doesn't get swallowed as a merchant name.
  static final _genericBankPattern = RegExp(
    r"(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:is\s+|has\s+been\s+|was\s+)?(debited|credited|spent|withdrawn|charged)\b"
    r".*?\b(?:for|towards|at|to(?!\s*(?:a/?c\b|acct\b|account\b|card\b)))\s+"
    r"([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\.|;|,|\s+Bal|\s+Avl|\s+on\s+\d|\n|$)",
    caseSensitive: false,
  );

  // Tier 5: Card spend alert, verb-first — "You've spent INR 555.00 on your
  // HDFC Bank card **1234 at AMAZON on 15/07/26". Amount follows the verb
  // here instead of leading it, so it needs its own pattern rather than
  // reusing genericBankPattern's amount-first shape.
  static final _cardSpendPattern = RegExp(
    r"(spent|charged)\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?\bat\s+"
    r"([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:\s+on\s+\d|\.|;|,|\n|$)",
    caseSensitive: false,
  );

  // Tier 6: Generic UPI — "₹349 paid to Zomato via UPI"
  static final _upiPattern = RegExp(
    r"(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:paid|sent)\s+to\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)\s+(?:via|using|through)\s+UPI",
    caseSensitive: false,
  );

  // Tier 7: Acct Dr/Cr — "Acct XXX099 Dr. INR 52.00 on 07/07/26 to KAVALI SANJ; UPI: ..."
  static final _acctDrCrPattern = RegExp(
    r"acct\s+\w+\s+(dr|cr)\.?\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+on\s+[\d\/\-]+\s+to\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,35}?)(?:;|\.|Bal|Avl|$)",
    caseSensitive: false,
  );

  // Tier 8: Generic debit/credit/spend (amount + type only, no merchant)
  static final _genericPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited|spent|withdrawn|charged)',
    caseSensitive: false,
  );

  static const _senderHints = {
    'HDFCBK': 'HDFC', 'ICICIB': 'ICICI', 'SBIINB': 'SBI',
    'AXISBK': 'Axis', 'KOTAKB': 'Kotak', 'PNBSMS': 'PNB',
    'CANBNK': 'Canara', 'BOIIND': 'Bank of India', 'INDBNK': 'Indian Bank',
    'YESBNK': 'Yes Bank', 'IDFCBK': 'IDFC', 'RBLBNK': 'RBL',
    'BOBIBN': 'Bank of Baroda', 'UNIONB': 'Union Bank', 'IDIBNK': 'IDBI',
    'FEDBNK': 'Federal Bank', 'INDUSB': 'IndusInd', 'HSBCIN': 'HSBC',
    'CITIBK': 'Citibank', 'SCBLTD': 'Standard Chartered', 'PYTMBK': 'Paytm Payments Bank',
    'SIBLTD': 'South Indian Bank', 'KTKBNK': 'Karnataka Bank', 'JKBANK': 'J&K Bank',
    'DBSBNK': 'DBS', 'AUBANK': 'AU Small Finance', 'DCBBNK': 'DCB Bank',
    'UCOBNK': 'UCO Bank', 'CBINBK': 'Central Bank of India', 'MAHABK': 'Bank of Maharashtra',
  };

  /// Matches sender IDs case-insensitively, tolerating DLT prefixes/suffixes
  /// carriers add around the bank code (e.g. "AD-HDFCBK-S", "VM-ICICIB").
  static String? _accountHintFor(String sender) {
    final upper = sender.toUpperCase();
    final direct = _senderHints[upper];
    if (direct != null) return direct;
    for (final entry in _senderHints.entries) {
      if (upper.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static ParsedSmsResult? parse(String sender, String body) {
    final accountHint = _accountHintFor(sender);

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

    final m1b = _hdfcSentPattern.firstMatch(body);
    if (m1b != null) {
      final amount = _parseAmount(m1b.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: TransactionType.expense,
          merchant: _cleanMerchant(m1b.group(2)),
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

    final m5 = _cardSpendPattern.firstMatch(body);
    if (m5 != null) {
      final amount = _parseAmount(m5.group(2)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: TransactionType.expense,
          merchant: _cleanMerchant(m5.group(3)),
          accountHint: accountHint,
        );
      }
    }

    final m6 = _upiPattern.firstMatch(body);
    if (m6 != null) {
      final amount = _parseAmount(m6.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: TransactionType.expense,
          merchant: _cleanMerchant(m6.group(2)),
          accountHint: accountHint,
        );
      }
    }

    final m7 = _acctDrCrPattern.firstMatch(body);
    if (m7 != null) {
      final amount = _parseAmount(m7.group(2)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: _typeFrom(m7.group(1)!),
          merchant: _cleanMerchant(m7.group(3)),
          accountHint: accountHint,
        );
      }
    }

    final m8 = _genericPattern.firstMatch(body);
    if (m8 != null) {
      final amount = _parseAmount(m8.group(1)!);
      if (amount != null) {
        return ParsedSmsResult(
          amount: amount,
          type: _typeFrom(m8.group(2)!),
          accountHint: accountHint,
        );
      }
    }

    return null;
  }

  static double? _parseAmount(String raw) =>
      double.tryParse(raw.replaceAll(',', '').trim());

  static TransactionType _typeFrom(String keyword) =>
      keyword.toLowerCase().startsWith('cr') ? TransactionType.income : TransactionType.expense;

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
