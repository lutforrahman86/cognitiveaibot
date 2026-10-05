import '../../domain/entities/chat_message.dart';

/// Chat message model - data layer
/// Extends/adapts the domain entity
class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.content,
    required super.role,
    required super.timestamp,
    super.modelId,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      content: json['content'] as String,
      role: MessageRole.values.byName(
        (json['role'] as String?)?.toLowerCase() ?? 'user',
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      modelId: json['modelId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      'modelId': modelId,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    String? modelId,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      modelId: modelId ?? this.modelId,
    );
  }
}
