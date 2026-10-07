import '../error/failures.dart';

/// Result type - either success with data or failure
typedef FutureResult<T> = Future<Result<T>>;

sealed class Result<T> {
  const Result();

  /// Runs [body], turning any thrown data-layer exception into a [FailureResult].
  static Future<Result<T>> guard<T>(Future<T> Function() body) async {
    try {
      return Success(await body());
    } catch (e) {
      return FailureResult(Failure.from(e));
    }
  }
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}

/// Base use case interface
/// [T] is the return type
/// [Params] is the parameters (use [NoParams] when none needed)
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// Use when the use case has no parameters
class NoParams {
  const NoParams();
}
