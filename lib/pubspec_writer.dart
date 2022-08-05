import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:pubspec_writer/args_parser.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

// Example Output:
// Resolving dependencies...
//   _fe_analyzer_shared 43.0.0
//   analyzer 4.3.1
//   archive 3.1.11 (3.3.1 available)
//   args 2.3.1
//   async 2.8.2 (2.9.0 available)
// No dependencies would change.
// Warning: You are using these overridden dependencies:1 package is discontinued.

class PackageOutput {
  String name = '';
  String version = '';
  String? _previous;
  String? _latest;

  String get previous => _previous ?? version;
  set previous(String ver) => _previous = ver;
  String get latest => _latest ?? version;
  set latest(String ver) => _latest = ver;
}

PackageOutput parsePackageOutput(String line) {
  final output = PackageOutput();
  String? prev;
  for (final part in line.split(' ')) {
    if (part.isEmpty) continue;
    if (output.name.isEmpty) {
      output.name = part;
    } else if (output.version.isEmpty) {
      output.version = part;
    } else {
      if (prev != null && prev.length > 1) {
        if (prev[0] == '(' && part == 'available)') {
          output.latest = prev.substring(1);
        } else if (prev == '(was' && part.endsWith(')')) {
          output.previous = part.substring(0, part.length - 1);
        }
      }
      prev = part;
    }
  }

  return output;
}

String getVersion(PackageOutput pkg, VersionUpgrade useVersion) {
  switch (useVersion) {
    case VersionUpgrade.empty:
      return '';
    case VersionUpgrade.latest:
      return pkg.latest;
    case VersionUpgrade.compatible:
    default:
      return pkg.version;
  }
}

Map<String, String> parseOutput(String output, VersionUpgrade useVersion) {
  final lines = LineSplitter.split(output);
  final result = <String, String>{};
  final pattern = RegExp(r'(!|>| ) ');
  for (final line in lines) {
    if (pattern.matchAsPrefix(line) != null) {
      final pkg = parsePackageOutput(line);
      if (pkg.name.isNotEmpty) {
        result[pkg.name] = getVersion(pkg, useVersion);
      }
    }
  }

  return result;
}

Iterable<String> getFilesRecursive(Directory path, String pattern) sync* {
  final topLevel = path.listSync(recursive: false);
  for (final dir in topLevel) {
    if (!FileSystemEntity.isDirectorySync(dir.path)) continue;

    final name = basename(dir.path);
    if (name.startsWith('.')) continue;
    switch (name.toLowerCase()) {
      case 'linux':
      case 'windows':
      case 'macos':
      case 'web':
      case 'android':
      case 'ios':
      case 'build':
      case 'assets':
        continue;
      default:
        break;
    }

    yield* Directory(dir.path)
        .listSync(recursive: true)
        .map((e) => e.path)
        .where((element) => basename(element) == pattern);
  }
}

void updateDependencies(
    YamlEditor yaml, Map<String, String> versions, Iterable<String> path) {
  final dependencies = yaml.parseAt(path);
  if (dependencies is! YamlMap) return;

  for (final entry in dependencies.nodes.entries) {
    // https://dart.dev/tools/pub/dependencies
    // Skip custom versions: git, path, sdk, hosted, etc
    // Any scalar values wouldn't have custom versions
    if (entry.value is! YamlScalar) {
      continue;
    }
    final key = entry.key.toString();
    final ver = versions[key];
    if (ver != null) {
      // TODO: Need a better way to create an empty scalar. This doesn't work
      yaml.update([...path, key], ver.isNotEmpty ? '^$ver' : '');
    }
  }
}

void updateVersions(YamlEditor yaml, Map<String, String> versions) {
  updateDependencies(yaml, versions, ['dependencies']);
  updateDependencies(yaml, versions, ['dev_dependencies']);
}

ProcessResult runPubUpgrade(String dir,
    [List<String> args = const <String>[]]) {
  return Process.runSync('flutter', ['pub', 'upgrade', '-n', ...args],
      workingDirectory: dir, runInShell: true);
}

YamlEditor parseYaml(String file) {
  return YamlEditor(File(file).readAsStringSync());
}

void writeYaml(YamlEditor yaml, String file) {
  File(file).writeAsStringSync(yaml.toString());
}
