/// Base type for all errors thrown by the SimpleFIN Dart client.
class SimplefinException implements Exception {
  /// Creates a new exception with an optional [cause] for context.
  SimplefinException(this.message, {this.cause});

  /// Human-readable description of the failure.
  final String message;

  /// Underlying error that triggered this exception.
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer('SimplefinException: $message');
    if (cause != null) {
      buffer.write(' (cause: $cause)');
    }
    return buffer.toString();
  }
}

/// Thrown when a supplied setup token cannot be parsed or validated.
class SimplefinInvalidSetupToken extends SimplefinException {
  /// Creates an error describing why the setup token was rejected.
  SimplefinInvalidSetupToken(super.message, {super.cause});
}

/// Thrown when SimpleFIN data does not match the documented format.
class SimplefinDataFormatException extends SimplefinException {
  /// Creates an error for malformed SimpleFIN data payloads.
  SimplefinDataFormatException(super.message, {super.cause});
}

/// Raised when the SimpleFIN bridge or access endpoint returns an error.
class SimplefinApiException extends SimplefinException {
  /// Creates an exception describing a non-success API response.
  SimplefinApiException({
    required this.uri,
    required this.statusCode,
    String? message,
    this.responseBody,
  }) : super(message ?? 'SimpleFIN API error (${statusCode ?? 'unknown'})');

  /// Endpoint that returned the error.
  final Uri uri;

  /// HTTP status code reported by the server.
  final int? statusCode;

  /// Raw response body provided by the server, when available.
  final String? responseBody;

  @override
  String toString() {
    final buffer = StringBuffer(
      'SimplefinApiException(status: $statusCode, uri: $uri',
    );
    if (responseBody != null && responseBody!.isNotEmpty) {
      buffer.write(', body: $responseBody');
    }
    buffer.write(')');
    return buffer.toString();
  }
}
