import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart' as impl;

/// True when running on macOS, Windows, or Linux.
/// Use this to show the desktop layout (sidebar) vs mobile (bottom nav).
bool get isDesktopPlatform => impl.isDesktopPlatform;
