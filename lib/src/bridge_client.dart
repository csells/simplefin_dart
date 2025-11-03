import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';
import 'credentials.dart';
import 'exceptions.dart';
import 'models.dart';

/// HTTP client for interacting with a SimpleFIN Bridge server.
class SimplefinBridgeClient {
  /// Creates a client targeting the provided bridge [root] URL.
  SimplefinBridgeClient({
    Uri? root,
    http.Client? httpClient,
    this.userAgent = defaultUserAgent,
  }) : root = root ?? Uri.parse(defaultBridgeRootUrl),
       _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// Base URI for all bridge API requests.
  final Uri root;

  /// Value supplied as the HTTP `User-Agent` header.
  final String userAgent;

  final http.Client _httpClient;
  final bool _ownsClient;

  /// Retrieves the list of protocol versions supported by the configured
  /// bridge instance.
  Future<SimplefinBridgeInfo> getInfo() async {
    final uri = _buildUri(['info']);
    final response = await _httpClient.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw SimplefinApiException(
        uri: uri,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Failed to query bridge info.',
      );
    }

    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      return SimplefinBridgeInfo.fromJson(decoded);
    } on FormatException catch (error) {
      throw SimplefinApiException(
        uri: uri,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Bridge info response is not valid JSON: ${error.message}',
      );
    }
  }

  /// Exchanges a user-provided setup token for long-lived access credentials.
  Future<SimplefinAccessCredentials> claimAccessCredentials(
    String setupToken,
  ) async {
    final parsedToken = SimplefinSetupToken.parse(setupToken);
    final response = await _httpClient.post(
      parsedToken.claimUri,
      headers: _headers(accept: 'text/plain'),
    );

    if (response.statusCode != 200) {
      throw SimplefinApiException(
        uri: parsedToken.claimUri,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Failed to claim access URL.',
      );
    }

    final trimmedBody = response.body.trim();
    if (trimmedBody.isEmpty) {
      throw SimplefinApiException(
        uri: parsedToken.claimUri,
        statusCode: response.statusCode,
        message: 'Claim response did not include an access URL.',
      );
    }

    return SimplefinAccessCredentials.parse(trimmedBody);
  }

  /// Releases the underlying HTTP client if this instance created it.
  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  Uri _buildUri(List<String> additionalSegments) {
    final segments = root.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    segments.addAll(additionalSegments.where((segment) => segment.isNotEmpty));

    return Uri(
      scheme: root.scheme,
      host: root.host,
      port: root.hasPort ? root.port : null,
      pathSegments: segments,
    );
  }

  Map<String, String> _headers({String accept = 'application/json'}) => {
    'User-Agent': userAgent,
    'Accept': accept,
  };
}
