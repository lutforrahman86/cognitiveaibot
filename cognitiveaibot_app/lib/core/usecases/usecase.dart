import '../error/failures.dart';

/// Result type - either success with data or failure
typedef FutureResult<T> = Future<Result<T>>;

sealed class Result<T> {
  const Result();
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
/// [Type] is the return type
/// [Params] is the parameters (use [NoParams] when none needed)
abstract interface class UseCase<Type, Params> {
  Future<Result<Type>> call(Params params);
}

/// Use when the use case has no parameters
class NoParams {
  const NoParams();
}
