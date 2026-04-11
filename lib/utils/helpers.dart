import 'package:intl/intl.dart';

import '../models/models.dart';

/// Stateless utility class — pure functions and static data.
class Helpers {
  Helpers._();

  // ── Constants ─────────────────────────────────────────────────────────────

  /// Default total monthly spending budget (INR).
  static const double monthlyBudget = 30000;

  /// Abbreviated month names for display (index 0 = January).
  static const List<String> months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // ── Formatters ───────────────────────────────────────────────────────────

  static final _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats [amount] as an Indian-locale currency string, e.g. "₹1,28,452".
  static String formatINR(double amount) => _inrFormat.format(amount);

  /// Converts an ISO-8601 date key ("yyyy-MM-dd") into a human label.
  /// Returns "Today", "Yesterday", or "MMM d" (e.g. "Mar 28").
  static String formatDateLabel(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now  = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today)     return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  // ── Data helpers ─────────────────────────────────────────────────────────

  /// Looks up a [Category] by [id]; falls back to the first category.
  static Category getCategoryById(String id) => Category.getById(id);

  /// All categories treated as expense categories in this app.
  static List<Category> getExpenseCategories() {
    const _expenseIds = {
      'shopping', 'restaurant', 'doctor', 'coffee', 'movies',
      'transport', 'groceries', 'utilities', 'music', 'travel',
      'fitness', 'education', 'home', 'phone', 'internet', 'gifts',
    };
    return Category.categories
        .where((c) => _expenseIds.contains(c.id))
        .toList();
  }

  /// Categories used for income transactions.
  static List<Category> getIncomeCategories() {
    const _incomeIds = {'savings', 'work'};
    return Category.categories
        .where((c) => _incomeIds.contains(c.id))
        .toList();
  }

  /// Groups [transactions] into a date-descending `Map<"yyyy-MM-dd", List<Transaction>>`.
  static Map<String, List<Transaction>> groupByDate(
    List<Transaction> transactions,
  ) {
    final Map<String, List<Transaction>> grouped = {};
    for (final tx in transactions) {
      final key =
          '${tx.date.year}-'
          '${tx.date.month.toString().padLeft(2, '0')}-'
          '${tx.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    // Return sorted newest-first.
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: grouped[k]!};
  }
}
