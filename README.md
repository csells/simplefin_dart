# simplefin_dart

Production-ready SimpleFIN Bridge client for Dart. The library covers the full
protocol surface area:

- Claim an access URL from a one-time setup token.
- Query bridge metadata (`GET /info`).
- Retrieve accounts and transactions with rich typed models.

Both the bridge and access clients accept an injected `http.Client` to simplify
testing and to support advanced scenarios such as custom retry middleware.

## Getting started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  simplefin_dart:
    path: .
```

> The package targets Dart SDK `^3.9.2`. No Flutter-specific features are used.

## Usage

### 1. Claim an Access URL

```dart
import 'package:simplefin_dart/simplefin_dart.dart';

Future<SimplefinAccessCredentials> claimFromUser(String setupToken) async {
  final bridge = SimplefinBridgeClient();
  try {
    return await bridge.claimAccessCredentials(setupToken);
  } finally {
    bridge.close();
  }
}
```

### 2. Fetch accounts and transactions

```dart
import 'package:simplefin_dart/simplefin_dart.dart';

Future<void> sync(SimplefinAccessCredentials credentials) async {
  final client = SimplefinAccessClient(credentials: credentials);
  try {
    final accounts = await client.getAccounts(
      startDate: DateTime.now().toUtc().subtract(const Duration(days: 30)),
      includePending: true,
    );

    for (final account in accounts.accounts) {
      // Handle balances and transactions.
    }

    if (accounts.errors.isNotEmpty) {
      // Surface bridge warnings back to the user.
    }
  } finally {
    client.close();
  }
}
```

See `example/main.dart` for a runnable end-to-end script that
loads credentials from a `.env` file using
[`package:dotenv`](https://pub.dev/packages/dotenv). Create a file named `.env`
next to the script with the following contents:

```
SIMPLEFIN_ACCESS_URL=https://user:password@bridge.simplefin.org/simplefin
# Optional: use this once to mint a new access URL.
SIMPLEFIN_SETUP_TOKEN=...
```

An annotated template is available at `example/example.env`; copy it to `.env`
and fill in the values described in the comments.

Run the example with `dart run example/main.dart`. Pass a custom `.env` path as
the first argument if needed. If only a setup token is specified, the script
will claim an access URL and print it to stdout.

### Where to obtain the values

1. Sign in to the SimpleFIN Bridge at
   [https://beta-bridge.simplefin.org/auth/login](https://beta-bridge.simplefin.org/auth/login).
2. After authentication, visit
   [https://bridge.simplefin.org/simplefin/create](https://bridge.simplefin.org/simplefin/create).
   This page generates a **Setup Token** (a long Base64 string).
3. Copy the setup token into your `.env` file as `SIMPLEFIN_SETUP_TOKEN`.
4. Run the example script once. It exchanges the setup token for an **Access
   URL** and prints it. Replace the setup token in your `.env` file with the
   newly returned `SIMPLEFIN_ACCESS_URL` for subsequent use.
5. Keep the access URL secure—anyone with the URL can read the associated
   account data until you revoke it in the Bridge UI.

## Testing

The unit test suite uses `MockClient` from `package:http` and does not hit the
live SimpleFIN service. For manual verification against live data, populate the
`.env` file described in the Usage section before running local workflows such
as the example script.

## Resources

- [SimpleFIN Protocol Specification](https://www.simplefin.org/protocol.html)
- [SimpleFIN Bridge developer docs](https://beta-bridge.simplefin.org/info/developers)
