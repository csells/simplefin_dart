import 'package:decimal/decimal.dart';

import '../exceptions.dart';
import '../utils/time_utils.dart';
import '../utils/validation_helpers.dart';
import 'organization.dart';
import 'transaction.dart';

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
  })  : transactions = List.unmodifiable(transactions),
        extra = extra == null ? null : Map.unmodifiable(extra);

  /// Parses an account object returned by the SimpleFIN API.
  factory SimplefinAccount.fromJson(Map<String, dynamic> json) {
    final orgField = json['org'];
    if (orgField is! Map<String, dynamic>) {
      throw SimplefinDataFormatException('Account is missing "org" object.');
    }

    final id = expectString(json, 'id');
    final name = expectString(json, 'name');
    final currency = expectString(json, 'currency');
    final balance = parseDecimal(json['balance'], 'balance');
    final availableBalance = json.containsKey('available-balance')
        ? parseDecimal(json['available-balance'], 'available-balance')
        : null;
    final balanceDate = parseDateTime(json['balance-date'], 'balance-date');

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
          'transactions':
              transactions.map((transaction) => transaction.toJson()).toList(),
        if (extra != null) 'extra': extra,
      };
}
