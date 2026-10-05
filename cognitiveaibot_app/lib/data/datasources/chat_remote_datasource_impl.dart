import '../../domain/entities/chat_message.dart';
import '../models/chat_message_model.dart';
import 'chat_remote_datasource.dart';

/// Placeholder implementation - replace with actual LLM API integration
/// (OpenAI, Anthropic, Gemini, DeepSeek, Grok, Perplexity, etc.)
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    return [];
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? modelId,
  }) async {
    // Placeholder response until LLM APIs are integrated
    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'This is a placeholder response. Configure OpenAI, Anthropic, '
          'Gemini, or other LLM APIs to get real AI responses.',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      modelId: modelId,
    );
  }
}
