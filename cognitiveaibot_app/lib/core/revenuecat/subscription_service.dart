import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_config.dart';

/// Handles RevenueCat initialization, purchases, and entitlement checking.
///
/// Best practices:
/// - Initialize before runApp in main()
/// - Use [isProEntitled] for feature gating
/// - Use [customerInfo] for subscription status and purchase history
/// - Call [restorePurchases] when user taps "Restore"
class SubscriptionService {
  SubscriptionService._();

  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService._();

  bool _initialized = false;

  /// Whether RevenueCat has been configured. Call [initialize] in main().
  bool get isInitialized => _initialized;

  /// Initialize RevenueCat. Call once at app startup, before [runApp].
  ///
  /// [appUserId] - Optional. Set for logged-in users to sync subscriptions.
  /// [observerMode] - Set true if you handle purchases outside RevenueCat.
  static Future<void> initialize({
    String? appUserId,
  }) async {
    if (instance._initialized) return;
    if (!RevenueCatConfig.isConfigured) {
      debugPrint('[RevenueCat] No API key for this build: purchases are disabled. '
          'See revenuecat_config.dart.');
      return;
    }

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      final configuration = PurchasesConfiguration(RevenueCatConfig.apiKey);

      if (appUserId != null && appUserId.isNotEmpty) {
        await Purchases.configure(configuration);
        await Purchases.logIn(appUserId);
      } else {
        await Purchases.configure(configuration);
      }

      instance._initialized = true;
      debugPrint('[RevenueCat] Initialized successfully');
    } catch (e) {
      // A billing problem must not stop the app from starting; purchases
      // simply stay unavailable.
      debugPrint('[RevenueCat] Initialization error, purchases disabled: $e');
    }
  }

  /// Check if the user has the Pro entitlement (active subscription or lifetime).
  Future<bool> isProEntitled() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements
          .all[RevenueCatConfig.proEntitlementId]
          ?.isActive ?? false;
    } catch (e) {
      debugPrint('[RevenueCat] Entitlement check error: $e');
      return false;
    }
  }

  /// Get current customer info (subscriptions, entitlements, purchase history).
  Future<CustomerInfo> getCustomerInfo() async {
    if (!_initialized) {
      throw StateError('RevenueCat not initialized. Call SubscriptionService.initialize() in main().');
    }
    return Purchases.getCustomerInfo();
  }

  /// Restore previous purchases. Call when user taps "Restore Purchase".
  Future<CustomerInfo> restorePurchases() async {
    if (!_initialized) {
      throw StateError('RevenueCat not initialized.');
    }
    return Purchases.restorePurchases();
  }

  /// Get available offerings (monthly, yearly, lifetime).
  Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[RevenueCat] Get offerings error: $e');
      return null;
    }
  }

  /// Purchase a package. Use packages from [getOfferings] or create manually.
  Future<CustomerInfo> purchasePackage(Package package) async {
    if (!_initialized) {
      throw StateError('RevenueCat not initialized.');
    }
    // ignore: deprecated_member_use
    final result = await Purchases.purchasePackage(package);
    return result.customerInfo;
  }
}
