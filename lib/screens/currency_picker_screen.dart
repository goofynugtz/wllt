import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/currencies.dart';
import '../providers/user_preferences_provider.dart';

// ── View mode ──────────────────────────────────────────────────────────────────

enum _CurrencyView { rows, twoCol, grid }

// ── Screen ─────────────────────────────────────────────────────────────────────

class CurrencyPickerScreen extends StatefulWidget {
  /// When false, selection is returned via Navigator.pop(code) without
  /// touching UserPreferencesProvider. Use this for account-level currency.
  final bool persistSelection;

  /// Pre-select this code instead of reading from global prefs.
  final String? initialCode;

  const CurrencyPickerScreen({
    super.key,
    this.persistSelection = true,
    this.initialCode,
  });

  @override
  State<CurrencyPickerScreen> createState() => _CurrencyPickerScreenState();
}

class _CurrencyPickerScreenState extends State<CurrencyPickerScreen> {
  String _query = '';
  late String _selectedCode;
  _CurrencyView _view = _CurrencyView.twoCol;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.initialCode ?? context.read<UserPreferencesProvider>().currency;
  }

  List<CurrencyInfo> get _filtered {
    if (_query.isEmpty) return kCurrencies;
    final q = _query.toLowerCase();
    return kCurrencies
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _select(String code) async {
    if (!widget.persistSelection) {
      if (mounted) Navigator.of(context).pop(code);
      return;
    }

    final prefs = context.read<UserPreferencesProvider>();
    final previousCode = prefs.currency;
    if (code == previousCode) return;

    final currencyInfo = kCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => kCurrencies.first,
    );

    bool convertHistory = true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change currency to ${currencyInfo.symbol} ${currencyInfo.code}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How should past transactions appear?'),
              const SizedBox(height: 12),
              RadioListTile<bool>(
                value: true,
                groupValue: convertHistory,
                onChanged: (v) => setDialogState(() => convertHistory = v!),
                title: Text('Convert all history to ${currencyInfo.code}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: convertHistory,
                onChanged: (v) => setDialogState(() => convertHistory = v!),
                title: const Text('Keep in original currencies'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rates shown reflect the exchange rate at the time of each transaction.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _selectedCode = code);
    await prefs.setCurrency(code);
    await prefs.setConvertHistoricalCurrency(convertHistory);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
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
                          'Currency',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.55,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '${kCurrencies.length} currencies available',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  _ViewToggle(
                    current: _view,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                ],
              ),
            ),

            // ── Search ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search currencies...',
                    hintStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                    prefixIcon: Icon(LucideIcons.search, size: 16, color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.searchX, size: 36, color: cs.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No results for "$_query"',
                            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : switch (_view) {
                      _CurrencyView.rows => _buildRowsView(filtered),
                      _CurrencyView.twoCol => ClipRect(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GridView.builder(
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 215 / 68,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _CurrencyDualTile(
                                currency: filtered[i],
                                isSelected: filtered[i].code == _selectedCode,
                                onTap: () => _select(filtered[i].code),
                              ),
                            ),
                          ),
                        ),
                      _CurrencyView.grid => GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _CurrencyTile(
                            currency: filtered[i],
                            isSelected: filtered[i].code == _selectedCode,
                            onTap: () => _select(filtered[i].code),
                          ),
                        ),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowsView(List<CurrencyInfo> currencies) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Column(
              children: currencies.asMap().entries.map((e) {
                return _CurrencyRowTile(
                  currency: e.value,
                  isFirst: e.key == 0,
                  isSelected: e.value.code == _selectedCode,
                  onTap: () => _select(e.value.code),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── View toggle ────────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final _CurrencyView current;
  final ValueChanged<_CurrencyView> onChanged;

  const _ViewToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(context, _CurrencyView.rows, LucideIcons.list),
          const SizedBox(width: 2),
          _btn(context, _CurrencyView.twoCol, LucideIcons.grip),
          const SizedBox(width: 2),
          _btn(context, _CurrencyView.grid, LucideIcons.layoutGrid),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, _CurrencyView view, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final active = current == view;
    return GestureDetector(
      onTap: () => onChanged(view),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: active ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 14, color: active ? cs.onSurface : cs.onSurfaceVariant),
      ),
    );
  }
}

// ── Currency symbol + flag badge ───────────────────────────────────────────────

class _CurrencySymbolBadge extends StatelessWidget {
  final CurrencyInfo currency;
  final double size;
  const _CurrencySymbolBadge({required this.currency, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final flagSize = size * 0.45;
    final offset = size * 0.09;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Center(
              child: Text(
                currency.symbol,
                style: TextStyle(
                  fontSize: size * 0.41,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -offset,
            right: -offset,
            child: Container(
              width: flagSize,
              height: flagSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: CountryFlag.fromCountryCode(
                currency.countryCode,
                height: flagSize,
                width: flagSize,
                shape: const Circle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Currency row tile ──────────────────────────────────────────────────────────

class _CurrencyRowTile extends StatelessWidget {
  final CurrencyInfo currency;
  final bool isFirst;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyRowTile({
    required this.currency,
    required this.isFirst,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: isFirst
                ? null
                : Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
          ),
          child: Row(
            children: [
              _CurrencySymbolBadge(currency: currency, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currency.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      '${currency.code} · ${currency.country}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Currency dual tile (2-col) ─────────────────────────────────────────────────

class _CurrencyDualTile extends StatelessWidget {
  final CurrencyInfo currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyDualTile({
    required this.currency,
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
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.surfaceContainerHigh
              : cs.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 2))]
              : null,
        ),
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CurrencySymbolBadge(currency: currency, size: 40),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currency.code,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          currency.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.check, size: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Currency grid tile ─────────────────────────────────────────────────────────

class _CurrencyTile extends StatelessWidget {
  final CurrencyInfo currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyTile({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: Colors.green, width: 2)
                  : Border.all(color: cs.outlineVariant, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (_, constraints) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Center(
                      child: _CurrencySymbolBadge(currency: currency, size: 34),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.code,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 9, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
