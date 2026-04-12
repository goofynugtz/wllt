import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_widget.dart';
import '../widgets/add_expense_sheet.dart';
import '../screens/layout_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final ValueNotifier<bool>? pageScrollEnabled;

  const HomeScreen({
    super.key,
    this.onNavigateToHistory,
    this.pageScrollEnabled,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
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

    final budgetPct =
        (totalExpense / Helpers.monthlyBudget * 100).clamp(0.0, 100.0);

    final categoryBreakdown = Helpers.getExpenseCategories()
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

    // Recent: today and yesterday only, from all transactions
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final allSorted = List<Transaction>.from(Transaction.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final todayTxns = allSorted.where((tx) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      return d == todayStart;
    }).toList();

    final yesterdayTxns = allSorted.where((tx) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      return d == yesterdayStart;
    }).toList();

    final swipeColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildBalanceCard(totalExpense, budgetPct, totalIncome),
      ],
    );

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ConstrainedBox(
                // Forces the column to be at least as tall as the viewport.
                // Subtract vertical padding (12+24=36) so total scrollable
                // height = padding + minHeight = exactly constraints.maxHeight
                // on sparse months — no over-scroll revealing the dark bg.
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) {
                        // Lock PageView so this drag is not stolen
                        widget.pageScrollEnabled?.value = false;
                      },
                      onHorizontalDragEnd: (details) {
                        widget.pageScrollEnabled?.value = true;
                        final v = details.primaryVelocity ?? 0;
                        if (v < -100) {
                          setState(() => _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                            1,
                          ));
                        } else if (v > 100) {
                          setState(() => _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month - 1,
                            1,
                          ));
                        }
                      },
                      onHorizontalDragCancel: () {
                        widget.pageScrollEnabled?.value = true;
                      },
                      child: swipeColumn,
                    ),
                    const SizedBox(height: 16),
                    _buildInsightChips(categoryBreakdown, totalExpense),
                    const SizedBox(height: 16),
                    if (categoryBreakdown.isNotEmpty) ...[
                      _buildSpendingBreakdown(categoryBreakdown, totalExpense),
                      const SizedBox(height: 16),
                    ],
                    _buildRecentTransactions(todayTxns, yesterdayTxns),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final monthLabel =
        '${Helpers.months[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // "Hi Ranjan"
        RichText(
          text: TextSpan(
            style: TextStyle(
                            fontSize: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            children: const [
              TextSpan(
                text: 'Hi ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: 'Ranjan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),

        // Controls: month pill + bell + avatar
        Row(
          children: [
            // Month selector pill
            GestureDetector(
              onTap: () => _showMonthPicker(context),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  monthLabel,
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Bell
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.bell,
                size: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'R',
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

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MonthPickerSheet(
        selected: _selectedMonth,
        onSelected: (m) => setState(() => _selectedMonth = m),
      ),
    );
  }

  // ── Balance Card ──────────────────────────────────────────────────────────

  Widget _buildBalanceCard(
    double totalExpense,
    double budgetPct,
    double totalIncome,
  ) {
    final monthName = Helpers.months[_selectedMonth.month - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.hardEdge,
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
              // Spending label
              Text(
                '$monthName spending'.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.66,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
              const SizedBox(height: 6),

              // Amount
              Text(
                Helpers.formatINR(totalExpense),
                style: const TextStyle(
                  fontSize: 38,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),

              const SizedBox(height: 16),

              // Budget bar
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

              const SizedBox(height: 14),

              // Pill row
              Row(
                children: [
                  _CardPill(
                    icon: LucideIcons.trendingUp,
                    iconColor: AppTheme.successColor,
                    label: '${Helpers.formatINR(totalIncome)} income',
                  ),
                  const SizedBox(width: 8),
                  _CardPill(
                    icon: LucideIcons.trendingDown,
                    iconColor: AppTheme.warningColor,
                    label: '${Helpers.formatINR(totalExpense)} spent',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Insight Chips ─────────────────────────────────────────────────────────

  Widget _buildInsightChips(
    List<CategoryData> breakdown,
    double totalExpense,
  ) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.month == now.month && _selectedMonth.year == now.year;
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final dayOfMonth = isCurrentMonth ? now.day : daysInMonth;
    final daysLeft = isCurrentMonth ? daysInMonth - dayOfMonth : 0;
    final dailyAvg =
        dayOfMonth > 0 ? totalExpense / dayOfMonth : 0.0;
    final topCategory = breakdown.isNotEmpty ? breakdown.first : null;
    final budgetOk = totalExpense <= Helpers.monthlyBudget;

    final chips = <_InsightChipData>[
      if (topCategory != null)
        _InsightChipData(
          icon: LucideIcons.flame,
          label: 'Top Spender',
          value: topCategory.category.name,
          sub: '${Helpers.formatINR(topCategory.amount)} this month',
        ),
      _InsightChipData(
        icon: LucideIcons.shieldCheck,
        label: 'Budget Health',
        value: budgetOk ? 'All on track' : 'Over budget',
        sub: budgetOk ? 'No overspending 🎉' : 'Review spending',
      ),
      if (isCurrentMonth)
        _InsightChipData(
          icon: LucideIcons.calendar,
          label: 'Month Progress',
          value: '${daysLeft}d left',
          sub: 'Day $dayOfMonth of $daysInMonth',
        ),
      _InsightChipData(
        icon: LucideIcons.barChart2,
        label: 'Daily Average',
        value: Helpers.formatINR(dailyAvg),
        sub: 'per day so far',
      ),
    ];

    // Extra height lets box-shadows render without clipping.
    // clipBehavior: none on the ListView so shadows bleed out of list bounds.
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: 5),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _InsightChip(data: chips[i]),
      ),
    );
  }

  // ── Spending Breakdown ────────────────────────────────────────────────────

  Widget _buildSpendingBreakdown(
    List<CategoryData> breakdown,
    double totalExpense,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending Breakdown', style: AppTheme.trackingWide),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Donut chart — outer box 112×112, chart padded inward by 8px
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 22,
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
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'total',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1,
                          ),
                        ),
                        Text(
                          Helpers.formatINR(totalExpense).replaceFirst('₹', ''),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Legend
              Expanded(
                child: Column(
                  children: breakdown.take(5).map((cd) {
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
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
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
        ],
      ),
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

  Widget _buildDateGroup(String label, List<Transaction> txns) {
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
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: txns.asMap().entries.map((entry) {
              final isNotFirst = entry.key > 0;
              final tx = entry.value;
              final category = Helpers.getCategoryById(tx.categoryId);
              final catColor = Color(
                int.parse(category.color.substring(1), radix: 16) + 0xFF000000,
              );
              final catBg = Color(
                int.parse(category.bg.substring(1), radix: 16) + 0xFF000000,
              );

              return Column(
                children: [
                  if (isNotFirst)
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
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
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: catBg,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: CategoryIconWidget(
                                  category: category,
                                  size: 18,
                                  color: catColor,
                                ),
                              ),
                            ),
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
                            Text(
                              '${tx.type == TransactionType.income ? '+' : '−'}${Helpers.formatINR(tx.amount)}',
                              style: TextStyle(
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
      ],
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _CardPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _CardPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
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
      width: 148,
      height: 86,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
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

// ── Month picker bottom sheet ─────────────────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  const _MonthPickerSheet({required this.selected, required this.onSelected});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Year navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '$_year',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _year++),
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Month grid (3 columns × 4 rows)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(12, (i) {
              final m = DateTime(_year, i + 1, 1);
              final isSelected =
                  m.month == widget.selected.month &&
                  m.year == widget.selected.year;
              return GestureDetector(
                onTap: () {
                  widget.onSelected(m);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    Helpers.months[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
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
