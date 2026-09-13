import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/currencies.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../models/ad_config.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/category_filter_sheet.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/trial_banner.dart';
import '../widgets/spending_trend_card.dart';
import '../widgets/suggested_actions_card.dart';
import '../services/ad_config_service.dart';
import '../services/exchange_rate_service.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../screens/layout_screen.dart';
import '../screens/category_breakdown_screen.dart';
import '../screens/insight_chat_screen.dart';
import '../providers/app_settings_provider.dart';
import '../ai/insight_adapter.dart';
import '../ai/insight_facts.dart';
import '../ai/summary_adapter.dart';
import '../providers/ai_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/insight_card.dart';
import '../services/ai_service.dart';
import '../services/insight_service.dart';

enum _TrendRange { m1, m6, y1 }

class HomeScreen extends StatefulWidget {
  final DateTime selectedMonth;
  final void Function(int delta)? onMonthChanged;
  final VoidCallback? onNavigateToHistory;
  final ValueNotifier<bool>? pageScrollEnabled;
  final VoidCallback? onCategoryBreakdownTap;
  final VoidCallback? onNavigateToBudgets;

  const HomeScreen({
    super.key,
    required this.selectedMonth,
    this.onMonthChanged,
    this.onNavigateToHistory,
    this.pageScrollEnabled,
    this.onCategoryBreakdownTap,
    this.onNavigateToBudgets,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  double _cardWidth = 0;
  late AnimationController _snapController;
  _TrendRange _trendRange = _TrendRange.m6;

  String? _prefetchCurrency;
  bool? _prefetchConvert;
  int? _prefetchTxCount;

  String? _aiSummary;
  List<String> _aiInsights = [];
  bool _aiContentLoaded = false;
  String? _webInsightWeekKey;
  DateTime? _devAiDate;
  bool _aiGenerating = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAiContent());
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  static const _kDemoInsight =
      'Your spending looks healthy! Groceries and transport are your top categories this week. Consider setting a budget to track your goals.';

  /// ISO-8601 week cache key, e.g. 'ai_insights_2026_w28'. Computed manually
  /// because intl's DateFormat does not implement the 'w' pattern — it emits
  /// a literal 'w', which made every week share one cache key.
  static String _weekKeyFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final firstDay = DateTime(thursday.year, 1, 1);
    final week = thursday.difference(firstDay).inDays ~/ 7 + 1;
    return 'ai_insights_${thursday.year}_w$week';
  }

  Future<void> _loadAiContent() async {
    if (_aiContentLoaded) return;
    if (!mounted) return;

    if (kIsWeb) {
      await _loadWebInsights();
      return;
    }

    final aiProvider = context.read<AiProvider>();
    final sub = context.read<SubscriptionProvider>();
    if (!aiProvider.isReady || !sub.isPro) return;
    _aiContentLoaded = true;

    await _generateAiContent(asOf: DateTime.now());
  }

