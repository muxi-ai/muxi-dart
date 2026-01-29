/// Base MUXI exception
class MuxiException implements Exception {
  final String code;
  final String message;
  final int statusCode;
  final Map<String, dynamic>? details;

  MuxiException(this.code, this.message, this.statusCode, [this.details]);

  @override
  String toString() => code.isNotEmpty ? '$code: $message' : message;
}

class AuthenticationException extends MuxiException {
  AuthenticationException(String code, String message, int statusCode, [Map<String, dynamic>? details])
      : super(code, message, statusCode, details);
}

class AuthorizationException extends MuxiException {
  AuthorizationException(String code, String message, int statusCode, [Map<String, dynamic>? details])
      : super(code, message, statusCode, details);
}

class NotFoundException extends MuxiException {
  NotFoundException(String code, String message, int statusCode, [Map<String, dynamic>? details])
      : super(code, message, statusCode, details);
}

class ConflictException extends MuxiException {
  ConflictException(String code, String message, int statusCode, [Map<String, dynamic>? details])
      : super(code, message, statusCode, details);
}

class ValidationException extends MuxiException {
  ValidationException(String code, String message, int statusCode, [Map<String, dynamic>? details])
      : super(code, message, statusCode, details);
}

class RateLimitException extends MuxiException {
  final int? retryAfter;

  RateLimitException(String message, int statusCode, {this.retryAfter, Map<String, dynamic>? details})
      : super('RATE_LIMITED', message, statusCode, details);
}

class ServerException extends MuxiException {
  ServerException(String code, String message, int statusCode, [Map<String, dynamic>? details])
      : super(code, message, statusCode, details);
}

class ConnectionException extends MuxiException {
  ConnectionException(String message) : super('CONNECTION_ERROR', message, 0);
}

MuxiException mapError(int status, String? code, String message, [Map<String, dynamic>? details, int? retryAfter]) {
  switch (status) {
    case 401:
      return AuthenticationException(code ?? 'UNAUTHORIZED', message, status, details);
    case 403:
      return AuthorizationException(code ?? 'FORBIDDEN', message, status, details);
    case 404:
      return NotFoundException(code ?? 'NOT_FOUND', message, status, details);
    case 409:
      return ConflictException(code ?? 'CONFLICT', message, status, details);
    case 422:
      return ValidationException(code ?? 'VALIDATION_ERROR', message, status, details);
    case 429:
      return RateLimitException(message.isEmpty ? 'Too Many Requests' : message, status, retryAfter: retryAfter, details: details);
    default:
      if (status >= 500 && status < 600) {
        return ServerException(code ?? 'SERVER_ERROR', message, status, details);
      }
      return MuxiException(code ?? 'ERROR', message, status, details);
  }
}
