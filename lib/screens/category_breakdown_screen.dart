import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/currencies.dart';
import '../models/models.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/exchange_rate_service.dart';
import '../utils/helpers.dart';
import '../widgets/category_filter_sheet.dart';
import '../widgets/category_icon_badge.dart';
import 'category_detail_screen.dart';

class CategoryBreakdownScreen extends StatefulWidget {
  final DateTime selectedMonth;

  const CategoryBreakdownScreen({super.key, required this.selectedMonth});

  @override
  State<CategoryBreakdownScreen> createState() =>
      _CategoryBreakdownScreenState();
}

class _CategoryBreakdownScreenState extends State<CategoryBreakdownScreen>
    with SingleTickerProviderStateMixin {
  static const double _kItemH = 68.0;

  late int _selectedYear;
  late int _selectedMonth;
  late AnimationController _listAnimController;

  // exit animation state
  final Map<String, _ExitData> _exitItems = {};
  // last known (category, pct, amount, index) per category id — not state
  final Map<String, (Category, double, double, int)> _lastRenderInfo = {};

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.selectedMonth.year;
    _selectedMonth = widget.selectedMonth.month;
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listAnimController.forward();
    });
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
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
    final allTx = context.watch<TransactionProvider>().transactions;
    final prefs = context.watch<UserPreferencesProvider>();
    final activeIds = prefs.activeCategories.toSet();
    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == displayCurrency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;

    double resolveAmount(Transaction t) {
      if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
      final snap = ExchangeRateService.instance
          .getCachedSnapshot(t.baseCurrency, t.date);
      return Helpers.convertAmount(
          t.amount, t.baseCurrency, displayCurrency, snap?.rates);
    }

    final monthTx = allTx.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == _selectedYear &&
        t.date.month == _selectedMonth);

    final breakdown = Helpers.getExpenseCategories(activeIds: activeIds)
        .map((cat) {
          final amount = monthTx
              .where((t) => t.categoryId == cat.id)
              .fold(0.0, (s, t) => s + resolveAmount(t));
          return _CategoryData(cat, amount);
        })
        .where((cd) => cd.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Denominator for percentages: only the shown (active) categories, so
    // hiding a category doesn't leave the rest summing to under 100%.
    final totalExpense = breakdown.fold(0.0, (s, cd) => s + cd.amount);

    final monthLabel = '${Helpers.months[_selectedMonth - 1]} $_selectedYear';

    // ── Exit animation detection ──────────────────────────────────────────
    final currentIds = breakdown.map((cd) => cd.category.id).toSet();

    // Remove exit items that reappeared (rapid month switching)
    final returned = _exitItems.keys.where((id) => currentIds.contains(id)).toList();
    if (returned.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() { for (final id in returned) _exitItems.remove(id); });
      });
    }

    final newlyExiting = <String, _ExitData>{};
    for (final entry in _lastRenderInfo.entries) {
      final id = entry.key;
      if (!currentIds.contains(id) && !_exitItems.containsKey(id)) {
        final (cat, pct, amount, idx) = entry.value;
        newlyExiting[id] = _ExitData(
          category: cat, pct: pct, amount: amount, lastIndex: idx,
          catColor: Color(int.parse(cat.color.substring(1), radix: 16) + 0xFF000000),
        );
      }
    }
    if (newlyExiting.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _exitItems.addAll(newlyExiting));
        Future.delayed(const Duration(milliseconds: 380), () {
          if (!mounted) return;
          setState(() {
            for (final id in newlyExiting.keys) {
              _exitItems.remove(id);
              _lastRenderInfo.remove(id);
            }
          });
        });
      });
    }
    // Update last render info for current items
    for (final entry in breakdown.asMap().entries) {
      final cd = entry.value;
      final pct = totalExpense > 0 ? cd.amount / totalExpense : 0.0;
      _lastRenderInfo[cd.category.id] = (cd.category, pct, cd.amount, entry.key);
    }

    final maxExitSlot = _exitItems.isEmpty
        ? 0
        : _exitItems.values.map((e) => e.lastIndex + 2).reduce(math.max);
    final stackH = math.max(breakdown.length, maxExitSlot) * _kItemH;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: (details) {
          final vx = details.velocity.pixelsPerSecond.dx;
          final vy = details.velocity.pixelsPerSecond.dy;
          if (vx.abs() < 300 || vy.abs() > vx.abs()) return;
          if (vx < 0) _nextMonth(); else _previousMonth();
        },
        child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(LucideIcons.chevronLeft, size: 22),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Spending by Category',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: cs.onSurface),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(LucideIcons.settings, size: 20),
                        onPressed: () => showCategoryFilterSheet(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Hero pie chart header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Hero(
                  tag: 'category-breakdown-pie',
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: breakdown.isEmpty
                        ? PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  color: cs.onSurface.withValues(alpha: 0.08),
                                  value: 1,
                                  title: '',
                                  radius: 32,
                                ),
                              ],
                            ),
                          )
                        : PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: breakdown.take(5).map((cd) {
                                return PieChartSectionData(
                                  color: Color(
                                    int.parse(cd.category.color.substring(1), radix: 16) + 0xFF000000,
                                  ),
                                  value: cd.amount,
                                  title: '',
                                  radius: 32,
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // ── Month navigator ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _previousMonth,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(LucideIcons.chevronLeft,
                            size: 20, color: cs.onSurface),
                      ),
                    ),
                    Text(
                      monthLabel,
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                    ),
                    Opacity(
                      opacity: _isCurrentMonth ? 0.3 : 1.0,
                      child: GestureDetector(
                        onTap: _nextMonth,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(LucideIcons.chevronRight,
                              size: 20, color: cs.onSurface),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Category list ─────────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanEnd: (details) {
                  final vx = details.velocity.pixelsPerSecond.dx;
                  final vy = details.velocity.pixelsPerSecond.dy;
                  if (vx.abs() < 300 || vy.abs() > vx.abs()) return;
                  if (vx < 0) _nextMonth(); else _previousMonth();
                },
                child: breakdown.isEmpty
                  ? Center(
                      child: Text(
                        'No expenses this month',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeInOut,
                          height: stackH,
                          child: Stack(
                            children: [
                            ...breakdown.asMap().entries.map((entry) {
                              final index = entry.key;
                              final cd = entry.value;
                              final pct = totalExpense > 0
                                  ? cd.amount / totalExpense
                                  : 0.0;
                              final catColor = Color(
                                int.parse(cd.category.color.substring(1),
                                        radix: 16) +
                                    0xFF000000,
                              );
                              final startInterval =
                                  (index * 0.12).clamp(0.0, 0.7);
                              final endInterval =
                                  (startInterval + 0.4).clamp(0.0, 1.0);
                              final itemAnim = CurvedAnimation(
                                parent: _listAnimController,
                                curve: Interval(startInterval, endInterval,
                                    curve: Curves.easeOut),
                              );

                              return AnimatedPositioned(
                                key: ValueKey(cd.category.id),
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeInOut,
                                top: index * _kItemH,
                                left: 0,
                                right: 0,
                                height: _kItemH,
                                child: AnimatedBuilder(
                                  animation: itemAnim,
                                  builder: (_, child) => Opacity(
                                    opacity: itemAnim.value,
                                    child: Transform.translate(
                                      offset: Offset(
                                          0, 28 * (1 - itemAnim.value)),
                                      child: child,
                                    ),
                                  ),
                                  child: Container(
                                    decoration: index < breakdown.length - 1
                                        ? BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: cs.outlineVariant
                                                    .withValues(alpha: 0.5),
                                                width: 0.5,
                                              ),
                                            ),
                                          )
                                        : null,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CategoryDetailScreen(
                                              category: cd.category,
                                            ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 14, 16, 14),
                                          child: Row(
                                            children: [
                                              CategoryIconBadge(
                                                  category: cd.category,
                                                  size: 40),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          cd.category.name,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: cs.onSurface,
                                                          ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              Helpers.formatAmount(
                                                                  cd.amount,
                                                                  currencySymbol),
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: cs
                                                                    .onSurface,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            SizedBox(
                                                              width: 32,
                                                              child: Text(
                                                                '${(pct * 100).round()}%',
                                                                textAlign:
                                                                    TextAlign
                                                                        .right,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: cs
                                                                      .onSurfaceVariant,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    TweenAnimationBuilder<
                                                        double>(
                                                      key: ValueKey(
                                                          cd.category.id),
                                                      tween: Tween(
                                                          begin: 0.0,
                                                          end: pct),
                                                      duration: const Duration(
                                                          milliseconds: 900),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      builder: (_, value,
                                                              __) =>
                                                          ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(99),
                                                        child:
                                                            LinearProgressIndicator(
                                                          value: value,
                                                          minHeight: 4,
                                                          backgroundColor:
                                                              catColor.withValues(
                                                                  alpha: 0.15),
                                                          valueColor:
                                                              AlwaysStoppedAnimation(
                                                                  catColor),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                LucideIcons.chevronRight,
                                                size: 16,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            // Exiting items slide down and fade out
                            ..._exitItems.entries.map((e) {
                              final data = e.value;
                              return Positioned(
                                key: ValueKey('exit_${e.key}'),
                                top: data.lastIndex * _kItemH,
                                left: 0,
                                right: 0,
                                height: _kItemH,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeIn,
                                  builder: (_, t, child) => Opacity(
                                    opacity: 1.0 - t,
                                    child: Transform.translate(
                                      offset: Offset(0, t * _kItemH),
                                      child: child,
                                    ),
                                  ),
                                  child: _buildExitRow(data, cs, currencySymbol),
                                ),
                              );
                            }),
                            ],
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildExitRow(_ExitData data, ColorScheme cs, String currencySymbol) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            CategoryIconBadge(category: data.category, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data.category.name,
                          style:
                              TextStyle(fontSize: 13, color: cs.onSurface)),
                      Row(children: [
                        Text(Helpers.formatAmount(data.amount, currencySymbol),
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurface)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${(data.pct * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 10, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: data.pct,
                      minHeight: 4,
                      backgroundColor:
                          data.catColor.withValues(alpha: 0.15),
                      valueColor:
                          AlwaysStoppedAnimation(data.catColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight,
                size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _CategoryData {
  final Category category;
  final double amount;
  _CategoryData(this.category, this.amount);
}

class _ExitData {
  final Category category;
  final double pct;
  final double amount;
  final int lastIndex;
  final Color catColor;

  const _ExitData({
    required this.category,
    required this.pct,
    required this.amount,
    required this.lastIndex,
    required this.catColor,
  });
}
