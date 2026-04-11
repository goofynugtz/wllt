import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_widget.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransactionFilter _filter = TransactionFilter.all;
  String? _expandedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> get _filteredTransactions {
    return Transaction.transactions.where((tx) {
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
      return matchSearch && matchType;
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
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () {
                // Show filter options
              },
              icon: const Icon(
                LucideIcons.slidersHorizontal,
                size: 15,
                color: AppTheme.onSurfaceColor,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
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
                      fontFamily: 'monospace',
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
                ? const Center(
                    child: Text(
                      'No transactions found',
                      style: TextStyle(color: Color(0xFFc0bdb8), fontSize: 13),
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
                      fontFamily: 'monospace',
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor, width: 0.5),
              ),
              child: Column(
                children: transactions.asMap().entries.map((entry) {
                  final tx = entry.value;
                  final isFirst = entry.key == 0;
                  final isExpanded = _expandedId == tx.id;

                  return TransactionRow(
                    transaction: tx,
                    isFirst: isFirst,
                    isExpanded: isExpanded,
                    onToggle: () {
                      setState(() {
                        _expandedId = isExpanded ? null : tx.id;
                      });
                    },
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
  final bool isExpanded;
  final VoidCallback onToggle;

  const TransactionRow({
    super.key,
    required this.transaction,
    required this.isFirst,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final category = Helpers.getCategoryById(transaction.categoryId);

    return Column(
      children: [
        // Main row
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: isFirst
                    ? null
                    : Border(
                        top: BorderSide(
                          color: Colors.black.withOpacity(0.05),
                          width: 0.5,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(category.bg.substring(1), radix: 16) +
                            0xFF000000,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CategoryIconWidget(
                        category: category,
                        size: 20,
                        color: Color(
                          int.parse(
                                category.color.substring(1),
                                radix: 16,
                              ) +
                              0xFF000000,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.transactionTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${category.name} · ${transaction.account}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Amount + chevron
                  Row(
                    children: [
                      Text(
                        '${transaction.type == TransactionType.income ? '+' : '−'}${Helpers.formatINR(transaction.amount)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: transaction.type == TransactionType.income
                              ? AppTheme.incomeColor
                              : AppTheme.expenseColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          LucideIcons.chevronDown,
                          size: 13,
                          color: Color(0xFFc0bdb8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expanded detail
        if (isExpanded)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFfaf9f6),
              border: Border(
                top: BorderSide(
                  color: Colors.black.withOpacity(0.04),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (transaction.note != null)
                        Text(
                          '"${transaction.note}"',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        const Text(
                          'No note',
                          style: TextStyle(fontSize: 12, color: Color(0xFFccc)),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.date.toString().substring(0, 10),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFc0bdb8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    // Edit button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.pencil,
                            size: 11,
                            color: Color(0xFF666),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfde8e8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.trash2,
                            size: 11,
                            color: AppTheme.expenseColor,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
