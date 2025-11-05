import 'package:decimal/decimal.dart';

import 'exceptions.dart';
import 'utils/time_utils.dart';

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

/// Structured response returned by the SimpleFIN `/accounts` endpoint.
class SimplefinAccountSet {
  /// Creates a response wrapper containing [serverMessages] and [accounts].
  SimplefinAccountSet({
    required Iterable<String> serverMessages,
    required Iterable<SimplefinAccount> accounts,
  }) : serverMessages = List.unmodifiable(serverMessages),
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

/// Represents a financial account exposed by a SimpleFIN server.
class SimplefinAccount {
  /// Creates an account definition returned by the SimpleFIN API.
  SimplefinAccount({
    required this.org,
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    required this.balanceDate,
    this.availableBalance,
    Iterable<SimplefinTransaction> transactions = const [],
    Map<String, dynamic>? extra,
  }) : transactions = List.unmodifiable(transactions),
       extra = extra == null ? null : Map.unmodifiable(extra);

  /// Parses an account object returned by the SimpleFIN API.
  factory SimplefinAccount.fromJson(Map<String, dynamic> json) {
    final orgField = json['org'];
    if (orgField is! Map<String, dynamic>) {
      throw SimplefinDataFormatException('Account is missing "org" object.');
    }

    final id = _expectString(json, 'id');
    final name = _expectString(json, 'name');
    final currency = _expectString(json, 'currency');
    final balance = _parseDecimal(json['balance'], 'balance');
    final availableBalance = json.containsKey('available-balance')
        ? _parseDecimal(json['available-balance'], 'available-balance')
        : null;
    final balanceDate = _parseDateTime(json['balance-date'], 'balance-date');

    final transactionsField = json['transactions'];
    final transactions = <SimplefinTransaction>[];
    if (transactionsField != null) {
      if (transactionsField is! List) {
        throw SimplefinDataFormatException(
          'Account "transactions" must be a list when present.',
        );
      }
      for (final transaction in transactionsField) {
        if (transaction is! Map<String, dynamic>) {
          throw SimplefinDataFormatException(
            'Each transaction must be an object. Found $transaction',
          );
        }
        transactions.add(SimplefinTransaction.fromJson(transaction));
      }
    }

    final extraField = json['extra'];
    Map<String, dynamic>? extra;
    if (extraField != null) {
      if (extraField is! Map<String, dynamic>) {
        throw SimplefinDataFormatException('"extra" must be an object.');
      }
      extra = Map<String, dynamic>.from(extraField);
    }

    return SimplefinAccount(
      org: SimplefinOrganization.fromJson(orgField),
      id: id,
      name: name,
      currency: currency,
      balance: balance,
      availableBalance: availableBalance,
      balanceDate: balanceDate,
      transactions: transactions,
      extra: extra,
    );
  }

  /// Organization that owns the account.
  final SimplefinOrganization org;

  /// Account identifier assigned by the provider.
  final String id;

  /// Human-friendly account name.
  final String name;

  /// ISO-4217 currency code for monetary values.
  final String currency;

  /// Current posted balance.
  final Decimal balance;

  /// Provider-reported available balance, when supplied.
  final Decimal? availableBalance;

  /// Timestamp when the balance was last refreshed.
  final DateTime balanceDate;

  /// Transactions returned alongside the account.
  final List<SimplefinTransaction> transactions;

  /// Provider-specific metadata.
  final Map<String, dynamic>? extra;

  /// Converts the account into its JSON wire format.
  Map<String, dynamic> toJson() => {
    'org': org.toJson(),
    'id': id,
    'name': name,
    'currency': currency,
    'balance': balance.toString(),
    if (availableBalance != null)
      'available-balance': availableBalance.toString(),
    'balance-date': toEpochSeconds(balanceDate),
    if (transactions.isNotEmpty)
      'transactions': transactions
          .map((transaction) => transaction.toJson())
          .toList(),
    if (extra != null) 'extra': extra,
  };
}

/// Immutable view of a transaction within a SimpleFIN account.
class SimplefinTransaction {
  /// Creates a transaction returned by the SimpleFIN API.
  SimplefinTransaction({
    required this.id,
    required this.posted,
    required this.amount,
    required this.description,
    this.transactedAt,
    this.pending = false,
    Map<String, dynamic>? extra,
  }) : extra = extra == null ? null : Map.unmodifiable(extra);

