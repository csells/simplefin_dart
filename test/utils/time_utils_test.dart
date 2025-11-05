import 'package:simplefin_dart/src/utils/time_utils.dart';
import 'package:test/test.dart';

void main() {
  group('toEpochSeconds', () {
    test('converts DateTime to Unix epoch seconds', () {
      final dateTime = DateTime.utc(2021, 1, 1);
      final epochSeconds = toEpochSeconds(dateTime);
      expect(epochSeconds, equals(1609459200));
    });

    test('converts non-UTC DateTime to UTC before conversion', () {
      final dateTime = DateTime(2021, 1, 1); // Local time
      final epochSeconds = toEpochSeconds(dateTime);
      final utcDateTime = dateTime.toUtc();
      final expectedSeconds = utcDateTime.millisecondsSinceEpoch ~/ 1000;
      expect(epochSeconds, equals(expectedSeconds));
    });
  });

  group('fromEpochSeconds', () {
    test('converts Unix epoch seconds to DateTime', () {
      const epochSeconds = 1609459200; // 2021-01-01 00:00:00 UTC
      final dateTime = fromEpochSeconds(epochSeconds);
      expect(dateTime.year, equals(2021));
      expect(dateTime.month, equals(1));
      expect(dateTime.day, equals(1));
      expect(dateTime.hour, equals(0));
      expect(dateTime.minute, equals(0));
      expect(dateTime.second, equals(0));
      expect(dateTime.isUtc, isTrue);
    });

    test('round-trip conversion preserves value', () {
      final original = DateTime.utc(2023, 6, 15, 14, 30, 45);
      final epochSeconds = toEpochSeconds(original);
      final converted = fromEpochSeconds(epochSeconds);
      expect(converted.millisecondsSinceEpoch ~/ 1000,
          equals(original.millisecondsSinceEpoch ~/ 1000));
    });
  });
}
