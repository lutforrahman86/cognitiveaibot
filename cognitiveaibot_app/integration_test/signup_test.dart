import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_helpers.dart';

/// Creates the test account through the sign-up screen (or, if it already
/// exists, shows the server's "Email already registered" and signs in).
void main() {
  initBinding();

  testWidgets('sign up through the app', (tester) async {
    await startApp(tester);
    if (find.byKey(const Key('auth-submit')).evaluate().isEmpty) {
      // A saved session was restored: sign out first.
      await openTab(tester, 'Settings');
      final logOut = find.byKey(const Key('settings-log-out'));
      await scrollTo(tester, logOut, find.byType(Scrollable).last);
      await tester.tap(logOut);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
      await waitFor(tester, find.byKey(const Key('auth-submit')));
    }
    await screenshot(tester, 'sign_in');
    await tester.tap(find.byKey(const Key('auth-toggle')));
    await tester.pump();
    await fill(tester, const Key('name-field'), 'Mobile Test');
    await fill(tester, const Key('email-field'), email);
    await fill(tester, const Key('password-field'), password);
    await screenshot(tester, 'sign_up_form');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await waitFor(
      tester,
      find.byWidgetPredicate((w) => w.key == const Key('auth-message') || w is NavigationBar || (w is Text && w.data == 'Log Out')),
    );
    final message = find.byKey(const Key('auth-message'));
    if (message.evaluate().isNotEmpty) {
      expect((tester.widget<Text>(message)).data, 'Email already registered');
      await tester.tap(find.byKey(const Key('auth-toggle')));
      await tester.pump();
      await signIn(tester);
    }
    await waitFor(tester, find.textContaining('credits'));
    await screenshot(tester, 'signed_in_home');
  });
}
