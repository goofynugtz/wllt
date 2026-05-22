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
import '../widgets/spending_trend_card.dart';
import 'edit_category_screen.dart';
import 'transactions_screen.dart';

// ── Outer shell: Scaffold + PageView over all active categories ───────────────

class CategoryDetailScreen extends StatefulWidget {
  final Category category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<Category>? _categories;
  PageController? _pageController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageController == null) {
      _categories = _buildCategories();
      final idx = _categories!.indexWhere((c) => c.id == widget.category.id);
      _pageController = PageController(initialPage: idx.clamp(0, _categories!.length - 1));
    }
  }

  List<Category> _buildCategories() {
    final prefs = context.read<UserPreferencesProvider>();
    final activeIds = prefs.activeCategories.toSet();
    final customMap = {for (final c in prefs.customCategories) c.id: c};
    final builtinIds = Category.categories.map((c) => c.id).toSet();
    return [
      ...Category.categories
          .where((c) => activeIds.isEmpty || activeIds.contains(c.id))
          .map((c) => customMap[c.id] ?? c),
      ...prefs.customCategories.where((c) => !builtinIds.contains(c.id)),
    ];
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories ?? [widget.category];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageView.builder(
        controller: _pageController,
        itemCount: cats.length,
        itemBuilder: (_, i) => _CategoryDetailPage(category: cats[i]),
      ),
    );
  }
}

enum _BreakdownMode { daily, weekly }

// ── Per-category page ─────────────────────────────────────────────────────────

class _CategoryDetailPage extends StatefulWidget {
  final Category category;

  const _CategoryDetailPage({required this.category});

