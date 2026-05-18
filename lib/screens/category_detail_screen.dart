import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/currencies.dart';
import '../models/models.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_widget.dart';
import 'edit_category_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final Category category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late Category _category;
  late int _selectedYear;
  late int _selectedMonth;

  String? _prefetchCurrency;
  bool? _prefetchConvert;
  int _prefetchTxCount = -1;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  Color get _accentColor {
    try {
      return Color(int.parse(_category.color.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF6750A4);
    }
  }

  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCategoryScreen(category: _category),
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == 'deleted') {
        Navigator.of(context).pop();
      } else if (result is Category) {
        setState(() => _category = result);
      }
    });
  }

  List<Transaction> _monthTransactions(List<Transaction> all, int year, int month) {
    return all
        .where((t) =>
            t.categoryId == _category.id &&
            t.date.year == year &&
            t.date.month == month &&
            t.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedYear < now.year ||
        (_selectedYear == now.year && _selectedMonth < now.month)) {
      setState(() {
        if (_selectedMonth == 12) {
          _selectedMonth = 1;
          _selectedYear++;
        } else {
          _selectedMonth++;
        }
      });
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  double _converted(Transaction t, String displayCurrency, bool convertHistory) {
    if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
    final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
    return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top;
    final prefs = context.watch<UserPreferencesProvider>();
    context.watch<ExchangeRateService>();

    final currencyCode = prefs.currency;
    final currencySymbol = getCurrencyByCode(currencyCode).symbol;
    final convertHistory = prefs.convertHistoricalCurrency;

    final allTransactions = context.watch<TransactionProvider>().transactions;

    if (_prefetchCurrency != currencyCode ||
        _prefetchConvert != convertHistory ||
        _prefetchTxCount != allTransactions.length) {
      _prefetchCurrency = currencyCode;
      _prefetchConvert = convertHistory;
      _prefetchTxCount = allTransactions.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ExchangeRateService.instance
            .prefetchForTransactions(allTransactions, currencyCode);
      });
    }

    final txs = _monthTransactions(allTransactions, _selectedYear, _selectedMonth);
    final totalSpent = txs.fold<double>(0, (sum, t) => sum + _converted(t, currencyCode, convertHistory));
    final txCount = txs.length;

    final prevMonth = _selectedMonth == 1 ? 12 : _selectedMonth - 1;
    final prevYear = _selectedMonth == 1 ? _selectedYear - 1 : _selectedYear;
    final prevTxs = _monthTransactions(allTransactions, prevYear, prevMonth);
    final prevSpent = prevTxs.fold<double>(0, (sum, t) => sum + _converted(t, currencyCode, convertHistory));

    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final avgPerDay = daysInMonth > 0 ? totalSpent / daysInMonth : 0.0;

    double? vsPercent;
    bool vsMore = false;
    if (prevSpent > 0) {
      vsPercent = ((totalSpent - prevSpent) / prevSpent * 100).abs();
      vsMore = totalSpent > prevSpent;
    }

    final budgetProvider = context.watch<BudgetProvider>();
    final budget = budgetProvider.budgetFor(_category.id);

    double budgetSpent = 0;
    if (budget != null) {
      final now = DateTime.now();
      if (budget.period == BudgetPeriod.monthly) {
        final currentMonthTxs = _monthTransactions(allTransactions, now.year, now.month);
        budgetSpent = currentMonthTxs.fold(
          0.0,
          (sum, t) => sum + _converted(t, currencyCode, convertHistory),
        );
      } else {
        final weekStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        budgetSpent = allTransactions
            .where((t) =>
                t.categoryId == _category.id &&
                t.type == TransactionType.expense &&
                !t.date.isBefore(weekStart) &&
                t.date.isBefore(weekEnd))
            .fold(0.0, (sum, t) => sum + _converted(t, currencyCode, convertHistory));
      }
    }

    final sixMonthAmounts = <double>[];
    final sixMonthLabels = <String>[];
    for (int i = 0; i < 6; i++) {
      final offset = 5 - i;
      var m = _selectedMonth - offset;
      var y = _selectedYear;
      while (m <= 0) {
        m += 12;
        y--;
      }
      final monthTxs = _monthTransactions(allTransactions, y, m);
      sixMonthAmounts.add(monthTxs.fold<double>(0, (s, t) => s + _converted(t, currencyCode, convertHistory)));
      sixMonthLabels.add(DateFormat('MMM').format(DateTime(y, m)));
    }

    final weeklyTotals = List.filled(4, 0.0);
    for (final t in txs) {
      final weekIdx = ((t.date.day - 1) ~/ 7).clamp(0, 3);
      weeklyTotals[weekIdx] += _converted(t, currencyCode, convertHistory);
    }

    final colorName = _colorName(_category.color);
    final monthLabel =
        DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final dayOfMonth = DateTime.now().day;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryHeroDelegate(
              category: _category,
              accentColor: _accentColor,
              colorName: colorName,
              topPadding: topPad,
              onBack: () => Navigator.of(context).pop(),
              onEdit: _openEdit,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  // Month navigator
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _previousMonth,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: Icon(
                              LucideIcons.chevronLeft,
                              size: 20,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              monthLabel,
                              style: TextStyle(
                                fontSize: 16,
                                color: cs.onSurface,
                              ),
                            ),
                            if (_isCurrentMonth)
                              Text(
                                'Day $dayOfMonth of $daysInMonth · in progress',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        Opacity(
                          opacity: _isCurrentMonth ? 0.3 : 1.0,
                          child: GestureDetector(
                            onTap: _nextMonth,
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.chevronRight,
                                size: 20,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Spent so far card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SPENT SO FAR',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currencySymbol${totalSpent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 36,
                            color: cs.onSurface,
                            letterSpacing: -0.9,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (budget != null && _isCurrentMonth) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (budgetSpent / budget.amount).clamp(0.0, 1.0),
                              backgroundColor: _accentColor.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(
                                budgetSpent >= budget.amount ? cs.error : _accentColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$currencySymbol${budgetSpent.toStringAsFixed(0)} of $currencySymbol${budget.amount.toStringAsFixed(0)} ${budget.period == BudgetPeriod.monthly ? 'this month' : 'this week'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: budgetSpent >= budget.amount
                                  ? cs.error
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Budget chip
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => _BudgetBottomSheet(
                        category: _category,
                        existing: budget,
                        budgetProvider: budgetProvider,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: budget != null
                            ? _accentColor.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: budget != null ? _accentColor : cs.outlineVariant,
                        ),
                      ),
                      child: Text(
                        budget != null
                            ? '$currencySymbol${budget.amount.toStringAsFixed(0)} / ${budget.period == BudgetPeriod.monthly ? 'month' : 'week'}'
                            : '+ Set budget',
                        style: TextStyle(
                          fontSize: 13,
                          color: budget != null ? _accentColor : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3 mini stat cards
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          label: 'TXNS',
                          valueWidget: Text(
                            '$txCount',
                            style: TextStyle(
                              fontSize: 22,
                              color: cs.onSurface,
                            ),
                          ),
                          sub: 'this month',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          label: 'VS PREV',
                          valueWidget: vsPercent != null
                              ? Row(
                                  children: [
                                    Icon(
                                      vsMore
                                          ? LucideIcons.trendingUp
                                          : LucideIcons.trendingDown,
                                      size: 14,
                                      color: vsMore
                                          ? const Color(0xFFB3261E)
                                          : AppTheme.incomeColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${vsPercent.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: vsMore
                                            ? const Color(0xFFB3261E)
                                            : AppTheme.incomeColor,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  '—',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: cs.onSurface,
                                  ),
                                ),
                          sub: vsPercent != null
                              ? (vsMore ? 'more' : 'less')
                              : 'no data',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          label: 'DAILY',
                          valueWidget: Text(
                            '$currencySymbol${avgPerDay.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              color: cs.onSurface,
                            ),
                          ),
                          sub: 'avg / day',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _TrendChartCard(
                    amounts: sixMonthAmounts,
                    labels: sixMonthLabels,
                    accentColor: _accentColor,
                    currencySymbol: currencySymbol,
                  ),

                  const SizedBox(height: 12),

                  _WeeklyChartCard(
                    weeklyTotals: weeklyTotals,
                    accentColor: _accentColor,
                    monthName: DateFormat('MMMM')
                        .format(DateTime(_selectedYear, _selectedMonth)),
                    currencySymbol: currencySymbol,
                  ),

                  const SizedBox(height: 12),

                  _TransactionsList(
                    transactions: txs,
                    accentColor: _accentColor,
                    count: txCount,
                    currencySymbol: currencySymbol,
                    displayCurrency: currencyCode,
                    convertHistory: convertHistory,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _colorName(String hex) {
    final Map<String, String> names = {
      '#EBA9A9': 'Soft Rose',
      '#E2B932': 'Amber',
      '#74A1DB': 'Cornflower Blue',
      '#9D85E5': 'Lavender',
      '#70C01F': 'Lime Green',
      '#86D9BC': 'Mint',
      '#8FC9E2': 'Sky Blue',
      '#F4A261': 'Sandy Orange',
      '#E76F51': 'Burnt Sienna',
      '#2A9D8F': 'Teal',
      '#FFB703': 'Golden Yellow',
      '#C77FFF': 'Violet',
      '#06D6A0': 'Emerald',
      '#FB8500': 'Orange',
      '#FF6B6B': 'Coral',
      '#4CC9F0': 'Cyan',
      '#A8DADC': 'Powder Blue',
      '#E63946': 'Crimson',
    };
    return names[hex.toUpperCase()] ?? names[hex] ?? 'Custom Color';
  }
}

// ── Category Hero Delegate ─────────────────────────────────────────────────

class _CategoryHeroDelegate extends SliverPersistentHeaderDelegate {
  final Category category;
  final Color accentColor;
  final String colorName;
  final double topPadding;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  static const double _btnTop     = 12.0;
  static const double _btnH       = 40.0;
  static const double _contentGap = 16.0;
  static const double _iconSize   = 68.0;
  static const double _innerExp   = 206.0;
  static const double _innerColl  = 64.0;

  _CategoryHeroDelegate({
    required this.category,
    required this.accentColor,
    required this.colorName,
    required this.topPadding,
    required this.onBack,
    required this.onEdit,
  });

  @override double get maxExtent => topPadding + _innerExp;
  @override double get minExtent => topPadding + _innerColl;

  @override
  bool shouldRebuild(_CategoryHeroDelegate old) =>
      old.category != category || old.accentColor != accentColor;

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    final iconFade  = (1.0 - t * 1.6).clamp(0.0, 1.0);
    final badgeFade = (1.0 - t * 2.5).clamp(0.0, 1.0);
    final titleFade = ((t - 0.4) / 0.6).clamp(0.0, 1.0);

    final cd = _darken(accentColor);
    final contentTop = _btnTop + _btnH + _contentGap;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cd, accentColor],
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
          // ── Decorative circles ────────────────────────────────────────
          Opacity(
            opacity: iconFade,
            child: Stack(children: [
              Positioned(top: -40, right: -30, child: _circle(140, 0.06)),
              Positioned(bottom: -20, left: -50, child: _circle(180, 0.05)),
            ]),
          ),

          // ── Icon + name + badge (fades out on scroll) ─────────────────
          Positioned(
            top:   topPadding + contentTop,
            left:  0,
            right: 0,
            child: Opacity(
              opacity: iconFade,
              child: Column(
                children: [
                  Container(
                    width:  _iconSize,
                    height: _iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CategoryIconWidget(
                        category: category,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Opacity(
                    opacity: badgeFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width:  6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            colorName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Category name in collapsed bar (fades in on scroll) ───────
          Positioned(
            top:    topPadding + _btnTop,
            left:   60,
            right:  60,
            height: _btnH,
            child: Opacity(
              opacity: titleFade,
              child: Center(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // ── Back + Edit buttons (always visible) ──────────────────────
          Positioned(
            top:    topPadding + _btnTop,
            left:   16,
            right:  16,
            height: _btnH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeroBtn(icon: LucideIcons.arrowLeft, onTap: onBack),
                _HeroBtn(icon: LucideIcons.pencil,    onTap: onEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      );
}

class _HeroBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ── Mini stat card ─────────────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String label;
  final Widget valueWidget;
  final String sub;

  const _MiniStatCard({
    required this.label,
    required this.valueWidget,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 6),
          valueWidget,
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 6-Month Trend card ────────────────────────────────────────────────────

class _TrendChartCard extends StatelessWidget {
  final List<double> amounts;
  final List<String> labels;
  final Color accentColor;
  final String currencySymbol;

  const _TrendChartCard({
    required this.amounts,
    required this.labels,
    required this.accentColor,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxVal = amounts.isEmpty ? 0.0 : amounts.reduce(max);
    final positives = amounts.where((a) => a > 0);
    final minVal = positives.isEmpty ? 0.0 : positives.reduce(min);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '6-Month Trend',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'Tap bar to navigate',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _BarChartPainter(
                values: amounts,
                labels: labels,
                highlightIndex: amounts.length - 1,
                accentColor: accentColor,
                showDot: true,
                labelColor: cs.onSurface,
                labelDimColor: cs.onSurfaceVariant,
                barBgColor: cs.surfaceContainerHighest,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Low $currencySymbol${minVal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                'High $currencySymbol${maxVal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Weekly Breakdown card ─────────────────────────────────────────────────

class _WeeklyChartCard extends StatelessWidget {
  final List<double> weeklyTotals;
  final Color accentColor;
  final String monthName;
  final String currencySymbol;

  const _WeeklyChartCard({
    required this.weeklyTotals,
    required this.accentColor,
    required this.monthName,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Breakdown',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface,
                ),
              ),
              Text(
                monthName,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: _BarChartPainter(
                values: weeklyTotals,
                labels: const ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'],
                highlightIndex: -1,
                accentColor: accentColor,
                showDot: false,
                labelColor: cs.onSurface,
                labelDimColor: cs.onSurfaceVariant,
                barBgColor: cs.surfaceContainerHighest,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weeklyTotals
                .map(
                  (v) => Text(
                    '$currencySymbol${v.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Shared bar chart painter ──────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final int highlightIndex;
  final Color accentColor;
  final bool showDot;
  final Color labelColor;
  final Color labelDimColor;
  final Color barBgColor;

  const _BarChartPainter({
    required this.values,
    required this.labels,
    required this.highlightIndex,
    required this.accentColor,
    required this.showDot,
    required this.labelColor,
    required this.labelDimColor,
    required this.barBgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.reduce(max);
    const labelHeight = 18.0;
    const dotDiameter = 6.0;
    const dotPadding = 5.0;
    final reservedTop = showDot ? dotDiameter + dotPadding : 0.0;
    final chartHeight = size.height - labelHeight - reservedTop;

    const barGap = 8.0;
    final totalGap = barGap * (values.length - 1);
    final barWidth = (size.width - totalGap) / values.length;

    final bgPaint = Paint()
      ..color = barBgColor
      ..isAntiAlias = true;
    final barPaint = Paint()..isAntiAlias = true;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < values.length; i++) {
      final x = i * (barWidth + barGap);
      final isHighlighted = i == highlightIndex;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, reservedTop, barWidth, chartHeight),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        bgPaint,
      );

      if (maxVal > 0 && values[i] > 0) {
        final fillHeight = (values[i] / maxVal) * chartHeight;
        final top = reservedTop + (chartHeight - fillHeight);
        barPaint.color = isHighlighted
            ? accentColor
            : accentColor.withOpacity(0.45);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, top, barWidth, fillHeight),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6),
          ),
          barPaint,
        );

        if (showDot && isHighlighted) {
          final dotPaint = Paint()
            ..color = accentColor
            ..isAntiAlias = true;
          final dotX = x + barWidth / 2;
          final dotY = top - dotPadding - dotDiameter / 2;
          canvas.drawCircle(Offset(dotX, dotY), dotDiameter / 2, dotPaint);
        }
      }

      textPainter.text = TextSpan(
        text: i < labels.length ? labels[i] : '',
        style: TextStyle(
          fontSize: 10,
          color: isHighlighted ? labelColor : labelDimColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + barWidth / 2 - textPainter.width / 2,
          size.height - labelHeight + 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.values != values ||
      old.highlightIndex != highlightIndex ||
      old.accentColor != accentColor ||
      old.labelColor != labelColor ||
      old.barBgColor != barBgColor;
}

// ── Budget Bottom Sheet ────────────────────────────────────────────────────

class _BudgetBottomSheet extends StatefulWidget {
  final Category category;
  final Budget? existing;
  final BudgetProvider budgetProvider;

  const _BudgetBottomSheet({
    required this.category,
    required this.existing,
    required this.budgetProvider,
  });

  @override
  State<_BudgetBottomSheet> createState() => _BudgetBottomSheetState();
}

class _BudgetBottomSheetState extends State<_BudgetBottomSheet> {
  late final TextEditingController _amountCtrl;
  late BudgetPeriod _period;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.amount.toStringAsFixed(0)
          : '',
    );
    _period = widget.existing?.period ?? BudgetPeriod.monthly;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final v = double.tryParse(_amountCtrl.text);
    return v != null && v > 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null ? 'Edit Budget' : 'Set Budget',
            style: TextStyle(fontSize: 18, color: cs.onSurface),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Limit amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<BudgetPeriod>(
            segments: const [
              ButtonSegment(
                value: BudgetPeriod.monthly,
                label: Text('Monthly'),
              ),
              ButtonSegment(
                value: BudgetPeriod.weekly,
                label: Text('Weekly'),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave
                  ? () {
                      FocusScope.of(context).unfocus();
                      widget.budgetProvider.setBudget(Budget(
                        categoryId: widget.category.id,
                        amount: double.parse(_amountCtrl.text),
                        period: _period,
                      ));
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('Save'),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  widget.budgetProvider.deleteBudget(widget.category.id);
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: cs.error),
                child: const Text('Remove budget'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Transactions list ─────────────────────────────────────────────────────

class _TransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final Color accentColor;
  final int count;
  final String currencySymbol;
  final String displayCurrency;
  final bool convertHistory;

  const _TransactionsList({
    required this.transactions,
    required this.accentColor,
    required this.count,
    required this.currencySymbol,
    required this.displayCurrency,
    required this.convertHistory,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count total',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),

          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No transactions this month',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            ...transactions.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              final isLast = i == transactions.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.13),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${t.date.day}',
                            style: TextStyle(
                              fontSize: 13,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.transactionTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM d, yyyy').format(t.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          () {
                            final snap = ExchangeRateService.instance
                                .getCachedSnapshot(t.baseCurrency, t.date);
                            final amt = (convertHistory || t.baseCurrency == displayCurrency)
                                ? Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates)
                                : t.amount;
                            return '−$currencySymbol${amt.toStringAsFixed(0)}';
                          }(),
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, color: cs.outlineVariant),
                ],
              );
            }),
        ],
      ),
    );
  }
}
