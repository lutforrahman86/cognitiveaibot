import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cognitiveaibot/main.dart' as app;

const email = String.fromEnvironment('E2E_EMAIL');
const password = String.fromEnvironment('E2E_PASSWORD');

bool get isDesktop => Platform.isMacOS;

late IntegrationTestWidgetsFlutterBinding binding;

IntegrationTestWidgetsFlutterBinding initBinding() => binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

/// Pumps until [finder] matches, or fails after [timeout]. (pumpAndSettle
/// never settles while a spinner animates.)
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> waitForGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder to disappear');
}

Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

int _shot = 0;
final _shots = <String, String>{};

/// Captures what Flutter drew (in-process, so system alerts from other apps
/// don't cover it) and hands it to the driver, which saves it as a PNG.
Future<void> screenshot(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  // The root layer is in physical pixels.
  final size = view.size * view.flutterView.devicePixelRatio;
  final image = await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size, pixelRatio: 0.6);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(data!.buffer.asUint8List());
  });
  final prefix = isDesktop ? 'macos' : 'ios';
  _shots['${prefix}_${(++_shot).toString().padLeft(2, '0')}_$name'] = image!;
  binding.reportData = {'screenshots': _shots};
}

Future<void> startApp(WidgetTester tester) async {
  expect(email, isNotEmpty, reason: 'pass --dart-define=E2E_EMAIL=...');
  expect(password, isNotEmpty, reason: 'pass --dart-define=E2E_PASSWORD=...');
  app.main();
  await waitFor(tester, find.byType(Scaffold));
  // Restoring the saved session shows a spinner first.
  await waitFor(
    tester,
    find.byWidgetPredicate((w) => w.key == const Key('auth-submit') || w is NavigationBar || (w is Text && w.data == 'Log Out')),
  );
}

Future<void> fill(WidgetTester tester, Key key, String text) async {
  await tester.enterText(find.byKey(key), text);
  await tester.pump();
}

Future<void> signIn(WidgetTester tester) async {
  if (find.byKey(const Key('auth-submit')).evaluate().isEmpty) return;
  await fill(tester, const Key('email-field'), email);
  await fill(tester, const Key('password-field'), password);
  await tester.tap(find.byKey(const Key('auth-submit')));
  await waitForGone(tester, find.byKey(const Key('auth-submit')));
}

/// Opens a tab of the shell (bottom bar on mobile, sidebar on desktop).
Future<void> openTab(WidgetTester tester, String mobileLabel, {String? desktopLabel}) async {
  final label = isDesktop ? (desktopLabel ?? mobileLabel) : mobileLabel;
  final finder = isDesktop
      ? find.text(label)
      : find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
  await tester.tap(finder.first);
  await pumpFor(tester, const Duration(milliseconds: 600));
}

/// Drags [scrollable] until [finder] has a match (dy < 0 scrolls down).
Future<void> scrollTo(WidgetTester tester, Finder finder, Finder scrollable, {double dy = -200}) async {
  for (var i = 0; i < 60; i++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await tester.pump(const Duration(milliseconds: 200));
      return;
    }
    await tester.drag(scrollable, Offset(0, dy));
    await tester.pump(const Duration(milliseconds: 200));
  }
  throw TestFailure('Could not scroll to $finder');
}
