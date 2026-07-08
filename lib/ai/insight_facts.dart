import '../models/models.dart';
import '../utils/helpers.dart';

/// A subscription-like charge detected from history: same title, similar
/// amount, ~monthly cadence.
class RecurringCharge {
  final String title;
  final double avgAmount;
  final int occurrences;

  const RecurringCharge({
    required this.title,
    required this.avgAmount,
    required this.occurrences,
  });
}

/// Hard-computed spending facts for the month of [compute]'s `asOf` date.
/// The AI adapters receive these pre-chewed lines so the model only phrases
/// and prioritizes — a 1B model can't reliably derive patterns from raw
/// category totals.
class InsightFacts {
  /// Income for the month of asOf.
  final double income;

  /// Total expenses for the month of asOf.
  final double totalSpent;

  /// Expense totals for the month of asOf, keyed by category display name.
  final Map<String, double> categoryTotals;

  final List<RecurringCharge> recurring;

  /// Prompt-ready fact lines, most actionable first.
  final List<String> factLines;

  const InsightFacts._({
    required this.income,
    required this.totalSpent,
    required this.categoryTotals,
    required this.recurring,
    required this.factLines,
  });

  // Categories where a recurring charge is realistically cancellable.
  // Rent (home) and electricity (utilities) recur too but "cancel your rent"
  // is not an insight.
  static const _cancellableCategories = {
    'movies', 'music', 'fitness', 'education', 'coffee',
    'restaurant', 'shopping', 'internet', 'phone',
  };

  static InsightFacts compute({
    required List<Transaction> transactions,
    required DateTime asOf,
    required String currencySymbol,
    Map<String, double> budgetLimits = const {},
  }) {
    String fmt(double v) => Helpers.formatAmount(v, currencySymbol);
    String name(String id) => Helpers.getCategoryById(id).name;
    bool inMonth(Transaction t, int year, int month) =>
        t.date.year == year && t.date.month == month;

    final prev = DateTime(asOf.year, asOf.month - 1);

    final curExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            inMonth(t, asOf.year, asOf.month))
        .toList();

    final income = transactions
        .where((t) =>
            t.type == TransactionType.income &&
            inMonth(t, asOf.year, asOf.month))
        .fold(0.0, (s, t) => s + t.amount);

    final curById = <String, double>{};
    final curCountById = <String, int>{};
    double totalSpent = 0;
    for (final t in curExpenses) {
      curById[t.categoryId] = (curById[t.categoryId] ?? 0) + t.amount;
      curCountById[t.categoryId] = (curCountById[t.categoryId] ?? 0) + 1;
      totalSpent += t.amount;
    }

    final prevById = <String, double>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (!inMonth(t, prev.year, prev.month)) continue;
      prevById[t.categoryId] = (prevById[t.categoryId] ?? 0) + t.amount;
    }

    // ── Recurring charges: same title, every gap ~monthly, similar amount ──
    final windowStart = asOf.subtract(const Duration(days: 100));
    final monthEnd = DateTime(asOf.year, asOf.month + 1, 1);
    final byTitle = <String, List<Transaction>>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (!t.date.isAfter(windowStart) || !t.date.isBefore(monthEnd)) continue;
      byTitle
          .putIfAbsent(t.transactionTitle.trim().toLowerCase(), () => [])
          .add(t);
    }
    final recurring = <RecurringCharge>[];
    for (final group in byTitle.values) {
      final txs = group..sort((a, b) => a.date.compareTo(b.date));
      if (txs.length < 2) continue;
      if (!_cancellableCategories.contains(txs.last.categoryId)) continue;
      var monthlyCadence = true;
      for (var i = 1; i < txs.length; i++) {
        final gap = txs[i].date.difference(txs[i - 1].date).inDays;
        if (gap < 20 || gap > 45) {
          monthlyCadence = false;
          break;
        }
      }
      if (!monthlyCadence) continue;
      final amounts = txs.map((t) => t.amount).toList();
      final lo = amounts.reduce((a, b) => a < b ? a : b);
      final hi = amounts.reduce((a, b) => a > b ? a : b);
      if (lo <= 0 || hi / lo > 1.3) continue;
      recurring.add(RecurringCharge(
        title: txs.last.transactionTitle,
        avgAmount: amounts.reduce((a, b) => a + b) / amounts.length,
        occurrences: txs.length,
      ));
    }
    recurring.sort((a, b) => b.avgAmount.compareTo(a.avgAmount));

    // ── Fact lines, most actionable first ──────────────────────────────────
    final lines = <String>[];

    // Budget overshoots
    final over = curById.entries
        .where((e) => (budgetLimits[e.key] ?? double.infinity) < e.value)
        .toList()
      ..sort((a, b) => (b.value - budgetLimits[b.key]!)
          .compareTo(a.value - budgetLimits[a.key]!));
    for (final e in over.take(2)) {
      final limit = budgetLimits[e.key]!;
      final pctOver = ((e.value / limit - 1) * 100).round();
      lines.add('${name(e.key)} is over budget: ${fmt(e.value)} spent vs '
          '${fmt(limit)} limit (+$pctOver%)');
    }

    // Month-over-month spikes
    final spikes = curById.entries.where((e) {
      final p = prevById[e.key] ?? 0;
      return p > 0 && e.value >= 300 && e.value / p >= 1.25;
    }).toList()
      ..sort((a, b) => (b.value / prevById[b.key]!)
          .compareTo(a.value / prevById[a.key]!));
    for (final e in spikes.take(2)) {
      final p = prevById[e.key]!;
      final pctUp = ((e.value / p - 1) * 100).round();
      lines.add('${name(e.key)} jumped to ${fmt(e.value)} this month from '
          '${fmt(p)} last month (+$pctUp%, ${curCountById[e.key]} transactions)');
    }

    // Recurring subscriptions
    if (recurring.isNotEmpty) {
      final parts = recurring
          .take(4)
          .map((r) => '${r.title} ${fmt(r.avgAmount)}')
          .join(', ');
      final monthlyTotal = recurring.fold(0.0, (s, r) => s + r.avgAmount);
      lines.add('Recurring subscriptions: $parts '
          '(${fmt(monthlyTotal)}/month total)');
    }

    // Largest one-off (excluding recurring titles)
    final recurringTitles =
        recurring.map((r) => r.title.toLowerCase()).toSet();
    final oneOffs = curExpenses
        .where((t) =>
            !recurringTitles.contains(t.transactionTitle.trim().toLowerCase()))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (oneOffs.isNotEmpty) {
      final top = oneOffs.first;
      lines.add('Largest single expense: ${top.transactionTitle} '
          '${fmt(top.amount)} (${name(top.categoryId)})');
    }

    // Top category + income context
    if (curById.isNotEmpty) {
      final top =
          curById.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final share =
          totalSpent > 0 ? (top.value / totalSpent * 100).round() : 0;
      lines.add('Top category: ${name(top.key)} ${fmt(top.value)} '
          '($share% of ${fmt(totalSpent)} total)');
    }
    if (income > 0 && totalSpent > 0) {
      final pct = (totalSpent / income * 100).round();
      lines.add('Spent ${fmt(totalSpent)} of ${fmt(income)} income ($pct%)');
    }

    return InsightFacts._(
      income: income,
      totalSpent: totalSpent,
      categoryTotals: {
        for (final e in curById.entries) name(e.key): e.value,
      },
      recurring: recurring,
      factLines: lines,
    );
  }
}
