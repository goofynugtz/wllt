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

    test('parses HDFC UPI "Sent" format', () {
      final r = SmsParser.parse(
        'HDFCBK',
        'Sent Rs.577.00\nFrom HDFC Bank A/C *7897\nTo 13 DHABHA\nOn 23/08/26\nRef 623543213734\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808',
      );
      expect(r, isNotNull);
      expect(r!.amount, 577.00);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('dhabha'));
      expect(r.accountHint, 'HDFC');
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

    test('parses Canara Acct Dr. semicolon-delimited debit', () {
      final r = SmsParser.parse(
        'CANBNK',
        'Dear Customer, Acct XXX099 Dr. INR 52.00 on 07/07/26 to KAVALI  SANJ; UPI: 655449588903; Bal INR 11,215.12.Not you?SMS BLOCKUPI to 9901771222-CanaraBank',
      );
      expect(r, isNotNull);
      expect(r!.amount, 52.00);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('kavali'));
      expect(r.accountHint, 'Canara');
    });

    test('parses ATM withdrawal with no explicit "for" merchant clause', () {
      final r = SmsParser.parse(
        'BOBIBN',
        'Rs.2,000.00 withdrawn from A/c XX7788 at ATM Sector18 on 15-07-26. Avl Bal Rs.8,300.00',
      );
      expect(r, isNotNull);
      expect(r!.amount, 2000.00);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('atm'));
      expect(r.accountHint, 'Bank of Baroda');
    });

    test('parses debit towards a bill with no "Bank/A/c/Acct" token', () {
      final r = SmsParser.parse(
        'UNIONB',
        'Rs 500.00 debited from your account towards Electricity Bill on 15-07-26.',
      );
      expect(r, isNotNull);
      expect(r!.amount, 500.00);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('electricity'));
    });

    test('parses verb-first credit card spend alert', () {
      final r = SmsParser.parse(
        'HDFCBK',
        "Alert: You've spent INR 555.00 on your HDFC Bank Card **1234 at AMAZON on 15/07/26 at 11:07AM IST. Call 1800xxx if not you.",
      );
      expect(r, isNotNull);
      expect(r!.amount, 555.00);
      expect(r.type, TransactionType.expense);
      expect(r.merchant?.toLowerCase(), contains('amazon'));
    });

    test('does not misparse merchant from "credited to a/c XX1234"', () {
      final r = SmsParser.parse(
        'HDFCBK',
        'Rs.85,000.00 credited to a/c XX1234. NEFT from EMPLOYER LTD.',
      );
      expect(r, isNotNull);
      expect(r!.amount, 85000.00);
      expect(r.type, TransactionType.income);
      expect(r.merchant, isNull);
    });

    test('matches sender with DLT prefix/suffix around bank code', () {
      final r = SmsParser.parse(
        'AD-HDFCBK-S',
        'Rs.100.00 debited from a/c XX4242 on UPI to CHAI POINT. Bal: Rs.900.00',
      );
      expect(r, isNotNull);
      expect(r!.accountHint, 'HDFC');
    });
  });
}
