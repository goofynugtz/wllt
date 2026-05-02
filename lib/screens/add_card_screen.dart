import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

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

// ── Network definition ─────────────────────────────────────────────────────────

class _NetworkDef {
  final List<Color> cardGradient;
  final Color chipBg;
  final String? assetPath;

  const _NetworkDef({
    required this.cardGradient,
    required this.chipBg,
    this.assetPath,
  });
}

const _kNetworks = <String, _NetworkDef>{
  'Visa': _NetworkDef(
    cardGradient: [Color(0xFF10215A), Color(0xFF1A6EC7)],
    chipBg: Color(0xFFEBF3FA),
    assetPath: 'assets/icons/networks/visa.svg',
  ),
  'Mastercard': _NetworkDef(
    cardGradient: [Color(0xFF1C1C1C), Color(0xFFB0221A)],
    chipBg: Color(0xFFFFF4EE),
    assetPath: 'assets/icons/networks/mastercard.svg',
  ),
  'RuPay': _NetworkDef(
    cardGradient: [Color(0xFF003D7A), Color(0xFF097ACA)],
    chipBg: Color(0xFFE3F2FD),
    assetPath: 'assets/icons/networks/rupay.svg',
  ),
  'Amex': _NetworkDef(
    cardGradient: [Color(0xFF1A3A5C), Color(0xFF2E6FA8)],
    chipBg: Color(0xFFF1F9FF),
    assetPath: 'assets/icons/networks/amex.svg',
  ),
};

// ── Screen ─────────────────────────────────────────────────────────────────────

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen>
    with SingleTickerProviderStateMixin {
  String _cardType = 'debit';
  final _last4Controller = TextEditingController();
  String? _selectedNetwork;
  final _creditLimitController = TextEditingController();

  late final AnimationController _cardAnimController;
  late Animation<double> _cardScaleAnim;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _cardScaleAnim = Tween<double>(begin: 0.94, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_cardAnimController);
    _cardAnimController.forward();
  }

  @override
  void dispose() {
    _last4Controller.dispose();
    _creditLimitController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  bool get _canAdd =>
      _last4Controller.text.length == 4 && _selectedNetwork != null;

  void _onNetworkTap(String name) {
    setState(() {
      _selectedNetwork = _selectedNetwork == name ? null : name;
    });
    _cardAnimController
      ..reset()
      ..forward();
  }

  void _submit() {
    if (!_canAdd) return;
    Navigator.pop(
      context,
      CardEntry(
        type: _cardType,
        last4: _last4Controller.text,
        network: _selectedNetwork!,
        creditLimit: _cardType == 'credit' &&
                _creditLimitController.text.isNotEmpty
            ? double.tryParse(_creditLimitController.text)
            : null,
      ),
    );
  }

  List<Color> get _activeGradient {
    if (_selectedNetwork != null) {
      return _kNetworks[_selectedNetwork]!.cardGradient;
    }
    final hsl = HSLColor.fromColor(AppTheme.primaryColor);
    return [
      hsl.withLightness(0.12).toColor(),
      hsl.withLightness(0.38).toColor(),
    ];
  }

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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.arrowLeft,
                          size: 18, color: cs.onSurface),
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
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Form ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Live card preview ──────────────────────────────────
                    ScaleTransition(
                      scale: _cardScaleAnim,
                      child: _CardPreview(
                        cardType: _cardType,
                        last4: _last4Controller.text,
                        network: _selectedNetwork,
                        gradient: _activeGradient,
                        networkDef: _selectedNetwork != null
                            ? _kNetworks[_selectedNetwork]
                            : null,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Card type ──────────────────────────────────────────
                    _FieldLabel(label: 'CARD TYPE'),
                    const SizedBox(height: 10),
                    _CardTypeToggle(
                      value: _cardType,
                      onChanged: (v) => setState(() => _cardType = v),
                    ),

                    const SizedBox(height: 24),

                    // ── Last 4 digits ──────────────────────────────────────
                    _FieldLabel(label: 'LAST 4 DIGITS', required: true),
                    const SizedBox(height: 10),
                    _Last4Field(
                      controller: _last4Controller,
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 24),

                    // ── Network ────────────────────────────────────────────
                    _FieldLabel(label: 'NETWORK', required: true),
                    const SizedBox(height: 10),
                    _NetworkGrid(
                      selected: _selectedNetwork,
                      onSelect: _onNetworkTap,
                    ),

                    // ── Credit limit ───────────────────────────────────────
                    if (_cardType == 'credit') ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _FieldLabel(label: 'CREDIT LIMIT'),
                          const SizedBox(width: 4),
                          Text(
                            '(optional)',
                            style:
                                TextStyle(fontSize: 11, color: cs.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _CreditLimitField(
                          controller: _creditLimitController),
                    ],
                  ],
                ),
              ),
            ),

            // ── CTA ─────────────────────────────────────────────────────────
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _canAdd
                          ? cs.onSurface
                          : cs.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: _canAdd
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
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

