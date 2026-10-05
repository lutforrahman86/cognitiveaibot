import '../../domain/entities/chat_message.dart';
import 'json_utils.dart';

/// Chat message model - data layer (a row of `messages` from the backend).
class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.content,
    required super.role,
    required super.timestamp,
    super.modelId,
    super.modelName,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final role = switch (readString(json['role'])) {
      'assistant' => MessageRole.assistant,
      'system' => MessageRole.system,
      _ => MessageRole.user,
    };
    return ChatMessageModel(
      id: readString(json['id']) ?? '',
      content: readString(json['content']) ?? '',
      role: role,
      timestamp: readDate(json['created_at']) ?? DateTime.now(),
      modelId: readString(json['model_id']),
      modelName: readString(json['model_name']),
    );
  }
}
