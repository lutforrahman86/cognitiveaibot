# RevenueCat Integration Guide

## Overview

This app integrates [RevenueCat](https://www.revenuecat.com/) for in-app subscriptions with:
- **Entitlement**: `pro` by default (set with `REVENUECAT_PRO_ENTITLEMENT`)
- **Products**: monthly, yearly, lifetime (configure in RevenueCat dashboard)
- **RevenueCat Paywall** for purchase UI
- **Customer Center** for subscription management and restore

## Files Added / Modified

| File | Purpose |
|------|---------|
| `lib/core/revenuecat/revenuecat_config.dart` | API key, entitlement ID, product IDs |
| `lib/core/revenuecat/subscription_service.dart` | RevenueCat init, purchases, entitlement checks |
| `lib/core/revenuecat/paywall_presenter.dart` | Paywall and Customer Center presentation |
| `lib/presentation/providers/subscription_provider.dart` | Riverpod providers for entitlement & customer info |
| `lib/presentation/screens/revenuecat_subscription_screen.dart` | Subscription management screen |
| `lib/main.dart` | Initialize RevenueCat before runApp |
| `pubspec.yaml` | Added purchases_flutter, purchases_ui_flutter |

## Configuration

### 1. API Key

No key is committed. Keys from the CognitiveAI Bot project in the RevenueCat dashboard are
passed at build time:

```bash
flutter run \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx \
  --dart-define=REVENUECAT_PRO_ENTITLEMENT=pro
```

`REVENUECAT_API_KEY` (e.g. a Test Store key) is used on any platform without its own key.
With no key, purchases are disabled: the app still runs, everyone is on the Free plan, and
the paywall doesn't open. See `revenuecat_config.dart`.

### 2. RevenueCat Dashboard Setup

1. **Products** (App Store Connect / Google Play):
   - `monthly` – Monthly subscription
   - `yearly` – Yearly subscription  
   - `lifetime` – One-time purchase

2. **Entitlement**:
   - Create entitlement: `pro` (or whatever you pass as `REVENUECAT_PRO_ENTITLEMENT`)
   - Attach products to this entitlement

3. **Offerings**:
   - Create a default offering with packages for monthly, yearly, lifetime

4. **Paywall**:
   - Design your paywall in RevenueCat dashboard (Paywalls → Create)
   - Associate with your offering

### 3. Platform Setup

**iOS**:
- Enable **In-App Purchase** capability: Xcode → Target → Signing & Capabilities → + Capability → In-App Purchase
- Podfile already has `platform :ios, '13.0'`

**Android**:
- BILLING permission added in AndroidManifest.xml
- MainActivity extends FlutterFragmentActivity (required for paywalls)
- launchMode: singleTop (already set)

## Usage Examples

### Check Pro Entitlement (Feature Gating)

```dart
class ProFeatureScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProEntitledProvider);

    return isPro.when(
      data: (pro) => pro ? _ProContent() : _UpgradePrompt(),
      loading: () => CircularProgressIndicator(),
      error: (_, __) => _UpgradePrompt(),
    );
  }
}
```

### Present Paywall Only When Needed

```dart
// Show paywall only if user is not Pro
final result = await PaywallPresenter.presentPaywallIfNeeded(
  displayCloseButton: true,
);
if (result == PaywallResult.purchased || result == PaywallResult.restored) {
  // Refresh UI
}
```

### Customer Info & Purchase History

```dart
final customerInfo = await ref.read(subscriptionServiceProvider).getCustomerInfo();

// Check entitlement
final isPro = customerInfo.entitlements.all[RevenueCatConfig.proEntitlementId]?.isActive ?? false;

// Active subscriptions
final subscriptions = customerInfo.entitlements.active;

// Non-subscription purchases (e.g. lifetime)
final nonSubscriptions = customerInfo.nonSubscriptionTransactions;
```

### Restore Purchases (Programmatic)

```dart
try {
  final info = await SubscriptionService.instance.restorePurchases();
  // Refresh providers
  ref.invalidate(customerInfoProvider);
  ref.invalidate(isProEntitledProvider);
} catch (e) {
  // Handle error
}
```

## Error Handling

- `PaywallResult.error` – Show a retry message to the user
- `PaywallResult.cancelled` – User dismissed paywall (no action needed)
- `PaywallResult.notPresented` – RevenueCat not initialized or user already has entitlement
- Purchase errors – Surface via `PurchasesErrorCode` in try/catch

## Best Practices

1. **Initialize early**: RevenueCat is initialized in `main()` before `runApp`.
2. **User IDs**: For logged-in users, call `Purchases.logIn(appUserId)` after configure to sync subscriptions.
3. **Testing**: Use sandbox accounts (iOS) and license testers (Android) for purchases.
4. **Production**: Replace the test API key with production keys before store submission.

## Resources

- [RevenueCat Flutter Docs](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [Paywalls](https://www.revenuecat.com/docs/tools/paywalls)
- [Customer Center](https://www.revenuecat.com/docs/tools/customer-center)
