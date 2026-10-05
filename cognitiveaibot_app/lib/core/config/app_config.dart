/// Build-time settings. Pass them with `--dart-define`:
///
/// ```
/// flutter run \
///   --dart-define=API_BASE_URL=http://localhost:3000 \
///   --dart-define=FRONTEND_URL=http://localhost:5173
/// ```
class AppConfig {
  AppConfig._();

  /// The CognitiveAI Bot backend. The app talks to nothing else for AI
  /// replies: every model is called by the backend, at its own provider.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// The web app. The desktop app sends users there to buy a plan.
  static const String frontendUrl = String.fromEnvironment(
    'FRONTEND_URL',
    defaultValue: 'http://localhost:5173',
  );

  static Uri get upgradeUrl => _page('/upgrade');

  /// The legal pages on the web app.
  static Uri get termsUrl => _page('/terms');
  static Uri get acceptableUseUrl => _page('/acceptable-use');
  static Uri get privacyUrl => _page('/privacy');

  static Uri _page(String path) => Uri.parse('${_withoutTrailingSlash(frontendUrl)}$path');

  static String _withoutTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
