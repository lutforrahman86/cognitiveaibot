/// Chat message entity - domain layer
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.modelId,
    this.modelName,
  });

  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  /// The backend's id of the model that wrote an assistant message.
  final String? modelId;
  final String? modelName;

  ChatMessage copyWith({String? id, String? content, DateTime? timestamp, String? modelId, String? modelName}) =>
      ChatMessage(
        id: id ?? this.id,
        content: content ?? this.content,
        role: role,
        timestamp: timestamp ?? this.timestamp,
        modelId: modelId ?? this.modelId,
        modelName: modelName ?? this.modelName,
      );
}

enum MessageRole {
  user,
  assistant,
  system,
}
