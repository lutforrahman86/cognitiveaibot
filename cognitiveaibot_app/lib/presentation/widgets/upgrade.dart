import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/platform_info.dart';
import '../screens/plans_screen.dart';

/// The Upgrade action. The desktop app doesn't sell in-app: it opens the
/// web Upgrade page in the browser. Mobile shows the plans screen, where
/// plans are bought through the App Store (RevenueCat).
Future<void> openUpgrade(BuildContext context) async {
  if (isDesktopPlatform) {
    await openWebUpgradePage(context);
  } else {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlansScreen()));
  }
}

Future<void> openWebUpgradePage(BuildContext context) async {
  final url = AppConfig.upgradeUrl;
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn’t open $url')));
  }
}
