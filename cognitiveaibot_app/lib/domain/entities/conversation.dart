/// Conversation entity - represents a chat session with a specific service/model
class Conversation {
  const Conversation({
    required this.id,
    required this.serviceId,
    required this.modelId,
    required this.createdAt,
    this.title = 'New Chat',
  });

  final String id;
  final String serviceId;
  final String modelId;
  final String title;
  final DateTime createdAt;
}
