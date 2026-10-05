/// Chat message entity - domain layer
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.modelId,
  });

  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final String? modelId;
}

enum MessageRole {
  user,
  assistant,
  system,
}
