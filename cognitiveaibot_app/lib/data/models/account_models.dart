import '../../domain/entities/account.dart';
import 'json_utils.dart';

CreditBalance creditBalanceFromJson(Map<String, dynamic> json) {
  final expiring = readMap(json['expiring']);
  return CreditBalance(
    balance: readDouble(json['balance']) ?? 0,
    held: readDouble(json['held']) ?? 0,
    available: readDouble(json['available']) ?? readDouble(json['balance']) ?? 0,
    expiringCredits: readDouble(expiring['credits']),
    expiringAt: readDate(expiring['at']),
  );
}

Plan planFromJson(Map<String, dynamic> json) {
  final productId = readString(json['revenuecat_product_id'])?.trim();
  return Plan(
    id: readString(json['id']) ?? '',
    slug: readString(json['slug']) ?? '',
    name: readString(json['name']) ?? '',
    description: readString(json['description']),
    kind: readString(json['kind']) ?? 'topup',
    interval: readString(json['interval']),
    priceCents: readInt(json['price_cents']) ?? 0,
    currency: readString(json['currency']) ?? 'usd',
    credits: readInt(json['credits']) ?? 0,
    includesApi: readBool(json['includes_api']),
    revenueCatProductId: productId == null || productId.isEmpty ? null : productId,
    modelTier: readInt(json['model_tier']) ?? 0,
  );
}

BillingInfo billingFromJson(Map<String, dynamic> json) {
  final sub = json['subscription'] is Map<String, dynamic> ? json['subscription'] as Map<String, dynamic> : null;
  return BillingInfo(
    credits: creditBalanceFromJson(readMap(json['credits'])),
    plan: json['plan'] is Map<String, dynamic> ? planFromJson(json['plan'] as Map<String, dynamic>) : null,
    subscriptionStatus: readString(sub?['status']),
    subscriptionSource: readString(sub?['source']),
    currentPeriodEnd: readDate(sub?['current_period_end']),
    cancelAtPeriodEnd: readBool(sub?['cancel_at_period_end']),
    paymentFailed: readBool(sub?['payment_failed']),
    paymentsEnabled: readBool(json['payments_enabled']),
  );
}

int _tokens(Map<String, dynamic> m) => (readInt(m['input_tokens']) ?? 0) + (readInt(m['output_tokens']) ?? 0);

UsageDashboard usageDashboardFromJson(Map<String, dynamic> json) {
  final totals = readMap(json['totals']);
  final daily = readList(json['by_day'])
      .map((d) => DailyUsage(
            date: DateTime.tryParse(readString(d['day']) ?? '') ?? DateTime.now(),
            requests: readInt(d['requests']) ?? 0,
            tokens: _tokens(d),
            credits: readDouble(d['credits']) ?? 0,
          ))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return UsageDashboard(
    days: readInt(json['days']) ?? 30,
    requests: readInt(totals['requests']) ?? 0,
    apiRequests: readInt(totals['api_requests']) ?? 0,
    inputTokens: readInt(totals['input_tokens']) ?? 0,
    outputTokens: readInt(totals['output_tokens']) ?? 0,
    credits: readDouble(totals['credits']) ?? 0,
    daily: daily,
    models: readList(json['by_model'])
        .map((m) => ModelUsage(
              name: readString(m['name']) ?? readString(m['model']) ?? 'Deleted model',
              provider: readString(m['provider']),
              requests: readInt(m['requests']) ?? 0,
              tokens: _tokens(m),
              credits: readDouble(m['credits']) ?? 0,
            ))
        .toList(),
  );
}

UserSettings settingsFromJson(Map<String, dynamic> json) {
  const d = UserSettings();
  final fontSize = readString(json['font_size']);
  return UserSettings(
    theme: readString(json['theme']) ?? d.theme,
    fontSize: UserSettings.fontSizes.contains(fontSize) ? fontSize! : d.fontSize,
    enterToSend: readBool(json['enter_to_send'], fallback: d.enterToSend),
    showTimestamps: readBool(json['show_timestamps'], fallback: d.showTimestamps),
    readAloud: readBool(json['read_aloud'], fallback: d.readAloud),
    aiVoiceModel: readString(json['ai_voice_model']),
    systemPrompt: readString(json['system_prompt']),
    temperature: readDouble(json['temperature']),
    tokenThreshold80: readBool(json['token_threshold_80'], fallback: d.tokenThreshold80),
    tokenThreshold90: readBool(json['token_threshold_90'], fallback: d.tokenThreshold90),
    tokenThreshold100: readBool(json['token_threshold_100'], fallback: d.tokenThreshold100),
  );
}

Map<String, dynamic> settingsToJson(UserSettings s) => {
      'theme': s.theme,
      'font_size': s.fontSize,
      'enter_to_send': s.enterToSend,
      'show_timestamps': s.showTimestamps,
      'read_aloud': s.readAloud,
      'ai_voice_model': s.aiVoiceModel,
      'system_prompt': (s.systemPrompt?.trim().isEmpty ?? true) ? null : s.systemPrompt!.trim(),
      'temperature': s.temperature == null ? null : double.parse(s.temperature!.toStringAsFixed(2)),
      'token_threshold_80': s.tokenThreshold80,
      'token_threshold_90': s.tokenThreshold90,
      'token_threshold_100': s.tokenThreshold100,
    };

/// Only the fields that changed: the server leaves the others alone.
Map<String, dynamic> settingsPatch(UserSettings previous, UserSettings next) {
  final before = settingsToJson(previous);
  final after = settingsToJson(next);
  return {
    for (final e in after.entries)
      if (before[e.key] != e.value) e.key: e.value,
  };
}