// ── Card preview ───────────────────────────────────────────────────────────────

class _CardPreview extends StatelessWidget {
  final String cardType;
  final String last4;
  final String? network;
  final List<Color> gradient;
  final _NetworkDef? networkDef;

  const _CardPreview({
    required this.cardType,
    required this.last4,
    required this.network,
    required this.gradient,
    required this.networkDef,
  });

  @override
  Widget build(BuildContext context) {
    final display = last4.isEmpty ? '————' : last4.padRight(4, '—');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: 204,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.6, -1.0),
          end: const Alignment(0.6, 1.0),
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.5),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circles
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -30,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Card content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: EMV chip + contactless
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _EmvChip(),
                    Icon(
                      LucideIcons.wifi,
                      size: 20,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ],
                ),

                const Spacer(),

                // Card number
                Text(
                  '••••   ••••   ••••   $display',
                  style: const TextStyle(
                    fontFamily: 'Archia',
                    fontSize: 18,
                    letterSpacing: 1.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom row: type label + network badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      cardType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.5,
                        color: Colors.white.withOpacity(0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    _CardNetworkBadge(
                      network: network,
                      networkDef: networkDef,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── EMV chip ───────────────────────────────────────────────────────────────────

class _EmvChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 29,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4A843), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: CustomPaint(painter: _ChipPainter()),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * 0.38),
        Offset(size.width, size.height * 0.38), paint);
    canvas.drawLine(Offset(0, size.height * 0.62),
        Offset(size.width, size.height * 0.62), paint);
    canvas.drawLine(Offset(size.width * 0.5, 0),
        Offset(size.width * 0.5, size.height), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.18, size.height * 0.18,
            size.width * 0.64, size.height * 0.64),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter o) => false;
}

// ── Network badge on card ──────────────────────────────────────────────────────

class _CardNetworkBadge extends StatelessWidget {
  final String? network;
  final _NetworkDef? networkDef;

  const _CardNetworkBadge(
      {required this.network, required this.networkDef});

  @override
  Widget build(BuildContext context) {
    if (network == null) {
      return Text(
        'SELECT NETWORK',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 2,
          color: Colors.white.withOpacity(0.35),
        ),
      );
    }

    if (networkDef?.assetPath != null) {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
        child: SvgPicture.asset(
          networkDef!.assetPath!,
          height: 20,
          fit: BoxFit.contain,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(5),
        border:
            Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        network!.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Card type toggle ───────────────────────────────────────────────────────────

class _CardTypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CardTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TypeSegment(
            icon: LucideIcons.wallet,
            label: 'Debit',
            selected: value == 'debit',
            onTap: () => onChanged('debit'),
          ),
          _TypeSegment(
            icon: LucideIcons.creditCard,
            label: 'Credit',
            selected: value == 'credit',
            onTap: () => onChanged('credit'),
          ),
        ],
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? cs.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? cs.surface : cs.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? cs.surface : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Last 4 field ───────────────────────────────────────────────────────────────

class _Last4Field extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _Last4Field({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filled = controller.text.length == 4;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filled
              ? AppTheme.primaryColor.withOpacity(0.4)
              : cs.outlineVariant.withOpacity(0.5),
          width: filled ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '••••   ••••   ••••',
            style: TextStyle(
              fontFamily: 'Archia',
              fontSize: 15,
              letterSpacing: 2,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ' ',
            style: TextStyle(fontSize: 18, color: cs.outlineVariant),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: 'Archia',
                fontSize: 20,
                letterSpacing: 5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                hintText: '0000',
                hintStyle: TextStyle(
                  fontFamily: 'Archia',
                  fontSize: 20,
                  letterSpacing: 5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                counterText: '',
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: filled
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${controller.text.length}/4',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: filled
                    ? AppTheme.primaryColor
                    : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Network grid ───────────────────────────────────────────────────────────────

class _NetworkGrid extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _NetworkGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final networks = _kNetworks.keys.toList();
    return Row(
      children: networks.map((name) {
        final def = _kNetworks[name]!;
        final isSelected = selected == name;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: name != networks.last ? 10 : 0,
            ),
            child: _NetworkChip(
              name: name,
              def: def,
              isSelected: isSelected,
              onTap: () => onSelect(name),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  final String name;
  final _NetworkDef def;
  final bool isSelected;
  final VoidCallback onTap;

  const _NetworkChip({
    required this.name,
    required this.def,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        height: 52,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? cs.onSurface : cs.outlineVariant.withOpacity(0.5),
            width: isSelected ? 2.0 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: def.assetPath != null
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    def.assetPath!,
                    fit: BoxFit.contain,
                  ),
                )
              : Text(
                  name,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isSelected ? Colors.white : def.cardGradient.first,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}

// ── Credit limit field ─────────────────────────────────────────────────────────

class _CreditLimitField extends StatelessWidget {
  final TextEditingController controller;

  const _CreditLimitField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 17,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: 16, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. 1,50,000',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: cs.onSurfaceVariant.withOpacity(0.45),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
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
