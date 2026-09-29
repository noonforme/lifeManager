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
      '${temp.path}/schema_v2.json',
    ]);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      exitCode = result.exitCode;
      return;
    }

    final generated = Directory(temp.path)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList(growable: false);
    if (generated.length != 1) {
      stderr.writeln('Generated schema snapshot is missing or ambiguous.');
      exitCode = 1;
      return;
    }

    final generatedBytes = await generated.single.readAsBytes();
    final committed = File('drift_schemas/schema_v2.json');
    if (!await committed.exists()) {
      stderr.writeln('Schema v2 snapshot is missing.');
      exitCode = 1;
      return;
    }
    final committedBytes = await committed.readAsBytes();
    if (!_sameBytes(generatedBytes, committedBytes)) {
      stderr.writeln('Committed schema v2 snapshot is stale.');
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
