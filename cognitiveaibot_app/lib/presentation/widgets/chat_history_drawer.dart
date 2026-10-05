import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/conversation.dart';
import '../providers/account_providers.dart';
import '../providers/chat_providers.dart';
import 'conversation_actions.dart';

/// The user's chats from the server, newest first, with server-side search.
/// Used as the mobile chat drawer and the desktop chat side panel.
class ConversationListPanel extends ConsumerStatefulWidget {
  const ConversationListPanel({
    super.key,
    required this.onSelectConversation,
    required this.onNewChat,
    this.currentConversationId,
    this.title = 'Chat History',
    this.closeOnSelect = false,
  });

  final ValueChanged<Conversation> onSelectConversation;
  final VoidCallback onNewChat;
  final String? currentConversationId;
  final String title;

  /// Pops the enclosing drawer before acting.
  final bool closeOnSelect;

  @override
  ConsumerState<ConversationListPanel> createState() => _ConversationListPanelState();
}

class _ConversationListPanelState extends ConsumerState<ConversationListPanel> {
  final _search = SearchDebouncer();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _act(VoidCallback action) {
    if (widget.closeOnSelect) Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(conversationsProvider(_search.query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitiveAIBotTheme.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'New chat',
                icon: const Icon(Icons.add_circle_outline, color: CognitiveAIBotTheme.textPrimary),
                onPressed: () => _act(widget.onNewChat),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SearchField(
            hintText: 'Search chats...',
            onChanged: (v) => _search.update(v, () => setState(() {})),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: chats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              text: errorText(e),
              action: TextButton(
                onPressed: () => ref.invalidate(conversationsProvider(_search.query)),
                child: const Text('Retry'),
              ),
            ),
            data: (list) => list.isEmpty
                ? _Message(text: _search.query.isEmpty ? 'No conversations yet' : 'No chats match “${_search.query}”')
                : RefreshIndicator(
                    onRefresh: () => ref.refresh(conversationsProvider(_search.query).future),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final selected = c.id == widget.currentConversationId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: CognitiveAIBotTheme.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          title: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected ? CognitiveAIBotTheme.textPrimary : Colors.white70,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            formatChatTime(c.updatedAt),
                            style: const TextStyle(fontSize: 11, color: CognitiveAIBotTheme.textSecondary),
                          ),
                          trailing: ConversationMenu(conversation: c),
                          onTap: () => _act(() => widget.onSelectConversation(c)),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The mobile chat drawer.
class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({
    super.key,
    required this.onSelectConversation,
    required this.onNewChat,
    this.currentConversationId,
  });

  final ValueChanged<Conversation> onSelectConversation;
  final VoidCallback onNewChat;
  final String? currentConversationId;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: CognitiveAIBotTheme.surface,
      child: SafeArea(
        child: ConversationListPanel(
          onSelectConversation: onSelectConversation,
          onNewChat: onNewChat,
          currentConversationId: currentConversationId,
          closeOnSelect: true,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary)),
            ?action,
          ],
        ),
      ),
    );
  }
}
