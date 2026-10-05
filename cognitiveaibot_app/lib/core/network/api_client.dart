import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/exceptions.dart';

/// Holds the signed-in session for [ApiClient]. The auth controller writes
/// it; the client only reads it, so neither depends on the other.
class SessionHolder {
  String? token;

  /// Called with the server's message when a signed-in request gets HTTP 401,
  /// or 403 `ACCOUNT_SUSPENDED`: the session can't be used any more.
  void Function(String message)? onUnauthorized;
}

/// JSON-over-HTTP client for the CognitiveAI Bot backend.
///
/// Every failure surfaces as a [ServerException] (with the backend's
/// `error` text and `code`), an [UnauthorizedException] or a
/// [NetworkException], so callers never see raw socket errors.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required SessionHolder session,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _session = session,
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final SessionHolder _session;
  final http.Client _http;
  final Duration timeout;

  static const _networkMessage =
      'Can’t reach the CognitiveAI Bot server. Check your connection and try again.';

  Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$_baseUrl$path');
    return query == null || query.isEmpty ? u : u.replace(queryParameters: query);
  }

  Map<String, String> _headers({required bool auth, bool json = true}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (auth && _session.token != null) 'Authorization': 'Bearer ${_session.token}',
      };

  Future<dynamic> get(String path, {Map<String, String>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = true}) => _send('DELETE', path, auth: auth);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    required bool auth,
  }) async {
    final request = http.Request(method, uri(path, query))
      ..headers.addAll(_headers(auth: auth, json: body != null));
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      throw const NetworkException(_networkMessage);
    } on http.ClientException {
      throw const NetworkException(_networkMessage);
    }
    return decodeResponse(response.statusCode, response.body, auth: auth);
  }

  /// Opens a streaming POST (Server-Sent Events). Completing [abortTrigger]
  /// closes the connection. A non-2xx or non-stream answer is turned into
  /// the matching exception, like any other request.
  Future<http.StreamedResponse> openStream(
    String path, {
    required Object body,
    Future<void>? abortTrigger,
  }) async {
    final request = http.AbortableRequest('POST', uri(path), abortTrigger: abortTrigger)
      ..headers.addAll(_headers(auth: true))
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(body);
    final http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException(_networkMessage);
    } on http.RequestAbortedException {
      rethrow;
    } on http.ClientException {
      throw const NetworkException(_networkMessage);
    }
    final type = response.headers['content-type'] ?? '';
    if (response.statusCode >= 200 && response.statusCode < 300 && type.startsWith('text/event-stream')) {
      return response;
    }
    final text = await response.stream.bytesToString();
    decodeResponse(response.statusCode, text, auth: true, fallback: 'Could not get a reply. Try again.');
    // A 2xx answer that isn't a stream is still not a reply.
    throw const ServerException('Could not get a reply. Try again.');
  }

  /// Decodes a JSON body, or throws the backend's error for a non-2xx status.
  dynamic decodeResponse(
    int status,
    String body, {
    required bool auth,
    String fallback = 'Something went wrong. Try again.',
  }) {
    dynamic json;
    if (body.isNotEmpty) {
      try {
        json = jsonDecode(body);
      } on FormatException {
        json = null;
      }
    }
    if (status >= 200 && status < 300) {
      if (body.isNotEmpty && json == null) throw ServerException(fallback, null, status);
      return json;
    }
    final message = json is Map && json['error'] is String ? json['error'] as String : fallback;
    final code = json is Map && json['code'] is String ? json['code'] as String : null;
    final sessionEnded = status == 401 || (status == 403 && code == 'ACCOUNT_SUSPENDED');
    if (sessionEnded && auth && _session.token != null) {
      _session.onUnauthorized?.call(message);
      throw UnauthorizedException(message);
    }
    throw ServerException(message, code, status);
  }
}
