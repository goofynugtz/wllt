import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../models/ad_config.dart';
import '../data/currencies.dart';
import '../providers/account_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/ad_config_service.dart';
import '../providers/transaction_provider.dart';
import '../services/exchange_rate_service.dart';
import '../utils/helpers.dart';
import 'package:provider/provider.dart';
import 'account_detail_screen.dart';
import 'bank_picker_screen.dart';

Color _bankColor(String? bank) {
  if (bank == null) return AppTheme.primaryColor;
  try {
    return kAllBanks.firstWhere((b) => b.name == bank).brandColor;
  } catch (_) {
    return AppTheme.primaryColor;
  }
}

String _bankInitials(String? bank) {
  if (bank == null) return '??';
  final words = bank.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
  return bank.substring(0, min(2, bank.length)).toUpperCase();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts     = context.watch<AccountProvider>().accounts;
    final transactions = context.watch<TransactionProvider>().transactions;
    final prefs        = context.watch<UserPreferencesProvider>();
    context.watch<ExchangeRateService>();
    // Global display currency (e.g. "USD") — used for net worth and section totals only.
    final displayCurrency = prefs.currency;
    // When true, historical tx amounts are converted using rates at tx date; otherwise raw amounts used.
    final convertHistory  = prefs.convertHistoricalCurrency;

    // Prefetch rates after frame — avoids triggering rebuilds during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final a in accounts) {
        if (a.baseCurrency != displayCurrency) {
          ExchangeRateService.instance.fetchSnapshot(a.baseCurrency, DateTime.now());
        }
      }
    });

    double resolveAmount(Transaction t, String targetCurrency) {
      final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
      return Helpers.convertAmount(t.amount, t.baseCurrency, targetCurrency, snap?.rates);
    }

    // Converts balance + tx delta to displayCurrency; used for net-worth card and ASSETS/DEBT totals.
    double effectiveBalance(Account a) {
      final balanceSnap = ExchangeRateService.instance.getCachedSnapshot(a.baseCurrency, DateTime.now());
      final balanceInDisplay = Helpers.convertAmount(a.balance, a.baseCurrency, displayCurrency, balanceSnap?.rates);
      final txs = transactions.where((t) => t.account == a.id);
      final income  = txs.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + resolveAmount(t, displayCurrency));
      final expense = txs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + resolveAmount(t, displayCurrency));
      return balanceInDisplay + income - expense;
    }

    // Keeps balance in the account's own baseCurrency; shown on the card row so the number matches the account denomination.
    double effectiveBalanceInAccountCurrency(Account a) {
      final txs = transactions.where((t) => t.account == a.id);
      final income  = txs.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + resolveAmount(t, a.baseCurrency));
      final expense = txs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + resolveAmount(t, a.baseCurrency));
      return a.balance + income - expense;
    }

    final assets = accounts.where((a) => effectiveBalance(a) >= 0).toList();
    final debts  = accounts.where((a) => effectiveBalance(a) <  0).toList();
    final totalAssets = assets.fold(0.0, (s, a) => s + effectiveBalance(a));
    final totalDebt   = debts.fold(0.0, (s, a) => s + effectiveBalance(a).abs());
    final netWorth    = totalAssets - totalDebt;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Net worth card
            _NetWorthCard(
              netWorth: netWorth,
              totalAssets: totalAssets,
              totalDebt: totalDebt,
            ),

            const SizedBox(height: 20),

            // ASSETS section
            _SectionHeader(
              label: 'ASSETS',
              total: totalAssets,
              color: const Color(0xFF4DBA7E),
            ),
            const SizedBox(height: 8),
            ...assets.map((a) => _TappableAccountCard(account: a, effectiveBalance: effectiveBalanceInAccountCurrency(a))),

            const SizedBox(height: 16),

            // DEBT section (only if any debts)
            if (debts.isNotEmpty) ...[
              _SectionHeader(
                label: 'DEBT',
                total: totalDebt,
                color: const Color(0xFFE76F51),
              ),
              const SizedBox(height: 8),
              ...debts.map((a) => _TappableAccountCard(account: a, effectiveBalance: effectiveBalanceInAccountCurrency(a))),
              const SizedBox(height: 16),
            ],

            // Inline ad card
            ValueListenableBuilder<AdConfig>(
              valueListenable: AdConfigService.instance.config,
              builder: (_, cfg, __) =>
                  cfg.showInlineAd ? const _InlineAdCard() : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Net worth card ─────────────────────────────────────────────────────────────

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
    final assetPct = totalAssets > 0 ? (totalAssets / (totalAssets + totalDebt)).clamp(0.0, 1.0) : 1.0;
    final prefs = context.watch<UserPreferencesProvider>();
    // Display currency symbol (e.g. "$") — net worth, assets, and debt totals all render in this currency.
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == prefs.currency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment(-0.5, -0.866),
          end: Alignment(0.5, 0.866),
          colors: [Color(0xFF1A1130), Color(0xFF4F378B), Color(0xFF7A65C4)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -32,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                'NET WORTH',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),

              // Amount row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${netWorth >= 0 ? '' : '−'}${Helpers.formatAmount(netWorth.abs(), currencySymbol)}',
                    style: const TextStyle(
                      fontFamily: 'Archia',
                      fontSize: 36,
                      color: Colors.white,
                      letterSpacing: -0.9,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.trendingUp,
                    size: 16,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'across all accounts',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.12), height: 1),
              const SizedBox(height: 14),

              // Assets / Debt / Progress row
              Row(
                children: [
                  // Assets
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ASSETS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Helpers.formatAmount(totalAssets, currencySymbol),
                        style: const TextStyle(
                          fontFamily: 'Archia',
                          fontSize: 16,
                          color: Color(0xFF4DBA7E),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.white.withOpacity(0.12),
                  ),
                  // Debt
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEBT',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Helpers.formatAmount(totalDebt, currencySymbol),
                        style: const TextStyle(
                          fontFamily: 'Archia',
                          fontSize: 16,
                          color: Color(0xFFE76F51),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(assetPct * 100).round()}% assets',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: assetPct,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4DBA7E),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final double total;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          Helpers.formatAmount(total, kCurrencies
              .firstWhere(
                (c) => c.code == context.watch<UserPreferencesProvider>().currency,
                orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'),
              )
              .symbol),
          style: TextStyle(fontFamily: 'Archia', fontSize: 12, color: color),
        ),
      ],
    );
  }
}

