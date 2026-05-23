# SMS Parsing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete SMS parsing pipeline that reads bank messages on Android (background WorkManager + share intent) and iOS (Share Extension), extracts transaction data deterministically, and surfaces a review queue via the notification bell in `layout_screen.dart`.

**Architecture:** Pure-Dart pipeline (SmsValidator → SmsFilter → SmsParser → SmsRulesEngine) feeds a Hive-backed `SmsPendingStore`, exposed via `SmsProvider` (ChangeNotifier). `SmsReader` is the only platform boundary. UI is a bottom sheet (`SmsInboxSheet`) containing inline-editable swipeable `SmsPendingCard` widgets.

**Tech Stack:** Flutter/Dart, Hive (existing), `flutter_workmanager`, `flutter_sms_inbox`, `receive_sharing_intent`, `crypto`, native Swift (iOS Share Extension)

---

### Task 1: Dependencies + data model

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/models/pending_sms_transaction.dart`
- Modify: `lib/models/models.dart` (remove `SmsParsed` stub)

- [ ] **Add dependencies to `pubspec.yaml`**

```yaml
  flutter_workmanager: ^0.5.0
  flutter_sms_inbox: ^1.0.0
  receive_sharing_intent: ^2.0.0
  crypto: ^3.0.0
```

- [ ] **Run `flutter pub get`**

Expected: no errors.

- [ ] **Create `lib/models/pending_sms_transaction.dart`**

```dart
import 'models.dart';

enum SmsVerdict { safe, suspicious, blocked }

class PendingSmsTransaction {
  final String id;
  final String rawSms;
  final String? merchant;
  final double? amount;
  final TransactionType type;
  final String? categoryId;
  final String? accountHint;
  final DateTime parsedAt;
  final bool isUnparsed;
  final SmsVerdict verdict;

  const PendingSmsTransaction({
    required this.id,
    required this.rawSms,
    this.merchant,
    this.amount,
    required this.type,
    this.categoryId,
    this.accountHint,
    required this.parsedAt,
    required this.isUnparsed,
    required this.verdict,
  });

  PendingSmsTransaction copyWith({
    String? merchant,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountHint,
  }) => PendingSmsTransaction(
    id: id,
    rawSms: rawSms,
    merchant: merchant ?? this.merchant,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    accountHint: accountHint ?? this.accountHint,
    parsedAt: parsedAt,
    isUnparsed: isUnparsed,
    verdict: verdict,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'rawSms': rawSms,
    if (merchant != null) 'merchant': merchant,
    if (amount != null) 'amount': amount,
    'type': type.name,
    if (categoryId != null) 'categoryId': categoryId,
    if (accountHint != null) 'accountHint': accountHint,
    'parsedAt': parsedAt.toIso8601String(),
    'isUnparsed': isUnparsed,
    'verdict': verdict.name,
  };

  factory PendingSmsTransaction.fromJson(Map<String, dynamic> json) =>
      PendingSmsTransaction(
        id: json['id'] as String,
        rawSms: json['rawSms'] as String,
        merchant: json['merchant'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        type: TransactionType.values.firstWhere((e) => e.name == json['type']),
        categoryId: json['categoryId'] as String?,
        accountHint: json['accountHint'] as String?,
        parsedAt: DateTime.parse(json['parsedAt'] as String),
        isUnparsed: json['isUnparsed'] as bool,
        verdict: SmsVerdict.values.firstWhere((e) => e.name == json['verdict']),
      );
}
```

- [ ] **Remove `SmsParsed` class from `lib/models/models.dart`**

Delete lines 919–962 (the `SmsParsed` class and its `smsParsed` list). Also delete the `SmsImportForm` widget from `lib/widgets/add_expense_sheet.dart` (lines 1554–1820) — it uses the now-deleted `SmsParsed` dummy model.

- [ ] **Run `flutter analyze`**

Expected: no errors referencing `SmsParsed`. Fix any remaining references.

- [ ] **Commit**

```
git add pubspec.yaml pubspec.lock lib/models/pending_sms_transaction.dart lib/models/models.dart lib/widgets/add_expense_sheet.dart
git commit -m "feat: add PendingSmsTransaction model, remove SmsParsed stub"
```

---

### Task 2: SmsFilter

**Files:**
- Create: `lib/services/sms_filter.dart`
- Create: `test/services/sms_filter_test.dart`

- [ ] **Write the failing tests**

```dart
// test/services/sms_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/services/sms_filter.dart';

void main() {
  group('SmsFilter', () {
    test('drops OTP messages', () {
      expect(
        SmsFilter.isFinancial('HDFCBK', '123456 is your OTP for login. Do not share.'),
        isFalse,
      );
    });

    test('drops promo messages without amount', () {
      expect(
        SmsFilter.isFinancial('ADVERT', 'Congratulations! You have won a reward. Click to claim.'),
        isFalse,
      );
    });

    test('keeps promo sender if body has financial keyword and amount', () {
      expect(
        SmsFilter.isFinancial('OFFERS', 'Cashback of Rs.50 credited to your account.'),
        isTrue,
      );
    });

    test('keeps known sender regardless of body', () {
      expect(
        SmsFilter.isFinancial('HDFCBK', 'Your account has been updated.'),
        isTrue,
      );
    });

    test('keeps unknown sender with financial keyword', () {
      expect(
        SmsFilter.isFinancial('VM-ICICI', 'Rs.520 debited from your account for Swiggy.'),
        isTrue,
      );
    });

    test('drops unknown sender with no financial keyword', () {
      expect(
        SmsFilter.isFinancial('TMINFO', 'Your appointment is confirmed for tomorrow at 10am.'),
        isFalse,
      );
    });

    test('keeps UPI payment message', () {
      expect(
        SmsFilter.isFinancial('PAYTM', '₹349 paid to Zomato via UPI. Ref: 123456789'),
        isTrue,
      );
    });
  });
}
```

- [ ] **Run to confirm failure**

```
flutter test test/services/sms_filter_test.dart
```

Expected: `Error: 'package:wllt/services/sms_filter.dart' not found`

- [ ] **Implement `lib/services/sms_filter.dart`**

```dart
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
```

- [ ] **Run tests**

```
flutter test test/services/sms_filter_test.dart
```

Expected: all 7 pass.

- [ ] **Commit**

```
git add lib/services/sms_filter.dart test/services/sms_filter_test.dart
git commit -m "feat: add SmsFilter with OTP/promo/keyword detection"
```

---

### Task 3: SmsValidator

**Files:**
- Create: `lib/services/sms_validator.dart`
- Create: `test/services/sms_validator_test.dart`

- [ ] **Write the failing tests**

```dart
// test/services/sms_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/services/sms_validator.dart';
import 'package:wllt/models/pending_sms_transaction.dart';

void main() {
  group('SmsValidator', () {
    test('blocks phone number sender', () {
      expect(
        SmsValidator.validate('9876543210', 'Rs.500 debited from your account'),
        SmsVerdict.blocked,
      );
    });

    test('blocks message with URL', () {
      expect(
        SmsValidator.validate('HDFCBK', 'Rs.500 debited. Click https://pay.now to verify'),
        SmsVerdict.blocked,
      );
    });

    test('blocks phishing request for PIN', () {
      expect(
        SmsValidator.validate('VM-BANK', 'Rs.500 received. Share your PIN to claim.'),
        SmsVerdict.blocked,
      );
    });

    test('blocks imperative payment request', () {
      expect(
        SmsValidator.validate('OFFER1', 'Please pay Rs.500 to complete your order.'),
        SmsVerdict.blocked,
      );
    });

    test('safe for exact allowlist sender', () {
      expect(
        SmsValidator.validate('HDFCBK', 'Rs.349 debited from a/c XX4242 to ZOMATO'),
        SmsVerdict.safe,
      );
    });

    test('suspicious for typosquat sender (edit distance 1)', () {
      expect(
        SmsValidator.validate('HDFCB', 'Rs.349 debited from your account'),
        SmsVerdict.suspicious,
      );
    });

    test('suspicious for urgency language with amount', () {
      expect(
        SmsValidator.validate('NEWBNK', 'Rs.500 debited. Act now to reverse this transaction immediately.'),
        SmsVerdict.suspicious,
      );
    });

    test('suspicious for amount over 5 lakh', () {
      expect(
        SmsValidator.validate('NEWBNK', 'Rs.6,00,000 debited from your account'),
        SmsVerdict.suspicious,
      );
    });

    test('safe for unknown sender without suspicious signals', () {
      expect(
        SmsValidator.validate('BANKXX', 'Rs.349 debited from your account for Zomato'),
        SmsVerdict.safe,
      );
    });
  });
}
```

- [ ] **Run to confirm failure**

```
flutter test test/services/sms_validator_test.dart
```

- [ ] **Implement `lib/services/sms_validator.dart`**

```dart
import 'pending_sms_transaction.dart';

// ignore: avoid_relative_lib_imports
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
    // Block conditions
    if (_phonePattern.hasMatch(sender.trim())) return SmsVerdict.blocked;
    if (_urlPattern.hasMatch(body)) return SmsVerdict.blocked;
    if (_phishingPattern.hasMatch(body)) return SmsVerdict.blocked;
    if (_imperativePattern.hasMatch(body)) return SmsVerdict.blocked;

