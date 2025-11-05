import 'package:http/http.dart' as http;

/// Mixin that provides HTTP client ownership pattern.
///
/// This mixin manages an HTTP client instance and tracks whether this object
/// owns the client (and should close it) or if the client was provided
/// externally.
mixin HttpClientOwnership {
  late final http.Client _httpClient;
  late final bool _ownsClient;

  /// Initializes the HTTP client.
  ///
  /// If [httpClient] is provided, this object will use it without taking
  /// ownership. If null, a new client is created and this object owns it.
  void initHttpClient(http.Client? httpClient) {
    _httpClient = httpClient ?? http.Client();
    _ownsClient = httpClient == null;
  }

  /// The HTTP client instance being used.
  http.Client get httpClient => _httpClient;

  /// Closes the HTTP client if this object owns it.
  ///
  /// Should be called when this object is no longer needed to free resources.
  void closeHttpClient() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}
