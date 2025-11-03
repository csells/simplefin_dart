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
      break;
    case 'info':
    case 'i':
      await _handleInfo(command, parsers);
      break;
    case 'accounts':
    case 'a':
      await _handleAccounts(command, parsers, scriptDir);
      break;
    case 'organizations':
    case 'o':
      await _handleOrganizations(command, parsers, scriptDir);
      break;
    case 'transactions':
    case 't':
      await _handleTransactions(command, parsers, scriptDir);
      break;
    default:
      stderr.writeln('Unknown command "${command.name}".');
      _printTopLevelUsage(parsers);
      exitCode = 64;
  }
}

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
        'Redirect or copy the line above into your .env file (e.g. >> $envPathDisplay).',
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

  _OutputFormat format;
  try {
    format = _parseOutputFormat(command['output-format'] as String?);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }
  final accessUrlOverride = (command['access-url'] as String?)
      ?.trim()
      .maybeEmptyToNull();
  final envContext = _loadEnvContext(scriptDir);
  final accessUrl = accessUrlOverride ?? envContext.accessUrl;
  if (accessUrl == null) {
    stderr
      ..writeln('No access URL provided.')
      ..writeln(
        'Set SIMPLEFIN_ACCESS_URL in ${envContext.displayPath} or pass --access-url.',
      );
    exitCode = 64;
    return;
  }

  final accountFilters = List<String>.from(command['account'] as List);

  final credentials = SimplefinAccessCredentials.parse(accessUrl);
  final client = SimplefinAccessClient(credentials: credentials);
  try {
    final accountSet = await client.getAccounts(
      accountIds: accountFilters.isEmpty ? null : accountFilters,
      balancesOnly: true,
    );

    _printBridgeErrors(accountSet.errors);

    if (accountSet.accounts.isEmpty) {
      stdout.writeln('No accounts returned by the bridge.');
      return;
    }

    switch (format) {
      case _OutputFormat.text:
        _printAccountsMarkdown(accountSet);
        break;
      case _OutputFormat.json:
        stdout.writeln(
          _jsonEncoder.convert(
            accountSet.accounts.map(_accountSummaryJson).toList(),
          ),
        );
        break;
      case _OutputFormat.csv:
        stdout.writeln(
          _accountsCsv(accountSet, includeTransactions: false).trimRight(),
        );
        break;
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

  _OutputFormat format;
  try {
    format = _parseOutputFormat(command['output-format'] as String?);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }

  final accessUrlOverride = (command['access-url'] as String?)
      ?.trim()
      .maybeEmptyToNull();
  final envContext = _loadEnvContext(scriptDir);
  final accessUrl = accessUrlOverride ?? envContext.accessUrl;
  if (accessUrl == null) {
    stderr
      ..writeln('No access URL provided.')
      ..writeln(
        'Set SIMPLEFIN_ACCESS_URL in ${envContext.displayPath} or pass --access-url.',
      );
    exitCode = 64;
    return;
  }

  final credentials = SimplefinAccessCredentials.parse(accessUrl);
  final client = SimplefinAccessClient(credentials: credentials);
  try {
    final accountSet = await client.getAccounts(balancesOnly: true);

    _printBridgeErrors(accountSet.errors);

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
        _printOrganizationsMarkdown(organizations);
        break;
      case _OutputFormat.json:
        stdout.writeln(
          _jsonEncoder.convert(
            organizations.length == 1
                ? _organizationJson(organizations.first)
                : organizations.map(_organizationJson).toList(),
          ),
        );
        break;
      case _OutputFormat.csv:
        stdout.writeln(_organizationsCsv(organizations).trimRight());
        break;
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

  final rest = command.rest;
  final accountId = rest.isEmpty ? null : rest.first.trim().maybeEmptyToNull();

  _OutputFormat format;
  try {
    format = _parseOutputFormat(command['output-format'] as String?);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }
  final accessUrlOverride = (command['access-url'] as String?)
      ?.trim()
      .maybeEmptyToNull();
  final envContext = _loadEnvContext(scriptDir);
  final accessUrl = accessUrlOverride ?? envContext.accessUrl;
  if (accessUrl == null) {
    stderr
      ..writeln('No access URL provided.')
      ..writeln(
        'Set SIMPLEFIN_ACCESS_URL in ${envContext.displayPath} or pass --access-url.',
      );
    exitCode = 64;
    return;
  }

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

    _printBridgeErrors(accountSet.errors);

    if (accountSet.accounts.isEmpty) {
      switch (format) {
        case _OutputFormat.text:
          stdout.writeln(
            accountId == null
                ? 'No transactions returned by the bridge.'
                : 'No account returned for ID "$accountId".',
          );
          break;
        case _OutputFormat.json:
          stdout.writeln('[]');
          break;
        case _OutputFormat.csv:
          stdout.writeln(
            _transactionsCsv(const <SimplefinAccount>[]).trimRight(),
          );
          break;
      }
      return;
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
          break;
        case _OutputFormat.json:
          stdout.writeln('[]');
          break;
        case _OutputFormat.csv:
          stdout.writeln(
            _transactionsCsv(const <SimplefinAccount>[]).trimRight(),
          );
          break;
      }
      return;
    }

    switch (format) {
      case _OutputFormat.text:
        _printTransactionsMarkdown(transactions);
        break;
      case _OutputFormat.json:
        stdout.writeln(
          _jsonEncoder.convert(
            transactions
                .map((pair) => _transactionJson(pair.transaction, pair.account))
                .toList(),
          ),
        );
        break;
      case _OutputFormat.csv:
        stdout.writeln(_transactionsCsv(accounts).trimRight());
        break;
    }
  } on SimplefinException catch (error) {
    stderr.writeln('Failed to fetch transactions: $error');
    exitCode = 1;
  } finally {
    client.close();
  }
}