  /// Parses a transaction object returned by the SimpleFIN API.
  factory SimplefinTransaction.fromJson(Map<String, dynamic> json) {
    final id = _expectString(json, 'id');
    final posted = _parseDateTime(json['posted'], 'posted');
    final amount = _parseDecimal(json['amount'], 'amount');
    final description = _expectString(json, 'description');
    final transactedAt = json.containsKey('transacted_at')
        ? _parseDateTime(json['transacted_at'], 'transacted_at')
        : null;
    final pendingValue = json['pending'];
    late final bool pending;
    if (pendingValue == null) {
      pending = false;
    } else if (pendingValue is bool) {
      pending = pendingValue;
    } else if (pendingValue is num) {
      pending = pendingValue != 0;
    } else {
      throw SimplefinDataFormatException(
        '"pending" must be a boolean when present.',
      );
    }

    final extraField = json['extra'];
    Map<String, dynamic>? extra;
    if (extraField != null) {
      if (extraField is! Map<String, dynamic>) {
        throw SimplefinDataFormatException(
          'Transaction "extra" must be an object when present.',
        );
      }
      extra = Map<String, dynamic>.from(extraField);
    }

    return SimplefinTransaction(
      id: id,
      posted: posted,
      amount: amount,
      description: description,
      transactedAt: transactedAt,
      pending: pending,
      extra: extra,
    );
  }

  /// Identifier for the transaction.
  final String id;

  /// Date the transaction posted.
  final DateTime posted;

  /// Monetary amount of the transaction.
  final Decimal amount;

  /// Provider-supplied description.
  final String description;

  /// Timestamp when the transaction occurred, when provided.
  final DateTime? transactedAt;

  /// Indicates whether the transaction is still pending.
  final bool pending;

  /// Additional provider metadata.
  final Map<String, dynamic>? extra;

  /// Converts the transaction into its JSON wire format.
  Map<String, dynamic> toJson() => {
    'id': id,
    'posted': toEpochSeconds(posted),
    'amount': amount.toString(),
    'description': description,
    if (transactedAt != null) 'transacted_at': toEpochSeconds(transactedAt!),
    if (pending) 'pending': pending,
    if (extra != null) 'extra': extra,
  };
}

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
    final sfinUrlString = _expectString(json, 'sfin-url');
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

String _expectString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw SimplefinDataFormatException('Expected "$key" to be a string.');
}

Decimal _parseDecimal(Object? value, String fieldName) {
  if (value == null) {
    throw SimplefinDataFormatException('Field "$fieldName" is required.');
  }
  if (value is Decimal) {
    return value;
  }
  if (value is num) {
    return Decimal.parse(value.toString());
  }
  if (value is String) {
    try {
      return Decimal.parse(value);
    } on FormatException catch (error) {
      throw SimplefinDataFormatException(
        '"$fieldName" must be a decimal string.',
        cause: error,
      );
    }
  }
  throw SimplefinDataFormatException(
    '"$fieldName" must be provided as a string or number.',
  );
}

DateTime _parseDateTime(Object? value, String fieldName) {
  final seconds = _parseEpochSeconds(value, fieldName);
  return fromEpochSeconds(seconds);
}

int _parseEpochSeconds(Object? value, String fieldName) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    if (value.isFinite) {
      return value.floor();
    }
  }
  if (value is String) {
    try {
      return int.parse(value);
    } on FormatException catch (error) {
      throw SimplefinDataFormatException(
        '"$fieldName" must be an integer Unix timestamp.',
        cause: error,
      );
    }
  }
  throw SimplefinDataFormatException(
    '"$fieldName" must be provided as an integer Unix timestamp.',
  );
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
