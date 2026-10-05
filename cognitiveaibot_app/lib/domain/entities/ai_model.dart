/// A model from the server's catalog (`GET /api/models`).
class AiModel {
  const AiModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.provider,
    this.category,
    this.available = false,
    this.contextWindow,
    this.tier = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String provider;
  final String? category;

  /// Whether the server can answer with this model right now. Unavailable
  /// models are listed but can't be chosen.
  final bool available;
  final int? contextWindow;

  /// Plan tier needed to chat with it (0: everyone). The server refuses a
  /// reply above the account's tier with `MODEL_REQUIRES_PLAN`.
  final int tier;
}