void _printAccountsMarkdown(SimplefinAccountSet accountSet) {
  for (final account in accountSet.accounts) {
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

void _printOrganizationsMarkdown(List<SimplefinOrganization> organizations) {
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
) {
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
      stdout.writeln(
        '- Transacted At: ${transaction.transactedAt!.toUtc().toIso8601String()}',
      );
    }
    stdout
      ..writeln('- Pending: ${transaction.pending ? 'yes' : 'no'}')
      ..writeln();
  }
}

String _accountsCsv(
  SimplefinAccountSet accountSet, {
  required bool includeTransactions,
}) {
  final rows = <List<dynamic>>[
    if (includeTransactions)
      [
        'record_type',
        'account_id',
        'account_name',
        'currency',
        'balance',
        'available_balance',
        'balance_date',
        'org_id',
        'transaction_id',
        'posted',
        'amount',
        'description',
        'pending',
        'transacted_at',
      ]
    else
      [
        'account_id',
        'account_name',
        'currency',
        'balance',
        'available_balance',
        'balance_date',
        'org_id',
      ],
  ];

  for (final account in accountSet.accounts) {
    if (includeTransactions) {
      rows.add([
        'account',
        account.id,
        account.name,
        account.currency,
        account.balance.toString(),
        account.availableBalance?.toString() ?? '',
        account.balanceDate.toUtc().toIso8601String(),
        account.org.id ?? '',
        '',
        '',
        '',
        '',
        '',
        '',
      ]);
    } else {
      rows.add([
        account.id,
        account.name,
        account.currency,
        account.balance.toString(),
        account.availableBalance?.toString() ?? '',
        account.balanceDate.toUtc().toIso8601String(),
        account.org.id ?? '',
      ]);
      continue;
    }

    for (final transaction in account.transactions) {
      rows.add([
        'transaction',
        account.id,
        account.name,
        account.currency,
        '',
        '',
        '',
        '',
        '',
        '',
        transaction.id,
        transaction.posted.toUtc().toIso8601String(),
        transaction.amount.toString(),
        transaction.description,
        transaction.pending,
        transaction.transactedAt?.toUtc().toIso8601String() ?? '',
      ]);
    }
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

String _organizationKey(SimplefinOrganization organization) {
  return organization.id ??
      organization.domain ??
      organization.sfinUrl.toString();
}

String _organizationDisplayName(SimplefinOrganization organization) {
  return organization.name ??
      organization.domain ??
      organization.id ??
      organization.sfinUrl.toString();
}

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

String _transactionsCsv(List<SimplefinAccount> accounts) {
  final rows = <List<dynamic>>[
    [
      'account_id',
      'transaction_id',
      'posted',
      'amount',
      'description',
      'pending',
      'transacted_at',
    ],
  ];

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
      ]);
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

String _organizationsCsv(List<SimplefinOrganization> organizations) {
  final rows = <List<dynamic>>[
    ['id', 'name', 'domain', 'url', 'sfin_url'],
  ];

  for (final org in organizations) {
    rows.add([
      org.id ?? '',
      org.name ?? '',
      org.domain ?? '',
      org.url?.toString() ?? '',
      org.sfinUrl.toString(),
    ]);
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
    ..writeln(
      'Usage: dart run example/main.dart transactions [options] [account_id]',
    )
    ..writeln()
    ..writeln(parsers.transactions.usage);
}

void _printBridgeErrors(List<String> errors) {
  if (errors.isEmpty) {
    return;
  }
  stderr.writeln('Bridge reported the following messages:');
  for (final error in errors) {
    stderr.writeln('- $error');
  }
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
      'Unable to parse date "$value". Use ISO-8601 (e.g. 2024-01-31T00:00:00Z) or epoch seconds.',
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
  });

  final ArgParser root;
  final ArgParser claim;
  final ArgParser info;
  final ArgParser accounts;
  final ArgParser organizations;
  final ArgParser transactions;

  static _ParserBundle build() {
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
        'access-url',
        abbr: 'a',
        help:
            'SimpleFIN access URL (default: value from example/.env if present).',
      )
      ..addMultiOption(
        'account',
        abbr: 'A',
        help: 'Restrict results to specific account IDs (repeatable).',
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
        'access-url',
        abbr: 'a',
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
        'access-url',
        abbr: 'a',
        help:
            'SimpleFIN access URL (default: value from example/.env if present).',
      )
      ..addOption(
        'start-date',
        abbr: 's',
        help:
            'Include transactions on/after this date (ISO-8601 or epoch seconds). '
            'Default: 30 days ago when omitted.',
      )
      ..addOption(
        'end-date',
        abbr: 'e',
        help:
            'Include transactions before this date (ISO-8601 or epoch seconds). '
            'Default: now.',
      )
      ..addFlag(
        'pending',
        negatable: false,
        help: 'Include pending transactions when supported (default: off).',
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

    return _ParserBundle(
      root: root,
      claim: claim,
      info: info,
      accounts: accounts,
      organizations: organizations,
      transactions: transactions,
    );
  }
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
