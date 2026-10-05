import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

/// Abstract local data source for chat (cache)
abstract interface class ChatLocalDataSource {
  Future<List<ChatMessageModel>> getMessages(String conversationId);
  Future<void> cacheMessages(String conversationId, List<ChatMessageModel> messages);
  Future<void> saveMessage(String conversationId, ChatMessageModel message);

  /// Conversation history - grouped by service
  Future<Map<String, List<ConversationModel>>> getConversationsGroupedByService();

  /// Get last message snippet for a conversation (first 50 chars)
  Future<String?> getLastMessageSnippet(String conversationId);
  Future<void> saveConversation(ConversationModel conversation);
  Future<void> updateConversationTitle(String conversationId, String title);
  Future<void> deleteConversation(String conversationId);
}
