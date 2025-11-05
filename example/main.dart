import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:csv/csv.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:simplefin_dart/simplefin_dart.dart';

Future<void> main(List<String> arguments) async {
  final parsers = _ParserBundle.build();
  final parser = parsers.root;

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _printTopLevelUsage(parsers);
    exitCode = 64;
    return;
  }

  if (results['help'] as bool) {
    _printTopLevelUsage(parsers);
    return;
  }

  final command = results.command;
  if (command == null) {
    stderr.writeln('No command provided.');
    _printTopLevelUsage(parsers);
    exitCode = 64;
    return;
  }

  final scriptDir = File.fromUri(Platform.script).parent;

  switch (command.name) {
    case 'claim':
    case 'c':
      await _handleClaim(command, parsers, scriptDir);
    case 'info':
    case 'i':
      await _handleInfo(command, parsers);
    case 'accounts':
    case 'a':
      await _handleAccounts(command, parsers, scriptDir);
    case 'organizations':
    case 'o':
      await _handleOrganizations(command, parsers, scriptDir);
    case 'transactions':
    case 't':
      await _handleTransactions(command, parsers, scriptDir);
    case 'demo':
    case 'd':
      await _handleDemo(command, parsers, scriptDir);
    default:
      stderr.writeln('Unknown command "${command.name}".');
      _printTopLevelUsage(parsers);
      exitCode = 64;
  }
}

// Helper functions to reduce duplication

/// Parses the output format from command args and exits on error.
/// Returns null if there was an error (after setting exitCode).
_OutputFormat? _parseOutputFormatOrExit(ArgResults command) {
  try {
    return _parseOutputFormat(command['output-format'] as String?);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return null;
  }
}

/// Gets the access URL from command args or environment.
/// Returns null and exits if no URL is available (after setting exitCode).
String? _getAccessUrlOrExit(ArgResults command, Directory scriptDir) {
  final accessUrlOverride = (command['url'] as String?)
      ?.trim()
      .maybeEmptyToNull();
  final envContext = _loadEnvContext(scriptDir);
  final accessUrl = accessUrlOverride ?? envContext.accessUrl;
  if (accessUrl == null) {
    stderr
      ..writeln('No access URL provided.')
      ..writeln(
        'Set SIMPLEFIN_ACCESS_URL in ${envContext.displayPath} or pass --url.',
      );
    exitCode = 64;
    return null;
  }
  return accessUrl;
}

/// Wraps data with server messages for JSON output.
dynamic _wrapWithServerMessages(dynamic data, List<String> serverMessages) =>
    serverMessages.isEmpty
    ? data
    : {'server-messages': serverMessages, 'data': data};

