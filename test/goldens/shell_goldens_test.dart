import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/lifeos_app.dart';

import '../support/scheduled_app.dart';
import '../support/synthetic_shell.dart';

/// The shell's screens at the two reference sizes, on synthetic data. Text
/// renders in the test font, so these guard colour, painting and layout
/// rather than glyphs.
void main() {
  const sizes = [Size(1280, 800), Size(960, 760)];
  for (final MapEntry(key: name, value: screen) in syntheticScreens.entries) {
    for (final size in sizes) {
      final file = '${name}_${size.width.round()}x${size.height.round()}';
      testWidgets(file, (tester) async {
        await pumpSyntheticShell(tester, size: size, screen: screen);
        await syntheticInteractions[name]?.call(tester);
        await expectLater(
          find.byType(LifeOsApp),
          matchesGoldenFile('$file.png'),
        );
      });
    }
  }

  for (final size in sizes) {
    final file = 'calendar_${size.width.round()}x${size.height.round()}';
    testWidgets(file, (tester) async {
      await pumpSyntheticShell(
        tester,
        size: size,
        screen: syntheticScreens['agreement']!,
      );
      await tester.tap(find.byKey(const ValueKey('agreement-effective-start')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(LifeOsApp), matchesGoldenFile('$file.png'));
    });
  }

  for (final (name, location) in [
    ('work_calendar', '/work?employment={employment}'),
    (
      'schedule',
      '/work?employment={employment}&sheet=schedules'
          '&record=schedule:{schedule}&mode=properties',
    ),
    // October's planned days greyed among the shifts.
    (
      'planned_shifts',
      '/work?employment={employment}&sheet=shifts'
          '&from=2026-10-01&to=2026-10-31&day=2026-10-06',
    ),
  ]) {
    for (final size in sizes) {
      final file = '${name}_${size.width.round()}x${size.height.round()}';
      testWidgets(file, (tester) async {
        await pumpScheduledApp(tester, size: size, location: location);
        await expectLater(
          find.byType(LifeOsApp),
          matchesGoldenFile('$file.png'),
        );
      });
    }
  }
}
