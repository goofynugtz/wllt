import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  // Single cross-platform test key — swap for platform-specific keys in production:
  //   iOS:     appl_XXXX
  //   Android: goog_XXXX
  static const _apiKey = 'test_MsPYemZlEQsOwdvwJWoOLCoolQK';

  static const String entitlementId = 'pro';

  Future<void> initialize() async {
    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.error,
    );
    await Purchases.configure(PurchasesConfiguration(_apiKey));
  }

  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  Future<Offerings> getOfferings() => Purchases.getOfferings();

  Future<CustomerInfo> purchase(Package package) =>
      Purchases.purchasePackage(package);

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  void addCustomerInfoListener(CustomerInfoUpdateListener listener) =>
      Purchases.addCustomerInfoUpdateListener(listener);

  void removeCustomerInfoListener(CustomerInfoUpdateListener listener) =>
      Purchases.removeCustomerInfoUpdateListener(listener);
}
