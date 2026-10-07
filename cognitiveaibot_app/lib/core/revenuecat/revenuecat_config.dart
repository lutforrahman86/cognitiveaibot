import 'package:flutter/foundation.dart';

/// RevenueCat configuration for CognitiveAI Bot.
///
/// Values come from the CognitiveAI Bot project in the RevenueCat dashboard
/// and are passed at build time, so no key is committed:
///
/// ```
/// flutter run \
///   --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
///   --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
/// ```
///
/// `REVENUECAT_API_KEY` (e.g. a Test Store key) is used on a mobile platform
/// that has no platform-specific key. With no key at all, in-app purchases
/// are off: the app runs and shows plans, but nothing can be bought in it.
///
/// The desktop app never sells in-app: its Upgrade button opens the web
/// Upgrade page instead.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String _iosKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const String _androidKey = String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
  static const String _fallbackKey = String.fromEnvironment('REVENUECAT_API_KEY');

  /// The key for the platform this build runs on, or empty when none was
  /// given or the platform doesn't sell in-app.
  static String get apiKey {
    if (kIsWeb) return '';
    final platformKey = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _iosKey,
      TargetPlatform.android => _androidKey,
      _ => null,
    };
    if (platformKey == null) return '';
    return platformKey.isNotEmpty ? platformKey : _fallbackKey;
  }

  static bool get isConfigured => apiKey.isNotEmpty;
}