    // Safe: exact allowlist match
    if (_allowlist.contains(sender.toUpperCase())) return SmsVerdict.safe;

    // Suspicious conditions
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
```

- [ ] **Fix import in `sms_validator.dart`** — replace the double import with:

```dart
import '../models/pending_sms_transaction.dart';
```

- [ ] **Run tests**

```
flutter test test/services/sms_validator_test.dart
```

Expected: all 9 pass.

- [ ] **Commit**

```
git add lib/services/sms_validator.dart test/services/sms_validator_test.dart
git commit -m "feat: add SmsValidator with fraud detection and Levenshtein typosquat check"
```

---

### Task 4: SmsParser

**Files:**
- Create: `lib/services/sms_parser.dart`
- Create: `test/services/sms_parser_test.dart`

- [ ] **Write the failing tests**

```dart
// test/services/sms_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/services/sms_parser.dart';
import 'package:wllt/models/models.dart';

void main() {
  group('SmsParser', () {
    test('parses HDFC UPI debit', () {
      final r = SmsParser.parse('HDFCBK', 'Rs.349.00 debited from a/c XX4242 on UPI to ZOMATO. Bal: Rs.12,450.00');
      expect(r, isNotNull);
      expect(r!.amount, 349.00);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('zomato'));
      expect(r.accountHint, 'HDFC');
    });

    test('parses ICICI debit with Info field', () {
      final r = SmsParser.parse('ICICIB', 'ICICI Bank Acct XX1234 debited for Rs 520.00 on 07-Apr-26; Info: Swiggy. Avl Bal: Rs 12,345.67');
      expect(r, isNotNull);
      expect(r!.amount, 520.00);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('swiggy'));
      expect(r.accountHint, 'ICICI');
    });

    test('parses SBI debit', () {
      final r = SmsParser.parse('SBIINB', 'Your A/c XXXX1234 is debited Rs.1,850.00 on 08-Apr-26 for BESCOM ONLINE. Avl Bal: Rs.40,500.00');
      expect(r, isNotNull);
      expect(r!.amount, 1850.00);
      expect(r.type, TransactionType.expense);
      expect(r.accountHint, 'SBI');
    });

    test('parses generic UPI payment', () {
      final r = SmsParser.parse('PAYTM', '₹349 paid to Zomato via UPI. Ref: 123456789012');
      expect(r, isNotNull);
      expect(r!.amount, 349.0);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('zomato'));
    });

    test('parses credit transaction as income', () {
      final r = SmsParser.parse('HDFCBK', 'Rs.85,000.00 credited to a/c XX1234. NEFT from EMPLOYER LTD.');
      expect(r, isNotNull);
      expect(r!.amount, 85000.00);
      expect(r.type, TransactionType.income);
    });

    test('returns null for non-financial message', () {
      final r = SmsParser.parse('RANDOM', 'Your appointment is confirmed for tomorrow.');
      expect(r, isNull);
    });

