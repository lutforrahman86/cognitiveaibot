import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/account.dart';
import '../../domain/usecases/delete_conversation.dart';
import '../../domain/usecases/get_conversations.dart';
import '../providers/account_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_session_provider.dart';
import '../providers/providers.dart';
import 'main_shell.dart';
import 'plans_screen.dart';

/// Account, plan and the settings saved on the server (`GET/PATCH /api/settings`).
class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key, this.useDesktopLayout = false});

  final bool useDesktopLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);

    final list = ListView(
      padding: EdgeInsets.all(useDesktopLayout ? 24 : 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (useDesktopLayout) ...[
                  const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                ],
                const _SectionHeader('ACCOUNT'),
                _Card(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.4),
                        child: Text(
                          (user?.displayName.isNotEmpty ?? false) ? user!.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      title: Text(user?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(user?.email ?? '', style: const TextStyle(color: CognitiveAIBotTheme.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const CurrentPlanCard(),
                const SizedBox(height: 8),
                _Card(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('View plans'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlansScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionHeader('CHAT'),
                settings.when(
                  loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => _Card(children: [
                    ListTile(
                      title: Text(errorText(e)),
                      trailing: TextButton(onPressed: () => ref.invalidate(settingsProvider), child: const Text('Retry')),
                    ),
                  ]),
                  data: (s) => _SettingsForm(settings: s),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('DATA'),
                _Card(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                      title: const Text('Delete all chats', style: TextStyle(color: Colors.redAccent)),
                      onTap: () => _deleteAllChats(context, ref),
                    ),
                    ListTile(
                      key: const Key('settings-log-out'),
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                      onTap: () => confirmSignOut(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: useDesktopLayout ? const Color(0xFF0D0D0D) : CognitiveAIBotTheme.background,
      appBar: useDesktopLayout
          ? null
          : AppBar(
              title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              backgroundColor: CognitiveAIBotTheme.background,
            ),
      body: list,
    );
  }

  Future<void> _deleteAllChats(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CognitiveAIBotTheme.cardBackground,
        title: const Text('Delete all chats?'),
        content: const Text('Every conversation and its messages will be deleted from your account. This can’t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete all', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    var deleted = 0;
    var failed = false;
    // The server lists up to 100 chats at a time; repeat until none are left.
    for (var round = 0; round < 50 && !failed; round++) {
      final result = await ref.read(getConversationsProvider).call(const GetConversationsParams());
      final chats = switch (result) {
        Success(:final data) => data,
        FailureResult() => null,
      };
      if (chats == null) {
        failed = true;
      } else if (chats.isEmpty) {
        break;
      }
      for (final c in chats ?? const []) {
        final r = await ref.read(deleteConversationProvider).call(DeleteConversationParams(conversationId: c.id));
        if (r is FailureResult) {
          failed = true;
          break;
        }
        deleted++;
      }
    }
    ref.read(chatSessionProvider.notifier).startNew();
    ref.invalidate(conversationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failed ? 'Some chats couldn’t be deleted. Try again.' : 'Deleted $deleted chat${deleted == 1 ? '' : 's'}'),
      ));
    }
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});

  final UserSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _prompt = TextEditingController(text: widget.settings.systemPrompt ?? '');
  double? _temperature;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _save(UserSettings Function(UserSettings) change, {String? done}) async {
    final error = await ref.read(settingsProvider.notifier).save(change);
    if (!mounted) return;
    if (error != null || done != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error ?? done!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final promptChanged = _prompt.text.trim() != (s.systemPrompt ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          children: [
            ListTile(
              title: const Text('Message text size'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<String>(
                  key: const Key('font-size'),
                  segments: const [
                    ButtonSegment(value: 'small', label: Text('Small')),
                    ButtonSegment(value: 'medium', label: Text('Medium')),
                    ButtonSegment(value: 'large', label: Text('Large')),
                  ],
                  selected: {s.fontSize},
                  onSelectionChanged: (v) => _save((c) => c.copyWith(fontSize: v.first)),
                ),
              ),
            ),
            SwitchListTile(
              key: const Key('enter-to-send'),
              title: const Text('Enter to send'),
              subtitle: const Text('Off: Enter starts a new line and ⌘ + Enter sends',
                  style: TextStyle(color: CognitiveAIBotTheme.textSecondary)),
              value: s.enterToSend,
              onChanged: (v) => _save((c) => c.copyWith(enterToSend: v)),
            ),
            SwitchListTile(
              key: const Key('show-timestamps'),
              title: const Text('Show timestamps'),
              subtitle: const Text('Time under each message', style: TextStyle(color: CognitiveAIBotTheme.textSecondary)),
              value: s.showTimestamps,
              onChanged: (v) => _save((c) => c.copyWith(showTimestamps: v)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('MODEL BEHAVIOUR'),
        _Card(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('System prompt', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('system-prompt'),
                    controller: _prompt,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 4000,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g. Answer briefly, in plain English.',
                      filled: true,
                      fillColor: CognitiveAIBotTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('save-system-prompt'),
                      onPressed: promptChanged
                          ? () => _save((c) => c.copyWith(systemPrompt: _prompt.text.trim()), done: 'System prompt saved')
                          : null,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              key: const Key('default-temperature'),
              title: const Text('Model’s default temperature'),
              subtitle: const Text('Off: choose how creative replies are (0 = focused, 2 = most varied)',
                  style: TextStyle(color: CognitiveAIBotTheme.textSecondary)),
              value: s.temperature == null,
              onChanged: (useDefault) => _save((c) => useDefault ? c.copyWith(clearTemperature: true) : c.copyWith(temperature: 1.0)),
            ),
            if (s.temperature != null)
              ListTile(
                title: Text('Temperature: ${(_temperature ?? s.temperature!).toStringAsFixed(1)}'),
                subtitle: Slider(
                  key: const Key('temperature'),
                  value: (_temperature ?? s.temperature!).clamp(0.0, 2.0),
                  min: 0,
                  max: 2,
                  divisions: 20,
                  onChanged: (v) => setState(() => _temperature = v),
                  onChangeEnd: (v) async {
                    await _save((c) => c.copyWith(temperature: v));
                    if (mounted) setState(() => _temperature = null);
                  },
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Applied to every reply, in the app and on the web.',
                style: TextStyle(fontSize: 12, color: CognitiveAIBotTheme.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textSecondary, letterSpacing: 0.6)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: CognitiveAIBotTheme.cardBackground, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Material(type: MaterialType.transparency, child: Column(children: children)),
      );
}
