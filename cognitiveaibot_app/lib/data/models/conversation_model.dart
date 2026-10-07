import '../../domain/entities/conversation.dart';
import 'json_utils.dart';

/// Conversation model - data layer (a row of `chats` from the backend).
class ConversationModel extends Conversation {
  const ConversationModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.title,
    super.modelId,
    super.modelName,
    super.excerpt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final created = readDate(json['created_at']) ?? DateTime.now();
    final title = readString(json['title']);
    return ConversationModel(
      id: readString(json['id']) ?? '',
      title: title == null || title.trim().isEmpty ? 'New chat' : title,
      modelId: readString(json['model_id']),
      modelName: readString(json['model_name']),
      excerpt: readString(json['excerpt']),
      createdAt: created,
      updatedAt: readDate(json['updated_at']) ?? created,
    );
  }
}
