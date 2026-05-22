import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/currencies.dart';
import '../models/models.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../screens/transactions_screen.dart';
import '../screens/bank_picker_screen.dart';
import 'add_account_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  String? _prefetchCurrency;
  bool? _prefetchConvert;
  int _prefetchTxCount = -1;

  double _converted(Transaction t, String displayCurrency, bool convertHistory) {
    if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
    final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
    return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<AccountProvider>().accounts
        .firstWhere((a) => a.id == widget.account.id, orElse: () => widget.account);

    final cs     = Theme.of(context).colorScheme;
    final color  = _brandColorFor(live);
    final topPad = MediaQuery.of(context).padding.top;

    final prefs = context.watch<UserPreferencesProvider>();
    context.watch<ExchangeRateService>();
    final displayCurrency = live.baseCurrency;
    final convertHistory  = prefs.convertHistoricalCurrency;

    final transactions = context.watch<TransactionProvider>().transactions
        .where((t) => t.account == live.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (_prefetchCurrency != displayCurrency ||
        _prefetchConvert != convertHistory ||
        _prefetchTxCount != transactions.length) {
      _prefetchCurrency = displayCurrency;
      _prefetchConvert  = convertHistory;
      _prefetchTxCount  = transactions.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ExchangeRateService.instance
            .prefetchForTransactions(transactions, displayCurrency);
      });
    }

    final grouped = Helpers.groupByDate(transactions);

    final txIncome  = transactions.where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + _converted(t, displayCurrency, convertHistory));
    final txExpense = transactions.where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + _converted(t, displayCurrency, convertHistory));
    final effectiveBalance = live.balance + txIncome - txExpense;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeroDelegate(
              account:          live,
              brandColor:       color,
              effectiveBalance: effectiveBalance,
              isNegative:       effectiveBalance < 0,
              topPadding:       topPad,
              onBack: () => Navigator.pop(context),
              onEdit: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddAccountScreen(initialAccount: live),
                  ),
                );
                if (result == 'deleted' && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
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
                    '${transactions.length}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          if (grouped.isEmpty)
            SliverFillRemaining(
              child: Center(
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
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  grouped.entries
                      .map((e) => _buildDayGroup(context, e.key, e.value))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _brandColorFor(Account account) {
    if (account.type == AccountType.cash) return AppTheme.primaryColor;
    try {
      return kAllBanks.firstWhere((b) => b.name == account.bank).brandColor;
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  Widget _buildDayGroup(
      BuildContext context, String dateStr, List<Transaction> txs) {
    final cs             = Theme.of(context).colorScheme;
    final prefs          = context.read<UserPreferencesProvider>();
    final currencyCode   = widget.account.baseCurrency;
    final currencySymbol = getCurrencyByCode(currencyCode).symbol;
    final convertHistory = prefs.convertHistoricalCurrency;
    final dayExpense     = txs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + _converted(t, currencyCode, convertHistory));

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
                Text(Helpers.formatDateLabel(dateStr),
                    style: AppTheme.trackingWideSecondary),
                if (dayExpense > 0)
                  Text(
                    '−${Helpers.formatAmount(dayExpense, currencySymbol)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.expenseColor),
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
                  return TransactionRow(
                      transaction: e.value, isFirst: e.key == 0);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero delegate ─────────────────────────────────────────────────────────────

class _HeroDelegate extends SliverPersistentHeaderDelegate {
  final Account account;
  final Color brandColor;
  final double effectiveBalance;
  final bool isNegative;
  final double topPadding;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  // Layout constants (inner = below topPadding)
  static const double _btnTop      = 12.0;  // button row inner top
  static const double _btnH        = 40.0;  // button row height
  static const double _contentGap  = 20.0;  // gap between buttons and content
  static const double _badgeSize   = 44.0;
  static const double _badgeLeft   = 20.0;
  static const double _nameLeft    = _badgeLeft + _badgeSize + 14.0; // 78
  static const double _contentTop  = _btnTop + _btnH + _contentGap;  // 72
  static const double _innerExp    = 216.0; // expanded inner height
  static const double _innerColl   = 68.0;

  // Collapsed title positioning
  static const double _collNameTop = 15.0;  // name inner top when collapsed
  static const double _collAmtTop  = 33.0;  // amount inner top when collapsed
  static const double _collLeft    = 68.0;  // left=20(btn)+40(btn)+8(gap)

  // Expanded amount positioning
  // inner: contentTop(72) + badgeSize(44) + gap(20) + label(14) + gap(6) = 156
  static const double _expAmtTop   = 156.0;
  static const double _expAmtLeft  = 20.0;

  _HeroDelegate({
    required this.account,
    required this.brandColor,
    required this.effectiveBalance,
    required this.isNegative,
    required this.topPadding,
    required this.onBack,
    required this.onEdit,
  });

  @override double get maxExtent => topPadding + _innerExp;
  @override double get minExtent => topPadding + _innerColl;

  @override
  bool shouldRebuild(_HeroDelegate o) =>
      o.account != account || o.brandColor != brandColor || o.effectiveBalance != effectiveBalance;

  static double _l(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t  = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final cd = _adjustLightness(brandColor, -0.18);

    final currencyCode   = account.baseCurrency;
    final currencySymbol = getCurrencyByCode(currencyCode).symbol;
    final amountStr =
        '${isNegative ? '−' : ''}${Helpers.formatAmount(effectiveBalance.abs(), currencySymbol)}';

    // Animated values
    final nameTop   = _l(_contentTop, _collNameTop, t);
    final nameLeft  = _l(_nameLeft,   _collLeft,    t);
    final nameFSize = _l(18.0,        14.0,         t);

    final amtTop    = _l(_expAmtTop,  _collAmtTop,  t);
    final amtLeft   = _l(_expAmtLeft, _collLeft,    t);
    final amtFSize  = _l(36.0,        12.0,         t);
    final amtLS     = _l(-1.0,         0.0,          t);

    final badgeFade   = (1 - t * 3.0).clamp(0.0, 1.0);
    final labelFade   = (1 - t * 2.5).clamp(0.0, 1.0);
    final circlesFade = (1 - t * 2.0).clamp(0.0, 1.0);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cd, brandColor],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28.0 * (1 - t)),
          bottomRight: Radius.circular(28.0 * (1 - t)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18 * t),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Decorative circles ────────────────────────────────────────────
          Opacity(
            opacity: circlesFade,
            child: Stack(children: [
              Positioned(top: -48, right: -40, child: _circle(160, 0.06)),
              Positioned(bottom: -32, left: -56, child: _circle(200, 0.05)),
            ]),
          ),

          // ── Bank badge (fades out) ─────────────────────────────────────────
          Positioned(
            top:  topPadding + _contentTop,
            left: _badgeLeft,
            child: Opacity(
              opacity: badgeFade,
              child: _HeroBadge(account: account),
            ),
          ),

          // ── Bank subtitle below display name (fades out) ──────────────────
          if (account.bank != null)
            Positioned(
              top:  topPadding + _contentTop + 22, // below name line (~18px + 4 leading)
              left: _nameLeft,
              right: account.cards.isNotEmpty || account.cardIdentifier != null ? 110 : 20,
              child: Opacity(
                opacity: badgeFade,
                child: Text(
                  account.bank!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // ── Card chips (fades out) ────────────────────────────────────────
          if (account.cards.isNotEmpty)
            Positioned(
              top:   topPadding + _contentTop + 8,
              right: 20,
              child: Opacity(
                opacity: badgeFade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: account.cards.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _CardChip(card: c),
                  )).toList(),
                ),
              ),
            )
          else if (account.cardIdentifier != null)
            Positioned(
              top:   topPadding + _contentTop + 10,
              right: 20,
              child: Opacity(
                opacity: badgeFade,
                child: Container(
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
              ),
            ),

          // ── Balance label (fades out) ─────────────────────────────────────
          Positioned(
            top:  topPadding + _contentTop + _badgeSize + _contentGap,
            left: 20,
            child: Opacity(
              opacity: labelFade,
              child: Text(
                account.type == AccountType.credit
                    ? 'OUTSTANDING BALANCE'
                    : 'AVAILABLE BALANCE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),

          // ── Bank name — animates from expanded to collapsed position ───────
          Positioned(
            top:   topPadding + nameTop,
            left:  nameLeft,
            right: 68,
            child: Text(
              account.displayName,
              style: TextStyle(
                fontSize:   nameFSize,
                fontWeight: FontWeight.w600,
                color:      Colors.white,
                letterSpacing: -0.4,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Balance amount — animates from expanded to collapsed position ──
          Positioned(
            top:   topPadding + amtTop,
            left:  amtLeft,
            right: 68,
            child: Text(
              amountStr,
              style: TextStyle(
                fontFamily:    'Archia',
                fontSize:      amtFSize,
                fontWeight:    FontWeight.w600,
                color:         Colors.white,
                letterSpacing: amtLS,
                height:        1.0,
              ),
            ),
          ),

          // ── Back + Edit buttons (fixed) ───────────────────────────────────
          Positioned(
            top:    topPadding + _btnTop,
            left:   20,
            right:  20,
            height: _btnH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeroButton(icon: LucideIcons.arrowLeft, onTap: onBack),
                _HeroButton(icon: LucideIcons.pencil,    onTap: onEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      shape: BoxShape.circle,
    ),
  );
}

// ── Card chip ─────────────────────────────────────────────────────────────────

class _CardChip extends StatelessWidget {
  final CardEntry card;
  const _CardChip({required this.card});

  @override
  Widget build(BuildContext context) {
    final logoPath = _networkLogoPath(card.network);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logoPath != null)
            SvgPicture.asset(logoPath, height: 11, fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))
          else
            Text(card.network,
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(
            '•••• ${card.last4}',
            style: const TextStyle(fontSize: 11, color: Colors.white, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

String? _networkLogoPath(String network) => Helpers.networkLogoPath(network);

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

// ── Hero icon button ──────────────────────────────────────────────────────────

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

    final words    = account.displayName.split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : account.displayName.substring(0, 2).toUpperCase();

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
