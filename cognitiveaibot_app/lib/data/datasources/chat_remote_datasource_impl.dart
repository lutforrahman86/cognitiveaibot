import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../core/network/sse_parser.dart';
import '../../domain/entities/completion_event.dart';
import '../../domain/entities/content_report.dart';
import '../models/ai_model_model.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/json_utils.dart';
import 'chat_remote_datasource.dart';

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  ChatRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<AiModelModel>> getModels() async {
    final json = readMap(await _api.get('/api/models', auth: false));
    return readList(json['models']).map(AiModelModel.fromJson).toList();
  }

  @override
  Future<List<ConversationModel>> getConversations({String? search}) async {
    final json = readMap(await _api.get('/api/chats', query: {
      'limit': '100',
      if (search != null && search.isNotEmpty) 'search': search,
    }));
    return readList(json['chats']).map(ConversationModel.fromJson).toList();
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    final json = readMap(await _api.get('/api/chats/${Uri.encodeComponent(conversationId)}/messages'));
    return readList(json['messages']).map(ChatMessageModel.fromJson).toList();
  }

  @override
  Future<ConversationModel> createConversation({String? modelId}) async {
    final json = readMap(await _api.post('/api/chats', body: {
      'title': 'New chat',
      'model_id': ?modelId,
    }));
    return ConversationModel.fromJson(readMap(json['chat']));
  }

  @override
  Future<ConversationModel> updateConversation(String conversationId, {required String title}) async {
    final json = readMap(
      await _api.patch('/api/chats/${Uri.encodeComponent(conversationId)}', body: {'title': title}),
    );
    return ConversationModel.fromJson(readMap(json['chat']));
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _api.delete('/api/chats/${Uri.encodeComponent(conversationId)}');
  }

  @override
  Future<void> reportMessage({required String messageId, required ReportReason reason, String? details}) async {
    final text = details?.trim();
    await _api.post('/api/reports', body: {
      'message_id': messageId,
      'reason': reason.name,
      if (text != null && text.isNotEmpty) 'details': text,
    });
  }

  @override
  Stream<CompletionEvent> streamCompletion({
    required String conversationId,
    String? content,
    required String modelId,
    bool regenerate = false,
    Future<void>? abortTrigger,
  }) async* {
    final http.StreamedResponse response;
    try {
      response = await _api.openStream(
        '/api/chats/${Uri.encodeComponent(conversationId)}/completions',
        body: regenerate ? {'regenerate': true, 'model_id': modelId} : {'content': content, 'model_id': modelId},
        abortTrigger: abortTrigger,
      );
    } on http.RequestAbortedException {
      return;
    }
    try {
      await for (final event in parseSseJson(response.stream)) {
        final parsed = completionEventFromJson(event);
        if (parsed != null) yield parsed;
      }
    } on http.RequestAbortedException {
      // Stopped by the user: the server keeps what was produced.
      return;
    } on http.ClientException {
      // The connection dropped mid-reply. Whatever arrived stays on screen.
      yield const CompletionFailed(message: 'The connection was lost before the reply finished.', code: 'NETWORK_ERROR');
    }
  }
}

/// Maps one server event to a [CompletionEvent]; unknown types are ignored.
CompletionEvent? completionEventFromJson(Map<String, dynamic> e) {
  final credits = readMap(e['credits']);
  ChatMessageModel? message() =>
      e['message'] is Map<String, dynamic> ? ChatMessageModel.fromJson(e['message'] as Map<String, dynamic>) : null;
  switch (e['type']) {
    case 'start':
      return CompletionStarted(
        userMessage: ChatMessageModel.fromJson(readMap(e['user_message'])),
        chatTitle: readString(readMap(e['chat'])['title']),
      );
    case 'delta':
      final text = readString(e['text']) ?? '';
      return text.isEmpty ? null : CompletionDelta(text);
    case 'done':
      return CompletionDone(
        message: message(),
        creditsCharged: readDouble(credits['charged']),
        balance: readDouble(credits['balance']),
      );
    case 'error':
      return CompletionFailed(
        message: readString(e['error']) ?? 'The reply stopped unexpectedly.',
        code: readString(e['code']),
        partial: message(),
        balance: readDouble(credits['balance']),
      );
    default:
      return null;
  }
}
