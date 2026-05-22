import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'package:country_flags/country_flags.dart';
import '../data/currencies.dart';
import '../providers/user_preferences_provider.dart';
import '../models/models.dart';
import '../providers/account_provider.dart';
import '../utils/helpers.dart';
import 'add_card_screen.dart';
import 'bank_picker_screen.dart';
import 'currency_picker_screen.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

class AddAccountScreen extends StatefulWidget {
  /// Pass to prefill the form for editing an existing account.
  final Account? initialAccount;

  const AddAccountScreen({super.key, this.initialAccount});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  BankEntry? _selectedBank;
  late final TextEditingController _balanceController;
  late final List<CardEntry> _cards;
  late String _selectedCurrencyCode;

  @override
  void initState() {
    super.initState();
    final acct = widget.initialAccount;
    _balanceController = TextEditingController(
      text: acct != null && acct.balance != 0
          ? acct.balance.abs().toStringAsFixed(acct.balance.truncateToDouble() == acct.balance ? 0 : 2)
          : '',
    );
    _cards = List<CardEntry>.from(acct?.cards ?? []);
    _selectedCurrencyCode = acct?.baseCurrency ??
        context.read<UserPreferencesProvider>().currency;
    if (acct?.bank != null) {
      try {
        _selectedBank = kAllBanks.firstWhere((b) => b.name == acct!.bank);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _pickBank() async {
    final result = await Navigator.push<BankEntry>(
      context,
      MaterialPageRoute(builder: (_) => BankPickerScreen(selectedBank: _selectedBank)),
    );
    if (result != null) setState(() => _selectedBank = result);
  }

  Future<void> _addCard() async {
    final result = await Navigator.push<CardEntry>(
      context,
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );
    if (result != null) setState(() => _cards.add(result));
  }

  Future<void> _pickCurrency() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => CurrencyPickerScreen(
        persistSelection: false,
        initialCode: _selectedCurrencyCode,
      )),
    );
    if (code != null) setState(() => _selectedCurrencyCode = code);
  }

