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
    session.onUnauthorized = (m, _) => ended = m;
    final api = client((r) async => http.Response(jsonEncode({'error': 'Invalid or expired token'}), 401));
    await expectLater(api.get('/api/chats'), throwsA(isA<UnauthorizedException>()));
    expect(ended, 'Invalid or expired token');
  });

  test('a suspended account (403 ACCOUNT_SUSPENDED) ends the session too', () async {
    String? ended;
    session.onUnauthorized = (m, _) => ended = m;
    final api = client((r) async =>
        http.Response(jsonEncode({'error': 'This account is suspended. Contact support.', 'code': 'ACCOUNT_SUSPENDED'}), 403));
    await expectLater(api.get('/api/chats'), throwsA(isA<UnauthorizedException>()));
    expect(ended, contains('suspended'));
  });

  test('a wrong password (401 on sign-in) is just an error, not a sign-out', () async {
    var ended = false;
    session.onUnauthorized = (_, _) => ended = true;
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

  test('401 SESSION_EXPIRED (password changed elsewhere) ends the session with its code', () async {
    (String, String?)? ended;
    session.onUnauthorized = (m, c) => ended = (m, c);
    final api = client((r) async => http.Response(
        jsonEncode({'error': 'Your password was changed. Sign in again.', 'code': 'SESSION_EXPIRED'}), 401));
    await expectLater(
      api.get('/api/chats'),
      throwsA(isA<UnauthorizedException>().having((e) => e.code, 'code', 'SESSION_EXPIRED')),
    );
    expect(ended, ('Your password was changed. Sign in again.', 'SESSION_EXPIRED'));
  });

  test('a 401 for a request sent with a token that was replaced meanwhile doesn’t sign out', () async {
    var ended = false;
    session.onUnauthorized = (_, _) => ended = true;
    final api = client((r) async {
      // The password was changed while this request was in flight.
      session.token = 'new-token';
      return http.Response(jsonEncode({'error': 'Your password was changed.', 'code': 'SESSION_EXPIRED'}), 401);
    });
    await expectLater(api.get('/api/billing'), throwsA(isA<ServerException>().having((e) => e.statusCode, 'status', 401)));
    expect(ended, isFalse);
  });

  test('DELETE sends a JSON body', () async {
    final api = client((r) async => http.Response(jsonEncode({'deleted': true}), 200));
    await api.delete('/api/users/me', body: {'confirm': 'pw'});
    expect(sent.single.method, 'DELETE');
    expect(jsonDecode(sent.single.body), {'confirm': 'pw'});
    expect(sent.single.headers['Content-Type'], startsWith('application/json'));
  });
}
