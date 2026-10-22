// Generates `OtaAppLocalizations` from the gen-l10n output, so every ARB key
// gets an OTA-first override without hand-written code.
//
// Usage (after `fvm flutter gen-l10n`):
//   fvm dart run tool/gen_ota_localizations.dart          # write the file
//   fvm dart run tool/gen_ota_localizations.dart --check  # exit 1 if stale (CI)
//
// Signatures are read from the generated abstract `AppLocalizations` class,
// so parameter names, types and order always match gen-l10n exactly. The
// template ARB is read only to find placeholders with a `format` (dates,
// compact numbers…), which IcuMessageFormatter can't reproduce; those keys
// always use the bundled string.

import 'dart:convert';
import 'dart:io';

const String _outputPath =
    'lib/src/features/ota_translations/presentation/l10n/ota_app_localizations.dart';
const String _formatterPath = 'lib/src/core/l10n/icu_message_formatter.dart';

/// Types whose `toString()` matches gen-l10n's output when no `format` is set.
const Set<String> _otaSafeTypes = {'String', 'int', 'num', 'double', 'Object'};

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  try {
    final config = _L10nConfig.read(File('l10n.yaml'));
    final members = _parseMembers(
      File(config.generatedFilePath).readAsStringSync(),
      config.outputClass,
    );
    final formatted = _formattedPlaceholders(
      File(config.templateArbPath).readAsStringSync(),
    );
    final source = await _format(_render(config, members, formatted));

    final output = File(_outputPath);
    if (check) {
      if (!output.existsSync() || output.readAsStringSync() != source) {
        stderr.writeln(
          '$_outputPath is stale. Run: '
          'fvm dart run tool/gen_ota_localizations.dart',
        );
        exit(1);
      }
      stdout.writeln('$_outputPath is up to date.');
      return;
    }
    output.writeAsStringSync(source);
    final skipped = members.where(
      (m) => _bundledOnlyReason(m, formatted) != null,
    );
    stdout.writeln('Wrote $_outputPath (${members.length} keys).');
    for (final member in skipped) {
      stdout.writeln(
        '  bundled only: ${member.name} (${_bundledOnlyReason(member, formatted)})',
      );
    }
  } on FileSystemException catch (e) {
    stderr.writeln(
      'gen_ota_localizations: cannot read ${e.path}; '
      'run `fvm flutter gen-l10n` first',
    );
    exit(2);
  } on _GeneratorException catch (e) {
    stderr.writeln('gen_ota_localizations: ${e.message}');
    exit(2);
  }
}

final class _GeneratorException implements Exception {
  const _GeneratorException(this.message);
  final String message;
}

/// The subset of `l10n.yaml` that decides where gen-l10n writes its output.
final class _L10nConfig {
  const _L10nConfig({
    required this.arbDir,
    required this.templateArbFile,
    required this.outputDir,
    required this.outputFile,
    required this.outputClass,
  });

  final String arbDir;
  final String templateArbFile;
  final String outputDir;
  final String outputFile;
  final String outputClass;

  String get templateArbPath => '$arbDir/$templateArbFile';
  String get generatedFilePath => '$outputDir/$outputFile';

  /// `l10n.yaml` is flat `key: value`, so a line parser avoids a yaml
  /// dependency. Defaults mirror gen-l10n's.
  static _L10nConfig read(File file) {
    if (!file.existsSync()) {
      throw const _GeneratorException(
        'l10n.yaml not found; run from the project root',
      );
    }
    final values = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final match = RegExp(r'^([\w-]+)\s*:\s*(.+?)\s*$').firstMatch(line);
      if (match == null) continue;
      values[match.group(1)!] = match
          .group(2)!
          .replaceAll(RegExp('''^['"]|['"]\$'''), '');
    }
    final arbDir = values['arb-dir'] ?? 'lib/l10n';
    return _L10nConfig(
      arbDir: arbDir,
      templateArbFile: values['template-arb-file'] ?? 'app_en.arb',
      outputDir: values['output-dir'] ?? arbDir,
      outputFile:
          values['output-localization-file'] ?? 'app_localizations.dart',
      outputClass: values['output-class'] ?? 'AppLocalizations',
    );
  }
}

final class _Parameter {
  const _Parameter(this.type, this.name);
  final String type;
  final String name;
}

final class _Member {
  const _Member(this.name, this.parameters);
  final String name;

  /// Null for getters.
  final List<_Parameter>? parameters;
}

/// Reads `String get key;` and `String key(Type a, Type b);` declarations
/// from the generated abstract class body.
List<_Member> _parseMembers(String generated, String className) {
  final start = generated.indexOf('abstract class $className');
  if (start < 0) {
    throw _GeneratorException(
      'abstract class $className not found; run gen-l10n first',
    );
  }
  final body = generated.substring(start);
  final pattern = RegExp(
    r'^\s*String\s+(?:get\s+(\w+)|(\w+)\s*\(([^)]*)\))\s*;',
    multiLine: true,
  );
  final members = <_Member>[];
  for (final match in pattern.allMatches(body)) {
    final getter = match.group(1);
    if (getter != null) {
      members.add(_Member(getter, null));
      continue;
    }
    final parameters = match
        .group(3)!
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) {
          final parts = p.split(RegExp(r'\s+'));
          if (parts.length != 2) {
            throw _GeneratorException(
              'Unsupported parameter "$p" in ${match.group(2)}',
            );
          }
          return _Parameter(parts[0], parts[1]);
        })
        .toList();
    members.add(_Member(match.group(2)!, parameters));
  }
  if (members.isEmpty) {
    throw _GeneratorException('No members found in $className');
  }
  return members;
}

