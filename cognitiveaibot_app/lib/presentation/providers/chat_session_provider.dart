import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/usecases/usecase.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/completion_event.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/usecases/create_conversation.dart';
import '../../domain/usecases/delete_conversation.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/stream_chat_reply.dart';
import 'account_providers.dart';
import 'auth_provider.dart';
import 'chat_providers.dart';
import 'providers.dart';

class ChatSessionState {
  const ChatSessionState({
    this.conversation,
    this.messages = const [],
    this.loading = false,
    this.loadError,
    this.streamingMessageId,
    this.modelId,
    this.error,
    this.errorCode,
  });

  /// Null for a new chat that hasn't been sent yet.
  final Conversation? conversation;
  final List<ChatMessage> messages;
  final bool loading;
  final String? loadError;

  /// The assistant message that is still arriving, while a reply streams.
  final String? streamingMessageId;

  /// The model the next message goes to. Null: the default model.
  final String? modelId;

  /// Why the last reply failed or was refused.
  final String? error;
  final String? errorCode;

  bool get streaming => streamingMessageId != null;

  ChatSessionState copyWith({
    Conversation? conversation,
    bool clearConversation = false,
    List<ChatMessage>? messages,
    bool? loading,
    String? loadError,
    bool clearLoadError = false,
    String? streamingMessageId,
    bool clearStreaming = false,
    String? modelId,
    String? error,
    String? errorCode,
    bool clearError = false,
  }) =>
      ChatSessionState(
        conversation: clearConversation ? null : (conversation ?? this.conversation),
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        loadError: clearLoadError ? null : (loadError ?? this.loadError),
        streamingMessageId: clearStreaming ? null : (streamingMessageId ?? this.streamingMessageId),
        modelId: modelId ?? this.modelId,
        error: clearError ? null : (error ?? this.error),
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
      );
}

/// One open chat: its messages, the streaming reply, Stop and Regenerate.
class ChatSessionController extends StateNotifier<ChatSessionState> {
  ChatSessionController(this._ref) : super(const ChatSessionState());

  final Ref _ref;
  Completer<void>? _stop;
  int _localIds = 0;
  int _loadToken = 0;

  String _localId(String kind) => 'local-$kind-${++_localIds}';

  void startNew() {
    stop();
    _loadToken++;
    state = ChatSessionState(modelId: state.modelId);
  }

