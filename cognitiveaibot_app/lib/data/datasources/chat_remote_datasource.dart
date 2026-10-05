import '../models/chat_message_model.dart';

/// Abstract remote data source for chat
/// Will be implemented with actual LLM API calls (OpenAI, Claude, etc.)
abstract interface class ChatRemoteDataSource {
  Future<List<ChatMessageModel>> getMessages(String conversationId);
  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? modelId,
  });
}
