import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Thin ad strip rendered above the bottom navigation bar.
///
/// Visibility is controlled by [AdConfigService] — hidden by default.
/// [onDismiss] fires when the user taps the close button; the parent is
/// responsible for removing the widget from the tree.
class AdBanner extends StatelessWidget {
  final VoidCallback? onDismiss;

  const AdBanner({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1D1A24),
        border: Border(
          top: BorderSide(color: Color(0xFF332D41), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // "Ad" label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF332D41)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'AD',
              style: TextStyle(
                fontSize: 9,
                color: Color(0xFF49454F),
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('🤖', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          // Two-colour ad copy
          const Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'SmartWallet Pro',
                    style: TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: ' · AI-powered budget insights for everyone',
                    style: TextStyle(
                      color: Color(0xFFE6E1E5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Download pill
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Download',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0EA5E9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Dismiss button
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF332D41),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.x, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
