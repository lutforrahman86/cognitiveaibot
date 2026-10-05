import '../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class DeleteConversation implements UseCase<void, DeleteConversationParams> {
  DeleteConversation(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<void>> call(DeleteConversationParams params) {
    return _repository.deleteConversation(params.conversationId);
  }
}

class DeleteConversationParams {
  const DeleteConversationParams({required this.conversationId});

  final String conversationId;
}
