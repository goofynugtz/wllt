import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedMonth = DateTime(2026, 3, 1); // March 2026

  @override
  Widget build(BuildContext context) {
    // Filter transactions for selected month
    final monthTransactions = Transaction.transactions
        .where(
          (tx) =>
              tx.date.month == _selectedMonth.month &&
              tx.date.year == _selectedMonth.year,
        )
        .toList();

    final totalExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final budgetPct = (totalExpense / Helpers.monthlyBudget * 100).clamp(
      0.0,
      100.0,
    );

    // Category breakdown for donut chart
    final categoryBreakdown =
        Helpers.getExpenseCategories()
            .map((cat) {
              final amount = monthTransactions
                  .where(
                    (t) =>
                        t.type == TransactionType.expense &&
                        t.categoryId == cat.id,
                  )
                  .fold(0.0, (sum, t) => sum + t.amount);
              return CategoryData(cat, amount);
            })
            .where((cd) => cd.amount > 0)
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    // Recent transactions
    final recentTransactions = List<Transaction>.from(monthTransactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = recentTransactions.take(9).toList();
    final grouped = Helpers.groupByDate(recent);

    return SafeArea(
      child: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),

                  const SizedBox(height: 20),

                  // Month selector
                  _buildMonthSelector(),

                  const SizedBox(height: 16),

                  // Balance card
                  _buildBalanceCard(totalExpense, budgetPct, totalIncome),

                  const SizedBox(height: 16),

                  // Spending breakdown
                  if (categoryBreakdown.isNotEmpty)
                    _buildSpendingBreakdown(categoryBreakdown, totalExpense),

                  const SizedBox(height: 16),

                  // Recent transactions
                  _buildRecentTransactions(grouped),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning,',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
            const Text(
              'Arjun',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.bell,
                size: 16,
                color: AppTheme.onSurfaceColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
                1,
              );
            }),
            icon: const Icon(
              LucideIcons.chevronLeft,
              size: 14,
              color: AppTheme.onSurfaceColor,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(
            '${Helpers.months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
                1,
              );
            }),
            icon: const Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: AppTheme.onSurfaceColor,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(
    double totalExpense,
    double budgetPct,
    double totalIncome,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -48,
            right: -48,
            child: Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -32,
            left: -24,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Helpers.months[_selectedMonth.month - 1]} spending',
                style: AppTheme.trackingWide.copyWith(
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Helpers.formatINR(totalExpense),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 38,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),

              const SizedBox(height: 16),

              // Budget bar
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget ${Helpers.formatINR(Helpers.monthlyBudget)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      Text(
                        '${budgetPct.round()}% used',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
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
                ],
              ),

              const SizedBox(height: 12),

              // Pills
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.trendingUp,
                          size: 11,
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${Helpers.formatINR(totalIncome)} income',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.trendingDown,
                          size: 11,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${Helpers.formatINR(totalExpense)} spent',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
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

  Widget _buildSpendingBreakdown(
    List<CategoryData> categoryBreakdown,
    double totalExpense,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending Breakdown', style: AppTheme.trackingWide),
          const SizedBox(height: 12),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 33,
                        sections: categoryBreakdown.take(5).map((cd) {
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
                            radius: 52,
                          );
                        }).toList(),
                      ),
                    ),
                    // Center label
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'total',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary,
                              height: 1,
                            ),
                          ),
                          Text(
                            Helpers.formatINR(totalExpense).substring(1),
                            style: AppTheme.smallMonoTextStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Legend
              Expanded(
                child: Column(
                  children: categoryBreakdown.take(5).map((cd) {
                    final pct = totalExpense > 0
                        ? (cd.amount / totalExpense * 100).round()
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                      cd.category.color.substring(1),
                                      radix: 16,
                                    ) +
                                    0xFF000000,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cd.category.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF555),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('$pct%', style: AppTheme.smallMonoTextStyle),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(Map<String, List<Transaction>> grouped) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent', style: AppTheme.trackingWide),
            TextButton(
              onPressed: () {
                // Navigate to transactions screen
              },
              child: const Text(
                'See all →',
                style: TextStyle(fontSize: 12, color: AppTheme.incomeColor),
              ),
            ),
          ],
        ),

        if (grouped.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: const Center(
              child: Text(
                'No transactions this month',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ),

        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  Helpers.formatDateLabel(entry.key),
                  style: AppTheme.trackingWideSecondary,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: entry.value.asMap().entries.map((txEntry) {
                      final tx = txEntry.value;
                      final category = Helpers.getCategoryById(tx.categoryId);
                      final isNotFirst = txEntry.key > 0;

                      return Column(
                        children: [
                          if (isNotFirst)
                            Divider(
                              height: 1,
                              color: Colors.black.withOpacity(0.05),
                              indent: 16,
                              endIndent: 16,
                            ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Handle transaction tap
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Color(
                                          int.parse(
                                                category.bg.substring(1),
                                                radix: 16,
                                              ) +
                                              0xFF000000,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: CategoryIconWidget(
                                          category: category,
                                          size: 20,
                                          color: Color(
                                            int.parse(
                                                  category.color.substring(1),
                                                  radix: 16,
                                                ) +
                                                0xFF000000,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.transactionTitle,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            category.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${tx.type == TransactionType.income ? '+' : '-'}${Helpers.formatINR(tx.amount)}',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        color: tx.type == TransactionType.income
                                            ? AppTheme.incomeColor
                                            : AppTheme.expenseColor,
                                      ),
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
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }
}

class CategoryData {
  final Category category;
  final double amount;

  CategoryData(this.category, this.amount);
}