  Future<void> _saveAccount() async {
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    final account = Account(
      id: widget.initialAccount?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: AccountType.bank,
      balance: balance,
      bank: _selectedBank!.name,
      bankLogoPath: _selectedBank!.logoPath,
      sparkline: widget.initialAccount?.sparkline ?? [balance],
      cards: _cards,
      baseCurrency: _selectedCurrencyCode,
    );
    final provider = context.read<AccountProvider>();
    if (widget.initialAccount != null) {
      await provider.updateAccount(account);
    } else {
      await provider.addAccount(account);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This removes the account. Linked transactions are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AccountProvider>().deleteAccount(widget.initialAccount!.id);
      if (mounted) Navigator.of(context).pop('deleted');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.arrowLeft, size: 18, color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialAccount != null ? 'Edit Account' : 'New Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.55,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          widget.initialAccount != null ? 'Update account details' : 'Add a bank account',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (widget.initialAccount != null)
                    IconButton(
                      icon: Icon(LucideIcons.trash2, color: Theme.of(context).colorScheme.error, size: 20),
                      onPressed: _confirmDelete,
                    ),
                ],
              ),
            ),

            // ── Form ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BANK *
                    _FieldLabel(label: 'BANK', required: true),
                    const SizedBox(height: 8),
                    _FieldCard(
                      onTap: _pickBank,
                      child: Row(
                        children: [
                          _BankLogoBox(bank: _selectedBank, size: 36, borderRadius: 14),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedBank?.name ?? 'Select a bank',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedBank != null
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 15, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CURRENCY
                    _FieldLabel(label: 'CURRENCY'),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final code = _selectedCurrencyCode;
                        final currencyInfo = _currencyInfo(code);
                        return _FieldCard(
                          onTap: _pickCurrency,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.13),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          currencyInfo?.symbol ?? code,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (currencyInfo != null)
                                      Positioned(
                                        bottom: -4,
                                        right: -4,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: CountryFlag.fromCountryCode(
                                            currencyInfo.countryCode,
                                            height: 18,
                                            width: 18,
                                            shape: const Circle(),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      code,
                                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                                    ),
                                    Text(
                                      _currencyName(code),
                                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(LucideIcons.chevronRight, size: 15, color: cs.onSurfaceVariant),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // BALANCE (optional)
                    Row(
                      children: [
                        _FieldLabel(label: 'BALANCE'),
                        const SizedBox(width: 4),
                        Text(
                          '(optional)',
                          style: TextStyle(fontSize: 11, color: cs.outlineVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _FieldCard(
                      child: Row(
                        children: [
                          Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 22,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _balanceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                              style: TextStyle(
                                fontSize: 22,
                                color: cs.onSurface.withOpacity(0.5),
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontSize: 22,
                                  color: cs.onSurfaceVariant.withOpacity(0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Enter the current available balance in this account',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CARDS (optional)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _FieldLabel(label: 'CARDS'),
                        Text(
                          'Optional',
                          style: TextStyle(fontSize: 11, color: cs.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Link debit or credit cards associated with this account. Only the last 4 digits are needed.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5),
                    ),
                    const SizedBox(height: 12),

                    // Card chips
                    if (_cards.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _cards.asMap().entries.map((e) {
                          return _CardChip(
                            card: e.value,
                            onRemove: () => setState(() => _cards.removeAt(e.key)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Add card button
                    GestureDetector(
                      onTap: _addCard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.plus, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Add Card',
                              style: TextStyle(fontSize: 13, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom CTA ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: _selectedBank == null ? null : _saveAccount,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _selectedBank != null
                          ? cs.onSurface
                          : cs.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: _selectedBank != null
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.check, size: 18, color: cs.surface),
                        const SizedBox(width: 8),
                        Text(
                          widget.initialAccount != null ? 'Update Account' : 'Create Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper: network logo ──────────────────────────────────────────────────────

String? _networkLogoPath(String network) => Helpers.networkLogoPath(network);

// ── Helper: currency name ─────────────────────────────────────────────────────

String _currencyName(String code) {
  try {
    return kCurrencies.firstWhere((c) => c.code == code).name;
  } catch (_) {
    return code;
  }
}

CurrencyInfo? _currencyInfo(String code) {
  try {
    return kCurrencies.firstWhere((c) => c.code == code);
  } catch (_) {
    return null;
  }
}

// ── Bank logo box ──────────────────────────────────────────────────────────────
// Used in both the header badge and the bank field card.

class _BankLogoBox extends StatelessWidget {
  final BankEntry? bank;
  final double size;
  final double borderRadius;

  const _BankLogoBox({
    required this.bank,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = bank?.brandColor ?? AppTheme.primaryColor;

    if (bank?.logoPath != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        padding: EdgeInsets.all(size * 0.18),
        child: SvgPicture.asset(bank!.logoPath!, fit: BoxFit.contain),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: bank != null
            ? Text(
                bank!.initials,
                style: TextStyle(
                  fontSize: size * 0.33,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.5,
                ),
              )
            : Icon(LucideIcons.wallet, size: size * 0.44, color: color),
      ),
    );
  }
}

// ── Field label ────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      required ? '$label *' : label,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
      ),
    );
  }
}

// ── Field card ─────────────────────────────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FieldCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// ── Card chip ──────────────────────────────────────────────────────────────────

class _CardChip extends StatelessWidget {
  final CardEntry card;
  final VoidCallback onRemove;

  const _CardChip({required this.card, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            card.type == 'credit' ? LucideIcons.creditCard : LucideIcons.wallet,
            size: 13,
            color: cs.onSurface,
          ),
          const SizedBox(width: 6),
          Text(
            '${card.type == 'credit' ? 'Credit' : 'Debit'} •••• ${card.last4}',
            style: TextStyle(fontSize: 12, color: cs.onSurface),
          ),
          const SizedBox(width: 6),
          if (_networkLogoPath(card.network) != null)
            SvgPicture.asset(
              _networkLogoPath(card.network)!,
              height: 14,
              fit: BoxFit.contain,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                card.network,
                style: const TextStyle(fontSize: 9, color: Color(0xFF097ACA)),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(LucideIcons.x, size: 11, color: cs.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

