/// A chat stored on the server.
class Conversation {
  const Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title = 'New chat',
    this.modelId,
    this.modelName,
    this.excerpt,
  });

  final String id;
  final String title;

  /// The model the chat last used (backend id), if any.
  final String? modelId;
  final String? modelName;

  /// The start of the latest message, for list previews.
  final String? excerpt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation copyWith({String? title}) => Conversation(
        id: id,
        title: title ?? this.title,
        modelId: modelId,
        modelName: modelName,
        excerpt: excerpt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
