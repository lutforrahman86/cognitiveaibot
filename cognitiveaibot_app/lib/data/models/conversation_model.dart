import '../../domain/entities/conversation.dart';

/// Conversation model - data layer
class ConversationModel extends Conversation {
  const ConversationModel({
    required super.id,
    required super.serviceId,
    required super.modelId,
    required super.createdAt,
    super.title,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      serviceId: json['serviceId'] as String,
      modelId: json['modelId'] as String,
      title: json['title'] as String? ?? 'New Chat',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceId': serviceId,
      'modelId': modelId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
