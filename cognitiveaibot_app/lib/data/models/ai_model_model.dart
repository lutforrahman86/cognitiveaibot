import '../../domain/entities/ai_model.dart';
import 'json_utils.dart';

class AiModelModel extends AiModel {
  const AiModelModel({
    required super.id,
    required super.slug,
    required super.name,
    required super.provider,
    super.category,
    super.available,
    super.contextWindow,
    super.tier,
  });

  factory AiModelModel.fromJson(Map<String, dynamic> json) => AiModelModel(
        id: readString(json['id']) ?? '',
        slug: readString(json['slug']) ?? '',
        name: readString(json['name']) ?? 'Unnamed model',
        provider: readString(json['provider']) ?? '',
        category: readString(json['category']),
        available: readBool(json['available']),
        contextWindow: readInt(json['context_window']),
        tier: readInt(json['tier']) ?? 0,
      );
}
