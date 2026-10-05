import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';

/// Desktop design colors — matches design image (#1F1F1F cards, #2196F3 blue, #4CAF50 green)
class _DesktopDesign {
  _DesktopDesign._();
  static const cardBg = Color(0xFF1F1F1F);
  static const accentBlue = Color(0xFF2196F3);
  static const accentGreen = Color(0xFF4CAF50);
  static const compareButtonBg = Color(0xFF2F2F2F);
  static const tooltipBg = Color(0xFF2F2F2F);
  static const barMuted = Color(0xFF4A4A4A);
}

/// Usage dashboard screen - shows cost, tokens, top models, daily spending
/// Uses dark theme matching the design.
/// When [useDesktopLayout] is true (Mac/Windows/Linux), renders without AppBar,
/// with an inline header matching the sidebar design.
class UsageDashboardScreen extends StatelessWidget {
  const UsageDashboardScreen({
    super.key,
    this.useDesktopLayout = false,
    this.usageAvailable = false,
  });

  final bool useDesktopLayout;

  /// The app doesn't track usage yet: that arrives with sign-in and the
  /// backend connection (roadmap Phase 4). Until then the screen says so
  /// instead of showing the design's sample figures as the user's own. The
  /// detailed cards below still hold those sample values and must be fed
  /// real data before this is ever set to true.
  final bool usageAvailable;

  IconData _iconForModel(String modelId) {
    if (modelId.startsWith('gpt')) return Icons.bolt;
    if (modelId.contains('gemini')) return Icons.auto_awesome;
    if (modelId.contains('perplexity')) return Icons.search;
    if (modelId.contains('grok')) return Icons.terminal;
    if (modelId.contains('claude')) return Icons.psychology;
    if (modelId.contains('mistral')) return Icons.auto_fix_high;
    return Icons.memory;
  }

  Color _iconColorForModel(String modelId) {
    if (modelId.startsWith('gpt')) return CognitiveAIBotTheme.iconGreen;
    if (modelId.contains('gemini')) return CognitiveAIBotTheme.iconBlue;
    if (modelId.contains('perplexity')) return CognitiveAIBotTheme.iconTeal;
    if (modelId.contains('grok')) return CognitiveAIBotTheme.iconPurple;
    if (modelId.contains('mistral')) return const Color(0xFF6366F1);
    return CognitiveAIBotTheme.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    if (!usageAvailable) {
      return Scaffold(
        backgroundColor: useDesktopLayout ? const Color(0xFF0D0D0D) : CognitiveAIBotTheme.background,
        appBar: useDesktopLayout
            ? null
            : AppBar(
                title: const Text(
                  'Usage Dashboard',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: CognitiveAIBotTheme.textPrimary,
                  ),
                ),
                elevation: 0,
              ),
        body: const _NoUsageYet(),
      );
    }

    if (useDesktopLayout) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DesktopHeader(onSelectDateRange: () {}, onExportData: () {}),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _DesktopDashboardContent(
                  iconForModel: _iconForModel,
                  iconColorForModel: _iconColorForModel,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SummaryCards(),
          const SizedBox(height: 24),
          _MostUsedModels(
            iconForModel: _iconForModel,
            iconColorForModel: _iconColorForModel,
          ),
          const SizedBox(height: 24),
          const _DailySpending(),
          const SizedBox(height: 24),
          _BreakdownByModel(
            iconForModel: _iconForModel,
            iconColorForModel: _iconColorForModel,
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.bar_chart, color: CognitiveAIBotTheme.primaryBlue),
              onPressed: () {},
            ),
          ),
        ),
        title: const Text(
          'Usage Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'date') {
                // TODO: Select date range
              } else if (value == 'export') {
                // TODO: Export data
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    SizedBox(width: 12),
                    Text('Select Date Range'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('Export Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: content,
    );
  }
}

