import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

enum VersionUpgrade { compatible, latest, empty }

class CommandLineOptions {
  String directory = '';
  String filename = 'pubspec.yaml';
  bool recurse = false;
  VersionUpgrade useVersion = VersionUpgrade.compatible;

  void parse(List<String> args) {
    final parser = ArgParser();
    parser.addFlag('help', abbr: 'h', negatable: false, help: 'Prints usage',
        callback: (value) {
      if (value) {
        print(parser.usage);
        exit(0);
      }
    });
    parser.addOption('version',
        abbr: 'v',
        allowed: VersionUpgrade.values.asNameMap().keys,
        defaultsTo: VersionUpgrade.compatible.name,
        help: 'Specifies which version to use when writing pubspec.yaml',
        callback: (platform) {
      if (platform == null) {
        return; // Not specified so do nothing
      }
      var value = VersionUpgrade.values.asNameMap()[platform];
      if (value != null) {
        useVersion = value;
      } else {
        print('Invalid version value; $platform');
        print(parser.usage);
        exit(-1);
      }
    });

    final results = parser.parse(args);
    if (results.rest.isNotEmpty) {
      filename = results.rest.first;
    }

    if (Directory(filename).existsSync()) {
      directory = filename;
      filename = join(directory, 'pubspec.yaml');
      recurse = true;
    } else {
      directory = File(filename).parent.path;
      recurse = false;
    }
  }
}
