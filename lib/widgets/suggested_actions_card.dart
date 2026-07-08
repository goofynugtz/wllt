import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/suggested_action.dart';
import '../providers/suggested_actions_provider.dart';

/// Home-screen checklist of suggestions saved from insight chat.
/// Unchecked newest-first, checked sink to the bottom (struck through,
/// dismissible via X). Hidden entirely when the list is empty.
class SuggestedActionsCard extends StatelessWidget {
  const SuggestedActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestedActionsProvider>();
    final actions = provider.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    final pending = actions.where((a) => !a.done).toList();
    final done = actions.where((a) => a.done).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.clipboardCheck,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Suggested Actions',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final action in pending) _ActionRow(action: action),
          for (final action in done) _ActionRow(action: action),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final SuggestedAction action;

  const _ActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.read<SuggestedActionsProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.toggleDone(action.id),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                action.done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                size: 18,
                color: action.done ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => provider.toggleDone(action.id),
              child: Text(
                action.text,
                style: TextStyle(
                  fontSize: 12,
                  color: action.done
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  decoration:
                      action.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          if (action.done)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => provider.remove(action.id),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Icon(
                  LucideIcons.x,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