/// `key -> placeholder names` that declare a `format` or a custom date format.
Map<String, Set<String>> _formattedPlaceholders(String arb) {
  final json = jsonDecode(arb) as Map<String, dynamic>;
  final result = <String, Set<String>>{};
  for (final MapEntry(:key, :value) in json.entries) {
    if (!key.startsWith('@') || key.startsWith('@@') || value is! Map) continue;
    final placeholders = value['placeholders'];
    if (placeholders is! Map) continue;
    for (final MapEntry(key: name, value: meta) in placeholders.entries) {
      if (meta is Map &&
          (meta.containsKey('format') ||
              meta['isCustomDateFormat'] == 'true')) {
        result.putIfAbsent(key.substring(1), () => {}).add(name as String);
      }
    }
  }
  return result;
}

String? _bundledOnlyReason(_Member member, Map<String, Set<String>> formatted) {
  final formattedNames = formatted[member.name];
  if (formattedNames != null) {
    return 'formatted placeholder: ${formattedNames.join(', ')}';
  }
  for (final parameter in member.parameters ?? const <_Parameter>[]) {
    if (!_otaSafeTypes.contains(parameter.type)) {
      return '${parameter.name} is ${parameter.type}';
    }
  }
  return null;
}

String _render(
  _L10nConfig config,
  List<_Member> members,
  Map<String, Set<String>> formatted,
) {
  final className = config.outputClass;
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: ${config.generatedFilePath}')
    ..writeln('// Regenerate: fvm dart run tool/gen_ota_localizations.dart')
    ..writeln()
    ..writeln(
      "import '${_relativeImport(_outputPath, config.generatedFilePath)}';",
    )
    ..writeln("import '${_relativeImport(_outputPath, _formatterPath)}';")
    ..writeln()
    ..writeln(
      '/// [$className] that prefers strings delivered over the air and',
    )
    ..writeln(
      '/// falls back to the bundled ARB string per key when the OTA string',
    )
    ..writeln('/// is missing, empty or malformed.')
    ..writeln('class OtaAppLocalizations extends $className {')
    ..writeln('  OtaAppLocalizations({')
    ..writeln('    required $className bundled,')
    ..writeln('    required this._messages,')
    ..writeln('  }) : _bundled = bundled,')
    ..writeln('       super(bundled.localeName);')
    ..writeln()
    ..writeln('  final $className _bundled;')
    ..writeln('  final Map<String, String> _messages;')
    ..writeln()
    ..writeln('  String _resolve(')
    ..writeln('    String key,')
    ..writeln('    String Function() fallback, [')
    ..writeln('    Map<String, Object> args = const {},')
    ..writeln('  ]) {')
    ..writeln('    final message = _messages[key];')
    ..writeln('    if (message == null || message.isEmpty) return fallback();')
    ..writeln('    return IcuMessageFormatter.format(')
    ..writeln('          message,')
    ..writeln('          locale: localeName,')
    ..writeln('          args: args,')
    ..writeln('        ) ??')
    ..writeln('        fallback();')
    ..writeln('  }');

  for (final member in members) {
    out.writeln();
    final name = member.name;
    final parameters = member.parameters;
    final reason = _bundledOnlyReason(member, formatted);
    if (reason != null) {
      out.writeln('  // Bundled only: $reason.');
    }
    out.writeln('  @override');
    if (parameters == null) {
      out.writeln(
        reason != null
            ? '  String get $name => _bundled.$name;'
            : "  String get $name => _resolve('$name', () => _bundled.$name);",
      );
      continue;
    }
    final signature = parameters.map((p) => '${p.type} ${p.name}').join(', ');
    final call = '_bundled.$name(${parameters.map((p) => p.name).join(', ')})';
    if (reason != null) {
      out.writeln('  String $name($signature) => $call;');
      continue;
    }
    final argsMap = parameters.map((p) => "'${p.name}': ${p.name}").join(', ');
    out.writeln(
      "  String $name($signature) => _resolve('$name', () => $call, {$argsMap});",
    );
  }
  out.writeln('}');
  return out.toString();
}

/// Import path from [from]'s directory to [to], both relative to the root.
String _relativeImport(String from, String to) {
  final fromDir = from.split('/')..removeLast();
  final target = to.split('/');
  var common = 0;
  while (common < fromDir.length &&
      common < target.length &&
      fromDir[common] == target[common]) {
    common++;
  }
  return [
    for (var i = common; i < fromDir.length; i++) '..',
    ...target.skip(common),
  ].join('/');
}

/// Formats with the same `dart` that runs this script. `--stdin-name` makes
/// the formatter use the project's language version, so the result matches
/// `dart format lib` and `--check` stays stable.
Future<String> _format(String source) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'format',
    '--stdin-name=$_outputPath',
  ]);
  process.stdin.write(source);
  await process.stdin.close();
  final (formatted, errors, exitCode) = await (
    process.stdout.transform(utf8.decoder).join(),
    process.stderr.transform(utf8.decoder).join(),
    process.exitCode,
  ).wait;
  if (exitCode != 0) {
    throw _GeneratorException('dart format failed:\n$errors');
  }
  return formatted;
}
