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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        final filled = i < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: filled ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
