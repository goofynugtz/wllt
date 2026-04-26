import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../models/ad_config.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/trial_banner.dart';
import '../services/ad_config_service.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../screens/layout_screen.dart';
import '../providers/app_settings_provider.dart';

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

    final monthTransactions = allTx
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

    final activeIds = context.watch<UserPreferencesProvider>().activeCategories.toSet();
    final categoryBreakdown = Helpers.getExpenseCategories(activeIds: activeIds)
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
        .fold(0.0, (s, t) => s + t.amount);
    double monthIncome(DateTime m) => allTx
        .where((t) =>
            t.date.month == m.month &&
            t.date.year == m.year &&
            t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
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
                                  child: _buildBalanceCard(prevExp, pct(prevExp), prevInc, month: prevMonth),
                                )),
                              ),
                              Transform.translate(
                                offset: Offset(_dragOffset, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(totalExpense, budgetPct, totalIncome),
                                )),
                              ),
                              Transform.translate(
                                offset: Offset(_dragOffset + w, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(nextExp, pct(nextExp), nextInc, month: nextMonth),
                                )),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // ── Insight chips ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildInsightChips(categoryBreakdown, totalExpense),
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
    double totalIncome, {
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
                      Helpers.formatINR(totalExpense),
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
                            'Budget ${Helpers.formatINR(Helpers.monthlyBudget)}',
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
                              amount: tx.amount,
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

// ── Amount badge ──────────────────────────────────────────────────────────────

class _AmountBadge extends StatelessWidget {
  final double amount;
  final bool isIncome;

  const _AmountBadge({required this.amount, required this.isIncome});

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
        '${isIncome ? '+' : '−'}${Helpers.formatINR(amount)}',
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
