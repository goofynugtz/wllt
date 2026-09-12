import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/sms_provider.dart';
import '../providers/app_settings_provider.dart';
import 'sms_pending_card.dart';

class SmsInboxSheet extends StatefulWidget {
  const SmsInboxSheet({super.key});

  @override
  State<SmsInboxSheet> createState() => _SmsInboxSheetState();
}

class _SmsInboxSheetState extends State<SmsInboxSheet> {
  final _itemKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return Consumer<SmsProvider>(
          builder: (ctx, sms, _) {
            final devMode = ctx.watch<AppSettingsProvider>().devMode;
            final items = devMode
                ? sms.pending
                : sms.pending.where((p) => (p.amount ?? 0) != 0).toList();

            if (sms.highlightedId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final key = _itemKeys[sms.highlightedId];
                if (key?.currentContext != null) {
                  Scrollable.ensureVisible(
                    key!.currentContext!,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                }
                sms.clearHighlight();
              });
            }

            if (sms.miscCategoryJustCreated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text("A 'Misc' category was created for unrecognized transactions"),
                  ),
                );
                sms.clearMiscCategoryFlag();
              });
            }

            return Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Text(
                        'SMS Transactions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${items.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.messageSquare, size: 36, color: cs.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                'No new transactions from SMS',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            _itemKeys.putIfAbsent(item.id, () => GlobalKey());
                            return SmsPendingCard(
                              key: _itemKeys[item.id],
                              item: item,
                              highlighted: sms.highlightedId == item.id,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
