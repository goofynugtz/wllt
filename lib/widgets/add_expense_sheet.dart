import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../ai/categorization_adapter.dart';
import '../ai/feedback_store.dart';
import '../data/currencies.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/account_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/ai_service.dart';
import '../services/exchange_rate_service.dart';
import '../utils/helpers.dart';
import 'category_icon_widget.dart';
import '../screens/add_account_screen.dart';
import '../screens/layout_screen.dart';
import '../screens/categories_screen.dart';
import 'amount_calculator.dart';

class AddTransactionPage extends StatefulWidget {
  final AddTransactionMethod method;
  final Transaction? editTransaction;

  const AddTransactionPage({
    super.key,
    required this.method,
    this.editTransaction,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  static const _methods = [
    AddTransactionMethod.expense,
    AddTransactionMethod.income,
    AddTransactionMethod.transfer,
  ];
  static const _labels = ['Expense', 'Income', 'Transfer'];

  late AddTransactionMethod _method;
  late final PageController _methodController;
  bool _isScrollerPressed = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.editTransaction;
    if (tx != null) {
      _method = tx.type == TransactionType.income
          ? AddTransactionMethod.income
          : AddTransactionMethod.expense;
    } else {
      _method = widget.method;
    }
    _methodController = PageController(
      initialPage: _methods.indexOf(_method).clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _methodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editTransaction != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isEdit ? 'Edit ' : 'Add ',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildMethodScroller(context),
                    ],
                  ),
                  Row(
                    children: [
                      if (isEdit) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () async {
                              final provider = context.read<TransactionProvider>();
                              await provider.deleteTransaction(widget.editTransaction!.id);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            icon: Icon(
                              LucideIcons.trash2,
                              size: 13,
                              color: cs.onErrorContainer,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            LucideIcons.x,
                            size: 13,
                            color: cs.onSecondaryContainer,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
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

  Widget _buildMethodScroller(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = _isScrollerPressed ? Colors.white : cs.primary;
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: labelColor,
    );

    return Listener(
      onPointerDown: (_) => setState(() => _isScrollerPressed = true),
      onPointerUp: (_) => setState(() => _isScrollerPressed = false),
      onPointerCancel: (_) => setState(() => _isScrollerPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: _isScrollerPressed ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Stack sizes to the invisible "Transfer" label (widest word),
            // PageView fills that rect and scrolls vertically one line at a time.
            Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: Text('Transfer', style: textStyle),
                ),
                Positioned.fill(
                  child: PageView.builder(
                    controller: _methodController,
                    scrollDirection: Axis.vertical,
                    itemCount: _labels.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _method = _methods[i]);
                    },
                    itemBuilder: (_, i) => Text(
                      _labels[i],
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 3),
            Icon(
              LucideIcons.chevronsUpDown,
              size: 11,
              color: _isScrollerPressed
                  ? Colors.white.withValues(alpha: 0.75)
                  : cs.primary.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    switch (_method) {
      case AddTransactionMethod.expense:
        return ManualEntryForm(
          key: const ValueKey('expense'),
          initialType: TransactionType.expense,
          editTransaction: widget.editTransaction,
        );
      case AddTransactionMethod.income:
        return ManualEntryForm(
          key: const ValueKey('income'),
          initialType: TransactionType.income,
          editTransaction: widget.editTransaction,
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
    with TickerProviderStateMixin {
  late TransactionType _type;
  String _amount = '';
  String _selectedCategory = 'food';
  String _merchant = '';
  DateTime _selectedDate = DateTime.now();
  final List<String> _tags = [];
  Account? _account;
  CardEntry? _selectedCard;
  bool _accountInitialized = false;
  bool _hadNoAccountsAtInit = false;
  bool _amountConverted = false;
  // Snapshots of the amount/account as first displayed (post currency-resolution) —
  // compared against live state to derive dirtiness; see _hasChanges.
  String _initialAmount = '';
  String _initialAccountId = '';
  // The amount as last typed/loaded, and the currency it's expressed in.
  // Every displayed amount is (re)computed from this single anchor via the
  // Hive-backed ExchangeRateService cache — never from the currently
  // displayed value — so switching accounts back and forth never compounds
  // rounding drift; the same anchor always converts to the same result.
  String _anchorAmount = '';
  String _anchorCurrency = '';
  bool _showCalculator = false;
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();

  // Calculator state — expression lives here so the display never moves
  String _expression = '';
  String _calcPreview = '';
  late AnimationController _calcController;
  late Animation<Offset> _calcSlide;
  final ScrollController _exprScrollController = ScrollController();

  String? _aiSuggestedCategory;
  Timer? _aiDebounce;
  final FeedbackStore _feedbackStore = FeedbackStore();
  bool _feedbackStoreReady = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    final tx = widget.editTransaction;
    if (tx != null) {
      _type = widget.initialType;
      final amt = tx.amount;
      _amount = amt == amt.truncate() ? amt.toInt().toString() : amt.toStringAsFixed(2);
      _anchorAmount = _amount;
      _anchorCurrency = tx.baseCurrency;
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

    _feedbackStore.init().then((_) {
      if (mounted) setState(() => _feedbackStoreReady = true);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          if (_aiSuggestedCategory != null) _pulseController.forward();
        }
      });
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_accountInitialized) {
      final accounts = context.read<AccountProvider>().accounts;
      final tx = widget.editTransaction;
      if (tx != null) {
        // Respect a transaction saved with no account — don't force one on.
        _account = accounts.where((a) => a.id == tx.account).firstOrNull;
      } else if (accounts.isNotEmpty) {
        _account = accounts.first;
      }
      _hadNoAccountsAtInit = accounts.isEmpty;
      _accountInitialized = true;
      _initialAccountId = _account?.id ?? '';
    }
    if (!_amountConverted && widget.editTransaction != null) {
      // Match whatever currency is actually shown (the selected account's,
      // falling back to the global preference) — not blindly the global
      // preference — otherwise the amount and the currency label disagree.
      final targetCurrency = _account?.baseCurrency ??
          context.read<UserPreferencesProvider>().currency;
      _amount = _convertedAmount(_anchorAmount, _anchorCurrency, targetCurrency);
      _amountConverted = true;
      _initialAmount = _amount;
    }
  }

  // Converts [amountStr] from [fromCurrency] to [toCurrency] via the same
  // Hive-backed rate cache (ExchangeRateService) the rest of the app uses
  // for display conversion — always a single hop from the stable anchor,
  // so repeated conversions never compound rounding.
  String _convertedAmount(String amountStr, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency || amountStr.isEmpty) return amountStr;
    final amountValue = double.tryParse(amountStr);
    if (amountValue == null) return amountStr;
    final snapshot = ExchangeRateService.instance.getCachedSnapshot(fromCurrency, _selectedDate);
    final converted = Helpers.convertAmount(amountValue, fromCurrency, toCurrency, snapshot?.rates);
    return converted == converted.truncate()
        ? converted.toInt().toString()
        : converted.toStringAsFixed(2);
  }

  // True once any field differs from the original record — gates the Save
  // button in edit mode so an untouched record can't be silently re-saved.
  // Computed (not a manually-flipped flag) so every field is covered by
  // construction instead of requiring a setState call to remember to set it.
  bool get _hasChanges {
    final tx = widget.editTransaction;
    if (tx == null) return true;
    return _type != tx.type ||
        _merchant.trim() != tx.transactionTitle.trim() ||
        _amount != _initialAmount ||
        _selectedCategory != tx.categoryId ||
        _selectedDate != tx.date ||
        (_account?.id ?? '') != _initialAccountId ||
        !_sameTags(_tags, tx.tags);
  }

  bool _sameTags(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _calcController.dispose();
    _exprScrollController.dispose();
    _aiDebounce?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    final amountValue = double.tryParse(_amount);
    if (amountValue == null || amountValue <= 0) return;
    if (_merchant.trim().isEmpty) return;

    final userCurrency =
        context.read<UserPreferencesProvider>().currency;
    final txCurrency = _account?.baseCurrency ?? userCurrency;

    debugPrint(
      '[AddExpense] Saving transaction: '
      'title="${_merchant.trim()}" '
      'amount=$amountValue '
      'type=${_type.name} '
      'date=${_selectedDate.toIso8601String()} '
      'baseCurrency=$txCurrency '
      'account=${_account?.id ?? "none"}',
    );

    // Fire-and-forget: caches snapshot for both account currency and user currency
    // so transactions screen can convert account→user currency sync.
    debugPrint('[AddExpense] Triggering ExchangeRateService.fetchSnapshot($txCurrency, ${_selectedDate.toIso8601String()})');
    ExchangeRateService.instance
        .fetchSnapshot(txCurrency, _selectedDate)
        .ignore();

    final provider = context.read<TransactionProvider>();
    final tx = Transaction(
      id: widget.editTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      transactionTitle: _merchant.trim(),
      categoryId: _selectedCategory,
      amount: amountValue,
      type: _type,
      date: _selectedDate,
      account: _account?.id ?? '',
      tags: List.from(_tags),
      baseCurrency: txCurrency,
    );

    if (widget.editTransaction != null) {
      await provider.updateTransaction(tx);
    } else {
      await provider.addTransaction(tx);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _selectPaymentMethod(Account account, CardEntry? card) {
    setState(() {
      _amount = _convertedAmount(_anchorAmount, _anchorCurrency, account.baseCurrency);
      _account = account;
      _selectedCard = card;
    });
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
        // Manual edit — this becomes the new source of truth for future
        // account-switch conversions, in whatever currency is showing now.
        _anchorAmount = result;
        _anchorCurrency = _account?.baseCurrency ??
            context.read<UserPreferencesProvider>().currency;
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
    final effectiveCurrency = _account?.baseCurrency ?? prefs.currency;
    final currencySymbol = kCurrencies
        .firstWhere((c) => c.code == effectiveCurrency,
            orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'))
        .symbol;
    final displayCategories = prefs.orderedCategories;

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
                  onTap: () {
                    if (_showCalculator) {
                      _closeCalculator(_calcTryEvaluate(_expression) ?? _expression);
                    }
                  },
                  onChanged: (v) {
                    setState(() => _merchant = v);
                    _requestAiCategory(v);
                  },
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
                    ? _buildExpressionDisplay(context, currencySymbol)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _openCalculator,
                            child: Text(
                              '$currencySymbol ${_amount.isEmpty ? '0' : _amount}',
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
                                onTap: () {
                                  if (_aiSuggestedCategory != null &&
                                      _aiSuggestedCategory != category.id &&
                                      _feedbackStoreReady) {
                                    _feedbackStore.recordCorrection(
                                      merchant: _merchant,
                                      aiSuggested: _aiSuggestedCategory!,
                                      userChose: category.id,
                                    );
                                  }
                                  _setAiSuggestion(null);
                                  setState(() => _selectedCategory = category.id);
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    category.id == _aiSuggestedCategory
                                        ? AnimatedBuilder(
                                            animation: _pulseAnim,
                                            builder: (_, child) {
                                              return Container(
                                                width: 72,
                                                height: 72,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: accentColor.withValues(
                                                        alpha: 0.4 * _pulseAnim.value,
                                                      ),
                                                      blurRadius:
                                                          16 * _pulseAnim.value,
                                                      spreadRadius:
                                                          4 * _pulseAnim.value,
                                                    ),
                                                  ],
                                                ),
                                                child: child,
                                              );
                                            },
                                            child: _buildCategoryCircle(
                                              context,
                                              category,
                                              isSelected,
                                              accentColor,
                                            ),
                                          )
                                        : _buildCategoryCircle(
                                            context,
                                            category,
                                            isSelected,
                                            accentColor,
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
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
                        // (only if there were none at open — don't override a
                        // transaction that was intentionally saved with no account).
                        if (_account == null && _hadNoAccountsAtInit && providerAccounts.isNotEmpty) {
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
                        // Flatten accounts into payable items:
                        // accounts without cards → account chip
                        // accounts with cards    → one chip per card
                        final items = <({Account account, CardEntry? card})>[];
                        for (final a in providerAccounts) {
                          if (a.cards.isEmpty) {
                            items.add((account: a, card: null));
                          } else {
                            for (final c in a.cards) {
                              items.add((account: a, card: c));
                            }
                          }
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: items.map((item) {
                              final account = item.account;
                              final card    = item.card;
                              final isSelected = account.id == _account?.id &&
                                  (card == null
                                      ? _selectedCard == null
                                      : _selectedCard?.last4 == card.last4 && _selectedCard?.network == card.network);
                              final networkPath = card != null ? Helpers.networkLogoPath(card.network) : null;

                              return Padding(
                                key: ValueKey(card == null ? account.id : '${account.id}_${card.last4}'),
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () => _selectPaymentMethod(account, card),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedSize(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeInOut,
                                    child: Container(
                                      height: 56,
                                      width: isSelected ? null : 56.0,
                                      clipBehavior: Clip.hardEdge,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: isSelected
                                            ? null
                                            : Border.all(
                                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                                                    SizedBox(
                                                      width: 28,
                                                      height: 28,
                                                      child: card != null && networkPath != null
                                                          ? Stack(
                                                              fit: StackFit.expand,
                                                              children: [
                                                                SvgPicture.asset(account.bankLogoPath!, fit: BoxFit.contain),
                                                                Positioned(
                                                                  right: -2,
                                                                  bottom: -2,
                                                                  child: Container(
                                                                    padding: const EdgeInsets.all(2),
                                                                    decoration: const BoxDecoration(
                                                                      color: Colors.white,
                                                                      shape: BoxShape.circle,
                                                                    ),
                                                                    child: SvgPicture.asset(networkPath, height: 12, fit: BoxFit.contain),
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          : SvgPicture.asset(account.bankLogoPath!, fit: BoxFit.contain),
                                                    ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        account.displayName,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        ),
                                                      ),
                                                      Text(
                                                        card != null
                                                            ? '•••• ${card.last4}  ·  ${account.baseCurrency}'
                                                            : account.baseCurrency,
                                                        style: TextStyle(
                                                          fontFamily: card != null ? 'Archia' : null,
                                                          fontSize: 10,
                                                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.65),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                              ),
                                            )
                                          : Center(
                                              child: card != null
                                                  ? (account.bankLogoPath != null && networkPath != null
                                                      // Composite: bank logo + network badge
                                                      ? Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            Padding(
                                                              padding: const EdgeInsets.all(12),
                                                              child: SvgPicture.asset(account.bankLogoPath!, fit: BoxFit.contain),
                                                            ),
                                                            Positioned(
                                                              right: 2,
                                                              bottom: 2,
                                                              child: Container(
                                                                padding: const EdgeInsets.all(2),
                                                                decoration: const BoxDecoration(
                                                                  color: Colors.white,
                                                                  shape: BoxShape.circle,
                                                                ),
                                                                child: SvgPicture.asset(networkPath, height: 18, fit: BoxFit.contain),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : networkPath != null
                                                          ? Padding(
                                                              padding: const EdgeInsets.all(14),
                                                              child: SvgPicture.asset(networkPath, fit: BoxFit.contain),
                                                            )
                                                          : Text(
                                                              card.network.substring(0, 2).toUpperCase(),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w700,
                                                                color: Theme.of(context).colorScheme.onSurface,
                                                              ),
                                                            ))
                                                  : (account.bankLogoPath != null
                                                      ? Padding(
                                                          padding: const EdgeInsets.all(12),
                                                          child: SvgPicture.asset(account.bankLogoPath!, fit: BoxFit.contain),
                                                        )
                                                      : Text(
                                                          _accountInitials(account.displayName),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: Theme.of(context).colorScheme.onSurface,
                                                          ),
                                                        )),
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
                        _selectedCategory.isNotEmpty &&
                        (widget.editTransaction == null || _hasChanges))
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
  Widget _buildExpressionDisplay(BuildContext context, String currencySymbol) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // currency symbol stays fixed — only the expression scrolls
        Text(
          currencySymbol,
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
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
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

  void _setAiSuggestion(String? cat) {
    setState(() => _aiSuggestedCategory = cat);
    if (cat != null) {
      _pulseController.forward();
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _requestAiCategory(String merchant) {
    _aiDebounce?.cancel();
    if (merchant.trim().length < 2) {
      if (_aiSuggestedCategory != null) _setAiSuggestion(null);
      return;
    }
    _aiDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final aiProvider = context.read<AiProvider>();
      final sub = context.read<SubscriptionProvider>();
      if (!aiProvider.isReady || !sub.isPro) return;

      // FeedbackStore correction takes priority
      if (_feedbackStoreReady) {
        final correction = _feedbackStore.lookup(merchant);
        if (correction != null && _selectedCategory != correction) {
          _setAiSuggestion(correction);
          return;
        }
      }

      // Deterministic map + AI fallback
      final prefs = context.read<UserPreferencesProvider>();
      final categoryIds = prefs.activeCategories.isNotEmpty
          ? prefs.activeCategories
          : Category.categories.map((c) => c.id).toList();

      final suggested = await CategorizationAdapter.suggest(
        merchant: merchant,
        availableCategories: categoryIds,
        infer: (p) => AiService.instance.infer(p, temperature: 0.1, maxTokens: 10),
      );
      if (mounted && suggested != null && suggested != _selectedCategory) {
        _setAiSuggestion(suggested);
      }
    });
  }

  Widget _buildCategoryCircle(
    BuildContext context,
    Category category,
    bool isSelected,
    Color accentColor,
  ) {
    return Container(
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
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
                width: 0.5,
              ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .colorScheme
                .shadow
                .withValues(alpha: 0.06),
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
    );
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
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
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
