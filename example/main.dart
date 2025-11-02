import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:simplefin_dart/simplefin_dart.dart';

Future<void> main(List<String> arguments) async {
  late final _CliOptions options;
  try {
    options = _CliOptions.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    _printUsage();
    exitCode = 64;
    return;
  }

  if (options.showHelp) {
    _printUsage();
    return;
  }

  final scriptDir = File.fromUri(Platform.script).parent;
  final envFile = _locateEnvFile(scriptDir);
  final envPathDisplay = envFile?.path ?? '${scriptDir.path}/.env';

  if (options.setupToken != null) {
    final bridgeClient = SimplefinBridgeClient();
    stdout.writeln('Claiming access URL from setup token...');
    try {
      final credentials = await bridgeClient.claimAccessCredentials(
        options.setupToken!,
      );
      stdout
        ..writeln('SIMPLEFIN_ACCESS_URL=${credentials.accessUrl}')
        ..writeln(
          'Redirect the line above into your .env file (e.g. >> $envPathDisplay).',
        );
    } on SimplefinException catch (error) {
      stderr.writeln('Failed to claim access URL: $error');
      exitCode = 1;
    } finally {
      bridgeClient.close();
    }
    return;
  }

  final env = dotenv.DotEnv(includePlatformEnvironment: true);
  if (envFile != null) {
    env.load(<String>[envFile.path]);
  } else {
    stdout.writeln(
      'No .env file found beside the script; copy example/example.env to $envPathDisplay and update it.',
    );
  }

  final accessUrl = env['SIMPLEFIN_ACCESS_URL']?.trim() ?? '';
  if (accessUrl.isEmpty) {
    stdout
      ..writeln('SIMPLEFIN_ACCESS_URL is not set in $envPathDisplay.')
      ..writeln(
        'Generate one with `dart run example/main.dart --claim <SETUP_TOKEN>`.',
      );
    return;
  }

  final credentials = SimplefinAccessCredentials.parse(accessUrl);
  final accessClient = SimplefinAccessClient(credentials: credentials);
  try {
    final accountSet = await accessClient.getAccounts(balancesOnly: true);
    for (final account in accountSet.accounts) {
      stdout.writeln(
        '${account.name} (${account.currency}) — balance ${account.balance}',
      );
    }
    if (accountSet.errors.isNotEmpty) {
      stdout
        ..writeln('Errors reported by bridge:')
        ..writeln(accountSet.errors.join('\n'));
    }
  } finally {
    accessClient.close();
  }
}

class _CliOptions {
  _CliOptions({this.setupToken, this.showHelp = false});

  final String? setupToken;
  final bool showHelp;

  static _CliOptions parse(List<String> arguments) {
    String? setupToken;
    var showHelp = false;

    for (var i = 0; i < arguments.length; i++) {
      final arg = arguments[i];
      switch (arg) {
        case '--claim':
        case '-c':
          if (i + 1 >= arguments.length) {
            throw FormatException('Missing setup token for $arg.');
          }
          setupToken = arguments[++i];
          break;
        case '--help':
        case '-h':
          showHelp = true;
          break;
        default:
          throw FormatException('Unknown argument "$arg".');
      }
    }

    return _CliOptions(setupToken: setupToken, showHelp: showHelp);
  }
}

void _printUsage() {
  stdout
    ..writeln('Usage: dart run example/main.dart [options]')
    ..writeln()
    ..writeln('Options:')
    ..writeln(
      '  -c, --claim <SETUP_TOKEN>   Exchange a setup token for an access URL.',
    )
    ..writeln('  -h, --help                  Show this help message.');
}

File? _locateEnvFile(Directory scriptDir) {
  final candidate = File('${scriptDir.path}/.env');
  if (candidate.existsSync()) {
    return candidate;
  }
  return null;
}
