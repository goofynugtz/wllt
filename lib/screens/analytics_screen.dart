import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';

class AnalyticsScreen extends StatefulWidget {
  final DateTime selectedMonth;

  const AnalyticsScreen({super.key, required this.selectedMonth});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = widget.selectedMonth.month == now.month &&
        widget.selectedMonth.year == now.year;
    final daysInMonth =
        DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
    final dayOfMonth = isCurrentMonth ? now.day : daysInMonth;

    final monthTxs = Transaction.transactions
        .where(
          (tx) =>
              tx.date.month == widget.selectedMonth.month &&
              tx.date.year == widget.selectedMonth.year,
        )
        .toList();

    final totalExpense = monthTxs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final txCount = monthTxs.length;
    final dailyAvg = dayOfMonth > 0 ? totalExpense / dayOfMonth : 0.0;

    final categoryBreakdown = Helpers.getExpenseCategories()
        .map((cat) {
          final amount = monthTxs
              .where(
                (t) =>
                    t.type == TransactionType.expense &&
                    t.categoryId == cat.id,
              )
              .fold(0.0, (sum, t) => sum + t.amount);
          return CategoryAnalytics(cat, amount);
        })
        .where((ca) => ca.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final catCount = categoryBreakdown.length;
    final topCategory =
        categoryBreakdown.isNotEmpty ? categoryBreakdown.first : null;

    final totalBudget =
        Budget.budgets.fold(0.0, (sum, b) => sum + b.budget);
    final budgetUsedPct = totalBudget > 0
        ? (totalExpense / totalBudget * 100).clamp(0.0, 100.0)
        : null;

    // Month-over-month change using static monthly trend data
    double? momChange;
    if (MonthlyData.monthlyData.length >= 2) {
      final prev =
          MonthlyData.monthlyData[MonthlyData.monthlyData.length - 2].amount;
      final curr =
          MonthlyData.monthlyData[MonthlyData.monthlyData.length - 1].amount;
      if (prev > 0) momChange = ((curr - prev) / prev) * 100;
    }

    // Per-day expense totals for the selected month
    final dailySpots = [
      for (int day = 1; day <= dayOfMonth; day++)
        FlSpot(
          day.toDouble(),
          monthTxs
              .where(
                (t) =>
                    t.type == TransactionType.expense && t.date.day == day,
              )
              .fold(0.0, (sum, t) => sum + t.amount),
        ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsGrid(
                totalExpense: totalExpense,
                budgetUsedPct: budgetUsedPct,
                txCount: txCount,
                catCount: catCount,
                dailyAvg: dailyAvg,
                momChange: momChange,
              ),
              const SizedBox(height: 20),
              _buildSpendingTrend(),
              const SizedBox(height: 20),
              if (categoryBreakdown.isNotEmpty) ...[
                _buildCategoryBreakdown(categoryBreakdown, totalExpense),
                const SizedBox(height: 20),
              ],
              if (dailySpots.isNotEmpty) ...[
                _buildDailySpending(dailySpots),
                const SizedBox(height: 20),
              ],
              _buildInsights(topCategory, totalExpense),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats Grid (2×2) ───────────────────────────────────────────────────────

  Widget _buildStatsGrid({
    required double totalExpense,
    required double? budgetUsedPct,
    required int txCount,
    required int catCount,
    required double dailyAvg,
    required double? momChange,
  }) {
    final momWidget = momChange != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                momChange > 0
                    ? LucideIcons.trendingUp
                    : LucideIcons.trendingDown,
                size: 12,
                color: momChange > 0
                    ? const Color(0xFFF4845F)
                    : AppTheme.incomeColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${momChange.abs().toStringAsFixed(0)}% vs last month',
                style: TextStyle(
                  fontSize: 11,
                  color: momChange > 0
                      ? const Color(0xFFF4845F)
                      : AppTheme.incomeColor,
                ),
              ),
            ],
          )
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _StatCard(
                label: 'Total Spent',
                value: Helpers.formatINR(totalExpense),
                subWidget: momWidget,
              ),
              const SizedBox(height: 12),
              _StatCard(
                label: 'Transactions',
                value: '$txCount',
                subText:
                    '$catCount ${catCount == 1 ? "category" : "categories"}',
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _StatCard(
                label: 'Budget Used',
                value: budgetUsedPct != null
                    ? '${budgetUsedPct.round()}%'
                    : '—',
              ),
              const SizedBox(height: 12),
              _StatCard(
                label: 'Daily Avg',
                value: Helpers.formatINR(dailyAvg),
                subText: 'per day',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Spending Trend (6-month line chart) ─────────────────────────────────────

  Widget _buildSpendingTrend() {
    final data = MonthlyData.monthlyData;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.map((d) => d.amount).reduce((a, b) => a > b ? a : b);

    return _SectionCard(
      title: 'Spending Trend',
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.2,
            barGroups: data.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.amount,
                    color: AppTheme.primaryColor,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        data[i].month,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                  Helpers.formatINR(rod.toY),
                  TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Category Breakdown (moved from HomeScreen) ─────────────────────────────

  Widget _buildCategoryBreakdown(
    List<CategoryAnalytics> breakdown,
    double totalExpense,
  ) {
    return _SectionCard(
      title: 'Category Breakdown',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 26,
                sections: breakdown.take(5).map((ca) {
                  return PieChartSectionData(
                    color: Color(
                      int.parse(
                            ca.category.color.substring(1),
                            radix: 16,
                          ) +
                          0xFF000000,
                    ),
                    value: ca.amount,
                    title: '',
                    radius: 26,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: breakdown.take(5).map((ca) {
                final pct = totalExpense > 0
                    ? (ca.amount / totalExpense * 100).round()
                    : 0;
                final color = Color(
                  int.parse(ca.category.color.substring(1), radix: 16) +
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
                          ca.category.name,
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
                        Helpers.formatINR(ca.amount),
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

  // ── Daily Spending (per-day line chart) ─────────────────────────────────────

  Widget _buildDailySpending(List<FlSpot> spots) {
    final maxY = spots.fold(0.0, (prev, s) => s.y > prev ? s.y : prev);

    return _SectionCard(
      title: 'Daily Spending',
      child: SizedBox(
        height: 90,
        child: BarChart(
          BarChartData(
            maxY: maxY > 0 ? maxY * 1.3 : 100,
            barGroups: spots.map((s) {
              return BarChartGroupData(
                x: s.x.toInt(),
                barRods: [
                  BarChartRodData(
                    toY: s.y,
                    color: AppTheme.primaryColor,
                    width: 5,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              );
            }).toList(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    const weekMarkers = [1, 8, 15, 22, 29];
                    final day = value.toInt();
                    if (!weekMarkers.contains(day)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 8,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Insights ───────────────────────────────────────────────────────────────

  Widget _buildInsights(
    CategoryAnalytics? topCategory,
    double totalExpense,
  ) {
    final insightText = topCategory != null && totalExpense > 0
        ? '${topCategory.category.name} is your top expense at '
            '${(topCategory.amount / totalExpense * 100).round()}% '
            'of total spending.'
        : 'No expense data for this month yet.';

    return _SectionCard(
      titleWidget: Row(
        children: [
          Icon(
            LucideIcons.zap,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          Text(
            'Insights',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.arrowRight,
            size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insightText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;

  const _SectionCard({this.title, this.titleWidget, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget ??
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

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subText;
  final Widget? subWidget;

  const _StatCard({
    required this.label,
    required this.value,
    this.subText,
    this.subWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 96,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.55,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 4),
            Text(
              subText!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (subWidget != null) ...[
            const SizedBox(height: 4),
            subWidget!,
          ],
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class CategoryAnalytics {
  final Category category;
  final double amount;

  CategoryAnalytics(this.category, this.amount);
}
