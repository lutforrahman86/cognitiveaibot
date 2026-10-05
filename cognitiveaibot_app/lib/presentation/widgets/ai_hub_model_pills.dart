import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';

/// Horizontal scrollable model pills for CognitiveAI Bot chat
class AIHubModelPills extends StatelessWidget {
  const AIHubModelPills({
    super.key,
    required this.selectedModelId,
    required this.models,
    required this.onModelSelected,
    this.statusText = 'OPENAI',
    this.statusColor = CognitiveAIBotTheme.positiveGreen,
  });

  final String selectedModelId;
  final List<({String id, String name})> models;
  final ValueChanged<String> onModelSelected;
  final String statusText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: models
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ModelPill(
                          label: m.name,
                          isSelected: m.id == selectedModelId,
                          onTap: () => onModelSelected(m.id),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CognitiveAIBotTheme.textPrimary,
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

class _ModelPill extends StatelessWidget {
  const _ModelPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? CognitiveAIBotTheme.primaryBlue
              : CognitiveAIBotTheme.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? CognitiveAIBotTheme.textPrimary
                : CognitiveAIBotTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
