/// Base class for all failures in the application
abstract class Failure {
  const Failure([this.message]);

  final String? message;
}

/// Generic server failure
class ServerFailure extends Failure {
  const ServerFailure([super.message]);
}

/// Network connectivity failure
class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);
}

/// Cache/storage failure
class CacheFailure extends Failure {
  const CacheFailure([super.message]);
}
