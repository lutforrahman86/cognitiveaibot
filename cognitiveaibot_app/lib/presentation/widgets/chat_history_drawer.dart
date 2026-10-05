import 'package:flutter/material.dart';

import '../../core/constants/ai_services.dart';
import '../../domain/entities/conversation.dart';

/// Drawer showing chat history grouped by service
class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({
    super.key,
    required this.conversationsByService,
    required this.onSelectConversation,
    required this.onNewChat,
    this.currentConversationId,
  });

  final Map<String, List<Conversation>> conversationsByService;
  final ValueChanged<Conversation> onSelectConversation;
  final VoidCallback onNewChat;
  final String? currentConversationId;

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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) {
      return 'Today';
    } else if (d == yesterday) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chat History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onNewChat();
                    },
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: conversationsByService.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No chat history yet',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation to see it here, grouped by service.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onNewChat();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Start New Chat'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final entry in conversationsByService.entries) ...[
                          _ServiceSection(
                            serviceName: AIServicesConfig.getService(entry.key)
                                    ?.name ??
                                entry.key,
                            icon: _iconForService(
                              AIServicesConfig.getService(entry.key)?.icon ??
                                  'memory',
                            ),
                            conversations: entry.value,
                            onSelect: onSelectConversation,
                            currentId: currentConversationId,
                            formatDate: _formatDate,
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceSection extends StatelessWidget {
  const _ServiceSection({
    required this.serviceName,
    required this.icon,
    required this.conversations,
    required this.onSelect,
    required this.currentId,
    required this.formatDate,
  });

  final String serviceName;
  final IconData icon;
  final List<Conversation> conversations;
  final ValueChanged<Conversation> onSelect;
  final String? currentId;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                serviceName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        ...conversations.map((c) {
          final isSelected = c.id == currentId;
          return ListTile(
            leading: Icon(
              isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              formatDate(c.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            selected: isSelected,
            onTap: () {
              Navigator.of(context).pop();
              onSelect(c);
            },
          );
        }),
      ],
    );
  }
}
