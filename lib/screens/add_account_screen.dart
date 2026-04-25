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
  final List<CardEntry> _cards = [];

  @override
  void initState() {
    super.initState();
    final acct = widget.initialAccount;
    _balanceController = TextEditingController(
      text: acct != null && acct.balance != 0
          ? acct.balance.abs().toStringAsFixed(acct.balance.truncateToDouble() == acct.balance ? 0 : 2)
          : '',
    );
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
      MaterialPageRoute(builder: (_) => const BankPickerScreen()),
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CurrencyPickerScreen()),
    );
    // CurrencyPickerScreen saves to UserPreferencesProvider and pops —
    // the Consumer below will rebuild with the updated currency.
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

                    // Add card button
                    GestureDetector(
                      onTap: _addCard,
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