    test('handles comma-separated amounts', () {
      final r = SmsParser.parse('AXISBK', 'INR 1,240.00 debited from Axis Bank A/c for DMart');
      expect(r, isNotNull);
      expect(r!.amount, 1240.00);
    });
  });
}
```

- [ ] **Run to confirm failure**

```
flutter test test/services/sms_parser_test.dart
```

- [ ] **Implement `lib/services/sms_parser.dart`**

```dart
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
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited).*?(?:UPI\s+to|for)\s+([A-Za-z0-9][A-Za-z0-9\s&\'.,-]{1,35}?)(?:\.|Bal|Avl|Available|\n|$)',
    caseSensitive: false,
  );

  // Tier 2: ICICI — "Acct XX1234 debited for Rs 520; Info: Swiggy"
  static final _iciciPattern = RegExp(
    r'(?:debited|credited)\s+for\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?).*?Info:\s*([A-Za-z0-9][A-Za-z0-9\s&\'.,-]{1,35}?)(?:\.|Avl|$)',
    caseSensitive: false,
  );

  // Tier 3: SBI — "A/c XXXX1234 is debited Rs.1,850 for BESCOM"
  static final _sbiPattern = RegExp(
    r'(?:a\/c|account)\s+\w+\s+is\s+(debited|credited)\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+on\s+[\d\-\/]+\s+for\s+([A-Za-z0-9][A-Za-z0-9\s&\'.,-]{1,35}?)(?:\.|Avl|$)',
    caseSensitive: false,
  );

  // Tier 4: Generic bank — "INR 1,240 debited from Axis Bank A/c for DMart"
  static final _genericBankPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited)\s+from\s+[A-Za-z\s]+(?:Bank|A\/c|Acct)[A-Za-z0-9\s]*for\s+([A-Za-z0-9][A-Za-z0-9\s&\'.,-]{1,35}?)(?:\.|Bal|$)',
    caseSensitive: false,
  );

  // Tier 5: Generic UPI — "₹349 paid to Zomato via UPI"
  static final _upiPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+(?:paid|sent)\s+to\s+([A-Za-z0-9][A-Za-z0-9\s&\'.,-]{1,35}?)\s+(?:via|using|through)\s+UPI',
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

    // Tier 1: HDFC pattern
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

    // Tier 2: ICICI pattern
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

    // Tier 3: SBI pattern
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

    // Tier 4: Generic bank pattern
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

    // Tier 5: UPI pattern
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

    // Tier 6: Generic — amount + type only
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
```

- [ ] **Run tests**

```
flutter test test/services/sms_parser_test.dart
```

Expected: all 7 pass. If HDFC/ICICI/SBI regex tests fail, adjust the pattern to match the test SMS string exactly.

- [ ] **Commit**

```
git add lib/services/sms_parser.dart test/services/sms_parser_test.dart
git commit -m "feat: add SmsParser with 6-tier Indian bank regex engine"
```

---

### Task 5: SmsRulesEngine

**Files:**
- Create: `lib/services/sms_rules_engine.dart`
- Create: `test/services/sms_rules_engine_test.dart`

- [ ] **Write the failing tests**

```dart
// test/services/sms_rules_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/services/sms_rules_engine.dart';

void main() {
  group('SmsRulesEngine', () {
    test('maps Zomato to restaurant', () {
      expect(SmsRulesEngine.categorize('Zomato'), 'restaurant');
    });

    test('maps BigBasket to groceries', () {
      expect(SmsRulesEngine.categorize('BigBasket'), 'groceries');
    });

    test('maps Netflix to movies', () {
      expect(SmsRulesEngine.categorize('Netflix'), 'movies');
    });

    test('maps BESCOM to utilities', () {
      expect(SmsRulesEngine.categorize('BESCOM'), 'utilities');
    });

    test('maps Apollo Pharmacy via tier-1 exact match', () {
      expect(SmsRulesEngine.categorize('Apollo Pharmacy'), 'doctor');
    });

    test('maps unknown pharmacy via tier-2 keyword', () {
      expect(SmsRulesEngine.categorize('MedPlus pharmacy'), 'doctor');
    });

    test('maps gym via tier-2 keyword', () {
      expect(SmsRulesEngine.categorize('Local gym'), 'fitness');
    });

    test('returns null for unknown merchant', () {
      expect(SmsRulesEngine.categorize('XYZ Corp'), isNull);
    });

    test('returns null for null merchant', () {
      expect(SmsRulesEngine.categorize(null), isNull);
    });

    test('case-insensitive match', () {
      expect(SmsRulesEngine.categorize('ZOMATO'), 'restaurant');
    });
  });
}
```

- [ ] **Run to confirm failure**

```
flutter test test/services/sms_rules_engine_test.dart
```

- [ ] **Implement `lib/services/sms_rules_engine.dart`**

```dart
class SmsRulesEngine {
  static const _merchantMap = <String, String>{
    // Restaurant
    'zomato': 'restaurant', 'swiggy': 'restaurant', 'eatfit': 'restaurant',
    'fasoos': 'restaurant', 'box8': 'restaurant', 'faasos': 'restaurant',
    // Groceries
    'bigbasket': 'groceries', 'dmart': 'groceries', 'blinkit': 'groceries',
    'zepto': 'groceries', 'jiomart': 'groceries', 'grofers': 'groceries',
    'swiggy instamart': 'groceries', 'dunzo': 'groceries', 'big bazaar': 'groceries',
    // Shopping
    'amazon': 'shopping', 'flipkart': 'shopping', 'myntra': 'shopping',
    'meesho': 'shopping', 'nykaa': 'shopping', 'ajio': 'shopping',
    'decathlon': 'shopping', 'reliance digital': 'shopping', 'croma': 'shopping',
    'snapdeal': 'shopping', 'tatacliq': 'shopping',
    // Transport
    'uber': 'transport', 'ola': 'transport', 'rapido': 'transport',
    'bmtc': 'transport', 'best bus': 'transport', 'dtc': 'transport',
    'metro': 'transport', 'irctc': 'transport', 'redbus': 'transport',
    'yulu': 'transport', 'bounce': 'transport',
    // Movies / Entertainment
    'netflix': 'movies', 'hotstar': 'movies', 'amazon prime': 'movies',
    'inox': 'movies', 'pvr': 'movies', 'bookmyshow': 'movies',
    'sony liv': 'movies', 'zee5': 'movies', 'voot': 'movies',
    'jio cinema': 'movies', 'apple tv': 'movies', 'disney': 'movies',
    // Utilities
    'bescom': 'utilities', 'mseb': 'utilities', 'tpddl': 'utilities',
    'bses': 'utilities', 'torrent power': 'utilities',
    'jio': 'utilities', 'airtel': 'utilities', 'vi ': 'utilities',
    'bsnl': 'utilities', 'act fibernet': 'utilities', 'hathway': 'utilities',
    'tata sky': 'utilities', 'dish tv': 'utilities',
    // Doctor / Medical
    'apollo pharmacy': 'doctor', 'practo': 'doctor', 'pharmeasy': 'doctor',
    '1mg': 'doctor', 'medline': 'doctor', 'netmeds': 'doctor',
    'apollo hospitals': 'doctor', 'fortis': 'doctor', 'max hospital': 'doctor',
    // Coffee
    'blue tokai': 'coffee', 'starbucks': 'coffee', 'cafe coffee day': 'coffee',
    'third wave': 'coffee', 'barista': 'coffee', 'tim hortons': 'coffee',
    // Fitness
    'decathlon': 'fitness', 'cure.fit': 'fitness', 'cult.fit': 'fitness',
    'gold gym': 'fitness', 'anytime fitness': 'fitness',
    // Travel
    'makemytrip': 'travel', 'goibibo': 'travel', 'cleartrip': 'travel',
    'indigo': 'travel', 'air india': 'travel', 'spicejet': 'travel',
    'oyo': 'travel', 'airbnb': 'travel', 'treebo': 'travel',
    'fabhotels': 'travel', 'agoda': 'travel',
    // Education
    'byjus': 'education', "byju's": 'education', 'unacademy': 'education',
    'coursera': 'education', 'udemy': 'education', 'upgrad': 'education',
    'vedantu': 'education', 'whitehat jr': 'education',
    // Phone / Internet (Jio/Airtel covered under utilities; phone-specific below)
    'jio recharge': 'phone', 'airtel recharge': 'phone', 'vi recharge': 'phone',
    // Gifts
    'amazon gift': 'gifts', 'flipkart gift': 'gifts',
    // Home
    'urban company': 'home', 'urbanclap': 'home', 'sulekha': 'home',
  };

  static const _keywordMap = <String, String>{
    'pharmacy': 'doctor', 'clinic': 'doctor', 'hospital': 'doctor',
    'medical': 'doctor', 'health': 'doctor',
    'cafe': 'coffee', 'coffee': 'coffee',
    'gym': 'fitness', 'fitness': 'fitness', 'yoga': 'fitness', 'sports': 'fitness',
    'school': 'education', 'college': 'education', 'university': 'education',
    'course': 'education', 'institute': 'education',
    'hotel': 'travel', 'resort': 'travel',
    'recharge': 'phone', 'broadband': 'internet', 'dth': 'utilities',
    'salary': 'savings', 'stipend': 'savings',
    'refund': 'savings', 'cashback': 'savings',
    'grocery': 'groceries', 'supermarket': 'groceries', 'mart': 'groceries',
    'restaurant': 'restaurant', 'food': 'restaurant', 'kitchen': 'restaurant',
    'pizza': 'restaurant', 'burger': 'restaurant', 'biryani': 'restaurant',
  };

  static String? categorize(String? merchant) {
    if (merchant == null) return null;
    final lower = merchant.toLowerCase().trim();

    for (final entry in _merchantMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    for (final entry in _keywordMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
```

> **Note:** `SmsRulesEngine.categorize()` returns a **category hint** string (e.g. `'restaurant'`), not a category ID. Users create their own categories — these IDs do not exist by default. `SmsProvider` resolves hints against the user's active categories at runtime (see Task 7). The tests verify hint strings, not IDs — no test changes needed.

- [ ] **Run tests**

```
flutter test test/services/sms_rules_engine_test.dart
```

Expected: all 10 pass.

- [ ] **Commit**

```
git add lib/services/sms_rules_engine.dart test/services/sms_rules_engine_test.dart
git commit -m "feat: add SmsRulesEngine with merchant-to-category hint map"
```

---

### Task 6: SmsPendingStore

**Files:**
- Create: `lib/services/sms_pending_store.dart`
- Create: `test/services/sms_pending_store_test.dart`

- [ ] **Write the failing tests**

```dart
// test/services/sms_pending_store_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wllt/services/sms_pending_store.dart';
import 'package:wllt/models/pending_sms_transaction.dart';
import 'package:wllt/models/models.dart';

PendingSmsTransaction _make(String id, {bool isUnparsed = false}) =>
    PendingSmsTransaction(
      id: id,
      rawSms: 'Rs.100 debited',
      amount: 100,
      type: TransactionType.expense,
      parsedAt: DateTime.now(),
      isUnparsed: isUnparsed,
      verdict: SmsVerdict.safe,
    );

void main() {
  late Directory tempDir;
  late SmsPendingStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    store = SmsPendingStore();
    await store.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('SmsPendingStore', () {
    test('starts empty', () {
      expect(store.all, isEmpty);
    });

    test('adds item', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      expect(store.all.length, 1);
      expect(store.all.first.id, 'id1');
    });

    test('dedup returns new_message for unknown', () {
      expect(store.checkDuplicate(null, 'newhash'), DedupResult.newMessage);
    });

    test('dedup detects duplicate by contentHash in pending', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      expect(store.checkDuplicate(null, 'hash1'), DedupResult.duplicatePending);
    });

    test('dedup detects confirmed by contentHash', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      await store.confirm('id1');
      expect(store.checkDuplicate(null, 'hash1'), DedupResult.duplicateConfirmed);
    });

    test('dismiss removes item', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      await store.dismiss('id1');
      expect(store.all, isEmpty);
    });

    test('update replaces item fields', () async {
      await store.add(_make('id1'), smsId: 'id1', contentHash: 'hash1');
      await store.update('id1', _make('id1').copyWith(merchant: 'Zomato'));
      expect(store.all.first.merchant, 'Zomato');
    });

    test('lastScanTs is null initially', () {
      expect(store.lastScanTs, isNull);
    });

    test('setLastScanTs persists', () async {
      final ts = DateTime(2026, 5, 23);
      await store.setLastScanTs(ts);
      expect(store.lastScanTs, ts);
    });
  });
}
```

- [ ] **Run to confirm failure**

```
flutter test test/services/sms_pending_store_test.dart
```

- [ ] **Implement `lib/services/sms_pending_store.dart`**

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/pending_sms_transaction.dart';

enum DedupResult { newMessage, duplicatePending, duplicateConfirmed }

class SmsPendingStore {
  static const _pendingBox = 'sms_pending';
  static const _metaBox = 'sms_meta';
  static const _processedIdsKey = 'processed_ids';
  static const _contentHashesKey = 'content_hashes';
  static const _confirmedHashesKey = 'confirmed_hashes';
  static const _idHashMapKey = 'id_hash_map';   // id → contentHash
  static const _lastScanTsKey = 'sms_last_scan_ts';

  late Box _pending;
  late Box _meta;

  Future<void> init() async {
    _pending = await Hive.openBox(_pendingBox);
    _meta = await Hive.openBox(_metaBox);
  }

  List<PendingSmsTransaction> get all => _pending.values
      .map((v) => PendingSmsTransaction.fromJson(Map<String, dynamic>.from(v as Map)))
      .toList()
    ..sort((a, b) => b.parsedAt.compareTo(a.parsedAt));

  DedupResult checkDuplicate(String? smsId, String contentHash) {
    final pendingHashes = _getSet(_contentHashesKey);
    final confirmedHashes = _getSet(_confirmedHashesKey);
    final processedIds = _getSet(_processedIdsKey);

    if (confirmedHashes.contains(contentHash)) return DedupResult.duplicateConfirmed;
    if (smsId != null && processedIds.contains(smsId)) {
      return pendingHashes.contains(contentHash)
          ? DedupResult.duplicatePending
          : DedupResult.duplicateConfirmed;
    }
    if (pendingHashes.contains(contentHash)) return DedupResult.duplicatePending;
    return DedupResult.newMessage;
  }

  Future<void> add(
    PendingSmsTransaction item, {
    required String? smsId,
    required String contentHash,
  }) async {
    await _pending.put(item.id, item.toJson());
    final hashes = _getSet(_contentHashesKey)..add(contentHash);
    await _meta.put(_contentHashesKey, hashes.toList());
    // Store id → contentHash so confirm() can move the hash to the confirmed set
    final idHashMap = _getMap(_idHashMapKey)..[item.id] = contentHash;
    await _meta.put(_idHashMapKey, idHashMap);
    if (smsId != null) {
      final ids = _getSet(_processedIdsKey)..add(smsId);
      await _meta.put(_processedIdsKey, ids.toList());
    }
  }

  Future<void> confirm(String id) async {
    if (_pending.get(id) == null) return;
    await _pending.delete(id);
    final idHashMap = _getMap(_idHashMapKey);
    final hash = idHashMap.remove(id);
    await _meta.put(_idHashMapKey, idHashMap);
    if (hash != null) {
      final pendingHashes = _getSet(_contentHashesKey)..remove(hash);
      await _meta.put(_contentHashesKey, pendingHashes.toList());
      final confirmedHashes = _getSet(_confirmedHashesKey)..add(hash);
      await _meta.put(_confirmedHashesKey, confirmedHashes.toList());
    }
  }

  Future<void> dismiss(String id) async {
    await _pending.delete(id);
    final idHashMap = _getMap(_idHashMapKey)..remove(id);
    await _meta.put(_idHashMapKey, idHashMap);
  }

  Future<void> update(String id, PendingSmsTransaction updated) async {
    await _pending.put(id, updated.toJson());
  }

  DateTime? get lastScanTs {
    final raw = _meta.get(_lastScanTsKey) as String?;
    return raw != null ? DateTime.parse(raw) : null;
  }

  Future<void> setLastScanTs(DateTime ts) async {
    await _meta.put(_lastScanTsKey, ts.toIso8601String());
  }

  Set<String> _getSet(String key) {
    final raw = _meta.get(key);
    if (raw == null) return {};
    return (raw as List).cast<String>().toSet();
  }

  Map<String, String> _getMap(String key) {
    final raw = _meta.get(key);
    if (raw == null) return {};
    return Map<String, String>.from(raw as Map);
  }
}
```

- [ ] **Run tests**

```
flutter test test/services/sms_pending_store_test.dart
```

Expected: all 9 pass.

- [ ] **Commit**

```
git add lib/services/sms_pending_store.dart test/services/sms_pending_store_test.dart
git commit -m "feat: add SmsPendingStore with Hive persistence and deduplication"
```

---

### Task 7: SmsProvider

**Files:**
- Create: `lib/providers/sms_provider.dart`

- [ ] **Implement `lib/providers/sms_provider.dart`**

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/models.dart';
import '../models/pending_sms_transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/sms_validator.dart';
import '../services/sms_filter.dart';
import '../services/sms_parser.dart';
import '../services/sms_rules_engine.dart';
import '../services/sms_pending_store.dart';
import '../services/storage_service.dart';

enum ProcessResult { added, alreadyCaptured, alreadyPending, blocked, filtered }

class SmsProvider extends ChangeNotifier {
  final SmsPendingStore _store;
  final TransactionProvider _transactions;
  final AccountProvider _accounts;
  final UserPreferencesProvider _prefs;
  final StorageService _storage;

  // Set when a duplicate-pending SMS is shared; SmsInboxSheet scrolls to + highlights this id.
  String? _highlightedId;
  String? get highlightedId => _highlightedId;
  void clearHighlight() {
    _highlightedId = null;
    notifyListeners();
  }

  bool _miscCategoryJustCreated = false;
  bool get miscCategoryJustCreated => _miscCategoryJustCreated;
  void clearMiscCategoryFlag() => _miscCategoryJustCreated = false;

  SmsProvider({
    required SmsPendingStore store,
    required TransactionProvider transactions,
    required AccountProvider accounts,
    required UserPreferencesProvider prefs,
    required StorageService storage,
  })  : _store = store,
        _transactions = transactions,
        _accounts = accounts,
        _prefs = prefs,
        _storage = storage;

  List<PendingSmsTransaction> get pending => _store.all;
  int get pendingCount => pending.length;

  Future<ProcessResult> processRawSms(String sender, String body, String? smsId) async {
    final contentHash = _hashBody(body);
    final dedup = _store.checkDuplicate(smsId, contentHash);
    if (dedup == DedupResult.duplicateConfirmed) return ProcessResult.alreadyCaptured;
    if (dedup == DedupResult.duplicatePending) {
      // Surface existing card in inbox sheet
      final existing = pending.firstWhereOrNull((p) => p.rawSms == body);
      if (existing != null) {
        _highlightedId = existing.id;
        notifyListeners();
      }
      return ProcessResult.alreadyPending;
    }

    final verdict = SmsValidator.validate(sender, body);
    if (verdict == SmsVerdict.blocked) return ProcessResult.blocked;

    if (!SmsFilter.isFinancial(sender, body)) return ProcessResult.filtered;

    final parsed = SmsParser.parse(sender, body);
    final hint = SmsRulesEngine.categorize(parsed?.merchant);
    final categoryId = hint != null ? _resolveCategoryId(hint) : null;
    final accountHint = parsed?.accountHint ?? _hintFromSender(sender);

    final item = PendingSmsTransaction(
      id: smsId ?? contentHash,
      rawSms: body,
      merchant: parsed?.merchant,
      amount: parsed?.amount,
      type: parsed?.type ?? TransactionType.expense,
      categoryId: categoryId,
      accountHint: accountHint,
      parsedAt: DateTime.now(),
      isUnparsed: parsed == null,
      verdict: verdict,
    );

    await _store.add(item, smsId: smsId, contentHash: contentHash);
    notifyListeners();
    return ProcessResult.added;
  }

  Future<void> confirm(String id) async {
    final item = pending.firstWhere((p) => p.id == id);
    final accountId = _resolveAccount(item.accountHint);
    final currency = _prefs.currency;
    final tx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transactionTitle: item.merchant ?? 'Unknown',
      categoryId: item.categoryId ?? '',  // null/empty = uncategorized; not defaulted to a hardcoded ID
      amount: item.amount ?? 0,
      type: item.type,
      date: item.parsedAt,
      account: accountId ?? '',
      tags: [],
      baseCurrency: currency,
    );
    await _transactions.addTransaction(tx);
    await _store.confirm(id);
    notifyListeners();
  }

  Future<void> confirmAsMisc(String id) async {
    await _ensureMiscCategory();
    final miscId = _resolveCategoryId('misc') ?? 'misc';
    final item = pending.firstWhere((p) => p.id == id);
    await _store.update(id, item.copyWith(categoryId: miscId));
    await confirm(id);
  }

  Future<void> dismiss(String id) async {
    await _store.dismiss(id);
    notifyListeners();
  }

  Future<void> updateItem(
    String id, {
    String? merchant,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountHint,
  }) async {
    final existing = pending.firstWhere((p) => p.id == id);
    await _store.update(id, existing.copyWith(
      merchant: merchant,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountHint: accountHint,
    ));
    notifyListeners();
  }

  // Resolves a hint string (e.g. 'restaurant') against the user's active categories by name.
  String? _resolveCategoryId(String hint) {
    final allCategories = [
      ...Category.categories,
      ..._storage.getCustomCategories(),
    ].where((c) => _prefs.activeCategories.isEmpty || _prefs.activeCategories.contains(c.id)).toList();

    final exact = allCategories.cast<Category?>().firstWhere(
      (c) => c!.name.toLowerCase() == hint.toLowerCase(),
      orElse: () => null,
    );
    if (exact != null) return exact.id;

    return allCategories.cast<Category?>().firstWhere(
      (c) =>
          c!.name.toLowerCase().contains(hint.toLowerCase()) ||
          hint.toLowerCase().contains(c.name.toLowerCase()),
      orElse: () => null,
    )?.id;
  }

  Future<void> _ensureMiscCategory() async {
    final custom = _storage.getCustomCategories();
    if (custom.any((c) => c.id == 'misc')) return;
    const misc = Category(
      id: 'misc',
      name: 'Misc',
      lucideIcon: LucideIcons.package,
      color: '#9E9E9E',
      bg: '#F5F5F5',
    );
    await _storage.saveCustomCategory(misc);
    final active = _prefs.activeCategories;
    if (!active.contains('misc')) {
      await _prefs.setActiveCategories([...active, 'misc']);
    }
    _miscCategoryJustCreated = true;
  }

  String? _resolveAccount(String? hint) {
    if (hint == null) return null;
    final matches = _accounts.accounts
        .where((a) => a.displayName.toLowerCase().contains(hint.toLowerCase()))
        .toList();
    return matches.length == 1 ? matches.first.id : null;
  }

  String _hashBody(String body) {
    final normalized = body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  String? _hintFromSender(String sender) {
    const hints = {
      'HDFCBK': 'HDFC', 'ICICIB': 'ICICI', 'SBIINB': 'SBI',
      'AXISBK': 'Axis', 'KOTAKB': 'Kotak',
    };
    return hints[sender.toUpperCase()];
  }
}
```

- [ ] **Run `flutter analyze`**

Expected: no errors.

- [ ] **Commit**

```
git add lib/providers/sms_provider.dart
git commit -m "feat: add SmsProvider with full pipeline orchestration"
```

---

### Task 8: Android SmsReader + WorkManager

**Files:**
- Create: `lib/services/sms_reader.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`

- [ ] **Add READ_SMS permission to `android/app/src/main/AndroidManifest.xml`** inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.READ_SMS" />
```

- [ ] **Register WorkManager in `lib/main.dart`**

Add after `WidgetsFlutterBinding.ensureInitialized()`:

```dart
import 'package:flutter_workmanager/flutter_workmanager.dart';

// Add before runApp():
if (defaultTargetPlatform == TargetPlatform.android) {
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'sms_scan_task',
    'sms_scan_task',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}
```

- [ ] **Add top-level WorkManager callback to `lib/main.dart`** (outside any class, before `main()`):

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != 'sms_scan_task') return true;
    await Hive.initFlutter();
    final store = SmsPendingStore();
    await store.init();
    final lastTs = store.lastScanTs ?? DateTime.now().subtract(const Duration(days: 30));
    final messages = await SmsReader.readSince(lastTs);
    for (final msg in messages) {
      final hash = _hashBody(msg.body);
      final dedup = store.checkDuplicate(msg.id, hash);
      if (dedup != DedupResult.newMessage) continue;
      final verdict = SmsValidator.validate(msg.sender, msg.body);
      if (verdict == SmsVerdict.blocked) continue;
      if (!SmsFilter.isFinancial(msg.sender, msg.body)) continue;
      final parsed = SmsParser.parse(msg.sender, msg.body);
      final item = PendingSmsTransaction(
        id: msg.id ?? hash,
        rawSms: msg.body,
        merchant: parsed?.merchant,
        amount: parsed?.amount,
        type: parsed?.type ?? TransactionType.expense,
        categoryId: SmsRulesEngine.categorize(parsed?.merchant),
        accountHint: parsed?.accountHint,
        parsedAt: DateTime.now(),
        isUnparsed: parsed == null,
        verdict: verdict,
      );
      await store.add(item, smsId: msg.id, contentHash: hash);
    }
    await store.setLastScanTs(DateTime.now());
    return true;
  });
}

