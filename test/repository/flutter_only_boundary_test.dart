import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository holds only the native Flutter application and its docs.
void main() {
  test('legacy Django, Python and web-template material is absent', () {
    for (final path in [
      'lifeos',
      'tests',
      'templates',
      'static',
      'scripts',
      'manage.py',
      'pyproject.toml',
      'uv.lock',
      'docs/foundation',
    ]) {
      expect(
        FileSystemEntity.typeSync(path),
        FileSystemEntityType.notFound,
        reason: path,
      );
    }
  });

  test(
    'native verification evidence contains no legacy web or runtime data',
    () {
      // Native release receipts now live here; the old directory-name ban
      // confused current evidence with the deleted Django verification tree.
      final evidence = Directory('docs/verification');
      _checkNativeEvidence(evidence);
    },
  );

  test('native evidence rejects a symlinked root before traversing it', () {
    final sandbox = Directory.systemTemp.createTempSync('lifeos-evidence-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final target = Directory('${sandbox.path}/target')..createSync();
    final link = Link('${sandbox.path}/evidence')..createSync(target.path);
    expect(
      () => _checkNativeEvidence(Directory(link.path)),
      throwsA(isA<TestFailure>()),
    );
  });

  test('native evidence rejects legacy content and runtime files', () {
    final sandbox = Directory.systemTemp.createTempSync('lifeos-evidence-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    for (final name in ['legacy.py', 'template.html', 'runtime.sqlite-wal']) {
      final file = File('${sandbox.path}/$name')
        ..writeAsStringSync('synthetic');
      expect(() => _checkNativeEvidence(sandbox), throwsA(isA<TestFailure>()));
      file.deleteSync();
    }
  });

  test('launcher and top-level docs describe only the native app', () {
    for (final path in ['app.sh', 'README.md']) {
      final text = File(path).readAsStringSync().toLowerCase();
      for (final legacy in ['manage.py', 'runserver', 'uv run', 'pytest']) {
        expect(text, isNot(contains(legacy)), reason: '$path: $legacy');
      }
    }
    final launcher = File('app.sh').readAsStringSync();
    expect(launcher, contains('run -d linux'));
    expect(launcher, contains('" test'));
  });
}

void _checkNativeEvidence(Directory evidence) {
  final type = FileSystemEntity.typeSync(evidence.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return;
  expect(type, FileSystemEntityType.directory, reason: evidence.path);
  final forbidden = RegExp(
    r'\.(py|html|jinja2?|sqlite3?|db)(-(wal|shm))?$|\.lifeos-(backup|export)',
    caseSensitive: false,
  );
  for (final entry in evidence.listSync(recursive: true, followLinks: false)) {
    expect(entry, isNot(isA<Link>()), reason: entry.path);
    expect(forbidden.hasMatch(entry.path), isFalse, reason: entry.path);
  }
}
