import 'dart:async';
import 'dart:convert';

import 'package:cognitiveaibot/domain/entities/ai_model.dart';
import 'package:cognitiveaibot/domain/entities/chat_message.dart';
import 'package:cognitiveaibot/domain/entities/conversation.dart';
import 'package:cognitiveaibot/presentation/providers/auth_provider.dart';
import 'package:cognitiveaibot/presentation/providers/chat_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/app_harness.dart';
import 'helpers/fake_backend.dart';

const model = AiModel(id: 'm1', slug: 'gpt', name: 'GPT Test', provider: 'OpenAI', available: true);

List<String> reply(String text, {String userText = 'Hi', String? title}) => [
      FakeBackend.event({'type': 'start', 'user_message': {'id': 'srv-u', 'role': 'user', 'content': userText}, 'chat': {'title': title}}),
      for (final word in text.split(' ')) FakeBackend.event({'type': 'delta', 'text': '$word '}),
      FakeBackend.event({'type': 'done', 'message': {'id': 'srv-r-${text.hashCode}', 'role': 'assistant', 'content': '$text ', 'model_name': 'GPT Test'}, 'credits': {'charged': 0.01, 'balance': 12.49}}),
    ];

void main() {
  late FakeBackend backend;
  late ProviderContainer container;
  ChatSessionController controller() => container.read(chatSessionProvider.notifier);
  ChatSessionState state() => container.read(chatSessionProvider);

  setUp(() async {
    backend = FakeBackend();
    container = await signedInContainer(backend);
    container.listen(chatSessionProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('send creates the chat on the server and streams the reply in', () async {
    backend.sse = reply('Hello there', title: 'Hi');
    expect(await controller().send('Hi', model), isNull);
    expect(state().conversation?.id, 'c1');
    expect(state().conversation?.title, 'Hi');
    expect(state().messages.map((m) => (m.role, m.content.trim())), [(MessageRole.user, 'Hi'), (MessageRole.assistant, 'Hello there')]);
    expect(state().messages.first.id, 'srv-u', reason: 'replaced by the saved message');
    expect(state().streaming, isFalse);
  });

  test('a refused message (402) is taken back out and its new chat deleted', () async {
    backend.overrides['POST /api/chats/c1/completions'] =
        (_) => FakeBackend.json({'error': 'Not enough credits.', 'code': 'INSUFFICIENT_CREDITS'}, 402);
    final refused = await controller().send('Hi', model);
    expect(refused, 'Not enough credits.');
    expect(state().messages, isEmpty);
    expect(state().conversation, isNull);
    expect(state().errorCode, 'INSUFFICIENT_CREDITS');
    expect(backend.requests.any((r) => r.method == 'DELETE' && r.url.path == '/api/chats/c1'), isTrue);
  });

  test('regenerate re-answers the last question and replaces the old reply', () async {
    backend.sse = reply('First answer');
    await controller().send('Hi', model);
    backend.sse = [
      FakeBackend.event({'type': 'start', 'user_message': {'id': 'srv-u', 'role': 'user', 'content': 'Hi'}, 'chat': {}}),
      FakeBackend.event({'type': 'delta', 'text': 'Second answer'}),
      FakeBackend.event({'type': 'done', 'message': {'id': 'srv-r2', 'role': 'assistant', 'content': 'Second answer'}}),
    ];
    await controller().regenerate(model);
    expect(jsonDecode(backend.bodies.last), {'regenerate': true, 'model_id': 'm1'});
    expect(state().messages.map((m) => m.content.trim()), ['Hi', 'Second answer']);
  });

  test('Stop keeps the partial reply', () async {
    final body = StreamController<List<int>>();
    backend.overrides['POST /api/chats/c1/completions'] =
        (_) => http.StreamedResponse(body.stream, 200, headers: {'content-type': 'text/event-stream'});
    final sending = controller().send('Hi', model);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    body.add(utf8.encode(reply('ignored').first));
    body.add(utf8.encode(FakeBackend.event({'type': 'delta', 'text': 'Partial'})));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(state().streaming, isTrue);
    controller().stop();
    await sending.timeout(const Duration(seconds: 2));
    expect(state().streaming, isFalse);
    expect(state().messages.last.content, 'Partial');
    await body.close();
  });

  test('an unavailable model is refused locally', () async {
    const off = AiModel(id: 'm2', slug: 'c', name: 'Claude Test', provider: 'Anthropic');
    expect(await controller().send('Hi', off), contains('isn’t available'));
    expect(backend.requests.where((r) => r.url.path.contains('/completions')), isEmpty);
  });

  test('a 401 while signed in signs out with a notice', () async {
    backend.overrides['GET /api/chats/c9/messages'] = (_) => FakeBackend.json({'error': 'Invalid or expired token'}, 401);
    await controller().open(Conversation(id: 'c9', createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
    expect(container.read(authControllerProvider).notice, contains('Sign in again'));
  });
}
