import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';

import '../support/catalog.dart';
import '../support/ui_library.dart';

/// CATALOG.md stays the truth about the library (database shell spec 5.2).
void main() {
  final heading = RegExp(
    r'^### (\w+) · (\S+\.dart) · (stable|new|deprecated \(use [^)]+\))$',
    multiLine: true,
  );
  final catalog = File('lib/ui/CATALOG.md').readAsStringSync();

  test('CATALOG.md has one complete, current entry per library widget', () {
    final classes = libraryWidgetClasses();
    final entries = heading.allMatches(catalog).toList();
    expect({
      for (final entry in entries) entry.group(1)!,
    }, classes.keys.toSet());
    expect(entries, hasLength(classes.length), reason: 'duplicate entries');

    final demos = {for (final demo in galleryDemos) demo.widget: demo};
    for (final entry in entries) {
      final name = entry.group(1)!;
      expect(entry.group(2), classes[name], reason: '$name: file');
      final body = catalogEntryBody(catalog, entry.end);
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

  test('an entry body ends at the next section heading', () {
    const text =
        '### A · a.dart · new\nUse for: a\n\n## Shell\n\nAPI: A()\n'
        '### B · b.dart · new\nAPI: B()\n';
    final body = catalogEntryBody(text, text.indexOf('\n'));
    expect(body, contains('Use for: a'));
    expect(body, isNot(contains('API: A()')));
  });

  test('the catalog opens with the job table', () {
    expect(catalog, contains('## Which widget for which job'));
    expect(
      catalog.indexOf('## Which widget for which job'),
      lessThan(catalog.indexOf('### ')),
    );
  });

  test("every name in the job table's Use column is declared in lib/ui", () {
    expect(undeclaredJobTableNames(catalog, librarySources()), isEmpty);
  });

  test('the job table check reports a misspelt name', () {
    const table =
        '## Which widget for which job\n\n| Job | Use | Not |\n'
        '|---|---|---|\n'
        '| A list | `DataGird` (legacy: `DataGrid`) | `ListView` |\n\n'
        '## Foundation\n';
    expect(
      undeclaredJobTableNames(table, {
        'data/data_grid.dart':
            'final class DataGrid<T> extends StatefulWidget {}',
      }),
      ['DataGird'],
    );
  });

  test('every Foundation name is declared in the file it names', () {
    expect(undeclaredFoundationNames(catalog, librarySources()), isEmpty);
  });

  test('the Foundation check reports a wrong file and an unparsed line', () {
    const section =
        '## Foundation\n\n'
        '- `EraIconKind`, `areaIcon(area)` (`foundation/era_icons.dart`): x.\n'
        '- `LifeOSArea` (`foundation/era_icons.dart`): y.\n'
        '- `Loose` without a file.\n'
        '\n### LifeOSSkinScope · foundation/lifeos_skin.dart · stable\n';
    expect(
      undeclaredFoundationNames(section, {
        'foundation/era_icons.dart':
            'enum EraIconKind { app }\n'
            'EraIconKind areaIcon(LifeOSArea area) => EraIconKind.app;\n',
      }),
      [
        'LifeOSArea (foundation/era_icons.dart)',
        'unparsed: - `Loose` without a file.',
      ],
    );
  });
}
