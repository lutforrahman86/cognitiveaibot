import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required ChatRemoteDataSource remoteDataSource,
    required ChatLocalDataSource localDataSource,
  })  : _remote = remoteDataSource,
        _local = localDataSource;

  final ChatRemoteDataSource _remote;
  final ChatLocalDataSource _local;

  @override
  Future<Result<List<ChatMessage>>> getMessages(String conversationId) async {
    try {
      try {
        final remote = await _remote.getMessages(conversationId);
        await _local.cacheMessages(conversationId, remote);
        return Success(remote);
      } on ServerException catch (_) {
        final local = await _local.getMessages(conversationId);
        return Success(local);
      }
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message));
    }
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String content,
    String? serviceId,
    String? modelId,
  }) async {
    try {
      final userMessage = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        modelId: modelId,
      );
      await _local.saveMessage(conversationId, userMessage);

      final response = await _remote.sendMessage(
        conversationId: conversationId,
        content: content,
        modelId: modelId,
      );
      await _local.saveMessage(conversationId, response);

      return Success(response);
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    }
  }

  @override
  Future<Result<Map<String, List<Conversation>>>> getConversationsGroupedByService() async {
    try {
      final grouped = await _local.getConversationsGroupedByService();
      return Success(grouped);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    }
  }

  @override
  Future<Result<Conversation>> createConversation({
    required String serviceId,
    required String modelId,
  }) async {
    try {
      final id = '${serviceId}_${DateTime.now().millisecondsSinceEpoch}';
      final conversation = ConversationModel(
        id: id,
        serviceId: serviceId,
        modelId: modelId,
        title: 'New Chat',
        createdAt: DateTime.now(),
      );
      await _local.saveConversation(conversation);
      return Success(conversation);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    }
  }

  @override
  Future<Result<void>> updateConversationTitle(
    String conversationId,
    String title,
  ) async {
    try {
      await _local.updateConversationTitle(conversationId, title);
      return const Success(null);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    }
  }

  @override
  Future<Result<void>> deleteConversation(String conversationId) async {
    try {
      await _local.deleteConversation(conversationId);
      return const Success(null);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    }
  }

  @override
  Future<Result<String?>> getLastMessageSnippet(String conversationId) async {
    try {
      final snippet = await _local.getLastMessageSnippet(conversationId);
      return Success(snippet);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    }
  }
}
