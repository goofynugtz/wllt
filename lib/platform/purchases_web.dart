// Web stub for purchases_flutter + purchases_ui_flutter.
// Subscriptions are managed in the mobile app only.
import 'package:flutter/material.dart';

// ── purchases_flutter stubs ────────────────────────────────────────────────────

class CustomerInfo {
  CustomerInfo();
}

class Offerings {
  final Offering? current;
  Offerings({this.current});
}

class Offering {
  final List<Package> availablePackages;
  Offering({this.availablePackages = const []});
}

class StoreProduct {
  final String priceString;
  const StoreProduct({this.priceString = ''});
}

enum PackageType { monthly, annual, lifetime, unknown }

class Package {
  final PackageType packageType;
  final StoreProduct storeProduct;
  final String identifier;
  const Package({
    required this.packageType,
    required this.storeProduct,
    this.identifier = '',
  });
}

enum LogLevel { verbose, debug, info, warn, error }

class PurchasesConfiguration {
  final String apiKey;
  const PurchasesConfiguration(this.apiKey);
}

typedef CustomerInfoUpdateListener = void Function(CustomerInfo);

enum PurchasesErrorCode { purchaseCancelledError, unknownError }

class PurchasesErrorHelper {
  static PurchasesErrorCode getErrorCode(dynamic e) =>
      PurchasesErrorCode.unknownError;
}

class Purchases {
  static Future<void> setLogLevel(LogLevel level) async {}
  static Future<void> configure(PurchasesConfiguration config) async {}
  static Future<CustomerInfo> logIn(String appUserId) async => CustomerInfo();
  static Future<CustomerInfo> logOut() async => CustomerInfo();
  static Future<CustomerInfo> getCustomerInfo() async => CustomerInfo();
  static Future<Offerings> getOfferings() async => Offerings();
  static Future<CustomerInfo> purchasePackage(Package package) async =>
      CustomerInfo();
  static Future<CustomerInfo> restorePurchases() async => CustomerInfo();
  static void addCustomerInfoUpdateListener(
      CustomerInfoUpdateListener listener) {}
  static void removeCustomerInfoUpdateListener(
      CustomerInfoUpdateListener listener) {}
}

// ── purchases_ui_flutter stubs ─────────────────────────────────────────────────

class PaywallResult {}

class PaywallView extends StatelessWidget {
  final Offering? offering;
  final bool displayCloseButton;
  final VoidCallback? onDismiss;
  final void Function(CustomerInfo, dynamic)? onPurchaseCompleted;
  final void Function(CustomerInfo)? onRestoreCompleted;
  final void Function(dynamic)? onPurchaseError;
  final void Function(dynamic)? onRestoreError;

  const PaywallView({
    super.key,
    this.offering,
    this.displayCloseButton = false,
    this.onDismiss,
    this.onPurchaseCompleted,
    this.onRestoreCompleted,
    this.onPurchaseError,
    this.onRestoreError,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Subscriptions are managed in the mobile app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class RevenueCatUI {
  static Future<PaywallResult> presentPaywall({Offering? offering}) async =>
      PaywallResult();
  static Future<PaywallResult> presentPaywallIfNeeded(
          String entitlementId) async =>
      PaywallResult();
  static Future<void> presentCustomerCenter() async {}
}
