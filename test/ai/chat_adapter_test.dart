import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/chat_adapter.dart';

/// Emits [text] one character at a time, simulating token-by-token
/// streaming from the model.
Stream<String> _charStream(String text) => Stream.fromIterable(text.split(''));

/// Runs [ChatAdapter.generateStream] to completion and returns the final
/// parsed reply from its terminal [ChatStreamDone] event.
Future<ChatReply?> _run({
  required List<String> facts,
  required List<ChatTurn> history,
  required String userMessage,
  required InferStreamFn inferStream,
}) async {
  final events = await ChatAdapter.generateStream(
    facts: facts,
    history: history,
    userMessage: userMessage,
    inferStream: inferStream,
  ).toList();
  expect(events, isNotEmpty);
  expect(events.last, isA<ChatStreamDone>());
  return (events.last as ChatStreamDone).reply;
}

void main() {
  const facts = [
    'Recurring subscriptions: Netflix ₹649 (₹649/month total)',
    'Top category: Groceries ₹8,200 (41% of ₹20,000 total)',
  ];

  test('splits mid-reply ACTION into text and actionText', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'How can I save money?',
      inferStream: (p) => _charStream(
          'You spend a lot on subscriptions. ACTION: Cancel Netflix to save ₹649/month.'),
    );
    expect(reply, isNotNull);
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'You spend a lot on subscriptions.');
    expect(reply.actionText, 'Cancel Netflix to save ₹649/month.');
  });

  test('reply that is only an action yields empty text', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) =>
          _charStream('ACTION: Cancel Netflix to save ₹649/month.'),
    );
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, isEmpty);
    expect(reply.actionText, 'Cancel Netflix to save ₹649/month.');
  });

  test('marker match is case-insensitive and trims whitespace', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) =>
          _charStream('Try this.  action:   cap groceries at ₹7,000  '),
    );
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'Try this.');
    expect(reply.actionText, 'cap groceries at ₹7,000');
  });

  test('strips echoed leading Coach: label', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'why is my spend high?',
      inferStream: (p) =>
          _charStream('Coach: Groceries drive most of your spending.'),
    );
    expect(reply!.isSuggestion, isFalse);
    expect(reply.text, 'Groceries drive most of your spending.');
  });

  test('strips Coach: label and still parses action', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream(
          'Coach: You overspend on food. ACTION: Set a ₹7,000 grocery cap'),
    );
    expect(reply!.text, 'You overspend on food.');
    expect(reply.actionText, 'Set a ₹7,000 grocery cap');
  });

  test('truncates hallucinated dialogue continuation', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) =>
          _charStream('Cut your coffee spend.\nUser: okay\nCoach: great!'),
    );
    expect(reply!.text, 'Cut your coffee spend.');
    expect(reply.isSuggestion, isFalse);
  });

  test('truncates at hallucinated turn tokens', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream(
          'Nice month overall!<end_of_turn>\n<start_of_turn>user\nthanks'),
    );
    expect(reply!.text, 'Nice month overall!');
  });

  test('reply without marker is not a suggestion', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'why is my spend high?',
      inferStream: (p) => _charStream('Which category do you want to cut first?'),
    );
    expect(reply!.isSuggestion, isFalse);
    expect(reply.actionText, isNull);
    expect(reply.text, 'Which category do you want to cut first?');
  });

  test('returns null on empty reply', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('   '),
    );
    expect(reply, isNull);
  });

  test('returns null on marker with empty body', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('ACTION:'),
    );
    expect(reply, isNull);
  });

  test('returns null when infer stream throws', () async {
    final reply = await _run(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => Stream<String>.error(Exception('timeout')),
    );
    expect(reply, isNull);
  });

  test('prompt uses Gemma multi-turn format without name labels', () async {
    String? seen;
    await _run(
      facts: facts,
      history: const [
        ChatTurn(isUser: false, text: 'Earlier coach reply'),
        ChatTurn(isUser: true, text: 'What about groceries?'),
      ],
      userMessage: 'And subscriptions?',
      inferStream: (p) {
        seen = p;
        return _charStream('ok');
      },
    );
    expect(seen, startsWith('<start_of_turn>user\n'));
    expect(seen, endsWith('<start_of_turn>model\n'));
    expect(seen, contains('Netflix ₹649'));
    expect(seen, contains('"ACTION:"'));
    expect(seen,
        contains('<start_of_turn>model\nEarlier coach reply<end_of_turn>'));
    expect(seen,
        contains('<start_of_turn>user\nWhat about groceries?<end_of_turn>'));
    expect(seen, contains('<start_of_turn>user\nAnd subscriptions?'));
    expect(seen, isNot(contains('Coach:')));
    expect(seen, isNot(contains('User says:')));
  });

  test('drops oldest history turns to fit budget, keeps newest', () async {
    final filler = 'x' * 200;
    final history = <ChatTurn>[
      for (var i = 0; i < 50; i++)
        ChatTurn(isUser: i.isEven, text: 'turn$i $filler'),
    ];
    String? seen;
    await _run(
      facts: facts,
      history: history,
      userMessage: 'latest question',
      inferStream: (p) {
        seen = p;
        return _charStream('ok');
      },
    );
    expect(seen, isNot(contains('turn0 ')));
    expect(seen, contains('turn49 '));
    expect(seen, contains('Netflix ₹649'));
    expect(seen, contains('latest question'));
    expect(seen!.length, lessThan(4000));
  });

  // --- Incremental safe-reveal behavior ---

  test('reveals text immediately, growing with each chunk', () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Cut back on takeout.'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    expect(texts, isNotEmpty);
    for (var i = 1; i < texts.length; i++) {
      expect(texts[i].length, greaterThanOrEqualTo(texts[i - 1].length));
    }
    expect(texts.last, 'Cut back on takeout.');
  });

  test('withholds an ambiguous ACTION prefix until it resolves', () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Spend less. ACTION: cut coffee'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    for (final t in texts) {
      expect(t, isNot(contains('ACTI')));
    }
    expect(texts.last, 'Spend less.');
  });

  test('reveals a near-match that turns out not to be a marker', () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Actually you are doing fine.'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    expect(texts.last, 'Actually you are doing fine.');
  });

  test('stops listening once a stop marker resolves', () async {
    var pulled = 0;
    Stream<String> chars() async* {
      for (final ch in 'Nice month!<end_of_turn>MORE'.split('')) {
        pulled++;
        yield ch;
      }
    }

    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => chars(),
    ).toList();

    expect((events.last as ChatStreamDone).reply!.text, 'Nice month!');
    // The generator was cancelled once <end_of_turn> resolved — it never
    // got to yield the trailing "MORE".
    expect(pulled, lessThan('Nice month!<end_of_turn>MORE'.length));
  });

  test('holds back leading Coach: label while streaming, not just at the end',
      () async {
    final events = await ChatAdapter.generateStream(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      inferStream: (p) => _charStream('Coach: Groceries drive your spend.'),
    ).toList();
    final texts =
        events.whereType<ChatStreamText>().map((e) => e.text).toList();
    for (final t in texts) {
      expect(t.toLowerCase(), isNot(contains('coach')));
    }
    expect(texts.last, 'Groceries drive your spend.');
  });
}
