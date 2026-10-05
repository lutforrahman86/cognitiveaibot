import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_helpers.dart';

/// Second test account (pass its E2E_EMAIL/E2E_PASSWORD): signs it up
/// through the app, checks the legal links on the sign-up form, and the
/// "confirm your email" banner with Resend. Run delete_account_test.dart
/// after confirming the email.
void main() {
  initBinding();

  testWidgets('sign up shows the confirmation banner; Resend sends a new email', (tester) async {
    expect(email, isNot('mobile-test@example.test'), reason: 'use the second test account');
    await startApp(tester);
    if (find.byKey(const Key('auth-submit')).evaluate().isEmpty) await signOutFromSettings(tester);

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Password (at least 8 characters)'), findsOneWidget);
    expect(find.textContaining('By creating an account you agree to the'), findsOneWidget);
    expect(find.byKey(const Key('legal-terms')), findsOneWidget);
    expect(find.byKey(const Key('legal-acceptableUse')), findsOneWidget);
    expect(find.byKey(const Key('legal-privacy')), findsOneWidget);
    await typeInto(tester, const Key('name-field'), 'Mobile Test 2');
    await typeInto(tester, const Key('email-field'), email);
    await typeInto(tester, const Key('password-field'), password);
    await screenshot(tester, 'sign_up_legal');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await waitFor(
      tester,
      find.byWidgetPredicate((w) => w.key == const Key('auth-message') || w.key == const Key('verify-email-banner')),
    );
    if (find.byKey(const Key('auth-message')).evaluate().isNotEmpty) {
      // Left over from an earlier run: sign in instead.
      expect(tester.widget<Text>(find.byKey(const Key('auth-message'))).data, 'Email already registered');
      await tester.tap(find.byKey(const Key('auth-toggle')));
      await tester.pump();
      await signIn(tester);
    }

    await waitFor(tester, find.byKey(const Key('verify-email-banner')));
    expect(find.text('Confirm your email to get your trial credits and to buy credits'), findsOneWidget);
    await screenshot(tester, 'verify_banner');
    await tester.tap(find.byKey(const Key('resend-verification')));
    await waitFor(tester, find.text('Confirmation email sent to $email.'));
    await screenshot(tester, 'verify_resent');
    await pumpFor(tester, const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('dismiss-verify-banner')));
    await waitForGone(tester, find.byKey(const Key('verify-email-banner')));
  });
}
