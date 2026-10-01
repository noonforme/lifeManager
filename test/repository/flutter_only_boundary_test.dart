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
      'docs/verification',
    ]) {
      expect(
        FileSystemEntity.typeSync(path),
        FileSystemEntityType.notFound,
        reason: path,
      );
    }
  });

  test('launcher and top-level docs describe only the native app', () {
    for (final path in ['app.sh', 'README.md', 'PRODUCT.md', 'DESIGN.md']) {
      final text = File(path).readAsStringSync().toLowerCase();
      for (final legacy in ['manage.py', 'runserver', 'uv run', 'pytest']) {
        expect(text, isNot(contains(legacy)), reason: '$path: $legacy');
      }
    }
    final launcher = File('app.sh').readAsStringSync();
    expect(launcher, contains('run -d linux'));
    expect(launcher, contains('" test'));
  });

  test('only native specifications remain', () {
    final specs = Directory('docs/superpowers/specs')
        .listSync()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();
    expect(specs, ['2026-09-29-lifeos-native-foundation-work-design.md']);
  });
}
