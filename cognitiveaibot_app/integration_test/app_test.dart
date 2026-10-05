import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cognitiveaibot/core/config/app_config.dart';
import 'package:cognitiveaibot/domain/entities/chat_message.dart';
import 'package:cognitiveaibot/presentation/providers/chat_session_provider.dart';
import 'package:cognitiveaibot/presentation/screens/chat_screen.dart';
import 'package:cognitiveaibot/presentation/widgets/ai_hub_message_bubble.dart';

import 'e2e_helpers.dart';

// Only OpenAI models are answered by the mock backend; every other provider
// would be a real (paid) call, so the test always picks this one.
const mockModel = 'GPT-6 Luna';

List<AIHubMessageBubble> bubbles(WidgetTester tester) =>
    tester.widgetList<AIHubMessageBubble>(find.byType(AIHubMessageBubble)).toList();

/// All messages of the open chat (the list only builds what is on screen).
List<ChatMessage> sessionMessages(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(ChatScreen)))
    .read(chatSessionProvider)
    .messages;

int mockReplies(WidgetTester tester) =>
    sessionMessages(tester).where((m) => m.role == MessageRole.assistant && m.content.contains('Mock reply')).length;

/// Sends [text] and waits until the reply has finished streaming.
Future<void> sendAndWait(WidgetTester tester, String text, {String? screenshotWhileStreaming}) async {
  await tester.tap(find.byKey(const Key('chat-input')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('chat-input')), text);
  await tester.pump();
  await tester.tap(find.byKey(const Key('send-button')));
  await waitFor(tester, find.byKey(const Key('stop-button')));
  if (screenshotWhileStreaming != null) {
    await pumpFor(tester, const Duration(milliseconds: 500));
    await screenshot(tester, screenshotWhileStreaming);
  }
  await waitFor(tester, find.byKey(const Key('send-button')), timeout: const Duration(seconds: 40));
  await pumpFor(tester, const Duration(milliseconds: 300));
}

