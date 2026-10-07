import 'package:cognitiveaibot/main.dart';
import 'package:cognitiveaibot/presentation/screens/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_harness.dart';
import 'helpers/fake_backend.dart';

// Strings the app used to show as if they were the user's own account. None
// may come back: everything shown now comes from the server.
const _fabricated = [
  'Alex Rivera',
  'Lutfor Rahman',
  'PRO MEMBER',
  'Pro Member',
  'Next billing date: Oct 12, 2024',
  r'$12.45',
  '2.5M',
  'Market Analysis Report',
  r'$42.84',
  'Oct 18 - Oct 24',
  'Flora Diary',
  'placeholder response',
  'Not signed in',
];

void _expectNoFabricatedData() {
  for (final text in _fabricated) {
    expect(find.textContaining(text), findsNothing, reason: '"$text" is not real account data');
  }
}

Future<FakeBackend> _pumpApp(WidgetTester tester, {bool signedIn = true, FakeBackend? backend}) async {
  // Tests run on a desktop host, so the app uses its desktop layout.
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final b = backend ?? FakeBackend();
  await tester.pumpWidget(ProviderScope(
    overrides: fakeBackendOverrides(b, savedToken: signedIn ? b.token : null),
    child: const CognitiveAIBotApp(),
  ));
  await tester.pumpAndSettle();
  return b;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out: email sign-in only, no social buttons, no invented account', (tester) async {
    await _pumpApp(tester, signedIn: false);
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('GitHub'), findsNothing);
    _expectNoFabricatedData();
  });

  testWidgets('wrong password shows the server message; right one opens the app', (tester) async {
    await _pumpApp(tester, signedIn: false);
    await tester.enterText(find.byKey(const Key('email-field')), 'tester@example.test');
    await tester.enterText(find.byKey(const Key('password-field')), 'wrong');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('password-field')), 'right-password');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Tester'), findsWidgets);
    expect(find.text('12.50 credits'), findsWidgets);
  });

  testWidgets('a saved session signs in on launch; Log Out returns to sign-in', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Tester'), findsWidgets);
    expect(find.text('Free plan'), findsWidgets);
    _expectNoFabricatedData();

    await tester.tap(find.text('Log Out').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
  });

  testWidgets('chat: streamed Markdown reply with Copy and Regenerate, no Like/Dislike', (tester) async {
    final backend = FakeBackend()
      ..sse = [
        FakeBackend.event({'type': 'start', 'user_message': {'id': 'u1', 'role': 'user', 'content': 'Code please'}, 'chat': {'title': 'Code please'}}),
        FakeBackend.event({'type': 'delta', 'text': 'Here:\n\n```dart\nprint(1);\n```\n'}),
        FakeBackend.event({'type': 'done', 'message': {'id': 'r1', 'role': 'assistant', 'content': 'Here:\n\n```dart\nprint(1);\n```\n', 'model_name': 'GPT Test'}}),
      ];
    await _pumpApp(tester, backend: backend);
    expect(find.text('GPT Test'), findsWidgets, reason: 'first available model is chosen');
    await tester.enterText(find.byKey(const Key('chat-input')), 'Code please');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('Copy code'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Regenerate'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
    expect(find.byIcon(Icons.thumb_down_outlined), findsNothing);
    expect(find.text('Code please'), findsWidgets, reason: 'title from the server');
  });

  testWidgets('a refused reply shows the server message and Get credits', (tester) async {
    final backend = FakeBackend();
    backend.overrides['POST /api/chats/c1/completions'] =
        (_) => FakeBackend.json({'error': 'You’re out of credits.', 'code': 'INSUFFICIENT_CREDITS'}, 402);
    await _pumpApp(tester, backend: backend);
    await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();
    expect(find.text('You’re out of credits.'), findsOneWidget);
    expect(find.text('Get credits'), findsOneWidget);
    final input = tester.widget<TextField>(find.byKey(const Key('chat-input')));
    expect(input.controller!.text, 'Hello', reason: 'the unsent text is given back');
  });

  testWidgets('History lists the server chats and searches on the server', (tester) async {
    final backend = FakeBackend()
      ..chats = [
        {'id': 'a', 'title': 'Trip to Rome', 'excerpt': 'Day one…', 'model_name': 'GPT Test', 'created_at': '2026-10-01T10:00:00Z', 'updated_at': '2026-10-02T10:00:00Z'},
        {'id': 'b', 'title': 'Taxes', 'created_at': '2026-10-01T10:00:00Z', 'updated_at': '2026-10-01T10:00:00Z'},
      ];
    await _pumpApp(tester, backend: backend);
    await _openTab(tester, 'History');
    expect(find.text('Trip to Rome'), findsWidgets);
    expect(find.text('Taxes'), findsWidgets);

    await tester.enterText(find.byKey(const Key('search-field')).last, 'rome');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(backend.requests.any((r) => r.url.queryParameters['search'] == 'rome'), isTrue);
    _expectNoFabricatedData();
  });

  testWidgets('History starts empty for a new account', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'History');
    expect(find.text('No conversations yet'), findsOneWidget);
    _expectNoFabricatedData();
  });

  testWidgets('Usage shows the real balance, and no sample figures before any usage', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'Usage');
    expect(find.text('No usage yet'), findsOneWidget);
    expect(find.text('12.50 credits'), findsWidgets);
    _expectNoFabricatedData();
  });

  testWidgets('Usage shows the server summary', (tester) async {
    final backend = FakeBackend()
      ..usage = {
        'days': 30,
        'totals': {'requests': 7, 'api_requests': 0, 'input_tokens': 1000, 'output_tokens': 500, 'credits': 3.5},
        'by_day': [{'day': '2026-10-05', 'requests': 7, 'input_tokens': 1000, 'output_tokens': 500, 'credits': 3.5}],
        'by_model': [{'model': 'gpt', 'name': 'GPT Test', 'provider': 'OpenAI', 'requests': 7, 'input_tokens': 1000, 'output_tokens': 500, 'credits': 3.5}],
      };
    await _pumpApp(tester, backend: backend);
    await _openTab(tester, 'Usage');
    expect(find.descendant(of: find.byKey(const Key('usage-credits')), matching: find.text('3.50')), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('1.5k'), findsOneWidget);
    expect(find.text('GPT Test · OpenAI'), findsOneWidget);
  });

  testWidgets('Settings are read from and saved to the server', (tester) async {
    final backend = await _pumpApp(tester);
    await _openTab(tester, 'Settings');
    expect(find.text('tester@example.test'), findsOneWidget);
    final toggle = find.byKey(const Key('show-timestamps'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(backend.settings['show_timestamps'], isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('desktop plans: every server plan, bought on the web', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await tester.pumpWidget(ProviderScope(
      overrides: fakeBackendOverrides(backend, savedToken: backend.token),
      child: const MaterialApp(home: PlansScreen(desktop: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('450 credits'), findsWidgets);
    expect(find.byKey(const Key('open-web-upgrade')), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('mobile plans: only plans with a RevenueCat product; purchases off without a key', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(ProviderScope(
      overrides: fakeBackendOverrides(backend, savedToken: backend.token),
      child: const MaterialApp(home: PlansScreen(desktop: false)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Starter'), findsNothing);
    expect(find.text('450 credits'), findsNothing);
    expect(find.text('In-app purchases aren’t available in this build.'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing, reason: 'no buy button while purchases are off');
    expect(find.byKey(const Key('open-web-upgrade')), findsNothing);
  });
}
