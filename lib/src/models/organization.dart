import '../exceptions.dart';
import '../utils/validation_helpers.dart';

/// Description of the financial institution that owns a SimpleFIN account.
class SimplefinOrganization {
  /// Creates an organization definition returned by the SimpleFIN API.
  SimplefinOrganization({
    required this.sfinUrl,
    this.domain,
    this.name,
    this.url,
    this.id,
  });

  /// Parses an organization object returned by the SimpleFIN API.
  factory SimplefinOrganization.fromJson(Map<String, dynamic> json) {
    final sfinUrlString = expectString(json, 'sfin-url');
    late final Uri sfinUrl;
    try {
      sfinUrl = Uri.parse(sfinUrlString);
    } on FormatException catch (error) {
      throw SimplefinDataFormatException(
        '"sfin-url" must be a valid URI.',
        cause: error,
      );
    }

    Uri? orgUrl;
    final urlString = json['url'];
    if (urlString != null) {
      if (urlString is! String) {
        throw SimplefinDataFormatException(
          '"url" must be a string when present.',
        );
      }
      try {
        orgUrl = Uri.parse(urlString);
      } on FormatException catch (error) {
        throw SimplefinDataFormatException(
          '"url" must be a valid URI.',
          cause: error,
        );
      }
    }

    return SimplefinOrganization(
      domain: json['domain'] as String?,
      sfinUrl: sfinUrl,
      name: json['name'] as String?,
      url: orgUrl,
      id: json['id'] as String?,
    );
  }

  /// Domain name associated with the organization, if available.
  final String? domain;

  /// Bridge URL for the organization.
  final Uri sfinUrl;

  /// Human-friendly organization name.
  final String? name;

  /// Public website for the organization.
  final Uri? url;

  /// Organization identifier included by the provider.
  final String? id;

  /// Converts the organization into its JSON wire representation.
  Map<String, dynamic> toJson() => {
        if (domain != null) 'domain': domain,
        'sfin-url': sfinUrl.toString(),
        if (name != null) 'name': name,
        if (url != null) 'url': url.toString(),
        if (id != null) 'id': id,
      };
}
