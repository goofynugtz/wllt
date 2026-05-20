import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/currencies.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../models/ad_config.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/trial_banner.dart';
import '../widgets/spending_trend_card.dart';
import '../services/ad_config_service.dart';
import '../services/exchange_rate_service.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../screens/layout_screen.dart';
import '../screens/category_breakdown_screen.dart';
import '../providers/app_settings_provider.dart';

enum _TrendRange { m1, m6, y1 }

class HomeScreen extends StatefulWidget {
  final DateTime selectedMonth;
  final void Function(int delta)? onMonthChanged;
  final VoidCallback? onNavigateToHistory;
  final ValueNotifier<bool>? pageScrollEnabled;

  const HomeScreen({
    super.key,
    required this.selectedMonth,
    this.onMonthChanged,
    this.onNavigateToHistory,
    this.pageScrollEnabled,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late AnimationController _snapController;
  _TrendRange _trendRange = _TrendRange.m6;

  String? _prefetchCurrency;
  bool? _prefetchConvert;
  int? _prefetchTxCount;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  static DateTime _addMonths(DateTime d, int n) {
    var m = d.month + n;
    var y = d.year;
    while (m > 12) { m -= 12; y++; }
    while (m < 1)  { m += 12; y--; }
    return DateTime(y, m);
  }

  void _animateTo(double target, double cardWidth) {
    _snapController.stop();
    final start = _dragOffset;
    final anim = Tween<double>(begin: start, end: target)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_snapController);
    late VoidCallback listener;
    listener = () => setState(() => _dragOffset = anim.value);
    _snapController.addListener(listener);
    _snapController.forward(from: 0).then((_) {
      _snapController.removeListener(listener);
      if (target.abs() >= cardWidth * 0.5) {
        final dir = target < 0 ? 1 : -1;
        setState(() => _dragOffset = 0.0);
        widget.onMonthChanged?.call(dir);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allTx = context.watch<TransactionProvider>().transactions;
    context.watch<AppSettingsProvider>(); // rebuild on color/theme changes
    context.watch<ExchangeRateService>(); // rebuild when new rates arrive

    final monthTransactions = allTx
        .where(
          (tx) =>
              tx.date.month == widget.selectedMonth.month &&
              tx.date.year == widget.selectedMonth.year,
        )
        .toList();

    final prefs = context.watch<UserPreferencesProvider>();
    final activeIds = prefs.activeCategories.toSet();
    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;

    if (_prefetchCurrency != displayCurrency ||
        _prefetchConvert != convertHistory ||
        _prefetchTxCount != allTx.length) {
      _prefetchCurrency = displayCurrency;
      _prefetchConvert = convertHistory;
      _prefetchTxCount = allTx.length;
      final txSnapshot = allTx;
      final currencySnapshot = displayCurrency;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ExchangeRateService.instance
            .prefetchForTransactions(txSnapshot, currencySnapshot);
      });
    }

    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == displayCurrency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;

    double resolveAmount(Transaction t) {
      if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
      final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
      return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
    }

    final totalExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + resolveAmount(t));

    final totalIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + resolveAmount(t));

    final budgetPct =
        (totalExpense / Helpers.monthlyBudget * 100).clamp(0.0, 100.0);

    final categoryBreakdown = Helpers.getExpenseCategories(activeIds: activeIds)
        .map((cat) {
          final amount = monthTransactions
              .where(
                (t) =>
                    t.type == TransactionType.expense &&
                    t.categoryId == cat.id,
              )
              .fold(0.0, (sum, t) => sum + resolveAmount(t));
          return CategoryData(cat, amount);
        })
        .where((cd) => cd.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Recent: today and yesterday only, from all transactions
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final allSorted = List<Transaction>.from(allTx)
      ..sort((a, b) => b.date.compareTo(a.date));

    final todayTxns = allSorted.where((tx) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      return d == todayStart;
    }).toList();

    final yesterdayTxns = allSorted.where((tx) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      return d == yesterdayStart;
    }).toList();

    // ── 3-card sliding strip (prev / current / next month) ──────────────────
    final prevMonth = _addMonths(widget.selectedMonth, -1);
    final nextMonth = _addMonths(widget.selectedMonth, 1);

    double monthExpense(DateTime m) => allTx
        .where((t) =>
            t.date.month == m.month &&
            t.date.year == m.year &&
            t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + resolveAmount(t));
    double monthIncome(DateTime m) => allTx
        .where((t) =>
            t.date.month == m.month &&
            t.date.year == m.year &&
            t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + resolveAmount(t));
    double pct(double exp) =>
        (exp / Helpers.monthlyBudget * 100).clamp(0.0, 100.0);

