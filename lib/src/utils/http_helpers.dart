/// Builds standard HTTP headers for SimpleFIN API requests.
///
/// All requests include:
/// - User-Agent: SimpleFIN client identifier
/// - Accept: Content type (defaults to 'application/json')
///
/// Optionally includes:
/// - Authorization: When [authorizationValue] is provided
Map<String, String> buildHeaders({
  required String userAgent,
  String accept = 'application/json',
  String? authorizationValue,
}) {
  final headers = <String, String>{
    'User-Agent': userAgent,
    'Accept': accept,
  };

  if (authorizationValue != null) {
    headers['Authorization'] = authorizationValue;
  }

  return headers;
}
