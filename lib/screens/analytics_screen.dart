import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  TimeFilter _timeFilter = TimeFilter.month;

  @override
  Widget build(BuildContext context) {
    // March 2026 data
    final monthTxs = Transaction.transactions
        .where((tx) => tx.date.month == 3 && tx.date.year == 2026)
        .toList();

    final totalExpense = monthTxs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = monthTxs
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final net = totalIncome - totalExpense;

    // Category breakdown
    final categoryBreakdown =
        Helpers.getExpenseCategories()
            .map((category) {
              final amount = monthTxs
                  .where(
                    (t) =>
                        t.type == TransactionType.expense &&
                        t.categoryId == category.id,
                  )
                  .fold(0.0, (sum, t) => sum + t.amount);
              return CategoryAnalytics(category, amount);
            })
            .where((ca) => ca.amount > 0)
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    // Top merchants
    final merchantMap = <String, double>{};
    for (final tx in monthTxs.where((t) => t.type == TransactionType.expense)) {
      merchantMap[tx.transactionTitle] = (merchantMap[tx.transactionTitle] ?? 0) + tx.amount;
    }
    final topMerchants = merchantMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Merchants = topMerchants.take(5).toList();

    // Month-over-month change
    final prevMonth =
        MonthlyData.monthlyData[MonthlyData.monthlyData.length - 2].amount;
    final currMonth =
        MonthlyData.monthlyData[MonthlyData.monthlyData.length - 1].amount;
    final momChange = ((currMonth - prevMonth) / prevMonth) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'March 2026',
              style: const TextStyle(fontSize: 12, color: Color(0xFFaaa)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Time filter
            Row(
              children: TimeFilter.values.map((filter) {
                final isActive = _timeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _timeFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        filter.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive
                              ? Colors.white
                              : AppTheme.onSurfaceColor,
                          letterSpacing: 0.05,
                          fontWeight: isActive
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Summary strip
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Spent',
                    value: Helpers.formatINR(totalExpense),
                    color: AppTheme.expenseColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Earned',
                    value: Helpers.formatINR(totalIncome),
                    color: AppTheme.incomeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Net',
                    value: Helpers.formatINR(net.abs()),
                    color: net >= 0
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Monthly bar chart
            _MonthlyChart(
              monthlyData: MonthlyData.monthlyData,
              momChange: momChange,
            ),

            const SizedBox(height: 16),

            // Category breakdown
            _CategoryBreakdown(
              categories: categoryBreakdown,
              totalExpense: totalExpense,
            ),

            const SizedBox(height: 16),

            // Top merchants
            _TopMerchants(merchants: top5Merchants),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

enum TimeFilter {
  week('Week'),
  month('Month'),
  threeM('3M'),
  year('Year');

  const TimeFilter(this.label);

  final String label;
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTheme.trackingWide.copyWith(
              fontSize: 10,
              letterSpacing: 0.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                            fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<MonthlyData> monthlyData;
  final double momChange;

  const _MonthlyChart({required this.monthlyData, required this.momChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Spending', style: AppTheme.trackingWide),
              Row(
                children: [
                  Transform.rotate(
                    angle: momChange <= 0
                        ? 1.5708
                        : 0, // 90 degrees if negative
                    child: Icon(
                      LucideIcons.arrowUpRight,
                      size: 12,
                      color: momChange > 0
                          ? AppTheme.expenseColor
                          : AppTheme.incomeColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${momChange.abs().toStringAsFixed(1)}% vs last month',
                    style: TextStyle(
                      fontSize: 11,
                      color: momChange > 0
                          ? AppTheme.expenseColor
                          : AppTheme.incomeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = monthlyData[group.x.toInt()];
                      return BarTooltipItem(
                        '',
                        TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                                                  ),
                        children: [
                          TextSpan(
                            text: Helpers.formatINR(month.amount),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                                                          ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
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
                        final index = value.toInt();
                        if (index >= 0 && index < monthlyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              monthlyData[index].month,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: monthlyData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isLast = index == monthlyData.length - 1;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data.amount,
                        color: isLast
                            ? AppTheme.primaryColor
                            : const Color(0xFFdbd7cf),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<CategoryAnalytics> categories;
  final double totalExpense;

  const _CategoryBreakdown({
    required this.categories,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By Category', style: AppTheme.trackingWide),
          const SizedBox(height: 16),
          ...categories.map((category) {
            final pct = totalExpense > 0
                ? (category.amount / totalExpense) * 100
                : 0;
            final budget = Budget.budgets
                .where((b) => b.categoryId == category.category.id)
                .firstOrNull;
            final over = budget != null && category.amount > budget.budget;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CategoryIconWidget(
                            category: category.category,
                            size: 18,
                            color: Color(
                              int.parse(
                                    category.category.color.substring(1),
                                    radix: 16,
                                  ) +
                                  0xFF000000,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category.category.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (budget != null)
                            Text(
                              'of ${Helpers.formatINR(budget.budget)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: over
                                    ? AppTheme.expenseColor
                                    : const Color(0xFFbbb),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            Helpers.formatINR(category.amount),
                            style: const TextStyle(
                                                            fontSize: 13,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: pct / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: over
                              ? AppTheme.expenseColor
                              : Color(
                                  int.parse(
                                        category.category.color.substring(1),
                                        radix: 16,
                                      ) +
                                      0xFF000000,
                                ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  if (budget != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${((category.amount / budget.budget) * 100).round()}% of budget',
                          style: TextStyle(
                            fontSize: 10,
                            color: over
                                ? AppTheme.expenseColor
                                : const Color(0xFFd0cdc8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TopMerchants extends StatelessWidget {
  final List<MapEntry<String, double>> merchants;

  const _TopMerchants({required this.merchants});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Merchants', style: AppTheme.trackingWide),
          const SizedBox(height: 12),
          ...merchants.asMap().entries.map((entry) {
            final index = entry.key;
            final merchant = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      merchant.key,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '−${Helpers.formatINR(merchant.value)}',
                    style: const TextStyle(
                                            fontSize: 12,
                      color: AppTheme.expenseColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class CategoryAnalytics {
  final Category category;
  final double amount;

  CategoryAnalytics(this.category, this.amount);
}
