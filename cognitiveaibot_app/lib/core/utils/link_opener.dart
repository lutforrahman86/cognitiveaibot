import 'package:url_launcher/url_launcher.dart';

/// Opens a web page in the browser. False when it couldn't be opened.
typedef LinkOpener = Future<bool> Function(Uri url);

Future<bool> openInBrowser(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
