import '../exceptions.dart';
import 'account.dart';

/// Structured response returned by the SimpleFIN `/accounts` endpoint.
class SimplefinAccountSet {
  /// Creates a response wrapper containing [serverMessages] and [accounts].
  SimplefinAccountSet({
    required Iterable<String> serverMessages,
    required Iterable<SimplefinAccount> accounts,
  })  : serverMessages = List.unmodifiable(serverMessages),
        accounts = List.unmodifiable(accounts);

  /// Parses an account set returned by a SimpleFIN server.
  factory SimplefinAccountSet.fromJson(Map<String, dynamic> json) {
    final errorsField = json['errors'];
    if (errorsField is! List) {
      throw SimplefinDataFormatException(
        'Expected "errors" to be a list in account set.',
      );
    }
    final serverMessages = errorsField.map((error) {
      if (error is! String) {
        throw SimplefinDataFormatException(
          'Each item in "errors" must be a string. Found $error',
        );
      }
      return error;
    });

    final accountsField = json['accounts'];
    if (accountsField is! List) {
      throw SimplefinDataFormatException(
        'Expected "accounts" to be a list in account set.',
      );
    }

    final accounts = accountsField.map((account) {
      if (account is! Map<String, dynamic>) {
        throw SimplefinDataFormatException(
          'Each account must be an object. Found $account',
        );
      }
      return SimplefinAccount.fromJson(account);
    });

    return SimplefinAccountSet(
      serverMessages: serverMessages,
      accounts: accounts,
    );
  }

  /// Informational messages reported by the bridge.
  ///
  /// These messages communicate system-wide conditions such as authentication
  /// issues, rate limits, or account sync problems. They are typically not
  /// fatal errors, but should be surfaced to end users. Messages are returned
  /// from the SimpleFIN server's "errors" field in the API response, despite
  /// the field name being "errors" in the wire format.
  ///
  /// Example messages:
  /// - "Account sync temporarily unavailable for savings account"
  /// - "Rate limit approaching - consider reducing polling frequency"
  ///
  /// These messages are preserved when filtering account sets:
  /// ```dart
  /// final accountSet = await client.getAccounts();
  /// final filtered = accountSet.filterByOrganizationId('org_123');
  /// // filtered.serverMessages still contains all original messages
  /// ```
  final List<String> serverMessages;

  /// Collection of accounts returned by the server.
  final List<SimplefinAccount> accounts;

  /// Converts the account set to a JSON representation.
  Map<String, dynamic> toJson() => {
        'errors': serverMessages,
        'accounts': accounts.map((account) => account.toJson()).toList(),
      };
}

/// Extension methods for filtering [SimplefinAccountSet] results.
extension SimplefinAccountSetFilters on SimplefinAccountSet {
  /// Returns a new [SimplefinAccountSet] containing only accounts
  /// that belong to the specified organization ID.
  ///
  /// Accounts without an organization ID are excluded from the result.
  SimplefinAccountSet filterByOrganizationId(String orgId) {
    final filtered = accounts.where((account) {
      final accountOrgId = account.org.id;
      return accountOrgId != null && accountOrgId == orgId;
    }).toList();

    return SimplefinAccountSet(
      serverMessages: serverMessages,
      accounts: filtered,
    );
  }
}
