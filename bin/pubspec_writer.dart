import 'dart:io';

import 'package:pubspec_writer/args_parser.dart';
import 'package:pubspec_writer/pubspec_writer.dart';

void main(List<String> arguments) {
  final opts = CommandLineOptions();
  opts.parse(arguments);

  final result = runPubUpgrade(opts.directory);
  if (result.exitCode != 0) {
    stderr.write(result.stderr.toString());
    exit(result.exitCode);
  }

  final pubspecs = <String>{
    opts.filename,
    if (opts.recurse)
      ...getFilesRecursive(Directory(opts.directory), 'pubspec.yaml')
  };

  final versions = parseOutput(result.stdout.toString(), opts.useVersion);
  for (final file in pubspecs) {
    final yaml = parseYaml(file);
    updateVersions(yaml, versions);
    writeYaml(yaml, file);
  }
}
