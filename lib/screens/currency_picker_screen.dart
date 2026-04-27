import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/currencies.dart';
import '../providers/user_preferences_provider.dart';

class CurrencyPickerScreen extends StatefulWidget {
  const CurrencyPickerScreen({super.key});

  @override
  State<CurrencyPickerScreen> createState() => _CurrencyPickerScreenState();
}

class _CurrencyPickerScreenState extends State<CurrencyPickerScreen> {
  String _query = '';
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = context.read<UserPreferencesProvider>().currency;
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
    setState(() => _selectedCode = code);
    await context.read<UserPreferencesProvider>().setCurrency(code);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // ── Fixed header ──────────────────────────────────────────────────
          ColoredBox(
            color: cs.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                            child: Icon(
                              LucideIcons.arrowLeft,
                              size: 18,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Currency',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(fontSize: 15, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search currencies...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: cs.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Scrollable list ───────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.searchX,
                          size: 36,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No results for "$_query"',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return _CurrencyRow(
                        currency: c,
                        isSelected: c.code == _selectedCode,
                        onTap: () => _select(c.code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  final CurrencyInfo currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyRow({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.secondaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Text(
                        currency.symbol,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CountryFlag.fromCountryCode(
                        currency.countryCode,
                        height: 20,
                        width: 20,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${currency.code} · ${currency.country}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.check,
                  size: 14,
                  color: cs.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
