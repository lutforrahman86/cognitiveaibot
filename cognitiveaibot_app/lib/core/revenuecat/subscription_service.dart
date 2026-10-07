import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_config.dart';

/// RevenueCat on iOS (and Android): configuration, identifying the user and
/// buying a plan's product.
///
/// The contract with the backend: after sign-in the app calls
/// `Purchases.logIn(<our user id>)`, so RevenueCat's webhook reports
/// purchases with `app_user_id` = our user id and the server credits the
/// right account. The app never grants credits itself.
class SubscriptionService {
  SubscriptionService._();

  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService._();

  bool _initialized = false;

  /// Whether RevenueCat is configured, i.e. in-app purchases are on.
  bool get isInitialized => _initialized;

  /// Configure RevenueCat. Call once at app startup, before [runApp].
  static Future<void> initialize() async {
    if (instance._initialized) return;
    if (!RevenueCatConfig.isConfigured) {
      debugPrint('[RevenueCat] No API key for this platform/build: in-app purchases are off.');
      return;
    }
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(RevenueCatConfig.apiKey));
      instance._initialized = true;
      debugPrint('[RevenueCat] Initialized');
    } catch (e) {
      // A billing problem must not stop the app from starting; purchases
      // simply stay unavailable.
      debugPrint('[RevenueCat] Initialization error, purchases disabled: $e');
    }
  }

  /// Identifies the signed-in user to RevenueCat (`app_user_id` = our user id).
  Future<void> logIn(String userId) async {
    if (!_initialized || userId.isEmpty) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('[RevenueCat] logIn failed: $e');
    }
  }

  /// Back to an anonymous RevenueCat user after sign-out.
  Future<void> logOut() async {
    if (!_initialized) return;
    try {
      if (!await Purchases.isAnonymous) await Purchases.logOut();
    } catch (e) {
      debugPrint('[RevenueCat] logOut failed: $e');
    }
  }

  /// Buys the store product [productId] (a plan's `revenuecat_product_id`).
  /// Returns false when the user cancelled. Throws [PurchaseUnavailable]
  /// when the product can't be found or purchases are off.
  Future<bool> purchaseProduct(String productId, {required bool subscription}) async {
    if (!_initialized) throw const PurchaseUnavailable('In-app purchases aren’t available in this build.');
    final products = await Purchases.getProducts(
      [productId],
      productCategory: subscription ? ProductCategory.subscription : ProductCategory.nonSubscription,
    );
    if (products.isEmpty) throw const PurchaseUnavailable('This plan isn’t available in the App Store right now.');
    try {
      await Purchases.purchase(PurchaseParams.storeProduct(products.first));
      return true;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  /// Restores earlier App Store purchases to the signed-in account.
  Future<void> restorePurchases() async {
    if (!_initialized) throw const PurchaseUnavailable('In-app purchases aren’t available in this build.');
    await Purchases.restorePurchases();
  }
}

class PurchaseUnavailable implements Exception {
  const PurchaseUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
