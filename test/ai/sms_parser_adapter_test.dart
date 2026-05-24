import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/sms_parser_adapter.dart';

void main() {
  Future<String> goodInfer(String p) async =>
      '{"merchant":"Zomato","amount":349.0,"type":"debit"}';
  Future<String> creditInfer(String p) async =>
      '{"merchant":"Employer","amount":85000.0,"type":"credit"}';
  Future<String> badJsonInfer(String p) async => 'not valid json';
  Future<String> negativeAmountInfer(String p) async =>
      '{"merchant":"X","amount":-10.0,"type":"debit"}';
  Future<String> nullAmountInfer(String p) async =>
      '{"merchant":"X","amount":null,"type":"debit"}';
  Future<String> throwInfer(String p) async => throw Exception('fail');

  const sms = 'Rs.349.00 debited from a/c XX4242 for UPI to ZOMATO. Bal: Rs.12,450';

  test('parses valid debit SMS', () async {
    final result = await SmsParserAdapter.parse(rawSms: sms, infer: goodInfer);
    expect(result, isNotNull);
    expect(result!.merchant, equals('Zomato'));
    expect(result.amount, equals(349.0));
    expect(result.type, equals('debit'));
  });

  test('parses credit SMS', () async {
    final result = await SmsParserAdapter.parse(
      rawSms: 'credited 85000',
      infer: creditInfer,
    );
    expect(result!.type, equals('credit'));
  });

  test('returns null on invalid JSON', () async {
    final result = await SmsParserAdapter.parse(rawSms: sms, infer: badJsonInfer);
    expect(result, isNull);
  });

  test('returns null on negative amount', () async {
    final result = await SmsParserAdapter.parse(rawSms: sms, infer: negativeAmountInfer);
    expect(result, isNull);
  });

  test('returns null on null amount', () async {
    final result = await SmsParserAdapter.parse(rawSms: sms, infer: nullAmountInfer);
    expect(result, isNull);
  });

  test('returns null when infer throws', () async {
    final result = await SmsParserAdapter.parse(rawSms: sms, infer: throwInfer);
    expect(result, isNull);
  });
}
