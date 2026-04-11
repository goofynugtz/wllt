import 'package:flutter/material.dart';
import 'onboarding_page1_screen.dart';
import 'onboarding_page2_screen.dart';
import 'onboarding_page3_screen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _controller = PageController();

  void _nextPage() => _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  void _previousPage() => _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        // Navigation is explicit — swiping is disabled to prevent skipping steps.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          OnboardingPage1Screen(onNext: _nextPage),
          OnboardingPage2Screen(onNext: _nextPage, onBack: _previousPage),
          OnboardingPage3Screen(onBack: _previousPage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
