class SimplefinException implements Exception {
  SimplefinException(this.message, {this.cause});

  final String message;
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

class SimplefinInvalidSetupToken extends SimplefinException {
  SimplefinInvalidSetupToken(super.message, {super.cause});
}

class SimplefinDataFormatException extends SimplefinException {
  SimplefinDataFormatException(super.message, {super.cause});
}

class SimplefinApiException extends SimplefinException {
  SimplefinApiException({
    required this.uri,
    required this.statusCode,
    String? message,
    this.responseBody,
  }) : super(message ?? 'SimpleFIN API error (${statusCode ?? 'unknown'})');

  final Uri uri;
  final int? statusCode;
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
