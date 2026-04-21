import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'package:country_flags/country_flags.dart';
import '../data/currencies.dart';
import '../providers/user_preferences_provider.dart';
import 'bank_picker_screen.dart';
import 'currency_picker_screen.dart';

// ── Card entry model (local UI only) ─────────────────────────────────────────

class _CardEntry {
  final String type;    // 'debit' or 'credit'
  final String last4;
  final String network; // 'Visa', 'Mastercard', 'RuPay', 'Amex'
  final double? creditLimit;

  const _CardEntry({
    required this.type,
    required this.last4,
    required this.network,
    this.creditLimit,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  BankEntry? _selectedBank;
  final _balanceController = TextEditingController();
  final List<_CardEntry> _cards = [];

  // Inline card form state
  bool _showCardForm = false;
  String _cardType = 'debit';
  final _last4Controller = TextEditingController();
  String? _selectedNetwork;
  final _creditLimitController = TextEditingController();

  @override
  void dispose() {
    _balanceController.dispose();
    _last4Controller.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _pickBank() async {
    final result = await Navigator.push<BankEntry>(
      context,
      MaterialPageRoute(builder: (_) => const BankPickerScreen()),
    );
    if (result != null) setState(() => _selectedBank = result);
  }

  Future<void> _pickCurrency() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CurrencyPickerScreen()),
    );
    // CurrencyPickerScreen saves to UserPreferencesProvider and pops —
    // the Consumer below will rebuild with the updated currency.
  }

  // ── Card form helpers ──────────────────────────────────────────────────────

