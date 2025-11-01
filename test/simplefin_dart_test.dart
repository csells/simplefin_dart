import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simplefin_dart/simplefin_dart.dart';
import 'package:test/test.dart';

void main() {
  group('SimplefinSetupToken', () {
    test('parses base64 token into claim URI', () {
      final claimUri = 'https://example.com/simplefin/claim/token';
      final token = base64.encode(utf8.encode(claimUri));

      final parsed = SimplefinSetupToken.parse(token);
      expect(parsed.claimUri.toString(), claimUri);
    });

    test('throws when token is empty', () {
      expect(
        () => SimplefinSetupToken.parse(''),
        throwsA(isA<SimplefinInvalidSetupToken>()),
      );
    });
  });

  group('SimplefinAccessCredentials', () {
    test('parses access URL with credentials and path', () {
      final credentials = SimplefinAccessCredentials.parse(
        'https://user:secret@example.com:8443/simplefin',
      );

      expect(credentials.username, 'user');
      expect(credentials.password, 'secret');
      expect(
        credentials.endpointUri(['accounts']).toString(),
        'https://example.com:8443/simplefin/accounts',
      );
      expect(credentials.basicAuthHeaderValue, startsWith('Basic '));
    });
  });

  group('SimplefinAccessClient', () {
    const sampleBody = '''
{
  "errors": [],
  "accounts": [
    {
      "org": {
        "domain": "mybank.com",
        "sfin-url": "https://sfin.mybank.com"
      },
      "id": "acc-001",
      "name": "Checking",
      "currency": "USD",
      "balance": "100.23",
      "available-balance": "98.00",
      "balance-date": 1609459200,
      "transactions": [
        {
          "id": "txn-001",
          "posted": 1609459300,
          "amount": "-50.00",
          "description": "Groceries",
          "pending": false
        }
      ]
    }
  ]
}
''';

    test('requests accounts with expected query parameters', () async {
      late Uri requestedUri;
      late Map<String, String> requestedHeaders;

      final mockClient = MockClient((request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        expect(request.method, equals('GET'));
        return http.Response(
          sampleBody,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final credentials = SimplefinAccessCredentials.parse(
        'https://user:secret@example.com/simplefin',
      );
      final accessClient = SimplefinAccessClient(
        credentials: credentials,
        httpClient: mockClient,
        userAgent: 'test-agent/1.0',
      );

      final startDate = DateTime.utc(2021, 1, 1);
      final endDate = DateTime.utc(2021, 1, 2);

      final accountSet = await accessClient.getAccounts(
        startDate: startDate,
        endDate: endDate,
        includePending: true,
        accountIds: ['acc-001', 'acc-002'],
        balancesOnly: true,
      );

      expect(requestedUri.path, '/simplefin/accounts');
      expect(requestedUri.queryParameters['start-date'], '1609459200');
      expect(requestedUri.queryParameters['end-date'], '1609545600');
      expect(requestedUri.queryParameters['pending'], '1');
      expect(requestedUri.queryParameters['balances-only'], '1');
      expect(requestedUri.queryParametersAll['account'], [
        'acc-001',
        'acc-002',
      ]);
      expect(
        requestedHeaders['authorization'],
        credentials.basicAuthHeaderValue,
      );
      expect(requestedHeaders['user-agent'], 'test-agent/1.0');

      expect(accountSet.accounts, hasLength(1));
      expect(accountSet.accounts.first.transactions, hasLength(1));
    });

    test('throws SimplefinApiException on non-200 response', () async {
      final mockClient = MockClient(
        (request) async => http.Response('Forbidden', 403),
      );

      final credentials = SimplefinAccessCredentials.parse(
        'https://user:secret@example.com/simplefin',
      );
      final accessClient = SimplefinAccessClient(
        credentials: credentials,
        httpClient: mockClient,
      );

      expect(
        () => accessClient.getAccounts(),
        throwsA(
          isA<SimplefinApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });
  });

  group('SimplefinBridgeClient', () {
    test('parses bridge info response', () async {
      final root = Uri.parse('https://example.com/simplefin');
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/simplefin/info');
        expect(request.method, equals('GET'));
        return http.Response(
          '{"versions":["1.0","1.0.7"]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final bridgeClient = SimplefinBridgeClient(
        root: root,
        httpClient: mockClient,
        userAgent: 'test-agent/1.0',
      );

      final info = await bridgeClient.getInfo();
      expect(info.versions, containsAll(['1.0', '1.0.7']));
    });

    test('claims access credentials', () async {
      final claimUri = Uri.parse('https://example.com/simplefin/claim/demo');
      final token = base64.encode(utf8.encode(claimUri.toString()));

      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url, claimUri);
        return http.Response('https://user:secret@example.com/simplefin', 200);
      });

      final bridgeClient = SimplefinBridgeClient(
        root: Uri.parse('https://example.com/simplefin'),
        httpClient: mockClient,
        userAgent: 'test-agent/1.0',
      );

      final credentials = await bridgeClient.claimAccessCredentials(token);

      expect(credentials.username, 'user');
      expect(
        credentials.endpointUri(['accounts']).toString(),
        'https://example.com/simplefin/accounts',
      );
    });
  });
}
