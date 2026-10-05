import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../providers/account_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_session_provider.dart';
import '../widgets/ai_hub_chat_input.dart';
import '../widgets/ai_hub_message_bubble.dart';
import '../widgets/chat_history_drawer.dart';
import '../widgets/conversation_actions.dart';
import '../widgets/model_picker.dart';
import '../widgets/plan_status_text.dart';
import '../widgets/upgrade.dart';

/// Desktop chat design tokens
class _DesktopChatDesign {
  _DesktopChatDesign._();
  static const sidebarBg = Color(0xFF181818);
  static const mainBg = Color(0xFF0D0D0D);
}

/// The chat: replies stream from the backend, with Stop, Regenerate and Copy.
///
/// On mobile it is pushed as its own page (with [conversation] to open an
/// existing chat). On desktop it is embedded in the shell, with the chat
/// list on the right.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.conversation,
    this.useDesktopLayout = false,
  });

  final Conversation? conversation;
  final bool useDesktopLayout;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.useDesktopLayout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final session = ref.read(chatSessionProvider.notifier);
        final c = widget.conversation;
        if (c != null) {
          session.open(
            c,
            models: ref.read(modelsProvider).valueOrNull ?? const [],
          );
        } else {
          session.startNew();
        }
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  AiModel? _selectedModel(List<AiModel> models, ChatSessionState session) {
    for (final m in models) {
      if (m.id == session.modelId && m.available) return m;
    }
    return defaultModel(models, ref.read(preferredModelIdProvider));
  }

  Future<void> _send(String text) async {
    final models = ref.read(modelsProvider).valueOrNull ?? const [];
    final model = _selectedModel(models, ref.read(chatSessionProvider));
    if (model == null) {
      _input.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No model is available right now. Try again later.'),
        ),
      );
      return;
    }
    final refused = await ref
        .read(chatSessionProvider.notifier)
        .send(text, model);
    // Nothing was saved: give the text back so it can be sent again.
    if (refused != null && mounted && _input.text.isEmpty) _input.text = text;
  }

  void _regenerate() {
    final models = ref.read(modelsProvider).valueOrNull ?? const [];
    final model = _selectedModel(models, ref.read(chatSessionProvider));
    if (model != null) ref.read(chatSessionProvider.notifier).regenerate(model);
  }

  void _openConversation(Conversation c) {
    ref
        .read(chatSessionProvider.notifier)
        .open(c, models: ref.read(modelsProvider).valueOrNull ?? const []);
  }

  void _newChat() {
    ref.read(chatSessionProvider.notifier).startNew();
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return widget.useDesktopLayout
        ? _buildDesktopLayout(context)
        : _buildMobileLayout(context);
  }

  Widget _modelPicker(List<AiModel> models, ChatSessionState session) {
    final modelsState = ref.watch(modelsProvider);
    if (modelsState.hasError && models.isEmpty) {
      return TextButton.icon(
        onPressed: () => ref.invalidate(modelsProvider),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Couldn’t load models. Retry'),
      );
    }
    return ModelPickerButton(
      models: models,
      selected: _selectedModel(models, session),
      enabled: !session.streaming,
      onSelected: ref.read(chatSessionProvider.notifier).selectModel,
    );
  }

  Widget _buildBody(BuildContext context, {required bool desktop}) {
    final session = ref.watch(chatSessionProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const UserSettings();
    final models = ref.watch(modelsProvider).valueOrNull ?? const <AiModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildMessages(session, settings, desktop: desktop)),
        if (session.error != null) _ErrorBanner(session: session),
        AIHubChatInput(
          controller: _input,
          onSend: _send,
          onStop: ref.read(chatSessionProvider.notifier).stop,
          streaming: session.streaming,
          enabled: !session.loading && models.any((m) => m.available),
          enterToSend: settings.enterToSend,
          hintText: session.streaming
              ? 'Replying… press Stop to end the reply'
              : 'Type a message...',
        ),
      ],
    );
  }

  Widget _buildMessages(
    ChatSessionState session,
    UserSettings settings, {
    required bool desktop,
  }) {
    if (session.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (session.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                session.loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              TextButton(
                onPressed: () => _openConversation(session.conversation!),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final visible = session.messages
        .where((m) => m.role != MessageRole.system)
        .toList();
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 72,
                color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 20),
              const Text(
                'Start a conversation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: CognitiveAIBotTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a model above and type your message below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: CognitiveAIBotTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const CreditsText(
                style: TextStyle(
                  fontSize: 13,
                  color: CognitiveAIBotTheme.textSecondary,
                ),
                suffix: ' credits available',
              ),
            ],
          ),
        ),
      );
    }
    final lastAssistant = visible.lastIndexWhere(
      (m) => m.role == MessageRole.assistant,
    );
    final canRegenerate =
        !session.streaming && lastAssistant == visible.length - 1;
    // Reversed, so the newest message stays at the bottom while text streams in.
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 24 : 16,
        vertical: 16,
      ),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final index = visible.length - 1 - i;
        final msg = visible[index];
        final bubble = AIHubMessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          streaming: msg.id == session.streamingMessageId,
          fontSize: settings.messageFontSize,
          showTimestamp: settings.showTimestamps,
          onRegenerate: canRegenerate && index == lastAssistant
              ? _regenerate
              : null,
        );
        return desktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: bubble,
                ),
              )
            : bubble;
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final session = ref.watch(chatSessionProvider);
    final models = ref.watch(modelsProvider).valueOrNull ?? const <AiModel>[];
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        foregroundColor: CognitiveAIBotTheme.textPrimary,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          session.conversation?.title ?? 'New chat',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: session.streaming ? null : _newChat,
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Chat history',
              icon: const Icon(Icons.history),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: ChatHistoryDrawer(
        currentConversationId: session.conversation?.id,
        onSelectConversation: _openConversation,
        onNewChat: _newChat,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _modelPicker(models, session),
            ),
          ),
          Expanded(child: _buildBody(context, desktop: false)),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final session = ref.watch(chatSessionProvider);
    final models = ref.watch(modelsProvider).valueOrNull ?? const <AiModel>[];
    final conversation = session.conversation;
    return Scaffold(
      backgroundColor: _DesktopChatDesign.mainBg,
      body: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          conversation?.title ?? 'New chat',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (conversation != null)
                        ConversationMenu(
                          conversation: conversation,
                          iconColor: Colors.white70,
                        ),
                      const SizedBox(width: 16),
                      _modelPicker(models, session),
                      const Spacer(),
                      const CreditsText(
                        style: TextStyle(
                          fontSize: 13,
                          color: CognitiveAIBotTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(context, desktop: true)),
              ],
            ),
          ),
          // A Material (not a coloured box) so the list tiles' highlights show.
          Material(
            color: _DesktopChatDesign.sidebarBg,
            child: SizedBox(
              width: 290,
              child: ConversationListPanel(
                title: 'Past conversations',
                currentConversationId: conversation?.id,
                onSelectConversation: _openConversation,
                onNewChat: _newChat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.session});

  final ChatSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both are fixed by buying a plan or credits.
    final needsPlan =
        session.errorCode == 'INSUFFICIENT_CREDITS' ||
        session.errorCode == 'MODEL_REQUIRES_PLAN';
    return Container(
      key: const Key('chat-error'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3D1E20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFDA3633).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFFF7B72)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              session.error!,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
          if (needsPlan)
            TextButton(
              onPressed: () => openUpgrade(context),
              child: Text(
                session.errorCode == 'MODEL_REQUIRES_PLAN'
                    ? 'View plans'
                    : 'Get credits',
              ),
            ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 18, color: Colors.white70),
            onPressed: ref.read(chatSessionProvider.notifier).dismissError,
          ),
        ],
      ),
    );
  }
}
