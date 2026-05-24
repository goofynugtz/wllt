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
