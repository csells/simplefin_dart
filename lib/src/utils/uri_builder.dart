/// Utility for building URIs with path segments and query parameters.
///
/// This provides a reusable pattern for appending path segments to a base URI
/// while filtering empty segments and optionally adding query parameters.
library;

/// Builds a new URI by appending [additionalSegments] to the [baseUri].
///
/// Empty segments in both the base URI and [additionalSegments] are
/// automatically filtered out. If [queryParameters] is provided and
/// non-empty, it will be added to the resulting URI.
///
/// Example:
/// ```dart
/// final base = Uri.parse('https://api.example.com/v1/');
/// final endpoint = buildUri(
///   base,
///   ['users', 'profile'],
///   queryParameters: {'include': 'email'},
/// );
/// // Result: https://api.example.com/v1/users/profile?include=email
/// ```
Uri buildUri(
  Uri baseUri,
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
    queryParameters:
        queryParameters?.isEmpty ?? true ? null : queryParameters,
  );
}