  /// Generates the monthly summary and weekly insight as of [asOf]. Both the
  /// data windows and the cache keys derive from [asOf], so the dev date
  /// picker can replay any period. [force] (dev-only) bypasses the Hive cache
  /// in both directions and skips the Firestore mirror so test runs never
  /// touch real cached or synced data.
  Future<void> _generateAiContent({
    required DateTime asOf,
    bool force = false,
  }) async {
    // Read context-dependent data before any await
    final allTxSnapshot = context.read<TransactionProvider>().transactions;
    final prefs = context.read<UserPreferencesProvider>();
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == prefs.currency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;

    if (force) setState(() => _aiGenerating = true);

    final box = await Hive.openBox<String>('ai_cache');

    final facts = InsightFacts.compute(
      transactions: allTxSnapshot,
      asOf: asOf,
      currencySymbol: currencySymbol,
      budgetLimits: {for (final b in Budget.budgets) b.categoryId: b.amount},
    );

    // Monthly summary
    final summaryKey = 'ai_summary_${DateFormat('yyyy_MM').format(asOf)}';
    var summary = force ? null : box.get(summaryKey);
    if (summary == null && facts.categoryTotals.isNotEmpty) {
      summary = await SummaryAdapter.generate(
        month: DateFormat('MMMM yyyy').format(asOf),
        income: facts.income,
        categoryTotals: facts.categoryTotals,
        totalSpent: facts.totalSpent,
        facts: facts.factLines,
        currencySymbol: currencySymbol,
        infer: (p) =>
            AiService.instance.infer(p, temperature: 0.3, maxTokens: 120),
      );
      if (summary != null && !force) await box.put(summaryKey, summary);
    }

    // Weekly insight
    final weekKey = _weekKeyFor(asOf);
    List<String> insights = [];
    final cachedInsight = force ? null : box.get(weekKey);
    if (cachedInsight != null) {
      insights = [cachedInsight];
    } else {
      final insight = await InsightAdapter.generate(
        facts: facts.factLines,
        infer: (p) =>
            AiService.instance.infer(p, temperature: 0.4, maxTokens: 100),
      );
      if (insight != null) {
        insights = [insight];
        if (!force) {
          await box.put(weekKey, insight);

          // Mirror to Firestore for cross-device visibility on web.
          if (prefs.authMode == 'google' && prefs.googleUid != null) {
            InsightService(
              db: FirebaseFirestore.instance,
              uid: prefs.googleUid!,
            ).save(InsightCard(
              weekKey: weekKey,
              text: insight,
              generatedAt: DateTime.now(),
            ));
          }
        }
      }
    }

    // Stale insight cleanup — always relative to the real current week so a
    // dev test run doesn't wipe the live cache entry.
    if (!force) {
      final currentWeekKey = _weekKeyFor(DateTime.now());
      for (final k in box.keys.toList()) {
        if (k.toString().startsWith('ai_insights_') && k != currentWeekKey) {
          await box.delete(k);
        }
      }
    }

    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _aiInsights = insights;
        _aiGenerating = false;
      });
    }
  }

  /// Dev-mode only: pick a date and regenerate AI content as of that date.
  Future<void> _pickAiDate() async {
    if (_aiGenerating) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _devAiDate ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Generate AI insights as of…',
    );
    if (picked == null || !mounted) return;
    setState(() => _devAiDate = picked);
    await _generateAiContent(asOf: picked, force: true);
  }

  /// Opens the ephemeral insight chat. Facts are recomputed with the same
  /// inputs the insight generation uses, so the model talks about the data
  /// behind the card the user tapped.
  void _openInsightChat() {
    if (_aiInsights.isEmpty) return;
    final allTx = context.read<TransactionProvider>().transactions;
    final prefs = context.read<UserPreferencesProvider>();
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == prefs.currency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;
    final facts = InsightFacts.compute(
      transactions: allTx,
      asOf: DateTime.now(),
      currencySymbol: currencySymbol,
      budgetLimits: {for (final b in Budget.budgets) b.categoryId: b.amount},
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InsightChatScreen(
          insightText: _aiInsights.first,
          factLines: facts.factLines,
        ),
      ),
    );
  }

  Future<void> _loadWebInsights() async {
    _aiContentLoaded = true;
    final settings = context.read<AppSettingsProvider>();

    if (settings.demoMode) {
      if (mounted) setState(() => _aiInsights = [_kDemoInsight]);
      return;
    }

    final prefs = context.read<UserPreferencesProvider>();
    if (prefs.authMode != 'google' || prefs.googleUid == null) return;

    final weekKey = _weekKeyFor(DateTime.now());
    final svc = InsightService(
      db: FirebaseFirestore.instance,
      uid: prefs.googleUid!,
    );
    final card = await svc.getThisWeek(weekKey);
    if (card != null && mounted) {
      setState(() {
        _aiInsights = [card.text];
        _webInsightWeekKey = weekKey;
      });
    }
  }

  Future<void> _dismissWebInsight() async {
    final key = _webInsightWeekKey;
    if (key == null) return;
    final prefs = context.read<UserPreferencesProvider>();
    if (prefs.googleUid != null) {
      InsightService(db: FirebaseFirestore.instance, uid: prefs.googleUid!)
          .deleteCard(key);
    }
    setState(() {
      _aiInsights = [];
      _webInsightWeekKey = null;
    });
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
    final settings =
        context.watch<AppSettingsProvider>(); // rebuild on color/theme changes
    context.watch<ExchangeRateService>(); // rebuild when new rates arrive
    final globalBudgetAmount = context.watch<BudgetProvider>().globalBudget?.amount;

    // Dev-mode date picker on the insight card — lets you replay AI
    // generation for any period against the current data set.
    final aiReady = context.watch<AiProvider>().isReady;
    final showAiDevPicker = !kIsWeb && settings.devMode && aiReady;
    // Chat entry: on-device model ready (mobile + Pro + AI on) and a real
    // generated insight showing. Web and the dev placeholder never open chat.
    final canOpenInsightChat = !kIsWeb && aiReady && _aiInsights.isNotEmpty;

    final monthTransactions = allTx
        .where(
          (tx) =>
              tx.date.month == widget.selectedMonth.month &&
              tx.date.year == widget.selectedMonth.year,
        )
        .toList();

    final prefs = context.watch<UserPreferencesProvider>();
    final activeIds = prefs.activeCategories.toSet();
    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;

    if (_prefetchCurrency != displayCurrency ||
        _prefetchConvert != convertHistory ||
        _prefetchTxCount != allTx.length) {
      _prefetchCurrency = displayCurrency;
      _prefetchConvert = convertHistory;
      _prefetchTxCount = allTx.length;
      final txSnapshot = allTx;
      final currencySnapshot = displayCurrency;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ExchangeRateService.instance
            .prefetchForTransactions(txSnapshot, currencySnapshot);
      });
    }

    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == displayCurrency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;

    double resolveAmount(Transaction t) {
      if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
      final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
      return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
    }

    final totalExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + resolveAmount(t));

    final totalIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + resolveAmount(t));

    final budgetPct = (globalBudgetAmount != null && globalBudgetAmount > 0)
        ? (totalExpense / globalBudgetAmount * 100).clamp(0.0, 100.0)
        : 0.0;

    final categoryBreakdown = Helpers.getExpenseCategories(activeIds: activeIds)
        .map((cat) {
          final amount = monthTransactions
              .where(
                (t) =>
                    t.type == TransactionType.expense &&
                    t.categoryId == cat.id,
              )
              .fold(0.0, (sum, t) => sum + resolveAmount(t));
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
        .fold(0.0, (s, t) => s + resolveAmount(t));
    double monthIncome(DateTime m) => allTx
        .where((t) =>
            t.date.month == m.month &&
            t.date.year == m.year &&
            t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + resolveAmount(t));
    double pct(double exp) => (globalBudgetAmount != null && globalBudgetAmount > 0)
        ? (exp / globalBudgetAmount * 100).clamp(0.0, 100.0)
        : 0.0;

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
                        final w = _cardWidth > 0 ? _cardWidth : MediaQuery.of(context).size.width;
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
                        _animateTo(0, _cardWidth > 0 ? _cardWidth : MediaQuery.of(context).size.width);
                      },
                      child: LayoutBuilder(builder: (ctx, box) {
                        final w = box.maxWidth;
                        _cardWidth = w;
                        return ClipRect(
                          child: Stack(
                            children: [
                              Transform.translate(
                                offset: Offset(_dragOffset - w, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(prevExp, pct(prevExp), prevInc, currencySymbol, month: prevMonth, monthlyBudgetAmount: globalBudgetAmount),
                                )),
                              ),
                              Transform.translate(
                                offset: Offset(_dragOffset, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(totalExpense, budgetPct, totalIncome, currencySymbol, monthlyBudgetAmount: globalBudgetAmount, onBudgetTap: widget.onNavigateToBudgets),
                                )),
                              ),
                              Transform.translate(
                                offset: Offset(_dragOffset + w, 0),
                                child: SizedBox(width: w, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: _buildBalanceCard(nextExp, pct(nextExp), nextInc, currencySymbol, month: nextMonth, monthlyBudgetAmount: globalBudgetAmount),
                                )),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // ── Category Breakdown ────────────────────────────────────
                    if (categoryBreakdown.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GestureDetector(
                          onTap: widget.onCategoryBreakdownTap ?? () => Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              pageBuilder: (_, __, ___) => CategoryBreakdownScreen(
                                selectedMonth: widget.selectedMonth,
                              ),
                              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                                child: child,
                              ),
                              transitionDuration: const Duration(milliseconds: 400),
                              reverseTransitionDuration: const Duration(milliseconds: 300),
                            ),
                          ),
                          child: _buildCategoryBreakdown(categoryBreakdown, currencySymbol),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Spending Trend ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSpendingTrendWidget(allTx, currencySymbol),
                    ),
                    const SizedBox(height: 16),

                    // ── Insight chips ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildInsightChips(categoryBreakdown, totalExpense, currencySymbol),
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

                    // ── AI Monthly Summary ────────────────────────────────────
                    if (_aiSummary != null)
                      _AiSummaryCard(text: _aiSummary!),

                    // ── AI Weekly Insights ────────────────────────────────────
                    if (showAiDevPicker && _aiGenerating)
                      _AiInsightRow(
                        insights: const ['Generating insights…'],
                        onPickDate: _pickAiDate,
                      )
                    else if (_aiInsights.isNotEmpty)
                      _AiInsightRow(
                        insights: _aiInsights,
                        onDismiss: _webInsightWeekKey != null ? _dismissWebInsight : null,
                        onPickDate: showAiDevPicker ? _pickAiDate : null,
                        onTap: canOpenInsightChat ? _openInsightChat : null,
                      )
                    else if (showAiDevPicker)
                      // Keeps the picker reachable when the chosen period has
                      // no data — otherwise the row (and the icon) vanish.
                      _AiInsightRow(
                        insights: const [
                          'No AI insight for this period. Tap the calendar to test another date.',
                        ],
                        onPickDate: _pickAiDate,
                      ),

                    // ── Suggested Actions checklist ───────────────────────────
                    const SuggestedActionsCard(),

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
    double totalIncome,
    String currencySymbol, {
    DateTime? month,
    double? monthlyBudgetAmount,
    VoidCallback? onBudgetTap,
  }) {
    final m = month ?? widget.selectedMonth;
    final monthName = Helpers.months[m.month - 1];
    final year = m.year;
    final hasBudget = monthlyBudgetAmount != null && monthlyBudgetAmount > 0;

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
                      Helpers.formatAmount(totalExpense, currencySymbol),
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

                    // Budget section — tappable through to the Budgets tab
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBudgetTap,
                      child: hasBudget
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Budget ${Helpers.formatAmount(monthlyBudgetAmount, currencySymbol)}',
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
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No budgets configured',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to set a monthly budget',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                    ),
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

  // ── Category Breakdown ────────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(
    List<CategoryData> breakdown,
    String currencySymbol,
  ) {
    // Denominator for percentages: only the shown (active) categories, so
    // hiding a category doesn't leave the rest summing to under 100%.
    final totalExpense = breakdown.fold(0.0, (s, cd) => s + cd.amount);

    return _SectionCard(
      title: 'Category Breakdown',
      trailing: SizedBox(
        width: 28,
        height: 28,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(LucideIcons.settings,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          onPressed: () => showCategoryFilterSheet(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'category-breakdown-pie',
            child: SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 26,
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
                        radius: 26,
                      );
                    }).toList(),
                  ),
                ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: breakdown.take(5).map((cd) {
                final pct = totalExpense > 0
                    ? (cd.amount / totalExpense * 100).round()
                    : 0;
                final color = Color(
                  int.parse(cd.category.color.substring(1), radix: 16) +
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
                          cd.category.name,
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
                        Helpers.formatAmount(cd.amount, currencySymbol),
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

  // ── Spending Trend ────────────────────────────────────────────────────────

  Widget _buildSpendingTrendWidget(List<Transaction> allTx, String currencySymbol) {
    final List<({String label, double amount})> bars;

    if (_trendRange == _TrendRange.m1) {
      final daysInMonth = DateTime(
          widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
      bars = List.generate(daysInMonth, (i) {
        final day = i + 1;
        final amount = allTx
            .where((t) =>
                t.type == TransactionType.expense &&
                t.date.year == widget.selectedMonth.year &&
                t.date.month == widget.selectedMonth.month &&
                t.date.day == day)
            .fold(0.0, (s, t) => s + t.amount);
        return (label: '$day', amount: amount);
      });
    } else if (_trendRange == _TrendRange.m6) {
      bars = List.generate(6, (i) {
        var m = widget.selectedMonth.month - 5 + i;
        var y = widget.selectedMonth.year;
        while (m < 1) { m += 12; y--; }
        final amount = allTx
            .where((t) =>
                t.type == TransactionType.expense &&
                t.date.month == m &&
                t.date.year == y)
            .fold(0.0, (s, t) => s + t.amount);
        return (label: Helpers.months[m - 1], amount: amount);
      });
    } else {
      bars = List.generate(12, (i) {
        var m = widget.selectedMonth.month - 11 + i;
        var y = widget.selectedMonth.year;
        while (m < 1) { m += 12; y--; }
        final amount = allTx
            .where((t) =>
                t.type == TransactionType.expense &&
                t.date.month == m &&
                t.date.year == y)
            .fold(0.0, (s, t) => s + t.amount);
        return (label: Helpers.months[m - 1], amount: amount);
      });
    }

    return SpendingTrendCard(
      bars: bars,
      rangeLabels: const ['1M', '6M', '1Y'],
      selectedRangeIndex: _trendRange.index,
      onRangeChanged: (i) => setState(() => _trendRange = _TrendRange.values[i]),
      currencySymbol: currencySymbol,
      labelStep: _trendRange == _TrendRange.m1 ? 7 : 1,
    );
  }

  // ── Insight Chips ─────────────────────────────────────────────────────────

  Widget _buildInsightChips(
    List<CategoryData> breakdown,
    double totalExpense,
    String currencySymbol,
  ) {
    final now = DateTime.now();
    final isCurrentMonth =
        widget.selectedMonth.month == now.month &&
        widget.selectedMonth.year == now.year;
    final daysInMonth =
        DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
    final dayOfMonth = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvg = dayOfMonth > 0 ? totalExpense / dayOfMonth : 0.0;
    final topCategory = breakdown.isNotEmpty ? breakdown.first : null;

    return Row(
      children: [
        Expanded(
          child: _InsightChip(data: _InsightChipData(
            icon: LucideIcons.flame,
            label: 'Top Spender',
            value: topCategory?.category.name ?? '—',
            sub: topCategory != null
                ? '${Helpers.formatAmount(topCategory.amount, currencySymbol)} this month'
                : 'No expenses yet',
          )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InsightChip(data: _InsightChipData(
            icon: LucideIcons.barChart2,
            label: 'Daily Average',
            value: Helpers.formatAmount(dailyAvg, currencySymbol),
            sub: 'per day so far',
          )),
        ),
      ],
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
    final prefs = context.watch<UserPreferencesProvider>();
    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;

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

              final double displayAmount;
              final String displaySymbol;
              if (convertHistory || tx.baseCurrency == displayCurrency) {
                final snap = ExchangeRateService.instance
                    .getCachedSnapshot(tx.baseCurrency, tx.date);
                displayAmount = Helpers.convertAmount(
                    tx.amount, tx.baseCurrency, displayCurrency, snap?.rates);
                displaySymbol = kCurrencies
                    .firstWhere((c) => c.code == displayCurrency,
                        orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
                    .symbol;
              } else {
                displayAmount = tx.amount;
                displaySymbol = kCurrencies
                    .firstWhere((c) => c.code == tx.baseCurrency,
                        orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
                    .symbol;
              }

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
                              amount: displayAmount,
                              symbol: displaySymbol,
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

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
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
      height: 86,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
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
  final String symbol;
  final bool isIncome;

  const _AmountBadge({
    required this.amount,
    required this.symbol,
    required this.isIncome,
  });

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
        '${isIncome ? '+' : '−'}${Helpers.formatAmount(amount, symbol)}',
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

// ── AI Summary Card ───────────────────────────────────────────────────────────

class _AiSummaryCard extends StatelessWidget {
  final String text;
  const _AiSummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 20px sides — aligns with the chips/trend/breakdown grid.
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.cpu,
                size: 14,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'Monthly Summary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Insight Row ────────────────────────────────────────────────────────────

class _AiInsightRow extends StatelessWidget {
  final List<String> insights;
  final VoidCallback? onDismiss;
  final VoidCallback? onPickDate;
  final VoidCallback? onTap;
  const _AiInsightRow({
    required this.insights,
    this.onDismiss,
    this.onPickDate,
    this.onTap,
  });

  /// Matches the _InsightChip ("Top Spender") height.
  static const double _wideHeight = 86;

  /// Approximates SpendingTrendCard's rendered height
  /// (16×2 padding + ~20 header + 12 gap + 120 chart).
  static const double _tallHeight = 184;

  /// Card body text; also used to measure whether the wide variant fits.
  static const TextStyle _bodyStyle = TextStyle(fontSize: 12);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;

        // Single insight: full width. Chip height when the text fits 2
        // lines; Spending Trend height otherwise.
        if (insights.length == 1) {
          final painter = TextPainter(
            text: TextSpan(text: insights.first, style: _bodyStyle),
            maxLines: 2,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: fullWidth - 28); // minus card padding
          final fitsWide = !painter.didExceedMaxLines;
          return SizedBox(
            height: fitsWide ? _wideHeight : _tallHeight,
            width: double.infinity,
            child: _AiInsightCard(
              text: insights.first,
              maxLines: fitsWide ? 2 : 8,
              onDismiss: onDismiss,
              onPickDate: onPickDate,
              onTap: onTap,
            ),
          );
        }

        // Multiple insights: chip width ("Top Spender"), Spending Trend
        // height, horizontally scrollable.
        final chipWidth = (fullWidth - 12) / 2;
        return SizedBox(
          height: _tallHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: chipWidth,
              child: _AiInsightCard(
                text: insights[i],
                maxLines: 8,
                onDismiss: i == 0 ? onDismiss : null,
                onPickDate: i == 0 ? onPickDate : null,
                onTap: onTap,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  final String text;
  final int maxLines;
  final VoidCallback? onDismiss;

  /// Dev-mode date picker trigger; renders a calendar icon when non-null.
  final VoidCallback? onPickDate;
  final VoidCallback? onTap;
  const _AiInsightCard({
    required this.text,
    required this.maxLines,
    this.onDismiss,
    this.onPickDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.lightbulb,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Insight',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (onPickDate != null || onDismiss != null) const Spacer(),
                if (onPickDate != null)
                  GestureDetector(
                    onTap: onPickDate,
                    child: Icon(
                      LucideIcons.calendar,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (onPickDate != null && onDismiss != null)
                  const SizedBox(width: 10),
                if (onDismiss != null)
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(
                      LucideIcons.x,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: _AiInsightRow._bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
