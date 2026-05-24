class SmsFilter {
  static const _knownSenderIds = {
    'HDFCBK', 'ICICIB', 'SBIINB', 'AXISBK', 'KOTAKB',
    'PNBSMS', 'CANBNK', 'BOIIND', 'INDBNK', 'YESBNK',
    'IDFCBK', 'SCBINB', 'CSBBNK', 'FEDBKM', 'RBLBNK',
  };

  static const _financialKeywords = [
    'debited', 'credited', 'spent', 'paid', 'received',
    'transferred', 'inr', 'rs.', '₹', 'a/c', 'acct',
    'upi', 'neft', 'imps', 'rtgs',
  ];

  static final _otpPattern = RegExp(
    r'\b\d{4,8}\b.*\b(otp|one.time|password|verification)\b',
    caseSensitive: false,
  );

  static final _promoPattern = RegExp(
    r'\b(offer|discount|cashback|win|reward|lucky|congratulations)\b',
    caseSensitive: false,
  );

  static final _amountPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*[\d,]+',
    caseSensitive: false,
  );

  static bool isFinancial(String sender, String body) {
    if (_otpPattern.hasMatch(body)) return false;
    if (_promoPattern.hasMatch(body) && !_amountPattern.hasMatch(body)) return false;
    if (_knownSenderIds.contains(sender.toUpperCase())) return true;
    final lower = body.toLowerCase();
    return _financialKeywords.any(lower.contains);
  }
}
