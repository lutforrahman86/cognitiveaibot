import '../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class UpdateConversationTitle implements UseCase<void, UpdateConversationTitleParams> {
  UpdateConversationTitle(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<void>> call(UpdateConversationTitleParams params) {
    return _repository.updateConversationTitle(
      params.conversationId,
      params.title,
    );
  }
}

class UpdateConversationTitleParams {
  const UpdateConversationTitleParams({
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;
}