// ── Account card ───────────────────────────────────────────────────────────────

class _TappableAccountCard extends StatelessWidget {
  final Account account;
  final double effectiveBalance;
  const _TappableAccountCard({required this.account, required this.effectiveBalance});

  @override
  Widget build(BuildContext context) {
    final isNegative = effectiveBalance < 0;
    final bankColor = _bankColor(account.bank);
    final amountColor = isNegative
        ? const Color(0xFFE76F51)
        : Theme.of(context).colorScheme.onSurface;
    // Account's own currency — balance displayed in the account's denomination, not global display currency.
    final currencyInfo = kCurrencies.firstWhere(
        (c) => c.code == account.baseCurrency,
        orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'));
    final currencySymbol = currencyInfo.symbol;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17.5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(17.5),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AccountDetailScreen(account: account)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colored accent bar
                  Container(
                    width: 3.5,
                    decoration: BoxDecoration(
                      color: bankColor.withOpacity(0.6),
                    ),
                  ),

                // Badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: _BankBadge(account: account, bankColor: bankColor),
                ),

                // Name + meta
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          account.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _CurrencyChip(symbol: currencyInfo.symbol, country: currencyInfo.country),
                      ],
                    ),
                  ),
                ),

                // Balance + chevron
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isNegative ? '−' : ''}${Helpers.formatAmount(effectiveBalance.abs(), currencySymbol)}',
                            style: TextStyle(
                              fontFamily: 'Archia',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: amountColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            account.type == AccountType.credit
                                ? 'Credit'
                                : account.type == AccountType.cash
                                    ? 'Cash'
                                    : 'Savings',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Currency chip ──────────────────────────────────────────────────────────────

class _CurrencyChip extends StatelessWidget {
  final String symbol;
  final String? country;

  const _CurrencyChip({required this.symbol, this.country});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final label = country != null ? '$symbol • $country' : symbol;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: muted.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      ),
    );
  }
}

// ── Bank badge ─────────────────────────────────────────────────────────────────

class _BankBadge extends StatelessWidget {
  final Account account;
  final Color bankColor;

  const _BankBadge({required this.account, required this.bankColor});

  @override
  Widget build(BuildContext context) {
    if (account.type == AccountType.cash) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(LucideIcons.wallet, size: 20, color: AppTheme.primaryColor),
      );
    }

    final hasSvg = account.bankLogoPath != null;

    if (hasSvg) {
      return SizedBox(
        width: 46,
        height: 46,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SvgPicture.asset(account.bankLogoPath!),
        ),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bankColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          _bankInitials(account.bank),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: bankColor,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ── Inline ad card ─────────────────────────────────────────────────────────────

class _InlineAdCard extends StatelessWidget {
  const _InlineAdCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2), width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('📅', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'BillTracker',
                  style: TextStyle(fontSize: 13, color: Color(0xFF10B981)),
                ),
                Text(
                  'Never miss a payment again',
                  style: TextStyle(fontSize: 11, color: Color(0xFF374151)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Get App',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
