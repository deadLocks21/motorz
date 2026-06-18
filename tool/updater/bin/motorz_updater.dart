import 'dart:io';

import 'package:motorz_updater/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
