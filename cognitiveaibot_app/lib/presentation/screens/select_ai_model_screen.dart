import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';

/// Model item for the Select AI Model screen
class _ModelItem {
  const _ModelItem({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    required this.capabilities,
    required this.iconLabel,
    required this.iconBgColor,
    required this.iconFgColor,
  });

  final String id;
  final String name;
  final String provider;
  final String description;
  final List<String> capabilities;
  final String iconLabel;
  final Color iconBgColor;
  final Color iconFgColor;
}

/// Select AI Model screen - choose from top tier models
class SelectAIModelScreen extends StatefulWidget {
  const SelectAIModelScreen({
    super.key,
    this.onBack,
  });

  /// When provided, back button triggers this instead of Navigator.pop
  final VoidCallback? onBack;

  @override
  State<SelectAIModelScreen> createState() => _SelectAIModelScreenState();
}

class _SelectAIModelScreenState extends State<SelectAIModelScreen> {
  String _selectedModelId = 'gpt-4o';
  String _searchQuery = '';
  String _activeFilter = 'All Models';
  final _searchController = TextEditingController();

  static const _filters = ['All Models', 'Reasoning', 'Coding', 'Search'];

  static final _models = [
    _ModelItem(
      id: 'gpt-4o',
      name: 'GPT-4o',
      provider: 'OpenAI',
      description:
          'Industry leader in complex reasoning, creative writing, and nuanced instruction following.',
      capabilities: ['Reasoning', 'Multimodal'],
      iconLabel: 'OAI',
      iconBgColor: Colors.transparent,
      iconFgColor: CognitiveAIBotTheme.iconGreen,
    ),
    _ModelItem(
      id: 'gemini-1.5-pro',
      name: 'Gemini 1.5 Pro',
      provider: 'Google',
      description:
          'Optimized for massive context windows and lightning-fast information retrieval across documents.',
      capabilities: ['2M Context', 'Fast'],
      iconLabel: 'G',
      iconBgColor: const Color(0xFF4285F4),
      iconFgColor: CognitiveAIBotTheme.textPrimary,
    ),
    _ModelItem(
      id: 'perplexity-sonar',
      name: 'Perplexity Sonar',
      provider: 'Perplexity',
      description:
          'Real-time web search and cited information for the most up-to-date factual queries.',
      capabilities: ['Live Search', 'Cited'],
      iconLabel: 'P',
      iconBgColor: const Color(0xFF1A1A1A),
      iconFgColor: CognitiveAIBotTheme.textPrimary,
    ),
    _ModelItem(
      id: 'deepseek-v3',
      name: 'DeepSeek-V3',
      provider: 'DeepSeek',
      description:
          'Exceptional performance in coding, mathematical logic, and technical documentation.',
      capabilities: ['Coding', 'Math'],
      iconLabel: 'DS',
      iconBgColor: const Color(0xFF0D9488),
      iconFgColor: CognitiveAIBotTheme.textPrimary,
    ),
    _ModelItem(
      id: 'grok-2',
      name: 'Grok-2',
      provider: 'xAI',
      description:
          'Real-time access to X data with a witty, unfiltered response style and current event awareness.',
      capabilities: ['Real-time X', 'Unfiltered'],
      iconLabel: 'x',
      iconBgColor: const Color(0xFFFFFFFF),
      iconFgColor: const Color(0xFF1A1A1A),
    ),
    _ModelItem(
      id: 'mistral-small',
      name: 'Mistral Small',
      provider: 'Mistral AI',
      description:
          'Fast and affordable model ideal for quick tasks and high-volume usage.',
      capabilities: ['Fast', 'Budget'],
      iconLabel: 'M',
      iconBgColor: const Color(0xFF6366F1),
      iconFgColor: CognitiveAIBotTheme.textPrimary,
    ),
    _ModelItem(
      id: 'mistral-large',
      name: 'Mistral Large',
      provider: 'Mistral AI',
      description:
          'State-of-the-art model for complex reasoning, code, and multilingual tasks.',
      capabilities: ['Reasoning', 'Multilingual'],
      iconLabel: 'M',
      iconBgColor: const Color(0xFF6366F1),
      iconFgColor: CognitiveAIBotTheme.textPrimary,
    ),
  ];

