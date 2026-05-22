import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ── Data ───────────────────────────────────────────────────────────────────────

class BankEntry {
  final String name;
  final String countryCode; // ISO 3166-1 alpha-2, e.g. 'IN', 'US'
  final Color brandColor;
  final String? logoPath; // asset path or null → show initials

  const BankEntry({
    required this.name,
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
  BankEntry(name: 'HDFC Bank',                  countryCode: 'IN', brandColor: Color(0xFF004C8F), logoPath: 'assets/icons/banks/HDFC Bank.svg'),
  BankEntry(name: 'ICICI Bank',                 countryCode: 'IN', brandColor: Color(0xFFB71C1C), logoPath: 'assets/icons/banks/ICICI Bank.svg'),
  BankEntry(name: 'State Bank of India',        countryCode: 'IN', brandColor: Color(0xFF1565C0), logoPath: 'assets/icons/banks/State Bank of India.svg'),
  BankEntry(name: 'Axis Bank',                  countryCode: 'IN', brandColor: Color(0xFF880E4F), logoPath: 'assets/icons/banks/Axis bank.svg'),
  BankEntry(name: 'Kotak Mahindra Bank',        countryCode: 'IN', brandColor: Color(0xFFE53935), logoPath: 'assets/icons/banks/Kotak Mahindra Bank.svg'),
  BankEntry(name: 'Canara Bank',                countryCode: 'IN', brandColor: Color(0xFF1A237E), logoPath: 'assets/icons/banks/Canara Bank.svg'),
  BankEntry(name: 'Punjab National Bank',       countryCode: 'IN', brandColor: Color(0xFF0D47A1), logoPath: 'assets/icons/banks/Punjab National Bank.svg'),
  BankEntry(name: 'Bank of Baroda',             countryCode: 'IN', brandColor: Color(0xFFF37021), logoPath: 'assets/icons/banks/Bank of Baroda.svg'),
  BankEntry(name: 'IndusInd Bank',              countryCode: 'IN', brandColor: Color(0xFF00796B), logoPath: 'assets/icons/banks/Induslnd Bank.svg'),
  BankEntry(name: 'Yes Bank',                   countryCode: 'IN', brandColor: Color(0xFF1976D2), logoPath: 'assets/icons/banks/Yes Bank.svg'),
  BankEntry(name: 'Airtel Payments Bank',       countryCode: 'IN', brandColor: Color(0xFFE40000), logoPath: 'assets/icons/banks/Airtel Payments Bank.svg'),
  BankEntry(name: 'AU Small Finance Bank',      countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/AU Small Finance Bank.svg'),
  BankEntry(name: 'Bandhan Bank',               countryCode: 'IN', brandColor: Color(0xFF1B4F82), logoPath: 'assets/icons/banks/Bandhan Bank.svg'),
  BankEntry(name: 'Bank of India',              countryCode: 'IN', brandColor: Color(0xFF1B5E20), logoPath: 'assets/icons/banks/Bank of India.svg'),
  BankEntry(name: 'Bank of Maharashtra',        countryCode: 'IN', brandColor: Color(0xFF1565C0), logoPath: 'assets/icons/banks/Bank of Maharastra.svg'),
  BankEntry(name: 'Central Bank of India',      countryCode: 'IN', brandColor: Color(0xFFB71C1C), logoPath: 'assets/icons/banks/Central Bank of India.svg'),
  BankEntry(name: 'City Union Bank',            countryCode: 'IN', brandColor: Color(0xFF1565C0), logoPath: 'assets/icons/banks/City Union Bank.svg'),
  BankEntry(name: 'CSB Bank',                   countryCode: 'IN', brandColor: Color(0xFF004B8D), logoPath: 'assets/icons/banks/CSB Bank.svg'),
  BankEntry(name: 'DCB Bank',                   countryCode: 'IN', brandColor: Color(0xFF00579B), logoPath: 'assets/icons/banks/DCB Bank.svg'),
  BankEntry(name: 'Dhanlaxmi Bank',             countryCode: 'IN', brandColor: Color(0xFF8B0000), logoPath: 'assets/icons/banks/Dhanlaxmi Bank.svg'),
  BankEntry(name: 'ESAF Small Finance Bank',    countryCode: 'IN', brandColor: Color(0xFF0075BE), logoPath: 'assets/icons/banks/ESAF Small Finance Bank Ltd.svg'),
  BankEntry(name: 'FINO Payments Bank',         countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/FINO Payments Bank.svg'),
  BankEntry(name: 'IDBI Bank',                  countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/IDBI Bank.svg'),
  BankEntry(name: 'IDFC First Bank',            countryCode: 'IN', brandColor: Color(0xFFCC0000), logoPath: 'assets/icons/banks/IDFC Bank.svg'),
  BankEntry(name: 'India Post Payments Bank',   countryCode: 'IN', brandColor: Color(0xFFC41E3A), logoPath: 'assets/icons/banks/India Post Payments Bank.svg'),
  BankEntry(name: 'Indian Bank',                countryCode: 'IN', brandColor: Color(0xFF1A237E), logoPath: 'assets/icons/banks/Indian Bank.svg'),
  BankEntry(name: 'Indian Overseas Bank',       countryCode: 'IN', brandColor: Color(0xFF0033A0), logoPath: 'assets/icons/banks/Indian Overseas Bank.svg'),
  BankEntry(name: 'Jammu & Kashmir Bank',       countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Jammu & Kashmir Bank.svg'),
  BankEntry(name: 'Jio Payments Bank',          countryCode: 'IN', brandColor: Color(0xFF0A1F5E), logoPath: 'assets/icons/banks/Jio Payments Bank.svg'),
  BankEntry(name: 'Karnataka Bank',             countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Karnataka Bank.svg'),
  BankEntry(name: 'Nainital Bank',              countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Nainital Bank.svg'),
  BankEntry(name: 'Paytm Payments Bank',        countryCode: 'IN', brandColor: Color(0xFF002970), logoPath: 'assets/icons/banks/Paytm Payments Bank.svg'),
  BankEntry(name: 'Punjab & Sind Bank',         countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Punjab & Sind Bank.svg'),
  BankEntry(name: 'RBL Bank',                   countryCode: 'IN', brandColor: Color(0xFFF7941E), logoPath: 'assets/icons/banks/RBL Bank.svg'),
  BankEntry(name: 'South Indian Bank',          countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/South Indian Bank.svg'),
  BankEntry(name: 'Tamilnad Mercantile Bank',   countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Tamilnad Mercantile Bank.svg'),
  BankEntry(name: 'UCO Bank',                   countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/UCO Bank.svg'),
  BankEntry(name: 'Ujjivan Small Finance Bank', countryCode: 'IN', brandColor: Color(0xFFE02020), logoPath: 'assets/icons/banks/Ujjivan Small Finance Bank.svg'),
  BankEntry(name: 'Union Bank of India',        countryCode: 'IN', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Union Bank.svg'),
  BankEntry(name: 'Chase Bank',                 countryCode: 'US', brandColor: Color(0xFF002B5C), logoPath: 'assets/icons/banks/JPMorgan Chase.svg'),
  BankEntry(name: 'Bank of America',            countryCode: 'US', brandColor: Color(0xFFE31837), logoPath: 'assets/icons/banks/Bank of America.svg'),
  BankEntry(name: 'Wells Fargo',                countryCode: 'US', brandColor: Color(0xFFCE2222)),
  BankEntry(name: 'Citibank',                   countryCode: 'US', brandColor: Color(0xFF003B8E), logoPath: 'assets/icons/banks/Citi Bank.svg'),
  BankEntry(name: 'US Bank',                    countryCode: 'US', brandColor: Color(0xFF003087)),
  BankEntry(name: 'Capital One',                countryCode: 'US', brandColor: Color(0xFFD03027)),
  BankEntry(name: 'American Express',           countryCode: 'US', brandColor: Color(0xFF016FD0), logoPath: 'assets/icons/banks/American Express.svg'),
  BankEntry(name: 'Barclays Bank',              countryCode: 'GB', brandColor: Color(0xFF00AEEF), logoPath: 'assets/icons/banks/Barclays Bank.svg'),
  BankEntry(name: 'HSBC Bank',                  countryCode: 'GB', brandColor: Color(0xFFDB0011), logoPath: 'assets/icons/banks/HSBC Bank.svg'),
  BankEntry(name: 'NatWest Bank',               countryCode: 'GB', brandColor: Color(0xFF42145F), logoPath: 'assets/icons/banks/NatWest Bank.svg'),
  BankEntry(name: 'Standard Chartered',         countryCode: 'GB', brandColor: Color(0xFF0072AA), logoPath: 'assets/icons/banks/Standard Chartered Bank.svg'),
  BankEntry(name: 'Deutsche Bank',              countryCode: 'DE', brandColor: Color(0xFF003D7C), logoPath: 'assets/icons/banks/Deutsche Bank.svg'),
  BankEntry(name: 'BNP Paribas',                countryCode: 'FR', brandColor: Color(0xFF004A97), logoPath: 'assets/icons/banks/BNP Paribas.svg'),
  BankEntry(name: 'Société Générale',           countryCode: 'FR', brandColor: Color(0xFFE60028), logoPath: 'assets/icons/banks/Société Générale.svg'),
  BankEntry(name: 'Crédit Agricole',            countryCode: 'FR', brandColor: Color(0xFF008852), logoPath: 'assets/icons/banks/Crédit Agricole Corporate and Investment Bank.svg'),
  BankEntry(name: 'Credit Suisse',              countryCode: 'CH', brandColor: Color(0xFF002766), logoPath: 'assets/icons/banks/Credit Suisse.svg'),
  BankEntry(name: 'ABN AMRO',                   countryCode: 'NL', brandColor: Color(0xFF009FE3), logoPath: 'assets/icons/banks/ABN AMRO.svg'),
  BankEntry(name: 'ANZ Bank',                   countryCode: 'AU', brandColor: Color(0xFF007DBA), logoPath: 'assets/icons/banks/Australia and New Zealand Banking Group.svg'),
  BankEntry(name: 'Westpac',                    countryCode: 'AU', brandColor: Color(0xFFDA1710), logoPath: 'assets/icons/banks/Westpac.svg'),
  BankEntry(name: 'Scotiabank',                 countryCode: 'CA', brandColor: Color(0xFFEC111A), logoPath: 'assets/icons/banks/Scotia Bank.svg'),
  BankEntry(name: 'DBS Bank',                   countryCode: 'SG', brandColor: Color(0xFFD42A21), logoPath: 'assets/icons/banks/DBS Bank.svg'),
  BankEntry(name: 'United Overseas Bank',       countryCode: 'SG', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/United Overseas Bank.svg'),
  BankEntry(name: 'Mizuho Bank',                countryCode: 'JP', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Mizuho Corporate Bank.svg'),
  BankEntry(name: 'MUFG Bank',                  countryCode: 'JP', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/MUFG Bank.svg'),
  BankEntry(name: 'SMBC',                       countryCode: 'JP', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Sumitomo Mitsui Banking Corporation.svg'),
  BankEntry(name: 'KEB Hana Bank',              countryCode: 'KR', brandColor: Color(0xFF009E60), logoPath: 'assets/icons/banks/KEB Hana Bank.svg'),
  BankEntry(name: 'Kookmin Bank',               countryCode: 'KR', brandColor: Color(0xFFFFB81C), logoPath: 'assets/icons/banks/Kookmin Bank.svg'),
  BankEntry(name: 'Shinhan Bank',               countryCode: 'KR', brandColor: Color(0xFF0046AD), logoPath: 'assets/icons/banks/Shinhan Bank.svg'),
  BankEntry(name: 'Industrial Bank Korea',      countryCode: 'KR', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Industrial Bank of Korea.svg'),
  BankEntry(name: 'Woori Bank',                 countryCode: 'KR', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Woori Bank.svg'),
  BankEntry(name: 'Bank of China',              countryCode: 'CN', brandColor: Color(0xFFAD0000), logoPath: 'assets/icons/banks/Bank of China.svg'),
  BankEntry(name: 'ICBC',                       countryCode: 'CN', brandColor: Color(0xFFBE0000), logoPath: 'assets/icons/banks/Industrial & Commercial Bank of China.svg'),
  BankEntry(name: 'Abu Dhabi Commercial Bank',  countryCode: 'AE', brandColor: Color(0xFF005CAB), logoPath: 'assets/icons/banks/Abu Dhabi Commercial Bank.svg'),
  BankEntry(name: 'Emirates NBD',               countryCode: 'AE', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Emirates NBD.svg'),
  BankEntry(name: 'First Abu Dhabi Bank',       countryCode: 'AE', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/First Abu Dhabi Bank.svg'),
  BankEntry(name: 'Qatar National Bank',        countryCode: 'QA', brandColor: Color(0xFF4B006E), logoPath: 'assets/icons/banks/Qatar National Bank.svg'),
  BankEntry(name: 'Doha Bank',                  countryCode: 'QA', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Doha Bank.svg'),
  BankEntry(name: 'Bank of Bahrain & Kuwait',   countryCode: 'BH', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Bank of Bahrain and Kuwait.svg'),
  BankEntry(name: 'FirstRand Bank',             countryCode: 'ZA', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/FirstRand Bank.svg'),
  BankEntry(name: 'Sberbank',                   countryCode: 'RU', brandColor: Color(0xFF1A9F29), logoPath: 'assets/icons/banks/Sberbank.svg'),
  BankEntry(name: 'Krung Thai Bank',            countryCode: 'TH', brandColor: Color(0xFF007B40), logoPath: 'assets/icons/banks/Krung Thai Bank.svg'),
  BankEntry(name: 'Sonali Bank',                countryCode: 'BD', brandColor: Color(0xFF006633), logoPath: 'assets/icons/banks/Sonali Bank.svg'),
  BankEntry(name: 'Bank of Ceylon',             countryCode: 'LK', brandColor: Color(0xFF003087), logoPath: 'assets/icons/banks/Bank of Ceylon.svg'),
  BankEntry(name: 'Maybank Indonesia',          countryCode: 'ID', brandColor: Color(0xFFFFAD00), logoPath: 'assets/icons/banks/Bank Maybank Indonesia.svg'),
];

// ── View mode ──────────────────────────────────────────────────────────────────

enum _BankView { rows, twoCol, grid }

// ── Screen ─────────────────────────────────────────────────────────────────────

class BankPickerScreen extends StatefulWidget {
  final BankEntry? selectedBank;
  const BankPickerScreen({super.key, this.selectedBank});

  @override
  State<BankPickerScreen> createState() => _BankPickerScreenState();
}

class _BankPickerScreenState extends State<BankPickerScreen> {
  String _query = '';
  _BankView _view = _BankView.twoCol;

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
                  Expanded(
                    child: Column(
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
                  ),
                  _ViewToggle(
                    current: _view,
                    onChanged: (v) => setState(() => _view = v),
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
                  : switch (_view) {
                      _BankView.rows => _buildRowsView(banks),
                      _BankView.twoCol => ClipRect(
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
                            itemCount: banks.length,
                            itemBuilder: (_, i) => _BankDualTile(
                              bank: banks[i],
                              isSelected: banks[i].name == widget.selectedBank?.name,
                              onTap: () => Navigator.pop(context, banks[i]),
                            ),
                          ),
                        ),
                        ),
                      _BankView.grid => GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 5,
                            mainAxisSpacing: 5,
                            childAspectRatio: 1,
                          ),
                          itemCount: banks.length,
                          itemBuilder: (_, i) => _BankTile(
                            bank: banks[i],
                            isSelected: banks[i].name == widget.selectedBank?.name,
                            onTap: () => Navigator.pop(context, banks[i]),
                          ),
                        ),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowsView(List<BankEntry> banks) {
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
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Column(
              children: banks.asMap().entries.map((e) {
                return _BankRowTile(
                  bank: e.value,
                  isFirst: e.key == 0,
                  isSelected: e.value.name == widget.selectedBank?.name,
                  onTap: () => Navigator.pop(context, e.value),
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
  final _BankView current;
  final ValueChanged<_BankView> onChanged;

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
          _btn(context, _BankView.rows, LucideIcons.list),
          const SizedBox(width: 2),
          _btn(context, _BankView.twoCol, LucideIcons.grip),
          const SizedBox(width: 2),
          _btn(context, _BankView.grid, LucideIcons.layoutGrid),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, _BankView view, IconData icon) {
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

// ── Bank row tile ──────────────────────────────────────────────────────────────

class _BankRowTile extends StatelessWidget {
  final BankEntry bank;
  final bool isFirst;
  final bool isSelected;
  final VoidCallback onTap;

  const _BankRowTile({
    required this.bank,
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
          padding: const EdgeInsets.all(16),
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
              _LogoBox(bank: bank, size: 36, padding: 8, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bank.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
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

// ── Bank dual tile (2-col) ─────────────────────────────────────────────────────

class _BankDualTile extends StatelessWidget {
  final BankEntry bank;
  final bool isSelected;
  final VoidCallback onTap;

  const _BankDualTile({required this.bank, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = bank.brandColor;

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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bank.logoPath != null
                          ? cs.surface
                          : (isSelected ? color : color.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(12),
                      border: bank.logoPath != null
                          ? Border.all(color: cs.outlineVariant, width: 0.5)
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: bank.logoPath != null
                          ? SvgPicture.asset(bank.logoPath!, fit: BoxFit.contain)
                          : Center(
                              child: Text(
                                bank.initials,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : color,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      bank.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

// ── Logo box helper ────────────────────────────────────────────────────────────

class _LogoBox extends StatelessWidget {
  final BankEntry bank;
  final double size;
  final double padding;
  final double borderRadius;

  const _LogoBox({
    required this.bank,
    required this.size,
    required this.padding,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (bank.logoPath != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        padding: EdgeInsets.all(padding),
        child: SvgPicture.asset(bank.logoPath!, fit: BoxFit.contain),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bank.brandColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Text(
          bank.initials,
          style: TextStyle(
            fontSize: size * 0.33,
            fontWeight: FontWeight.bold,
            color: bank.brandColor,
            letterSpacing: -0.5,
          ),
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

    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 6),
      child: GestureDetector(
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
            padding: const EdgeInsets.all(14),
            child: bank.logoPath != null
                ? Center(child: Transform.scale(scale: 1.4, child: SvgPicture.asset(bank.logoPath!, fit: BoxFit.contain)))
                : Center(
                    child: Text(
                      bank.initials,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: bank.brandColor,
                      ),
                    ),
                  ),
          ),
          if (isSelected)
            Positioned(
              top: -6,
              right: -6,
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
      ),
    );
  }
}
