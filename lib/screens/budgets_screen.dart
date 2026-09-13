import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/currencies.dart';
import '../models/models.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/category_icon_badge.dart';
import 'category_detail_screen.dart';

class BudgetsScreen extends StatelessWidget {
  final DateTime selectedMonth;

  const BudgetsScreen({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final allTx = context.watch<TransactionProvider>().transactions;
    final budgetProvider = context.watch<BudgetProvider>();
    final prefs = context.watch<UserPreferencesProvider>();
    context.watch<ExchangeRateService>(); // rebuild when new rates arrive

    final displayCurrency = prefs.currency;
    final convertHistory = prefs.convertHistoricalCurrency;
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == displayCurrency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;

    double resolveAmount(Transaction t) {
      if (!convertHistory && t.baseCurrency != displayCurrency) return t.amount;
      final snap = ExchangeRateService.instance.getCachedSnapshot(t.baseCurrency, t.date);
      return Helpers.convertAmount(t.amount, t.baseCurrency, displayCurrency, snap?.rates);
    }

    final monthTx = allTx.where((t) =>
        t.date.month == selectedMonth.month && t.date.year == selectedMonth.year);

    double spentFor(String? categoryId) => monthTx
        .where((t) =>
            t.type == TransactionType.expense &&
            (categoryId == null || t.categoryId == categoryId))
        .fold(0.0, (s, t) => s + resolveAmount(t));

    final totalSpent = spentFor(null);
    final global = budgetProvider.globalBudget;
    final activeIds = prefs.activeCategories.toSet();
    final categories = Helpers.getExpenseCategories(activeIds: activeIds);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _GlobalBudgetCard(
            amount: global?.amount,
            spent: totalSpent,
            currencySymbol: currencySymbol,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => _GlobalBudgetSheet(
                existing: global,
                budgetProvider: budgetProvider,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('CATEGORY ALLOCATIONS', style: AppTheme.trackingWide),
          const SizedBox(height: 10),
          ...categories.map((cat) {
            final budget = budgetProvider.budgetFor(cat.id);
            final allocated =
                budget != null ? BudgetProvider.monthlyEquivalent(budget) : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryAllocationTile(
                category: cat,
                allocated: allocated,
                spent: spentFor(cat.id),
                currencySymbol: currencySymbol,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: cat)),
                ),
              ),
            );
          }),
          if (global != null) ...[
            const SizedBox(height: 4),
            Text(
              '${Helpers.formatAmount(budgetProvider.remainingGlobalBudget(), currencySymbol)} unallocated',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Global budget card ────────────────────────────────────────────────────

class _GlobalBudgetCard extends StatelessWidget {
  final double? amount;
  final double spent;
  final String currencySymbol;
  final VoidCallback onTap;

  const _GlobalBudgetCard({
    required this.amount,
    required this.spent,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBudget = amount != null && amount! > 0;
    final pct = hasBudget ? (spent / amount! * 100).clamp(0.0, 100.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MONTHLY BUDGET',
                style: TextStyle(fontSize: 11, letterSpacing: 0.8, color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            if (hasBudget) ...[
              Text(Helpers.formatAmount(spent, currencySymbol),
                  style: TextStyle(fontSize: 28, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text('of ${Helpers.formatAmount(amount!, currencySymbol)} this month',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: pct >= 100 ? cs.error : cs.primary,
                ),
              ),
            ] else ...[
              Text('Set a monthly budget', style: TextStyle(fontSize: 16, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Tap to set a spending cap for the month',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlobalBudgetSheet extends StatefulWidget {
  final Budget? existing;
  final BudgetProvider budgetProvider;

  const _GlobalBudgetSheet({required this.existing, required this.budgetProvider});

  @override
  State<_GlobalBudgetSheet> createState() => _GlobalBudgetSheetState();
}

class _GlobalBudgetSheetState extends State<_GlobalBudgetSheet> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amount = double.tryParse(_amountCtrl.text);
    final canSave = amount != null && amount > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing != null ? 'Edit Monthly Budget' : 'Set Monthly Budget',
              style: TextStyle(fontSize: 18, color: cs.onSurface)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Monthly limit',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave
                  ? () {
                      FocusScope.of(context).unfocus();
                      widget.budgetProvider.setGlobalBudget(amount);
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
                  widget.budgetProvider.deleteGlobalBudget();
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

// ── Category allocation row ───────────────────────────────────────────────

class _CategoryAllocationTile extends StatelessWidget {
  final Category category;
  final double? allocated;
  final double spent;
  final String currencySymbol;
  final VoidCallback onTap;

  const _CategoryAllocationTile({
    required this.category,
    required this.allocated,
    required this.spent,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBudget = allocated != null && allocated! > 0;
    final pct = hasBudget ? (spent / allocated! * 100).clamp(0.0, 100.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Row(
          children: [
            CategoryIconBadge(category: category, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  if (hasBudget)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 5,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: pct >= 100 ? cs.error : cs.primary,
                      ),
                    )
                  else
                    Text('No budget set', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Helpers.formatAmount(spent, currencySymbol),
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                if (hasBudget)
                  Text('of ${Helpers.formatAmount(allocated!, currencySymbol)}',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
