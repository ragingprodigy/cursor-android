sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'API key rejected']);
}

class RateLimitedException extends AppException {
  const RateLimitedException([super.message = 'Rate limited']);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network unavailable']);
}

class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode, this.code});
  final int? statusCode;
  final String? code;
}
