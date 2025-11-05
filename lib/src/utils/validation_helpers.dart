import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../exceptions.dart';
import 'time_utils.dart';

/// Parses and validates a URI string, ensuring it has both a scheme and host.
///
/// Throws [SimplefinDataFormatException] if the URI is invalid or missing
/// required components.
Uri parseAndValidateUri(String value, String context) {
  late final Uri uri;
  try {
    uri = Uri.parse(value);
  } on FormatException catch (error) {
    throw SimplefinDataFormatException(
      '$context is not a valid URI.',
      cause: error,
    );
  }

  if (!uri.hasScheme || uri.host.isEmpty) {
    throw SimplefinDataFormatException(
      '$context must include a scheme and host.',
    );
  }

  return uri;
}

/// Extension methods for string validation.
extension StringValidation on String {
  /// Returns the trimmed string if non-empty, otherwise throws an exception.
  ///
  /// Throws [SimplefinDataFormatException] if the trimmed string is empty.
  String requireNonEmpty(String fieldName) {
    final trimmed = trim();
    if (trimmed.isEmpty) {
      throw SimplefinDataFormatException('$fieldName must not be empty.');
    }
    return trimmed;
  }

  /// Returns null if the trimmed string is empty, otherwise returns the
  /// trimmed string.
  String? maybeEmptyToNull() {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Validates that a JSON value is of the expected type [T].
///
/// Throws [SimplefinDataFormatException] if the value is not of type [T].
T expectType<T>(dynamic value, String fieldName) {
  if (value is! T) {
    throw SimplefinDataFormatException(
      'Expected "$fieldName" to be $T.',
    );
  }
  return value;
}

/// Extracts a string value from a JSON map by key.
///
/// Throws [SimplefinDataFormatException] if the value is not a string.
String expectString(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw SimplefinDataFormatException('Expected "$key" to be a string.');
}

/// Parses a value into a [Decimal], accepting numbers or string
/// representations.
///
/// Throws [SimplefinDataFormatException] if the value cannot be parsed or is
/// missing when required.
Decimal parseDecimal(Object? value, String fieldName) {
  if (value == null) {
    throw SimplefinDataFormatException('Field "$fieldName" is required.');
  }
  if (value is Decimal) {
    return value;
  }
  if (value is num) {
    return Decimal.parse(value.toString());
  }
  if (value is String) {
    try {
      return Decimal.parse(value);
    } on FormatException catch (error) {
      throw SimplefinDataFormatException(
        '"$fieldName" must be a decimal string.',
        cause: error,
      );
    }
  }
  throw SimplefinDataFormatException(
    '"$fieldName" must be provided as a string or number.',
  );
}

/// Parses a Unix timestamp (epoch seconds) into a [DateTime].
///
/// Throws [SimplefinDataFormatException] if the value cannot be parsed.
DateTime parseDateTime(Object? value, String fieldName) {
  final seconds = parseEpochSeconds(value, fieldName);
  return fromEpochSeconds(seconds);
}

/// Parses a value into epoch seconds (Unix timestamp).
///
/// Accepts integers, numbers, or string representations of integers.
///
/// Throws [SimplefinDataFormatException] if the value cannot be parsed.
int parseEpochSeconds(Object? value, String fieldName) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    if (value.isFinite) {
      return value.floor();
    }
  }
  if (value is String) {
    try {
      return int.parse(value);
    } on FormatException catch (error) {
      throw SimplefinDataFormatException(
        '"$fieldName" must be an integer Unix timestamp.',
        cause: error,
      );
    }
  }
  throw SimplefinDataFormatException(
    '"$fieldName" must be provided as an integer Unix timestamp.',
  );
}

/// Decodes a Base64 or Base64URL encoded string.
///
/// First attempts standard Base64 decoding. If that fails, falls back to
/// Base64URL decoding. Whitespace is stripped before decoding.
///
/// Throws [SimplefinInvalidSetupToken] if both decoding attempts fail.
List<int> decodeBase64WithFallback(String encoded) {
  final normalized = encoded.replaceAll(
    RegExp(r'\s+'),
    '',
  ); // Defensive whitespace removal.

  try {
    return base64.decode(base64.normalize(normalized));
  } on FormatException {
    try {
      return base64Url.decode(base64Url.normalize(normalized));
    } on FormatException catch (error) {
      throw SimplefinInvalidSetupToken(
        'Token is not valid Base64.',
        cause: error,
      );
    }
  }
}