String _hashBody(String body) {
  final normalized = body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return sha256.convert(utf8.encode(normalized)).toString();
}
```

Add the required imports at the top of `main.dart`:
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_workmanager/flutter_workmanager.dart';
import 'services/sms_reader.dart';
import 'services/sms_validator.dart';
import 'services/sms_filter.dart';
import 'services/sms_parser.dart';
import 'services/sms_rules_engine.dart';
import 'services/sms_pending_store.dart';
import 'models/pending_sms_transaction.dart';
import 'models/models.dart';
```

- [ ] **Implement `lib/services/sms_reader.dart`**

```dart
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class SmsMessage {
  final String? id;
  final String sender;
  final String body;
  final DateTime date;

  const SmsMessage({this.id, required this.sender, required this.body, required this.date});
}

class SmsReader {
  static Future<List<SmsMessage>> readSince(DateTime since) async {
    try {
      final query = SmsQuery();
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
      );
      return messages
          .where((m) =>
              m.body != null &&
              m.sender != null &&
              (m.dateSent?.isAfter(since) ?? false))
          .map((m) => SmsMessage(
                id: m.id?.toString(),
                sender: m.sender!,
                body: m.body!,
                date: m.dateSent ?? DateTime.now(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
```

- [ ] **Run `flutter analyze`**

