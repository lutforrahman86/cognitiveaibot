import 'dart:async';
import 'dart:convert';

import 'package:cognitiveaibot/core/network/api_client.dart';
import 'package:cognitiveaibot/core/storage/token_store.dart';
import 'package:cognitiveaibot/core/usecases/usecase.dart';
import 'package:cognitiveaibot/data/datasources/account_remote_datasource.dart';
import 'package:cognitiveaibot/data/datasources/auth_remote_datasource.dart';
import 'package:cognitiveaibot/data/datasources/chat_remote_datasource_impl.dart';
import 'package:cognitiveaibot/data/models/account_models.dart';
import 'package:cognitiveaibot/data/repositories/account_repository_impl.dart';
import 'package:cognitiveaibot/data/repositories/auth_repository_impl.dart';
import 'package:cognitiveaibot/data/repositories/chat_repository_impl.dart';
import 'package:cognitiveaibot/domain/entities/account.dart';
import 'package:cognitiveaibot/domain/entities/chat_message.dart';
import 'package:cognitiveaibot/domain/entities/completion_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late SessionHolder session;
  late ApiClient api;

  setUp(() {
    backend = FakeBackend();
    session = SessionHolder()..token = backend.token;
    api = ApiClient(baseUrl: 'http://api.test', session: session, httpClient: backend);
  });

  group('ChatRepository', () {
    late ChatRepositoryImpl repo;
    setUp(() => repo = ChatRepositoryImpl(remoteDataSource: ChatRemoteDataSourceImpl(api)));

    test('lists models with availability', () async {
      final result = await repo.getModels() as Success;
      expect(result.data.map((m) => (m.name, m.available)), [('GPT Test', true), ('Claude Test', false)]);
    });

    test('search is sent to the server', () async {
      backend.chats = [
        {'id': 'a', 'title': 'Trip to Rome', 'created_at': '2026-10-01T10:00:00Z', 'updated_at': '2026-10-02T10:00:00Z', 'model_name': 'GPT Test'},
        {'id': 'b', 'title': 'Taxes', 'created_at': '2026-10-01T10:00:00Z', 'updated_at': '2026-10-01T10:00:00Z'},
      ];
      final result = await repo.getConversations(search: 'rome') as Success;
      expect(backend.requests.last.url.queryParameters['search'], 'rome');
      expect(result.data.single.title, 'Trip to Rome');
      expect(result.data.single.modelName, 'GPT Test');
    });

    test('messages map role, model and time', () async {
      backend.messages['a'] = [
        {'id': '1', 'role': 'user', 'content': 'Hi', 'created_at': '2026-10-05T10:00:00Z'},
        {'id': '2', 'role': 'assistant', 'content': 'Hello', 'model_id': 'm1', 'model_name': 'GPT Test', 'created_at': '2026-10-05T10:00:01Z'},
      ];
      final result = await repo.getMessages('a') as Success;
      final list = result.data as List<ChatMessage>;
      expect(list.map((m) => m.role), [MessageRole.user, MessageRole.assistant]);
      expect(list.last.modelName, 'GPT Test');
    });

    test('streams start, deltas and done', () async {
      backend.sse = [
        FakeBackend.event({'type': 'start', 'user_message': {'id': 'u1', 'role': 'user', 'content': 'Hi'}, 'chat': {'id': 'c1', 'title': 'Hi'}}),
        FakeBackend.event({'type': 'delta', 'text': 'Hel'}),
        FakeBackend.event({'type': 'delta', 'text': 'lo'}),
        FakeBackend.event({'type': 'done', 'message': {'id': 'r1', 'role': 'assistant', 'content': 'Hello'}, 'usage': {}, 'credits': {'charged': 0.01, 'balance': 9.99}}),
      ];
      final events = await repo.streamReply(conversationId: 'c1', content: 'Hi', modelId: 'm1').toList();
      expect(events[0], isA<CompletionStarted>().having((e) => e.chatTitle, 'title', 'Hi'));
      expect(events.whereType<CompletionDelta>().map((e) => e.text).join(), 'Hello');
      expect(events.last, isA<CompletionDone>().having((e) => e.balance, 'balance', 9.99));
      expect(jsonDecode(backend.bodies.last), {'content': 'Hi', 'model_id': 'm1'});
    });

    test('regenerate asks the server to answer the last message again', () async {
      backend.sse = [FakeBackend.event({'type': 'done', 'message': null})];
      await repo.streamReply(conversationId: 'c1', modelId: 'm1', regenerate: true).toList();
      expect(jsonDecode(backend.bodies.last), {'regenerate': true, 'model_id': 'm1'});
    });

    test('a refusal before streaming (402) becomes a refused failure event', () async {
      backend.overrides['POST /api/chats/c1/completions'] =
          (_) => FakeBackend.json({'error': 'Not enough credits.', 'code': 'INSUFFICIENT_CREDITS'}, 402);
      final events = await repo.streamReply(conversationId: 'c1', content: 'Hi', modelId: 'm1').toList();
      expect(
        events.single,
        isA<CompletionFailed>()
            .having((e) => e.refused, 'refused', isTrue)
            .having((e) => e.code, 'code', 'INSUFFICIENT_CREDITS')
            .having((e) => e.message, 'message', 'Not enough credits.'),
      );
    });

    test('a provider error mid-reply keeps the saved partial message', () async {
      backend.sse = [
        FakeBackend.event({'type': 'start', 'user_message': {'id': 'u1', 'role': 'user', 'content': 'Hi'}, 'chat': {}}),
        FakeBackend.event({'type': 'delta', 'text': 'Par'}),
        FakeBackend.event({'type': 'error', 'code': 'PROVIDER_ERROR', 'error': 'The model failed.', 'message': {'id': 'r1', 'role': 'assistant', 'content': 'Par'}}),
      ];
      final events = await repo.streamReply(conversationId: 'c1', content: 'Hi', modelId: 'm1').toList();
      expect(events.last, isA<CompletionFailed>().having((e) => e.refused, 'refused', isFalse).having((e) => e.partial?.content, 'partial', 'Par'));
    });

    test('completing the cancel future closes the stream (Stop)', () async {
      final controller = StreamController<List<int>>();
      backend.overrides['POST /api/chats/c1/completions'] = (_) =>
          http.StreamedResponse(controller.stream, 200, headers: {'content-type': 'text/event-stream'});
      final stop = Completer<void>();
      final received = <CompletionEvent>[];
      final done = repo.streamReply(conversationId: 'c1', content: 'Hi', modelId: 'm1', cancel: stop.future).forEach(received.add);
      controller.add(utf8.encode(FakeBackend.event({'type': 'delta', 'text': 'partial'})));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      stop.complete();
      await done.timeout(const Duration(seconds: 2));
      expect(received.whereType<CompletionDelta>().single.text, 'partial');
      await controller.close();
    });

    test('rename and delete hit the chat endpoints', () async {
      backend.chats = [{'id': 'a', 'title': 'Old', 'created_at': '2026-10-01T10:00:00Z'}];
      final renamed = await repo.updateConversationTitle('a', 'New') as Success;
      expect(renamed.data.title, 'New');
      expect(await repo.deleteConversation('a'), isA<Success<void>>());
      expect(backend.chats, isEmpty);
    });
  });

  group('AuthRepository', () {
    late MemoryTokenStore store;
    late AuthRepositoryImpl repo;
    setUp(() {
      session.token = null;
      store = MemoryTokenStore();
      repo = AuthRepositoryImpl(remote: AuthRemoteDataSourceImpl(api), tokenStore: store, session: session);
    });

    test('sign-in saves the token and uses it for later calls', () async {
      final result = await repo.signIn(email: 'tester@example.test', password: 'right-password');
      expect(result, isA<Success>());
      expect(await store.read(), backend.token);
      expect(session.token, backend.token);
    });

    test('wrong password returns the server message', () async {
      final result = await repo.signIn(email: 'tester@example.test', password: 'nope') as FailureResult;
      expect(result.failure.message, 'Invalid email or password');
      expect(await store.read(), isNull);
    });

    test('restore uses the saved token; an expired one is deleted', () async {
      await store.write(backend.token);
      final ok = await repo.restoreSession() as Success;
      expect(ok.data?.user.email, 'tester@example.test');

      await store.write('expired');
      final gone = await repo.restoreSession() as Success;
      expect(gone.data, isNull);
      expect(await store.read(), isNull);
    });

    test('sign-out forgets the token', () async {
      await repo.signIn(email: 'tester@example.test', password: 'right-password');
      await repo.signOut();
      expect(await store.read(), isNull);
      expect(session.token, isNull);
    });
  });

  group('AccountRepository', () {
    late AccountRepositoryImpl repo;
    setUp(() => repo = AccountRepositoryImpl(AccountRemoteDataSourceImpl(api)));

    test('billing: available credits and expiring plan credits', () async {
      backend.overrides['GET /api/billing'] = (_) => FakeBackend.json({
            'plan': {'id': 'p2', 'name': 'Pro', 'kind': 'subscription', 'price_cents': 2500, 'currency': 'usd', 'credits': 2250},
            'subscription': {'status': 'active', 'current_period_end': '2026-11-05T00:00:00Z', 'cancel_at_period_end': false},
            'payments_enabled': true,
            'credits': {'balance': '100.5', 'held': 0.5, 'available': 100, 'expiring': {'credits': 80, 'at': '2026-11-05T00:00:00Z'}},
          });
      final b = (await repo.getBilling() as Success).data as BillingInfo;
      expect(b.plan?.name, 'Pro');
      expect(b.credits.available, 100);
      expect(b.credits.balance, 100.5);
      expect(b.credits.expiringCredits, 80);
      expect(b.subscriptionStatus, 'active');
    });

    test('plans keep their RevenueCat product id (or null)', () async {
      final plans = (await repo.getPlans() as Success).data as List<Plan>;
      expect(plans.map((p) => p.revenueCatProductId), [null, 'cab_pro_monthly', null]);
      expect(plans.first.formattedPrice, r'$10 / month');
    });

    test('usage summary in credits', () async {
      backend.usage = {
        'days': 30,
        'totals': {'requests': 3, 'api_requests': 1, 'input_tokens': 100, 'output_tokens': 50, 'credits': 0.25},
        'by_day': [
          {'day': '2026-10-05', 'requests': 2, 'input_tokens': 60, 'output_tokens': 30, 'credits': 0.2},
          {'day': '2026-10-04', 'requests': 1, 'input_tokens': 40, 'output_tokens': 20, 'credits': 0.05},
        ],
        'by_model': [{'model': 'gpt', 'name': 'GPT Test', 'provider': 'OpenAI', 'requests': 3, 'input_tokens': 100, 'output_tokens': 50, 'credits': 0.25}],
      };
      final u = (await repo.getUsageDashboard() as Success).data as UsageDashboard;
      expect(u.credits, 0.25);
      expect(u.tokens, 150);
      expect(u.daily.map((d) => d.date.day), [4, 5], reason: 'oldest first');
      expect(u.models.single.name, 'GPT Test');
      expect(backend.requests.last.url.path, '/api/usage/summary');
    });

    test('settings: PATCH sends only what changed', () async {
      final s = (await repo.getSettings() as Success).data as UserSettings;
      expect(s.temperature, isNull);
      final next = s.copyWith(showTimestamps: false, temperature: 1.2);
      final saved = (await repo.updateSettings(s, next) as Success).data as UserSettings;
      expect(jsonDecode(backend.bodies.last), {'show_timestamps': false, 'temperature': 1.2});
      expect(saved.showTimestamps, isFalse);
      expect(settingsPatch(saved, saved.copyWith(clearTemperature: true)), {'temperature': null});
    });
  });
}
