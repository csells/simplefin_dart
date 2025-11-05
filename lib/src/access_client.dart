import 'package:http/http.dart' as http;

import 'constants.dart';
import 'credentials.dart';
import 'exceptions.dart';
import 'models/account_set.dart';
import 'utils/http_client_ownership.dart';
import 'utils/http_helpers.dart';
import 'utils/json_parser.dart';
import 'utils/time_utils.dart';

/// Client that uses SimpleFIN access credentials to retrieve account data.
class SimplefinAccessClient with HttpClientOwnership {
  /// Creates a client that issues requests with the provided [credentials].
  SimplefinAccessClient({
    required this.credentials,
    http.Client? httpClient,
    this.userAgent = defaultUserAgent,
  }) {
    initHttpClient(httpClient);
  }

  /// Credentials used to authenticate against the SimpleFIN server.
  final SimplefinAccessCredentials credentials;

  /// Value supplied as the HTTP `User-Agent` header.
  final String userAgent;

  /// Retrieves account and transaction data from the SimpleFIN server.
  ///
  /// Throws [ArgumentError] if [startDate] is after [endDate].
  Future<SimplefinAccountSet> getAccounts({
    DateTime? startDate,
    DateTime? endDate,
    bool includePending = false,
    Iterable<String>? accountIds,
    bool balancesOnly = false,
  }) async {
    // Validate date range
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw ArgumentError(
        'startDate must be before or equal to endDate. '
        'Got startDate=$startDate, endDate=$endDate',
      );
    }

    final queryParameters = _buildAccountQueryParameters(
      startDate: startDate,
      endDate: endDate,
      includePending: includePending,
      accountIds: accountIds,
      balancesOnly: balancesOnly,
    );

    final uri = credentials.endpointUri([
      'accounts',
    ], queryParameters: queryParameters.isEmpty ? null : queryParameters);

    final response = await httpClient.get(
      uri,
      headers: buildHeaders(
        userAgent: userAgent,
        authorizationValue: credentials.basicAuthHeaderValue,
      ),
    );
    if (response.statusCode != 200) {
      throw SimplefinApiException(
        uri: uri,
        statusCode: response.statusCode,
        responseBody: response.body,
        message: 'Failed to fetch accounts.',
      );
    }

    final jsonBody = parseJsonObject(
      response.body,
      uri: uri,
      statusCode: response.statusCode,
      errorContext: 'Accounts response',
    );
    return SimplefinAccountSet.fromJson(jsonBody);
  }

  /// Releases the underlying HTTP client if this instance created it.
  void close() {
    closeHttpClient();
  }

  /// Builds query parameters for the accounts endpoint.
  Map<String, dynamic> _buildAccountQueryParameters({
    DateTime? startDate,
    DateTime? endDate,
    bool includePending = false,
    Iterable<String>? accountIds,
    bool balancesOnly = false,
  }) {
    final queryParameters = <String, dynamic>{};

    if (startDate != null) {
      queryParameters['start-date'] = toEpochSeconds(startDate).toString();
    }
    if (endDate != null) {
      queryParameters['end-date'] = toEpochSeconds(endDate).toString();
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

    return queryParameters;
  }
}
