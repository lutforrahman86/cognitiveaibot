import 'dart:convert';

import 'package:cognitiveaibot/core/config/app_config.dart';
import 'package:cognitiveaibot/core/storage/export_saver.dart';
import 'package:cognitiveaibot/core/storage/token_store.dart';
import 'package:cognitiveaibot/main.dart';
import 'package:cognitiveaibot/presentation/providers/auth_provider.dart';
import 'package:cognitiveaibot/presentation/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

class _RecordingSaver implements ExportSaver {
  final saved = <String, String>{};

  @override
  Future<SavedExport> save(String fileName, String contents) async {
    saved[fileName] = contents;
    return SavedExport(path: '/Users/me/Downloads/$fileName', description: 'Downloads');
  }
}

class _Harness {
  _Harness(this.backend, this.tokens);

  final FakeBackend backend;
  final MemoryTokenStore tokens;
  final opened = <Uri>[];
  final saver = _RecordingSaver();
}

/// The whole app on a desktop-sized window (tests run on a desktop host).
Future<_Harness> _pumpApp(WidgetTester tester, {bool signedIn = true, FakeBackend? backend}) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final b = backend ?? FakeBackend();
  final h = _Harness(b, MemoryTokenStore(signedIn ? b.token : null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      httpClientProvider.overrideWithValue(b),
      tokenStoreProvider.overrideWithValue(h.tokens),
      exportSaverProvider.overrideWithValue(h.saver),
      linkOpenerProvider.overrideWithValue((url) async {
        h.opened.add(url);
        return true;
      }),
    ],
    child: const CognitiveAIBotApp(),
  ));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Settings').first);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _lastBody(FakeBackend b, String method, String path) {
  for (var i = b.requests.length - 1; i >= 0; i--) {
    if (b.requests[i].method == method && b.requests[i].url.path == path) {
      return jsonDecode(b.bodies[i]) as Map<String, dynamic>;
    }
  }
  throw StateError('no $method $path');
}

bool _sent(FakeBackend b, String method, String path) =>
    b.requests.any((r) => r.method == method && r.url.path == path);

