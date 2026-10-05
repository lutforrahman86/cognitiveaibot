import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/revenuecat/subscription_service.dart';

/// Provider for the subscription service (initialized in main).
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});

/// Current customer info. Call [ref.invalidate(customerInfoProvider)] after
/// purchase or restore to refresh.
final customerInfoProvider = FutureProvider<CustomerInfo>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getCustomerInfo();
});

/// Whether the user has Pro entitlement. Use for feature gating.
/// Call [ref.invalidate(isProEntitledProvider)] after purchase/restore to refresh.
final isProEntitledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.isProEntitled();
});
