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

/// Produces a stream of raw model token deltas for [prompt], as
/// [AiService.inferStream] does.
typedef InferStreamFn = Stream<String> Function(String prompt);

/// Events emitted by [ChatAdapter.generateStream], oldest first, always
/// terminated by exactly one [ChatStreamDone].
sealed class ChatStreamEvent {}

/// The growing, marker-safe prefix of the reply's conversational text. Each
/// event's [text] is a superset of the previous event's — safe to render
/// directly, it never shrinks or exposes a partial marker (the one
/// exception is a single trailing-whitespace trim the instant a marker
/// resolves, matching the final parsed text).
class ChatStreamText extends ChatStreamEvent {
  final String text;
  ChatStreamText(this.text);
}

/// Terminal event. [reply] is null when the model produced nothing usable
/// or inference failed — caller shows an error bubble with retry.
class ChatStreamDone extends ChatStreamEvent {
  final ChatReply? reply;
  ChatStreamDone(this.reply);
}

class ChatAdapter {
  ChatAdapter._();

  static const _marker = 'action:';
  static const _coachLabel = 'coach:';

  /// ~700 tokens at ~4 chars/token for the facts + history + message block.
  /// The model context is 1024; this leaves room for the rule text and the
  /// reply.
  static const _charBudget = 2800;

  /// The model tends to continue the dialogue past its own turn; anything
  /// after these markers is hallucinated conversation, not the reply. Only
  /// these — not [_marker] — signal the reply itself has ended.
  static const _stopMarkers = [
    '<end_of_turn>',
    '<start_of_turn>',
    '\nUser:',
    '\nCoach:',
  ];

  /// Strings watched for partial-match hold-back at the tail of the safe
  /// prefix, so a marker never flashes on screen mid-character.
  static final _watchStrings = [..._stopMarkers, _marker];

  /// Runs one chat turn as a stream of events: zero or more [ChatStreamText]
  /// (a growing, marker-safe prefix of the reply) followed by exactly one
  /// [ChatStreamDone]. Rebuilds the full prompt every call (stateless —
  /// AiService uses one session per inference) in Gemma's multi-turn format,
  /// so the model never sees name labels it could echo back.
  static Stream<ChatStreamEvent> generateStream({
    required List<String> facts,
    required List<ChatTurn> history,
    required String userMessage,
    required InferStreamFn inferStream,
  }) async* {
    final prompt = _buildPrompt(
      facts: facts,
      history: history,
      userMessage: userMessage,
    );

    final buffer = StringBuffer();
    var lastVisible = '';
    ChatReply? reply;
    try {
      await for (final chunk in inferStream(prompt)) {
        buffer.write(chunk);
        final raw = buffer.toString();
        final seen = _visibleFrom(raw);
        if (seen.visible != lastVisible) {
          lastVisible = seen.visible;
          yield ChatStreamText(lastVisible);
        }
        if (seen.complete) {
          reply = _parse(raw);
          break;
        }
      }
      reply ??= _parse(buffer.toString());
    } catch (_) {
      reply = null;
    }
    yield ChatStreamDone(reply);
  }

  static String _buildPrompt({
    required List<String> facts,
    required List<ChatTurn> history,
    required String userMessage,
  }) {
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
    return prompt.toString();
  }

  /// Safe-to-render visible text for the raw buffer accumulated so far, and
  /// whether the reply itself is now known-complete (a stop marker fully
  /// matched, so anything further is hallucinated continuation — safe to
  /// stop listening). [_marker] ("action:") caps how far [visible] grows
  /// but does *not* mark completion — the action body keeps streaming in
  /// after it.
  static ({String visible, bool complete}) _visibleFrom(String raw) {
    final t = raw.trimLeft();
    final lower = t.toLowerCase();
    var start = 0;
    if (lower.startsWith(_coachLabel)) {
      start = _coachLabel.length;
      while (start < t.length && t[start] == ' ') {
        start++;
      }
    } else if (_coachLabel.startsWith(lower)) {
      // Buffer so far is a strict prefix of "coach:" — could still become
      // the echoed label. Nothing safe to show yet.
      return (visible: '', complete: false);
    }

    final rest = t.substring(start);
    var stopCut = rest.length;
    for (final stop in _stopMarkers) {
      final i = rest.indexOf(stop);
      if (i != -1 && i < stopCut) stopCut = i;
    }
    final actionIdx = rest.toLowerCase().indexOf(_marker);
    final cut = actionIdx != -1 && actionIdx < stopCut ? actionIdx : stopCut;

    final region = rest.substring(0, cut);
    final hold = _holdback(region);
    final visible = region.substring(0, region.length - hold);

    // Once cut is pinned by either kind of marker, region can never grow
    // again — safe to trim trailing whitespace to match the final parse.
    final frozen = cut < rest.length;
    final complete = stopCut < rest.length;
    return (
      visible: frozen ? visible.trimRight() : visible,
      complete: complete,
    );
  }

  /// Longest suffix of [region] that is a strict prefix of any watched
  /// marker string — withheld because it might still grow into a full
  /// match on the next chunk.
  static int _holdback(String region) {
    var hold = 0;
    for (final watch in _watchStrings) {
      final caseSensitive = watch != _marker;
      final hay = caseSensitive ? region : region.toLowerCase();
      final needle = caseSensitive ? watch : watch.toLowerCase();
      final maxLen = (needle.length - 1).clamp(0, hay.length);
      for (var k = maxLen; k > hold; k--) {
        if (hay.substring(hay.length - k) == needle.substring(0, k)) {
          hold = k;
          break;
        }
      }
    }
    return hold;
  }

  static ChatReply? _parse(String raw) {
    var text = raw.trim();

    for (final stop in _stopMarkers) {
      final i = text.indexOf(stop);
      if (i != -1) text = text.substring(0, i).trim();
    }

    // Strip an echoed leading speaker label.
    if (text.toLowerCase().startsWith(_coachLabel)) {
      text = text.substring(_coachLabel.length).trim();
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
