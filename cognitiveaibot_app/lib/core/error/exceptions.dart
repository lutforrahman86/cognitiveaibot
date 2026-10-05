/// Base class for exceptions
class ServerException implements Exception {
  const ServerException([this.message]);

  final String? message;
}

/// Exception when no network connectivity
class NetworkException implements Exception {
  const NetworkException([this.message]);

  final String? message;
}

/// Exception for cache/storage operations
class CacheException implements Exception {
  const CacheException([this.message]);

  final String? message;
}
