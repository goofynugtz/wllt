import 'categorization_adapter.dart' show InferFn;

/// One prior exchange in the ephemeral insight chat, oldest first.
class ChatTurn {
  final bool isUser;
  final String text;
  const ChatTurn({required this.isUser, required this.text});
}

/// A parsed model reply. [text] is the conversational part (may be empty
/// when the whole reply was an action); [actionText] is the concrete saving
/// suggestion split out from an "ACTION:" marker anywhere in the reply.
class ChatReply {
  final String text;
  final String? actionText;
  const ChatReply({required this.text, this.actionText});

  bool get isSuggestion => actionText != null;
}

class ChatAdapter {
  ChatAdapter._();

  static const _marker = 'action:';

  /// ~700 tokens at ~4 chars/token for the facts + history + message block.
  /// The model context is 1024; this leaves room for the rule text and the
  /// reply.
  static const _charBudget = 2800;

  /// The model tends to continue the dialogue past its own turn; anything
  /// after these markers is hallucinated conversation, not the reply.
  static const _stopMarkers = [
    '<end_of_turn>',
    '<start_of_turn>',
    '\nUser:',
    '\nCoach:',
  ];

  /// Runs one chat turn. Rebuilds the full prompt every call (stateless —
  /// AiService uses one session per inference) in Gemma's multi-turn format,
  /// so the model never sees name labels it could echo back. Returns null
  /// when the model produced nothing usable or inference failed; caller
  /// shows an error bubble with retry.
  static Future<ChatReply?> generate({
    required List<String> facts,
    required List<ChatTurn> history,
    required String userMessage,
    required InferFn infer,
  }) async {
    final factBlock = facts.map((f) => '- $f').join('\n');

    // Drop oldest turns until facts + history + message fit the budget.
    final kept = List<ChatTurn>.from(history);
    int turnsLength() => kept.fold(0, (s, t) => s + t.text.length);
    while (kept.isNotEmpty &&
        factBlock.length + turnsLength() + userMessage.length > _charBudget) {
      kept.removeAt(0);
    }

    final prompt = StringBuffer()
      ..write('<start_of_turn>user\n')
      ..write('You are a personal finance coach chatting with the user. '
          "User's spending facts:\n"
          '$factBlock\n'
          'Rules: Speak directly to the user in plain sentences — never '
          'start your reply with a name or label. Max 3 sentences. Cite '
          'exact amounts from the facts. If you recommend one concrete '
          'saving action, put it on a final line starting with "ACTION:". '
          'If you need more info, just ask a question instead.\n');
    if (kept.isEmpty) {
      prompt.write('$userMessage\n<end_of_turn>\n<start_of_turn>model\n');
    } else {
      prompt.write('<end_of_turn>\n');
      for (final t in kept) {
        prompt.write('<start_of_turn>${t.isUser ? 'user' : 'model'}\n'
            '${t.text}<end_of_turn>\n');
      }
      prompt.write('<start_of_turn>user\n$userMessage\n<end_of_turn>\n'
          '<start_of_turn>model\n');
    }

    try {
      return _parse(await infer(prompt.toString()));
    } catch (_) {
      return null;
    }
  }

  static ChatReply? _parse(String raw) {
    var text = raw.trim();

    for (final stop in _stopMarkers) {
      final i = text.indexOf(stop);
      if (i != -1) text = text.substring(0, i).trim();
    }

    // Strip an echoed leading speaker label.
    if (text.toLowerCase().startsWith('coach:')) {
      text = text.substring('coach:'.length).trim();
    }

    // Split out the ACTION suggestion wherever it appears. toLowerCase is
    // length-preserving here, so the index maps back onto the original.
    final idx = text.toLowerCase().indexOf(_marker);
    String? actionText;
    if (idx != -1) {
      final body = text.substring(idx + _marker.length).trim();
      actionText = body.isEmpty ? null : body;
      text = text.substring(0, idx).trim();
    }

    if (text.isEmpty && actionText == null) return null;
    return ChatReply(text: text, actionText: actionText);
  }
}