/// Shown until usage is tracked for a real account.
class _NoUsageYet extends StatelessWidget {
  const _NoUsageYet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              const Text(
                'No usage yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cost and token tracking starts once the app is connected to your '
                'CognitiveAI Bot account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.4, color: CognitiveAIBotTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop header: "Usage Dashboard" title + kebab menu (Select Date Range, Export Data)
class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.onSelectDateRange,
    required this.onExportData,
  });

  final VoidCallback onSelectDateRange;
  final VoidCallback onExportData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Usage Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70, size: 24),
            offset: const Offset(0, 48),
            color: _DesktopDesign.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (value) {
              if (value == 'date') onSelectDateRange();
              if (value == 'export') onExportData();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: Colors.white70),
                    const SizedBox(width: 12),
                    const Text('Select Date Range', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20, color: Colors.white70),
                    const SizedBox(width: 12),
                    const Text('Export Data', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Desktop-only dashboard content — pixel-perfect match to design image
class _DesktopDashboardContent extends StatelessWidget {
  const _DesktopDashboardContent({
    required this.iconForModel,
    required this.iconColorForModel,
  });

  final IconData Function(String) iconForModel;
  final Color Function(String) iconColorForModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DesktopSummaryCards(),
        const SizedBox(height: 28),
        _DesktopMostUsedModels(
          iconForModel: iconForModel,
          iconColorForModel: iconColorForModel,
        ),
        const SizedBox(height: 28),
        const _DesktopDailySpending(),
        const SizedBox(height: 28),
        _DesktopBreakdownByModel(
          iconForModel: iconForModel,
          iconColorForModel: iconColorForModel,
        ),
      ],
    );
  }
}

class _DesktopSummaryCards extends StatelessWidget {
  const _DesktopSummaryCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: _DesktopLeftCard()),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: _DesktopTotalUsageCard()),
      ],
    );
  }
}

/// Left card: Total Cost (left half) + Current Progress inner card (right half)
class _DesktopLeftCard extends StatelessWidget {
  const _DesktopLeftCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _DesktopDesign.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'TOTAL COST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '\$12.45',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _DesktopDesign.accentBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward, size: 14, color: _DesktopDesign.accentGreen),
                    const SizedBox(width: 4),
                    Text(
                      '12% from last month',
                      style: TextStyle(fontSize: 12, color: _DesktopDesign.accentGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // FilledButton.icon(
                    //   onPressed: () {},
                    //   icon: const Icon(Icons.notifications_outlined, size: 18, color: Colors.white),
                    //   label: const Text('Set Budget Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    //   style: FilledButton.styleFrom(
                    //     backgroundColor: _DesktopDesign.accentBlue,
                    //     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    //     minimumSize: Size.zero,
                    //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    //   ),
                    // ),
                    Material(
                      color: _DesktopDesign.accentBlue,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: const Text(
                            'Set Budget Alert',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),

                    Material(
                      color: _DesktopDesign.compareButtonBg,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: const Text(
                            'Compare with Last Month',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _DesktopCurrentProgressInnerCard(),
        ],
        ),
      ),
    );
  }
}

