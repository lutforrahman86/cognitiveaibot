import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/revenuecat/subscription_service.dart';

/// The RevenueCat service (configured in main). In-app purchases are on only
/// when it is initialized (iOS/Android with a key).
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});
