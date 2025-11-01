import 'dart:convert';

import 'exceptions.dart';

/// Representation of the temporary setup token that a user creates via the
/// SimpleFIN Bridge UI. The token is Base64 encoded and resolves to the
/// one-time claim URL when decoded.
class SimplefinSetupToken {
  SimplefinSetupToken._(this.value, this.claimUri);

  /// Parses a Base64-encoded setup token string into a [SimplefinSetupToken].
  ///
  /// Throws [SimplefinInvalidSetupToken] when the token cannot be decoded or
  /// does not resolve to a valid claim URI.
  factory SimplefinSetupToken.parse(String token) {
    final cleaned = token.trim();
    if (cleaned.isEmpty) {
      throw SimplefinInvalidSetupToken('Setup token must not be empty.');
    }

    final decodedBytes = _decodeBase64(cleaned);
    final decoded = utf8.decode(decodedBytes);

    late final Uri claimUri;
    try {
      claimUri = Uri.parse(decoded);
    } on FormatException catch (error) {
      throw SimplefinInvalidSetupToken(
        'Decoded setup token is not a valid URI.',
        cause: error,
      );
    }

    if (!claimUri.hasScheme || claimUri.host.isEmpty) {
      throw SimplefinInvalidSetupToken(
        'Decoded setup token must include a scheme and host.',
      );
    }

    return SimplefinSetupToken._(cleaned, claimUri);
  }

  final String value;
  final Uri claimUri;

  static List<int> _decodeBase64(String token) {
    final normalized = token.replaceAll(
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
          'Setup token is not valid Base64.',
          cause: error,
        );
      }
    }
  }
}

/// Credentials extracted from a SimpleFIN Access URL. Access URLs embed the
/// HTTP basic auth username and password required to query account data.
class SimplefinAccessCredentials {
  SimplefinAccessCredentials._({
    required this.accessUrl,
    required this.baseUri,
    required this.username,
    required this.password,
  });

  factory SimplefinAccessCredentials.parse(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw SimplefinDataFormatException('Access URL must not be empty.');
    }

    late final Uri parsed;
    try {
      parsed = Uri.parse(trimmed);
    } on FormatException catch (error) {
      throw SimplefinDataFormatException(
        'Access URL is not a valid URI.',
        cause: error,
      );
    }

    if (!parsed.hasScheme || parsed.host.isEmpty) {
      throw SimplefinDataFormatException(
        'Access URL must include a scheme and host.',
      );
    }

    final colonIndex = parsed.userInfo.indexOf(':');
    if (colonIndex < 0) {
      throw SimplefinDataFormatException(
        'Access URL must contain Basic Auth credentials.',
      );
    }
    final username = Uri.decodeComponent(
      parsed.userInfo.substring(0, colonIndex),
    );
    final password = Uri.decodeComponent(
      parsed.userInfo.substring(colonIndex + 1),
    );

    final pathSegments = parsed.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final baseUri = Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      pathSegments: pathSegments,
    );

    return SimplefinAccessCredentials._(
      accessUrl: trimmed,
      baseUri: baseUri,
      username: username,
      password: password,
    );
  }

  final String accessUrl;
  final Uri baseUri;
  final String username;
  final String password;

  /// Value to use for the `Authorization` header in HTTP requests.
  String get basicAuthHeaderValue {
    final encoded = base64.encode(utf8.encode('$username:$password'));
    return 'Basic $encoded';
  }

  /// Builds a new [Uri] pointing to an endpoint relative to the Access URL.
  Uri endpointUri(
    List<String> additionalSegments, {
    Map<String, dynamic>? queryParameters,
  }) {
    final normalizedSegments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final allSegments = [
      ...normalizedSegments,
      ...additionalSegments.where((segment) => segment.isNotEmpty),
    ];

    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      pathSegments: allSegments,
      queryParameters: queryParameters?.isEmpty ?? true
          ? null
          : queryParameters,
    );
  }
}
