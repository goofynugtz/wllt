import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../providers/subscription_provider.dart';
import '../services/purchase_service.dart';

/// Wraps the RevenueCat [PaywallView] as a full-screen route.
///
/// Use the static helpers for common presentation patterns:
///   - [showModal]          — always show paywall as a platform modal
///   - [showIfNeeded]       — only show when user lacks the entitlement
///   - [showCustomerCenter] — manage an active subscription (RC Pro plan required)
class PaywallScreen extends StatelessWidget {
  final Offering? offering;

  const PaywallScreen({super.key, this.offering});

  // ── Static helpers ────────────────────────────────────────────────────────

  /// Present the default RC paywall as a platform modal.
  /// Configure the paywall template in the RevenueCat dashboard first.
  static Future<PaywallResult> showModal({Offering? offering}) =>
      RevenueCatUI.presentPaywall(offering: offering);

  /// Show paywall only when user doesn't have [PurchaseService.entitlementId].
  static Future<PaywallResult> showIfNeeded() =>
      RevenueCatUI.presentPaywallIfNeeded(PurchaseService.entitlementId);

  /// Open the RevenueCat Customer Center (subscription management portal).
  /// Requires RevenueCat Pro or Enterprise plan in the dashboard.
  static Future<void> showCustomerCenter() =>
      RevenueCatUI.presentCustomerCenter();

  // ── Widget (push-navigation) ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaywallView(
        offering: offering,
        displayCloseButton: true,
        onDismiss: () => Navigator.of(context).pop(),
        onPurchaseCompleted: (customerInfo, _) {
          context.read<SubscriptionProvider>().refresh();
          Navigator.of(context).pop();
        },
        onRestoreCompleted: (customerInfo) {
          context.read<SubscriptionProvider>().refresh();
          Navigator.of(context).pop();
        },
        onPurchaseError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        },
        onRestoreError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        },
      ),
    );
  }
}
