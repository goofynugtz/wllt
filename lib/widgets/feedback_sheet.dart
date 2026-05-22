import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/feedback_service.dart';

class FeedbackSheet extends StatefulWidget {
  final String trigger;
  const FeedbackSheet({super.key, required this.trigger});

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  bool _showTextStep = false;
  bool _submitting = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _userId =>
      context.read<UserPreferencesProvider>().googleUid ?? 'offline';

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await FeedbackService.submitFeedback(
        sentiment: 'negative',
        message: text,
        trigger: widget.trigger,
        userId: _userId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send feedback. Try again.')),
      );
    }
  }

  Future<void> _onPositive() async {
    final userId = _userId;
    Navigator.of(context).pop();
    await FeedbackService.submitFeedback(
      sentiment: 'positive',
      trigger: widget.trigger,
      userId: userId,
    );
    await FeedbackService.requestReview();
  }

  Future<void> _onSkip() async {
    final userId = _userId;
    Navigator.of(context).pop();
    await FeedbackService.submitFeedback(
      sentiment: 'negative',
      trigger: widget.trigger,
      userId: userId,
    );
  }

  void _onNegative() => setState(() => _showTextStep = true);

  Widget _buildDragHandle(ColorScheme cs) => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildStep1(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDragHandle(cs),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enjoying WLLT?',
                style: TextStyle(fontSize: 18, color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Takes one tap',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SentimentButton(
                      icon: LucideIcons.thumbsUp,
                      label: 'Loving it',
                      background: cs.primaryContainer,
                      foreground: cs.onPrimaryContainer,
                      onTap: _onPositive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SentimentButton(
                      icon: LucideIcons.thumbsDown,
                      label: 'Not really',
                      background: cs.surfaceContainerHighest,
                      foreground: cs.onSurfaceVariant,
                      onTap: _onNegative,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(ColorScheme cs) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(cs),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What can we do better?',
                  style: TextStyle(fontSize: 18, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Goes directly to the developer',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  minLines: 3,
                  maxLines: 5,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Tell us what's on your mind…",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Feedback'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _onSkip,
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: _showTextStep ? _buildStep2(cs) : _buildStep1(cs),
    );
  }
}

class _SentimentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _SentimentButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 24, color: foreground),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
