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
