import '../entities/completion_event.dart';
import '../repositories/chat_repository.dart';

/// Sends a message and streams the model's reply, or (with `regenerate`)
/// has the server answer the chat's last user message again.
class StreamChatReply {
  StreamChatReply(this._repository);

  final ChatRepository _repository;

  Stream<CompletionEvent> call(StreamChatReplyParams params) {
    final content = params.content?.trim() ?? '';
    if (!params.regenerate && content.isEmpty) {
      return Stream.value(const CompletionFailed(message: 'Message is empty.', code: 'EMPTY_MESSAGE', refused: true));
    }
    return _repository.streamReply(
      conversationId: params.conversationId,
      content: params.regenerate ? null : content,
      modelId: params.modelId,
      regenerate: params.regenerate,
      cancel: params.cancel,
    );
  }
}

class StreamChatReplyParams {
  const StreamChatReplyParams({
    required this.conversationId,
    this.content,
    required this.modelId,
    this.regenerate = false,
    this.cancel,
  });

  final String conversationId;
  final String? content;
  final String modelId;
  final bool regenerate;
  final Future<void>? cancel;
}
