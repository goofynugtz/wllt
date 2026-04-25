import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../screens/transactions_screen.dart';
import '../screens/bank_picker_screen.dart';
import 'add_account_screen.dart';

class AccountDetailScreen extends StatelessWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  Color get _brandColor {
    if (account.type == AccountType.cash) return AppTheme.primaryColor;
    try {
      return kAllBanks.firstWhere((b) => b.name == account.bank).brandColor;
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  List<Transaction> get _transactions =>
      Transaction.dummyData
          .where((t) => t.account == account.name)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Map<String, List<Transaction>> get _grouped =>
      Helpers.groupByDate(_transactions);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _brandColor;
    final isNegative = account.balance < 0;

    // Derive gradient stops from brand color
    final colorDark = _adjustLightness(color, -0.18);
    final colorMid  = _adjustLightness(color,  0.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Hero ──────────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorDark, colorMid],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  top: -48,
                  right: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -32,
                  left: -56,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back + Edit row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _HeroButton(
                              icon: LucideIcons.arrowLeft,
                              onTap: () => Navigator.pop(context),
                            ),
                            _HeroButton(
                              icon: LucideIcons.pencil,
                              onTap: () async {
                                final result = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddAccountScreen(initialAccount: account),
                                  ),
                                );
                                if (result == 'deleted' && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Bank badge + name
                        Row(
                          children: [
                            _HeroBadge(account: account),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    account.bank ?? _accountTypeLabel(account.type),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (account.cardIdentifier != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '•••• ${account.cardIdentifier}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Balance label
                        Text(
                          account.type == AccountType.credit
                              ? 'OUTSTANDING BALANCE'
                              : 'AVAILABLE BALANCE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Balance amount
                        Text(
                          '${isNegative ? '−' : ''}${Helpers.formatINR(account.balance.abs())}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -1.0,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Transactions ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Text(
                  'TRANSACTIONS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Divider(height: 1, color: cs.outlineVariant)),
                const SizedBox(width: 8),
                Text(
                  '${_transactions.length}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

          Expanded(
            child: _grouped.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.receipt, size: 32, color: cs.outlineVariant),
                        const SizedBox(height: 8),
                        Text(
                          'No transactions yet',
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: _grouped.entries.map((entry) {
                      return _buildDayGroup(context, entry.key, entry.value);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayGroup(BuildContext context, String dateStr, List<Transaction> txs) {
    final cs = Theme.of(context).colorScheme;
    final dayExpense = txs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(Helpers.formatDateLabel(dateStr), style: AppTheme.trackingWideSecondary),
                if (dayExpense > 0)
                  Text(
                    '−${Helpers.formatINR(dayExpense)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.expenseColor),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant, width: 0.5),
              ),
              child: Column(
                children: txs.asMap().entries.map((e) {
                  return TransactionRow(transaction: e.value, isFirst: e.key == 0);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _accountTypeLabel(AccountType type) {
  switch (type) {
    case AccountType.bank:   return 'Bank Account';
    case AccountType.credit: return 'Credit Card';
    case AccountType.cash:   return 'Cash';
  }
}

Color _adjustLightness(Color color, double delta) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}

// ── Hero icon button (back / edit) ────────────────────────────────────────────

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ── Hero bank badge ───────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final Account account;

  const _HeroBadge({required this.account});

  @override
  Widget build(BuildContext context) {
    if (account.type == AccountType.cash) {
      return Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(LucideIcons.wallet, size: 20, color: Colors.white),
      );
    }

    if (account.bankLogoPath != null) {
      return Container(
        width: 44, height: 44,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SvgPicture.asset(account.bankLogoPath!, fit: BoxFit.contain),
      );
    }

    // Initials fallback
    final words = (account.bank ?? account.name).split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : (account.bank ?? account.name).substring(0, 2).toUpperCase();

    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
