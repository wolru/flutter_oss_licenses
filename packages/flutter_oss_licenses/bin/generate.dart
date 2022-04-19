import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_pubspec_licenses/dart_pubspec_licenses.dart' as oss;
import 'package:path/path.dart' as path;
import 'package:args/args.dart';

main(List<String> args) async {
  final parser = getArgParser();
  final pubCacheDirPath = oss.guessPubCacheDir();
  final results = parser.parse(args);

  try {
    if (results['help']) {
      printUsage(parser);
      return 0;
    } else if (oss.flutterDir == null) {
      print('FLUTTER_ROOT is not set.');
      return 1;
    } else if (pubCacheDirPath == null) {
      print('Could not determine PUB_CACHE directory.');
      return 2;
    } else if (results.rest.length > 0) {
      print('WARNING: extra parameter given\n');
      printUsage(parser);
      return 3;
    }

    final projectRoot = results['project-root'] ?? await findProjectRoot();
    final outputFilePath = results['output'] ?? path.join(projectRoot, 'lib', 'oss_licenses.dart');
    final licenses = await oss.generateLicenseInfo(
      pubspecLockPath: path.join(projectRoot, 'pubspec.lock'),
    );

    final jsonCode = const JsonEncoder.withIndent("  ").convert(licenses);
    final dartCode = '''// cSpell:disable
// ignore_for_file: prefer_single_quotes

/// This code was generated by flutter_oss_licenses
/// https://pub.dev/packages/flutter_oss_licenses
final ossLicenses = <String, dynamic>''' +
        jsonCode +
        ';';

    await File(outputFilePath).writeAsString(results['json'] ? jsonCode : dartCode);
    return 0;
  } catch (e, s) {
    print('$e: $s');
    return 4;
  }
}

Future<String> findProjectRoot({Directory? from}) async {
  from = from ?? Directory.current;
  if (await File(path.join(from.path, 'pubspec.yaml')).exists()) {
    return from.path;
  }
  return findProjectRoot(from: from.parent);
}

ArgParser getArgParser() {
  final parser = ArgParser();

  parser.addOption('output', abbr: 'o', defaultsTo: null, help: '''
Specify output file path.
The default output file path depends on the --json flag:
  with    --json: PROJECT_ROOT/assets/oss_licenses.json
  without --json: PROJECT_ROOT/lib/oss_licenses.dart
''');
  parser.addOption('project-root',
      defaultsTo: null, help: 'Explicitly specify project root directory that contains pubspec.lock.');
  parser.addFlag('json',
      abbr: 'j', defaultsTo: false, negatable: false, help: 'Generate JSON file rather than dart file.');
  parser.addFlag('help', abbr: 'h', defaultsTo: false, negatable: false, help: 'show help');

  return parser;
}

void printUsage(ArgParser parser) {
  print('Usage: ${path.basename(Platform.script.toString())} [OPTION]\n');
  print(parser.usage);
}
