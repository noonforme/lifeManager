import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The new shell outlives the old Work screens (deleted in Phase 5), so it
/// must not depend on them.
void main() {
  test('retired shell sources and imports are absent from the library', () {
    const retired = [
      'shared/shell/',
      'core/desks/',
      'features/journal/',
      'features/work/presentation/',
      'old_shell_',
      'desk_host',
      'desk_providers',
      'shell_host',
    ];
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (retired.any(file.path.contains)) {
        offenders.add(file.path);
      }
      for (final line in file.readAsLinesSync()) {
        if ((line.startsWith('import ') || line.startsWith('export ')) &&
            retired.any(line.contains)) {
          offenders.add('${file.path}: $line');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the production entry reaches only the new shell', () {
    const old = [
      'old_shell_',
      'shell_host',
      'desk_host',
      'shared/shell/',
      'features/work/presentation/',
      'features/journal/',
    ];
    final offenders = [
      for (final path in [
        'lib/main.dart',
        'lib/app/lifeos_app.dart',
        'lib/app/app_router.dart',
      ])
        for (final line in File(path).readAsLinesSync())
          if (line.startsWith('import ') && old.any(line.contains))
            '$path: $line',
    ];
    expect(offenders, isEmpty);
  });

  test('nothing main reaches imports the old shell', () {
    const old = ['old_shell_', 'shell_host.dart', 'desk_host.dart'];
    final seen = <String>{};
    final offenders = <String>[];
    void visit(String path) {
      if (!seen.add(path)) return;
      for (final line in File(path).readAsLinesSync()) {
        final match = RegExp(r"^(?:import|export) '([^']+)'").firstMatch(line);
        final target = match?.group(1);
        if (target == null ||
            target.startsWith('package:') ||
            target.startsWith('dart:')) {
          continue;
        }
        final next = File(path).parent.uri.resolve(target).toFilePath();
        final relative = next.substring(
          next.indexOf(
                '${Platform.pathSeparator}lib${Platform.pathSeparator}',
              ) +
              1,
        );
        if (old.any(relative.contains)) offenders.add('$path → $relative');
        visit(relative);
      }
    }

    visit('lib/main.dart');
    expect(seen.length, greaterThan(50), reason: 'the walk reached the app');
    expect(offenders, isEmpty);
  });
}
