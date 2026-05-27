class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String? message])
    : super(message ?? 'Unauthorized', statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([String? message])
    : super(message ?? 'Forbidden', statusCode: 403);
}

class NotFoundException extends ApiException {
  NotFoundException([String? message])
    : super(message ?? 'Not found', statusCode: 404);
}

class ValidationException extends ApiException {
  ValidationException([String? message])
    : super(message ?? 'Validation failed', statusCode: 400);
}

class ServerException extends ApiException {
  ServerException([String? message])
    : super(message ?? 'Server error', statusCode: 500);
}

String userFacingMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
