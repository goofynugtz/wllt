import 'package:flutter/material.dart';

/// 3-segment progress bar used on pages 2 and 3 of the onboarding flow.
class OnboardingProgressBar extends StatelessWidget {
  final int current; // number of filled segments (1-based)
  final int total;

  const OnboardingProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: filled
                  ? const Color(0xFF6750A4)
                  : const Color(0xFFE8E0EC),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
