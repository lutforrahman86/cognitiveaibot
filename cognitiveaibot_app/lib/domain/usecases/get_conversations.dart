import '../../core/usecases/usecase.dart';
import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

class GetConversations implements UseCase<List<Conversation>, GetConversationsParams> {
  GetConversations(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<List<Conversation>>> call(GetConversationsParams params) {
    final q = params.search?.trim();
    return _repository.getConversations(search: q == null || q.isEmpty ? null : q);
  }
}

class GetConversationsParams {
  const GetConversationsParams({this.search});

  final String? search;
}
