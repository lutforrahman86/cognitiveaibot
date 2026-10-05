
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ai_services.dart';
import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/usecases/create_conversation.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/send_chat_message.dart';
import '../../domain/usecases/update_conversation_title.dart';
import '../providers/providers.dart';
import '../widgets/ai_hub_chat_input.dart';
import '../widgets/ai_hub_message_bubble.dart';
import '../widgets/ai_hub_model_pills.dart';
import '../widgets/chat_history_drawer.dart';
import '../widgets/export_data_modal.dart';
import '../widgets/plan_status_text.dart';

/// Desktop chat design tokens — matches design image
class _DesktopChatDesign {
  _DesktopChatDesign._();
  static const sidebarBg = Color(0xFF181818);
  static const mainBg = Color(0xFF0D0D0D);
  static const accentBlue = Color(0xFF2196F3);
  static const positiveGreen = Color(0xFF4CAF50);
  static const cardBg = Color(0xFF1F1F1F);
  static const navActiveBg = Color(0xFF2F2F2F);
}

/// CognitiveAI Bot style chat screen - glassmorphic dark theme
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.conversation,
    this.initialServiceId,
    this.initialModelId,
    this.useDesktopLayout = false,
    this.onGoHome,
  });

  final Conversation? conversation;
  final String? initialServiceId;
  final String? initialModelId;
  final bool useDesktopLayout;
  final VoidCallback? onGoHome;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late String _conversationId;
  late String _serviceId;
  late String _modelId;
  String? _title;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  Map<String, List<Conversation>> _history = {};

  /// Top models for the pills (id, displayName, serviceId)
  static const _modelPills = [
    ('gpt-4o', 'GPT-4', 'openai'),
    ('claude-3-5-sonnet', 'Claude 3', 'anthropic'),
    ('gemini-1.5-pro', 'Gemini', 'gemini'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.conversation != null) {
      _conversationId = widget.conversation!.id;
      _serviceId = widget.conversation!.serviceId;
      _modelId = widget.conversation!.modelId;
      _title = widget.conversation!.title;
    } else {
      _serviceId = widget.initialServiceId ?? AIServicesConfig.services.first.id;
      _modelId = widget.initialModelId ??
          AIServicesConfig.services.first.models.first.id;
      _conversationId = '';
      _title = null;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (_conversationId.isEmpty) {
      // A new chat starts empty. (It used to be pre-filled from
      // assets/data/chat_demo.json, an invented conversation.)
      if (mounted) {
        setState(() {
          _messages = [];
          _isLoading = false;
        });
      }
    } else {
      final result = await ref.read(getChatMessagesProvider).call(
            GetChatMessagesParams(conversationId: _conversationId),
          );
      switch (result) {
        case Success(:final data):
          if (mounted) {
            setState(() {
              _messages = data;
              _isLoading = false;
            });
          }
        case FailureResult(:final failure):
          if (mounted) {
            setState(() {
              _error = failure.message ?? 'Failed to load messages';
              _isLoading = false;
            });
          }
      }
    }

    await _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final result =
        await ref.read(getConversationsProvider).call(const NoParams());
    switch (result) {
      case Success(:final data):
        if (mounted) {
          setState(() => _history = data);
        }
      case FailureResult():
        break;
    }
  }

  Future<bool> _startNewChat() async {
    final result = await ref.read(createConversationProvider).call(
          CreateConversationParams(
            serviceId: _serviceId,
            modelId: _modelId,
          ),
        );
    switch (result) {
      case Success(:final data):
        if (mounted) {
          setState(() {
            _conversationId = data.id;
            _serviceId = data.serviceId;
            _modelId = data.modelId;
            _title = data.title;
            _messages = [];
          });
          _refreshHistory();
        }
        return true;
      case FailureResult(:final failure):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message ?? 'Failed to create chat')),
          );
        }
        return false;
    }
  }

  void _openConversation(Conversation conv) {
    setState(() {
      _conversationId = conv.id;
      _serviceId = conv.serviceId;
      _modelId = conv.modelId;
      _title = conv.title;
      _isLoading = true;
    });
    _loadData();
  }

  Future<void> _sendMessage(String content) async {
    if (_conversationId.isEmpty) {
      final created = await _startNewChat();
      if (!mounted || !created) return;
    }

    setState(() => _isSending = true);

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      modelId: _modelId,
    );
    setState(() => _messages = [..._messages, userMessage]);

    if (_title == 'New Chat' || _title == null) {
      final newTitle =
          content.length > 40 ? '${content.substring(0, 40)}...' : content;
      _title = newTitle;
      ref.read(updateConversationTitleProvider).call(
            UpdateConversationTitleParams(
              conversationId: _conversationId,
              title: newTitle,
            ),
          );
    }

    final result = await ref.read(sendChatMessageProvider).call(
          SendChatMessageParams(
            conversationId: _conversationId,
            content: content,
            serviceId: _serviceId,
            modelId: _modelId,
          ),
        );

    switch (result) {
      case Success(:final data):
        if (mounted) {
          setState(() {
            _messages = [..._messages, data];
            _isSending = false;
          });
          _refreshHistory();
        }
      case FailureResult(:final failure):
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message ?? 'Failed to send message')),
          );
        }
    }
  }

  void _onModelPillSelected(String modelId) {
    final pill = _modelPills.firstWhere(
      (p) => p.$1 == modelId,
      orElse: () => _modelPills.first,
    );
    setState(() {
      _modelId = modelId;
      _serviceId = pill.$3;
    });
  }

  void _showExportChatModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => ExportDataModal(
        title: 'Export Chat',
        description:
            'Select your preferred file format to download this chat conversation.',
        onExport: (format) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exporting chat as ${format.name.toUpperCase()}...'),
            ),
          );
        },
      ),
    );
  }

  String _getStatusText() {
    final service = AIServicesConfig.getService(_serviceId);
    final model = AIServicesConfig.getModel(_serviceId, _modelId);
    final serviceName = service?.name.toUpperCase() ?? 'OPENAI';
    final modelName = model?.name ?? 'GPT-4';
    return '$serviceName $modelName ACTIVE';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useDesktopLayout) {
      return _buildDesktopLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: _DesktopChatDesign.mainBg,
      body: Row(
        children: [
          _DesktopChatLeftNav(
            onHome: widget.onGoHome ?? () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopChatHeader(
                  selectedModelId: _modelId,
                  models: _modelPills.map((p) => (id: p.$1, name: p.$2)).toList(),
                  onModelSelected: _onModelPillSelected,
                  statusText: _getStatusText(),
                  onMenuSelected: (v) => _onDesktopMenuSelected(context, v),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: _DesktopChatDesign.accentBlue))
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                    const SizedBox(height: 16),
                                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            )
                          : _messages.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 80, color: _DesktopChatDesign.accentBlue.withValues(alpha: 0.5)),
                                        const SizedBox(height: 24),
                                        const Text('Start a conversation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), textAlign: TextAlign.center),
                                        const SizedBox(height: 8),
                                        Text('Choose a model above and type your message below.', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)), textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, i) {
                                    final msg = _messages[i];
                                    if (msg.role == MessageRole.system) return const SizedBox.shrink();
                                    final modelName = AIServicesConfig.getModel(_serviceId, msg.modelId ?? _modelId)?.name ?? AIServicesConfig.getService(_serviceId)?.name;
                                    return AIHubMessageBubble(message: msg, modelName: modelName);
                                  },
                                ),
                ),
                AIHubChatInput(
                  onSend: _sendMessage,
                  enabled: !_isSending,
                  hintText: _isSending ? 'Waiting for response...' : 'Type a message...',
                ),
              ],
            ),
          ),
          _DesktopPastConversations(
            conversationsByService: _history,
            currentConversationId: _conversationId.isEmpty ? null : _conversationId,
            onSelectConversation: _openConversation,
            onNewChat: () {
              setState(() {
                _conversationId = '';
                _messages = [];
                _title = null;
              });
              _refreshHistory();
            },
          ),
        ],
      ),
    );
  }

  void _onDesktopMenuSelected(BuildContext context, String value) {
    if (value == 'history') return;
    if (value == 'export') {
      _showExportChatModal(context);
    } else if (value == 'settings') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat settings')));
    } else if (value == 'clear') {
      setState(() {
        _conversationId = '';
        _messages = [];
        _title = null;
      });
      _refreshHistory();
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        foregroundColor: CognitiveAIBotTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close, color: CognitiveAIBotTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CognitiveAI Bot',
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
                _showExportChatModal(context);
              } else if (value == 'settings') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat settings')),
                );
              } else if (value == 'clear') {
                setState(() {
                  _conversationId = '';
                  _messages = [];
                  _title = null;
                });
                _refreshHistory();
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
      drawer: ChatHistoryDrawer(
        conversationsByService: _history,
        onSelectConversation: _openConversation,
        onNewChat: () {
          setState(() {
            _conversationId = '';
            _messages = [];
            _title = null;
          });
          _refreshHistory();
        },
        currentConversationId: _conversationId.isEmpty ? null : _conversationId,
      ),
      body: Column(
        children: [
          AIHubModelPills(
            selectedModelId: _modelId,
            models: _modelPills
                .map((p) => (id: p.$1, name: p.$2))
                .toList(),
            onModelSelected: _onModelPillSelected,
            statusText: _getStatusText(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: CognitiveAIBotTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 80,
                                    color: CognitiveAIBotTheme.primaryBlue
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Start a conversation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: CognitiveAIBotTheme.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Choose a model above and type your message below.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: CognitiveAIBotTheme.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final msg = _messages[i];
                              if (msg.role == MessageRole.system) {
                                return const SizedBox.shrink();
                              }
                              final modelName = AIServicesConfig.getModel(
                                        _serviceId,
                                        msg.modelId ?? _modelId,
                                      )?.name ??
                                      AIServicesConfig.getService(_serviceId)
                                          ?.name;
                              return AIHubMessageBubble(
                                message: msg,
                                modelName: modelName,
                              );
                            },
                          ),
          ),
          AIHubChatInput(
            onSend: _sendMessage,
            enabled: !_isSending,
            hintText:
                _isSending ? 'Waiting for response...' : 'Type a message...',
          ),
        ],
      ),
    );
  }
}

