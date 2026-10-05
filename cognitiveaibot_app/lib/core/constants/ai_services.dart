/// AI service definition with available models
class AIService {
  const AIService({
    required this.id,
    required this.name,
    required this.icon,
    required this.models,
  });

  final String id;
  final String name;
  final String icon; // Material icon name
  final List<AIModel> models;
}

/// AI model within a service
class AIModel {
  const AIModel({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
}

/// Available AI services and their models
/// Configure as needed when integrating actual APIs
class AIServicesConfig {
  AIServicesConfig._();

  static const List<AIService> services = [
    AIService(
      id: 'openai',
      name: 'OpenAI',
      icon: 'bolt',
      models: [
        AIModel(id: 'gpt-4o', name: 'GPT-4o', description: 'Most capable'),
        AIModel(id: 'gpt-4o-mini', name: 'GPT-4o Mini', description: 'Fast & affordable'),
        AIModel(id: 'gpt-4-turbo', name: 'GPT-4 Turbo', description: 'Extended context'),
      ],
    ),
    AIService(
      id: 'anthropic',
      name: 'Claude',
      icon: 'psychology',
      models: [
        AIModel(id: 'claude-sonnet-4', name: 'Claude Sonnet 4', description: 'Balanced'),
        AIModel(id: 'claude-3-5-sonnet', name: 'Claude 3.5 Sonnet', description: 'Latest'),
        AIModel(id: 'claude-3-haiku', name: 'Claude 3 Haiku', description: 'Fast'),
      ],
    ),
    AIService(
      id: 'gemini',
      name: 'Gemini',
      icon: 'auto_awesome',
      models: [
        AIModel(id: 'gemini-2.0-flash', name: 'Gemini 2.0 Flash', description: 'Fast'),
        AIModel(id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', description: 'Advanced'),
        AIModel(id: 'gemini-1.5-flash', name: 'Gemini 1.5 Flash', description: 'Lightweight'),
      ],
    ),
    AIService(
      id: 'deepseek',
      name: 'DeepSeek',
      icon: 'explore',
      models: [
        AIModel(id: 'deepseek-chat', name: 'DeepSeek Chat', description: 'General purpose'),
        AIModel(id: 'deepseek-coder', name: 'DeepSeek Coder', description: 'Code focused'),
      ],
    ),
    AIService(
      id: 'perplexity',
      name: 'Perplexity',
      icon: 'search',
      models: [
        AIModel(id: 'sonar', name: 'Sonar', description: 'Search-augmented'),
      ],
    ),
    AIService(
      id: 'grok',
      name: 'Grok',
      icon: 'smart_toy',
      models: [
        AIModel(id: 'grok-2', name: 'Grok 2', description: 'xAI model'),
      ],
    ),
    AIService(
      id: 'mistral',
      name: 'Mistral AI',
      icon: 'auto_fix_high',
      models: [
        AIModel(id: 'mistral-small', name: 'Mistral Small', description: 'Fast & affordable'),
        AIModel(id: 'mistral-large', name: 'Mistral Large', description: 'State-of-the-art'),
      ],
    ),
  ];

  static AIService? getService(String id) {
    try {
      return services.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static AIModel? getModel(String serviceId, String modelId) {
    final service = getService(serviceId);
    if (service == null) return null;
    try {
      return service.models.firstWhere((m) => m.id == modelId);
    } catch (_) {
      return null;
    }
  }
}