    final prevExp  = monthExpense(prevMonth);
    final nextExp  = monthExpense(nextMonth);
    final prevInc  = monthIncome(prevMonth);
    final nextInc  = monthIncome(nextMonth);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // No horizontal padding here — each section pads itself so the
              // card strip can be truly full-width without escape hacks.
              padding: const EdgeInsets.only(bottom: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Trial banner ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: TrialBanner(
                        trialDaysLeft: 30,
                        onUpgrade: () {},
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 3-card sliding strip ──────────────────────────────────
                    // Stack + Transform: each card lays out at (0,0) so Stack
                    // sizes to one card's height; Transform shifts visually only.
                    // ClipRect hides the off-screen prev/next cards.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) {
                        _snapController.stop();
                        widget.pageScrollEnabled?.value = false;
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() => _dragOffset += details.delta.dx);
                      },
                      onHorizontalDragEnd: (details) {
                        widget.pageScrollEnabled?.value = true;
                        final w = MediaQuery.of(context).size.width;
                        final v = details.primaryVelocity ?? 0;
                        if (v < -300 || _dragOffset < -w * 0.4) {
                          _animateTo(-w, w);
                        } else if (v > 300 || _dragOffset > w * 0.4) {
                          _animateTo(w, w);
                        } else {
                          _animateTo(0, w);
                        }
                      },
                      onHorizontalDragCancel: () {
                        widget.pageScrollEnabled?.value = true;
                        _animateTo(0, MediaQuery.of(context).size.width);
                      },
                      child: LayoutBuilder(builder: (ctx, box) {
                        final w = box.maxWidth;
                        return ClipRect(
                          child: Stack(
                            children: [
                              Transform.translate(
                                offset: Offset(_dragOffset - w, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(prevExp, pct(prevExp), prevInc, currencySymbol, month: prevMonth),
                                )),
                              ),
                              Transform.translate(
                                offset: Offset(_dragOffset, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(totalExpense, budgetPct, totalIncome, currencySymbol),
                                )),
                              ),
                              Transform.translate(
                                offset: Offset(_dragOffset + w, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(nextExp, pct(nextExp), nextInc, currencySymbol, month: nextMonth),
                                )),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // ── Category Breakdown ────────────────────────────────────
                    if (categoryBreakdown.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              pageBuilder: (_, __, ___) => CategoryBreakdownScreen(
                                selectedMonth: widget.selectedMonth,
                              ),
                              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                                child: child,
                              ),
                              transitionDuration: const Duration(milliseconds: 400),
                              reverseTransitionDuration: const Duration(milliseconds: 300),
                            ),
                          ),
                          child: _buildCategoryBreakdown(categoryBreakdown, totalExpense, currencySymbol),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Spending Trend ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSpendingTrendWidget(allTx, currencySymbol),
                    ),
                    const SizedBox(height: 16),

