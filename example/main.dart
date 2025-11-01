import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:simplefin_dart/simplefin_dart.dart';

Future<void> main(List<String> arguments) async {
  final envFile = arguments.isNotEmpty ? arguments.first : '.env';
  final env = dotenv.DotEnv(includePlatformEnvironment: true);

  if (await File(envFile).exists()) {
    env.load(<String>[envFile]);
  } else {
    stdout.writeln('No $envFile file found; create one to use this example.');
  }

  final accessUrl = env['SIMPLEFIN_ACCESS_URL']?.trim() ?? '';
  if (accessUrl.isEmpty) {
    stdout
      ..writeln('Add SIMPLEFIN_ACCESS_URL to $envFile before running.')
      ..writeln(
        'If you only have a setup token, add SIMPLEFIN_SETUP_TOKEN as well.',
      );
    final setupToken = env['SIMPLEFIN_SETUP_TOKEN']?.trim() ?? '';
    if (setupToken.isNotEmpty) {
      final bridgeClient = SimplefinBridgeClient();
      try {
        final credentials = await bridgeClient.claimAccessCredentials(
          setupToken,
        );
        stdout
          ..writeln('Claimed Access URL:')
          ..writeln(credentials.accessUrl);
      } finally {
        bridgeClient.close();
      }
    }
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
