import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/insight_adapter.dart';

void main() {
  Future<String> goodInfer(String p) async => '  Your restaurant spend is over budget.  ';
  Future<String> throwInfer(String p) async => throw Exception('fail');

  const facts = [
    'Restaurant is over budget: ₹4,200 spent vs ₹3,000 limit (+40%)',
    'Recurring subscriptions: Netflix ₹649 (₹649/month total)',
  ];

  test('returns trimmed insight text', () async {
    final result = await InsightAdapter.generate(
      facts: facts,
      infer: goodInfer,
    );
    expect(result, equals('Your restaurant spend is over budget.'));
  });

  test('includes fact lines in prompt', () async {
    String? seenPrompt;
    await InsightAdapter.generate(
      facts: facts,
      infer: (p) async {
        seenPrompt = p;
        return 'ok';
      },
    );
    expect(seenPrompt, contains('over budget'));
    expect(seenPrompt, contains('Netflix'));
  });

  test('returns null for empty facts without calling infer', () async {
    var called = false;
    final result = await InsightAdapter.generate(
      facts: const [],
      infer: (p) async {
        called = true;
        return 'x';
      },
    );
    expect(result, isNull);
    expect(called, isFalse);
  });

  test('returns null when infer throws', () async {
    final result = await InsightAdapter.generate(
      facts: facts,
      infer: throwInfer,
    );
    expect(result, isNull);
  });
}
