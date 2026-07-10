import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/suggested_action.dart';
import '../providers/suggested_actions_provider.dart';

/// Full checklist of suggestions saved from insight chat. Pushed from the
/// compact [SuggestedActionsCard] on the home screen.
class SuggestedActionsScreen extends StatelessWidget {
  const SuggestedActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestedActionsProvider>();
    final actions = provider.actions;
    final pending = actions.where((a) => !a.done).toList();
    final done = actions.where((a) => a.done).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Suggested Actions')),
      body: SafeArea(
        child: actions.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  for (final action in pending) _ActionRow(action: action),
                  for (final action in done) _ActionRow(action: action),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.clipboardCheck,
              size: 32,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No suggestions yet. Ask the AI coach in Insight Chat and '
              'save a suggestion to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
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
                  fontSize: 13,
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
