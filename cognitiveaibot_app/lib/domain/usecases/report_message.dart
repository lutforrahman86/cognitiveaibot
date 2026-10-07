import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/content_report.dart';
import '../repositories/chat_repository.dart';

/// Reports a saved assistant reply (one with a server id).
class ReportMessage implements UseCase<void, ReportMessageParams> {
  ReportMessage(this._repository);

  final ChatRepository _repository;

  static const maxDetails = 2000;

  @override
  Future<Result<void>> call(ReportMessageParams params) async {
    if (params.messageId.isEmpty || params.messageId.startsWith('local-')) {
      return const FailureResult(ServerFailure('This reply isn’t saved yet, so it can’t be reported.'));
    }
    final details = params.details?.trim();
    return _repository.reportMessage(
      messageId: params.messageId,
      reason: params.reason,
      details: details == null || details.isEmpty
          ? null
          : (details.length > maxDetails ? details.substring(0, maxDetails) : details),
    );
  }
}

class ReportMessageParams {
  const ReportMessageParams({required this.messageId, required this.reason, this.details});

  final String messageId;
  final ReportReason reason;
  final String? details;
}
