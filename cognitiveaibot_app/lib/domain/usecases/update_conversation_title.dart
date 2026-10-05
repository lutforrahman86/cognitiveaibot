import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

class UpdateConversationTitle implements UseCase<Conversation, UpdateConversationTitleParams> {
  UpdateConversationTitle(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<Conversation>> call(UpdateConversationTitleParams params) async {
    final title = params.title.trim();
    if (title.isEmpty) return const FailureResult(ServerFailure('Enter a title.'));
    return _repository.updateConversationTitle(params.conversationId, title);
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
