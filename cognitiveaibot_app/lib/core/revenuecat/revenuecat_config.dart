import 'package:flutter/foundation.dart';

/// RevenueCat configuration for CognitiveAI Bot.
///
/// Values come from the CognitiveAI Bot project in the RevenueCat dashboard
/// and are passed at build time, so no key is committed:
///
/// ```
/// flutter run \
///   --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
///   --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx \
///   --dart-define=REVENUECAT_PRO_ENTITLEMENT=pro
/// ```
///
/// `REVENUECAT_API_KEY` (e.g. a Test Store key) is used on any platform that
/// has no platform-specific key. With no key at all, purchases are disabled:
/// the app runs, everyone is on the Free plan and the paywall doesn't open.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String _iosKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const String _androidKey = String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
  static const String _fallbackKey = String.fromEnvironment('REVENUECAT_API_KEY');

  /// The key for the platform this build runs on, or empty when none was given.
  static String get apiKey {
    final platformKey = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _iosKey,
      TargetPlatform.android => _androidKey,
      _ => '',
    };
    return platformKey.isNotEmpty ? platformKey : _fallbackKey;
  }

  static bool get isConfigured => apiKey.isNotEmpty;

  /// Entitlement that gates Pro features. Must match the identifier in the
  /// RevenueCat dashboard exactly.
  static const String proEntitlementId = String.fromEnvironment(
    'REVENUECAT_PRO_ENTITLEMENT',
    defaultValue: 'pro',
  );

  /// Product identifiers for offerings (monthly, yearly, lifetime).
  /// These should match App Store Connect / Google Play product IDs.
  static const String productMonthly = 'monthly';
  static const String productYearly = 'yearly';
  static const String productLifetime = 'lifetime';
}
