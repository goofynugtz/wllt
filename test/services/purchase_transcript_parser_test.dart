import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/services/purchase_transcript_parser.dart';

void main() {
  group('PurchaseTranscriptParser', () {
    test('parses "spent <amount> at <merchant>"', () {
      final r = PurchaseTranscriptParser.parse('spent 450 at Swiggy');
      expect(r, isNotNull);
      expect(r!.amount, 450.0);
      expect(r.merchant, 'Swiggy');
    });

    test('parses "paid <amount> on <merchant>" (no "at")', () {
      final r = PurchaseTranscriptParser.parse('paid 1240 on groceries');
      expect(r, isNotNull);
      expect(r!.amount, 1240.0);
      expect(r.merchant, 'groceries');
    });

    test('prefers "at" merchant over an earlier "on" in the same transcript', () {
      final r = PurchaseTranscriptParser.parse('spent 200 on coffee at Third Wave');
      expect(r, isNotNull);
      expect(r!.amount, 200.0);
      expect(r.merchant, 'Third Wave');
    });

    test('handles ₹ symbol and comma-formatted amount', () {
      final r = PurchaseTranscriptParser.parse('spent ₹1,240 at D-Mart');
      expect(r, isNotNull);
      expect(r!.amount, 1240.0);
      expect(r.merchant, 'D-Mart');
    });

    test('amount with no merchant marker returns null merchant, not null result', () {
      final r = PurchaseTranscriptParser.parse('I spent 90 today');
      expect(r, isNotNull);
      expect(r!.amount, 90.0);
      expect(r.merchant, isNull);
    });

    test('no amount at all returns null', () {
      final r = PurchaseTranscriptParser.parse('bought coffee at Third Wave');
      expect(r, isNull);
    });
  });
}
