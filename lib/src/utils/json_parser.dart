import 'dart:convert';

import '../exceptions.dart';

/// Parses a JSON string into a typed object with proper error handling.
///
/// This utility handles the common pattern of parsing JSON responses from
/// SimpleFIN API endpoints, including validation and error wrapping.

/// Decodes a JSON string into a [Map<String, dynamic>].
///
/// Throws [SimplefinApiException] if the response is not valid JSON or
/// if the decoded value is not a JSON object.
///
/// Example:
/// ```dart
/// final response = await httpClient.get(uri);
/// final jsonBody = parseJsonObject(
///   response.body,
///   uri: uri,
///   statusCode: response.statusCode,
///   errorContext: 'accounts response',
/// );
/// ```
Map<String, dynamic> parseJsonObject(
  String jsonString, {
  required Uri uri,
  required int statusCode,
  required String errorContext,
}) {
  try {
    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  } on FormatException catch (error) {
    throw SimplefinApiException(
      uri: uri,
      statusCode: statusCode,
      responseBody: jsonString,
      message: '$errorContext is not valid JSON: ${error.message}',
    );
  }
}
