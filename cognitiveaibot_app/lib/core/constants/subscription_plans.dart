/// Subscription plan data for all 11 packages.
/// Free, Starter $9.99, Basic $19.99, Pro $29.99 → Elite $999.99.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.price,
    required this.messages,
    required this.tokens,
    required this.modelsCount,
    required this.modelsDescription,
    required this.historyRetention,
    required this.exportFacilities,
    required this.otherFacilities,
    this.valuePositioning,
    this.badge,
  });

  final String tier;
  final String name;
  final double price;
  final int messages;
  final String tokens;
  final int modelsCount;
  final String modelsDescription;
  final String historyRetention;
  final List<String> exportFacilities;
  final List<String> otherFacilities;
  final String? valuePositioning;
  final String? badge;

  String get formattedPrice =>
      price == 0 ? '\$0' : '\$${price.toStringAsFixed(2)}';

  static const List<SubscriptionPlan> all = [
    SubscriptionPlan(
      tier: 'Free',
      name: 'Free',
      price: 0,
      messages: 20,
      tokens: '10K',
      modelsCount: 3,
      modelsDescription:
          'GPT-3.5 Turbo, Gemini Flash, Perplexity (5 searches/month)',
      historyRetention: '7-day chat history',
      exportFacilities: [],
      otherFacilities: [
        'Web & mobile access',
        'Community support',
        'Standard response speed',
        'Basic usage dashboard',
      ],
      valuePositioning: 'Try before you buy',
    ),
    SubscriptionPlan(
      tier: 'Entry',
      name: 'Starter',
      price: 9.99,
      messages: 1366,
      tokens: '1M',
      modelsCount: 8,
      modelsDescription:
          'GPT-3.5 Turbo, GPT-4o Mini, Gemini Flash, Claude 3 Haiku, Perplexity (20/mo), DeepSeek, Mistral Small',
      historyRetention: '14-day chat history',
      exportFacilities: ['CSV export'],
      otherFacilities: [
        'Web & mobile access',
        'Email support',
        'Usage analytics',
        '1 concurrent conversation',
      ],
      valuePositioning: 'Entry / small users',
    ),
    SubscriptionPlan(
      tier: 'Individual',
      name: 'Basic',
      price: 19.99,
      messages: 4100,
      tokens: '3M',
      modelsCount: 12,
      modelsDescription:
          'GPT-4o Mini, GPT-4 Turbo, Gemini 1.5 Flash/Pro, Claude 3 Haiku/Sonnet, Perplexity (50/mo), DeepSeek, Grok-2, Mistral Small/Large',
      historyRetention: '30-day chat history',
      exportFacilities: ['CSV', 'JSON'],
      otherFacilities: [
        'Priority processing',
        'Usage analytics & spending breakdown',
        'Email support',
        '3 concurrent conversations',
        'Custom system prompts',
      ],
      valuePositioning: 'Light regular usage',
    ),
    SubscriptionPlan(
      tier: 'Individual',
      name: 'Pro',
      price: 29.99,
      messages: 9000,
      tokens: '4.5M',
      modelsCount: 19,
      modelsDescription:
          'All models: OpenAI, Anthropic, Google, DeepSeek, Perplexity, xAI, Mistral',
      historyRetention: '14-day chat history',
      exportFacilities: ['CSV export'],
      otherFacilities: [
        'Web & mobile access',
        'Email support',
        'Usage analytics',
        '3 concurrent conversations',
      ],
      valuePositioning: 'Power users',
    ),
    SubscriptionPlan(
      tier: 'Individual',
      name: 'Growth',
      price: 49.99,
      messages: 15000,
      tokens: '7.5M',
      modelsCount: 19,
      modelsDescription:
          'All models: OpenAI, Anthropic, Google, DeepSeek, Perplexity, xAI, Mistral',
      historyRetention: '30-day chat history',
      exportFacilities: ['CSV', 'JSON'],
      otherFacilities: [
        'Priority processing',
        'Usage analytics & spending breakdown',
        'Email support',
        '5 concurrent conversations',
        'Custom system prompts',
      ],
      valuePositioning: 'Growing users',
      badge: 'POPULAR',
    ),
    SubscriptionPlan(
      tier: 'Individual',
      name: 'Growth',
      price: 79.99,
      messages: 24000,
      tokens: '12M',
      modelsCount: 19,
      modelsDescription:
          'All models: OpenAI, Anthropic, Google, DeepSeek, Perplexity, xAI, Mistral',
      historyRetention: '90-day chat history',
      exportFacilities: ['CSV', 'JSON', 'PDF'],
      otherFacilities: [
        'Advanced usage analytics',
        'Token threshold alerts',
        '10 concurrent conversations',
        'Voice input/output (basic)',
        'API access (5,000 calls/month)',
      ],
      valuePositioning: 'Growing users',
    ),
    SubscriptionPlan(
      tier: 'Pro',
      name: 'Pro Plus',
      price: 99.99,
      messages: 30000,
      tokens: '15M',
      modelsCount: 19,
      modelsDescription:
          'All models: OpenAI, Anthropic, Google, DeepSeek, Perplexity, xAI, Mistral',
      historyRetention: '180-day chat history',
      exportFacilities: ['Unlimited CSV', 'JSON', 'PDF'],
      otherFacilities: [
        'Highest priority processing',
        'Detailed cost breakdown by model',
        '15 concurrent conversations',
        'Full voice input/output',
        'API access (15,000 calls/month)',
        'Custom model preferences',
      ],
      valuePositioning: 'Power users',
    ),
    SubscriptionPlan(
      tier: 'Business',
      name: 'Business',
      price: 199.99,
      messages: 60000,
      tokens: '30M',
      modelsCount: 19,
      modelsDescription:
          'All models + reserved capacity: OpenAI, Anthropic, Google, DeepSeek, Perplexity, xAI, Mistral',
      historyRetention: '1-year chat history',
      exportFacilities: ['Team-wide export', 'API export', 'Data export on demand'],
      otherFacilities: [
        '10 team seats included',
        'Shared workspace & conversations',
        'Admin dashboard',
        'Full API access (40,000 calls/month)',
        'SSO (SAML 2.0)',
        'Audit logs',
      ],
      valuePositioning: 'Teams / heavy usage',
    ),
    SubscriptionPlan(
      tier: 'Business',
      name: 'Scale',
      price: 299.99,
      messages: 100000,
      tokens: '50M',
      modelsCount: 19,
      modelsDescription:
          'All models + reserved capacity + beta access',
      historyRetention: '2-year chat history',
      exportFacilities: ['Full data export', 'Compliance export'],
      otherFacilities: [
        '25 team seats included',
        'Everything in Business',
        'Unlimited API access (fair use)',
        'Multiple SSO configurations',
        'Dedicated success manager',
        '99.95% uptime SLA',
        'Custom SLAs',
      ],
      valuePositioning: 'Fast-growing SaaS',
    ),
    SubscriptionPlan(
      tier: 'Enterprise',
      name: 'Enterprise',
      price: 499.99,
      messages: 160000,
      tokens: '80M',
      modelsCount: 19,
      modelsDescription:
          'All models + dedicated instances + private beta',
      historyRetention: '5-year data retention',
      exportFacilities: ['Full enterprise export', 'Compliance export'],
      otherFacilities: [
        '50 team seats included',
        'Everything in Scale',
        'Unlimited API',
        'Custom data residency',
        'SOC 2 compliance support',
        '99.99% uptime SLA',
        '24/7 priority support',
        'Custom integrations development',
      ],
      valuePositioning: 'Large workloads',
    ),
    SubscriptionPlan(
      tier: 'Enterprise',
      name: 'Elite',
      price: 999.99,
      messages: 320000,
      tokens: '160M',
      modelsCount: 19,
      modelsDescription:
          'All models + dedicated capacity + first access to new models',
      historyRetention: '5-year data retention',
      exportFacilities: ['Full enterprise export', 'Custom export'],
      otherFacilities: [
        '150 team seats included',
        'Everything in Enterprise',
        'Truly unlimited API',
        'Custom contract & pricing',
        'Dedicated support team',
        'Multi-region deployment',
        'Custom security audit',
        'Annual strategic planning',
      ],
      valuePositioning: 'High-scale / agencies',
    ),
  ];
}
