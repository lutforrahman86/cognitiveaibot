import '../../core/usecases/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class GetChatMessages implements UseCase<List<ChatMessage>, GetChatMessagesParams> {
  GetChatMessages(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<List<ChatMessage>>> call(GetChatMessagesParams params) {
    return _repository.getMessages(params.conversationId);
  }
}

class GetChatMessagesParams {
  const GetChatMessagesParams({required this.conversationId});

  final String conversationId;
}
