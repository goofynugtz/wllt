import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ── Card entry model ───────────────────────────────────────────────────────────

class CardEntry {
  final String type;    // 'debit' or 'credit'
  final String last4;
  final String network; // 'Visa', 'Mastercard', 'RuPay', 'Amex'
  final double? creditLimit;

  const CardEntry({
    required this.type,
    required this.last4,
    required this.network,
    this.creditLimit,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  String _cardType = 'debit';
  final _last4Controller = TextEditingController();
  String? _selectedNetwork;
  final _creditLimitController = TextEditingController();

  @override
  void dispose() {
    _last4Controller.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  bool get _canAdd =>
      _last4Controller.text.length == 4 && _selectedNetwork != null;

  void _submit() {
    if (!_canAdd) return;
    Navigator.pop(
      context,
      CardEntry(
        type: _cardType,
        last4: _last4Controller.text,
        network: _selectedNetwork!,
        creditLimit: _cardType == 'credit' && _creditLimitController.text.isNotEmpty
            ? double.tryParse(_creditLimitController.text)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Card',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.55,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'Link a debit or credit card',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Form ──────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARD TYPE
                    _SectionLabel(label: 'CARD TYPE'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TypeButton(
                          label: 'Debit',
                          selected: _cardType == 'debit',
                          onTap: () => setState(() => _cardType = 'debit'),
                        ),
                        const SizedBox(width: 8),
                        _TypeButton(
                          label: 'Credit',
                          selected: _cardType == 'credit',
                          onTap: () => setState(() => _cardType = 'credit'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // LAST 4 DIGITS
                    _SectionLabel(label: 'LAST 4 DIGITS', required: true),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
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
                              controller: _last4Controller,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
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

                    const SizedBox(height: 24),

                    // NETWORK
                    _SectionLabel(label: 'NETWORK', required: true),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _NetworkChip(
                          label: 'Visa',
                          selected: _selectedNetwork == 'Visa',
                          bg: const Color(0xFF1A1F71),
                          fg: Colors.white,
                          onTap: () => setState(() =>
                              _selectedNetwork = _selectedNetwork == 'Visa' ? null : 'Visa'),
                        ),
                        _NetworkChip(
                          label: 'Mastercard',
                          selected: _selectedNetwork == 'Mastercard',
                          bg: const Color(0xFFFFEBEE),
                          fg: const Color(0xFFB71C1C),
                          onTap: () => setState(() =>
                              _selectedNetwork = _selectedNetwork == 'Mastercard' ? null : 'Mastercard'),
                        ),
                        _NetworkChip(
                          label: 'RuPay',
                          selected: _selectedNetwork == 'RuPay',
                          bg: const Color(0xFFE3F2FD),
                          fg: const Color(0xFF097ACA),
                          onTap: () => setState(() =>
                              _selectedNetwork = _selectedNetwork == 'RuPay' ? null : 'RuPay'),
                        ),
                        _NetworkChip(
                          label: 'Amex',
                          selected: _selectedNetwork == 'Amex',
                          bg: const Color(0xFFEDE7F6),
                          fg: const Color(0xFF1565C0),
                          onTap: () => setState(() =>
                              _selectedNetwork = _selectedNetwork == 'Amex' ? null : 'Amex'),
                        ),
                      ],
                    ),

                    // CREDIT LIMIT (credit only)
                    if (_cardType == 'credit') ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _SectionLabel(label: 'CREDIT LIMIT'),
                          const SizedBox(width: 4),
                          Text(
                            '(optional)',
                            style: TextStyle(fontSize: 11, color: cs.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border.all(color: cs.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text('₹', style: TextStyle(fontSize: 18, color: cs.outline)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _creditLimitController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.5)),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 150000',
                                  hintStyle: TextStyle(
                                    fontSize: 16,
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
                  ],
                ),
              ),
            ),

            // ── CTA ────────────────────────────────────────────────────────────
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
                  onTap: _canAdd ? _submit : null,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _canAdd ? cs.onSurface : cs.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: _canAdd
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
                        Icon(LucideIcons.plus, size: 18, color: cs.surface),
                        const SizedBox(width: 8),
                        Text(
                          'Add Card',
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

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _SectionLabel({required this.label, this.required = false});

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
          height: 48,
          decoration: BoxDecoration(
            color: selected ? cs.onSurface : cs.surfaceContainerHighest,
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? fg : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
