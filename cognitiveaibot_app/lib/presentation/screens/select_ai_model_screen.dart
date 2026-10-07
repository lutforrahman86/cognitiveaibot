import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/ai_model.dart';
import '../providers/account_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_session_provider.dart';

/// The server's model catalog. Choosing a model makes it the one new chats
/// (and the open chat) use. Models the server can't answer with yet are
/// shown greyed out.
class SelectAIModelScreen extends ConsumerStatefulWidget {
  const SelectAIModelScreen({super.key, this.onModelChosen});

  final ValueChanged<AiModel>? onModelChosen;

  @override
  ConsumerState<SelectAIModelScreen> createState() => _SelectAIModelScreenState();
}

class _SelectAIModelScreenState extends ConsumerState<SelectAIModelScreen> {
  String _query = '';
  String? _category;

  void _choose(AiModel model) {
    ref.read(preferredModelIdProvider.notifier).state = model.id;
    ref.read(chatSessionProvider.notifier).selectModel(model);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${model.name} will answer your next message')));
    widget.onModelChosen?.call(model);
  }

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(modelsProvider);
    final preferred = ref.watch(preferredModelIdProvider);
    final current = defaultModel(models.valueOrNull ?? const [], preferred);

    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select AI Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (current != null)
              Text('Current: ${current.name}', style: const TextStyle(fontSize: 12, color: CognitiveAIBotTheme.primaryBlue)),
          ],
        ),
      ),
      body: models.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorText(e), style: const TextStyle(color: CognitiveAIBotTheme.textSecondary)),
              TextButton(onPressed: () => ref.invalidate(modelsProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (all) => _buildList(all, current),
      ),
    );
  }

  Widget _buildList(List<AiModel> all, AiModel? current) {
    final categories = {for (final m in all) if (m.category != null) m.category!}.toList()..sort();
    final q = _query.toLowerCase();
    final shown = all.where((m) {
      if (_category != null && m.category != _category) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) || m.provider.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search models...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: CognitiveAIBotTheme.cardBackground,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in [null, ...categories])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c ?? 'All Models'),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('No models match', style: TextStyle(color: CognitiveAIBotTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final m = shown[i];
                    final selected = m.id == current?.id;
                    return Opacity(
                      opacity: m.available ? 1 : 0.45,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: selected ? CognitiveAIBotTheme.primaryBlue : Colors.transparent),
                        ),
                        child: ListTile(
                          enabled: m.available,
                          onTap: m.available ? () => _choose(m) : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: CognitiveAIBotTheme.cardBackgroundAlt,
                            child: Text(
                              m.provider.isEmpty ? '?' : m.provider[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: CognitiveAIBotTheme.textPrimary),
                            ),
                          ),
                          title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textPrimary)),
                          subtitle: Text(
                            [m.provider, if (m.category != null) m.category!, if (!m.available) 'Not available yet'].join(' · '),
                            style: const TextStyle(fontSize: 12, color: CognitiveAIBotTheme.textSecondary),
                          ),
                          trailing: selected ? const Icon(Icons.check_circle, color: CognitiveAIBotTheme.primaryBlue) : null,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
