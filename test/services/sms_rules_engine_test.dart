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