Future<void> _handleClaim(
  ArgResults command,
  _ParserBundle parsers,
  Directory scriptDir,
) async {
  if (command['help'] as bool) {
    _printClaimUsage(parsers);
    return;
  }

  final rest = command.rest;
  if (rest.isEmpty) {
    stderr.writeln('Missing setup token.');
    _printClaimUsage(parsers);
    exitCode = 64;
    return;
  }

  final setupToken = rest.first;
  final bridgeRoot = command['bridge'] as String;
  final envPathDisplay = '${scriptDir.path}/.env';

  final client = SimplefinBridgeClient(root: Uri.parse(bridgeRoot));
  stdout.writeln('Claiming access URL from setup token...');
  try {
    final credentials = await client.claimAccessCredentials(setupToken);
    stdout
      ..writeln('SIMPLEFIN_ACCESS_URL=${credentials.accessUrl}')
      ..writeln(
        'Redirect or copy the line above into your .env file '
        '(e.g. >> $envPathDisplay).',
      );
  } on SimplefinException catch (error) {
    stderr.writeln('Failed to claim access URL: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<void> _handleInfo(ArgResults command, _ParserBundle parsers) async {
  if (command['help'] as bool) {
    _printInfoUsage(parsers);
    return;
  }

  final bridgeRoot = command['bridge'] as String;
  final client = SimplefinBridgeClient(root: Uri.parse(bridgeRoot));
  try {
    final info = await client.getInfo();
    if (info.versions.isEmpty) {
      stdout.writeln('No protocol versions reported by the bridge.');
    } else {
      stdout.writeln('Bridge supports the following protocol versions:');
      for (final version in info.versions) {
        stdout.writeln('- $version');
      }
    }
  } on SimplefinException catch (error) {
    stderr.writeln('Failed to fetch bridge info: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<void> _handleAccounts(
  ArgResults command,
  _ParserBundle parsers,
  Directory scriptDir,
) async {
  if (command['help'] as bool) {
    _printAccountsUsage(parsers);
    return;
  }

  final format = _parseOutputFormatOrExit(command);
  if (format == null) return;

  final accessUrl = _getAccessUrlOrExit(command, scriptDir);
  if (accessUrl == null) return;

  final orgIdFilter = (command['org-id'] as String?)?.trim().maybeEmptyToNull();
  final credentials = SimplefinAccessCredentials.parse(accessUrl);
  final client = SimplefinAccessClient(credentials: credentials);
  try {
    var accountSet = await client.getAccounts(balancesOnly: true);

    if (orgIdFilter != null) {
      accountSet = accountSet.filterByOrganizationId(orgIdFilter);
    }

    if (accountSet.accounts.isEmpty) {
      stdout.writeln(
        orgIdFilter == null
            ? 'No accounts returned by the bridge.'
            : 'No accounts found for organization "$orgIdFilter".',
      );
      return;
    }

    switch (format) {
      case _OutputFormat.text:
        _printAccountsMarkdown(accountSet.accounts, accountSet.serverMessages);
      case _OutputFormat.json:
        final jsonOutput = _wrapWithServerMessages(
          accountSet.accounts.map(_accountSummaryJson).toList(),
          accountSet.serverMessages,
        );
        stdout.writeln(_jsonEncoder.convert(jsonOutput));
      case _OutputFormat.csv:
        stdout.writeln(
          _accountsCsv(
            accountSet.accounts,
            accountSet.serverMessages,
          ).trimRight(),
        );
    }
  } on SimplefinException catch (error) {
    stderr.writeln('Failed to fetch accounts: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<void> _handleOrganizations(
  ArgResults command,
  _ParserBundle parsers,
  Directory scriptDir,
) async {
  if (command['help'] as bool) {
    _printOrganizationsUsage(parsers);
    return;
  }

  final format = _parseOutputFormatOrExit(command);
  if (format == null) return;

  final accessUrl = _getAccessUrlOrExit(command, scriptDir);
  if (accessUrl == null) return;

  final credentials = SimplefinAccessCredentials.parse(accessUrl);
  final client = SimplefinAccessClient(credentials: credentials);
  try {
    final accountSet = await client.getAccounts(balancesOnly: true);

    final organizationsMap = <String, SimplefinOrganization>{};
    for (final account in accountSet.accounts) {
      final org = account.org;
      organizationsMap.putIfAbsent(_organizationKey(org), () => org);
    }

    if (organizationsMap.isEmpty) {
      stdout.writeln('No organizations returned by the bridge.');
      return;
    }

    final organizations = organizationsMap.values.toList()
      ..sort(
        (a, b) =>
            _organizationDisplayName(a).compareTo(_organizationDisplayName(b)),
      );

    switch (format) {
      case _OutputFormat.text:
        _printOrganizationsMarkdown(organizations, accountSet.serverMessages);
      case _OutputFormat.json:
        final jsonData = organizations.length == 1
            ? _organizationJson(organizations.first)
            : organizations.map(_organizationJson).toList();
        final jsonOutput = _wrapWithServerMessages(
          jsonData,
          accountSet.serverMessages,
        );
        stdout.writeln(_jsonEncoder.convert(jsonOutput));
      case _OutputFormat.csv:
        stdout.writeln(
          _organizationsCsv(
            organizations,
            accountSet.serverMessages,
          ).trimRight(),
        );
    }
  } on SimplefinException catch (error) {
    stderr.writeln('Failed to fetch organizations: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<void> _handleTransactions(
  ArgResults command,
  _ParserBundle parsers,
  Directory scriptDir,
) async {
  if (command['help'] as bool) {
    _printTransactionsUsage(parsers);
    return;
  }

  final accountId = (command['account'] as String?)?.trim().maybeEmptyToNull();

  final format = _parseOutputFormatOrExit(command);
  if (format == null) return;

  final accessUrl = _getAccessUrlOrExit(command, scriptDir);
  if (accessUrl == null) return;

  DateTime? startDate;
  DateTime? endDate;
  try {
    startDate = _parseDateOption(command['start-date'] as String?);
    endDate = _parseDateOption(command['end-date'] as String?);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }

  final includePending = command['pending'] as bool;

  startDate ??= DateTime.now().toUtc().subtract(const Duration(days: 30));

  final credentials = SimplefinAccessCredentials.parse(accessUrl);
  final client = SimplefinAccessClient(credentials: credentials);
  try {
    final accountSet = await client.getAccounts(
      startDate: startDate,
      endDate: endDate,
      includePending: includePending,
      accountIds: accountId == null ? null : [accountId],
      balancesOnly: false,
    );

    if (accountSet.accounts.isEmpty) {
      switch (format) {
        case _OutputFormat.text:
          stdout.writeln(
            accountId == null
                ? 'No transactions returned by the bridge.'
                : 'No account returned for ID "$accountId".',
          );
          return;
        case _OutputFormat.json:
          stdout.writeln('[]');
          return;
        case _OutputFormat.csv:
          stdout.writeln(
            _transactionsCsv(
              const <SimplefinAccount>[],
              accountSet.serverMessages,
            ).trimRight(),
          );
          return;
      }
    }

    final accounts = accountSet.accounts;
    final transactions = accounts
        .expand(
          (account) => account.transactions.map(
            (transaction) => (account: account, transaction: transaction),
          ),
        )
        .toList();

    if (transactions.isEmpty) {
      switch (format) {
        case _OutputFormat.text:
          stdout.writeln('No transactions returned.');
          return;
        case _OutputFormat.json:
          stdout.writeln('[]');
          return;
        case _OutputFormat.csv:
          stdout.writeln(
            _transactionsCsv(
              const <SimplefinAccount>[],
              accountSet.serverMessages,
            ).trimRight(),
          );
          return;
      }
    }

    switch (format) {
      case _OutputFormat.text:
        _printTransactionsMarkdown(transactions, accountSet.serverMessages);
      case _OutputFormat.json:
        final jsonData = transactions
            .map((pair) => _transactionJson(pair.transaction, pair.account))
            .toList();
        final jsonOutput = _wrapWithServerMessages(
          jsonData,
          accountSet.serverMessages,
        );
        stdout.writeln(_jsonEncoder.convert(jsonOutput));
      case _OutputFormat.csv:
        stdout.writeln(
          _transactionsCsv(accounts, accountSet.serverMessages).trimRight(),
        );
    }
  } on SimplefinException catch (error) {
    stderr.writeln('Failed to fetch transactions: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<void> _handleDemo(
  ArgResults command,
  _ParserBundle parsers,
  Directory scriptDir,
) async {
  if (command['help'] as bool) {
    _printDemoUsage(parsers);
    return;
  }

  final accessUrl = _getAccessUrlOrExit(command, scriptDir);
  if (accessUrl == null) return;

  stdout.writeln('🎬 SimpleFIN CLI Demo Mode');
  stdout.writeln('=' * 60);
  stdout.writeln('Running all commands to demonstrate functionality...');
  stdout.writeln();

  final credentials = SimplefinAccessCredentials.parse(accessUrl);
  final client = SimplefinAccessClient(credentials: credentials);

  try {
    // Step 1: Fetch organizations in all formats
    stdout.writeln('📋 Step 1: Fetching organizations...');
    stdout.writeln('-' * 60);
    stdout.writeln();

    final accountSet = await client.getAccounts(balancesOnly: true);
    final organizationsMap = <String, SimplefinOrganization>{};
    for (final account in accountSet.accounts) {
      final org = account.org;
      organizationsMap.putIfAbsent(_organizationKey(org), () => org);
    }
    final organizations = organizationsMap.values.toList();

    if (organizations.isEmpty) {
      stdout.writeln('❌ No organizations found. Cannot continue demo.');
      return;
    }

    stdout.writeln('💻 Command: dart run example/main.dart o');
    stdout.writeln('✓ Text format:');
    _printOrganizationsMarkdown(organizations, accountSet.serverMessages);
    stdout.writeln();

    stdout.writeln('💻 Command: dart run example/main.dart o -f json');
    stdout.writeln('✓ JSON format:');
    final orgJsonData = organizations.length == 1
        ? _organizationJson(organizations.first)
        : organizations.map(_organizationJson).toList();
    stdout.writeln(
      _jsonEncoder.convert(
        _wrapWithServerMessages(orgJsonData, accountSet.serverMessages),
      ),
    );
    stdout.writeln();

    stdout.writeln('💻 Command: dart run example/main.dart o -f csv');
    stdout.writeln('✓ CSV format:');
    stdout.writeln(
      _organizationsCsv(organizations, accountSet.serverMessages).trimRight(),
    );
    stdout.writeln();

    // Step 2: Get first organization ID
    final firstOrgId = organizations.first.id;
    if (firstOrgId == null) {
      stdout.writeln(
        '❌ First organization has no ID. Skipping org filter demo.',
      );
    } else {
      stdout.writeln(
        '📋 Step 2: Fetching accounts for organization "$firstOrgId"...',
      );
      stdout.writeln('-' * 60);
      stdout.writeln();

      final filteredAccountSet = accountSet.filterByOrganizationId(firstOrgId);

      stdout.writeln('💻 Command: dart run example/main.dart a -o $firstOrgId');
      stdout.writeln('✓ Text format:');
      _printAccountsMarkdown(
        filteredAccountSet.accounts,
        filteredAccountSet.serverMessages,
      );
      stdout.writeln();

      stdout.writeln(
        '💻 Command: dart run example/main.dart a -o $firstOrgId -f json',
      );
      stdout.writeln('✓ JSON format:');
      stdout.writeln(
        _jsonEncoder.convert(
          _wrapWithServerMessages(
            filteredAccountSet.accounts.map(_accountSummaryJson).toList(),
            filteredAccountSet.serverMessages,
          ),
        ),
      );
      stdout.writeln();

      stdout.writeln(
        '💻 Command: dart run example/main.dart a -o $firstOrgId -f csv',
      );
      stdout.writeln('✓ CSV format:');
      stdout.writeln(
        _accountsCsv(
          filteredAccountSet.accounts,
          filteredAccountSet.serverMessages,
        ).trimRight(),
      );
      stdout.writeln();
    }

    // Step 3: Fetch all accounts (no filter)
    stdout.writeln('📋 Step 3: Fetching all accounts...');
    stdout.writeln('-' * 60);
    stdout.writeln();

    stdout.writeln('💻 Command: dart run example/main.dart a');
    stdout.writeln('✓ Text format:');
    _printAccountsMarkdown(accountSet.accounts, accountSet.serverMessages);
    stdout.writeln();

    stdout.writeln('💻 Command: dart run example/main.dart a -f json');
    stdout.writeln('✓ JSON format:');
    stdout.writeln(
      _jsonEncoder.convert(
        _wrapWithServerMessages(
          accountSet.accounts.map(_accountSummaryJson).toList(),
          accountSet.serverMessages,
        ),
      ),
    );
    stdout.writeln();

    stdout.writeln('💻 Command: dart run example/main.dart a -f csv');
    stdout.writeln('✓ CSV format:');
    stdout.writeln(
      _accountsCsv(accountSet.accounts, accountSet.serverMessages).trimRight(),
    );
    stdout.writeln();

    // Step 4: Fetch transactions for first account
    if (accountSet.accounts.isEmpty) {
      stdout.writeln('❌ No accounts found. Skipping transactions demo.');
    } else {
      final firstAccount = accountSet.accounts.first;
      final sevenDaysAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 7),
      );
      final startDate = sevenDaysAgo.toUtc().toIso8601String();

      stdout.writeln(
        '📋 Step 4: Fetching transactions for "${firstAccount.name}"...',
      );
      stdout.writeln('   (from $startDate)');
      stdout.writeln('-' * 60);
      stdout.writeln();

      final txAccountSet = await client.getAccounts(
        startDate: sevenDaysAgo,
        includePending: false,
      );

      final accounts = <SimplefinAccount>[];
      for (final account in txAccountSet.accounts) {
        if (account.id == firstAccount.id && account.transactions.isNotEmpty) {
          accounts.add(account);
        }
      }

      if (accounts.isEmpty) {
        stdout.writeln('ℹ️  No transactions found in the last 7 days.');
      } else {
        final transactions = accounts
            .expand(
              (account) => account.transactions.map(
                (transaction) => (account: account, transaction: transaction),
              ),
            )
            .toList();

        stdout.writeln(
          '💻 Command: dart run example/main.dart t -a ${firstAccount.id} -s $startDate',
        );
        stdout.writeln('✓ Text format:');
        _printTransactionsMarkdown(transactions, txAccountSet.serverMessages);
        stdout.writeln();

        stdout.writeln(
          '💻 Command: dart run example/main.dart t -a ${firstAccount.id} -s $startDate -f json',
        );
        stdout.writeln('✓ JSON format:');
        final txJsonData = transactions
            .map((pair) => _transactionJson(pair.transaction, pair.account))
            .toList();
        stdout.writeln(
          _jsonEncoder.convert(
            _wrapWithServerMessages(txJsonData, txAccountSet.serverMessages),
          ),
        );
        stdout.writeln();

        stdout.writeln(
          '💻 Command: dart run example/main.dart t -a ${firstAccount.id} -s $startDate -f csv',
        );
        stdout.writeln('✓ CSV format:');
        stdout.writeln(
          _transactionsCsv(accounts, txAccountSet.serverMessages).trimRight(),
        );
        stdout.writeln();
      }
    }

    stdout.writeln('=' * 60);
    stdout.writeln('🎉 Demo completed successfully!');
    stdout.writeln();
  } on SimplefinException catch (error) {
    stderr.writeln('❌ Demo failed: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

void _printAccountsMarkdown(
  Iterable<SimplefinAccount> accounts,
  List<String> serverMessages,
) {
  _printServerMessages(serverMessages);

  for (final account in accounts) {
    stdout
      ..writeln('# Account: ${account.name}')
      ..writeln('- ID: ${account.id}')
      ..writeln('- Balance: ${account.balance}')
      ..writeln('- Currency: ${account.currency}')
      ..writeln(
        '- Balance Date: ${account.balanceDate.toUtc().toIso8601String()}',
      );
    if (account.availableBalance != null) {
      stdout.writeln('- Available Balance: ${account.availableBalance}');
    }
    stdout.writeln('- Organization ID: ${account.org.id ?? ''}');

    stdout.writeln();
  }
}

void _printOrganizationsMarkdown(
  List<SimplefinOrganization> organizations,
  List<String> serverMessages,
) {
  _printServerMessages(serverMessages);

  for (final org in organizations) {
    stdout
      ..writeln('# Organization: ${_organizationDisplayName(org)}')
      ..writeln('- ID: ${org.id ?? ''}')
      ..writeln('- Domain: ${org.domain ?? ''}')
      ..writeln('- URL: ${org.url?.toString() ?? ''}')
      ..writeln('- SimpleFIN URL: ${org.sfinUrl}')
      ..writeln();
  }
}

void _printTransactionsMarkdown(
  List<({SimplefinAccount account, SimplefinTransaction transaction})>
  transactions,
  List<String> serverMessages,
) {
  _printServerMessages(serverMessages);

  for (final pair in transactions) {
    final account = pair.account;
    final transaction = pair.transaction;
    stdout
      ..writeln('# Transaction: ${transaction.description}')
      ..writeln('- Account ID: ${account.id}')
      ..writeln('- Transaction ID: ${transaction.id}')
      ..writeln('- Amount: ${transaction.amount}')
      ..writeln('- Posted: ${transaction.posted.toUtc().toIso8601String()}');
    if (transaction.transactedAt != null) {
      final transactedAt = transaction.transactedAt!.toUtc().toIso8601String();
      stdout.writeln('- Transacted At: $transactedAt');
    }
    stdout
      ..writeln('- Pending: ${transaction.pending ? 'yes' : 'no'}')
      ..writeln();
  }
}

void _printServerMessages(List<String> serverMessages) {
  if (serverMessages.isEmpty) return;

  stdout.writeln('# Server Messages');
  for (final message in serverMessages) {
    stdout.writeln('- $message');
  }
  stdout.writeln();
}

String _formatServerMessagesForCsv(List<String> serverMessages) =>
    serverMessages.isEmpty ? '' : serverMessages.join('; ');

String _accountsCsv(
  Iterable<SimplefinAccount> accounts,
  List<String> serverMessages,
) {
  final serverMessagesField = _formatServerMessagesForCsv(serverMessages);

  final rows = <List<dynamic>>[
    [
      'account_id',
      'account_name',
      'currency',
      'balance',
      'available_balance',
      'balance_date',
      'org_id',
      'server_messages',
    ],
  ];

  var isFirstRow = true;
  for (final account in accounts) {
    rows.add([
      account.id,
      account.name,
      account.currency,
      account.balance.toString(),
      account.availableBalance?.toString() ?? '',
      account.balanceDate.toUtc().toIso8601String(),
      account.org.id ?? '',
      if (isFirstRow) serverMessagesField else '',
    ]);
    isFirstRow = false;
  }

  return const ListToCsvConverter().convert(rows);
}

Map<String, dynamic> _accountSummaryJson(SimplefinAccount account) =>
    {
      'id': account.id,
      'name': account.name,
      'balance': account.balance.toString(),
      'available-balance':
          account.availableBalance?.toString() ?? account.balance.toString(),
      'currency': account.currency,
      'balance-date': account.balanceDate.toUtc().toIso8601String(),
      'org-id': account.org.id,
    }..removeWhere(
      (_, value) => value == null || (value is String && value.isEmpty),
    );

String _organizationKey(SimplefinOrganization organization) =>
    organization.id ?? organization.domain ?? organization.sfinUrl.toString();

String _organizationDisplayName(SimplefinOrganization organization) =>
    organization.name ??
    organization.domain ??
    organization.id ??
    organization.sfinUrl.toString();

Map<String, dynamic> _organizationJson(SimplefinOrganization organization) {
  final json = <String, dynamic>{
    'id': organization.id,
    'name': organization.name,
    'domain': organization.domain,
    'url': organization.url?.toString(),
    'sfin-url': organization.sfinUrl.toString(),
  };
  json.removeWhere(
    (_, value) => value == null || (value is String && value.isEmpty),
  );
  return json;
}

String _transactionsCsv(
  List<SimplefinAccount> accounts,
  List<String> serverMessages,
) {
  final serverMessagesField = _formatServerMessagesForCsv(serverMessages);

  final rows = <List<dynamic>>[
    [
      'account_id',
      'transaction_id',
      'posted',
      'amount',
      'description',
      'pending',
      'transacted_at',
      'server_messages',
    ],
  ];

  var isFirstRow = true;
  for (final account in accounts) {
    for (final transaction in account.transactions) {
      rows.add([
        account.id,
        transaction.id,
        transaction.posted.toUtc().toIso8601String(),
        transaction.amount.toString(),
        transaction.description,
        transaction.pending,
        transaction.transactedAt?.toUtc().toIso8601String() ?? '',
        if (isFirstRow) serverMessagesField else '',
      ]);
      isFirstRow = false;
    }
  }

  return const ListToCsvConverter().convert(rows);
}

Map<String, dynamic> _transactionJson(
  SimplefinTransaction transaction,
  SimplefinAccount account,
) => {
  'account-id': account.id,
  'transaction-id': transaction.id,
  'posted': transaction.posted.toUtc().toIso8601String(),
  'amount': transaction.amount.toString(),
  'description': transaction.description,
  'pending': transaction.pending,
  if (transaction.transactedAt != null)
    'transacted-at': transaction.transactedAt!.toUtc().toIso8601String(),
};

String _organizationsCsv(
  List<SimplefinOrganization> organizations,
  List<String> serverMessages,
) {
  final serverMessagesField = _formatServerMessagesForCsv(serverMessages);

  final rows = <List<dynamic>>[
    ['id', 'name', 'domain', 'url', 'sfin_url', 'server_messages'],
  ];

  var isFirstRow = true;
  for (final org in organizations) {
    rows.add([
      org.id ?? '',
      org.name ?? '',
      org.domain ?? '',
      org.url?.toString() ?? '',
      org.sfinUrl.toString(),
      if (isFirstRow) serverMessagesField else '',
    ]);
    isFirstRow = false;
  }

  return const ListToCsvConverter().convert(rows);
}

void _printTopLevelUsage(_ParserBundle parsers) {
  stdout
    ..writeln('Usage: dart run example/main.dart <command> [arguments]')
    ..writeln()
    ..writeln('Available commands:')
    ..writeln('  claim         Exchange a setup token for an access URL.')
    ..writeln(
      '  info          Query the SimpleFIN bridge for supported versions.',
    )
    ..writeln('  accounts      Retrieve account balances.')
    ..writeln('  organizations List organizations referenced by accounts.')
    ..writeln('  transactions  Retrieve transactions for a specific account.')
    ..writeln('  demo          Run all commands to demonstrate functionality.')
    ..writeln()
    ..writeln('Run `dart run example/main.dart <command> --help` for details.');
}

void _printClaimUsage(_ParserBundle parsers) {
  stdout
    ..writeln('Usage: dart run example/main.dart claim [options] <setup_token>')
    ..writeln()
    ..writeln(parsers.claim.usage);
}

void _printInfoUsage(_ParserBundle parsers) {
  stdout
    ..writeln('Usage: dart run example/main.dart info [options]')
    ..writeln()
    ..writeln(parsers.info.usage);
}

void _printAccountsUsage(_ParserBundle parsers) {
  stdout
    ..writeln('Usage: dart run example/main.dart accounts [options]')
    ..writeln()
    ..writeln(parsers.accounts.usage);
}

void _printOrganizationsUsage(_ParserBundle parsers) {
  stdout
    ..writeln('Usage: dart run example/main.dart organizations [options]')
    ..writeln()
    ..writeln(parsers.organizations.usage);
}

void _printTransactionsUsage(_ParserBundle parsers) {
  stdout
    ..writeln('Usage: dart run example/main.dart transactions [options]')
    ..writeln()
    ..writeln(parsers.transactions.usage);
}

void _printDemoUsage(_ParserBundle parsers) {
  stdout
    ..writeln('Usage: dart run example/main.dart demo [options]')
    ..writeln()
    ..writeln('Run all commands in sequence to demonstrate CLI functionality.')
    ..writeln(
      'This executes organizations, accounts, and transactions commands',
    )
    ..writeln('in all output formats (text, JSON, CSV) to showcase features.')
    ..writeln()
    ..writeln(parsers.demo.usage);
}

DateTime? _parseDateOption(String? rawValue) {
  final value = rawValue?.trim().maybeEmptyToNull();
  if (value == null) {
    return null;
  }
  final asInt = int.tryParse(value);
  if (asInt != null) {
    return DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true);
  }
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException(
      'Unable to parse date "$value". '
      'Use ISO-8601 (e.g. 2024-01-31T00:00:00Z) or epoch seconds.',
    );
  }
}

_OutputFormat _parseOutputFormat(String? rawValue) {
  final value = (rawValue ?? 'text').toLowerCase();
  switch (value) {
    case 'text':
      return _OutputFormat.text;
    case 'json':
      return _OutputFormat.json;
    case 'csv':
      return _OutputFormat.csv;
    default:
      throw FormatException('Unknown output format "$rawValue".');
  }
}

_EnvContext _loadEnvContext(Directory scriptDir) {
  final envFile = _locateEnvFile(scriptDir);
  if (envFile == null) {
    return _EnvContext(null, '${scriptDir.path}/.env', null);
  }
  final env = dotenv.DotEnv(includePlatformEnvironment: true);
  env.load(<String>[envFile.path]);
  final accessUrl = env['SIMPLEFIN_ACCESS_URL']?.trim().maybeEmptyToNull();
  return _EnvContext(envFile, envFile.path, accessUrl);
}

File? _locateEnvFile(Directory scriptDir) {
  final candidate = File('${scriptDir.path}/.env');
  if (candidate.existsSync()) {
    return candidate;
  }
  return null;
}

class _ParserBundle {
  _ParserBundle({
    required this.root,
    required this.claim,
    required this.info,
    required this.accounts,
    required this.organizations,
    required this.transactions,
    required this.demo,
  });

  factory _ParserBundle.build() {
    final root = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      );

    final claim = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for claim.',
      )
      ..addOption(
        'bridge',
        abbr: 'b',
        help: 'SimpleFIN bridge root URL (default: $defaultBridgeRootUrl).',
        defaultsTo: defaultBridgeRootUrl,
      );
    root
      ..addCommand('claim', claim)
      ..addCommand('c', claim);

    final info = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for info.',
      )
      ..addOption(
        'bridge',
        abbr: 'b',
        help: 'SimpleFIN bridge root URL (default: $defaultBridgeRootUrl).',
        defaultsTo: defaultBridgeRootUrl,
      );
    root
      ..addCommand('info', info)
      ..addCommand('i', info);

    final accounts = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for accounts.',
      )
      ..addOption(
        'url',
        abbr: 'u',
        help:
            'SimpleFIN access URL (default: value from example/.env if present).',
      )
      ..addOption(
        'org-id',
        abbr: 'o',
        help: 'Restrict results to a specific organization ID.',
        valueHelp: 'ORG_ID',
      )
      ..addOption(
        'output-format',
        abbr: 'f',
        defaultsTo: 'text',
        allowed: const ['text', 'json', 'csv'],
        help: 'Output format: text, json, or csv (default: text).',
      );
    root
      ..addCommand('accounts', accounts)
      ..addCommand('a', accounts);

    final organizations = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for organizations.',
      )
      ..addOption(
        'url',
        abbr: 'u',
        help:
            'SimpleFIN access URL (default: value from example/.env if present).',
      )
      ..addOption(
        'output-format',
        abbr: 'f',
        defaultsTo: 'text',
        allowed: const ['text', 'json', 'csv'],
        help: 'Output format: text, json, or csv (default: text).',
      );
    root
      ..addCommand('organizations', organizations)
      ..addCommand('o', organizations);

    final transactions = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for transactions.',
      )
      ..addOption(
        'url',
        abbr: 'u',
        help:
            'SimpleFIN access URL (default: value from example/.env if present).',
      )
      ..addOption(
        'start-date',
        abbr: 's',
        help:
            'Include transactions on/after this date '
            '(ISO-8601 or epoch seconds). '
            'Default: 30 days ago when omitted.',
      )
      ..addOption(
        'end-date',
        abbr: 'e',
        help:
            'Include transactions before this date '
            '(ISO-8601 or epoch seconds). '
            'Default: now.',
      )
      ..addFlag(
        'pending',
        negatable: false,
        help: 'Include pending transactions when supported (default: off).',
      )
      ..addOption(
        'account',
        abbr: 'a',
        help: 'Filter to a specific account ID.',
        valueHelp: 'ID',
      )
      ..addOption(
        'output-format',
        abbr: 'f',
        defaultsTo: 'text',
        allowed: const ['text', 'json', 'csv'],
        help: 'Output format: text, json, or csv (default: text).',
      );
    root
      ..addCommand('transactions', transactions)
      ..addCommand('t', transactions);

    final demo = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for demo.',
      )
      ..addOption(
        'url',
        abbr: 'u',
        help: 'SimpleFIN access URL (overrides environment).',
      );
    root
      ..addCommand('demo', demo)
      ..addCommand('d', demo);

    return _ParserBundle(
      root: root,
      claim: claim,
      info: info,
      accounts: accounts,
      organizations: organizations,
      transactions: transactions,
      demo: demo,
    );
  }

  final ArgParser root;
  final ArgParser claim;
  final ArgParser info;
  final ArgParser accounts;
  final ArgParser organizations;
  final ArgParser transactions;
  final ArgParser demo;
}

class _EnvContext {
  _EnvContext(this.file, this.displayPath, this.accessUrl);

  final File? file;
  final String displayPath;
  final String? accessUrl;
}

const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

enum _OutputFormat { text, json, csv }

extension on String? {
  String? maybeEmptyToNull() {
    if (this == null) return null;
    final trimmed = this!.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
