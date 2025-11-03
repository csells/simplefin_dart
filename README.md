# simplefin_dart

After losing Mint and Personal Capital, and now Empower moving my cheese again,
I decided that a stable place to track my accounts and transactions is in
order. So I found [SimpleFIN](https://www.simplefin.org/), which allows you to
put the credentials in for your various financial institutions and tracks their
balance and transactions, exposing them with a simple, secure REST API for only
$15/year.

There are several existing OSS apps that plug into SimpleFIN, but of course, I
wanted to build my own in Flutter, so `simplefin_dart` was born. This packages
covers the API surface area:

- Claim an access URL from a one-time setup token.
- Query bridge metadata (`GET /info`).
- Retrieve accounts and transactions with rich typed models.

Both the bridge and access clients accept an injected `http.Client` to simplify
testing and to support advanced scenarios such as custom retry middleware.

## API Usage

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

### 2. Fetch accounts

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
      // Handle balances.
    }

    if (accounts.errors.isNotEmpty) {
      // Surface bridge warnings back to the user.
    }
  } finally {
    client.close();
  }
}
```

### SimpleFIN Tokens

The SimpleFIN service requires you to obtain an API access URL via a scavenger
hunt style process:

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


## Example CLI

See `example/main.dart` for a runnable app that loads credentials from a `.env`
file (set up as described above). Here's the usage to access your SimpleFIN
organizations, accounts and transactions:

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

$ dart run example/main.dart organizations --help
Usage: dart run example/main.dart organizations [options]
    -u, --url=<URL>              Override SIMPLEFIN_ACCESS_URL from .env (default: example/.env)
    -f, --output-format=<FORMAT> Output as text, json, or csv (default: text)
    -h, --help                   Show usage information

$ dart run example/main.dart accounts --help
Usage: dart run example/main.dart accounts [options]
    -u, --url=<URL>              Override SIMPLEFIN_ACCESS_URL from .env (default: example/.env)
    -o, --org-id=<ORG_ID>        Restrict results to a specific organization ID
    -f, --output-format=<FORMAT> Output as text, json, or csv (default: text)
    -h, --help                   Show usage information

$ dart run example/main.dart transactions --help
Usage: dart run example/main.dart transactions [options]
    -u, --url=<URL>              Override SIMPLEFIN_ACCESS_URL from .env (default: example/.env)
    -s, --start-date=<DATE>      ISO-8601 or epoch seconds inclusive (default: 30 days ago)
    -e, --end-date=<DATE>        ISO-8601 or epoch seconds exclusive (default: now)
        --pending                Include pending transactions (default: off)
    -a, --account=<ID>           Filter to a specific account when provided
    -f, --output-format=<FORMAT> Output as text, json, or csv (default: text)
    -h, --help                   Show usage information
```

## Resources

- [SimpleFIN Protocol Specification](https://www.simplefin.org/protocol.html)
- [SimpleFIN Bridge developer
  docs](https://beta-bridge.simplefin.org/info/developers)
