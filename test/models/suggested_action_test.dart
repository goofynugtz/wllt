import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/models/suggested_action.dart';

void main() {
  test('encode/decode roundtrip preserves all fields', () {
    final action = SuggestedAction(
      id: '1751900000000',
      text: 'Cancel Netflix to save ₹649/month',
      createdAt: DateTime(2026, 7, 7, 10, 30),
      done: true,
    );
    final decoded = SuggestedAction.decode(action.encode());
    expect(decoded.id, action.id);
    expect(decoded.text, action.text);
    expect(decoded.createdAt, action.createdAt);
    expect(decoded.done, isTrue);
  });

  test('done defaults to false', () {
    final action = SuggestedAction(
      id: '1',
      text: 'x',
      createdAt: DateTime(2026, 1, 1),
    );
    expect(action.done, isFalse);
  });

  test('copyWith flips done and keeps identity', () {
    final action = SuggestedAction(
      id: '1',
      text: 'x',
      createdAt: DateTime(2026, 1, 1),
    );
    final toggled = action.copyWith(done: true);
    expect(toggled.done, isTrue);
    expect(toggled.id, '1');
    expect(toggled.text, 'x');
    expect(toggled.createdAt, action.createdAt);
  });

  test('decode tolerates missing optional fields', () {
    final decoded = SuggestedAction.decode(
        '{"id":"7","text":"hello","createdAt":"2026-07-07T00:00:00.000"}');
    expect(decoded.done, isFalse);
    expect(decoded.text, 'hello');
  });
}
