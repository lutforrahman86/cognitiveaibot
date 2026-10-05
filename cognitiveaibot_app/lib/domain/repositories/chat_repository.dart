import '../../core/usecases/usecase.dart';
import '../entities/ai_model.dart';
import '../entities/chat_message.dart';
import '../entities/completion_event.dart';
import '../entities/content_report.dart';
import '../entities/conversation.dart';

/// Chats, messages, the model catalog and streamed replies. Everything lives
/// on the server, so history survives a restart and follows the account.
abstract interface class ChatRepository {
  Future<Result<List<AiModel>>> getModels();

  /// Newest first. [search] filters by title and content on the server.
  Future<Result<List<Conversation>>> getConversations({String? search});
  Future<Result<List<ChatMessage>>> getMessages(String conversationId);
  Future<Result<Conversation>> createConversation({String? modelId});
  Future<Result<Conversation>> updateConversationTitle(String conversationId, String title);
  Future<Result<void>> deleteConversation(String conversationId);

  /// Sends [content] and streams the reply. Completing [cancel] stops the
  /// reply: the server keeps (and charges for) only what was produced.
  /// Never throws: failures arrive as a [CompletionFailed] event.
  ///
  /// With [regenerate] (no [content]) the server answers the chat's last
  /// user message again and replaces the replies after it.
  Stream<CompletionEvent> streamReply({
    required String conversationId,
    String? content,
    required String modelId,
    bool regenerate = false,
    Future<void>? cancel,
  });

  /// Flags a saved assistant reply for review by an admin.
  Future<Result<void>> reportMessage({required String messageId, required ReportReason reason, String? details});
}
