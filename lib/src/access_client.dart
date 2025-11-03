import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';
import 'credentials.dart';
import 'exceptions.dart';
import 'models.dart';

/// Client that uses SimpleFIN access credentials to retrieve account data.
class SimplefinAccessClient {
  /// Creates a client that issues requests with the provided [credentials].
  SimplefinAccessClient({
    required this.credentials,
    http.Client? httpClient,
    this.userAgent = defaultUserAgent,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// Credentials used to authenticate against the SimpleFIN server.
  final SimplefinAccessCredentials credentials;

  /// Value supplied as the HTTP `User-Agent` header.
  final String userAgent;

  final http.Client _httpClient;
  final bool _ownsClient;

  /// Retrieves account and transaction data from the SimpleFIN server.
  Future<SimplefinAccountSet> getAccounts({
    DateTime? startDate,
    DateTime? endDate,
    bool includePending = false,
    Iterable<String>? accountIds,
    bool balancesOnly = false,
  }) async {
    final queryParameters = <String, dynamic>{};

    if (startDate != null) {
      queryParameters['start-date'] = _toEpochSeconds(startDate).toString();
    }
    if (endDate != null) {
      queryParameters['end-date'] = _toEpochSeconds(endDate).toString();
    }
    if (includePending) {
      queryParameters['pending'] = '1';
    }
    if (balancesOnly) {
      queryParameters['balances-only'] = '1';
    }
    final accounts = accountIds?.where((id) => id.isNotEmpty).toList();
    if (accounts != null && accounts.isNotEmpty) {
      queryParameters['account'] = accounts;
    }

    final uri = credentials.endpointUri([
      'accounts',
    ], queryParameters: queryParameters.isEmpty ? null : queryParameters);

    final response = await _httpClient.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw SimplefinApiException(
        uri: uri,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Failed to fetch accounts.',
      );
    }

    Map<String, dynamic> jsonBody;
    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object.');
      }
      jsonBody = decoded;
    } on FormatException catch (error) {
      throw SimplefinApiException(
        uri: uri,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Accounts response is not valid JSON: ${error.message}',
      );
    }

    return SimplefinAccountSet.fromJson(jsonBody);
  }

  /// Releases the underlying HTTP client if this instance created it.
  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  Map<String, String> _headers() => {
    'User-Agent': userAgent,
    'Accept': 'application/json',
    'Authorization': credentials.basicAuthHeaderValue,
  };
}

int _toEpochSeconds(DateTime value) =>
    value.toUtc().millisecondsSinceEpoch ~/ 1000;
