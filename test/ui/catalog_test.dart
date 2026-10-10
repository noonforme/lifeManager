import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';

import '../support/ui_library.dart';

/// CATALOG.md stays the truth about the library (database shell spec 5.2).
void main() {
  final heading = RegExp(
    r'^### (\w+) · (\S+\.dart) · (stable|new|deprecated \(use [^)]+\))$',
    multiLine: true,
  );

  test('CATALOG.md has one complete, current entry per library widget', () {
    final catalog = File('lib/ui/CATALOG.md').readAsStringSync();
    final classes = libraryWidgetClasses();
    final entries = heading.allMatches(catalog).toList();
    expect({
      for (final entry in entries) entry.group(1)!,
    }, classes.keys.toSet());
    expect(entries, hasLength(classes.length), reason: 'duplicate entries');

    final demos = {for (final demo in galleryDemos) demo.widget: demo};
    for (final (index, entry) in entries.indexed) {
      final name = entry.group(1)!;
      expect(entry.group(2), classes[name], reason: '$name: file');
      final end = index + 1 < entries.length
          ? entries[index + 1].start
          : catalog.length;
      final body = catalog.substring(entry.end, end);
      expect(body, contains('Use for:'), reason: name);
      expect(body, contains('API: $name'), reason: name);
      final demo = demos[name]!;
      final golden = 'test/ui/goldens/${demo.goldenName}.png';
      expect(
        body,
        contains('Gallery: ${demo.id} · Goldens: $golden'),
        reason: name,
      );
      expect(File(golden).existsSync(), isTrue, reason: golden);
      final realGolden = 'test/ui/goldens/real_font/${demo.goldenName}.png';
      expect(File(realGolden).existsSync(), isTrue, reason: realGolden);
    }
  });

  test('the catalog opens with the job table', () {
    final catalog = File('lib/ui/CATALOG.md').readAsStringSync();
    expect(catalog, contains('## Which widget for which job'));
    expect(
      catalog.indexOf('## Which widget for which job'),
      lessThan(catalog.indexOf('### ')),
    );
  });
}
