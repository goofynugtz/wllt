import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../ai/chat_adapter.dart';
import '../providers/suggested_actions_provider.dart';
import '../services/ai_service.dart';

/// Ephemeral chat with the on-device model about the current weekly insight.
/// Seeded with the insight text and the fact lines that generated it. All
/// state is screen-local — popping discards the conversation; saved actions
/// are the durable output.
class InsightChatScreen extends StatefulWidget {
  final String insightText;
  final List<String> factLines;

  const InsightChatScreen({
    super.key,
    required this.insightText,
    required this.factLines,
  });

  @override
  State<InsightChatScreen> createState() => _InsightChatScreenState();
}

class _ChatMessage {
  final bool isUser;
  final String text;

  /// Concrete saving suggestion parsed out of the reply; rendered as a
  /// separate save chip under the conversational text.
  final String? actionText;
  final bool isError;

  const _ChatMessage({
    required this.isUser,
    required this.text,
    this.actionText,
    this.isError = false,
  });
}

/// Where the in-flight reply is: not generating, waiting for the first
/// token (dots), or actively revealing streamed text.
enum _Phase { idle, thinking, streaming }

class _InsightChatScreenState extends State<InsightChatScreen> {
  final _messages = <_ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  _Phase _phase = _Phase.idle;
  String? _lastUserMessage;

  // Typewriter reveal: the model-safe text known so far ([_targetText]) vs.
  // what's currently on screen ([_displayedText]); a ticker advances the
  // latter toward the former at a capped, catch-up-aware pace.
  String _targetText = '';
  String _displayedText = '';
  Timer? _revealTimer;
  StreamSubscription<ChatStreamEvent>? _streamSub;

  static const _tick = Duration(milliseconds: 16);
  // Target baseline; the actual floor is higher in practice because
  // charsThisTick rounds up to at least 1 char per 16ms tick (~62/sec).
  static const _baseCharsPerSecond = 40.0;
  static const _catchUpBacklogChars = 60;
  static const _catchUpDurationMs = 500;

  @override
  void initState() {
    super.initState();
    // The tapped insight opens the conversation. Not saveable — it is the
    // insight itself, not a suggestion.
    _messages.add(_ChatMessage(isUser: false, text: widget.insightText));
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _revealTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// History for the prompt. Recombines a parsed-out action with its text so
  /// the model sees its own prior suggestions in the format it produced them.
  List<ChatTurn> get _historyForModel => [
        for (final m in _messages)
          if (!m.isError)
            ChatTurn(
              isUser: m.isUser,
              text: m.actionText == null
                  ? m.text
                  : m.text.isEmpty
                      ? 'ACTION: ${m.actionText}'
                      : '${m.text}\nACTION: ${m.actionText}',
            ),
      ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _phase != _Phase.idle) return;
    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
    });
    _generate(text);
  }

  /// Re-runs generation for the last user message after an error bubble.
  void _retry() {
    final text = _lastUserMessage;
    if (text == null || _phase != _Phase.idle) return;
    setState(() {
      _messages.removeWhere((m) => m.isError);
    });
    _generate(text);
  }

  void _generate(String userMessage) {
    _lastUserMessage = userMessage;
    // History for the model excludes the message being answered — it goes
    // into the prompt's final user turn instead.
    final turns = _historyForModel;
    final history = turns.sublist(0, turns.length - 1);

    setState(() {
      _phase = _Phase.thinking;
      _targetText = '';
      _displayedText = '';
    });
    _scrollToBottom();

    final stream = ChatAdapter.generateStream(
      facts: widget.factLines,
      history: history,
      userMessage: userMessage,
      inferStream: (p) => AiService.instance.inferStream(p, temperature: 0.7),
    );

    _streamSub = stream.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ChatStreamText(:final text):
          setState(() {
            if (_phase == _Phase.thinking) _phase = _Phase.streaming;
            _targetText = text;
          });
          _revealTimer ??= Timer.periodic(_tick, _onRevealTick);
          _scrollToBottom();
        case ChatStreamDone(:final reply):
          _revealTimer?.cancel();
          _revealTimer = null;
          setState(() {
            _phase = _Phase.idle;
            _messages.add(reply == null
                ? const _ChatMessage(
                    isUser: false,
                    text: "Couldn't think of a reply. Try again.",
                    isError: true,
                  )
                : _ChatMessage(
                    isUser: false,
                    text: reply.text,
                    actionText: reply.actionText,
                  ));
          });
          _scrollToBottom();
      }
    });
  }

  void _onRevealTick(Timer t) {
    if (!mounted) return;
    if (_displayedText.length >= _targetText.length) return;
    final backlog = _targetText.length - _displayedText.length;
    final charsPerSecond = backlog > _catchUpBacklogChars
        ? backlog * 1000 / _catchUpDurationMs
        : _baseCharsPerSecond;
    final charsThisTick =
        (charsPerSecond * _tick.inMilliseconds / 1000).ceil().clamp(1, backlog);
    setState(() {
      _displayedText =
          _targetText.substring(0, _displayedText.length + charsThisTick);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insight Chat')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length + (_phase == _Phase.idle ? 0 : 1),
                itemBuilder: (context, i) {
                  if (i == _messages.length) {
                    return _phase == _Phase.thinking || _displayedText.isEmpty
                        ? const _ThinkingDots()
                        : _StreamingBubble(text: _displayedText);
                  }
                  return _MessageBubble(
                    message: _messages[i],
                    onRetry: _messages[i].isError ? _retry : null,
                  );
                },
              ),
            ),
            _buildInputRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              inputFormatters: [LengthLimitingTextInputFormatter(400)],
              decoration: InputDecoration(
                hintText: 'Ask about your spending…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _phase == _Phase.idle ? _send : null,
            icon: const Icon(LucideIcons.send, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: message.isError
              ? Border.all(color: scheme.error.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  color: isUser
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            if (message.actionText != null) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              _ActionChip(text: message.actionText!),
            ],
            if (message.isError && onRetry != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onRetry,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.refreshCw, size: 12, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The parsed ACTION suggestion as its own tappable element: shows the
/// action text with a save affordance; tapping anywhere on it saves.
class _ActionChip extends StatelessWidget {
  final String text;

  const _ActionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestedActionsProvider>();
    final saved = provider.contains(text);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: saved
          ? null
          : () => context.read<SuggestedActionsProvider>().add(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: saved
              ? scheme.surfaceContainerHigh
              : scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: saved
                ? scheme.outlineVariant.withValues(alpha: 0.5)
                : scheme.primary.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              saved ? LucideIcons.check : LucideIcons.bookmarkPlus,
              size: 14,
              color: saved ? scheme.onSurfaceVariant : scheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: saved ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              saved ? 'Saved ✓' : 'Save',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: saved ? scheme.onSurfaceVariant : scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live preview of the reply while it's still streaming in: same shape as
/// a non-user [_MessageBubble] but no action chip or retry affordance —
/// those only make sense once the reply is finalized.
class _StreamingBubble extends StatelessWidget {
  final String text;

  const _StreamingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Bouncing 3-dot "typing" indicator shown while waiting for the first
/// token of a reply.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Stagger each dot by a third of the cycle; bounce via a
                // triangle wave so the motion eases up and back down.
                final t = (_controller.value + i / 3) % 1.0;
                final bounce = (t < 0.5 ? t : 1 - t) * 2; // 0..1..0
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -4 * bounce),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
