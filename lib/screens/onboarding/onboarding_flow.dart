import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_preferences_provider.dart';
import '../../screens/layout_screen.dart';
import 'onboarding_page1_screen.dart';
import 'onboarding_page1_web.dart';
import 'onboarding_page2_screen.dart';
import 'onboarding_page3_screen.dart';
import 'onboarding_page4_screen.dart';

// Page indices:
//   0 → Page1 (auth)
//   1 → Page2 (currency)
//   2 → Page3 (categories)
//   3 → Page4 (name — offline only; Google users complete after Page3)

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _goTo(int index) {
    setState(() => _currentPage = index);
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onPage3Done() async {
    final prefs = context.read<UserPreferencesProvider>();
    if (prefs.authMode == 'offline') {
      _goTo(3);
    } else {
      // Google: name already stored from sign-in; complete onboarding now.
      await prefs.completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LayoutScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_currentPage - 1);
      },
      child: Scaffold(
        body: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (kIsWeb)
              OnboardingPage1WebScreen(onNextGoogle: () => _goTo(1))
            else
              OnboardingPage1Screen(
                onNextGoogle: () => _goTo(1),
                onNextOffline: () => _goTo(1),
              ),
            OnboardingPage2Screen(
              onNext: () => _goTo(2),
              onBack: () => _goTo(0),
            ),
            OnboardingPage3Screen(
              onBack: () => _goTo(1),
              onGetStarted: _onPage3Done,
            ),
            OnboardingPage4Screen(
              onBack: () => _goTo(2),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
