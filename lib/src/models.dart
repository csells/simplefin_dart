import 'package:decimal/decimal.dart';

import 'exceptions.dart';

/// Metadata describing the capabilities of a SimpleFIN Bridge server.
class SimplefinBridgeInfo {
  SimplefinBridgeInfo({required Iterable<String> versions})
    : versions = List.unmodifiable(versions);

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

  final List<String> versions;

  Map<String, dynamic> toJson() => {'versions': versions};
}

/// Structured response returned by the SimpleFIN `/accounts` endpoint.
class SimplefinAccountSet {
  SimplefinAccountSet({
    required Iterable<String> errors,
    required Iterable<SimplefinAccount> accounts,
  }) : errors = List.unmodifiable(errors),
       accounts = List.unmodifiable(accounts);

  factory SimplefinAccountSet.fromJson(Map<String, dynamic> json) {
    final errorsField = json['errors'];
    if (errorsField is! List) {
      throw SimplefinDataFormatException(
        'Expected "errors" to be a list in account set.',
      );
    }
    final errors = errorsField.map((error) {
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

    return SimplefinAccountSet(errors: errors, accounts: accounts);
  }

  final List<String> errors;
  final List<SimplefinAccount> accounts;

  Map<String, dynamic> toJson() => {
    'errors': errors,
    'accounts': accounts.map((account) => account.toJson()).toList(),
  };
}

/// Represents a financial account exposed by a SimpleFIN server.
class SimplefinAccount {
  SimplefinAccount({
    required this.org,
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    this.availableBalance,
    required this.balanceDate,
    Iterable<SimplefinTransaction> transactions = const [],
    Map<String, dynamic>? extra,
  }) : transactions = List.unmodifiable(transactions),
       extra = extra == null ? null : Map.unmodifiable(extra);

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

  final SimplefinOrganization org;
  final String id;
  final String name;
  final String currency;
  final Decimal balance;
  final Decimal? availableBalance;
  final DateTime balanceDate;
  final List<SimplefinTransaction> transactions;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    'org': org.toJson(),
    'id': id,
    'name': name,
    'currency': currency,
    'balance': balance.toString(),
    if (availableBalance != null)
      'available-balance': availableBalance.toString(),
    'balance-date': balanceDate.toUtc().millisecondsSinceEpoch ~/ 1000,
    if (transactions.isNotEmpty)
      'transactions': transactions
          .map((transaction) => transaction.toJson())
          .toList(),
    if (extra != null) 'extra': extra,
  };
}

/// Immutable view of a transaction within a SimpleFIN account.
class SimplefinTransaction {
  SimplefinTransaction({
    required this.id,
    required this.posted,
    required this.amount,
    required this.description,
    this.transactedAt,
    this.pending = false,
    Map<String, dynamic>? extra,
  }) : extra = extra == null ? null : Map.unmodifiable(extra);

  factory SimplefinTransaction.fromJson(Map<String, dynamic> json) {
    final id = _expectString(json, 'id');
    final posted = _parseDateTime(json['posted'], 'posted');
    final amount = _parseDecimal(json['amount'], 'amount');
    final description = _expectString(json, 'description');
    final transactedAt = json.containsKey('transacted_at')
        ? _parseDateTime(json['transacted_at'], 'transacted_at')
        : null;
    final pendingValue = json['pending'];
    final pending = pendingValue == null
        ? false
        : pendingValue is bool
        ? pendingValue
        : (pendingValue is num
              ? pendingValue != 0
              : throw SimplefinDataFormatException(
                  '"pending" must be a boolean when present.',
                ));

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

  final String id;
  final DateTime posted;
  final Decimal amount;
  final String description;
  final DateTime? transactedAt;
  final bool pending;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    'id': id,
    'posted': posted.toUtc().millisecondsSinceEpoch ~/ 1000,
    'amount': amount.toString(),
    'description': description,
    if (transactedAt != null)
      'transacted_at': transactedAt!.toUtc().millisecondsSinceEpoch ~/ 1000,
    if (pending) 'pending': pending,
    if (extra != null) 'extra': extra,
  };
}

/// Description of the financial institution that owns a SimpleFIN account.
class SimplefinOrganization {
  SimplefinOrganization({
    this.domain,
    required this.sfinUrl,
    this.name,
    this.url,
    this.id,
  });

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

  final String? domain;
  final Uri sfinUrl;
  final String? name;
  final Uri? url;
  final String? id;

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
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
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
