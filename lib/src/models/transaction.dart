import 'package:decimal/decimal.dart';

import '../exceptions.dart';
import '../utils/time_utils.dart';
import '../utils/validation_helpers.dart';

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
    final id = expectString(json, 'id');
    final posted = parseDateTime(json['posted'], 'posted');
    final amount = parseDecimal(json['amount'], 'amount');
    final description = expectString(json, 'description');
    final transactedAt = json.containsKey('transacted_at')
        ? parseDateTime(json['transacted_at'], 'transacted_at')
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
        if (transactedAt != null)
          'transacted_at': toEpochSeconds(transactedAt!),
        if (pending) 'pending': pending,
        if (extra != null) 'extra': extra,
      };
}