// --- Desktop chat layout widgets ---

class _DesktopChatLeftNav extends StatelessWidget {
  const _DesktopChatLeftNav({required this.onHome});

  final VoidCallback onHome;

  static const _navItems = [
    (Icons.home_outlined, 'Home', 0),
    (Icons.history, 'History', 1),
    (Icons.view_in_ar, 'Models', 2),
    (Icons.show_chart, 'Usage', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _DesktopChatDesign.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white70, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    notSignedInLabel,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ..._navItems.map((item) {
            final (icon, label, index) = item;
            final isHistory = index == 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Material(
                color: isHistory ? _DesktopChatDesign.navActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: isHistory ? null : (index == 0 ? onHome : () {}),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      if (isHistory)
                        Container(
                          width: 3,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: _DesktopChatDesign.accentBlue,
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 22,
                              color: isHistory ? _DesktopChatDesign.accentBlue : Colors.white70,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isHistory ? FontWeight.w600 : FontWeight.w500,
                                color: isHistory ? Colors.white : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 22, color: Colors.white70),
                      const SizedBox(width: 14),
                      const Text(
                        'Settings',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DesktopChatHeader extends StatelessWidget {
  const _DesktopChatHeader({
    required this.selectedModelId,
    required this.models,
    required this.onModelSelected,
    required this.statusText,
    required this.onMenuSelected,
  });

  final String selectedModelId;
  final List<({String id, String name})> models;
  final ValueChanged<String> onModelSelected;
  final String statusText;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _DesktopChatDesign.mainBg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'AI Hub',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          ...models.map((m) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _DesktopModelPill(
              label: m.name,
              isSelected: m.id == selectedModelId,
              onTap: () => onModelSelected(m.id),
            ),
          )),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _DesktopChatDesign.positiveGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _DesktopChatDesign.positiveGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white70, size: 24),
            offset: const Offset(0, 40),
            color: _DesktopChatDesign.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: onMenuSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'history', child: Row(children: [Icon(Icons.history, size: 20, color: Colors.white70), SizedBox(width: 12), Text('Chat History', style: TextStyle(color: Colors.white))])),
              const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.download, size: 20, color: Colors.white70), SizedBox(width: 12), Text('Export Data', style: TextStyle(color: Colors.white))])),
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, size: 20, color: Colors.white70), SizedBox(width: 12), Text('Settings', style: TextStyle(color: Colors.white))])),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 12), Text('Clear History', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopModelPill extends StatelessWidget {
  const _DesktopModelPill({required this.label, required this.isSelected, required this.onTap});

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
          color: isSelected ? _DesktopChatDesign.accentBlue : _DesktopChatDesign.cardBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _DesktopPastConversations extends StatelessWidget {
  const _DesktopPastConversations({
    required this.conversationsByService,
    required this.currentConversationId,
    required this.onSelectConversation,
    required this.onNewChat,
  });

  final Map<String, List<Conversation>> conversationsByService;
  final String? currentConversationId;
  final ValueChanged<Conversation> onSelectConversation;
  final VoidCallback onNewChat;

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) {
      return 'Today, ${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } else if (d == yesterday) {
      return 'Yesterday, ${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } else {
      return 'Oct ${dt.day}, ${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = conversationsByService.values
        .expand((e) => e)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      width: 280,
      color: _DesktopChatDesign.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              'PAST CONVERSATIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search history...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                filled: true,
                fillColor: _DesktopChatDesign.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: all.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No conversations yet',
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: all.take(10).map((c) {
                      final isSelected = c.id == currentConversationId;
                      final title = c.title.length > 25 ? '${c.title.substring(0, 25)}...' : c.title;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelectConversation(c),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Colors.white : Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatTimestamp(c.createdAt),
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New Chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: _DesktopChatDesign.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
