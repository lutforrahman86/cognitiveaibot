import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_helpers.dart';

/// Second test account, after its email was confirmed: the banner is gone
/// on relaunch, then the account is deleted through Settings. Refuses to
/// run against the main test account.
void main() {
  initBinding();

  testWidgets('confirmed account has no banner; delete account', (tester) async {
    expect(email, isNot('mobile-test@example.test'), reason: 'never delete the main test account');
    await startApp(tester);
    await signIn(tester);
    await waitFor(tester, find.textContaining('credits'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(const Key('verify-email-banner')), findsNothing, reason: 'the email was confirmed');
    await screenshot(tester, 'confirmed_no_banner');

    await openTab(tester, 'Settings');
    await tapSettingsRow(tester, const Key('settings-delete-account'));
    await waitFor(tester, find.byKey(const Key('delete-account-submit')));
    expect(find.textContaining('An App Store subscription isn’t'), findsOneWidget);
    await typeInto(tester, const Key('delete-account-confirm-field'), 'not-the-password');
    await tester.tap(find.byKey(const Key('delete-account-submit')));
    await waitFor(tester, find.text('That password isn’t right.'));
    await screenshot(tester, 'delete_account_wrong');

    await typeInto(tester, const Key('delete-account-confirm-field'), password);
    await tester.tap(find.byKey(const Key('delete-account-submit')));
    await waitFor(tester, find.byKey(const Key('auth-info')));
    await waitForGone(tester, find.byKey(const Key('delete-account-submit')));
    expect(find.textContaining('cancel it in your Apple account settings'), findsOneWidget);
    await screenshot(tester, 'account_deleted');

    // The account is gone: signing in again fails.
    await typeInto(tester, const Key('email-field'), email);
    await typeInto(tester, const Key('password-field'), password);
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await waitFor(tester, find.byKey(const Key('auth-message')));
  });
}
