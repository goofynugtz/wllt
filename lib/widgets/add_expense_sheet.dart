import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../utils/helpers.dart';
import 'category_icon_widget.dart';
import '../screens/add_account_screen.dart';
import '../screens/layout_screen.dart';
import '../screens/categories_screen.dart';
import 'amount_calculator.dart';

class AddTransactionPage extends StatelessWidget {
  final AddTransactionMethod method;
  final Transaction? editTransaction;

  const AddTransactionPage({
    super.key,
    required this.method,
    this.editTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final isEdit = editTransaction != null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Transaction' : 'Add Transaction',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        LucideIcons.x,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildFormContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    switch (method) {
      case AddTransactionMethod.expense:
        return ManualEntryForm(
          initialType: TransactionType.expense,
          editTransaction: editTransaction,
        );
      case AddTransactionMethod.income:
        return ManualEntryForm(
          initialType: TransactionType.income,
          editTransaction: editTransaction,
        );
      case AddTransactionMethod.transfer:
        return const TransferForm();
    }
  }
}

class ManualEntryForm extends StatefulWidget {
  final TransactionType initialType;
  final Transaction? editTransaction;

  const ManualEntryForm({
    super.key,
    required this.initialType,
    this.editTransaction,
  });

  @override
  State<ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm>
    with SingleTickerProviderStateMixin {
  late TransactionType _type;
  String _amount = '';
  String _selectedCategory = 'food';
  String _merchant = '';
  DateTime _selectedDate = DateTime.now();
  final List<String> _tags = [];
  Account? _account;
  bool _accountInitialized = false;
  bool _showCalculator = false;
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();

  // Calculator state — expression lives here so the display never moves
  String _expression = '';
  String _calcPreview = '';
  late AnimationController _calcController;
  late Animation<Offset> _calcSlide;
  final ScrollController _exprScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final tx = widget.editTransaction;
    if (tx != null) {
      _type = tx.type;
      final amt = tx.amount;
      _amount = amt == amt.truncate() ? amt.toInt().toString() : amt.toStringAsFixed(2);
      _selectedCategory = tx.categoryId;
      _merchant = tx.transactionTitle;
      _selectedDate = tx.date;
      _tags.addAll(tx.tags);
    } else {
      _type = widget.initialType;
      _selectedCategory = '';
    }
    _titleController = TextEditingController(text: _merchant);
    _calcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _calcSlide = Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _calcController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_accountInitialized) {
      final accounts = context.read<AccountProvider>().accounts;
      if (accounts.isNotEmpty) {
        final tx = widget.editTransaction;
        _account = tx != null
            ? accounts.firstWhere((a) => a.displayName == tx.account, orElse: () => accounts.first)
            : accounts.first;
      }
      _accountInitialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _calcController.dispose();
    _exprScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    final amountValue = double.tryParse(_amount);
    if (amountValue == null || amountValue <= 0) return;
    if (_merchant.trim().isEmpty) return;

    final provider = context.read<TransactionProvider>();
    final tx = Transaction(
      id: widget.editTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      transactionTitle: _merchant.trim(),
      categoryId: _selectedCategory,
      amount: amountValue,
      type: _type,
      date: _selectedDate,
      account: _account?.displayName ?? '',
      tags: List.from(_tags),
    );

    if (widget.editTransaction != null) {
      await provider.updateTransaction(tx);
    } else {
      await provider.addTransaction(tx);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _selectAccount(Account account) {
    if (account.id == _account?.id) return;
    setState(() => _account = account);
  }

  void _openCalculator() {
    _titleFocusNode.unfocus();
    _expression = _amount;
    _calcPreview = _calcTryEvaluate(_expression) ?? '';
    setState(() => _showCalculator = true);
    _calcController.forward(from: 0);
  }

  void _closeCalculator(String result) {
    _calcController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _amount = result;
        _showCalculator = false;
        _expression = '';
        _calcPreview = '';
      });
    });
  }

  void _onCalcButton(String label) {
    if (label == '=') {
      _closeCalculator(_calcTryEvaluate(_expression) ?? _expression);
      return;
    }
    setState(() {
      switch (label) {
        case '⌫':
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
          }
        case 'AC':
          _expression = '';
          _calcPreview = '';
          return;
        case '( )':
          _expression += _calcSmartBracket(_expression);
        case '÷':
          _expression += '/';
        case '×':
          _expression += '*';
        case '−':
          _expression += '-';
        default:
          _expression += label;
      }
      _calcPreview = _calcTryEvaluate(_expression) ?? '';
    });
    // Scroll expression to end after the frame re-renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_exprScrollController.hasClients) {
        _exprScrollController.animateTo(
          _exprScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _calcSmartBracket(String expr) {
    final opens = '('.allMatches(expr).length;
    final closes = ')'.allMatches(expr).length;
    if (opens == closes) return '(';
    if (expr.isNotEmpty &&
        ['+', '-', '*', '/', '('].contains(expr[expr.length - 1])) return '(';
    return ')';
  }

  String? _calcTryEvaluate(String expression) {
    if (expression.isEmpty) return null;
    if (!RegExp(r'[+\-*/()%]').hasMatch(expression)) return null;
    try {
      final result = _calcEval(expression);
      return result == result.toInt()
          ? result.toInt().toString()
          : result.toStringAsFixed(2);
    } catch (_) {
      return null;
    }
  }

  double _calcEval(String expr) {
    expr = expr.trim().replaceAllMapped(
      RegExp(r'(\d+\.?\d*)%'),
      (m) => '(${m.group(1)}/100)',
    );
    while (expr.contains('(')) {
      final open = expr.lastIndexOf('(');
      final close = expr.indexOf(')', open);
      if (close == -1) throw Exception('Unmatched parenthesis');
      final inner = _calcEvalSimple(expr.substring(open + 1, close));
      expr = expr.substring(0, open) +
          inner.toString() +
          expr.substring(close + 1);
    }
    return _calcEvalSimple(expr);
  }

  double _calcEvalSimple(String expr) {
    final mulDiv = RegExp(r'(-?\d+\.?\d*)\s*([*/])\s*(-?\d+\.?\d*)');
    while (mulDiv.hasMatch(expr)) {
      final m = mulDiv.firstMatch(expr)!;
      final l = double.parse(m.group(1)!), r = double.parse(m.group(3)!);
      final res =
          m.group(2) == '*' ? l * r : (r == 0 ? throw Exception('÷0') : l / r);
      expr = expr.replaceFirst(m.group(0)!, res.toString());
    }
    final addSub = RegExp(r'(-?\d+\.?\d*)\s*([+\-])\s*(-?\d+\.?\d*)');
    while (addSub.hasMatch(expr)) {
      final m = addSub.firstMatch(expr)!;
      final l = double.parse(m.group(1)!), r = double.parse(m.group(3)!);
      final res = m.group(2) == '+' ? l + r : l - r;
      expr = expr.replaceFirst(m.group(0)!, res.toString());
    }
    return double.parse(expr);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showCalculator,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showCalculator) {
          _closeCalculator(_calcTryEvaluate(_expression) ?? _expression);
        }
      },
      child: _buildNormalForm(context),
    );
  }

  Widget _buildNormalForm(BuildContext context) {
    // Measure at the large size (40) as a fixed ruler — if the text wraps
    // at 40px, render at 32px. Always measuring at 40 avoids the flip-flop
    // where a smaller font would make text refit → snap back → repeat.
    final availableWidth = MediaQuery.of(context).size.width - 40;
    final _tp = TextPainter(
      text: TextSpan(
        text: _merchant.isEmpty ? ' ' : _merchant,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availableWidth);
    final titleFontSize = _tp.computeLineMetrics().length > 1 ? 32.0 : 40.0;

    final isExpense = _type == TransactionType.expense;
    final prefs = context.watch<UserPreferencesProvider>();
    final activeIds = prefs.activeCategories.toSet();
    final customMap = {for (final c in prefs.customCategories) c.id: c};
    final builtinIds = Category.categories.map((c) => c.id).toSet();
    // Single source of truth: show what user picked in onboarding, for both
    // expense and income. Fall back to all built-ins if nothing selected yet.
    final baseCategories = activeIds.isEmpty
        ? Category.categories
        : Category.categories.where((c) => activeIds.contains(c.id)).toList();
    final displayCategories = [
      ...baseCategories.map((c) => customMap[c.id] ?? c),
      ...prefs.customCategories.where((c) => !builtinIds.contains(c.id)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fixed top: title + amount display — never moves ──────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title TextField — same widget in both modes
              Material(
                color: Colors.transparent,
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  onChanged: (v) => setState(() => _merchant = v),
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 60,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add Description',
                    hintStyle: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      height: 1.15,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                ),
              ),

              // Amount / Expression — fixed-height slot so the ₹ never
              // shifts when switching modes. 106px fits both branches:
              //   normal  : amount(~70) + divider+margin(21) = 91px
              //   calc    : expression(72) + preview(~34)    = 106px
              SizedBox(
                height: 106,
                child: _showCalculator
                    ? _buildExpressionDisplay(context)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _openCalculator,
                            child: Text(
                              '₹ ${_amount.isEmpty ? '0' : _amount}',
                              style: TextStyle(
                                fontFamily: 'Archia',
                                fontSize: 64,
                                fontWeight: FontWeight.normal,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.1,
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.only(bottom: 20),
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),

        // ── Bottom: form fields OR animated calculator grid ───────────────
        Expanded(
          child: _showCalculator
              ? ClipRect(
                  child: SlideTransition(
                    position: _calcSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: AmountCalculator(
                        onButtonPressed: _onCalcButton,
                        onSetPressed: () => _closeCalculator(
                          _calcTryEvaluate(_expression) ?? _expression,
                        ),
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSectionHeader(
                          context,
                          LucideIcons.tag,
                          'Category',
                          showEdit: true,
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CategoriesScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: displayCategories.map((category) {
                            final isSelected = _selectedCategory == category.id;
                            final accentColor = Color(
                              int.parse(
                                    category.color.substring(1),
                                    radix: 16,
                                  ) +
                                  0xFF000000,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _selectedCategory = category.id,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accentColor
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? null
                                            : Border.all(
                                                color: Theme.of(context).colorScheme.outlineVariant,
                                                width: 1,
                                              ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: CategoryIconWidget(
                                          category: category,
                                          size: 30,
                                          color: isSelected
                                              ? Colors.white
                                              : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        category.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Created on section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Created On',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _pickDate(),
                                  child: Text(
                                    DateFormat('EEE d MMM').format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _pickTime(),
                                  child: Text(
                                    DateFormat('HH:mm').format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Pay with section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSectionHeader(
                          context,
                          LucideIcons.creditCard,
                          'Pay with',
                          showEdit: true,
                          editLabel: 'Add',
                          onEdit: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddAccountScreen(),
                              ),
                            );
                            // Auto-select first account if none selected yet
                            if (mounted && _account == null) {
                              final updated = context.read<AccountProvider>().accounts;
                              if (updated.isNotEmpty) {
                                setState(() => _account = updated.first);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(builder: (context) {
                        final providerAccounts = context.watch<AccountProvider>().accounts;
                        // Auto-select when first account arrives without requiring re-open
                        if (_account == null && providerAccounts.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _account == null) {
                              setState(() => _account = providerAccounts.first);
                            }
                          });
                        }
                        if (providerAccounts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text(
                              'No accounts yet — tap Add to create one',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: providerAccounts.map((account) {
                            final isSelected = account.id == _account?.id;

                            return Padding(
                              key: ValueKey(account.id),
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () => _selectAccount(account),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOut,
                                  clipBehavior: Clip.hardEdge,
                                  height: 56,
                                  width: isSelected ? 160.0 : 56.0,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                            color: Theme.of(context).colorScheme.outlineVariant,
                                            width: 0.5,
                                          ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.shadow.withValues(
                                          alpha: isSelected ? 0.15 : 0.06,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (account.bankLogoPath != null)
                                                Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  padding: const EdgeInsets.all(4),
                                                  child: SvgPicture.asset(
                                                    account.bankLogoPath!,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              const SizedBox(width: 10),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    account.displayName,
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (account.cardIdentifier != null)
                                                    Text(
                                                      '**** ${account.cardIdentifier}',
                                                      style: TextStyle(
                                                        fontFamily: 'Archia',
                                                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.65),
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        )
                                      : Center(
                                          child: account.bankLogoPath != null
                                              ? Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: SvgPicture.asset(
                                                    account.bankLogoPath!,
                                                    fit: BoxFit.contain,
                                                  ),
                                                )
                                              : Text(
                                                  _accountInitials(account.displayName),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                ),
                                        ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                      }),

                      const SizedBox(height: 24),

                      // Tags section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              context,
                              LucideIcons.tags,
                              'Tags',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ..._tags.map((tag) => _buildTagChip(context, tag)),
                                _buildAddTagButton(context),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // Save button — only in normal mode
        if (!_showCalculator)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_amount.isNotEmpty &&
                        _merchant.trim().isNotEmpty &&
                        _selectedCategory.isNotEmpty)
                    ? _saveTransaction
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Save Transaction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Expression display — replaces the amount GestureDetector in calculator mode.
  // Rendered in the exact same parent position so Y never shifts.
  Widget _buildExpressionDisplay(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ₹ stays fixed — only the expression scrolls
        Text(
          '₹',
          style: TextStyle(
            fontFamily: 'Archia',
            fontSize: 64,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed-height row: scrolls horizontally, never wraps
              SizedBox(
                height: 72,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _exprScrollController,
                  child: Text(
                    _expression.isEmpty ? '0' : _expression,
                    style: TextStyle(
                      fontFamily: 'Archia',
                      fontSize: 64,
                      color: _expression.isEmpty
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              // Preview — always rendered to reserve space
              Text(
                _calcPreview.isEmpty ? ' ' : '= $_calcPreview',
                style: TextStyle(
                  fontFamily: 'Archia',
                  fontSize: 28,
                  color: _calcPreview.isEmpty
                      ? Colors.transparent
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String label, {
    bool showEdit = false,
    String editLabel = 'Edit',
    VoidCallback? onEdit,
  }) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: labelColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (showEdit) ...[
          const Spacer(),
          GestureDetector(
            onTap: onEdit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.pencil, size: 11, color: labelColor),
                const SizedBox(width: 4),
                Text(
                  editLabel,
                  style: TextStyle(fontSize: 11, color: labelColor),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    return GestureDetector(
      onTap: () => setState(() => _tags.remove(tag)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '#$tag',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary),
        ),
      ),
    );
  }

  Widget _buildAddTagButton(BuildContext context) {
    final subtleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: () => _showAddTagDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 12, color: subtleColor),
            const SizedBox(width: 4),
            Text(
              'Add tag',
              style: TextStyle(fontSize: 12, color: subtleColor),
            ),
          ],
        ),
      ),
    );
  }

  String _accountInitials(String name) {
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    setState(
      () => _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedDate.hour,
        _selectedDate.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null || !mounted) return;
    setState(
      () => _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _showAddTagDialog() async {
    String inputValue = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag', style: TextStyle(fontSize: 16)),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name (without #)'),
          onChanged: (v) => inputValue = v,
          onSubmitted: (_) => Navigator.of(ctx).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final tag = inputValue.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && mounted) {
      setState(() => _tags.add(tag));
    }
  }
}

class VoiceInputForm extends StatefulWidget {
  const VoiceInputForm({super.key});

  @override
  State<VoiceInputForm> createState() => _VoiceInputFormState();
}

class _VoiceInputFormState extends State<VoiceInputForm>
    with SingleTickerProviderStateMixin {
  VoiceStage _stage = VoiceStage.idle;
  String _transcribed = '';
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Waveform visualization
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [8, 16, 26, 12, 22, 10, 20, 14, 8, 24, 12, 18]
                  .asMap()
                  .entries
                  .map((entry) {
                    return Container(
                      width: 3,
                      height: _stage == VoiceStage.listening
                          ? entry.value.toDouble()
                          : 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.incomeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _stage == VoiceStage.idle
                ? 'Tap the mic to speak'
                : _stage == VoiceStage.listening
                ? 'Listening…'
                : "Got it! Here's what I heard:",
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),

          if (_transcribed.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _transcribed,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          if (_stage == VoiceStage.parsed) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildChip(
                  '₹450',
                  const Color(0xFFe8f5e9),
                  const Color(0xFF1a5c2a),
                ),
                _buildChip(
                  'Food & Drink',
                  const Color(0xFFfff3e0),
                  const Color(0xFF8a4a00),
                ),
                _buildChip(
                  'Today',
                  const Color(0xFFe3f2fd),
                  const Color(0xFF0d47a1),
                ),
                _buildChip(
                  'Swiggy',
                  const Color(0xFFf3e5f5),
                  const Color(0xFF6a1b9a),
                ),
              ],
            ),
          ],

          const Spacer(),

          if (_stage != VoiceStage.parsed)
            GestureDetector(
              onTap: _startListening,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _stage == VoiceStage.listening
                      ? AppTheme.expenseColor
                      : AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.mic,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _stage = VoiceStage.idle;
                      _transcribed = '';
                    }),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Retake',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Confirm & Save',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: textColor)),
    );
  }

  void _startListening() {
    setState(() => _stage = VoiceStage.listening);

    // Simulate listening and transcription
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(
          () => _transcribed = '"Paid four fifty at Swiggy for lunch today"',
        );
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) {
            setState(() => _stage = VoiceStage.parsed);
          }
        });
      }
    });
  }
}

enum VoiceStage { idle, listening, parsed }

class SmsImportForm extends StatefulWidget {
  const SmsImportForm({super.key});

  @override
  State<SmsImportForm> createState() => _SmsImportFormState();
}

class _SmsImportFormState extends State<SmsImportForm> {
  int _currentIndex = 0;
  final Set<String> _skipped = <String>{};

  List<SmsParsed> get _pending =>
      SmsParsed.smsParsed.where((sms) => !_skipped.contains(sms.id)).toList();

  SmsParsed? get _currentCard =>
      _currentIndex < _pending.length ? _pending[_currentIndex] : null;

  @override
  Widget build(BuildContext context) {
    if (_currentCard == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFe8f5e9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.check,
                size: 24,
                color: AppTheme.incomeColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'All SMS transactions reviewed!',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final category = Helpers.getCategoryById(_currentCard!.categoryId);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _pending.asMap().entries.map((entry) {
              final index = entry.key;
              final isActive = index == _currentIndex;
              final isCompleted = index < _currentIndex;

              return Container(
                width: isActive ? 22 : 7,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor
                      : isCompleted
                      ? AppTheme.successColor
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // SMS card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currentCard!.bank,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _currentCard!.date,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _currentCard!.transactionTitle,
                  style: TextStyle(
                    fontSize: 19,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Helpers.formatINR(_currentCard!.amount),
                      style: const TextStyle(
                        fontFamily: 'Archia',
                        fontSize: 26,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(category.bg.substring(1), radix: 16) +
                              0xFF000000,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryIconWidget(
                            category: category,
                            size: 14,
                            color: Color(
                              int.parse(
                                    category.color.substring(1),
                                    radix: 16,
                                  ) +
                                  0xFF000000,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(
                                int.parse(
                                      category.color.substring(1),
                                      radix: 16,
                                    ) +
                                    0xFF000000,
                              ),
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

          const SizedBox(height: 16),

          Text(
            '${_currentIndex + 1} of ${_pending.length} pending SMS',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _skip(_currentCard!.id),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Accept ✓',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Accept all remaining',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (_currentIndex < _pending.length - 1) {
      setState(() => _currentIndex++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip(String id) {
    setState(() {
      _skipped.add(id);
      if (_currentIndex >= _pending.length - 1) {
        Navigator.of(context).pop();
      }
    });
  }
}

class TransferForm extends StatelessWidget {
  const TransferForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.arrowLeftRight,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Transfer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Transfer money between accounts',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          const Text(
            'Coming Soon',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
