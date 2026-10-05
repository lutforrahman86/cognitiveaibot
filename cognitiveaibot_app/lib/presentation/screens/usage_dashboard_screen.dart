import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/account.dart';
import '../providers/account_providers.dart';
import '../widgets/upgrade.dart';
import '../widgets/plan_status_text.dart';
import 'plans_screen.dart';

/// Credits and usage from the server: the balance (`GET /api/billing`) and
/// the last 30 days of usage in credits (`GET /api/usage/summary`).
class UsageDashboardScreen extends ConsumerWidget {
  const UsageDashboardScreen({super.key, this.useDesktopLayout = false});

  final bool useDesktopLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(usageDashboardProvider);
    final content = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(billingProvider);
        ref.invalidate(usageDashboardProvider);
        await ref.read(usageDashboardProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.all(useDesktopLayout ? 24 : 16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (useDesktopLayout) ...[
                    const Text(
                      'Usage',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const CurrentPlanCard(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => openUpgrade(context),
                      icon: const Icon(Icons.add_card, size: 18),
                      label: const Text('Get more credits'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  usage.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => _Card(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              errorText(e),
                              style: const TextStyle(
                                color: CognitiveAIBotTheme.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(usageDashboardProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (d) => d.isEmpty
                        ? const _NoUsageYet()
                        : _UsageDetails(dashboard: d, wide: useDesktopLayout),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: useDesktopLayout
          ? const Color(0xFF0D0D0D)
          : CognitiveAIBotTheme.background,
      appBar: useDesktopLayout
          ? null
          : AppBar(
              title: const Text(
                'Usage Dashboard',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              backgroundColor: CognitiveAIBotTheme.background,
            ),
      body: content,
    );
  }
}

class _NoUsageYet extends StatelessWidget {
  const _NoUsageYet();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Icon(
            Icons.bar_chart,
            size: 44,
            color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          const Text(
            'No usage yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CognitiveAIBotTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Credits, requests and tokens from the last 30 days appear here once you chat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CognitiveAIBotTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageDetails extends StatelessWidget {
  const _UsageDetails({required this.dashboard, required this.wide});

  final UsageDashboard dashboard;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final stats = [
      _Stat(
        label: 'CREDITS USED · ${d.days} DAYS',
        value: formatCredits(d.credits),
        key: const Key('usage-credits'),
      ),
      _Stat(
        label: 'REQUESTS',
        value: '${d.requests}',
        detail: d.apiRequests > 0 ? '${d.apiRequests} through the API' : null,
        key: const Key('usage-requests'),
      ),
      _Stat(
        label: 'TOKENS',
        value: formatTokens(d.tokens),
        detail:
            '${formatTokens(d.inputTokens)} in · ${formatTokens(d.outputTokens)} out',
        key: const Key('usage-tokens'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: stats[0]),
                const SizedBox(width: 12),
                Expanded(child: stats[1]),
                const SizedBox(width: 12),
                Expanded(child: stats[2]),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(child: stats[0]),
              const SizedBox(width: 12),
              Expanded(child: stats[1]),
            ],
          ),
          const SizedBox(height: 12),
          stats[2],
        ],
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title('Credits by day'),
              const SizedBox(height: 16),
              if (d.daily.isEmpty)
                Text(
                  'No usage in the last ${d.days} days.',
                  style: TextStyle(color: CognitiveAIBotTheme.textSecondary),
                )
              else
                _DailyBars(
                  days: d.daily.length > 14
                      ? d.daily.sublist(d.daily.length - 14)
                      : d.daily,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title('By model'),
              const SizedBox(height: 8),
              if (d.models.isEmpty)
                const Text(
                  'No usage by model yet.',
                  style: TextStyle(color: CognitiveAIBotTheme.textSecondary),
                ),
              for (final m in d.models) _ModelRow(model: m, total: d.credits),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.days});

  final List<DailyUsage> days;

  @override
  Widget build(BuildContext context) {
    final maxCredits = days.fold<double>(
      0.000001,
      (m, d) => d.credits > m ? d.credits : m,
    );
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Tooltip(
                message:
                    '${d.requests} requests · ${formatTokens(d.tokens)} tokens · ${formatCredits(d.credits)} credits',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        formatCredits(d.credits),
                        style: const TextStyle(
                          fontSize: 10,
                          color: CognitiveAIBotTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 100 * (d.credits / maxCredits).clamp(0.04, 1.0),
                        decoration: BoxDecoration(
                          color: CognitiveAIBotTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${weekdays[d.date.weekday - 1]} ${d.date.day}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: CognitiveAIBotTheme.textSecondary,
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
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model, required this.total});

  final ModelUsage model;
  final double total;

  @override
  Widget build(BuildContext context) {
    final share = total > 0 ? (model.credits / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.provider == null
                      ? model.name
                      : '${model.name} · ${model.provider}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CognitiveAIBotTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${model.requests} req · ${formatTokens(model.tokens)} tokens · ${formatCredits(model.credits)} cr',
                style: const TextStyle(
                  fontSize: 12,
                  color: CognitiveAIBotTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: CognitiveAIBotTheme.cardBackgroundAlt,
              color: CognitiveAIBotTheme.positiveGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: CognitiveAIBotTheme.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail!,
            style: const TextStyle(
              fontSize: 12,
              color: CognitiveAIBotTheme.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: CognitiveAIBotTheme.textPrimary,
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CognitiveAIBotTheme.cardBackground,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

String formatTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}
