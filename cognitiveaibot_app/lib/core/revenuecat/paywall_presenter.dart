import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'revenuecat_config.dart';
import 'subscription_service.dart';

/// Presents RevenueCat Paywall and Customer Center.
///
/// Usage:
/// - [presentPaywall] - Always show paywall (e.g. "Upgrade" button)
/// - [presentPaywallIfNeeded] - Show only when user lacks Pro entitlement
/// - [presentCustomerCenter] - For subscribed users to manage subscription
class PaywallPresenter {
  PaywallPresenter._();

  static final PaywallPresenter instance = PaywallPresenter._();

  /// Present the RevenueCat Paywall (always shown).
  ///
  /// [displayCloseButton] - Show close/dismiss button (original templates only).
  /// Returns [PaywallResult] for handling purchase/restore/cancel.
  static Future<PaywallResult> presentPaywall({
    BuildContext? context,
    Offering? offering,
    bool displayCloseButton = true,
  }) async {
    if (!SubscriptionService.instance.isInitialized) {
      debugPrint('[PaywallPresenter] RevenueCat not initialized');
      return PaywallResult.notPresented;
    }
    try {
      return await RevenueCatUI.presentPaywall(
        offering: offering,
        displayCloseButton: displayCloseButton,
      );
    } catch (e, st) {
      debugPrint('[PaywallPresenter] Error: $e\n$st');
      return PaywallResult.error;
    }
  }

  /// Present paywall only if user does not have Pro entitlement.
  /// If user is already Pro, paywall is not shown and returns [PaywallResult.notPresented].
  static Future<PaywallResult> presentPaywallIfNeeded({
    BuildContext? context,
    Offering? offering,
    bool displayCloseButton = true,
  }) async {
    if (!SubscriptionService.instance.isInitialized) {
      debugPrint('[PaywallPresenter] RevenueCat not initialized');
      return PaywallResult.notPresented;
    }
    try {
      return await RevenueCatUI.presentPaywallIfNeeded(
        RevenueCatConfig.proEntitlementId,
        offering: offering,
        displayCloseButton: displayCloseButton,
      );
    } catch (e, st) {
      debugPrint('[PaywallPresenter] Error: $e\n$st');
      return PaywallResult.error;
    }
  }

  /// Present the Customer Center for managing subscriptions (restore, cancel, etc.).
  /// Use from Settings when user taps "Manage Subscription".
  static Future<void> presentCustomerCenter({
    VoidCallback? onRestoreCompleted,
    VoidCallback? onRestoreFailed,
  }) async {
    if (!SubscriptionService.instance.isInitialized) {
      debugPrint('[PaywallPresenter] RevenueCat not initialized');
      return;
    }
    try {
      await RevenueCatUI.presentCustomerCenter(
        onRestoreCompleted: onRestoreCompleted != null
            ? (_) => onRestoreCompleted()
            : null,
        onRestoreFailed: onRestoreFailed != null ? (_) => onRestoreFailed() : null,
      );
    } catch (e, st) {
      debugPrint('[PaywallPresenter] Customer Center error: $e\n$st');
    }
  }
}
