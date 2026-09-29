import 'dart:io';

Future<void> main() async {
  final temp = await Directory.systemTemp.createTemp('lifeos-schema-check-');
  try {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'drift_dev',
      'schema',
      'dump',
      'lib/core/database/app_database.dart',
      temp.path,
    ]);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      exitCode = result.exitCode;
      return;
    }

    final generated = File('${temp.path}/drift_schema_v1.json');
    final committed = File('drift_schemas/schema_v1.json');
    if (!await generated.exists() || !await committed.exists()) {
      stderr.writeln('Schema snapshot is missing.');
      exitCode = 1;
      return;
    }
    final generatedBytes = await generated.readAsBytes();
    final committedBytes = await committed.readAsBytes();
    if (!_sameBytes(generatedBytes, committedBytes)) {
      stderr.writeln('Committed schema snapshot is stale.');
      exitCode = 1;
    }
  } finally {
    await temp.delete(recursive: true);
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
