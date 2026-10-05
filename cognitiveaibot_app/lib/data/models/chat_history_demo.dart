/// Demo chat history entry from JSON
class ChatHistoryCategory {
  const ChatHistoryCategory({
    required this.category,
    required this.chats,
  });

  final String category;
  final List<ChatHistoryEntry> chats;

  factory ChatHistoryCategory.fromJson(Map<String, dynamic> json) {
    final chatsList = json['chats'] as List<dynamic>? ?? [];
    return ChatHistoryCategory(
      category: json['category'] as String? ?? '',
      chats: chatsList
          .map((e) => ChatHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatHistoryEntry {
  const ChatHistoryEntry({
    required this.id,
    required this.iconType,
    required this.iconBackgroundColor,
    required this.title,
    required this.timestamp,
    required this.descriptionExcerpt,
    required this.modelName,
    required this.modelTagStyle,
  });

  final String id;
  final String iconType;
  final String iconBackgroundColor;
  final String title;
  final String timestamp;
  final String descriptionExcerpt;
  final String modelName;
  final ModelTagStyle modelTagStyle;

  factory ChatHistoryEntry.fromJson(Map<String, dynamic> json) {
    final tagStyle = json['model_tag_style'] as Map<String, dynamic>?;
    return ChatHistoryEntry(
      id: json['id'] as String? ?? '',
      iconType: json['icon_type'] as String? ?? 'chat_bubble',
      iconBackgroundColor: json['icon_background_color'] as String? ?? '#2196F3',
      title: json['title'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      descriptionExcerpt: json['description_excerpt'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      modelTagStyle: tagStyle != null ? ModelTagStyle.fromJson(tagStyle) : const ModelTagStyle(),
    );
  }
}

class ModelTagStyle {
  const ModelTagStyle({
    this.backgroundColor = '#E0E0E0',
    this.textColor = '#424242',
  });

  final String backgroundColor;
  final String textColor;

  factory ModelTagStyle.fromJson(Map<String, dynamic> json) {
    return ModelTagStyle(
      backgroundColor: json['background_color'] as String? ?? '#E0E0E0',
      textColor: json['text_color'] as String? ?? '#424242',
    );
  }
}
