import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'e2e_helpers.dart';

// The mock backend answers only OpenAI models.
const mockModel = 'GPT-6 Luna';

/// Launch-readiness flows on the main test account, against the mock
/// backend: forgot password, report a reply, change password (and back),
/// download my data, legal links. Leaves the account as it found it.
void main() {
  initBinding();

  final run = DateTime.now().millisecondsSinceEpoch % 1000000;
  final tempPassword = '$password-tmp$run';

  testWidgets('forgot password, report, change password, export', (tester) async {
    await startApp(tester);
    if (find.byKey(const Key('auth-submit')).evaluate().isEmpty) await signOutFromSettings(tester);

    // --- Forgot password ---
    await typeInto(tester, const Key('email-field'), email);
    await tester.tap(find.byKey(const Key('forgot-password')));
    await waitFor(tester, find.byKey(const Key('forgot-submit')));
    await screenshot(tester, 'forgot_password');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await waitFor(tester, find.byKey(const Key('forgot-sent')));
    expect(find.textContaining('If an account uses that email, a reset link is on its way'), findsOneWidget);
    await screenshot(tester, 'forgot_password_sent');
    await tester.tap(find.byKey(const Key('forgot-done')));
    await waitFor(tester, find.byKey(const Key('auth-submit')));

    // --- Sign in: a confirmed account has no banner ---
    await signIn(tester);
    await waitFor(tester, find.textContaining('credits'));
    expect(find.byKey(const Key('verify-email-banner')), findsNothing);

    // --- Report a reply ---
    if (!isDesktop) await tester.tap(find.text('Start Chat'));
    await waitFor(tester, find.byKey(const Key('chat-input')));
    await waitForGone(tester, find.text('Loading models…'));
    await tester.tap(find.byKey(const Key('model-picker')));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await scrollTo(tester, find.text(mockModel), find.byType(Scrollable).last, dy: 200);
    await tester.tap(find.text(mockModel).last);
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('chat-input')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('chat-input')), 'Report check $run');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await waitFor(tester, find.byKey(const Key('stop-button')));
    await waitFor(tester, find.byKey(const Key('send-button')), timeout: const Duration(seconds: 40));
    await waitFor(tester, find.byTooltip('Report'));
    await tester.tap(find.byTooltip('Report').last);
    await waitFor(tester, find.byKey(const Key('report-submit')));
    await tester.tap(find.byKey(const Key('report-reason-inaccurate')));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await typeInto(tester, const Key('report-details'), 'e2e report $run');
    await screenshot(tester, 'report_dialog');
    await tester.tap(find.byKey(const Key('report-submit')));
    await waitFor(tester, find.text('Thanks. The reply was reported for review.'));
    await screenshot(tester, 'report_sent');
    await pumpFor(tester, const Duration(seconds: 1));
    if (!isDesktop) {
      await tester.tap(find.byTooltip('Close'));
      await pumpFor(tester, const Duration(milliseconds: 600));
    }

    // --- Change password, then back ---
    await openTab(tester, 'Settings');
    Future<void> changePassword(String from, String to) async {
      await tapSettingsRow(tester, const Key('settings-change-password'));
      await waitFor(tester, find.byKey(const Key('change-password-submit')));
      await typeInto(tester, const Key('current-password-field'), from);
      await typeInto(tester, const Key('new-password-field'), to);
      await typeInto(tester, const Key('repeat-password-field'), to);
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await waitFor(tester, find.text('Password changed. Other devices were signed out.'));
      await pumpFor(tester, const Duration(milliseconds: 500));
    }

    // A wrong current password is refused.
    await tapSettingsRow(tester, const Key('settings-change-password'));
    await waitFor(tester, find.byKey(const Key('change-password-submit')));
    await typeInto(tester, const Key('current-password-field'), 'not-the-password');
    await typeInto(tester, const Key('new-password-field'), tempPassword);
    await typeInto(tester, const Key('repeat-password-field'), tempPassword);
    await tester.tap(find.byKey(const Key('change-password-submit')));
    await waitFor(tester, find.text('Your current password isn’t right.'));
    await screenshot(tester, 'change_password_wrong');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    await changePassword(password, tempPassword);
    await screenshot(tester, 'password_changed');
    // Still signed in with the new token: the server answers signed-in calls.
    await openTab(tester, 'Usage');
    await waitFor(tester, find.byKey(const Key('usage-tokens')));
    expect(find.byKey(const Key('auth-submit')), findsNothing);
    await openTab(tester, 'Settings');
    await changePassword(tempPassword, password);
    expect(find.byKey(const Key('auth-submit')), findsNothing);

    // --- Download my data ---
    await tapSettingsRow(tester, const Key('settings-export'));
    final savedText = find.textContaining('Saved cognitiveaibot-export-');
    await waitFor(tester, savedText);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await screenshot(tester, 'export_saved');
    // The file is really there, with this account's data. (Removed again:
    // on macOS it is in the user's Downloads folder.)
    final message = tester.widget<Text>(savedText).data!;
    final fileName = RegExp(r'Saved (\S+\.json) to').firstMatch(message)!.group(1)!;
    final exported = await tester.runAsync(() async {
      final dir = isDesktop ? (await getDownloadsDirectory())! : await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await file.delete();
      return json;
    });
    expect((exported!['profile'] as Map)['email'], email);
    expect(exported['chats'], isA<List>());
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Legal links are listed ---
    for (final key in ['settings-legal-terms', 'settings-legal-acceptableUse', 'settings-legal-privacy']) {
      await scrollTo(tester, find.byKey(Key(key)), find.byType(Scrollable).last);
    }
    await screenshot(tester, 'settings_legal');
  });
}