  Future<void> open(Conversation conversation, {List<AiModel> models = const []}) async {
    stop();
    final token = ++_loadToken;
    final chatModel = models.where((m) => m.id == conversation.modelId && m.available).firstOrNull;
    state = ChatSessionState(
      conversation: conversation,
      loading: true,
      modelId: chatModel?.id ?? state.modelId,
    );
    final result = await _ref
        .read(getChatMessagesProvider)
        .call(GetChatMessagesParams(conversationId: conversation.id));
    if (!mounted || token != _loadToken) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(messages: data, loading: false),
      FailureResult(:final failure) =>
        state.copyWith(loading: false, loadError: failure.message ?? 'Couldn’t load this chat.'),
    };
  }

  void selectModel(AiModel model) {
    if (!model.available || state.streaming) return;
    state = state.copyWith(modelId: model.id);
  }

  void renamed(Conversation conversation) {
    if (state.conversation?.id == conversation.id) state = state.copyWith(conversation: conversation);
  }

  void dismissError() => state = state.copyWith(clearError: true);

  /// Closes the connection. The server keeps and charges only what was
  /// produced; the partial reply stays on screen.
  void stop() {
    final stop = _stop;
    if (stop != null && !stop.isCompleted) stop.complete();
  }

  /// The user message that Regenerate would send again.
  ChatMessage? get lastUserMessage {
    for (final m in state.messages.reversed) {
      if (m.role == MessageRole.user) return m;
    }
    return null;
  }

  /// Has the server answer the last user message again
  /// (`{regenerate: true}`); the old replies after it are replaced.
  Future<String?> regenerate(AiModel model) async {
    final conversation = state.conversation;
    final last = lastUserMessage;
    if (conversation == null || last == null || state.streaming) return null;
    if (!model.available) return '${model.name} isn’t available right now. Choose another model.';
    final keep = state.messages.sublist(0, state.messages.indexOf(last) + 1);
    final replaced = state.messages.sublist(keep.length);
    return _reply(
      conversation: conversation,
      model: model,
      base: keep,
      regenerate: true,
      // Refused: nothing changed on the server, so the old replies come back.
      restoreOnRefusal: replaced,
    );
  }

  /// Sends [text] to [model] and streams the reply into [ChatSessionState].
  /// Returns an error message when the server refused the message before
  /// answering (nothing was saved), so the caller can give the text back.
  Future<String?> send(String text, AiModel model) async {
    final content = text.trim();
    if (content.isEmpty || state.streaming) return null;
    if (!model.available) return '${model.name} isn’t available right now. Choose another model.';

    _loadToken++;
    Conversation? created;
    var conversation = state.conversation;
    if (conversation == null) {
      final result = await _ref.read(createConversationProvider).call(CreateConversationParams(modelId: model.id));
      if (!mounted) return null;
      switch (result) {
        case Success(:final data):
          conversation = created = data;
        case FailureResult(:final failure):
          final message = failure.message ?? 'Couldn’t start a chat.';
          state = state.copyWith(error: message, errorCode: failure.code);
          return message;
      }
    }
    return _reply(conversation: conversation, model: model, base: state.messages, content: content, created: created);
  }

  Future<String?> _reply({
    required Conversation conversation,
    required AiModel model,
    required List<ChatMessage> base,
    String? content,
    bool regenerate = false,
    Conversation? created,
    List<ChatMessage> restoreOnRefusal = const [],
  }) async {
    _loadToken++;
    final userId = _localId('user');
    final replyId = _localId('reply');
    final now = DateTime.now();
    var reply = ChatMessage(
      id: replyId,
      content: '',
      role: MessageRole.assistant,
      timestamp: now,
      modelId: model.id,
      modelName: model.name,
    );
    var replyKey = replyId;
    state = state.copyWith(
      conversation: conversation,
      modelId: model.id,
      messages: [
        ...base,
        if (!regenerate) ChatMessage(id: userId, content: content!, role: MessageRole.user, timestamp: now),
        reply,
      ],
      streamingMessageId: replyId,
      clearError: true,
    );

    final stop = _stop = Completer<void>();
    var started = false;
    CompletionFailed? refused;
    final buffer = StringBuffer();

    void replace(String id, ChatMessage message) {
      state = state.copyWith(messages: [for (final m in state.messages) m.id == id ? message : m]);
    }

    await for (final event in _ref.read(streamChatReplyProvider).call(StreamChatReplyParams(
          conversationId: conversation.id,
          content: content,
          modelId: model.id,
          regenerate: regenerate,
          cancel: stop.future,
        ))) {
      if (!mounted) return null;
      switch (event) {
        case CompletionStarted(:final userMessage, :final chatTitle):
          started = true;
          if (!regenerate) replace(userId, userMessage);
          if (chatTitle != null && chatTitle.isNotEmpty) {
            state = state.copyWith(conversation: state.conversation?.copyWith(title: chatTitle));
          }
        case CompletionDelta(:final text):
          buffer.write(text);
          reply = reply.copyWith(content: buffer.toString());
          replace(replyKey, reply);
        case CompletionDone(:final message):
          if (message != null) {
            reply = message.copyWith(modelName: message.modelName ?? model.name);
            replace(replyKey, reply);
            replyKey = reply.id;
          }
        case CompletionFailed(refused: true):
          refused = event;
        case CompletionFailed(:final partial):
          if (partial != null) {
            reply = partial.copyWith(modelName: partial.modelName ?? model.name);
            replace(replyKey, reply);
            replyKey = reply.id;
          }
          state = state.copyWith(error: event.message, errorCode: event.code);
      }
    }
    if (!mounted) return null;
    if (identical(_stop, stop)) _stop = null;

    var messages = state.messages;
    if (!started) {
      // Nothing reached the server: take the message back out (or put the
      // old replies back), and drop a chat that was created only for it.
      messages = [...messages.where((m) => m.id != userId && m.id != replyKey), ...restoreOnRefusal];
      if (created != null) {
        _ref.read(deleteConversationProvider).call(DeleteConversationParams(conversationId: created.id));
      }
    } else if (reply.content.isEmpty) {
      messages = messages.where((m) => m.id != replyKey).toList();
    }
    state = ChatSessionState(
      conversation: !started && created != null ? null : state.conversation,
      messages: messages,
      modelId: state.modelId,
      error: refused?.message ?? state.error,
      errorCode: refused?.code ?? state.errorCode,
    );

    if (started) {
      _ref.invalidate(conversationsProvider);
      _ref.invalidate(billingProvider);
      _ref.invalidate(usageDashboardProvider);
    }
    return refused?.message;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// The open chat. Kept while the app runs (the desktop shell embeds the chat,
/// and History opens chats into it); reset when the signed-in user changes.
final chatSessionProvider = StateNotifierProvider<ChatSessionController, ChatSessionState>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ChatSessionController(ref);
});
