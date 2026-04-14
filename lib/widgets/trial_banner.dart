import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Subscription trial countdown banner.
///
/// Shown during the free trial period. Not ad-config-dependent — controlled
/// by subscription state. [trialDaysLeft] and [onUpgrade] should be wired
/// to the subscription service once available.
class TrialBanner extends StatelessWidget {
  final int trialDaysLeft;
  final int totalTrialDays;
  final VoidCallback? onUpgrade;

  const TrialBanner({
    super.key,
    required this.trialDaysLeft,
    this.totalTrialDays = 30,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (trialDaysLeft / totalTrialDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF4F378B),
        border: Border.all(color: const Color(0xFF332D41)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFCFBCFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.zap,
              size: 15,
              color: Color(0xFF1D1B20),
            ),
          ),
          const SizedBox(width: 12),
          // Countdown text + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trialDaysLeft}d left in free trial',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFCFBCFF),
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFF332D41),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFCFBCFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Upgrade pill
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCFBCFF),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
