import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveaibot/presentation/providers/chat_session_provider.dart';
import 'package:cognitiveaibot/presentation/screens/chat_screen.dart';

import 'package:cognitiveaibot/presentation/widgets/ai_hub_message_bubble.dart';

import 'e2e_helpers.dart';

/// Run after app_test: the saved session signs in on launch, the chat
/// history comes back from the server, and Log Out returns to sign-in.
void main() {
  initBinding();

  testWidgets('relaunch restores the session and history; sign out', (tester) async {
    await startApp(tester);
    expect(find.byKey(const Key('auth-submit')), findsNothing, reason: 'signed in automatically');
    await openTab(tester, 'History');
    await waitFor(tester, find.text('Renamed by e2e'));
    await screenshot(tester, 'relaunch_history');

    await tester.tap(find.text('Renamed by e2e').first);
    await waitFor(tester, find.byType(AIHubMessageBubble));
    final messages = ProviderScope.containerOf(tester.element(find.byType(ChatScreen))).read(chatSessionProvider).messages;
    expect(messages.where((m) => m.content.contains('Mock reply')), hasLength(1));
    await screenshot(tester, 'relaunch_chat');
    if (!isDesktop) {
      await tester.tap(find.byTooltip('Close'));
      await pumpFor(tester, const Duration(milliseconds: 600));
    }

    await openTab(tester, 'Settings');
    final logOut = find.byKey(const Key('settings-log-out'));
    await scrollTo(tester, logOut, find.byType(Scrollable).last);
    await tester.tap(logOut);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
    await waitFor(tester, find.byKey(const Key('auth-submit')));
    await screenshot(tester, 'signed_out');
  });
}