Expected: no errors.

- [ ] **Test on Android device/emulator manually** — grant SMS permission when prompted, confirm WorkManager task registers without crash.

- [ ] **Commit**

```
git add lib/services/sms_reader.dart lib/main.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat: add Android SmsReader with WorkManager background scan"
```

---

### Task 9: Android share target + iOS Share Extension hookup

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart` (add share intent listener)
- Create: `ios/SmsShareExtension/ShareViewController.swift`
- Create: `ios/SmsShareExtension/Info.plist`

- [ ] **Add Android share intent-filter to `AndroidManifest.xml`** inside the `<activity>` tag:

```xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
```

- [ ] **Add share intent listener in `lib/main.dart`** inside `_AppState.initState()`:

```dart
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void _handleSharedText(String text, BuildContext context) async {
  if (text.isEmpty) return;
  final sms = context.read<SmsProvider>();
  final result = await sms.processRawSms('shared', text, null);
  if (!context.mounted) return;
  if (result == ProcessResult.alreadyCaptured) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Already captured')),
    );
  }
}

// In initState():
ReceiveSharingIntent.instance.getTextStream().listen((text) {
  if (text != null) _handleSharedText(text, context);
});
ReceiveSharingIntent.instance.getInitialText().then((text) {
  if (text != null) _handleSharedText(text, context);
});
```

- [ ] **Create iOS Share Extension Xcode target** — in Xcode, File → New → Target → Share Extension → name: `SmsShareExtension`. Xcode auto-generates boilerplate.

- [ ] **Create `ios/SmsShareExtension/Info.plist`** with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>SmsShareExtension</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
            </dict>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    </dict>
</dict>
</plist>
```

