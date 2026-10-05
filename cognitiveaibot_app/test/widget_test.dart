import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveaibot/main.dart';
import 'package:cognitiveaibot/presentation/widgets/plan_status_text.dart';

// Strings the app used to show as if they were the user's own account. With
// no sign-in and no purchase, none of them may appear anywhere.
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
];

Future<void> _pumpApp(WidgetTester tester) async {
  // Tests run on a desktop host, so the app uses its desktop layout.
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: CognitiveAIBotApp()));
  await tester.pumpAndSettle();
}

void _expectNoFabricatedData() {
  for (final text in _fabricated) {
    expect(find.textContaining(text), findsNothing, reason: '"$text" is not real account data');
  }
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the app starts on Home, with no invented account', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Start Chat'), findsOneWidget);
    expect(find.text(notSignedInLabel), findsWidgets);
    _expectNoFabricatedData();
  });

  testWidgets('Settings shows the real plan state, not a fake Pro subscription', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'Settings');

    expect(find.text('Free plan'), findsWidgets);
    expect(find.text('View plans'), findsWidgets);
    _expectNoFabricatedData();
  });

  testWidgets('Usage says there is no usage yet instead of showing sample figures', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'Usage');

    expect(find.text('No usage yet'), findsOneWidget);
    _expectNoFabricatedData();
  });

  testWidgets('History starts empty instead of listing invented chats', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'History');

    expect(find.text('No conversations yet'), findsOneWidget);
    _expectNoFabricatedData();
  });

  test('plan labels follow the entitlement', () {
    expect(PlanStatusText.labelFor(PlanText.title, isPro: false), 'Free plan');
    expect(PlanStatusText.labelFor(PlanText.title, isPro: true), 'CognitiveAI Bot Pro');
    expect(PlanStatusText.labelFor(PlanText.badge, isPro: true), 'PRO');
    expect(PlanStatusText.labelFor(PlanText.actionLabel, isPro: false), 'View plans');
  });
}