                    // ── Insight chips ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildInsightChips(categoryBreakdown, totalExpense, currencySymbol),
                    ),

                    const SizedBox(height: 16),

                    // ── Inline ad ─────────────────────────────────────────────
                    ValueListenableBuilder<AdConfig>(
                      valueListenable: AdConfigService.instance.config,
                      builder: (_, cfg, child) => cfg.showInlineAd
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: _buildInlineAd(),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // ── Recent transactions ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildRecentTransactions(todayTxns, yesterdayTxns),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Balance Card ──────────────────────────────────────────────────────────

  List<Color> _buildCardGradient(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    return [
      hsl.withLightness(0.08).toColor(),
      hsl.withLightness(0.27).toColor(),
      hsl.withLightness(0.36).toColor(),
    ];
  }



  Widget _buildBalanceCard(
    double totalExpense,
    double budgetPct,
    double totalIncome,
    String currencySymbol, {
    DateTime? month,
  }) {
    final m = month ?? widget.selectedMonth;
    final monthName = Helpers.months[m.month - 1];
    final year = m.year;
    final hasBudget = Helpers.monthlyBudget > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(0.7, -1.0),
          end: const Alignment(-0.3, 1.0),
          colors: _buildCardGradient(context.read<AppSettingsProvider>().colorSeed),
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        // Clip.none so circles aren't pre-clipped to Stack's rectangular
        // bounds — the parent Container's rounded clip handles it cleanly.
        clipBehavior: Clip.none,
        children: [
          // Decorative circles — sized and positioned to match Figma
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 30,
            left: -32,
            child: Container(
              width: 208,
              height: 208,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Card content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month label
                    Text(
                      '$monthName $year · Overview'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Amount
                    Text(
                      Helpers.formatAmount(totalExpense, currencySymbol),
                      style: const TextStyle(
                        fontSize: 38,
                        color: Colors.white,
                        letterSpacing: -0.95,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'total spent this month',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Budget section
                    if (hasBudget) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget ${Helpers.formatAmount(Helpers.monthlyBudget, currencySymbol)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          Text(
                            '${budgetPct.round()}% used',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: budgetPct / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: budgetPct > 85
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No budgets configured',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Edit categories to set monthly budgets',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Wallet icon circle
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.wallet,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Category Breakdown ────────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(
    List<CategoryData> breakdown,
    double totalExpense,
    String currencySymbol,
  ) {
    return _SectionCard(
      title: 'Category Breakdown',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'category-breakdown-pie',
            child: SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 26,
                    sections: breakdown.take(5).map((cd) {
                      return PieChartSectionData(
                        color: Color(
                          int.parse(
                                cd.category.color.substring(1),
                                radix: 16,
                              ) +
                              0xFF000000,
                        ),
                        value: cd.amount,
                        title: '',
                        radius: 26,
                      );
                    }).toList(),
                  ),
                ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: breakdown.take(5).map((cd) {
                final pct = totalExpense > 0
                    ? (cd.amount / totalExpense * 100).round()
                    : 0;
                final color = Color(
                  int.parse(cd.category.color.substring(1), radix: 16) +
                      0xFF000000,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cd.category.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Helpers.formatAmount(cd.amount, currencySymbol),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$pct%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Spending Trend ────────────────────────────────────────────────────────

  Widget _buildSpendingTrendWidget(List<Transaction> allTx, String currencySymbol) {
    final List<({String label, double amount})> bars;

    if (_trendRange == _TrendRange.m1) {
      final daysInMonth = DateTime(
          widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
      bars = List.generate(daysInMonth, (i) {
        final day = i + 1;
        final amount = allTx
            .where((t) =>
                t.type == TransactionType.expense &&
                t.date.year == widget.selectedMonth.year &&
                t.date.month == widget.selectedMonth.month &&
                t.date.day == day)
            .fold(0.0, (s, t) => s + t.amount);
        return (label: '$day', amount: amount);
      });
    } else if (_trendRange == _TrendRange.m6) {
      bars = List.generate(6, (i) {
        var m = widget.selectedMonth.month - 5 + i;
        var y = widget.selectedMonth.year;
        while (m < 1) { m += 12; y--; }
        final amount = allTx
            .where((t) =>
                t.type == TransactionType.expense &&
                t.date.month == m &&
                t.date.year == y)
            .fold(0.0, (s, t) => s + t.amount);
        return (label: Helpers.months[m - 1], amount: amount);
      });
    } else {
      bars = List.generate(12, (i) {
        var m = widget.selectedMonth.month - 11 + i;
        var y = widget.selectedMonth.year;
        while (m < 1) { m += 12; y--; }
        final amount = allTx
            .where((t) =>
                t.type == TransactionType.expense &&
                t.date.month == m &&
                t.date.year == y)
            .fold(0.0, (s, t) => s + t.amount);
        return (label: Helpers.months[m - 1], amount: amount);
      });
    }

    return SpendingTrendCard(
      bars: bars,
      rangeLabels: const ['1M', '6M', '1Y'],
      selectedRangeIndex: _trendRange.index,
      onRangeChanged: (i) => setState(() => _trendRange = _TrendRange.values[i]),
      currencySymbol: currencySymbol,
      labelStep: _trendRange == _TrendRange.m1 ? 7 : 1,
    );
  }

  // ── Insight Chips ─────────────────────────────────────────────────────────

  Widget _buildInsightChips(
    List<CategoryData> breakdown,
    double totalExpense,
    String currencySymbol,
  ) {
    final now = DateTime.now();
    final isCurrentMonth =
        widget.selectedMonth.month == now.month &&
        widget.selectedMonth.year == now.year;
    final daysInMonth =
        DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
    final dayOfMonth = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvg = dayOfMonth > 0 ? totalExpense / dayOfMonth : 0.0;
    final topCategory = breakdown.isNotEmpty ? breakdown.first : null;

    return Row(
      children: [
        Expanded(
          child: _InsightChip(data: _InsightChipData(
            icon: LucideIcons.flame,
            label: 'Top Spender',
            value: topCategory?.category.name ?? '—',
            sub: topCategory != null
                ? '${Helpers.formatAmount(topCategory.amount, currencySymbol)} this month'
                : 'No expenses yet',
          )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InsightChip(data: _InsightChipData(
            icon: LucideIcons.barChart2,
            label: 'Daily Average',
            value: Helpers.formatAmount(dailyAvg, currencySymbol),
            sub: 'per day so far',
          )),
        ),
      ],
    );
  }

  // ── Recent Transactions ───────────────────────────────────────────────────

  Widget _buildRecentTransactions(
    List<Transaction> todayTxns,
    List<Transaction> yesterdayTxns,
  ) {
    final hasAny = todayTxns.isNotEmpty || yesterdayTxns.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent', style: AppTheme.trackingWide),
            TextButton(
              onPressed: widget.onNavigateToHistory,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all →',
                style: TextStyle(fontSize: 12, color: AppTheme.incomeColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        if (!hasAny)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Text(
              'No transactions today or yesterday',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),

        if (todayTxns.isNotEmpty) ...[
          _buildDateGroup('Today', todayTxns),
          const SizedBox(height: 12),
        ],

        if (yesterdayTxns.isNotEmpty)
          _buildDateGroup('Yesterday', yesterdayTxns),
      ],
    );
  }

  // ── Inline Ad Card ────────────────────────────────────────────────────────

  Widget _buildInlineAd() {
    const green = Color(0xFF10B981);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        border: Border.all(color: green.withValues(alpha: 0.13)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // "Ad" label – top right
          Positioned(
            right: 8,
            top: 8,
            child: Text(
              'AD',
              style: TextStyle(
                fontSize: 9,
                color: green.withValues(alpha: 0.6),
                letterSpacing: 0.9,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                // Icon bubble
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text('📅', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BillTracker',
                        style: TextStyle(
                          fontSize: 13,
                          color: green,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        'Never miss a payment again',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Get App button
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Get App',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(LucideIcons.arrowRight, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(String label, List<Transaction> txns) {
    final prefs = context.watch<UserPreferencesProvider>();
    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: AppTheme.trackingWideSecondary,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: txns.asMap().entries.map((entry) {
              final isNotFirst = entry.key > 0;
              final tx = entry.value;
              final category = Helpers.getCategoryById(tx.categoryId);

              final double displayAmount;
              final String displaySymbol;
              if (convertHistory || tx.baseCurrency == displayCurrency) {
                final snap = ExchangeRateService.instance
                    .getCachedSnapshot(tx.baseCurrency, tx.date);
                displayAmount = Helpers.convertAmount(
                    tx.amount, tx.baseCurrency, displayCurrency, snap?.rates);
                displaySymbol = kCurrencies
                    .firstWhere((c) => c.code == displayCurrency,
                        orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
                    .symbol;
              } else {
                displayAmount = tx.amount;
                displaySymbol = kCurrencies
                    .firstWhere((c) => c.code == tx.baseCurrency,
                        orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
                    .symbol;
              }

              return Column(
                children: [
                  if (isNotFirst)
                    Divider(
                      height: 0.5,
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddTransactionPage(
                              method: tx.type == TransactionType.income
                                  ? AddTransactionMethod.income
                                  : AddTransactionMethod.expense,
                              editTransaction: tx,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            // Icon circle
                            CategoryIconBadge(category: category, size: 40),
                            const SizedBox(width: 12),
                            // Title + category
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.transactionTitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFB0ADA8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Amount
                            _AmountBadge(
                              amount: displayAmount,
                              symbol: displaySymbol,
                              isIncome: tx.type == TransactionType.income,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InsightChipData {
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  const _InsightChipData({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });
}

class _InsightChip extends StatelessWidget {
  final _InsightChipData data;

  const _InsightChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with icon
          Row(
            children: [
              Icon(data.icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Value
          Text(
            data.value,
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Sub-label
          Text(
            data.sub,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Amount badge ──────────────────────────────────────────────────────────────

class _AmountBadge extends StatelessWidget {
  final double amount;
  final String symbol;
  final bool isIncome;

  const _AmountBadge({
    required this.amount,
    required this.symbol,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isIncome ? '+' : '−'}${Helpers.formatAmount(amount, symbol)}',
        style: TextStyle(
          fontFamily: 'Archia',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: -0.2,
          color: color,
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class CategoryData {
  final Category category;
  final double amount;

  CategoryData(this.category, this.amount);
}
