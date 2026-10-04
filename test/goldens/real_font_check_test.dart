@Tags(['real-font'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/lifeos_app.dart';

import '../support/synthetic_shell.dart';

/// The shell's screens rendered with the bundled EraSans, for a look by
/// eye before merging (Millennium shell spec 9). Skipped by default; run:
/// flutter test --run-skipped -t real-font --update-goldens
///   test/goldens/real_font_check_test.dart
void main() {
  setUpAll(() async {
    for (final (family, dir) in [
      ('EraSans', 'assets/fonts/era_sans'),
      ('NotoSans', 'assets/fonts/noto_sans'),
    ]) {
      final loader = FontLoader(family);
      for (final file in Directory(dir).listSync().whereType<File>().where(
        (file) => file.path.endsWith('.ttf'),
      )) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
      await loader.load();
    }
  });

  for (final MapEntry(key: name, value: screen) in syntheticScreens.entries) {
    testWidgets('real_font/$name', (tester) async {
      await pumpSyntheticShell(
        tester,
        size: const Size(1280, 800),
        screen: screen,
      );
      await syntheticInteractions[name]?.call(tester);
      await expectLater(
        find.byType(LifeOsApp),
        matchesGoldenFile('real_font/$name.png'),
      );
    });
  }

  // The open month calendar (era pickers spec 5).
  testWidgets('real_font/calendar', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['agreement']!,
    );
    await tester.tap(find.byKey(const ValueKey('agreement-effective-start')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LifeOsApp),
      matchesGoldenFile('real_font/calendar.png'),
    );
  });
}
