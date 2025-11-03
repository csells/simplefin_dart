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
```

An annotated template is available at `example/example.env`; copy it to
`example/.env` and follow the inline instructions. You can also generate the
access URL via the CLI:

```
dart run example/main.dart claim <SETUP_TOKEN>
```

List account data with:

```
dart run example/main.dart accounts
```

List organizations referenced by the accounts payload:

```
dart run example/main.dart organizations
```

Inspect transactions (optionally filtering to a specific account):

```
dart run example/main.dart transactions [ACCOUNT_ID]
```

Use `--account <ID>` (repeatable) or `--access-url <URL>` to customise the
accounts query; it always returns balances only. The `organizations` command
lists the distinct institutions referenced by the accounts payload. The
`transactions` command accepts `--start-date` (`-s`), `--end-date` (`-e`), `--pending`, and
`--access-url`. All commands support `-f/--output-format` with `text`
(default), `json`, or `csv`. The commands read `example/.env` automatically
when `--access-url` is omitted.

When no `--start-date` is supplied to `transactions`, the last 30 days of
activity are requested (the SimpleFIN API caps ranges at 60 days). When
`--end-date` is omitted, the current time is used.

### Example CLI usage

```
$ dart run example/main.dart --help
Usage: dart run example/main.dart <command> [arguments]

Available commands:
  c (claim)         Exchange a setup token for an access URL.
  i (info)          Query the SimpleFIN bridge for supported versions.
  a (accounts)      Retrieve account balances.
  o (organizations) List organizations referenced by accounts.
  t (transactions)  Retrieve transactions for a specific account.

Run `dart run example/main.dart <command> --help` for details.
```

```
$ dart run example/main.dart organizations --help
Usage: dart run example/main.dart organizations [options]
    -a, --access-url=<URL>       Override SIMPLEFIN_ACCESS_URL from .env (default: example/.env)
    -f, --output-format=<FORMAT> Output as text, json, or csv (default: text)
    -h, --help                   Show usage information

$ dart run example/main.dart accounts --help
Usage: dart run example/main.dart accounts [options]
    -a, --access-url=<URL>       Override SIMPLEFIN_ACCESS_URL from .env (default: example/.env)
    -A, --account=<ID>           Filter to a specific account (repeatable)
    -f, --output-format=<FORMAT> Output as text, json, or csv (default: text)
    -h, --help                   Show usage information

$ dart run example/main.dart organizations --help
Usage: dart run example/main.dart organizations [options]
    -a, --access-url=<URL>       Override SIMPLEFIN_ACCESS_URL from .env (default: example/.env)
    -f, --output-format=<FORMAT> Output as text, json, or csv (default: text)
    -h, --help                   Show usage information
```

Markdown (`text`) output renders one block per account, `json` streams the API
payload, and `csv` flattens accounts and transactions into rows suitable for
spreadsheets. The `accounts` command reports only balance information and
includes each account's `org-id`; use `organizations` for full institution
metadata. The `transactions` command provides similar help and accepts an
optional account ID to narrow results.

### Where to obtain the values

1. Sign in to the SimpleFIN Bridge at
   [https://beta-bridge.simplefin.org/auth/login](https://beta-bridge.simplefin.org/auth/login).
2. After authentication, visit
   [https://bridge.simplefin.org/simplefin/create](https://bridge.simplefin.org/simplefin/create).
   This page generates a **Setup Token** (a long Base64 string).
3. Run `dart run example/main.dart claim <SETUP_TOKEN>`. The command exchanges
   the setup token for an **Access URL** and prints `SIMPLEFIN_ACCESS_URL=...`.
   Append or paste that line into your `.env` file.
4. Keep the access URL secure—anyone with the URL can read the associated
   account data until you revoke it in the Bridge UI.

## Testing

The unit test suite uses `MockClient` from `package:http` and does not hit the
live SimpleFIN service. For manual verification against live data, populate the
`.env` file described in the Usage section before running local workflows such
as the example script.

## Resources

- [SimpleFIN Protocol Specification](https://www.simplefin.org/protocol.html)
- [SimpleFIN Bridge developer docs](https://beta-bridge.simplefin.org/info/developers)
