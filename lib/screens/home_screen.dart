import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../models/ad_config.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/trial_banner.dart';
import '../services/ad_config_service.dart';
import '../screens/layout_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final monthTransactions = Transaction.transactions
        .where(
          (tx) =>
              tx.date.month == widget.selectedMonth.month &&
              tx.date.year == widget.selectedMonth.year,
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
        // TODO: Replace hardcoded values with real subscription state once
        // the subscription service is wired up.
        TrialBanner(
          trialDaysLeft: 30,
          onUpgrade: () {
            // TODO: Navigate to upgrade/subscription screen.
          },
        ),
        const SizedBox(height: 12),
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
                          widget.onMonthChanged?.call(1);
                        } else if (v > 100) {
                          widget.onMonthChanged?.call(-1);
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
                    ValueListenableBuilder<AdConfig>(
                      valueListenable: AdConfigService.instance.config,
                      builder: (_, cfg, child) => cfg.showInlineAd
                          ? Column(
                              children: [
                                _buildInlineAd(),
                                const SizedBox(height: 16),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
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

  // ── Balance Card ──────────────────────────────────────────────────────────

  Widget _buildBalanceCard(
    double totalExpense,
    double budgetPct,
    double totalIncome,
  ) {
    final monthName = Helpers.months[widget.selectedMonth.month - 1];

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
                color: Colors.white.withValues(alpha: 0.04),
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
                color: Colors.white.withValues(alpha: 0.03),
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
                  color: Colors.white.withValues(alpha: 0.45),
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
        widget.selectedMonth.month == now.month &&
        widget.selectedMonth.year == now.year;
    final daysInMonth =
        DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
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
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _InsightChip(data: chips[i]),
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
        color: Colors.white.withValues(alpha: 0.1),
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
            color: Colors.black.withValues(alpha: 0.07),
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

// ── Data class ────────────────────────────────────────────────────────────────

class CategoryData {
  final Category category;
  final double amount;

  CategoryData(this.category, this.amount);
}