  void _addCard() {
    if (_last4Controller.text.length != 4) return;
    if (_selectedNetwork == null) return;
    setState(() {
      _cards.add(_CardEntry(
        type: _cardType,
        last4: _last4Controller.text,
        network: _selectedNetwork!,
        creditLimit: _cardType == 'credit' && _creditLimitController.text.isNotEmpty
            ? double.tryParse(_creditLimitController.text)
            : null,
      ));
      _showCardForm = false;
      _last4Controller.clear();
      _creditLimitController.clear();
      _selectedNetwork = null;
      _cardType = 'debit';
    });
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
                          'New Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.55,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'Add a bank account',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  // Dynamic bank badge
                  _BankLogoBox(bank: _selectedBank, size: 36, borderRadius: 14),
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
                                if (_selectedBank != null)
                                  Row(
                                    children: [
                                      CountryFlag.fromCountryCode(
                                        _selectedBank!.countryCode,
                                        height: 12,
                                        width: 18,
                                        shape: const RoundedRectangle(2),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _selectedBank!.country,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
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
                    Consumer<UserPreferencesProvider>(
                      builder: (_, prefs, __) {
                        final code = prefs.currency;
                        return _FieldCard(
                          onTap: _pickCurrency,
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(LucideIcons.globe, size: 17, color: AppTheme.primaryColor),
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

                    // Add card button or inline form
                    if (!_showCardForm)
                      GestureDetector(
                        onTap: () => setState(() => _showCardForm = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
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
                      )
                    else
                      _InlineCardForm(
                        cardType: _cardType,
                        last4Controller: _last4Controller,
                        selectedNetwork: _selectedNetwork,
                        creditLimitController: _creditLimitController,
                        onCardTypeChanged: (t) => setState(() => _cardType = t),
                        onNetworkChanged: (n) => setState(() => _selectedNetwork = n),
                        onCancel: () => setState(() {
                          _showCardForm = false;
                          _last4Controller.clear();
                          _creditLimitController.clear();
                          _selectedNetwork = null;
                          _cardType = 'debit';
                        }),
                        onAdd: _addCard,
                      ),
                  ],
                ),
              ),
            ),

            // ── Bottom CTA ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: _selectedBank == null
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account creation coming soon!')),
                          );
                        },
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
                          'Create Account',
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

// ── Helper: currency name ─────────────────────────────────────────────────────

String _currencyName(String code) {
  try {
    return kCurrencies.firstWhere((c) => c.code == code).name;
  } catch (_) {
    return code;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ── Card chip ──────────────────────────────────────────────────────────────────

class _CardChip extends StatelessWidget {
  final _CardEntry card;
  final VoidCallback onRemove;

  const _CardChip({required this.card, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        border: Border.all(color: cs.outlineVariant),
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

// ── Inline card form ───────────────────────────────────────────────────────────

class _InlineCardForm extends StatelessWidget {
  final String cardType;
  final TextEditingController last4Controller;
  final String? selectedNetwork;
  final TextEditingController creditLimitController;
  final ValueChanged<String> onCardTypeChanged;
  final ValueChanged<String?> onNetworkChanged;
  final VoidCallback onCancel;
  final VoidCallback onAdd;

  const _InlineCardForm({
    required this.cardType,
    required this.last4Controller,
    required this.selectedNetwork,
    required this.creditLimitController,
    required this.onCardTypeChanged,
    required this.onNetworkChanged,
    required this.onCancel,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.primary, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card type toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CARD TYPE',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TypeButton(
                      label: 'Debit',
                      selected: cardType == 'debit',
                      onTap: () => onCardTypeChanged('debit'),
                    ),
                    const SizedBox(width: 8),
                    _TypeButton(
                      label: 'Credit',
                      selected: cardType == 'credit',
                      onTap: () => onCardTypeChanged('credit'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Last 4 digits
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST 4 DIGITS',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '•••• •••• ••••',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 4,
                          color: cs.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: last4Controller,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 17,
                            letterSpacing: 4,
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                          decoration: InputDecoration(
                            hintText: '0000',
                            hintStyle: TextStyle(
                              fontSize: 17,
                              letterSpacing: 4,
                              color: cs.onSurfaceVariant.withOpacity(0.4),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Network
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NETWORK',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _NetworkChip(label: 'Visa',       selected: selectedNetwork == 'Visa',       bg: const Color(0xFF1A1F71), fg: Colors.white,          onTap: () => onNetworkChanged(selectedNetwork == 'Visa' ? null : 'Visa')),
                    _NetworkChip(label: 'Mastercard',  selected: selectedNetwork == 'Mastercard', bg: const Color(0xFFFFEBEE), fg: const Color(0xFFB71C1C), onTap: () => onNetworkChanged(selectedNetwork == 'Mastercard' ? null : 'Mastercard')),
                    _NetworkChip(label: 'RuPay',       selected: selectedNetwork == 'RuPay',      bg: const Color(0xFFE3F2FD), fg: const Color(0xFF097ACA), onTap: () => onNetworkChanged(selectedNetwork == 'RuPay' ? null : 'RuPay')),
                    _NetworkChip(label: 'Amex',        selected: selectedNetwork == 'Amex',       bg: const Color(0xFFEDE7F6), fg: const Color(0xFF1565C0), onTap: () => onNetworkChanged(selectedNetwork == 'Amex' ? null : 'Amex')),
                  ],
                ),
              ],
            ),
          ),

          // Credit limit (credit only)
          if (cardType == 'credit') ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('CREDIT LIMIT',
                          style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Text('(optional)',
                          style: TextStyle(fontSize: 10, color: cs.outline)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text('₹', style: TextStyle(fontSize: 16, color: cs.outline)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: creditLimitController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withOpacity(0.5),
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 150000',
                              hintStyle: TextStyle(
                                fontSize: 14,
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
                ],
              ),
            ),
          ],

          // Cancel / Add Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text('Cancel',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: cs.onSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text('Add Card',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.surface)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card type button ───────────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected ? cs.onSurface : cs.surfaceContainerHighest,
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? cs.surface : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Network chip ───────────────────────────────────────────────────────────────

class _NetworkChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _NetworkChip({
    required this.label,
    required this.selected,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? bg : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [BoxShadow(color: bg.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? fg : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
