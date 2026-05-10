import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/purchase_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;

  bool get isPro =>
      _customerInfo?.entitlements.active
          .containsKey(PurchaseService.entitlementId) ??
      false;

  SubscriptionProvider() {
    PurchaseService.instance.addCustomerInfoListener(_onCustomerInfoUpdated);
  }

  @override
  void dispose() {
    PurchaseService.instance.removeCustomerInfoListener(_onCustomerInfoUpdated);
    super.dispose();
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _customerInfo = info;
    notifyListeners();
  }

  Future<void> init() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _customerInfo = await PurchaseService.instance.getCustomerInfo();
      _offerings = await PurchaseService.instance.getOfferings();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => init();

  Future<bool> purchase(Package package) async {
    try {
      _customerInfo = await PurchaseService.instance.purchase(package);
      notifyListeners();
      return isPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _error = e.message;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    _loading = true;
    notifyListeners();
    try {
      _customerInfo = await PurchaseService.instance.restorePurchases();
      return isPro;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
