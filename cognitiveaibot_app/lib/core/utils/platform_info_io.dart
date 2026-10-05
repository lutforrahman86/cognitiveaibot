import 'dart:io' show Platform;

/// True when running on macOS, Windows, or Linux
bool get isDesktopPlatform =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;
