import 'package:simplefin_dart/src/models/account.dart';
import 'package:simplefin_dart/src/models/account_set.dart';
import 'package:simplefin_dart/src/models/bridge_info.dart';
import 'package:test/test.dart';

void main() {
  group('SimplefinBridgeInfo', () {
    test('fromJson parses versions list correctly', () {
      final json = {
        'versions': ['v1', 'v2'],
      };

      final info = SimplefinBridgeInfo.fromJson(json);

      expect(info.versions, hasLength(2));
      expect(info.versions, contains('v1'));
      expect(info.versions, contains('v2'));
    });

    test('toJson produces expected output', () {
      final info = SimplefinBridgeInfo(versions: ['v1', 'v2']);

      final json = info.toJson();

      expect(json['versions'], equals(['v1', 'v2']));
    });

    test('versions list is unmodifiable', () {
      final info = SimplefinBridgeInfo(versions: ['v1']);

      expect(() => info.versions.add('v2'), throwsUnsupportedError);
    });
  });

  group('SimplefinAccountSet', () {
    test('fromJson parses accounts and server messages', () {
      final json = {
        'errors': ['Server message 1', 'Server message 2'],
        'accounts': [],
      };

      final accountSet = SimplefinAccountSet.fromJson(json);

      expect(accountSet.serverMessages, hasLength(2));
      expect(accountSet.serverMessages, contains('Server message 1'));
      expect(accountSet.serverMessages, contains('Server message 2'));
      expect(accountSet.accounts, isEmpty);
    });

    test('toJson produces expected output', () {
      final accountSet = SimplefinAccountSet(
        serverMessages: ['Message 1'],
        accounts: [],
      );

      final json = accountSet.toJson();

      expect(json['errors'], equals(['Message 1']));
      expect(json['accounts'], isEmpty);
    });

    test('server messages list is unmodifiable', () {
      final accountSet = SimplefinAccountSet(
        serverMessages: ['Message 1'],
        accounts: [],
      );

      expect(() => accountSet.serverMessages.add('Message 2'),
          throwsUnsupportedError);
    });

    test('accounts list is unmodifiable', () {
      final accountSet = SimplefinAccountSet(
        serverMessages: [],
        accounts: [],
      );

      expect(accountSet.accounts, isA<List<SimplefinAccount>>());
      expect(accountSet.accounts, isEmpty);
    });
  });
}
