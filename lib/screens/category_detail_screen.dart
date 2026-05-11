import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allTransactions = context.watch<TransactionProvider>().transactions;
    final txs = _monthTransactions(allTransactions, _selectedYear, _selectedMonth);
    final totalSpent = txs.fold<double>(0, (sum, t) => sum + t.amount);
    final txCount = txs.length;

    // Previous month comparison
    final prevMonth = _selectedMonth == 1 ? 12 : _selectedMonth - 1;
    final prevYear = _selectedMonth == 1 ? _selectedYear - 1 : _selectedYear;
    final prevTxs = _monthTransactions(allTransactions, prevYear, prevMonth);
    final prevSpent = prevTxs.fold<double>(0, (sum, t) => sum + t.amount);

    // Daily average
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final avgPerDay = daysInMonth > 0 ? totalSpent / daysInMonth : 0.0;

    // VS PREV
    double? vsPercent;
    bool vsMore = false;
    if (prevSpent > 0) {
      vsPercent = ((totalSpent - prevSpent) / prevSpent * 100).abs();
      vsMore = totalSpent > prevSpent;
    }

    // Budget
    final budget = Budget.budgets.cast<Budget?>().firstWhere(
          (b) => b?.categoryId == _category.id,
          orElse: () => null,
        );

    // 6-month trend (last 6 months ending at selected month)
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
      sixMonthAmounts.add(monthTxs.fold<double>(0, (s, t) => s + t.amount));
      sixMonthLabels.add(DateFormat('MMM').format(DateTime(y, m)));
    }

    // Weekly breakdown (Wk 1 = days 1–7, Wk 2 = 8–14, Wk 3 = 15–21, Wk 4 = 22+)
    final weeklyTotals = List.filled(4, 0.0);
    for (final t in txs) {
      final weekIdx = ((t.date.day - 1) ~/ 7).clamp(0, 3);
      weeklyTotals[weekIdx] += t.amount;
    }

    final colorName = _colorName(_category.color);
    final monthLabel =
        DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final dayOfMonth = DateTime.now().day;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          LucideIcons.chevronLeft,
                          size: 22,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      'Category Details',
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    GestureDetector(
                      onTap: _openEdit,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          LucideIcons.pencil,
                          size: 20,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    // Icon + name + color badge
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: _accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: CategoryIconWidget(
                                category: _category,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _category.name,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                              letterSpacing: -0.75,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Color badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  colorName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

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
                            '\$${totalSpent.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 36,
                              color: cs.onSurface,
                              letterSpacing: -0.9,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (budget != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: (totalSpent / budget.budget)
                                    .clamp(0.0, 1.0),
                                backgroundColor: _accentColor.withOpacity(0.15),
                                valueColor:
                                    AlwaysStoppedAnimation(_accentColor),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '\$${totalSpent.toStringAsFixed(0)} of \$${budget.budget.toStringAsFixed(0)} budget',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ] else
                            Text(
                              'No budget set · edit to add one',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
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
                              '\$${avgPerDay.toStringAsFixed(0)}',
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

                    // 6-Month Trend chart
                    _TrendChartCard(
                      amounts: sixMonthAmounts,
                      labels: sixMonthLabels,
                      accentColor: _accentColor,
                    ),

                    const SizedBox(height: 12),

                    // Weekly Breakdown chart
                    _WeeklyChartCard(
                      weeklyTotals: weeklyTotals,
                      accentColor: _accentColor,
                      monthName: DateFormat('MMMM')
                          .format(DateTime(_selectedYear, _selectedMonth)),
                    ),

                    const SizedBox(height: 12),

                    // Transactions list
                    _TransactionsList(
                      transactions: txs,
                      accentColor: _accentColor,
                      count: txCount,
                    ),
                  ],
                ),
              ),
            ),

            // ── Sticky Edit Category button ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: GestureDetector(
                onTap: _openEdit,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.pencil, size: 18, color: Theme.of(context).colorScheme.onPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Category',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

  const _TrendChartCard({
    required this.amounts,
    required this.labels,
    required this.accentColor,
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
                'Low \$${minVal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                'High \$${maxVal.toStringAsFixed(0)}',
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

  const _WeeklyChartCard({
    required this.weeklyTotals,
    required this.accentColor,
    required this.monthName,
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
                    '\$${v.toStringAsFixed(0)}',
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

      // Empty background bar
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, reservedTop, barWidth, chartHeight),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        bgPaint,
      );

      // Filled bar
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

        // Dot indicator on highlighted bar
        if (showDot && isHighlighted) {
          final dotPaint = Paint()
            ..color = accentColor
            ..isAntiAlias = true;
          final dotX = x + barWidth / 2;
          final dotY = top - dotPadding - dotDiameter / 2;
          canvas.drawCircle(Offset(dotX, dotY), dotDiameter / 2, dotPaint);
        }
      }

      // Label below bar
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

// ── Transactions list ─────────────────────────────────────────────────────

class _TransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final Color accentColor;
  final int count;

  const _TransactionsList({
    required this.transactions,
    required this.accentColor,
    required this.count,
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
          // Header
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

          // Rows
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
                        // Day-of-month circle
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
                        // Title + date
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
                        // Amount
                        Text(
                          '−\$${t.amount.toStringAsFixed(0)}',
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
