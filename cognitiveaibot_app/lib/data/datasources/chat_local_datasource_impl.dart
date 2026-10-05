import '../../core/error/exceptions.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import 'chat_local_datasource.dart';

/// In-memory implementation - replace with shared_preferences or Hive for persistence
class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  ChatLocalDataSourceImpl();

  final Map<String, List<ChatMessageModel>> _cache = {};
  final Map<String, ConversationModel> _conversations = {};

  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    try {
      return List.from(_cache[conversationId] ?? []);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> cacheMessages(
    String conversationId,
    List<ChatMessageModel> messages,
  ) async {
    try {
      _cache[conversationId] = messages;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> saveMessage(
    String conversationId,
    ChatMessageModel message,
  ) async {
    try {
      final messages = _cache[conversationId] ?? [];
      messages.add(message);
      _cache[conversationId] = messages;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<Map<String, List<ConversationModel>>> getConversationsGroupedByService() async {
    try {
      final list = _conversations.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final grouped = <String, List<ConversationModel>>{};
      for (final c in list) {
        grouped.putIfAbsent(c.serviceId, () => []).add(c);
      }
      return grouped;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> saveConversation(ConversationModel conversation) async {
    try {
      _conversations[conversation.id] = conversation;
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<void> updateConversationTitle(String conversationId, String title) async {
    try {
      final existing = _conversations[conversationId];
      if (existing != null) {
        _conversations[conversationId] = ConversationModel(
          id: existing.id,
          serviceId: existing.serviceId,
          modelId: existing.modelId,
          title: title,
          createdAt: existing.createdAt,
        );
      }
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<String?> getLastMessageSnippet(String conversationId) async {
    try {
      final messages = _cache[conversationId] ?? [];
      if (messages.isEmpty) return null;
      final last = messages.last;
      return last.content.length > 50
          ? '${last.content.substring(0, 50)}...'
          : last.content;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      _conversations.remove(conversationId);
      _cache.remove(conversationId);
    } catch (e) {
      throw CacheException(e.toString());
    }
  }
}
