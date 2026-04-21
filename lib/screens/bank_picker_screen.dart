import 'dart:math' show min;
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ── Data ───────────────────────────────────────────────────────────────────────

class BankEntry {
  final String name;
  final String country;
  final String flag;
  final String countryCode; // ISO 3166-1 alpha-2, e.g. 'IN', 'US'
  final Color brandColor;
  final String? logoPath; // asset path or null → show initials

  const BankEntry({
    required this.name,
    required this.country,
    required this.flag,
    required this.countryCode,
    required this.brandColor,
    this.logoPath,
  });

  String get initials {
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.substring(0, min(2, name.length)).toUpperCase();
  }
}

const List<BankEntry> kAllBanks = [
  // India — with SVG assets
  BankEntry(name: 'HDFC Bank',            country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF004C8F), logoPath: 'assets/icons/banks/hdfc.svg'),
  BankEntry(name: 'ICICI Bank',           country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFB71C1C), logoPath: 'assets/icons/banks/icici.svg'),
  BankEntry(name: 'State Bank of India',  country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1565C0), logoPath: 'assets/icons/banks/sbi.svg'),
  BankEntry(name: 'Axis Bank',            country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF880E4F), logoPath: 'assets/icons/banks/axis.svg'),
  BankEntry(name: 'Kotak Mahindra Bank',  country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFE53935), logoPath: 'assets/icons/banks/kotak.svg'),
  BankEntry(name: 'Canara Bank',          country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1A237E), logoPath: 'assets/icons/banks/canara.svg'),
  BankEntry(name: 'Punjab National Bank', country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF0D47A1), logoPath: 'assets/icons/banks/pnb.svg'),
  // India — no SVG assets yet
  BankEntry(name: 'Bank of Baroda', country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF6A1B9A)),
  BankEntry(name: 'IndusInd Bank',  country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF00796B)),
  BankEntry(name: 'Yes Bank',       country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1976D2)),
  // United States — no SVG assets yet
  BankEntry(name: 'Chase Bank',      country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFF002B5C)),
  BankEntry(name: 'Bank of America', country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFFE31837)),
  BankEntry(name: 'Wells Fargo',     country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFFCE2222)),
  BankEntry(name: 'Citibank',        country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFF003B8E)),
  BankEntry(name: 'US Bank',         country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFF003087)),
  BankEntry(name: 'Capital One',     country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFFD03027)),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class BankPickerScreen extends StatefulWidget {
  const BankPickerScreen({super.key});

  @override
  State<BankPickerScreen> createState() => _BankPickerScreenState();
}

class _BankPickerScreenState extends State<BankPickerScreen> {
  String _query = '';

  List<BankEntry> get _filtered {
    if (_query.isEmpty) return kAllBanks;
    final q = _query.toLowerCase();
    return kAllBanks
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            b.country.toLowerCase().contains(q))
        .toList();
  }

  Map<String, List<BankEntry>> get _grouped {
    final result = <String, List<BankEntry>>{};
    for (final b in _filtered) {
      result.putIfAbsent(b.country, () => []).add(b);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _grouped;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header + search
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
                      child: Icon(LucideIcons.arrowLeft, size: 18, color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search banks...',
                          hintStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                          prefixIcon: Icon(LucideIcons.search, size: 16, color: cs.onSurfaceVariant),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Text(
                        'No banks found',
                        style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      children: [
                        for (final entry in grouped.entries) ...[
                          _CountryHeader(
                            countryCode: entry.value.first.countryCode,
                            country: entry.key.toUpperCase(),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              children: entry.value.asMap().entries.map((e) {
                                final isLast = e.key == entry.value.length - 1;
                                return _BankRow(
                                  bank: e.value,
                                  showDivider: !isLast,
                                  onTap: () => Navigator.pop(context, e.value),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Country header ─────────────────────────────────────────────────────────────

class _CountryHeader extends StatelessWidget {
  final String countryCode;
  final String country;

  const _CountryHeader({required this.countryCode, required this.country});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          CountryFlag.fromCountryCode(
            countryCode,
            height: 12,
            width: 18,
            shape: const RoundedRectangle(2),
          ),
          const SizedBox(width: 6),
          Text(
            country,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.0,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bank row ───────────────────────────────────────────────────────────────────

class _BankRow extends StatelessWidget {
  final BankEntry bank;
  final bool showDivider;
  final VoidCallback onTap;

  const _BankRow({
    required this.bank,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Badge: SVG or initials
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bank.logoPath != null
                        ? cs.surface
                        : bank.brandColor.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(14),
                    border: bank.logoPath != null
                        ? Border.all(color: cs.outlineVariant, width: 0.5)
                        : null,
                  ),
                  padding: bank.logoPath != null ? const EdgeInsets.all(7) : null,
                  child: bank.logoPath != null
                      ? SvgPicture.asset(
                          bank.logoPath!,
                          fit: BoxFit.contain,
                        )
                      : Center(
                          child: Text(
                            bank.initials,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: bank.brandColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Name
                Expanded(
                  child: Text(
                    bank.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              indent: 68,
              endIndent: 16,
              color: cs.outlineVariant,
            ),
        ],
      ),
    );
  }
}
