import 'dart:convert';

import 'package:cognitiveaibot/core/error/exceptions.dart';
import 'package:cognitiveaibot/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late SessionHolder session;
  late List<http.Request> sent;

  ApiClient client(Future<http.Response> Function(http.Request) handler) {
    sent = [];
    return ApiClient(
      baseUrl: 'http://api.test/',
      session: session,
      httpClient: MockClient((r) {
        sent.add(r);
        return handler(r);
      }),
    );
  }

  setUp(() => session = SessionHolder()..token = 'tok');

  test('sends the bearer token and JSON body, decodes JSON', () async {
    final api = client((r) async => http.Response(jsonEncode({'ok': true}), 200));
    final res = await api.post('/api/chats', body: {'title': 'x'});
    expect(res, {'ok': true});
    expect(sent.single.url.toString(), 'http://api.test/api/chats');
    expect(sent.single.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(sent.single.body), {'title': 'x'});
  });

  test('public calls send no token', () async {
    final api = client((r) async => http.Response('{}', 200));
    await api.get('/api/models', auth: false);
    expect(sent.single.headers.containsKey('Authorization'), isFalse);
  });

  test('turns an error body into a ServerException with the code', () async {
    final api = client((r) async => http.Response(jsonEncode({'error': 'Not enough credits', 'code': 'INSUFFICIENT_CREDITS'}), 402));
    await expectLater(
      api.get('/api/x'),
      throwsA(isA<ServerException>()
          .having((e) => e.message, 'message', 'Not enough credits')
          .having((e) => e.code, 'code', 'INSUFFICIENT_CREDITS')
          .having((e) => e.statusCode, 'status', 402)),
    );
  });

  test('401 on a signed-in call ends the session', () async {
    String? ended;
    session.onUnauthorized = (m) => ended = m;
    final api = client((r) async => http.Response(jsonEncode({'error': 'Invalid or expired token'}), 401));
    await expectLater(api.get('/api/chats'), throwsA(isA<UnauthorizedException>()));
    expect(ended, 'Invalid or expired token');
  });

  test('a suspended account (403 ACCOUNT_SUSPENDED) ends the session too', () async {
    String? ended;
    session.onUnauthorized = (m) => ended = m;
    final api = client((r) async =>
        http.Response(jsonEncode({'error': 'This account is suspended. Contact support.', 'code': 'ACCOUNT_SUSPENDED'}), 403));
    await expectLater(api.get('/api/chats'), throwsA(isA<UnauthorizedException>()));
    expect(ended, contains('suspended'));
  });

  test('a wrong password (401 on sign-in) is just an error, not a sign-out', () async {
    var ended = false;
    session.onUnauthorized = (_) => ended = true;
    final api = client((r) async => http.Response(jsonEncode({'error': 'Invalid email or password'}), 401));
    await expectLater(
      api.post('/api/auth/login', body: {}, auth: false),
      throwsA(isA<ServerException>().having((e) => e.message, 'message', 'Invalid email or password')),
    );
    expect(ended, isFalse);
  });

  test('connection failures become a NetworkException', () async {
    final api = client((r) async => throw http.ClientException('refused'));
    await expectLater(api.get('/api/chats'), throwsA(isA<NetworkException>()));
  });

  test('openStream refuses a JSON answer with the backend error', () async {
    final api = client((r) async => http.Response(jsonEncode({'error': 'Wait', 'code': 'REPLY_IN_PROGRESS'}), 429));
    await expectLater(
      api.openStream('/api/chats/1/completions', body: {}),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 'REPLY_IN_PROGRESS')),
    );
  });
}
