import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/currencies.dart';
import '../../providers/user_preferences_provider.dart';
import 'onboarding_shared_widgets.dart';

class OnboardingPage2Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingPage2Screen({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingPage2Screen> createState() => _OnboardingPage2ScreenState();
}

class _OnboardingPage2ScreenState extends State<OnboardingPage2Screen> {
  late String _selectedCode;
  late String _detectedCode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _detectedCode = detectCurrencyFromLocale();
    _selectedCode = _detectedCode;
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

  Future<void> _handleContinue() async {
    await context.read<UserPreferencesProvider>().setCurrency(_selectedCode);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final detectedInfo = getCurrencyByCode(_detectedCode);
    final selectedInfo = getCurrencyByCode(_selectedCode);
    final isOffline =
        context.read<UserPreferencesProvider>().authMode == 'offline';
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Fixed-width back button so progress bar is truly centered
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: widget.onBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: OnboardingProgressBar(current: 2, total: 3),
                  ),
                  const SizedBox(width: 12),
                  // Same fixed width as back button to keep bar centered
                  const SizedBox(
                    width: 40,
                    child: Text(
                      '2 of 3',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                                                fontSize: 12,
                        color: Color(0xFF6B6572),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Heading ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 33),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's your currency?",
                    style: TextStyle(
                                            fontSize: 26,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.65,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Use Row+widget instead of RichText so CountryFlag can be inlined
                  Row(
                    children: [
                      const Text(
                        'We detected ',
                        style: TextStyle(
                                                    fontSize: 14,
                          color: Color(0xFF6B6572),
                        ),
                      ),
                      CountryFlag.fromCountryCode(
                        detectedInfo.countryCode,
                        height: 14,
                        width: 20,
                        shape: const RoundedRectangle(2),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        detectedInfo.code,
                        style: const TextStyle(
                                                    fontSize: 14,
                          color: Color(0xFF1D1B20),
                        ),
                      ),
                      const Text(
                        ' based on your region.',
                        style: TextStyle(
                                                    fontSize: 14,
                          color: Color(0xFF6B6572),
                        ),
                      ),
                    ],
                  ),
                  if (isOffline) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x66FFD54F)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.alertTriangle,
                              size: 12, color: Color(0xFF92400E)),
                          SizedBox(width: 6),
                          Text(
                            'Offline mode · No cloud backup',
                            style: TextStyle(
                                                            fontSize: 11,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Search ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search currencies...',
                      hintStyle: TextStyle(
                                                fontSize: 15,
                        color: Color(0xFFCAC4D0),
                      ),
                      prefixIcon: Icon(LucideIcons.search,
                          size: 18, color: Color(0xFF6B6572)),
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Selected currency card — AnimatedSwitcher fades content
            // when the selection changes; fixed height prevents any layout
            // jump during the cross-fade overlap.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Container(
                  key: ValueKey(_selectedCode),
                  height: 64,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EFF7),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFF6750A4), width: 2),
                  ),
                  child: Row(
                  children: [
                    CountryFlag.fromCountryCode(
                      selectedInfo.countryCode,
                      height: 24,
                      width: 34,
                      shape: const RoundedRectangle(4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedInfo.name,
                            style: const TextStyle(
                                                            fontSize: 14,
                              color: Color(0xFF6750A4),
                            ),
                          ),
                          Text(
                            '${selectedInfo.code} · ${selectedInfo.symbol}',
                            style: const TextStyle(
                                                            fontSize: 12,
                              color: Color(0xFF9D85E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Selected',
                        style: TextStyle(
                                                    fontSize: 12,
                          color: Color(0xFF6750A4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ), // AnimatedSwitcher
            ),
            const SizedBox(height: 8),
            // ── Currency list ─────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.searchX,
                            size: 36,
                            color: Color(0xFFCAC4D0),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No results for "$_query"',
                            style: const TextStyle(
                                                            fontSize: 14,
                              color: Color(0xFF9E99A3),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final currency = filtered[i];
                        return _CurrencyRow(
                          currency: currency,
                          isSelected: currency.code == _selectedCode,
                          onTap: () {
                            // Dismiss keyboard when a row is tapped.
                            FocusScope.of(context).unfocus();
                            setState(() => _selectedCode = currency.code);
                          },
                        );
                      },
                    ),
            ),
            // ── Continue button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
              child: GestureDetector(
                onTap: _handleContinue,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1B20),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x38000000),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                                                    fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(LucideIcons.chevronRight,
                          size: 18, color: Colors.white),
                    ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5EFF7)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CountryFlag.fromCountryCode(
              currency.countryCode,
              height: 24,
              width: 34,
              shape: const RoundedRectangle(4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency.name,
                    style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                  Text(
                    '${currency.code} · ${currency.symbol} · ${currency.country}',
                    style: const TextStyle(
                                            fontSize: 12,
                      color: Color(0xFF9E99A3),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF6750A4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.check,
                    size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