  @override
  State<_CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<_CategoryDetailPage>
    with SingleTickerProviderStateMixin {
  late Category _category;
  late int _selectedYear;
  late int _selectedMonth;

  String? _prefetchCurrency;
  bool? _prefetchConvert;
  int _prefetchTxCount = -1;

  // Month slide state
  double _dragOffset = 0.0;
  int? _peekYear;
  int? _peekMonth;
  late AnimationController _animCtrl;

  // Breakdown mode state
  _BreakdownMode _breakdownMode = _BreakdownMode.weekly;

  // Trend window state
  int _trendWindowSize = 6;
  late int _trendWindowStart; // abs month = year*12 + (month-1)
  late int _trendHighlightIndex;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final absMonth = _selectedYear * 12 + (_selectedMonth - 1);
    _trendWindowStart = absMonth - (_trendWindowSize - 1);
    _trendHighlightIndex = _trendWindowSize - 1;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
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
      MaterialPageRoute(builder: (_) => EditCategoryScreen(category: _category)),
    ).then((result) {
      if (!mounted) return;
      if (result == 'deleted') {
        Navigator.of(context).pop();
      } else if (result is Category) {
        setState(() => _category = result);
      }
    });
  }

  // ── Month helpers ──────────────────────────────────────────────────────────

  (int, int) _offsetMonth(int year, int month, int delta) {
    final abs = year * 12 + (month - 1) + delta;
    return (abs ~/ 12, (abs % 12) + 1);
  }

  // Mutates trend state — call inside setState
  void _updateTrendWindow() {
    final selectedAbs = _selectedYear * 12 + (_selectedMonth - 1);
    int hiIdx = selectedAbs - _trendWindowStart;
    if (hiIdx < 0) {
      _trendWindowStart = selectedAbs;
      hiIdx = 0;
    } else if (hiIdx >= _trendWindowSize) {
      _trendWindowStart = selectedAbs - (_trendWindowSize - 1);
      hiIdx = _trendWindowSize - 1;
    }
    _trendHighlightIndex = hiIdx;
  }

  void _setTrendWindowSize(int size) {
    setState(() {
      _trendWindowSize = size;
      final selectedAbs = _selectedYear * 12 + (_selectedMonth - 1);
      _trendWindowStart = selectedAbs - (size - 1);
      _trendHighlightIndex = size - 1;
    });
  }

  bool _isFutureMonth(int year, int month) {
    final now = DateTime.now();
    return year > now.year || (year == now.year && month > now.month);
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

  double _converted(Transaction t, String displayCurrency, bool convertHistory) {
    if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
    final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
    return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
  }

  // ── Slide animation ────────────────────────────────────────────────────────

  void _animateTo(double from, double to, {Curve curve = Curves.easeOut, required VoidCallback onDone}) {
    _animCtrl.stop();
    _animCtrl.reset();
    final anim = Tween<double>(begin: from, end: to)
        .animate(CurvedAnimation(parent: _animCtrl, curve: curve));
    void listener() {
      if (mounted) setState(() => _dragOffset = anim.value);
    }
    anim.addListener(listener);
    _animCtrl.forward().then((_) {
      anim.removeListener(listener);
      onDone();
    });
  }

  void _commitPeek() {
    if (!mounted) return;
    setState(() {
      _selectedYear = _peekYear!;
      _selectedMonth = _peekMonth!;
      _dragOffset = 0;
      _peekYear = null;
      _peekMonth = null;
      _updateTrendWindow();
    });
  }

  void _cancelPeek() {
    if (!mounted) return;
    setState(() {
      _dragOffset = 0;
      _peekYear = null;
      _peekMonth = null;
    });
  }

  void _jumpMonth(int direction) {
    final sw = MediaQuery.of(context).size.width;
    final (py, pm) = _offsetMonth(_selectedYear, _selectedMonth, direction);
    if (direction > 0 && _isFutureMonth(py, pm)) return;
    setState(() {
      _peekYear = py;
      _peekMonth = pm;
      _dragOffset = 0;
    });
    _animateTo(0, direction < 0 ? sw : -sw, onDone: _commitPeek);
  }

  // ── Drag callbacks ─────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails _) => _animCtrl.stop();

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragOffset += d.delta.dx;

      if (_dragOffset < 0) {
        // Left drag → next month
        final (py, pm) = _offsetMonth(_selectedYear, _selectedMonth, 1);
        if (_isFutureMonth(py, pm)) {
          // Rubber-band: damp this delta, undo full and re-apply partial
          _dragOffset -= d.delta.dx;
          _dragOffset += d.delta.dx * 0.15;
          _peekYear = null;
          _peekMonth = null;
        } else {
          _peekYear = py;
          _peekMonth = pm;
        }
      } else {
        // Right drag → prev month
        final (py, pm) = _offsetMonth(_selectedYear, _selectedMonth, -1);
        _peekYear = py;
        _peekMonth = pm;
      }
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final sw = MediaQuery.of(context).size.width;
    final vel = d.primaryVelocity ?? 0;
    if (_peekYear != null && (vel.abs() > 400 || _dragOffset.abs() > sw * 0.35)) {
      final end = _dragOffset < 0 ? -sw : sw;
      _animateTo(_dragOffset, end, onDone: _commitPeek);
    } else {
      _animateTo(_dragOffset, 0, curve: Curves.elasticOut, onDone: _cancelPeek);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        ExchangeRateService.instance.prefetchForTransactions(allTransactions, currencyCode);
      });
    }

    final budgetProvider = context.watch<BudgetProvider>();
    final budget = budgetProvider.budgetFor(_category.id);
    final colorName = _colorName(_category.color);

    // Fixed section — based on committed selection, not peek
    final now = DateTime.now();
    final isCurrentMonth = _selectedYear == now.year && _selectedMonth == now.month;
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));

    final trendAmounts = <double>[];
    final trendLabels = <String>[];
    for (int i = 0; i < _trendWindowSize; i++) {
      final abs = _trendWindowStart + i;
      final y = abs ~/ 12;
      final m = (abs % 12) + 1;
      final mTxs = _monthTransactions(allTransactions, y, m);
      trendAmounts.add(mTxs.fold<double>(0, (s, t) => s + _converted(t, currencyCode, convertHistory)));
      trendLabels.add(DateFormat('MMM').format(DateTime(y, m)));
    }

    return CustomScrollView(
      key: PageStorageKey(_category.id),
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

        // ── Fixed: 6-month trend + month picker ──────────────────────────────
        SliverToBoxAdapter(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                SpendingTrendCard(
                  title: 'Trend',
                  bars: List.generate(
                    trendAmounts.length,
                    (i) => (label: trendLabels[i], amount: trendAmounts[i]),
                  ),
                  rangeLabels: const ['3M', '6M', '12M'],
                  selectedRangeIndex: const [3, 6, 12].indexOf(_trendWindowSize),
                  onRangeChanged: (i) => _setTrendWindowSize(const [3, 6, 12][i]),
                  highlightIndex: _trendHighlightIndex,
                  accentColor: _accentColor,
                  currencySymbol: currencySymbol,
                  showMinMax: true,
                  chartHeight: 110,
                ),
                const SizedBox(height: 12),
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _jumpMonth(-1),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(LucideIcons.chevronLeft, size: 20, color: cs.onSurface),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(monthLabel, style: TextStyle(fontSize: 16, color: cs.onSurface)),
                          if (isCurrentMonth)
                            Text(
                              'Day ${now.day} of $daysInMonth · in progress',
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                      Opacity(
                        opacity: isCurrentMonth ? 0.3 : 1.0,
                        child: GestureDetector(
                          onTap: () => _jumpMonth(1),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: Icon(LucideIcons.chevronRight, size: 20, color: cs.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          ),
        ),

        // ── Swipeable: spent so far, mini stats, weekly chart, transactions ──
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final sw = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Current month — slides out
                    Transform.translate(
                      offset: Offset(_dragOffset, 0),
                      child: _buildSwipeableBody(
                        sw: sw,
                        year: _selectedYear,
                        month: _selectedMonth,
                        allTransactions: allTransactions,
                        currencyCode: currencyCode,
                        currencySymbol: currencySymbol,
                        convertHistory: convertHistory,
                        budgetProvider: budgetProvider,
                        budget: budget,
                        cs: cs,
                      ),
                    ),
                    // Peek month — slides in from side
                    if (_peekYear != null)
                      Positioned(
                        left: _dragOffset < 0 ? sw + _dragOffset : -sw + _dragOffset,
                        top: 0,
                        width: sw,
                        child: _buildSwipeableBody(
                          sw: sw,
                          year: _peekYear!,
                          month: _peekMonth!,
                          allTransactions: allTransactions,
                          currencyCode: currencyCode,
                          currencySymbol: currencySymbol,
                          convertHistory: convertHistory,
                          budgetProvider: budgetProvider,
                          budget: budget,
                          cs: cs,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeableBody({
    required double sw,
    required int year,
    required int month,
    required List<Transaction> allTransactions,
    required String currencyCode,
    required String currencySymbol,
    required bool convertHistory,
    required BudgetProvider budgetProvider,
    required Budget? budget,
    required ColorScheme cs,
  }) {
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    final txs = _monthTransactions(allTransactions, year, month);
    final totalSpent = txs.fold<double>(0, (s, t) => s + _converted(t, currencyCode, convertHistory));
    final txCount = txs.length;

    final (prevYear, prevMonth) = _offsetMonth(year, month, -1);
    final prevTxs = _monthTransactions(allTransactions, prevYear, prevMonth);
    final prevSpent = prevTxs.fold<double>(0, (s, t) => s + _converted(t, currencyCode, convertHistory));

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final avgPerDay = daysInMonth > 0 ? totalSpent / daysInMonth : 0.0;

    double? vsPercent;
    bool vsMore = false;
    if (prevSpent > 0) {
      vsPercent = ((totalSpent - prevSpent) / prevSpent * 100).abs();
      vsMore = totalSpent > prevSpent;
    }

    double budgetSpent = 0;
    if (budget != null && isCurrentMonth) {
      if (budget.period == BudgetPeriod.monthly) {
        budgetSpent = totalSpent;
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
            .fold(0.0, (s, t) => s + _converted(t, currencyCode, convertHistory));
      }
    }

    final breakdownBars = _breakdownMode == _BreakdownMode.daily
        ? List.generate(daysInMonth, (i) {
            final day = i + 1;
            final amount = txs
                .where((t) => t.date.day == day)
                .fold(0.0, (s, t) => s + _converted(t, currencyCode, convertHistory));
            return (label: '$day', amount: amount);
          })
        : List.generate(4, (wk) {
            final amount = txs
                .where((t) => ((t.date.day - 1) ~/ 7).clamp(0, 3) == wk)
                .fold(0.0, (s, t) => s + _converted(t, currencyCode, convertHistory));
            return (label: 'Wk ${wk + 1}', amount: amount);
          });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          // Spent so far — tap to manage budget
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
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SPENT SO FAR',
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, letterSpacing: 1.1),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$currencySymbol${totalSpent.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 36, color: cs.onSurface, letterSpacing: -0.9),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              budget != null ? 'Edit Budget' : 'Set Budget?',
                              style: TextStyle(fontSize: 11, color: _accentColor),
                            ),
                            const SizedBox(width: 3),
                            Icon(LucideIcons.chevronRight, size: 10, color: _accentColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (budget != null && isCurrentMonth) ...[
                    const SizedBox(height: 12),
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
                      '$currencySymbol${budgetSpent.toStringAsFixed(0)} of '
                      '$currencySymbol${budget.amount.toStringAsFixed(0)} '
                      '${budget.period == BudgetPeriod.monthly ? 'this month' : 'this week'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: budgetSpent >= budget.amount ? cs.error : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
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
                  valueWidget: Text('$txCount', style: TextStyle(fontSize: 22, color: cs.onSurface)),
                  sub: 'this month',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatCard(
                  label: 'VS PREV',
                  valueWidget: vsPercent != null
                      ? Row(children: [
                          Icon(
                            vsMore ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                            size: 14,
                            color: vsMore ? const Color(0xFFB3261E) : AppTheme.incomeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${vsPercent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 18,
                              color: vsMore ? const Color(0xFFB3261E) : AppTheme.incomeColor,
                            ),
                          ),
                        ])
                      : Text('—', style: TextStyle(fontSize: 18, color: cs.onSurface)),
                  sub: vsPercent != null ? (vsMore ? 'more' : 'less') : 'no data',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatCard(
                  label: 'DAILY',
                  valueWidget: Text(
                    '$currencySymbol${avgPerDay.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 18, color: cs.onSurface),
                  ),
                  sub: 'avg / day',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SpendingTrendCard(
            title: 'Breakdown',
            bars: breakdownBars,
            rangeLabels: const ['Daily', 'Weekly'],
            selectedRangeIndex: _breakdownMode.index,
            onRangeChanged: (i) =>
                setState(() => _breakdownMode = _BreakdownMode.values[i]),
            accentColor: _accentColor,
            currencySymbol: currencySymbol,
            labelStep: _breakdownMode == _BreakdownMode.daily ? 7 : 1,
            chartHeight: 90,
          ),

          const SizedBox(height: 12),

          _TransactionsList(transactions: txs),
        ],
      ),
    );
  }

  String _colorName(String hex) {
    const names = {
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

    final cd = _darken(accentColor);
    final contentTop = _btnTop + _btnH + _contentGap;

    // Sliding name: no fade — slides from expanded position (below icon, centered)
    // to collapsed position (top-left, after back button).
    final expandedNameTop = topPadding + contentTop + _iconSize + 8.0;
    final collapsedNameTop = topPadding + _btnTop + (_btnH - 16.0) / 2.0;
    final nameTop = expandedNameTop + (collapsedNameTop - expandedNameTop) * t;
    final nameFontSize = 20.0 - 4.0 * t; // 20 → 16

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
          Opacity(
            opacity: iconFade,
            child: Stack(children: [
              Positioned(top: -40, right: -30, child: _circle(140, 0.06)),
              Positioned(bottom: -20, left: -50, child: _circle(180, 0.05)),
            ]),
          ),

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
                  const SizedBox(height: 38),
                  Opacity(
                    opacity: badgeFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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

          // Category name slides from expanded (below icon, centered) to
          // collapsed (top-left, after back button). No fade — always visible.
          Positioned(
            top:   nameTop,
            left:  0,
            right: 0,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: 64.0 * t),
              child: Align(
                alignment: AlignmentDirectional(-t, 0.0),
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: -0.5 * (1.0 - t),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

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
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, letterSpacing: 0.25)),
          const SizedBox(height: 6),
          valueWidget,
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
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
      text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '',
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
        left: 24, right: 24, top: 24,
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<BudgetPeriod>(
            segments: const [
              ButtonSegment(value: BudgetPeriod.monthly, label: Text('Monthly')),
              ButtonSegment(value: BudgetPeriod.weekly,  label: Text('Weekly')),
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

  const _TransactionsList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transactions', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('${transactions.length} total',
                        style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No transactions this month',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              )
            else
              ...transactions.asMap().entries.map((entry) => TransactionRow(
                    transaction: entry.value,
                    isFirst: entry.key == 0,
                  )),
          ],
        ),
      ),
    );
  }
}
