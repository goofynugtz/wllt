import 'dart:math' show min;
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
        .where((b) => b.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final banks = _filtered;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Bank',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.55,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${kAllBanks.length} banks available',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
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

            Expanded(
              child: banks.isEmpty
                  ? Center(
                      child: Text(
                        'No banks found',
                        style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: banks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _BankRow(
                        bank: banks[i],
                        onTap: () => Navigator.pop(context, banks[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bank row ───────────────────────────────────────────────────────────────────

class _BankRow extends StatelessWidget {
  final BankEntry bank;
  final VoidCallback onTap;

  const _BankRow({required this.bank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
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
                  ? SvgPicture.asset(bank.logoPath!, fit: BoxFit.contain)
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
    );
  }
}
