import '../../core/usecases/usecase.dart';
import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

class GetConversations implements UseCase<Map<String, List<Conversation>>, NoParams> {
  GetConversations(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<Map<String, List<Conversation>>>> call(NoParams params) {
    return _repository.getConversationsGroupedByService();
  }
}