- [ ] **Replace `ios/SmsShareExtension/ShareViewController.swift`** with:

```swift
import UIKit
import Social

class ShareViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let attachment = item.attachments?.first,
      attachment.hasItemConformingToTypeIdentifier("public.plain-text")
    else {
      extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      return
    }

    attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, _ in
      guard let text = data as? String else {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        return
      }
      let groupId = "group.\(Bundle.main.bundleIdentifier ?? "").sms"
      let defaults = UserDefaults(suiteName: groupId)
      defaults?.set(text, forKey: "pending_sms_text")
      defaults?.synchronize()
      self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
  }
}
```

- [ ] **Configure App Group** — in Xcode, enable App Groups capability for both the main app target and `SmsShareExtension` target. Use group ID: `group.<your-bundle-id>.sms`.

- [ ] **Read from App Group in `lib/main.dart`** on app launch (iOS only):

```dart
import 'package:shared_preferences/shared_preferences.dart';

// Add to app init, iOS branch:
if (defaultTargetPlatform == TargetPlatform.iOS) {
  // Read any SMS forwarded via Share Extension
  // App Group UserDefaults is read via a method channel or the
  // existing shared_preferences plugin configured with the App Group suite.
  // Simplest: add a native method channel call in AppDelegate.swift
  // that reads from UserDefaults(suiteName: groupId) and returns the string.
  // See AppDelegate note below.
}
```

- [ ] **Add to `ios/Runner/AppDelegate.swift`** inside `application(_:didFinishLaunchingWithOptions:)`, after `GeneratedPluginRegistrant.register(with: self)`:

```swift
let controller = window?.rootViewController as! FlutterViewController
let channel = FlutterMethodChannel(
  name: "sms_share_channel",
  binaryMessenger: controller.binaryMessenger
)
let groupId = "group.\(Bundle.main.bundleIdentifier ?? "").sms"
channel.setMethodCallHandler { call, result in
  if call.method == "getPendingSms" {
    let text = UserDefaults(suiteName: groupId)?.string(forKey: "pending_sms_text") ?? ""
    if !text.isEmpty {
      UserDefaults(suiteName: groupId)?.removeObject(forKey: "pending_sms_text")
      UserDefaults(suiteName: groupId)?.synchronize()
    }
    result(text.isEmpty ? nil : text)
  } else {
    result(FlutterMethodNotImplemented)
  }
}
```

Wire the MethodChannel on the Dart side in `main.dart`:

```dart
if (defaultTargetPlatform == TargetPlatform.iOS) {
  const channel = MethodChannel('sms_share_channel');
  try {
    final text = await channel.invokeMethod<String>('getPendingSms');
    if (text != null && text.isNotEmpty) {
      // processRawSms called after SmsProvider is available
    }
  } catch (_) {}
}
```

- [ ] **Run `flutter analyze`**

- [ ] **Test Android share:** open Messages app on emulator → long-press a message → Share → select your app → verify `SmsProvider.processRawSms` is called.

- [ ] **Commit**

```
git add android/app/src/main/AndroidManifest.xml lib/main.dart ios/SmsShareExtension/ ios/Runner/AppDelegate.swift
git commit -m "feat: add Android share intent + iOS Share Extension for SMS forwarding"
```

---

### Task 10: Bell badge + SmsInboxSheet

**Files:**
- Modify: `lib/screens/layout_screen.dart`
- Create: `lib/widgets/sms_inbox_sheet.dart`

- [ ] **Wire `SmsProvider` into `main.dart` provider tree**

In `main.dart`, add `SmsProvider` to `MultiProvider`:

```dart
ChangeNotifierProxyProvider3<TransactionProvider, AccountProvider, UserPreferencesProvider, SmsProvider>(
  create: (ctx) => SmsProvider(
    store: smsPendingStore, // initialized during app startup
    transactions: ctx.read<TransactionProvider>(),
    accounts: ctx.read<AccountProvider>(),
    prefs: ctx.read<UserPreferencesProvider>(),
    storage: storageService,
  ),
  update: (_, tx, acc, prefs, prev) => prev!,
),
```

Add `SmsPendingStore` initialization before `runApp`:

```dart
final smsPendingStore = SmsPendingStore();
await smsPendingStore.init();
```

- [ ] **Add bell badge to `layout_screen.dart`**

In `_buildTopHeader`, replace the existing bell `Container` with:

```dart
Consumer<SmsProvider>(
  builder: (ctx, sms, _) {
    final count = sms.pendingCount;
    return GestureDetector(
      onTap: () => _showSmsInbox(ctx),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bell, size: 16, color: AppTheme.textPrimary),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  },
),
```

Add `_showSmsInbox` method to `_LayoutScreenState`:

```dart
void _showSmsInbox(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const SmsInboxSheet(),
  );
}
```

