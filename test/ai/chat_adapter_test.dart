import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/ai/chat_adapter.dart';

void main() {
  const facts = [
    'Recurring subscriptions: Netflix ₹649 (₹649/month total)',
    'Top category: Groceries ₹8,200 (41% of ₹20,000 total)',
  ];

  test('splits mid-reply ACTION into text and actionText', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'How can I save money?',
      infer: (p) async =>
          'You spend a lot on subscriptions. ACTION: Cancel Netflix to save ₹649/month.',
    );
    expect(reply, isNotNull);
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'You spend a lot on subscriptions.');
    expect(reply.actionText, 'Cancel Netflix to save ₹649/month.');
  });

  test('reply that is only an action yields empty text', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => 'ACTION: Cancel Netflix to save ₹649/month.',
    );
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, isEmpty);
    expect(reply.actionText, 'Cancel Netflix to save ₹649/month.');
  });

  test('marker match is case-insensitive and trims whitespace', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => 'Try this.  action:   cap groceries at ₹7,000  ',
    );
    expect(reply!.isSuggestion, isTrue);
    expect(reply.text, 'Try this.');
    expect(reply.actionText, 'cap groceries at ₹7,000');
  });

  test('strips echoed leading Coach: label', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'why is my spend high?',
      infer: (p) async => 'Coach: Groceries drive most of your spending.',
    );
    expect(reply!.isSuggestion, isFalse);
    expect(reply.text, 'Groceries drive most of your spending.');
  });

  test('strips Coach: label and still parses action', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async =>
          'Coach: You overspend on food. ACTION: Set a ₹7,000 grocery cap',
    );
    expect(reply!.text, 'You overspend on food.');
    expect(reply.actionText, 'Set a ₹7,000 grocery cap');
  });

  test('truncates hallucinated dialogue continuation', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => 'Cut your coffee spend.\nUser: okay\nCoach: great!',
    );
    expect(reply!.text, 'Cut your coffee spend.');
    expect(reply.isSuggestion, isFalse);
  });

  test('truncates at hallucinated turn tokens', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async =>
          'Nice month overall!<end_of_turn>\n<start_of_turn>user\nthanks',
    );
    expect(reply!.text, 'Nice month overall!');
  });

  test('reply without marker is not a suggestion', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'why is my spend high?',
      infer: (p) async => 'Which category do you want to cut first?',
    );
    expect(reply!.isSuggestion, isFalse);
    expect(reply.actionText, isNull);
    expect(reply.text, 'Which category do you want to cut first?');
  });

  test('returns null on empty reply', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => '   ',
    );
    expect(reply, isNull);
  });

  test('returns null on marker with empty body', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => 'ACTION:',
    );
    expect(reply, isNull);
  });

  test('returns null when infer throws', () async {
    final reply = await ChatAdapter.generate(
      facts: facts,
      history: const [],
      userMessage: 'hi',
      infer: (p) async => throw Exception('timeout'),
    );
    expect(reply, isNull);
  });

  test('prompt uses Gemma multi-turn format without name labels', () async {
    String? seen;
    await ChatAdapter.generate(
      facts: facts,
      history: const [
        ChatTurn(isUser: false, text: 'Earlier coach reply'),
        ChatTurn(isUser: true, text: 'What about groceries?'),
      ],
      userMessage: 'And subscriptions?',
      infer: (p) async {
        seen = p;
        return 'ok';
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
    await ChatAdapter.generate(
      facts: facts,
      history: history,
      userMessage: 'latest question',
      infer: (p) async {
        seen = p;
        return 'ok';
      },
    );
    expect(seen, isNot(contains('turn0 ')));
    expect(seen, contains('turn49 '));
    expect(seen, contains('Netflix ₹649'));
    expect(seen, contains('latest question'));
    expect(seen!.length, lessThan(4000));
  });
}
