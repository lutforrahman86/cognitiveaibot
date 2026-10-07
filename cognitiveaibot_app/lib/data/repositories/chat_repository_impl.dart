import 'dart:async';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/completion_event.dart';
import '../../domain/entities/content_report.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required ChatRemoteDataSource remoteDataSource}) : _remote = remoteDataSource;

  final ChatRemoteDataSource _remote;

  @override
  Future<Result<List<AiModel>>> getModels() => Result.guard(_remote.getModels);

  @override
  Future<Result<List<Conversation>>> getConversations({String? search}) =>
      Result.guard(() => _remote.getConversations(search: search));

  @override
  Future<Result<List<ChatMessage>>> getMessages(String conversationId) =>
      Result.guard(() => _remote.getMessages(conversationId));

  @override
  Future<Result<Conversation>> createConversation({String? modelId}) =>
      Result.guard(() => _remote.createConversation(modelId: modelId));

  @override
  Future<Result<Conversation>> updateConversationTitle(String conversationId, String title) =>
      Result.guard(() => _remote.updateConversation(conversationId, title: title));

  @override
  Future<Result<void>> deleteConversation(String conversationId) =>
      Result.guard(() => _remote.deleteConversation(conversationId));

  @override
  Future<Result<void>> reportMessage({required String messageId, required ReportReason reason, String? details}) =>
      Result.guard(() => _remote.reportMessage(messageId: messageId, reason: reason, details: details));

  @override
  Stream<CompletionEvent> streamReply({
    required String conversationId,
    String? content,
    required String modelId,
    bool regenerate = false,
    Future<void>? cancel,
  }) async* {
    var started = false;
    try {
      await for (final event in _remote.streamCompletion(
        conversationId: conversationId,
        content: content,
        modelId: modelId,
        regenerate: regenerate,
        abortTrigger: cancel,
      )) {
        if (event is CompletionStarted) started = true;
        yield event;
      }
    } catch (e) {
      final failure = Failure.from(e);
      yield CompletionFailed(
        message: failure.message ?? 'Could not get a reply. Try again.',
        code: failure.code,
        refused: !started,
      );
    }
  }
}
