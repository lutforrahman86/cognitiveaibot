import 'package:flutter/material.dart';

import '../../core/constants/subscription_plans.dart';
import '../../core/theme/cognitive_aibot_theme.dart';

/// Subscription plan selection screen — displays all 11 packages
class SubscriptionPlanScreen extends StatefulWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  State<SubscriptionPlanScreen> createState() => _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState extends State<SubscriptionPlanScreen> {
  bool _isYearly = false;
  int? _expandedIndex;

  double _priceForPlan(SubscriptionPlan plan) {
    if (plan.price == 0) return 0;
    if (_isYearly) {
      // 10% discount when billed yearly
      return plan.price * 0.9;
    }
    return plan.price;
  }

  String _periodLabel() => _isYearly ? '/month (billed yearly)' : '/month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeadline(),
                    const SizedBox(height: 20),
                    _buildDurationToggle(),
                    const SizedBox(height: 24),
                    _buildPlanList(),
                    const SizedBox(height: 32),
                    _buildFeatureHighlights(),
                    const SizedBox(height: 32),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: CognitiveAIBotTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: CognitiveAIBotTheme.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: CognitiveAIBotTheme.primaryBlue, size: 24),
          const SizedBox(width: 8),
          const Text(
            'CognitiveAI Bot',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: CognitiveAIBotTheme.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.help_outline,
            color: CognitiveAIBotTheme.textSecondary,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help & FAQ')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Power',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '11 plans — Free to Elite. Price, Tokens, Models & facilities included.',
          style: TextStyle(
            fontSize: 14,
            color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.95),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isYearly
                      ? Colors.transparent
                      : CognitiveAIBotTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Monthly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: CognitiveAIBotTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isYearly
                      ? CognitiveAIBotTheme.primaryBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Yearly',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _isYearly
                            ? CognitiveAIBotTheme.textPrimary
                            : CognitiveAIBotTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CognitiveAIBotTheme.primaryBlue
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Save 10%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: CognitiveAIBotTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All packages',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CognitiveAIBotTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          SubscriptionPlan.all.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanCard(
              plan: SubscriptionPlan.all[i],
              price: _priceForPlan(SubscriptionPlan.all[i]),
              periodLabel: _periodLabel(),
              isExpanded: _expandedIndex == i,
              onTap: () {
                setState(() {
                  _expandedIndex = _expandedIndex == i ? null : i;
                });
              },
              onSelect: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected: ${SubscriptionPlan.all[i].name}',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All facilities included at no extra cost',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _FeatureBlock(
          icon: Icons.history,
          title: 'Chat history',
          description:
              'Retention from 7 days (Free) to 5 years (Enterprise). No extra charge.',
        ),
        const SizedBox(height: 10),
        _FeatureBlock(
          icon: Icons.download,
          title: 'Export options',
          description:
              'CSV, JSON, PDF export included. Business & enterprise plans include bulk export.',
        ),
        const SizedBox(height: 10),
        _FeatureBlock(
          icon: Icons.smart_toy,
          title: 'AI models',
          description:
              '19+ models: OpenAI, Anthropic, Google, DeepSeek, Perplexity, xAI & Mistral.',
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            _FooterLink(label: 'RESTORE PURCHASE'),
            _FooterLink(label: 'TERMS OF SERVICE'),
            _FooterLink(label: 'PRIVACY POLICY'),
            _FooterLink(label: 'CONTACT US'),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Subscription automatically renews unless auto-renew is turned off '
          'at least 24-hours before the end of the current period.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PlatformIcon(icon: Icons.apple),
            const SizedBox(width: 12),
            _PlatformIcon(icon: Icons.android),
            const SizedBox(width: 12),
            _PlatformIcon(icon: Icons.credit_card),
          ],
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.periodLabel,
    required this.isExpanded,
    required this.onTap,
    required this.onSelect,
  });

  final SubscriptionPlan plan;
  final double price;
  final String periodLabel;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isFree = plan.price == 0;
    final hasBadge = plan.badge != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CognitiveAIBotTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasBadge
                ? CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TierChip(label: plan.tier),
                          if (hasBadge)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: CognitiveAIBotTheme.primaryBlue
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plan.badge!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: CognitiveAIBotTheme.primaryBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CognitiveAIBotTheme.textPrimary,
                        ),
                      ),
                      if (plan.valuePositioning != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          plan.valuePositioning!,
                          style: TextStyle(
                            fontSize: 12,
                            color: CognitiveAIBotTheme.textSecondary
                                .withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          plan.price == 0
                              ? '\$0'
                              : '\$${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: CognitiveAIBotTheme.textPrimary,
                          ),
                        ),
                        Text(
                          periodLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: CognitiveAIBotTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: CognitiveAIBotTheme.textSecondary,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.chat_bubble_outline,
                  label: _formatMessages(plan.messages),
                ),
                _InfoChip(
                  icon: Icons.memory,
                  label: plan.tokens,
                ),
                _InfoChip(
                  icon: Icons.smart_toy_outlined,
                  label: '${plan.modelsCount} models',
                ),
              ],
            ),
            if (isExpanded) ...[
              const Divider(height: 24, color: CognitiveAIBotTheme.textSecondary),
              _Section(
                title: 'History',
                items: [plan.historyRetention],
              ),
              if (plan.exportFacilities.isNotEmpty)
                _Section(
                  title: 'Export',
                  items: plan.exportFacilities,
                ),
              _Section(
                title: 'Models',
                items: [plan.modelsDescription],
              ),
              _Section(
                title: 'Other facilities',
                items: plan.otherFacilities,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: isFree
                        ? CognitiveAIBotTheme.cardBackgroundAlt
                        : CognitiveAIBotTheme.primaryBlue,
                    foregroundColor: CognitiveAIBotTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isFree ? 'Current Plan' : 'Select ${plan.name}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatMessages(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M msg';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K msg';
    return '$n msg';
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: CognitiveAIBotTheme.textSecondary,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: CognitiveAIBotTheme.primaryBlue),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CognitiveAIBotTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: CognitiveAIBotTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: CognitiveAIBotTheme.textPrimary
                            .withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBlock extends StatelessWidget {
  const _FeatureBlock({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CognitiveAIBotTheme.primaryBlue, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: CognitiveAIBotTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: CognitiveAIBotTheme.textSecondary
                        .withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(label)),
        );
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _PlatformIcon extends StatelessWidget {
  const _PlatformIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: CognitiveAIBotTheme.textSecondary, size: 22),
    );
  }
}