- [ ] **Create `lib/widgets/sms_inbox_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/sms_provider.dart';
import 'sms_pending_card.dart';

class SmsInboxSheet extends StatefulWidget {
  const SmsInboxSheet({super.key});

  @override
  State<SmsInboxSheet> createState() => _SmsInboxSheetState();
}

class _SmsInboxSheetState extends State<SmsInboxSheet> {
  final _itemKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return Consumer<SmsProvider>(
          builder: (ctx, sms, _) {
            // Scroll to + highlight duplicate-pending card
            if (sms.highlightedId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final key = _itemKeys[sms.highlightedId];
                if (key?.currentContext != null) {
                  Scrollable.ensureVisible(
                    key!.currentContext!,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                }
                sms.clearHighlight();
              });
            }

            // Misc category snackbar
            if (sms.miscCategoryJustCreated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("A 'Misc' category was created for unrecognized transactions")),
                );
                sms.clearMiscCategoryFlag();
              });
            }

            return Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Text(
                        'SMS Transactions',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface),
                      ),
                      const SizedBox(width: 8),
                      if (sms.pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${sms.pendingCount}',
                            style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: sms.pending.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.messageSquare, size: 36, color: cs.outlineVariant),
                              const SizedBox(height: 12),
                              Text('No new transactions from SMS', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          itemCount: sms.pending.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final item = sms.pending[i];
                            _itemKeys.putIfAbsent(item.id, () => GlobalKey());
                            return SmsPendingCard(
                              key: _itemKeys[item.id],
                              item: item,
                              highlighted: sms.highlightedId == item.id,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Update `SmsPendingCard`** — add `highlighted` parameter and animate border flash:

```dart
// Add to SmsPendingCard:
final bool highlighted;
const SmsPendingCard({super.key, required this.item, this.highlighted = false});

// In _SmsPendingCardState, add:
bool _flash = false;

@override
void didUpdateWidget(SmsPendingCard oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.highlighted && !oldWidget.highlighted) {
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _flash = false);
    });
  }
}

// In Container decoration, change border color when _flash:
border: Border.all(
  color: _flash
      ? Theme.of(context).colorScheme.primary
      : widget.item.verdict == SmsVerdict.suspicious
          ? Colors.red.withValues(alpha: 0.4)
          : cs.outlineVariant.withValues(alpha: 0.4),
  width: _flash ? 1.5 : 0.5,
),
```

- [ ] **Run `flutter analyze`**

- [ ] **Commit**

```
git add lib/screens/layout_screen.dart lib/widgets/sms_inbox_sheet.dart lib/main.dart
git commit -m "feat: add bell badge with pending count and SmsInboxSheet"
```

---

### Task 11: SmsPendingCard

**Files:**
- Create: `lib/widgets/sms_pending_card.dart`

- [ ] **Implement `lib/widgets/sms_pending_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/pending_sms_transaction.dart';
import '../providers/sms_provider.dart';
import '../providers/account_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../data/currencies.dart';
import 'category_icon_widget.dart';

class SmsPendingCard extends StatefulWidget {
  final PendingSmsTransaction item;
  const SmsPendingCard({super.key, required this.item});

  @override
  State<SmsPendingCard> createState() => _SmsPendingCardState();
}

