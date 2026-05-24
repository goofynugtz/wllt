import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/pending_sms_transaction.dart';
import '../providers/sms_provider.dart';
import '../providers/account_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../data/currencies.dart';
import 'category_icon_widget.dart';

class SmsPendingCard extends StatefulWidget {
  final PendingSmsTransaction item;
  final bool highlighted;

  const SmsPendingCard({super.key, required this.item, this.highlighted = false});

  @override
  State<SmsPendingCard> createState() => _SmsPendingCardState();
}

class _SmsPendingCardState extends State<SmsPendingCard> {
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TransactionType _type;
  late String? _categoryId;
  String? _accountId;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.merchant ?? '');
    _amountCtrl = TextEditingController(
      text: widget.item.amount != null ? '${widget.item.amount}' : '',
    );
    _type = widget.item.type;
    _categoryId = widget.item.categoryId;
  }

  @override
  void didUpdateWidget(SmsPendingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !oldWidget.highlighted) {
      setState(() => _flash = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _flash = false);
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncAndConfirm(SmsProvider sms) async {
    await sms.updateItem(
      widget.item.id,
      merchant: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text),
      type: _type,
      categoryId: _categoryId,
      accountHint: _accountId,
    );
    await sms.confirm(widget.item.id);
  }

  Future<void> _syncAndDismiss(SmsProvider sms) async {
    await sms.dismiss(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sms = context.read<SmsProvider>();
    final accounts = context.watch<AccountProvider>().accounts;
    final prefs = context.watch<UserPreferencesProvider>();
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == prefs.currency, orElse: () => kCurrencies.first)
        .symbol;

    final allCategories = [
      ...Category.categories.where((c) =>
          prefs.activeCategories.isEmpty || prefs.activeCategories.contains(c.id)),
      ...prefs.customCategories,
    ];

    if (_accountId == null && widget.item.accountHint != null) {
      final matches = accounts.where((a) =>
          a.displayName.toLowerCase().contains(widget.item.accountHint!.toLowerCase())).toList();
      if (matches.length == 1) _accountId = matches.first.id;
    }

    return Dismissible(
      key: ValueKey(widget.item.id),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await _syncAndConfirm(sms);
          return false;
        } else {
          await _syncAndDismiss(sms);
          return false;
        }
      },
      background: _buildSwipeBackground(cs, isConfirm: true),
      secondaryBackground: _buildSwipeBackground(cs, isConfirm: false),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _flash
                ? cs.primary
                : widget.item.verdict == SmsVerdict.suspicious
                    ? Colors.red.withValues(alpha: 0.4)
                    : cs.outlineVariant.withValues(alpha: 0.4),
            width: _flash ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.item.verdict == SmsVerdict.suspicious)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, size: 14, color: Colors.red),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Could not verify sender. Confirm only if you recognise this transaction.',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(currencySymbol, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontFamily: 'Archia',
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 20,
                              fontFamily: 'Archia',
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _type = _type == TransactionType.expense
                            ? TransactionType.income
                            : TransactionType.expense),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _type == TransactionType.expense
                                ? Colors.red.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _type == TransactionType.expense ? 'Expense' : 'Income',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _type == TransactionType.expense ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.item.isUnparsed
                          ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                          : cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.item.isUnparsed
                          ? "We don't know what this was for"
                          : 'Description',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: allCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = allCategories[i];
                        final selected = _categoryId == cat.id;
                        final accent = Color(
                          int.parse(cat.color.replaceFirst('#', ''), radix: 16) + 0xFF000000,
                        );
                        return GestureDetector(
                          onTap: () => setState(() => _categoryId = cat.id),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected ? accent : cs.surfaceContainerLow,
                              shape: BoxShape.circle,
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: cs.outlineVariant.withValues(alpha: 0.4),
                                      width: 0.5,
                                    ),
                            ),
                            child: Center(
                              child: CategoryIconWidget(
                                category: cat,
                                size: 20,
                                color: selected ? Colors.white : cs.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (accounts.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: accounts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final acc = accounts[i];
                          final selected = _accountId == acc.id;
                          return GestureDetector(
                            onTap: () => setState(() => _accountId = acc.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: selected ? cs.primary : cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: selected
                                    ? null
                                    : Border.all(
                                        color: cs.outlineVariant.withValues(alpha: 0.4),
                                        width: 0.5,
                                      ),
                              ),
                              child: Center(
                                child: Text(
                                  acc.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: selected ? cs.onPrimary : cs.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),
                ],
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _syncAndDismiss(sms),
                    child: Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.x, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'Dismiss',
                              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.item.isUnparsed
                        ? sms.confirmAsMisc(widget.item.id)
                        : _syncAndConfirm(sms),
                    child: Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.item.isUnparsed ? LucideIcons.plus : LucideIcons.check,
                              size: 14,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.item.isUnparsed ? 'Add as misc expense' : 'Confirm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(ColorScheme cs, {required bool isConfirm}) {
    return Container(
      decoration: BoxDecoration(
        color: isConfirm ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isConfirm ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        isConfirm ? LucideIcons.check : LucideIcons.x,
        color: isConfirm ? Colors.green : Colors.red,
      ),
    );
  }
}
