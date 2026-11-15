import 'dart:io';

Future<void> main() async {
  final tracked = await Process.run('git', ['ls-files', '-z']);
  if (tracked.exitCode != 0) {
    stderr.writeln('Unable to enumerate tracked files.');
    exitCode = 1;
    return;
  }

  final paths = (tracked.stdout as String)
      .split('\u0000')
      .where((path) => path.isNotEmpty)
      .toList();
  final violations = <String>[];
  final runtimeArtifact = RegExp(
    r'\.(sqlite|sqlite3|db)(-(wal|shm))?$|\.lifeos-(backup|export)',
    caseSensitive: false,
  );
  final personalFixturePath = RegExp(
    r'(^|/)(personal|production|real[-_]data)(/|$)',
    caseSensitive: false,
  );

  for (final path in paths) {
    if (runtimeArtifact.hasMatch(path)) {
      violations.add('$path: tracked runtime data artifact');
    }
    if (personalFixturePath.hasMatch(path)) {
      violations.add('$path: prohibited personal-data fixture path');
    }
    if (!path.startsWith('lib/') || !path.endsWith('.dart')) continue;

    final source = await File(path).readAsString();
    final lines = source.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (RegExp(r'\b(print|debugPrint|log)\s*\(').hasMatch(line) &&
          (line.contains(r'$') || line.contains(r'${'))) {
        violations.add('$path:${index + 1}: interpolated logger call');
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Privacy scan failed:');
    for (final violation in violations) {
      stderr.writeln('- $violation');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Privacy scan passed (${paths.length} tracked files).');
}
