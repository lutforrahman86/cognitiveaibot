import 'package:flutter/material.dart';

import '../../core/constants/ai_services.dart';

/// Service and model selector dropdown
class ServiceModelSelector extends StatelessWidget {
  const ServiceModelSelector({
    super.key,
    required this.selectedServiceId,
    required this.selectedModelId,
    required this.onServiceChanged,
    required this.onModelChanged,
  });

  final String selectedServiceId;
  final String selectedModelId;
  final ValueChanged<String> onServiceChanged;
  final ValueChanged<String> onModelChanged;

  IconData _iconForService(String iconName) {
    switch (iconName) {
      case 'bolt':
        return Icons.bolt;
      case 'psychology':
        return Icons.psychology;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'explore':
        return Icons.explore;
      case 'search':
        return Icons.search;
      case 'smart_toy':
        return Icons.smart_toy;
      case 'auto_fix_high':
        return Icons.auto_fix_high;
      default:
        return Icons.memory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = AIServicesConfig.getService(selectedServiceId) ??
        AIServicesConfig.services.first;
    final model = AIServicesConfig.getModel(selectedServiceId, selectedModelId) ??
        service.models.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DropdownButton<String>(
              value: selectedServiceId,
              items: AIServicesConfig.services
                  .map((s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconForService(s.icon), size: 20),
                            const SizedBox(width: 8),
                            Text(s.name, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: onServiceChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownButton<String>(
              value: model.id,
              items: service.models
                  .map((m) => DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(m.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onModelChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownButton<T> extends StatelessWidget {
  const _DropdownButton({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items: items,
      onChanged: (v) => v != null ? onChanged(v) : null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
