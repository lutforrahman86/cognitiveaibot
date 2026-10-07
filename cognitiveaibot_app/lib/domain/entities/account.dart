/// Credits on the account (`credits` in `GET /api/billing`).
class CreditBalance {
  const CreditBalance({
    required this.balance,
    required this.held,
    required this.available,
    this.expiringCredits,
    this.expiringAt,
  });

  final double balance;

  /// Reserved for replies that are still streaming.
  final double held;

  /// What can be spent now: [balance] minus [held].
  final double available;

  /// Plan credits that lapse when the subscription period ends.
  final double? expiringCredits;
  final DateTime? expiringAt;
}

/// The account's plan and credits (`GET /api/billing`).
class BillingInfo {
  const BillingInfo({
    required this.credits,
    this.plan,
    this.subscriptionStatus,
    this.subscriptionSource,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.paymentFailed = false,
    this.paymentsEnabled = false,
  });

  final CreditBalance credits;
  final Plan? plan;
  final String? subscriptionStatus;
  final String? subscriptionSource;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final bool paymentFailed;
  final bool paymentsEnabled;
}

/// A plan from the server's catalog (`GET /api/plans`).
class Plan {
  const Plan({
    required this.id,
    required this.slug,
    required this.name,
    required this.kind,
    required this.priceCents,
    required this.currency,
    required this.credits,
    this.description,
    this.interval,
    this.includesApi = false,
    this.revenueCatProductId,
    this.modelTier = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;

  /// `subscription` or `topup`.
  final String kind;

  /// `month` or `year` for a subscription; null for a top-up.
  final String? interval;
  final int priceCents;
  final String currency;
  final int credits;
  final bool includesApi;

  /// The App Store / Play product sold through RevenueCat for this plan.
  /// Null: the plan can't be bought in the app.
  final String? revenueCatProductId;

  /// Highest model tier this plan unlocks.
  final int modelTier;

  bool get isSubscription => kind == 'subscription';

  String get formattedPrice {
    final amount = (priceCents / 100).toStringAsFixed(priceCents % 100 == 0 ? 0 : 2);
    final symbol = switch (currency.toLowerCase()) {
      'usd' => r'$',
      'eur' => '€',
      'gbp' => '£',
      _ => '${currency.toUpperCase()} ',
    };
    final per = switch (interval) { 'month' => ' / month', 'year' => ' / year', _ => '' };
    return '$symbol$amount$per';
  }
}

/// `GET /api/usage/summary`: what the account's calls cost in credits
/// (app and API together) over the last [days] days.
class UsageDashboard {
  const UsageDashboard({
    required this.days,
    required this.requests,
    required this.apiRequests,
    required this.inputTokens,
    required this.outputTokens,
    required this.credits,
    required this.daily,
    required this.models,
  });

  final int days;
  final int requests;
  final int apiRequests;
  final int inputTokens;
  final int outputTokens;
  final double credits;

  /// Days with usage, oldest first.
  final List<DailyUsage> daily;

  /// Most credits first.
  final List<ModelUsage> models;

  int get tokens => inputTokens + outputTokens;

  bool get isEmpty => requests == 0;
}

class DailyUsage {
  const DailyUsage({required this.date, required this.requests, required this.tokens, required this.credits});

  final DateTime date;
  final int requests;
  final int tokens;
  final double credits;
}

class ModelUsage {
  const ModelUsage({required this.name, this.provider, required this.requests, required this.tokens, required this.credits});

  final String name;
  final String? provider;
  final int requests;
  final int tokens;
  final double credits;
}

/// `GET/PATCH /api/settings`. The server applies the system prompt and
/// temperature to every chat reply.
class UserSettings {
  const UserSettings({
    this.theme = 'dark',
    this.fontSize = 'medium',
    this.enterToSend = true,
    this.showTimestamps = true,
    this.readAloud = false,
    this.aiVoiceModel,
    this.systemPrompt,
    this.temperature,
    this.tokenThreshold80 = true,
    this.tokenThreshold90 = true,
    this.tokenThreshold100 = true,
  });

  final String theme;

  /// `small`, `medium` or `large`.
  final String fontSize;
  final bool enterToSend;
  final bool showTimestamps;
  final bool readAloud;
  final String? aiVoiceModel;
  final String? systemPrompt;
  /// 0–2; null means the model's own default.
  final double? temperature;
  final bool tokenThreshold80;
  final bool tokenThreshold90;
  final bool tokenThreshold100;

  static const fontSizes = ['small', 'medium', 'large'];

  /// Message text size for [fontSize].
  double get messageFontSize => switch (fontSize) { 'small' => 13, 'large' => 17, _ => 15 };

  UserSettings copyWith({
    String? fontSize,
    bool? enterToSend,
    bool? showTimestamps,
    String? systemPrompt,
    double? temperature,
    bool clearTemperature = false,
    bool? tokenThreshold80,
    bool? tokenThreshold90,
    bool? tokenThreshold100,
  }) =>
      UserSettings(
        theme: theme,
        fontSize: fontSize ?? this.fontSize,
        enterToSend: enterToSend ?? this.enterToSend,
        showTimestamps: showTimestamps ?? this.showTimestamps,
        readAloud: readAloud,
        aiVoiceModel: aiVoiceModel,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        temperature: clearTemperature ? null : (temperature ?? this.temperature),
        tokenThreshold80: tokenThreshold80 ?? this.tokenThreshold80,
        tokenThreshold90: tokenThreshold90 ?? this.tokenThreshold90,
        tokenThreshold100: tokenThreshold100 ?? this.tokenThreshold100,
      );
}
