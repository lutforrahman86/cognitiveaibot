/// The server answered with an error (or something that isn't valid JSON).
class ServerException implements Exception {
  const ServerException([this.message, this.code, this.statusCode]);

  final String? message;

  /// The backend's machine-readable error code, e.g. `INSUFFICIENT_CREDITS`.
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ServerException($statusCode, $code, $message)';
}

/// The session is missing, invalid or expired (HTTP 401 on a signed-in call).
class UnauthorizedException extends ServerException {
  const UnauthorizedException([String? message, String? code])
      : super(message ?? 'Your session has ended. Sign in again.', code ?? 'UNAUTHORIZED', 401);
}

/// The server couldn't be reached.
class NetworkException implements Exception {
  const NetworkException([this.message]);

  final String? message;

  @override
  String toString() => 'NetworkException($message)';
}

/// Exception for cache/storage operations
class CacheException implements Exception {
  const CacheException([this.message]);

  final String? message;
}
