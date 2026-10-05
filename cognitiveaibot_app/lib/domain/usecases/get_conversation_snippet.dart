import '../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class GetConversationSnippet implements UseCase<String?, GetConversationSnippetParams> {
  GetConversationSnippet(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<String?>> call(GetConversationSnippetParams params) {
    return _repository.getLastMessageSnippet(params.conversationId);
  }
}

class GetConversationSnippetParams {
  const GetConversationSnippetParams({required this.conversationId});

  final String conversationId;
}
