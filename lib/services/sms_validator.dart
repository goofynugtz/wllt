import '../models/pending_sms_transaction.dart';

class SmsValidator {
  static const _allowlist = {
    'HDFCBK', 'ICICIB', 'SBIINB', 'AXISBK', 'KOTAKB',
    'PNBSMS', 'CANBNK', 'BOIIND', 'INDBNK', 'YESBNK',
    'IDFCBK', 'SCBINB', 'CSBBNK', 'FEDBKM', 'RBLBNK',
  };

  static final _phonePattern = RegExp(r'^\+?\d{7,13}$');
  static final _urlPattern = RegExp(r'https?://', caseSensitive: false);
  static final _phishingPattern = RegExp(
    r'\b(click here|enter otp|share your pin|share your password|share pin)\b',
    caseSensitive: false,
  );
  static final _imperativePattern = RegExp(
    r'\b(please pay|send money to|transfer to)\b',
    caseSensitive: false,
  );
  static final _urgencyPattern = RegExp(
    r'\b(immediately|account will be blocked|act now|last chance)\b',
    caseSensitive: false,
  );
  static final _amountPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static const _largeAmountThreshold = 500000.0;

  static SmsVerdict validate(String sender, String body) {
    if (_phonePattern.hasMatch(sender.trim())) return SmsVerdict.blocked;
    if (_urlPattern.hasMatch(body)) return SmsVerdict.blocked;
    if (_phishingPattern.hasMatch(body)) return SmsVerdict.blocked;
    if (_imperativePattern.hasMatch(body)) return SmsVerdict.blocked;

    if (_allowlist.contains(sender.toUpperCase())) return SmsVerdict.safe;

    if (_isTyposquat(sender)) return SmsVerdict.suspicious;
    if (_urgencyPattern.hasMatch(body) && _amountPattern.hasMatch(body)) {
      return SmsVerdict.suspicious;
    }
    final amount = _extractAmount(body);
    if (amount != null && amount > _largeAmountThreshold) return SmsVerdict.suspicious;

    return SmsVerdict.safe;
  }

  static bool _isTyposquat(String sender) {
    final upper = sender.toUpperCase();
    return _allowlist.any((id) => _levenshtein(upper, id) <= 2 && upper != id);
  }

  static double? _extractAmount(String body) {
    final match = _amountPattern.firstMatch(body);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) dp[i][0] = i;
    for (var j = 0; j <= b.length; j++) dp[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }
}
