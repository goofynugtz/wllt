import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart'
    if (dart.library.html) '../platform/purchases_web.dart';

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  // Swap these for real platform-specific keys before release:
  //   iOS:     appl_XXXX  (from RevenueCat dashboard → iOS app → API keys)
  //   Android: goog_XXXX  (from RevenueCat dashboard → Android app → API keys)
  static const _apiKey = 'goog_pfkKRnePXwTtaSYlXsWrvjVRTzE';

  static const String entitlementId = 'pro';

  Future<void> initialize() async {
    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.error,
    );
    await Purchases.configure(PurchasesConfiguration(_apiKey));
  }

  /// Call after Firebase sign-in so purchases are tied to the user account.
  /// This enables cross-device restore without manual intervention.
  Future<void> loginUser(String uid) async {
    await Purchases.logIn(uid);
  }

  /// Call on sign-out to detach the user identity from this device.
  Future<void> logoutUser() async {
    await Purchases.logOut();
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
