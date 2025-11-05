import '../exceptions.dart';

/// Metadata describing the capabilities of a SimpleFIN Bridge server.
class SimplefinBridgeInfo {
  /// Creates metadata describing available protocol [versions].
  SimplefinBridgeInfo({required Iterable<String> versions})
      : versions = List.unmodifiable(versions);

  /// Parses bridge metadata from a JSON response.
  factory SimplefinBridgeInfo.fromJson(Map<String, dynamic> json) {
    final rawVersions = json['versions'];
    if (rawVersions is! List) {
      throw SimplefinDataFormatException(
        'Expected "versions" to be a list in bridge info response.',
      );
    }
    return SimplefinBridgeInfo(
      versions: rawVersions.map((version) {
        if (version is! String) {
          throw SimplefinDataFormatException(
            'Versions must be strings. Found $version',
          );
        }
        return version;
      }),
    );
  }

  /// Supported SimpleFIN protocol versions reported by the bridge.
  final List<String> versions;

  /// Converts the bridge metadata back into JSON.
  Map<String, dynamic> toJson() => {'versions': versions};
}
