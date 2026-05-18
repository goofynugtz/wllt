import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../data/currencies.dart';
import '../providers/user_preferences_provider.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import '../widgets/add_expense_sheet.dart';
import '../screens/layout_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final DateTime selectedMonth;

  const TransactionsScreen({super.key, required this.selectedMonth});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransactionFilter _filter = TransactionFilter.all;

  String? _prefetchCurrency;
  bool? _prefetchConvert;
  int? _prefetchTxCount;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _filteredTransactions(List<Transaction> source, String currencySymbol) {
    final query = _searchController.text.toLowerCase().trim();
    return source.where((tx) {
      final matchMonth =
          tx.date.month == widget.selectedMonth.month &&
          tx.date.year == widget.selectedMonth.year;
      final category = Helpers.getCategoryById(tx.categoryId);
      final matchSearch = query.isEmpty ||
          tx.transactionTitle.toLowerCase().contains(query) ||
          category.name.toLowerCase().contains(query) ||
          tx.amount.toString().contains(query) ||
          Helpers.formatAmount(tx.amount, currencySymbol).toLowerCase().contains(query) ||
          tx.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchType =
          _filter == TransactionFilter.all || tx.type.name == _filter.name;
      return matchMonth && matchSearch && matchType;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    final allTx = context.watch<TransactionProvider>().transactions;
    final prefs = context.watch<UserPreferencesProvider>();
    context.watch<ExchangeRateService>();

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
    final filtered = _filteredTransactions(allTx, currencySymbol);
    final grouped = Helpers.groupByDate(filtered);
    final total = filtered.fold(0.0, (sum, tx) {
      final snap = ExchangeRateService.instance.getCachedSnapshot(tx.baseCurrency, tx.date);
      final resolved = (convertHistory || tx.baseCurrency == displayCurrency)
          ? Helpers.convertAmount(tx.amount, tx.baseCurrency, displayCurrency, snap?.rates)
          : tx.amount;
      return sum + (tx.type == TransactionType.expense ? -resolved : resolved);
    });
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search merchant, category, tag or amount…',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12.5,
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),

          // Filter chips and total
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Filter chips
                ...TransactionFilter.values.map((filter) {
                  final isActive = _filter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          filter.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // Running total
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${total >= 0 ? '+' : '−'}${Helpers.formatAmount(total.abs(), currencySymbol)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: total >= 0
                          ? AppTheme.incomeColor
                          : AppTheme.expenseColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Transactions list
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Text(
                      'No transactions found',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: grouped.entries.map((entry) {
                      return _buildDayGroup(entry.key, entry.value, currencySymbol);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayGroup(String dateStr, List<Transaction> transactions, String currencySymbol) {
    final prefs = context.watch<UserPreferencesProvider>();
    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;

    double _resolved(Transaction t) {
      if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
      final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
      return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
    }

    final dayExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + _resolved(t));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Day header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Helpers.formatDateLabel(dateStr),
                  style: AppTheme.trackingWideSecondary,
                ),
                if (dayExpense > 0)
                  Text(
                    '−${Helpers.formatAmount(dayExpense, currencySymbol)}',
                    style: const TextStyle(
                                            fontSize: 11,
                      color: AppTheme.expenseColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Transaction rows
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
              ),
              child: Column(
                children: transactions.asMap().entries.map((entry) {
                  final tx = entry.value;
                  final isFirst = entry.key == 0;

                  return TransactionRow(
                    transaction: tx,
                    isFirst: isFirst,
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

class _AmountBadge extends StatelessWidget {
  final double amount;
  final bool isIncome;
  final String symbol;

  const _AmountBadge({
    required this.amount,
    required this.isIncome,
    required this.symbol,
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

enum TransactionFilter {
  all('All'),
  expense('Expenses'),
  income('Income');

  const TransactionFilter(this.label);

  final String label;
}

class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final bool isFirst;

  const TransactionRow({
    super.key,
    required this.transaction,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final category = Helpers.getCategoryById(transaction.categoryId);
    final accounts = context.watch<AccountProvider>().accounts;
    Account? _resolvedAccount;
    try { _resolvedAccount = accounts.firstWhere((a) => a.id == transaction.account); } catch (_) {}
    _resolvedAccount ??= accounts.cast<Account?>().firstWhere((a) => a!.displayName == transaction.account, orElse: () => null);
    final accountName = _resolvedAccount?.displayName ?? transaction.account;

    final prefs = context.watch<UserPreferencesProvider>();
    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;

    final double displayAmount;
    final String displaySymbol;

    if (convertHistory || transaction.baseCurrency == displayCurrency) {
      final snapshot = ExchangeRateService.instance
          .getCachedSnapshot(transaction.baseCurrency, transaction.date);
      displayAmount = Helpers.convertAmount(
        transaction.amount,
        transaction.baseCurrency,
        displayCurrency,
        snapshot?.rates,
      );
      displaySymbol = kCurrencies
          .firstWhere((c) => c.code == displayCurrency,
              orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
          .symbol;
    } else {
      displayAmount = transaction.amount;
      displaySymbol = kCurrencies
          .firstWhere((c) => c.code == transaction.baseCurrency,
              orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
          .symbol;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddTransactionPage(
                method: transaction.type == TransactionType.income
                    ? AddTransactionMethod.income
                    : AddTransactionMethod.expense,
                editTransaction: transaction,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: isFirst
                ? null
                : Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
          ),
          child: Row(
            children: [
              // Icon
              CategoryIconBadge(category: category, size: 36, iconSize: 18),
              const SizedBox(width: 12),

              // Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.transactionTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${category.name} · $accountName',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount
              _AmountBadge(
                amount: displayAmount,
                isIncome: transaction.type == TransactionType.income,
                symbol: displaySymbol,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