Future<Map<String, dynamic>> serverSettings() async {
  final base = AppConfig.apiBaseUrl;
  final login = await http.post(
    Uri.parse('$base/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  final token = (jsonDecode(login.body) as Map)['token'];
  final res = await http.get(Uri.parse('$base/api/settings'), headers: {'Authorization': 'Bearer $token'});
  return (jsonDecode(res.body) as Map)['settings'] as Map<String, dynamic>;
}

void main() {
  initBinding();

  final run = DateTime.now().millisecondsSinceEpoch % 1000000;

  testWidgets('chat, history, usage, settings and plans against the backend', (tester) async {
    await startApp(tester);
    await signIn(tester);
    await waitFor(tester, find.textContaining('credits'));
    await screenshot(tester, 'home');

    // --- B1: chat ---
    if (!isDesktop) await tester.tap(find.text('Start Chat'));
    await waitFor(tester, find.byKey(const Key('chat-input')));
    await waitForGone(tester, find.text('Loading models…'));

    await tester.tap(find.byKey(const Key('model-picker')));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await screenshot(tester, 'model_picker');
    // Further down: models the server can't answer with are listed, disabled.
    await scrollTo(tester, find.text('Not available yet'), find.byType(Scrollable).last);
    final unavailable = find.ancestor(of: find.text('Not available yet').first, matching: find.byType(ListTile));
    expect(tester.widget<ListTile>(unavailable).enabled, isFalse);
    await screenshot(tester, 'model_picker_unavailable');
    await scrollTo(tester, find.text(mockModel), find.byType(Scrollable).last, dy: 200);
    await tester.tap(find.text(mockModel).last);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text(mockModel), findsWidgets);

    await sendAndWait(
      tester,
      'Markdown check $run **bold**\n```js\nconsole.log("hi")\n```\n',
      screenshotWhileStreaming: 'streaming',
    );
    expect(mockReplies(tester), 1);
    expect(find.text('Copy code'), findsWidgets, reason: 'the code block renders with its own Copy button');
    await screenshot(tester, 'reply_markdown');

    // Copy
    await tester.tap(find.byTooltip('Copy').last);
    await tester.pump();
    final clip = await Clipboard.getData('text/plain');
    expect(clip?.text, contains('Mock reply'));
    await pumpFor(tester, const Duration(seconds: 1));

    // Regenerate: the server answers the same question again and replaces
    // the old reply (no duplicate question in the history).
    final oldReplyId = sessionMessages(tester).last.id;
    await tester.tap(find.byTooltip('Regenerate'));
    await waitFor(tester, find.byKey(const Key('stop-button')));
    await waitFor(tester, find.byKey(const Key('send-button')), timeout: const Duration(seconds: 40));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(mockReplies(tester), 1);
    expect(sessionMessages(tester).where((m) => m.role == MessageRole.user), hasLength(1));
    expect(sessionMessages(tester).last.id, isNot(oldReplyId));
    await screenshot(tester, 'regenerated');

    // Stop, in a second chat: the partial reply stays.
    await tester.tap(find.byTooltip('New chat').first);
    await pumpFor(tester, const Duration(milliseconds: 500));
    // Click into the box first, as a user would (it isn't focused after New chat).
    await tester.tap(find.byKey(const Key('chat-input')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('chat-input')), 'Stop test $run');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await waitFor(tester, find.byKey(const Key('stop-button')));
    await waitFor(tester, find.byWidgetPredicate((w) => w is AIHubMessageBubble && w.message.content.length > 20));
    await tester.tap(find.byKey(const Key('stop-button')));
    await waitFor(tester, find.byKey(const Key('send-button')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    final partial = sessionMessages(tester).last.content;
    expect(partial, startsWith('[Mock reply'));
    expect(partial, isNot(contains('to get real answers')), reason: 'Stop ended the reply early');
    await screenshot(tester, 'stopped');

    // --- B2: history, search, rename, delete ---
    if (!isDesktop) {
      await tester.tap(find.byTooltip('Close'));
      await pumpFor(tester, const Duration(milliseconds: 600));
    }
    await openTab(tester, 'History');
    await waitFor(tester, find.text('Markdown check $run **bold**'));
    expect(find.text('Stop test $run'), findsWidgets);
    await screenshot(tester, 'history');

    final search = find.byKey(const Key('search-field')).last;
    await tester.enterText(search, 'zzzunmatchedzzz');
    await waitFor(tester, find.textContaining('No chats match'));
    await tester.enterText(search, 'Markdown check $run');
    await waitFor(tester, find.text('Markdown check $run **bold**'));
    await waitForGone(tester, find.text('Stop test $run'));
    await screenshot(tester, 'history_search');
    await tester.enterText(search, '');
    await waitFor(tester, find.text('Stop test $run'));

    // Rename the first chat.
    final firstTile = find.ancestor(of: find.text('Markdown check $run **bold**').last, matching: find.byType(InkWell)).first;
    await tester.tap(find.descendant(of: firstTile, matching: find.byTooltip('Chat options')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Rename').last);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.enterText(find.byKey(const Key('rename-field')), 'Renamed by e2e');
    await tester.tap(find.text('Save').last);
    await waitFor(tester, find.text('Renamed by e2e'));

    // Delete the stopped chat.
    final stopTile = find.ancestor(of: find.text('Stop test $run').last, matching: find.byType(InkWell)).first;
    await tester.tap(find.descendant(of: stopTile, matching: find.byTooltip('Chat options')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Delete').last);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await waitForGone(tester, find.text('Stop test $run'));
    await screenshot(tester, 'history_renamed_deleted');

    // --- B4: balance and usage ---
    await openTab(tester, 'Usage');
    await waitFor(tester, find.byKey(const Key('usage-tokens')));
    expect(find.byKey(const Key('available-credits')), findsWidgets);
    await screenshot(tester, 'usage');

    // --- Settings, saved on the server ---
    await openTab(tester, 'Settings');
    await waitFor(tester, find.byKey(const Key('show-timestamps')));
    final before = (await tester.runAsync(serverSettings))!;
    final toggle = find.byKey(const Key('show-timestamps'));
    await tester.ensureVisible(toggle);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(toggle);
    await pumpFor(tester, const Duration(seconds: 1));
    final after = (await tester.runAsync(serverSettings))!;
    expect(after['show_timestamps'], !(before['show_timestamps'] as bool));
    await screenshot(tester, 'settings');
    await tester.tap(toggle); // put it back
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Plans from the server ---
    await tester.ensureVisible(find.text('View plans'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('View plans'));
    await pumpFor(tester, const Duration(seconds: 1));
    if (isDesktop) {
      await waitFor(tester, find.text('Starter'));
      expect(find.byKey(const Key('open-web-upgrade')), findsOneWidget);
    } else {
      // No RevenueCat key in this build, and no plan has a store product yet.
      await waitFor(tester, find.text('In-app purchases aren’t available in this build.'));
      expect(find.text('No plans can be bought in the app yet.'), findsOneWidget);
    }
    await screenshot(tester, 'plans');
  });
}
