import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// An in-memory stand-in for the CognitiveAI Bot API, answering the same
/// paths and JSON shapes as the backend. Every request is recorded.
class FakeBackend extends http.BaseClient {
  FakeBackend({this.token = 'valid-token'});

  final String token;
  final requests = <http.BaseRequest>[];
  final bodies = <String>[];

  /// Next answer for a path ("METHOD /path"), overriding the defaults.
  final overrides = <String, http.StreamedResponse Function(http.BaseRequest)>{};

  List<Map<String, dynamic>> chats = [];
  Map<String, List<Map<String, dynamic>>> messages = {};
  Map<String, dynamic> settings = {
    'theme': 'dark',
    'font_size': 'medium',
    'enter_to_send': true,
    'show_timestamps': true,
    'read_aloud': false,
    'ai_voice_model': null,
    'system_prompt': null,
    'temperature': null,
  };
  List<Map<String, dynamic>> plans = [
    {'id': 'p1', 'slug': 'starter', 'name': 'Starter', 'kind': 'subscription', 'interval': 'month', 'price_cents': 1000, 'currency': 'usd', 'credits': 900, 'includes_api': false, 'revenuecat_product_id': null},
    {'id': 'p2', 'slug': 'pro', 'name': 'Pro', 'kind': 'subscription', 'interval': 'month', 'price_cents': 2500, 'currency': 'usd', 'credits': 2250, 'includes_api': true, 'revenuecat_product_id': 'cab_pro_monthly'},
    {'id': 'p3', 'slug': 'topup', 'name': '450 credits', 'kind': 'topup', 'interval': null, 'price_cents': 500, 'currency': 'usd', 'credits': 450, 'includes_api': false},
  ];
  Map<String, dynamic> usage = {'days': 30, 'totals': {'requests': 0, 'api_requests': 0, 'input_tokens': 0, 'output_tokens': 0, 'credits': 0}, 'by_day': [], 'by_model': []};
  List<String> sse = [];

  static http.StreamedResponse json(Object body, [int status = 200]) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static http.StreamedResponse events(List<String> chunks) => http.StreamedResponse(
        Stream.fromIterable(chunks.map(utf8.encode)),
        200,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );

  static String event(Map<String, dynamic> e) => 'data: ${jsonEncode(e)}\n\n';

  Map<String, dynamic> get user => {'id': 'u1', 'email': 'tester@example.test', 'name': 'Tester', 'type': 'user'};

  /// Like a real client: completing an abortable request's trigger ends its
  /// response stream with [http.RequestAbortedException].
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _answer(request);
    final trigger = request is http.Abortable ? request.abortTrigger : null;
    if (trigger == null) return response;
    final out = StreamController<List<int>>();
    final sub = response.stream.listen(out.add, onError: out.addError, onDone: out.close);
    trigger.whenComplete(() {
      if (out.isClosed) return;
      sub.cancel();
      out.addError(http.RequestAbortedException(request.url));
      out.close();
    });
    return http.StreamedResponse(out.stream, response.statusCode, headers: response.headers);
  }

  Future<http.StreamedResponse> _answer(http.BaseRequest request) async {
    requests.add(request);
    final body = request is http.Request ? request.body : '';
    bodies.add(body);
    final path = request.url.path;
    final key = '${request.method} $path';
    final override = overrides[key];
    if (override != null) return override(request);

    if (path == '/api/models') {
      return json({'models': [
        {'id': 'm1', 'slug': 'gpt', 'name': 'GPT Test', 'provider': 'OpenAI', 'category': 'General', 'available': true, 'tier': 0},
        {'id': 'm2', 'slug': 'claude', 'name': 'Claude Test', 'provider': 'Anthropic', 'category': 'Reasoning', 'available': false, 'tier': 0},
      ]});
    }
    if (path == '/api/plans') return json({'plans': plans});
    if (path == '/api/auth/login') {
      final b = jsonDecode(body) as Map;
      return b['password'] == 'right-password'
          ? json({'token': token, 'user': user})
          : json({'error': 'Invalid email or password'}, 401);
    }
    if (path == '/api/auth/register') return json({'token': token, 'user': user}, 201);

    if (request.headers['Authorization'] != 'Bearer $token') {
      return json({'error': 'Invalid or expired token'}, 401);
    }
    if (path == '/api/auth/me') return json({'user': user});
    if (path == '/api/billing') {
      return json({'plan': null, 'subscription': null, 'payments_enabled': false, 'credits': {'balance': 12.5, 'held': 0, 'available': 12.5, 'expiring': null}});
    }
    if (path == '/api/usage/summary') return json(usage);
    if (path == '/api/settings') {
      if (request.method == 'PATCH') settings = {...settings, ...(jsonDecode(body) as Map<String, dynamic>)};
      return json({'settings': settings});
    }
    if (path == '/api/chats' && request.method == 'GET') {
      final q = request.url.queryParameters['search']?.toLowerCase();
      return json({'chats': q == null ? chats : chats.where((c) => (c['title'] as String).toLowerCase().contains(q)).toList()});
    }
    if (path == '/api/chats' && request.method == 'POST') {
      final chat = {'id': 'c${chats.length + 1}', 'title': 'New chat', 'created_at': '2026-10-05T10:00:00Z', 'updated_at': '2026-10-05T10:00:00Z'};
      chats.insert(0, chat);
      return json({'chat': chat}, 201);
    }
    final chatMatch = RegExp(r'^/api/chats/([^/]+)(/messages|/completions)?$').firstMatch(path);
    if (chatMatch != null) {
      final id = chatMatch.group(1)!;
      switch ((request.method, chatMatch.group(2))) {
        case ('GET', '/messages'):
          return json({'messages': messages[id] ?? []});
        case ('POST', '/completions'):
          return events(sse);
        case ('PATCH', null):
          final chat = chats.firstWhere((c) => c['id'] == id);
          chat['title'] = (jsonDecode(body) as Map)['title'];
          return json({'chat': chat});
        case ('DELETE', null):
          chats.removeWhere((c) => c['id'] == id);
          return http.StreamedResponse(const Stream.empty(), 204);
      }
    }
    return json({'error': 'Not found'}, 404);
  }
}
