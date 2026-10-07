import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Runs an integration test on a device and saves the screenshots it
/// reports to build/e2e_screenshots/.
Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        final shots = (data?['screenshots'] as Map?) ?? const {};
        for (final entry in shots.entries) {
          final file = File('build/e2e_screenshots/${entry.key}.png');
          await file.create(recursive: true);
          await file.writeAsBytes(base64Decode(entry.value as String));
        }
      },
    );
