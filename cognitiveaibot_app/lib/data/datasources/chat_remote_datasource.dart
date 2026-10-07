import '../../domain/entities/completion_event.dart';
import '../../domain/entities/content_report.dart';
import '../models/ai_model_model.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

/// The backend's chat API. Methods throw the exceptions in
/// `core/error/exceptions.dart`; [streamCompletion] emits them as stream errors.
abstract interface class ChatRemoteDataSource {
  Future<List<AiModelModel>> getModels();
  Future<List<ConversationModel>> getConversations({String? search});
  Future<List<ChatMessageModel>> getMessages(String conversationId);
  Future<ConversationModel> createConversation({String? modelId});
  Future<ConversationModel> updateConversation(String conversationId, {required String title});
  Future<void> deleteConversation(String conversationId);

  /// `POST /api/chats/:id/completions`, parsed into events. Completing
  /// [abortTrigger] closes the connection, which stops the reply. With
  /// [regenerate] (and no [content]) the server answers the chat's last user
  /// message again, replacing the replies after it.
  Stream<CompletionEvent> streamCompletion({
    required String conversationId,
    String? content,
    required String modelId,
    bool regenerate = false,
    Future<void>? abortTrigger,
  });

  /// `POST /api/reports`: flags a saved reply for review.
  Future<void> reportMessage({required String messageId, required ReportReason reason, String? details});
}
