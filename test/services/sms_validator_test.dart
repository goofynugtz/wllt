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