/// Inner card: Current Progress with donut chart, inside the left summary card
class _DesktopCurrentProgressInnerCard extends StatelessWidget {
  const _DesktopCurrentProgressInnerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DesktopDesign.compareButtonBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CURRENT PROGRESS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.75,
                  strokeWidth: 6,
                  backgroundColor: _DesktopDesign.barMuted,
                  valueColor: const AlwaysStoppedAnimation<Color>(_DesktopDesign.accentBlue),
                ),
                const Text(
                  '75%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'of \$16.00 limit',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _DesktopTotalUsageCard extends StatelessWidget {
  const _DesktopTotalUsageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _DesktopDesign.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL USAGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '2.5M',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Across 4 models',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 55),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quota Remaining',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
              ),
              Text(
                '8.5M / 10M',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.85,
              backgroundColor: _DesktopDesign.barMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(_DesktopDesign.accentBlue),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopMostUsedModels extends StatelessWidget {
  const _DesktopMostUsedModels({
    required this.iconForModel,
    required this.iconColorForModel,
  });

  final IconData Function(String) iconForModel;
  final Color Function(String) iconColorForModel;

  static const _topModels = [
    ('gpt-4o', 'GPT-4o', '1.2M', 1),
    ('gemini-pro', 'Gemini Pro', '800k', 2),
    ('perplexity', 'Perplexity', '200s', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MOST USED MODELS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const Text(
              'TOP 3',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _DesktopDesign.accentBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DesktopTopModelCard(
                modelId: _topModels[0].$1,
                name: _topModels[0].$2,
                usage: _topModels[0].$3,
                rank: _topModels[0].$4,
                icon: iconForModel(_topModels[0].$1),
                iconColor: iconColorForModel(_topModels[0].$1),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _DesktopTopModelCard(
                modelId: _topModels[1].$1,
                name: _topModels[1].$2,
                usage: _topModels[1].$3,
                rank: _topModels[1].$4,
                icon: iconForModel(_topModels[1].$1),
                iconColor: iconColorForModel(_topModels[1].$1),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _DesktopTopModelCard(
                modelId: _topModels[2].$1,
                name: _topModels[2].$2,
                usage: _topModels[2].$3,
                rank: _topModels[2].$4,
                icon: iconForModel(_topModels[2].$1),
                iconColor: iconColorForModel(_topModels[2].$1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DesktopTopModelCard extends StatelessWidget {
  const _DesktopTopModelCard({
    required this.modelId,
    required this.name,
    required this.usage,
    required this.rank,
    required this.icon,
    required this.iconColor,
  });

  final String modelId;
  final String name;
  final String usage;
  final int rank;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DesktopDesign.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _DesktopDesign.accentBlue,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          Center(
            child: Padding(padding: const EdgeInsets.only(top: 25), child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                usage,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
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

class _DesktopDailySpending extends StatelessWidget {
  const _DesktopDailySpending();

  static const _data = [2.5, 3.1, 1.8, 3.5, 2.9, 1.5, 2.1];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxVal = _data.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DAILY SPENDING',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Last 7 Days',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _DesktopDesign.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 230,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _data.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Tooltip(
                    message: i == 3
                        ? '\$${_data[i].toStringAsFixed(2)} (Today)'
                        : '\$${_data[i].toStringAsFixed(2)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (i == 3)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _DesktopDesign.tooltipBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24, width: 0.5),
                              ),
                              child: Text(
                                '\$${_data[i].toStringAsFixed(2)} (Today)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          height: 24 + (_data[i] / maxVal) * 130,
                          decoration: BoxDecoration(
                            color: i == 3 ? _DesktopDesign.accentBlue : _DesktopDesign.barMuted,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _days[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ],
    );
  }
}

class _DesktopBreakdownByModel extends StatelessWidget {
  const _DesktopBreakdownByModel({
    required this.iconForModel,
    required this.iconColorForModel,
  });

  final IconData Function(String) iconForModel;
  final Color Function(String) iconColorForModel;

  static const _models = [
    ('gpt-4o', 'GPT-4o', '1.2M tokens', '+8%', '\$8.20', 0.66),
    ('gemini-1.5-pro', 'Gemini 1.5 Pro', '800k tokens', '+5%', '\$2.15', 0.17),
    ('perplexity', 'Perplexity', '200 searches', '+2%', '\$1.50', 0.12),
    ('grok-2', 'Grok-2', '300k tokens', '-1%', '\$0.60', 0.05),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BREAKDOWN BY MODEL',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._models.map((m) {
          final (id, name, usage, trend, cost, pct) = m;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DesktopBreakdownRow(
              modelId: id,
              name: name,
              usage: usage,
              trend: trend,
              cost: cost,
              progress: pct,
              icon: iconForModel(id),
              iconColor: iconColorForModel(id),
            ),
          );
        }),
      ],
    );
  }
}

class _DesktopBreakdownRow extends StatelessWidget {
  const _DesktopBreakdownRow({
    required this.modelId,
    required this.name,
    required this.usage,
    required this.trend,
    required this.cost,
    required this.progress,
    required this.icon,
    required this.iconColor,
  });

  final String modelId;
  final String name;
  final String usage;
  final String trend;
  final String cost;
  final double progress;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final isPositive = trend.startsWith('+');
    final trendColor = isPositive
        ? _DesktopDesign.accentGreen
        : trend.startsWith('-')
            ? Colors.red.shade400
            : Colors.white70;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DesktopDesign.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          usage,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isPositive ? Icons.arrow_upward : Icons.trending_down,
                          size: 12,
                          color: trendColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          trend,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: trendColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                cost,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _DesktopDesign.barMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(_DesktopDesign.accentBlue),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'TOTAL COST',
            value: '\$12.45',
            valueColor: CognitiveAIBotTheme.primaryBlue,
            subtitle: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_upward, size: 16, color: CognitiveAIBotTheme.positiveGreen),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '12% from last month',
                    style: TextStyle(
                      fontSize: 12,
                      color: CognitiveAIBotTheme.positiveGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'TOTAL TOKENS',
            value: '2.5M',
            valueColor: CognitiveAIBotTheme.textPrimary,
            subtitle: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 14, color: CognitiveAIBotTheme.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Across 4 models',
                  style: TextStyle(
                    fontSize: 12,
                    color: CognitiveAIBotTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.valueColor = CognitiveAIBotTheme.primaryBlue,
  });

  final String title;
  final String value;
  final Widget subtitle;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CognitiveAIBotTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          subtitle,
        ],
      ),
    );
  }
}

class _MostUsedModels extends StatelessWidget {
  const _MostUsedModels({
    required this.iconForModel,
    required this.iconColorForModel,
  });

  final IconData Function(String) iconForModel;
  final Color Function(String) iconColorForModel;

  static const _topModels = [
    ('gpt-4o', 'GPT-4o', '1.2M', 1),
    ('gemini-pro', 'Gemini Pro', '800k', 2),
    ('perplexity', 'Perplexity', '200s', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MOST USED MODELS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CognitiveAIBotTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CognitiveAIBotTheme.topBadgeBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'TOP 3',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CognitiveAIBotTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _topModels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final (id, name, usage, rank) = _topModels[i];
              return SizedBox(
                width: 110,
                child: _TopModelCard(
                  modelId: id,
                  name: name,
                  usage: usage,
                  rank: rank,
                  icon: iconForModel(id),
                  iconColor: iconColorForModel(id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopModelCard extends StatelessWidget {
  const _TopModelCard({
    required this.modelId,
    required this.name,
    required this.usage,
    required this.rank,
    required this.icon,
    required this.iconColor,
  });

  final String modelId;
  final String name;
  final String usage;
  final int rank;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: CognitiveAIBotTheme.textPrimary,
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: CognitiveAIBotTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CognitiveAIBotTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                usage,
                style: const TextStyle(
                  fontSize: 12,
                  color: CognitiveAIBotTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailySpending extends StatelessWidget {
  const _DailySpending();

  static const _data = [2.5, 3.1, 1.8, 4.2, 2.9, 1.5, 2.1];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxVal = _data.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DAILY SPENDING',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CognitiveAIBotTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const Text(
              'Last 7 Days',
              style: TextStyle(
                fontSize: 12,
                color: CognitiveAIBotTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _data.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: 30 + (_data[i] / maxVal) * 55,
                        decoration: BoxDecoration(
                          color: i == 3
                              ? CognitiveAIBotTheme.primaryBlue
                              : CognitiveAIBotTheme.cardBackgroundAlt,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _days[i],
                        style: const TextStyle(
                          fontSize: 10,
                          color: CognitiveAIBotTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownByModel extends StatelessWidget {
  const _BreakdownByModel({
    required this.iconForModel,
    required this.iconColorForModel,
  });

  final IconData Function(String) iconForModel;
  final Color Function(String) iconColorForModel;

  static const _models = [
    ('gpt-4o', 'GPT-4o', '1.2M tokens', '\$8.20', 0.66),
    ('gemini-1.5-pro', 'Gemini 1.5 Pro', '800k tokens', '\$2.15', 0.17),
    ('perplexity', 'Perplexity', '200 searches', '\$1.50', 0.12),
    ('grok-2', 'Grok-2', '300k tokens', '\$0.60', 0.05),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BREAKDOWN BY MODEL',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CognitiveAIBotTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._models.map((m) {
          final (id, name, usage, cost, pct) = m;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BreakdownRow(
              modelId: id,
              name: name,
              usage: usage,
              cost: cost,
              progress: pct,
              icon: iconForModel(id),
              iconColor: iconColorForModel(id),
            ),
          );
        }),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.modelId,
    required this.name,
    required this.usage,
    required this.cost,
    required this.progress,
    required this.icon,
    required this.iconColor,
  });

  final String modelId;
  final String name;
  final String usage;
  final String cost;
  final double progress;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: CognitiveAIBotTheme.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CognitiveAIBotTheme.textPrimary,
                      ),
                    ),
                    Text(
                      usage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CognitiveAIBotTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                cost,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CognitiveAIBotTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: CognitiveAIBotTheme.cardBackgroundAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(CognitiveAIBotTheme.primaryBlue),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
