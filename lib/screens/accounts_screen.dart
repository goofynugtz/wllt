import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final netWorth = Account.accounts.fold(
      0.0,
      (sum, account) => sum + account.balance,
    );
    final totalAssets = Account.accounts
        .where((a) => a.balance > 0)
        .fold(0.0, (sum, a) => sum + a.balance);
    final totalDebt = Account.accounts
        .where((a) => a.balance < 0)
        .fold(0.0, (sum, a) => sum + a.balance.abs());

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Net worth card
            _NetWorthCard(
              netWorth: netWorth,
              totalAssets: totalAssets,
              totalDebt: totalDebt,
            ),

            const SizedBox(height: 16),

            // Account cards
            ...Account.accounts.map((account) {
              final txCount = Transaction.transactions
                  .where((t) => t.account == account.name)
                  .length;
              return AccountCard(account: account, transactionCount: txCount);
            }),

            const SizedBox(height: 16),

            // Link bank button
            _LinkBankButton(),

            const SizedBox(height: 16),

            // Disclaimer
            const Text(
              'Balances are synced from SMS notifications. Last updated just now.',
              style: TextStyle(fontSize: 11, color: Color(0xFFc0bdb8)),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  final double netWorth;
  final double totalAssets;
  final double totalDebt;

  const _NetWorthCard({
    required this.netWorth,
    required this.totalAssets,
    required this.totalDebt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net Worth',
                style: AppTheme.trackingWide.copyWith(
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${netWorth >= 0 ? '' : '−'}${Helpers.formatINR(netWorth.abs())}',
                style: const TextStyle(
                                    fontSize: 36,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  // Assets
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assets',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 0.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Helpers.formatINR(totalAssets),
                        style: const TextStyle(
                                                    fontSize: 14,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Divider
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.1),
                  ),

                  const SizedBox(width: 16),

                  // Debt
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debt',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 0.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Helpers.formatINR(totalDebt),
                        style: const TextStyle(
                                                    fontSize: 14,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  final Account account;
  final int transactionCount;

  const AccountCard({
    super.key,
    required this.account,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = account.balance < 0;
    final sparkColor = isNegative
        ? AppTheme.warningColor
        : AppTheme.incomeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          // Account info and sparkline
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Account info
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: account.bankLogoPath != null
                        ? SvgPicture.asset(
                            account.bankLogoPath!,
                            fit: BoxFit.contain,
                          )
                        : Icon(
                            _getAccountIcon(account.type),
                            size: 18,
                            color: isNegative
                                ? const Color(0xFFe91e63)
                                : AppTheme.incomeColor,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${account.bank ?? _getAccountTypeLabel(account.type)} · $transactionCount txns',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Sparkline
              SizedBox(
                width: 72,
                height: 34,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: account.sparkline
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: sparkColor,
                        barWidth: 1.8,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    lineTouchData: const LineTouchData(enabled: false),
                    titlesData: const FlTitlesData(show: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    minY:
                        account.sparkline.reduce((a, b) => a < b ? a : b) * 0.9,
                    maxY:
                        account.sparkline.reduce((a, b) => a > b ? a : b) * 1.1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Balance row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                account.type == AccountType.credit
                    ? 'Outstanding balance'
                    : 'Available balance',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${isNegative ? '−' : ''}${Helpers.formatINR(account.balance.abs())}',
                    style: TextStyle(
                                            fontSize: 18,
                      color: isNegative
                          ? AppTheme.expenseColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: Color(0xFFc0bdb8),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getAccountIcon(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return LucideIcons.building2;
      case AccountType.cash:
        return LucideIcons.wallet;
      case AccountType.credit:
        return LucideIcons.creditCard;
    }
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return 'Savings Account';
      case AccountType.cash:
        return 'Cash';
      case AccountType.credit:
        return 'Credit Card';
    }
  }
}

class _LinkBankButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.primaryColor.withOpacity(0.03),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.link2, size: 15, color: Color(0xFF2a5a2a)),
          const SizedBox(width: 8),
          const Text(
            'Link Bank Account via SMS',
            style: TextStyle(fontSize: 13, color: Color(0xFF2a5a2a)),
          ),
        ],
      ),
    );
  }
}
