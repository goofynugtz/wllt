import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
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
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> get _filteredTransactions {
    return Transaction.transactions.where((tx) {
      final matchMonth =
          tx.date.month == widget.selectedMonth.month &&
          tx.date.year == widget.selectedMonth.year;
      final category = Helpers.getCategoryById(tx.categoryId);
      final matchSearch =
          _searchController.text.isEmpty ||
          tx.transactionTitle.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          category.name.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
      final matchType =
          _filter == TransactionFilter.all || tx.type.name == _filter.name;
      return matchMonth && matchSearch && matchType;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Map<String, List<Transaction>> get _groupedTransactions {
    return Helpers.groupByDate(_filteredTransactions);
  }

  double get _totalFiltered {
    return _filteredTransactions.fold(0.0, (sum, tx) {
      return sum +
          (tx.type == TransactionType.expense ? -tx.amount : tx.amount);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                hintText: 'Search merchant or category…',
                hintStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12.5,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? Colors.white
                                : AppTheme.onSurfaceColor,
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
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_totalFiltered >= 0 ? '+' : '−'}${Helpers.formatINR(_totalFiltered.abs())}',
                    style: TextStyle(
                      fontSize: 12,
                                            color: _totalFiltered >= 0
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
            child: _groupedTransactions.isEmpty
                ? Center(
                    child: Text(
                      'No transactions found',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _groupedTransactions.entries.map((entry) {
                      return _buildDayGroup(entry.key, entry.value);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayGroup(String dateStr, List<Transaction> transactions) {
    final dayExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

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
                    '−${Helpers.formatINR(dayExpense)}',
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
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
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
                      color: Theme.of(context).colorScheme.outlineVariant,
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
                      '${category.name} · ${transaction.account}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '${transaction.type == TransactionType.income ? '+' : '−'}${Helpers.formatINR(transaction.amount)}',
                style: TextStyle(
                                    fontSize: 13,
                  color: transaction.type == TransactionType.income
                      ? AppTheme.incomeColor
                      : AppTheme.expenseColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
