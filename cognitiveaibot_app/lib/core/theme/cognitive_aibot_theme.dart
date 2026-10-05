import 'package:flutter/material.dart';

/// Default app theme for Cognitive AI Bot
/// Dark blue/grey backgrounds, white text, bright blue accents
class CognitiveAIBotTheme {
  CognitiveAIBotTheme._();

  // Dark background - very dark blue/grey
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color cardBackground = Color(0xFF21262D);
  static const Color cardBackgroundAlt = Color(0xFF30363D);

  // Accents
  static const Color primaryBlue = Color(0xFF58A6FF);
  static const Color primaryBlueDim = Color(0xFF388BFD);
  static const Color positiveGreen = Color(0xFF3FB950);
  static const Color topBadgeBlue = Color(0xFF238636);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B949E);

  // Model icon colors
  static const Color iconGreen = Color(0xFF3FB950);
  static const Color iconBlue = Color(0xFF58A6FF);
  static const Color iconTeal = Color(0xFF39BAE6);
  static const Color iconPurple = Color(0xFFD2A8FF);

  /// Default app theme - applied as both theme and darkTheme
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        primary: primaryBlue,
        onPrimary: textPrimary,
        primaryContainer: topBadgeBlue,
        onPrimaryContainer: textPrimary,
        surfaceContainerHighest: cardBackground,
        surfaceContainerHigh: cardBackgroundAlt,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryBlue,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