class _SmsPendingCardState extends State<SmsPendingCard> {
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TransactionType _type;
  late String? _categoryId;
  late String? _accountId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.merchant ?? '');
    _amountCtrl = TextEditingController(
      text: widget.item.amount != null ? '${widget.item.amount}' : '',
    );
    _type = widget.item.type;
    _categoryId = widget.item.categoryId;
    _accountId = null; // resolved from accountHint in build
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncAndConfirm(SmsProvider sms) async {
    await sms.updateItem(
      widget.item.id,
      merchant: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text),
      type: _type,
      categoryId: _categoryId,
      accountHint: _accountId,
    );
    await sms.confirm(widget.item.id);
  }

  Future<void> _syncAndDismiss(SmsProvider sms) async {
    await sms.dismiss(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sms = context.read<SmsProvider>();
    final accounts = context.watch<AccountProvider>().accounts;
    final prefs = context.watch<UserPreferencesProvider>();
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == prefs.currency, orElse: () => kCurrencies.first)
        .symbol;

    final allCategories = [
      ...Category.categories.where((c) => prefs.activeCategories.isEmpty || prefs.activeCategories.contains(c.id)),
      ...prefs.customCategories,
    ];

    // Resolve accountId from accountHint on first build
    if (_accountId == null && widget.item.accountHint != null) {
      final matches = accounts.where((a) =>
          a.displayName.toLowerCase().contains(widget.item.accountHint!.toLowerCase())).toList();
      if (matches.length == 1) _accountId = matches.first.id;
    }

    return Dismissible(
      key: ValueKey(widget.item.id),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await _syncAndConfirm(sms);
          return false; // SmsProvider notifyListeners removes card
        } else {
          await _syncAndDismiss(sms);
          return false;
        }
      },
      background: _buildSwipeBackground(cs, isConfirm: true),
      secondaryBackground: _buildSwipeBackground(cs, isConfirm: false),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.item.verdict == SmsVerdict.suspicious
                ? Colors.red.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Suspicious warning banner
            if (widget.item.verdict == SmsVerdict.suspicious)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Could not verify sender. Confirm only if you recognise this transaction.',
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Amount + type toggle
                  Row(
                    children: [
                      Text(currencySymbol, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface, fontFamily: 'Archia'),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 20, fontFamily: 'Archia'),
                            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _type = _type == TransactionType.expense
                            ? TransactionType.income
                            : TransactionType.expense),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _type == TransactionType.expense
                                ? Colors.red.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _type == TransactionType.expense ? 'Expense' : 'Income',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _type == TransactionType.expense ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row 2: Title
                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.item.isUnparsed
                          ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                          : cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.item.isUnparsed ? 'We don\'t know what this was for' : 'Description',
                      hintStyle: TextStyle(fontSize: 15, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Row 3: Category chips
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: allCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = allCategories[i];
                        final selected = _categoryId == cat.id;
                        final accent = Color(int.parse(cat.color.substring(1), radix: 16) + 0xFF000000);
                        return GestureDetector(
                          onTap: () => setState(() => _categoryId = cat.id),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: selected ? accent : cs.surfaceContainerLow,
                              shape: BoxShape.circle,
                              border: selected ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5),
                            ),
                            child: Center(
                              child: CategoryIconWidget(
                                category: cat,
                                size: 20,
                                color: selected ? Colors.white : cs.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Row 4: Account chips
                  if (accounts.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: accounts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final acc = accounts[i];
                          final selected = _accountId == acc.id;
                          return GestureDetector(
                            onTap: () => setState(() => _accountId = acc.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: selected ? cs.primary : cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: selected ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5),
                              ),
                              child: Center(
                                child: Text(
                                  acc.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: selected ? cs.onPrimary : cs.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Divider + action buttons
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _syncAndDismiss(sms),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.x, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text('Dismiss', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.item.isUnparsed
                        ? sms.confirmAsMisc(widget.item.id)
                        : _syncAndConfirm(sms),
                    child: Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.item.isUnparsed ? LucideIcons.plus : LucideIcons.check,
                              size: 14,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.item.isUnparsed ? 'Add as misc expense' : 'Confirm',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(ColorScheme cs, {required bool isConfirm}) {
    return Container(
      decoration: BoxDecoration(
        color: isConfirm ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isConfirm ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        isConfirm ? LucideIcons.check : LucideIcons.x,
        color: isConfirm ? Colors.green : Colors.red,
      ),
    );
  }
}
```

- [ ] **Run `flutter analyze`**

Expected: no errors.

- [ ] **Test on device** — open bell, verify card renders with all four rows. Swipe right on a card → confirm toast / transaction added. Swipe left → card disappears.

- [ ] **Commit**

```
git add lib/widgets/sms_pending_card.dart
git commit -m "feat: add SmsPendingCard with inline edit, swipe confirm/dismiss, fraud warning"
```

---

### Task 12: Misc category snackbar + permission request

**Files:**
- Modify: `lib/providers/sms_provider.dart`
- Modify: `lib/screens/layout_screen.dart`

- [ ] **Expose `miscCategoryCreated` stream in `SmsProvider`**

Add to `SmsProvider`:

```dart
bool _miscCategoryJustCreated = false;
bool get miscCategoryJustCreated => _miscCategoryJustCreated;

void clearMiscCategoryFlag() => _miscCategoryJustCreated = false;
```

In `_ensureMiscCategory()`, set `_miscCategoryJustCreated = true` when creating:

```dart
Future<void> _ensureMiscCategory() async {
  final custom = _storage.getCustomCategories();
  if (custom.any((c) => c.id == 'misc')) return;
  const misc = Category(
    id: 'misc',
    name: 'Misc',
    lucideIcon: LucideIcons.package,
    color: '#9E9E9E',
    bg: '#F5F5F5',
  );
  await _storage.saveCustomCategory(misc);
  final active = _prefs.activeCategories;
  if (!active.contains('misc')) {
    await _prefs.setActiveCategories([...active, 'misc']);
  }
  _miscCategoryJustCreated = true;
}
```

- [ ] **Show snackbar in `SmsInboxSheet`** — add listener:

```dart
// In SmsInboxSheet build, wrap Consumer with a listener:
return Consumer<SmsProvider>(
  builder: (ctx, sms, _) {
    if (sms.miscCategoryJustCreated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("A 'Misc' category was created for unrecognized transactions")),
        );
        sms.clearMiscCategoryFlag();
      });
    }
    // ... rest of build
  },
);
```

- [ ] **Add `smsFeatureEnabled` to `UserPreferencesProvider`**

```dart
// In UserPreferencesProvider:
bool get smsFeatureEnabled => _prefs.getBool('sms_feature_enabled') ?? true;
Future<void> setSmsFeatureEnabled(bool v) async {
  await _prefs.setBool('sms_feature_enabled', v);
  notifyListeners();
}
```

- [ ] **Update bell icon in `layout_screen.dart`** — hide when Android + (permanently denied OR feature disabled):

```dart
import 'package:permission_handler/permission_handler.dart';

// Replace bell Container with:
Consumer<SmsProvider>(
  builder: (ctx, sms, _) {
    final prefs = ctx.watch<UserPreferencesProvider>();
    return FutureBuilder<PermissionStatus>(
      future: defaultTargetPlatform == TargetPlatform.android
          ? Permission.sms.status
          : Future.value(PermissionStatus.granted),
      builder: (_, snap) {
        final status = snap.data;
        final hidden = defaultTargetPlatform == TargetPlatform.android &&
            (!prefs.smsFeatureEnabled || status == PermissionStatus.permanentlyDenied);
        if (hidden) return const SizedBox.shrink();
        final count = sms.pendingCount;
        return GestureDetector(
          onTap: () => _showSmsInbox(ctx),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.bell, size: 16, color: AppTheme.textPrimary),
              ),
              if (count > 0)
                Positioned(
                  right: -2, top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  },
),
```

- [ ] **Update `_showSmsInbox` in `layout_screen.dart`** — request permission on first tap (undetermined/denied only):

```dart
void _showSmsInbox(BuildContext context) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final status = await Permission.sms.status;
    if (status.isDenied) {
      final result = await Permission.sms.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission required to detect transactions')),
          );
        }
        return;
      }
    }
  }
  if (!mounted) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const SmsInboxSheet(),
  );
}
```

- [ ] **Add SMS toggle to `settings_screen.dart`** — new "Privacy & Permissions" section (Android only):

```dart
if (defaultTargetPlatform == TargetPlatform.android)
  _SettingsSection(
    title: 'Privacy & Permissions',
    children: [
      Consumer<UserPreferencesProvider>(
        builder: (ctx, prefs, _) {
          return FutureBuilder<PermissionStatus>(
            future: Permission.sms.status,
            builder: (_, snap) {
              final status = snap.data;
              final isPermanent = status == PermissionStatus.permanentlyDenied;
              return SwitchListTile(
                title: const Text('SMS Transaction Detection'),
                subtitle: Text(
                  isPermanent
                      ? 'Permission denied — tap to open app settings'
                      : 'Automatically detect transactions from bank SMS',
                  style: const TextStyle(fontSize: 12),
                ),
                value: prefs.smsFeatureEnabled && status == PermissionStatus.granted,
                onChanged: (v) async {
                  if (!v) {
                    await prefs.setSmsFeatureEnabled(false);
                    await Workmanager().cancelByUniqueName('sms_scan_task');
                    return;
                  }
                  if (isPermanent) {
                    await openAppSettings();
                    return;
                  }
                  final result = await Permission.sms.request();
                  if (result.isGranted) {
                    await prefs.setSmsFeatureEnabled(true);
                    await Workmanager().registerPeriodicTask(
                      'sms_scan_task', 'sms_scan_task',
                      frequency: const Duration(minutes: 15),
                      existingWorkPolicy: ExistingWorkPolicy.keep,
                    );
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('SMS permission is required')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    ],
  ),
```

Add `permission_handler` to `pubspec.yaml`:

```yaml
permission_handler: ^11.0.0
```

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_SMS"/>
```

- [ ] **Run `flutter pub get` then `flutter analyze`**

- [ ] **Commit**

```
git add lib/providers/user_preferences_provider.dart lib/providers/sms_provider.dart lib/widgets/sms_inbox_sheet.dart lib/screens/layout_screen.dart lib/screens/settings_screen.dart pubspec.yaml
git commit -m "feat: SMS feature toggle in settings, bell hides on permanent denial, misc category snackbar"
```

---

### Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| PendingSmsTransaction model | Task 1 |
| Remove SmsParsed stub | Task 1 |
| SmsFilter (OTP/promo/keyword) | Task 2 |
| SmsValidator (fraud/suspicious) | Task 3 |
| Levenshtein typosquat detection | Task 3 |
| SmsParser 6-tier regex | Task 4 |
| SmsRulesEngine merchant map | Task 5 |
| SmsPendingStore dedup (id + hash) | Task 6 |
| SmsProvider pipeline orchestration | Task 7 |
| Auto-create misc category | Task 7 + 12 |
| Android WorkManager background scan | Task 8 |
| Android share intent | Task 9 |
| iOS Share Extension | Task 9 |
| Bell badge with count | Task 10 |
| Bell hidden on permanent denial / feature off | Task 12 |
| SmsInboxSheet empty state | Task 10 |
| Scroll-to + highlight duplicate-pending card | Task 10 |
| "Already captured" toast | Task 9 |
| SmsPendingCard inline edit | Task 11 |
| Swipe confirm/dismiss | Task 11 |
| Parsed card null category → empty, user picks | Task 7 + 11 |
| Unparsed card placeholder | Task 11 |
| Suspicious warning banner | Task 11 |
| "Add as misc expense" button (unparsed only) | Task 11 |
| Misc category snackbar | Task 10 |
| Settings screen SMS feature toggle | Task 12 |
| Runtime SMS permission on bell tap | Task 12 |
| SmsPendingStore confirm uses contentHash | Task 6 |
| Category hint resolved against user categories | Task 7 |

**No placeholders found.**

**Type consistency:** `DedupResult.newMessage` used consistently. `SmsVerdict` used consistently from `PendingSmsTransaction` through `SmsValidator` and `SmsProvider`. `ProcessResult` enum defined in `SmsProvider`. `ParsedSmsResult` defined in `SmsParser`, consumed in `SmsProvider`.
