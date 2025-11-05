import 'package:http/http.dart' as http;

import 'constants.dart';
import 'credentials.dart';
import 'exceptions.dart';
import 'models/bridge_info.dart';
import 'utils/http_client_ownership.dart';
import 'utils/http_helpers.dart';
import 'utils/json_parser.dart';
import 'utils/uri_builder.dart';

/// HTTP client for interacting with a SimpleFIN Bridge server.
class SimplefinBridgeClient with HttpClientOwnership {
  /// Creates a client targeting the provided bridge [root] URL.
  SimplefinBridgeClient({
    Uri? root,
    http.Client? httpClient,
    this.userAgent = defaultUserAgent,
  }) : root = root ?? Uri.parse(defaultBridgeRootUrl) {
    initHttpClient(httpClient);
  }

  /// Base URI for all bridge API requests.
  final Uri root;

  /// Value supplied as the HTTP `User-Agent` header.
  final String userAgent;

  /// Retrieves the list of protocol versions supported by the configured
  /// bridge instance.
  Future<SimplefinBridgeInfo> getInfo() async {
    final uri = buildUri(root, ['info']);
    final response = await httpClient.get(
      uri,
      headers: buildHeaders(userAgent: userAgent),
    );
    if (response.statusCode != 200) {
      throw SimplefinApiException(
        uri: uri,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Failed to query bridge info.',
      );
    }

    final jsonBody = parseJsonObject(
      response.body,
      uri: uri,
      statusCode: response.statusCode,
      errorContext: 'Bridge info response',
    );
    return SimplefinBridgeInfo.fromJson(jsonBody);
  }

  /// Exchanges a user-provided setup token for long-lived access credentials.
  Future<SimplefinAccessCredentials> claimAccessCredentials(
    String setupToken,
  ) async {
    final parsedToken = SimplefinSetupToken.parse(setupToken);
    final response = await httpClient.post(
      parsedToken.claimUri,
      headers: buildHeaders(userAgent: userAgent, accept: 'text/plain'),
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
    closeHttpClient();
  }
}
