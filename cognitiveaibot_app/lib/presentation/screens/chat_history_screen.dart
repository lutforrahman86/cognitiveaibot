
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/utils/platform_info.dart';
import '../../data/models/chat_history_demo.dart';
import '../../domain/entities/conversation.dart';
import 'chat_screen.dart';

/// Desktop History design tokens — matches design image
class _DesktopHistoryDesign {
  _DesktopHistoryDesign._();
  static const mainBg = Color(0xFF0D0D0D);
  static const cardBg = Color(0xFF1F1F1F);
  static const accentBlue = Color(0xFF2196F3);
  static const accentGreen = Color(0xFF4CAF50);
  static const accentRed = Color(0xFFE53935);
  static const inputBg = Color(0xFF2F2F2F);
}

/// Chat History screen - list of conversations grouped by time (from demo JSON)
/// When [useDesktopLayout] is true, renders usage history table design for desktop
class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key, this.useDesktopLayout = false});

  final bool useDesktopLayout;

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  final List<ChatHistoryCategory> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // History isn't connected to real conversations until the app syncs with
    // the backend (roadmap Phase 4), so it starts empty. It used to show
    // invented chats from assets/data/chat_history_demo.json.
    _isLoading = false;
  }

  List<ChatHistoryCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    final q = _searchQuery.toLowerCase();
    return _categories.map((cat) {
      final filtered = cat.chats.where((c) =>
          c.title.toLowerCase().contains(q) ||
          c.descriptionExcerpt.toLowerCase().contains(q) ||
          c.modelName.toLowerCase().contains(q));
      return ChatHistoryCategory(category: cat.category, chats: filtered.toList());
    }).where((cat) => cat.chats.isNotEmpty).toList();
  }

  void _openChat(ChatHistoryEntry entry) {
    // Create a Conversation from demo entry for ChatScreen compatibility
    final serviceId = _modelToServiceId(entry.modelName);
    final modelId = _modelToModelId(entry.modelName);
    final conv = Conversation(
      id: entry.id,
      serviceId: serviceId,
      modelId: modelId,
      title: entry.title,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          conversation: conv,
          useDesktopLayout: isDesktopPlatform,
        ),
      ),
    );
  }

  void _openNewChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(useDesktopLayout: isDesktopPlatform),
      ),
    );
  }

  String _modelToServiceId(String model) {
    final m = model.toUpperCase();
    if (m.contains('GPT')) return 'openai';
    if (m.contains('CLAUDE')) return 'anthropic';
    if (m.contains('GEMINI')) return 'gemini';
    if (m.contains('GROK')) return 'grok';
    return 'openai';
  }

  String _modelToModelId(String model) {
    final m = model.toUpperCase();
    if (m.contains('GPT')) return 'gpt-4-turbo';
    if (m.contains('CLAUDE')) return 'claude-3-5-sonnet';
    if (m.contains('GEMINI')) return 'gemini-1.5-pro';
    if (m.contains('GROK')) return 'grok-2';
    return 'gpt-4o';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useDesktopLayout) {
      return _buildDesktopLayout(context);
    }
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        foregroundColor: CognitiveAIBotTheme.textPrimary,
        title: const Text(
          'Chat History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: CognitiveAIBotTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'history') {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Scaffold.of(context).openDrawer();
                  }
                });
              } else if (value == 'export') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export chat')),
                );
              } else if (value == 'settings') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat settings')),
                );
              } else if (value == 'clear') {
                // setState(() {
                //   _conversationId = '';
                //   _messages = [];
                //   _title = null;
                // });
                // _refreshHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: CognitiveAIBotTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('Chat History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: CognitiveAIBotTheme.primaryBlue),
                    SizedBox(width: 12),
                    Text('Export chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: CognitiveAIBotTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('Chat Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Clear History', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildConversationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    // The table, date range and stat cards below still hold the design's
    // sample rows (Oct 2023 dates, made-up costs); they're only shown once
    // there is real history to put in them.
    if (_categories.isEmpty) {
      return Scaffold(
        backgroundColor: _DesktopHistoryDesign.mainBg,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'History',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Expanded(child: _buildConversationList()),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _DesktopHistoryDesign.mainBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DesktopHistoryHeader(),
            const SizedBox(height: 24),
            const _DesktopHistoryTable(),
            const SizedBox(height: 24),
            _DesktopHistoryPagination(),
            const SizedBox(height: 24),
            const _DesktopHistoryStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
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

  Widget _buildConversationList() {
    final filtered = _filteredCategories;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CognitiveAIBotTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new chat from the AI Chat tab',
              style: TextStyle(
                fontSize: 14,
                color: CognitiveAIBotTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openNewChat,
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: FilledButton.styleFrom(
                backgroundColor: CognitiveAIBotTheme.primaryBlue,
              ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    for (final cat in filtered) {
        children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            cat.category,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CognitiveAIBotTheme.textSecondary,
            ),
          ),
        ),
      );
      for (int i = 0; i < cat.chats.length; i++) {
        children.add(_DemoChatTile(
          entry: cat.chats[i],
          onTap: () => _openChat(cat.chats[i]),
          showDivider: i < cat.chats.length - 1,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }
}

class _DemoChatTile extends StatelessWidget {
  const _DemoChatTile({
    required this.entry,
    required this.onTap,
    this.showDivider = true,
  });

  final ChatHistoryEntry entry;
  final VoidCallback onTap;
  final bool showDivider;

  static IconData _iconFromType(String type) {
    switch (type) {
      case 'chat_bubble':
        return Icons.chat_bubble;
      case 'terminal':
        return Icons.terminal;
      case 'fork_knife':
        return Icons.restaurant;
      case 'airplane':
        return Icons.flight;
      default:
        return Icons.chat_bubble;
    }
  }

  static Color _colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _colorFromHex(entry.iconBackgroundColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _iconFromType(entry.iconType),
                    size: 24,
                    color: Colors.white,
                  ),
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
                              entry.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CognitiveAIBotTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            entry.timestamp,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CognitiveAIBotTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.descriptionExcerpt,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CognitiveAIBotTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CognitiveAIBotTheme.cardBackgroundAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.modelName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CognitiveAIBotTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.2),
            ),
          ),
      ],
    );
  }
}

