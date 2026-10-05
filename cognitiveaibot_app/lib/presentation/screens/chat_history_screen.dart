import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/conversation.dart';
import '../providers/account_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/conversation_actions.dart';

/// The user's chats, stored on the server, newest first. Search runs on the
/// server (title and latest message).
class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({
    super.key,
    required this.onOpenConversation,
    required this.onNewChat,
    this.useDesktopLayout = false,
  });

  final ValueChanged<Conversation> onOpenConversation;
  final VoidCallback onNewChat;
  final bool useDesktopLayout;

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  final _search = SearchDebouncer();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = widget.useDesktopLayout;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (desktop)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text('History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(desktop ? 24 : 16, desktop ? 0 : 8, desktop ? 24 : 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: desktop ? 420 : double.infinity),
              child: SearchField(
                hintText: 'Search conversations...',
                onChanged: (v) => _search.update(v, () => setState(() {})),
              ),
            ),
          ),
        ),
        Expanded(child: _buildList(desktop)),
      ],
    );
    return Scaffold(
      backgroundColor: desktop ? const Color(0xFF0D0D0D) : CognitiveAIBotTheme.background,
      appBar: desktop
          ? null
          : AppBar(
              title: const Text('Chat History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: CognitiveAIBotTheme.background,
              actions: [
                IconButton(tooltip: 'New chat', icon: const Icon(Icons.add_comment_outlined), onPressed: widget.onNewChat),
              ],
            ),
      body: body,
    );
  }

  Widget _buildList(bool desktop) {
    final query = _search.query;
    final chats = ref.watch(conversationsProvider(query));
    return chats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Empty(
        icon: Icons.cloud_off,
        title: 'Couldn’t load your chats',
        subtitle: errorText(e),
        action: FilledButton(onPressed: () => ref.invalidate(conversationsProvider(query)), child: const Text('Retry')),
      ),
      data: (list) {
        if (list.isEmpty) {
          return query.isEmpty
              ? _Empty(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations yet',
                  subtitle: 'Your chats are saved to your account and show up here.',
                  action: FilledButton.icon(onPressed: widget.onNewChat, icon: const Icon(Icons.add), label: const Text('New Chat')),
                )
              : _Empty(icon: Icons.search_off, title: 'No chats match “$query”', subtitle: 'Try other words.');
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(conversationsProvider(query).future),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(desktop ? 16 : 0, 0, desktop ? 16 : 0, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.15),
            ),
            itemBuilder: (context, i) => _ChatTile(
              conversation: list[i],
              onTap: () => widget.onOpenConversation(list[i]),
            ),
          ),
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat_bubble, size: 22, color: CognitiveAIBotTheme.primaryBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(formatChatTime(c.updatedAt), style: const TextStyle(fontSize: 12, color: CognitiveAIBotTheme.textSecondary)),
                    ],
                  ),
                  if (c.excerpt != null && c.excerpt!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.excerpt!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: CognitiveAIBotTheme.textSecondary),
                    ),
                  ],
                  if (c.modelName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CognitiveAIBotTheme.cardBackgroundAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.modelName!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textPrimary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ConversationMenu(conversation: c),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary)),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
