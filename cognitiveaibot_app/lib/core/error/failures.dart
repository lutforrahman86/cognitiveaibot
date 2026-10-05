import 'exceptions.dart';

/// Base class for all failures in the application
abstract class Failure {
  const Failure([this.message, this.code]);

  final String? message;

  /// The backend's error code when there is one, e.g. `INSUFFICIENT_CREDITS`.
  final String? code;

  /// Maps a data-layer exception to a failure. Anything unexpected becomes a
  /// generic [ServerFailure] rather than escaping to the UI.
  static Failure from(Object error) => switch (error) {
        UnauthorizedException(:final message) => UnauthorizedFailure(message),
        ServerException(:final message, :final code) => ServerFailure(message, code),
        NetworkException(:final message) => NetworkFailure(message),
        CacheException(:final message) => CacheFailure(message),
        _ => const ServerFailure('Something went wrong. Try again.'),
      };
}

/// Generic server failure
class ServerFailure extends Failure {
  const ServerFailure([super.message, super.code]);
}

/// The session ended; the app returns to sign-in.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String? message]) : super(message, 'UNAUTHORIZED');
}

/// Network connectivity failure
class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);
}

/// Cache/storage failure
class CacheFailure extends Failure {
  const CacheFailure([super.message]);
}