// --- Desktop History layout widgets ---

class _DesktopHistoryHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'History',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: const Text('AUDIT LOG'),
        ),
        const Spacer(),
        SizedBox(
          width: 240,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search records...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: _DesktopHistoryDesign.inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _DesktopHistoryDesign.inputBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 18, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text('Oct 18 - Oct 24', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.white70),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline, color: Colors.white70, size: 22),
        ),
      ],
    );
  }
}

class _DesktopHistoryTable extends StatelessWidget {
  const _DesktopHistoryTable();

  static final _rows = [
    ('Oct 24, 2023, 14:32:05', 'gpt-4o', 'GPT-4o', '12,400 tokens', '\$0.15', true),
    ('Oct 23, 2023, 11:05:41', 'gemini-pro', 'Gemini Pro', '5,200 tokens', '\$0.08', true),
    ('Oct 23, 2023, 09:15:22', 'perplexity', 'Perplexity', '12 searches', '\$0.24', true),
    ('Oct 22, 2023, 18:44:09', 'claude', 'Claude 3.5 Sonnet', '8,900 tokens', '\$0.11', true),
    ('Oct 22, 2023, 14:02:11', 'gpt-4o', 'GPT-4o', '—', '\$0.00', false),
  ];

  static IconData _iconForModel(String id) {
    if (id.startsWith('gpt')) return Icons.bolt;
    if (id.contains('gemini')) return Icons.auto_awesome;
    if (id.contains('perplexity')) return Icons.search;
    if (id.contains('claude')) return Icons.psychology;
    return Icons.memory;
  }

  static Color _colorForModel(String id) {
    if (id.startsWith('gpt')) return const Color(0xFF4CAF50);
    if (id.contains('gemini')) return const Color(0xFF4285F4);
    if (id.contains('perplexity')) return const Color(0xFF1A73E8);
    if (id.contains('claude')) return const Color(0xFFFF9800);
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: _DesktopHistoryDesign.cardBg,
        ),
        child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(0.8),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(0.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            children: [
              _headerCell('DATE'),
              _headerCell('MODEL USED'),
              _headerCell('TOKENS/SEARCHES'),
              _headerCell('COST'),
              _headerCell('STATUS'),
              _headerCell('ACTIONS'),
            ],
          ),
          for (final row in _rows) ...[
            TableRow(
              children: [
                _dataCell(row.$1),
                _modelCell(row.$2, row.$3),
                _dataCell(row.$4),
                _dataCell(row.$5),
                _statusCell(row.$6),
                _actionsCell(),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7)),
      ),
    );
  }

  Widget _dataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white)),
    );
  }

  Widget _modelCell(String modelId, String name) {
    final icon = _iconForModel(modelId);
    final color = _colorForModel(modelId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _statusCell(bool success) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: success ? _DesktopHistoryDesign.accentGreen : _DesktopHistoryDesign.accentRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            success ? 'SUCCESS' : 'FAILED',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: success ? _DesktopHistoryDesign.accentGreen : _DesktopHistoryDesign.accentRed),
          ),
        ],
      ),
    );
  }

  Widget _actionsCell() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: IconButton(icon: Icon(Icons.more_vert, color: Colors.white70, size: 20), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    );
  }
}

class _DesktopHistoryPagination extends StatelessWidget {
  const _DesktopHistoryPagination();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing 1 to 5 of 128 results',
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
        ),
        Row(
          children: [
            _PageButton(icon: Icons.chevron_left, onTap: () {}),
            const SizedBox(width: 4),
            _PageButton(label: '1', selected: true),
            _PageButton(label: '2'),
            _PageButton(label: '3'),
            _PageButton(label: '...'),
            _PageButton(label: '25'),
            const SizedBox(width: 4),
            _PageButton(icon: Icons.chevron_right, onTap: () {}),
          ],
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({this.label, this.icon, this.selected = false, this.onTap});

  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _DesktopHistoryDesign.accentBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: icon != null
              ? Icon(icon, size: 20, color: Colors.white70)
              : Text(label!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : Colors.white70)),
        ),
      ),
    );
  }
}

class _DesktopHistoryStats extends StatelessWidget {
  const _DesktopHistoryStats();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Spent (Period)',
            value: '\$42.84',
            sub: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_upward, size: 14, color: _DesktopHistoryDesign.accentGreen),
                const SizedBox(width: 4),
                Text('+12%', style: TextStyle(fontSize: 12, color: _DesktopHistoryDesign.accentGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(title: 'Top Model', value: 'GPT-4o', sub: Text('68% calls', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(title: 'Tokens Processed', value: '842k', sub: Text('Across 4 models', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(title: 'Reliability Rate', value: '99.2%', sub: Text('1 error today', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)))),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.sub});

  final String title;
  final String value;
  final Widget sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DesktopHistoryDesign.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 8),
              sub,
            ],
          ),
        ],
      ),
    );
  }
}
