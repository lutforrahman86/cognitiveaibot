import '../../core/usecases/usecase.dart';
import '../entities/chat_message.dart';
import '../entities/conversation.dart';

/// Abstract chat repository - domain layer
/// Data layer will implement this
abstract interface class ChatRepository {
  Future<Result<List<ChatMessage>>> getMessages(String conversationId);
  Future<Result<ChatMessage>> sendMessage({
    required String conversationId,
    required String content,
    String? serviceId,
    String? modelId,
  });
  Future<Result<Map<String, List<Conversation>>>> getConversationsGroupedByService();
  Future<Result<Conversation>> createConversation({
    required String serviceId,
    required String modelId,
  });
  Future<Result<void>> updateConversationTitle(String conversationId, String title);
  Future<Result<void>> deleteConversation(String conversationId);
  Future<Result<String?>> getLastMessageSnippet(String conversationId);
}