void main() {
  group('forgot password', () {
    testWidgets('sends the email and says a link is on its way', (tester) async {
      final h = await _pumpApp(tester, signedIn: false);
      await tester.enterText(find.byKey(const Key('email-field')), 'tester@example.test');
      await tester.tap(find.byKey(const Key('forgot-password')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byKey(const Key('forgot-email-field')));
      expect(field.controller!.text, 'tester@example.test', reason: 'the sign-in email is carried over');
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pumpAndSettle();
      expect(_lastBody(h.backend, 'POST', '/api/auth/forgot-password'), {'email': 'tester@example.test'});
      expect(find.textContaining('If an account uses that email, a reset link is on its way'), findsOneWidget);
      await tester.tap(find.byKey(const Key('forgot-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    });

    testWidgets('an invalid email is caught before anything is sent', (tester) async {
      final h = await _pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(const Key('forgot-password')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('forgot-email-field')), 'not-an-email');
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(_sent(h.backend, 'POST', '/api/auth/forgot-password'), isFalse);
    });
  });

  group('sign-up', () {
    testWidgets('legal links open the web pages; passwords need 8 characters', (tester) async {
      final h = await _pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(const Key('auth-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Password (at least 8 characters)'), findsOneWidget);
      expect(find.textContaining('By creating an account you agree to the'), findsOneWidget);
      await tester.tap(find.byKey(const Key('legal-terms')));
      await tester.tap(find.byKey(const Key('legal-acceptableUse')));
      await tester.tap(find.byKey(const Key('legal-privacy')));
      await tester.pumpAndSettle();
      expect(h.opened, [AppConfig.termsUrl, AppConfig.acceptableUseUrl, AppConfig.privacyUrl]);
      expect(h.opened.map((u) => u.path), ['/terms', '/acceptable-use', '/privacy']);

      await tester.enterText(find.byKey(const Key('email-field')), 'new@example.test');
      await tester.enterText(find.byKey(const Key('password-field')), 'short7c');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Use a password of at least 8 characters.'), findsOneWidget);
      expect(_sent(h.backend, 'POST', '/api/auth/register'), isFalse);
    });

    testWidgets('a new, unconfirmed account sees the confirmation banner', (tester) async {
      final backend = FakeBackend()..emailVerified = false;
      await _pumpApp(tester, signedIn: false, backend: backend);
      await tester.tap(find.byKey(const Key('auth-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email-field')), 'new@example.test');
      await tester.enterText(find.byKey(const Key('password-field')), 'long-enough');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('verify-email-banner')), findsOneWidget);
    });
  });

  group('email confirmation banner', () {
    testWidgets('not shown for a confirmed account', (tester) async {
      await _pumpApp(tester);
      expect(find.byKey(const Key('verify-email-banner')), findsNothing);
    });

    testWidgets('Resend sends a new email; Dismiss hides the banner', (tester) async {
      final h = await _pumpApp(tester, backend: FakeBackend()..emailVerified = false);
      expect(find.text('Confirm your email to get your trial credits and to buy credits'), findsOneWidget);
      await tester.tap(find.byKey(const Key('resend-verification')));
      await tester.pumpAndSettle();
      expect(h.backend.verificationEmails, 1);
      expect(find.text('Confirmation email sent to tester@example.test.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dismiss-verify-banner')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('verify-email-banner')), findsNothing);
    });

    testWidgets('too many emails shows the server message', (tester) async {
      final backend = FakeBackend()..emailVerified = false;
      backend.overrides['POST /api/auth/resend-verification'] =
          (_) => FakeBackend.json({'error': 'Too many emails. Try again in an hour.', 'code': 'TOO_MANY_EMAILS'}, 429);
      await _pumpApp(tester, backend: backend);
      await tester.tap(find.byKey(const Key('resend-verification')));
      await tester.pumpAndSettle();
      expect(find.text('Too many emails. Try again in an hour.'), findsOneWidget);
      expect(find.byKey(const Key('verify-email-banner')), findsOneWidget);
    });

    testWidgets('disappears once the server says the email is confirmed', (tester) async {
      final backend = FakeBackend()..emailVerified = false;
      await _pumpApp(tester, backend: backend);
      expect(find.byKey(const Key('verify-email-banner')), findsOneWidget);
      backend.emailVerified = true; // confirmed on the web
      final container = ProviderScope.containerOf(tester.element(find.byType(CognitiveAIBotApp)));
      await container.read(authControllerProvider.notifier).refreshUser();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('verify-email-banner')), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('change password: wrong current password, then success keeps this device signed in', (tester) async {
      final h = await _pumpApp(tester);
      await _openSettings(tester);
      await _tapVisible(tester, find.byKey(const Key('settings-change-password')));

      await tester.enterText(find.byKey(const Key('current-password-field')), 'nope-nope');
      await tester.enterText(find.byKey(const Key('new-password-field')), 'brand-new-pass');
      await tester.enterText(find.byKey(const Key('repeat-password-field')), 'brand-new-pass');
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Your current password isn’t right.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('current-password-field')), 'right-password');
      await tester.enterText(find.byKey(const Key('new-password-field')), 'short');
      await tester.enterText(find.byKey(const Key('repeat-password-field')), 'short');
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Use a password of at least 8 characters.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('new-password-field')), 'brand-new-pass');
      await tester.enterText(find.byKey(const Key('repeat-password-field')), 'brand-new-pass');
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();
      expect(_lastBody(h.backend, 'POST', '/api/users/me/password'),
          {'current_password': 'right-password', 'new_password': 'brand-new-pass'});
      expect(find.text('Password changed. Other devices were signed out.'), findsOneWidget);
      expect(await h.tokens.read(), 'token-after-password-change', reason: 'the new token is saved');

      // The old token is rejected now; the app goes on working with the new one.
      final container = ProviderScope.containerOf(tester.element(find.byType(CognitiveAIBotApp)));
      await container.read(authControllerProvider.notifier).refreshUser();
      await tester.pumpAndSettle();
      expect(container.read(authControllerProvider).status, AuthStatus.signedIn);
      expect(h.backend.requests.last.headers['Authorization'], 'Bearer token-after-password-change');
    });

    testWidgets('delete account: wrong password is refused; right one returns to sign-in with the App Store note',
        (tester) async {
      final h = await _pumpApp(tester);
      await _openSettings(tester);
      await _tapVisible(tester, find.byKey(const Key('settings-delete-account')));
      expect(find.textContaining('An App Store subscription isn’t'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('delete-account-confirm-field')), 'wrong');
      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();
      expect(find.text('That password isn’t right.'), findsOneWidget);
      expect(h.backend.deleted, isFalse);

      await tester.enterText(find.byKey(const Key('delete-account-confirm-field')), 'right-password');
      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();
      expect(_lastBody(h.backend, 'DELETE', '/api/users/me'), {'confirm': 'right-password'});
      expect(h.backend.deleted, isTrue);
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
      expect(find.byKey(const Key('auth-info')), findsOneWidget);
      expect(find.textContaining('cancel it in your Apple account settings'), findsOneWidget);
      expect(await h.tokens.read(), isNull, reason: 'the session is forgotten');
    });

    testWidgets('last admin can’t be deleted: the server reason is shown', (tester) async {
      final backend = FakeBackend();
      backend.overrides['DELETE /api/users/me'] = (_) => FakeBackend.json(
          {'error': 'This is the only admin account. Make another admin before deleting it.', 'code': 'LAST_ADMIN'}, 400);
      await _pumpApp(tester, backend: backend);
      await _openSettings(tester);
      await _tapVisible(tester, find.byKey(const Key('settings-delete-account')));
      await tester.enterText(find.byKey(const Key('delete-account-confirm-field')), 'right-password');
      await tester.tap(find.byKey(const Key('delete-account-submit')));
      await tester.pumpAndSettle();
      expect(find.text('This is the only admin account. Make another admin before deleting it.'), findsOneWidget);
      expect(find.byKey(const Key('auth-submit')), findsNothing);
    });

    testWidgets('download my data saves the export as JSON', (tester) async {
      final h = await _pumpApp(tester);
      await _openSettings(tester);
      await _tapVisible(tester, find.byKey(const Key('settings-export')));
      expect(h.saver.saved.keys.single, matches(RegExp(r'^cognitiveaibot-export-\d{4}-\d{2}-\d{2}\.json$')));
      final json = jsonDecode(h.saver.saved.values.single) as Map;
      expect((json['profile'] as Map)['email'], 'tester@example.test');
      expect(find.textContaining('to Downloads.'), findsOneWidget);
    });

    testWidgets('legal pages open in the browser', (tester) async {
      final h = await _pumpApp(tester);
      await _openSettings(tester);
      await _tapVisible(tester, find.byKey(const Key('settings-legal-terms')));
      await _tapVisible(tester, find.byKey(const Key('settings-legal-acceptableUse')));
      await _tapVisible(tester, find.byKey(const Key('settings-legal-privacy')));
      expect(h.opened, [AppConfig.termsUrl, AppConfig.acceptableUseUrl, AppConfig.privacyUrl]);
    });
  });

  group('chat', () {
    FakeBackend replyBackend() => FakeBackend()
      ..messages['c1'] = [
        {'id': '7d0c6f4e-0000-4000-8000-000000000001', 'role': 'assistant', 'content': 'Hi there'},
      ]
      ..sse = [
        FakeBackend.event({'type': 'start', 'user_message': {'id': 'q1', 'role': 'user', 'content': 'Hello'}}),
        FakeBackend.event({'type': 'delta', 'text': 'Hi there'}),
        FakeBackend.event({
          'type': 'done',
          'message': {'id': '7d0c6f4e-0000-4000-8000-000000000001', 'role': 'assistant', 'content': 'Hi there'},
        }),
      ];

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('chat-input')), text);
      await tester.pump();
      await tester.tap(find.byKey(const Key('send-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('report a saved reply with a reason and details', (tester) async {
      final h = await _pumpApp(tester, backend: replyBackend());
      await send(tester, 'Hello');
      await tester.tap(find.byTooltip('Report'));
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('report-submit'));
      expect(tester.widget<TextButton>(submit).onPressed, isNull, reason: 'a reason must be chosen first');
      await tester.tap(find.byKey(const Key('report-reason-inaccurate')));
      await tester.enterText(find.byKey(const Key('report-details')), '  Wrong date  ');
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(h.backend.reports.single, {
        'message_id': '7d0c6f4e-0000-4000-8000-000000000001',
        'reason': 'inaccurate',
        'details': 'Wrong date',
      });
      expect(find.text('Thanks. The reply was reported for review.'), findsOneWidget);
    });

    testWidgets('a report the server can’t find shows its message', (tester) async {
      final backend = replyBackend()..messages.clear();
      await _pumpApp(tester, backend: backend);
      await send(tester, 'Hello');
      await tester.tap(find.byTooltip('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-reason-harmful')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-submit')));
      await tester.pumpAndSettle();
      expect(find.text('That reply wasn’t found in your chats.'), findsOneWidget);
    });

    testWidgets('a blocked prompt is explained and the text given back', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /api/chats/c1/completions'] = (_) => FakeBackend.json(
          {'error': 'This request breaks the content rules, so it wasn’t sent.', 'code': 'CONTENT_BLOCKED'}, 400);
      await _pumpApp(tester, backend: backend);
      await send(tester, 'something bad');
      expect(find.text('This request breaks the content rules, so it wasn’t sent.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, 'something bad');
    });

    testWidgets('too many messages is explained', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /api/chats/c1/completions'] = (_) =>
          FakeBackend.json({'error': 'You’re sending messages very fast. Wait a moment.', 'code': 'TOO_MANY_MESSAGES'}, 429);
      await _pumpApp(tester, backend: backend);
      await send(tester, 'Hello');
      expect(find.text('You’re sending messages very fast. Wait a moment, then try again.'), findsOneWidget);
    });

    testWidgets('password changed elsewhere: back to sign-in with that reason', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /api/chats/c1/completions'] = (_) =>
          FakeBackend.json({'error': 'Your password was changed. Sign in again.', 'code': 'SESSION_EXPIRED'}, 401);
      await _pumpApp(tester, backend: backend);
      await send(tester, 'Hello');
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
      expect(find.text('Your password was changed. Sign in again.'), findsOneWidget);
    });
  });
}
