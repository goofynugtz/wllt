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

class _InsightChatScreenState extends State<InsightChatScreen> {
  final _messages = <_ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _generating = false;
  String? _lastUserMessage;

  @override
  void initState() {
    super.initState();
    // The tapped insight opens the conversation. Not saveable — it is the
    // insight itself, not a suggestion.
    _messages.add(_ChatMessage(isUser: false, text: widget.insightText));
  }

  @override
  void dispose() {
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

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _generating) return;
    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
    });
    await _generate(text);
  }

  /// Re-runs generation for the last user message after an error bubble.
  Future<void> _retry() async {
    final text = _lastUserMessage;
    if (text == null || _generating) return;
    setState(() {
      _messages.removeWhere((m) => m.isError);
    });
    await _generate(text);
  }

  Future<void> _generate(String userMessage) async {
    _lastUserMessage = userMessage;
    // History for the model excludes the message being answered — it goes
    // into the prompt's final user turn instead.
    final turns = _historyForModel;
    final history = turns.sublist(0, turns.length - 1);
    setState(() => _generating = true);
    _scrollToBottom();

    final reply = await ChatAdapter.generate(
      facts: widget.factLines,
      history: history,
      userMessage: userMessage,
      infer: (p) =>
          AiService.instance.infer(p, temperature: 0.4, maxTokens: 150),
    );

    if (!mounted) return;
    setState(() {
      _generating = false;
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
                itemCount: _messages.length + (_generating ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _ThinkingBubble();
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
            onPressed: _generating ? null : _send,
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

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FadeTransition(
          opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
          child: Text(
            'Thinking…',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
