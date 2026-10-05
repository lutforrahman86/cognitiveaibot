import '../../core/usecases/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class SendChatMessage implements UseCase<ChatMessage, SendChatMessageParams> {
  SendChatMessage(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<ChatMessage>> call(SendChatMessageParams params) {
    return _repository.sendMessage(
      conversationId: params.conversationId,
      content: params.content,
      serviceId: params.serviceId,
      modelId: params.modelId,
    );
  }
}

class SendChatMessageParams {
  const SendChatMessageParams({
    required this.conversationId,
    required this.content,
    this.serviceId,
    this.modelId,
  });

  final String conversationId;
  final String content;
  final String? serviceId;
  final String? modelId;
}
