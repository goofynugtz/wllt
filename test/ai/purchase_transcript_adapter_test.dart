import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/purchase_transcript_adapter.dart';

void main() {
  Future<String> goodInfer(String p) async =>
      '{"merchant":"Third Wave","amount":200.0}';
  Future<String> noMerchantInfer(String p) async =>
      '{"merchant":null,"amount":90.0}';
  Future<String> badJsonInfer(String p) async => 'not valid json';
  Future<String> negativeAmountInfer(String p) async =>
      '{"merchant":"X","amount":-10.0}';
  Future<String> nullAmountInfer(String p) async =>
      '{"merchant":"X","amount":null}';
  Future<String> throwInfer(String p) async => throw Exception('fail');

  const transcript = 'spent two hundred on coffee at third wave';

  test('parses a valid transcript', () async {
    final result =
        await PurchaseTranscriptAdapter.parse(transcript: transcript, infer: goodInfer);
    expect(result, isNotNull);
    expect(result!.merchant, equals('Third Wave'));
    expect(result.amount, equals(200.0));
  });

  test('handles a null merchant', () async {
    final result = await PurchaseTranscriptAdapter.parse(
        transcript: transcript, infer: noMerchantInfer);
    expect(result, isNotNull);
    expect(result!.merchant, isNull);
    expect(result.amount, equals(90.0));
  });

  test('returns null on invalid JSON', () async {
    final result =
        await PurchaseTranscriptAdapter.parse(transcript: transcript, infer: badJsonInfer);
    expect(result, isNull);
  });

  test('returns null on negative amount', () async {
    final result = await PurchaseTranscriptAdapter.parse(
        transcript: transcript, infer: negativeAmountInfer);
    expect(result, isNull);
  });

  test('returns null on null amount', () async {
    final result = await PurchaseTranscriptAdapter.parse(
        transcript: transcript, infer: nullAmountInfer);
    expect(result, isNull);
  });

  test('returns null when infer throws', () async {
    final result =
        await PurchaseTranscriptAdapter.parse(transcript: transcript, infer: throwInfer);
    expect(result, isNull);
  });
}
