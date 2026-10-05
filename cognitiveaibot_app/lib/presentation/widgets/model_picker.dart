import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/ai_model.dart';

/// Button showing the chosen model; opens the server's model list. Models
/// the server can't answer with right now are greyed out and can't be chosen.
class ModelPickerButton extends StatelessWidget {
  const ModelPickerButton({
    super.key,
    required this.models,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final List<AiModel> models;
  final AiModel? selected;
  final ValueChanged<AiModel> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CognitiveAIBotTheme.cardBackground,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: const Key('model-picker'),
        borderRadius: BorderRadius.circular(24),
        onTap: enabled && models.isNotEmpty ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, size: 18, color: selected != null ? CognitiveAIBotTheme.positiveGreen : CognitiveAIBotTheme.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  selected?.name ?? (models.isEmpty ? 'Loading models…' : 'No model available'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18, color: CognitiveAIBotTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<AiModel>(
      context: context,
      backgroundColor: CognitiveAIBotTheme.surface,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, controller) => ModelList(
          models: models,
          selectedId: selected?.id,
          scrollController: controller,
          onSelected: (m) => Navigator.of(ctx).pop(m),
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }
}

/// The model catalog grouped by provider, unavailable models greyed out.
class ModelList extends StatelessWidget {
  const ModelList({
    super.key,
    required this.models,
    required this.selectedId,
    required this.onSelected,
    this.scrollController,
    this.padding = const EdgeInsets.only(bottom: 24),
  });

  final List<AiModel> models;
  final String? selectedId;
  final ValueChanged<AiModel> onSelected;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final byProvider = <String, List<AiModel>>{};
    for (final m in models) {
      byProvider.putIfAbsent(m.provider.isEmpty ? 'Other' : m.provider, () => []).add(m);
    }
    return ListView(
      controller: scrollController,
      padding: padding,
      children: [
        for (final entry in byProvider.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              entry.key.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textSecondary, letterSpacing: 0.6),
            ),
          ),
          for (final m in entry.value) _ModelTile(model: m, selected: m.id == selectedId, onTap: () => onSelected(m)),
        ],
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.model, required this.selected, required this.onTap});

  final AiModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = model.available ? CognitiveAIBotTheme.textPrimary : CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.6);
    return ListTile(
      enabled: model.available,
      onTap: model.available ? onTap : null,
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(model.name, style: TextStyle(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      subtitle: Text(
        model.available ? (model.category ?? model.provider) : 'Not available yet',
        style: TextStyle(fontSize: 12, color: CognitiveAIBotTheme.textSecondary.withValues(alpha: model.available ? 1 : 0.6)),
      ),
      trailing: selected ? const Icon(Icons.check, color: CognitiveAIBotTheme.primaryBlue) : null,
    );
  }
}
