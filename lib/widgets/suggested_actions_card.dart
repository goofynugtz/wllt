import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/suggested_actions_provider.dart';
import '../screens/suggested_actions_screen.dart';

/// Home-screen entry point into the "Suggested Actions" checklist saved
/// from insight chat. Shows a pending count; tapping opens the full
/// checklist. Hidden entirely when there are no saved suggestions.
class SuggestedActionsCard extends StatelessWidget {
  const SuggestedActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuggestedActionsProvider>();
    final actions = provider.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    final pendingCount = actions.where((a) => !a.done).length;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SuggestedActionsScreen()),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.clipboardCheck, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Suggested Actions',
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
            ),
            if (pendingCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              )
            else
              Icon(LucideIcons.checkCircle2, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
