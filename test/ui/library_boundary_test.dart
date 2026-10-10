import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The UI library's import boundaries (database shell spec 5.4).
void main() {
  final directive = RegExp(r"^(?:import|export)\s+'([^']+)'", multiLine: true);

  Iterable<File> dartFiles(String dir) =>
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

  /// The repository path a directive in [file] points at, or null for a
  /// `dart:` or third-party package.
  String? target(File file, String uri) {
    if (uri.startsWith('package:lifeos/')) {
      return p.posix.join('lib', uri.substring('package:lifeos/'.length));
    }
    if (uri.startsWith('package:') || uri.startsWith('dart:')) return null;
    return p.posix.normalize(p.posix.join(p.posix.dirname(file.path), uri));
  }

  List<String> offenders(
    Iterable<File> files,
    bool Function(File file, String target) allowed,
  ) => [
    for (final file in files)
      for (final match in directive.allMatches(file.readAsStringSync()))
        if (target(file, match.group(1)!) case final to?)
          if (to.startsWith('lib/ui/') && !allowed(file, to))
            '${file.path} → $to',
  ];

  test('features, app and the old shell reach the library only through '
      'ui.dart', () {
    final files = [
      ...dartFiles('lib/features'),
      ...dartFiles('lib/app'),
      ...dartFiles('lib/shared'),
      File('lib/main.dart'),
    ];
    expect(
      offenders(
        files,
        (file, to) =>
            to == 'lib/ui/ui.dart' ||
            (file.path == 'lib/main.dart' &&
                to == 'lib/ui/gallery/gallery_main.dart'),
      ),
      isEmpty,
    );
  });

  test('tests reach the library through ui.dart or the gallery', () {
    expect(
      offenders(
        dartFiles('test'),
        (file, to) =>
            to == 'lib/ui/ui.dart' || to.startsWith('lib/ui/gallery/'),
      ),
      isEmpty,
    );
  });

  test('the library depends only on itself, time and explanations', () {
    bool allowed(File file, String uri) {
      if (uri.startsWith('dart:') ||
          uri.startsWith('package:flutter/') ||
          uri.startsWith('package:path/')) {
        return true;
      }
      final to = target(file, uri);
      if (to == null) return false; // any other third-party package
      return to.startsWith('lib/ui/') ||
          to.startsWith('lib/core/time/') ||
          to.startsWith('lib/core/explain/');
    }

    final outside = [
      for (final file in dartFiles('lib/ui'))
        for (final match in directive.allMatches(file.readAsStringSync()))
          if (!allowed(file, match.group(1)!))
            '${file.path} → ${match.group(1)}',
    ];
    expect(outside, isEmpty);
  });

  test('mixed files are split into their homes (spec 5.1)', () {
    String source(String path) => File(path).readAsStringSync();
    expect(
      source('lib/ui/controls/property_sheet_tabs.dart'),
      contains('final class PropertySheetTabs '),
    );
    expect(
      source('lib/ui/controls/keys.dart'),
      isNot(contains('PropertySheetTabs')),
    );
    expect(
      source('lib/ui/controls/etched_line.dart'),
      contains('final class EtchedLine '),
    );
    expect(
      source('lib/ui/shell/dialog_parts.dart'),
      isNot(contains('final class EtchedLine ')),
    );
  });

  test('the old workbench folders are gone', () {
    expect(Directory('lib/shared/workbench').existsSync(), isFalse);
    expect(Directory('test/shared/workbench').existsSync(), isFalse);
  });
}
