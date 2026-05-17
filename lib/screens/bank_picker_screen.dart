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
  // ── India ────────────────────────────────────────────────────────────────────
  BankEntry(name: 'HDFC Bank',                  country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF004C8F), logoPath: 'assets/icons/banks/HDFC Bank.svg'),
  BankEntry(name: 'ICICI Bank',                 country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFB71C1C), logoPath: 'assets/icons/banks/ICICI Bank.svg'),
  BankEntry(name: 'State Bank of India',        country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1565C0), logoPath: 'assets/icons/banks/State Bank of India.svg'),
  BankEntry(name: 'Axis Bank',                  country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF880E4F), logoPath: 'assets/icons/banks/Axis bank.svg'),
  BankEntry(name: 'Kotak Mahindra Bank',        country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFE53935), logoPath: 'assets/icons/banks/Kotak Mahindra Bank.svg'),
  BankEntry(name: 'Canara Bank',                country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1A237E), logoPath: 'assets/icons/banks/Canara Bank.svg'),
  BankEntry(name: 'Punjab National Bank',       country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF0D47A1), logoPath: 'assets/icons/banks/Punjab National Bank.svg'),
  BankEntry(name: 'Bank of Baroda',             country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFF37021), logoPath: 'assets/icons/banks/Bank of Baroda.svg'),
  BankEntry(name: 'IndusInd Bank',              country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF00796B), logoPath: 'assets/icons/banks/Induslnd Bank.svg'),
  BankEntry(name: 'Yes Bank',                   country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1976D2), logoPath: 'assets/icons/banks/Yes Bank.svg'),
  BankEntry(name: 'Airtel Payments Bank',       country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFE40000), logoPath: 'assets/icons/banks/Airtel Payments Bank.svg'),
  BankEntry(name: 'AU Small Finance Bank',      country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/AU Small Finance Bank.svg'),
  BankEntry(name: 'Bandhan Bank',               country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1B4F82), logoPath: 'assets/icons/banks/Bandhan Bank.svg'),
  BankEntry(name: 'Bank of India',              country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1B5E20), logoPath: 'assets/icons/banks/Bank of India.svg'),
  BankEntry(name: 'Bank of Maharashtra',        country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1565C0), logoPath: 'assets/icons/banks/Bank of Maharastra.svg'),
  BankEntry(name: 'Central Bank of India',      country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFB71C1C), logoPath: 'assets/icons/banks/Central Bank of India.svg'),
  BankEntry(name: 'City Union Bank',            country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1565C0), logoPath: 'assets/icons/banks/City Union Bank.svg'),
  BankEntry(name: 'CSB Bank',                   country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF004B8D), logoPath: 'assets/icons/banks/CSB Bank.svg'),
  BankEntry(name: 'DCB Bank',                   country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF00579B), logoPath: 'assets/icons/banks/DCB Bank.svg'),
  BankEntry(name: 'Dhanlaxmi Bank',             country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF8B0000), logoPath: 'assets/icons/banks/Dhanlaxmi Bank.svg'),
  BankEntry(name: 'ESAF Small Finance Bank',    country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF0075BE), logoPath: 'assets/icons/banks/ESAF Small Finance Bank Ltd.svg'),
  BankEntry(name: 'FINO Payments Bank',         country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/FINO Payments Bank.svg'),
  BankEntry(name: 'IDBI Bank',                  country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/IDBI Bank.svg'),
  BankEntry(name: 'IDFC First Bank',            country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFCC0000), logoPath: 'assets/icons/banks/IDFC Bank.svg'),
  BankEntry(name: 'India Post Payments Bank',   country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFC41E3A), logoPath: 'assets/icons/banks/India Post Payments Bank.svg'),
  BankEntry(name: 'Indian Bank',                country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF1A237E), logoPath: 'assets/icons/banks/Indian Bank.svg'),
  BankEntry(name: 'Indian Overseas Bank',       country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF0033A0), logoPath: 'assets/icons/banks/Indian Overseas Bank.svg'),
  BankEntry(name: 'Jammu & Kashmir Bank',       country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Jammu & Kashmir Bank.svg'),
  BankEntry(name: 'Jio Payments Bank',          country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF0A1F5E), logoPath: 'assets/icons/banks/Jio Payments Bank.svg'),
  BankEntry(name: 'Karnataka Bank',             country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Karnataka Bank.svg'),
  BankEntry(name: 'Nainital Bank',              country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Nainital Bank.svg'),
  BankEntry(name: 'Paytm Payments Bank',        country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF002970), logoPath: 'assets/icons/banks/Paytm Payments Bank.svg'),
  BankEntry(name: 'Punjab & Sind Bank',         country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Punjab & Sind Bank.svg'),
  BankEntry(name: 'RBL Bank',                   country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFF7941E), logoPath: 'assets/icons/banks/RBL Bank.svg'),
  BankEntry(name: 'South Indian Bank',          country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/South Indian Bank.svg'),
  BankEntry(name: 'Tamilnad Mercantile Bank',   country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Tamilnad Mercantile Bank.svg'),
  BankEntry(name: 'UCO Bank',                   country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/UCO Bank.svg'),
  BankEntry(name: 'Ujjivan Small Finance Bank', country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFFE02020), logoPath: 'assets/icons/banks/Ujjivan Small Finance Bank.svg'),
  BankEntry(name: 'Union Bank of India',        country: 'India', flag: '🇮🇳', countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Union Bank.svg'),
  // ── United States ─────────────────────────────────────────────────────────
  BankEntry(name: 'Chase Bank',       country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFF002B5C), logoPath: 'assets/icons/banks/JPMorgan Chase.svg'),
  BankEntry(name: 'Bank of America',  country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFFE31837), logoPath: 'assets/icons/banks/Bank of America.svg'),
  BankEntry(name: 'Wells Fargo',      country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFFCE2222)),
  BankEntry(name: 'Citibank',         country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFF003B8E), logoPath: 'assets/icons/banks/Citi Bank.svg'),
  BankEntry(name: 'US Bank',          country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFF003087)),
  BankEntry(name: 'Capital One',      country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFFD03027)),
  BankEntry(name: 'American Express', country: 'United States', flag: '🇺🇸', countryCode: 'US', brandColor: Color(0xFF016FD0), logoPath: 'assets/icons/banks/American Express.svg'),
  // ── United Kingdom ────────────────────────────────────────────────────────
  BankEntry(name: 'Barclays Bank',        country: 'United Kingdom', flag: '🇬🇧', countryCode: 'GB', brandColor: Color(0xFF00AEEF), logoPath: 'assets/icons/banks/Barclays Bank.svg'),
  BankEntry(name: 'HSBC Bank',            country: 'United Kingdom', flag: '🇬🇧', countryCode: 'GB', brandColor: Color(0xFFDB0011), logoPath: 'assets/icons/banks/HSBC Bank.svg'),
  BankEntry(name: 'NatWest Bank',         country: 'United Kingdom', flag: '🇬🇧', countryCode: 'GB', brandColor: Color(0xFF42145F), logoPath: 'assets/icons/banks/NatWest Bank.svg'),
  BankEntry(name: 'Standard Chartered',   country: 'United Kingdom', flag: '🇬🇧', countryCode: 'GB', brandColor: Color(0xFF0072AA), logoPath: 'assets/icons/banks/Standard Chartered Bank.svg'),
  // ── Germany ───────────────────────────────────────────────────────────────
  BankEntry(name: 'Deutsche Bank',  country: 'Germany', flag: '🇩🇪', countryCode: 'DE', brandColor: Color(0xFF003D7C), logoPath: 'assets/icons/banks/Deutsche Bank.svg'),
  // ── France ────────────────────────────────────────────────────────────────
  BankEntry(name: 'BNP Paribas',      country: 'France', flag: '🇫🇷', countryCode: 'FR', brandColor: Color(0xFF004A97), logoPath: 'assets/icons/banks/BNP Paribas.svg'),
  BankEntry(name: 'Société Générale', country: 'France', flag: '🇫🇷', countryCode: 'FR', brandColor: Color(0xFFE60028), logoPath: 'assets/icons/banks/Société Générale.svg'),
  BankEntry(name: 'Crédit Agricole',  country: 'France', flag: '🇫🇷', countryCode: 'FR', brandColor: Color(0xFF008852), logoPath: 'assets/icons/banks/Crédit Agricole Corporate and Investment Bank.svg'),
  // ── Switzerland ───────────────────────────────────────────────────────────
  BankEntry(name: 'Credit Suisse',  country: 'Switzerland', flag: '🇨🇭', countryCode: 'CH', brandColor: Color(0xFF002766), logoPath: 'assets/icons/banks/Credit Suisse.svg'),
  // ── Netherlands ───────────────────────────────────────────────────────────
  BankEntry(name: 'ABN AMRO',  country: 'Netherlands', flag: '🇳🇱', countryCode: 'NL', brandColor: Color(0xFF009FE3), logoPath: 'assets/icons/banks/ABN AMRO.svg'),
  // ── Australia ─────────────────────────────────────────────────────────────
  BankEntry(name: 'ANZ Bank', country: 'Australia', flag: '🇦🇺', countryCode: 'AU', brandColor: Color(0xFF007DBA), logoPath: 'assets/icons/banks/Australia and New Zealand Banking Group.svg'),
  BankEntry(name: 'Westpac',  country: 'Australia', flag: '🇦🇺', countryCode: 'AU', brandColor: Color(0xFFDA1710), logoPath: 'assets/icons/banks/Westpac.svg'),
  // ── Canada ────────────────────────────────────────────────────────────────
  BankEntry(name: 'Scotiabank',  country: 'Canada', flag: '🇨🇦', countryCode: 'CA', brandColor: Color(0xFFEC111A), logoPath: 'assets/icons/banks/Scotia Bank.svg'),
  // ── Singapore ─────────────────────────────────────────────────────────────
  BankEntry(name: 'DBS Bank',             country: 'Singapore', flag: '🇸🇬', countryCode: 'SG', brandColor: Color(0xFFD42A21), logoPath: 'assets/icons/banks/DBS Bank.svg'),
  BankEntry(name: 'United Overseas Bank', country: 'Singapore', flag: '🇸🇬', countryCode: 'SG', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/United Overseas Bank.svg'),
  // ── Japan ─────────────────────────────────────────────────────────────────
  BankEntry(name: 'Mizuho Bank', country: 'Japan', flag: '🇯🇵', countryCode: 'JP', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Mizuho Corporate Bank.svg'),
  BankEntry(name: 'MUFG Bank',   country: 'Japan', flag: '🇯🇵', countryCode: 'JP', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/MUFG Bank.svg'),
  BankEntry(name: 'SMBC',        country: 'Japan', flag: '🇯🇵', countryCode: 'JP', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Sumitomo Mitsui Banking Corporation.svg'),
  // ── South Korea ───────────────────────────────────────────────────────────
  BankEntry(name: 'KEB Hana Bank',         country: 'South Korea', flag: '🇰🇷', countryCode: 'KR', brandColor: Color(0xFF009E60), logoPath: 'assets/icons/banks/KEB Hana Bank.svg'),
  BankEntry(name: 'Kookmin Bank',          country: 'South Korea', flag: '🇰🇷', countryCode: 'KR', brandColor: Color(0xFFFFB81C), logoPath: 'assets/icons/banks/Kookmin Bank.svg'),
  BankEntry(name: 'Shinhan Bank',          country: 'South Korea', flag: '🇰🇷', countryCode: 'KR', brandColor: Color(0xFF0046AD), logoPath: 'assets/icons/banks/Shinhan Bank.svg'),
  BankEntry(name: 'Industrial Bank Korea', country: 'South Korea', flag: '🇰🇷', countryCode: 'KR', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Industrial Bank of Korea.svg'),
  BankEntry(name: 'Woori Bank',            country: 'South Korea', flag: '🇰🇷', countryCode: 'KR', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Woori Bank.svg'),
  // ── China ─────────────────────────────────────────────────────────────────
  BankEntry(name: 'Bank of China', country: 'China', flag: '🇨🇳', countryCode: 'CN', brandColor: Color(0xFFAD0000), logoPath: 'assets/icons/banks/Bank of China.svg'),
  BankEntry(name: 'ICBC',          country: 'China', flag: '🇨🇳', countryCode: 'CN', brandColor: Color(0xFFBE0000), logoPath: 'assets/icons/banks/Industrial & Commercial Bank of China.svg'),
  // ── UAE ───────────────────────────────────────────────────────────────────
  BankEntry(name: 'Abu Dhabi Commercial Bank', country: 'UAE', flag: '🇦🇪', countryCode: 'AE', brandColor: Color(0xFF005CAB), logoPath: 'assets/icons/banks/Abu Dhabi Commercial Bank.svg'),
  BankEntry(name: 'Emirates NBD',              country: 'UAE', flag: '🇦🇪', countryCode: 'AE', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Emirates NBD.svg'),
  BankEntry(name: 'First Abu Dhabi Bank',      country: 'UAE', flag: '🇦🇪', countryCode: 'AE', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/First Abu Dhabi Bank.svg'),
  // ── Qatar ─────────────────────────────────────────────────────────────────
  BankEntry(name: 'Qatar National Bank', country: 'Qatar', flag: '🇶🇦', countryCode: 'QA', brandColor: Color(0xFF4B006E), logoPath: 'assets/icons/banks/Qatar National Bank.svg'),
  BankEntry(name: 'Doha Bank',           country: 'Qatar', flag: '🇶🇦', countryCode: 'QA', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Doha Bank.svg'),
  // ── Bahrain ───────────────────────────────────────────────────────────────
  BankEntry(name: 'Bank of Bahrain & Kuwait', country: 'Bahrain', flag: '🇧🇭', countryCode: 'BH', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Bank of Bahrain and Kuwait.svg'),
  // ── South Africa ──────────────────────────────────────────────────────────
  BankEntry(name: 'FirstRand Bank', country: 'South Africa', flag: '🇿🇦', countryCode: 'ZA', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/FirstRand Bank.svg'),
  // ── Russia ────────────────────────────────────────────────────────────────
  BankEntry(name: 'Sberbank', country: 'Russia', flag: '🇷🇺', countryCode: 'RU', brandColor: Color(0xFF1A9F29), logoPath: 'assets/icons/banks/Sberbank.svg'),
  // ── Thailand ──────────────────────────────────────────────────────────────
  BankEntry(name: 'Krung Thai Bank', country: 'Thailand', flag: '🇹🇭', countryCode: 'TH', brandColor: Color(0xFF007B40), logoPath: 'assets/icons/banks/Krung Thai Bank.svg'),
  // ── Bangladesh ────────────────────────────────────────────────────────────
  BankEntry(name: 'Sonali Bank', country: 'Bangladesh', flag: '🇧🇩', countryCode: 'BD', brandColor: Color(0xFF006633), logoPath: 'assets/icons/banks/Sonali Bank.svg'),
  // ── Sri Lanka ─────────────────────────────────────────────────────────────
  BankEntry(name: 'Bank of Ceylon', country: 'Sri Lanka', flag: '🇱🇰', countryCode: 'LK', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Bank of Ceylon.svg'),
  // ── Indonesia ─────────────────────────────────────────────────────────────
  BankEntry(name: 'Maybank Indonesia', country: 'Indonesia', flag: '🇮🇩', countryCode: 'ID', brandColor: Color(0xFFFFAD00), logoPath: 'assets/icons/banks/Bank Maybank Indonesia.svg'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class BankPickerScreen extends StatefulWidget {
  final BankEntry? selectedBank;
  const BankPickerScreen({super.key, this.selectedBank});

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
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: banks.length,
                      itemBuilder: (_, i) => _BankTile(
                        bank: banks[i],
                        isSelected: banks[i].name == widget.selectedBank?.name,
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

// ── Bank tile ──────────────────────────────────────────────────────────────────

class _BankTile extends StatelessWidget {
  final BankEntry bank;
  final bool isSelected;
  final VoidCallback onTap;

  const _BankTile({required this.bank, required this.isSelected, required this.onTap});

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
              color: bank.logoPath != null ? cs.surface : bank.brandColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: Colors.green, width: 2)
                  : bank.logoPath != null
                      ? Border.all(color: cs.outlineVariant, width: 0.5)
                      : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: bank.logoPath != null
                ? SvgPicture.asset(bank.logoPath!, fit: BoxFit.contain)
                : Center(
                    child: Text(
                      bank.initials,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: bank.brandColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
          ),
          if (isSelected)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