  List<_ModelItem> get _filteredModels {
    var list = _models;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              m.provider.toLowerCase().contains(q) ||
              m.description.toLowerCase().contains(q) ||
              m.capabilities.any((c) => c.toLowerCase().contains(q)))
          .toList();
    }
    if (_activeFilter != 'All Models') {
      list = list
          .where((m) => m.capabilities
              .any((c) => c.toLowerCase().contains(_activeFilter.toLowerCase())))
          .toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        foregroundColor: CognitiveAIBotTheme.textPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select AI Model',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: CognitiveAIBotTheme.textPrimary,
              ),
            ),
            Text(
              'Current: ${_models.firstWhere((m) => m.id == _selectedModelId, orElse: () => _models.first).name}',
              style: const TextStyle(
                fontSize: 12,
                color: CognitiveAIBotTheme.primaryBlue,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'TOP TIER MODELS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CognitiveAIBotTheme.primaryBlue,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 12.0;
                    final useTwoColumns = constraints.maxWidth >= 600;
                    final columns = useTwoColumns ? 2 : 1;
                    final models = _filteredModels;
                    final rows = <Widget>[];

                    for (var i = 0; i < models.length; i += columns) {
                      final rowModels = models.skip(i).take(columns).toList();
                      rows.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var j = 0; j < columns; j++) ...[
                                if (j > 0) SizedBox(width: gap),
                                SizedBox(
                                  width: (constraints.maxWidth - (columns - 1) * gap) / columns,
                                  child: j < rowModels.length
                                      ? _ModelCard(
                                          model: rowModels[j],
                                          isSelected: rowModels[j].id == _selectedModelId,
                                          onSelect: () => setState(() => _selectedModelId = rowModels[j].id),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...rows,
                        const SizedBox(height: 24),
                        _buildConnectApiCta(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search models by capability...',
          hintStyle: const TextStyle(
            color: CognitiveAIBotTheme.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: CognitiveAIBotTheme.textSecondary,
            size: 22,
          ),
          filled: true,
          fillColor: CognitiveAIBotTheme.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          color: CognitiveAIBotTheme.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _filters.map((f) {
          final isActive = f == _activeFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f),
              selected: isActive,
              onSelected: (_) => setState(() => _activeFilter = f),
              backgroundColor: CognitiveAIBotTheme.cardBackground,
              selectedColor: CognitiveAIBotTheme.primaryBlue,
              labelStyle: TextStyle(
                color: isActive
                    ? CognitiveAIBotTheme.textPrimary
                    : CognitiveAIBotTheme.textPrimary,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConnectApiCta() {
    return Column(
      children: [
        const Text(
          'Power user? Connect your own providers.',
          style: TextStyle(
            color: CognitiveAIBotTheme.textPrimary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Connect custom API
          },
          icon: const Icon(Icons.key, color: CognitiveAIBotTheme.primaryBlue),
          label: const Text(
            'Connect Custom API',
            style: TextStyle(color: CognitiveAIBotTheme.primaryBlue),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: CognitiveAIBotTheme.primaryBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onSelect,
  });

  final _ModelItem model;
  final bool isSelected;
  final VoidCallback onSelect;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: model.iconBgColor,
                  border: Border.all(
                    color: model.iconFgColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  model.iconLabel,
                  style: TextStyle(
                    color: model.iconFgColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          model.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: CognitiveAIBotTheme.textPrimary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: CognitiveAIBotTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: CognitiveAIBotTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${model.provider}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CognitiveAIBotTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            model.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: CognitiveAIBotTheme.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: model.capabilities
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CognitiveAIBotTheme.cardBackgroundAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CognitiveAIBotTheme.textPrimary,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSelect,
              style: FilledButton.styleFrom(
                backgroundColor: isSelected
                    ? CognitiveAIBotTheme.primaryBlue
                    : CognitiveAIBotTheme.cardBackgroundAlt,
                foregroundColor: CognitiveAIBotTheme.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(isSelected ? 'Selected' : 'Select Model'),
            ),
          ),
        ],
      ),
    );
  }
}
