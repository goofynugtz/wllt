import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/categorization_adapter.dart';

Future<String> _mockInfer(String prompt) async => 'coffee';
Future<String> _badInfer(String prompt) async => 'not_a_real_category';
Future<String> _throwingInfer(String prompt) async => throw Exception('model error');

void main() {
  const categories = ['shopping', 'restaurant', 'coffee', 'groceries', 'transport'];

  test('deterministic map returns known merchant without calling infer', () async {
    var inferCalled = false;
    Future<String> trackingInfer(String p) async {
      inferCalled = true;
      return 'coffee';
    }
    final result = await CategorizationAdapter.suggest(
      merchant: 'Swiggy',
      availableCategories: categories,
      infer: trackingInfer,
    );
    expect(result, isNotNull);
    expect(inferCalled, false);
  });

  test('unknown merchant calls infer and returns valid category', () async {
    final result = await CategorizationAdapter.suggest(
      merchant: 'XYZ Unknown Shop',
      availableCategories: categories,
      infer: _mockInfer,
    );
    expect(result, equals('coffee'));
  });

  test('returns null when AI output is not a known category', () async {
    final result = await CategorizationAdapter.suggest(
      merchant: 'XYZ Unknown Shop',
      availableCategories: categories,
      infer: _badInfer,
    );
    expect(result, isNull);
  });

  test('returns null when infer throws', () async {
    final result = await CategorizationAdapter.suggest(
      merchant: 'XYZ Unknown Shop',
      availableCategories: categories,
      infer: _throwingInfer,
    );
    expect(result, isNull);
  });

  test('empty merchant returns null', () async {
    final result = await CategorizationAdapter.suggest(
      merchant: '',
      availableCategories: categories,
      infer: _mockInfer,
    );
    expect(result, isNull);
  });
}
