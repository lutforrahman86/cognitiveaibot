/// Demo chat conversation from JSON
class ChatDemo {
  const ChatDemo({
    required this.title,
    required this.model,
    required this.serviceId,
    required this.modelId,
    required this.statusText,
    required this.messages,
  });

  final String title;
  final String model;
  final String serviceId;
  final String modelId;
  final String statusText;
  final List<ChatDemoMessage> messages;

  factory ChatDemo.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List<dynamic>? ?? [];
    return ChatDemo(
      title: json['title'] as String? ?? 'New Chat',
      model: json['model'] as String? ?? 'GPT-4',
      serviceId: json['serviceId'] as String? ?? 'openai',
      modelId: json['modelId'] as String? ?? 'gpt-4o',
      statusText: json['statusText'] as String? ?? 'OPENAI GPT-4 ACTIVE',
      messages: messagesList
          .map((e) => ChatDemoMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatDemoMessage {
  const ChatDemoMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestampDisplay,
  });

  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final String timestampDisplay;

  factory ChatDemoMessage.fromJson(Map<String, dynamic> json) {
    return ChatDemoMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      timestampDisplay: json['timestamp'] as String? ?? '',
    );
  }
}
