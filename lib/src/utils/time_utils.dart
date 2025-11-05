/// Utilities for converting between DateTime and Unix epoch timestamps.
///
/// SimpleFIN API uses Unix timestamps (seconds since epoch) for all
/// date/time values in JSON responses.

/// Converts a [DateTime] to Unix epoch seconds.
///
/// The input [value] is converted to UTC before calculating the timestamp.
///
/// Example:
/// ```dart
/// final now = DateTime.now();
/// final epochSeconds = toEpochSeconds(now);
/// // Use in API request
/// queryParams['start-date'] = epochSeconds.toString();
/// ```
int toEpochSeconds(DateTime value) =>
    value.toUtc().millisecondsSinceEpoch ~/ 1000;

/// Converts Unix epoch seconds to a [DateTime].
///
/// Returns a UTC DateTime instance.
///
/// Example:
/// ```dart
/// final timestamp = 1609459200; // 2021-01-01 00:00:00 UTC
/// final dateTime = fromEpochSeconds(timestamp);
/// ```
DateTime fromEpochSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
