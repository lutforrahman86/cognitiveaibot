import '../../core/usecases/usecase.dart';
import '../entities/ai_model.dart';
import '../repositories/chat_repository.dart';

class GetModels implements UseCase<List<AiModel>, NoParams> {
  GetModels(this._repository);

  final ChatRepository _repository;

  @override
  Future<Result<List<AiModel>>> call(NoParams params) => _repository.getModels();
}
