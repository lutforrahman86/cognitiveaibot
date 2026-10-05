import '../../core/usecases/usecase.dart';
import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

class CreateConversation implements UseCase<Conversation, CreateConversationParams> {
  CreateConversation(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<Conversation>> call(CreateConversationParams params) {
    return _repository.createConversation(modelId: params.modelId);
  }
}

class CreateConversationParams {
  const CreateConversationParams({this.modelId});

  final String? modelId;
}
