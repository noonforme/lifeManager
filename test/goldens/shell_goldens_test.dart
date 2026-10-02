import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/lifeos_app.dart';

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
        await expectLater(
          find.byType(LifeOsApp),
          matchesGoldenFile('$file.png'),
        );
      });
    }
  }
}
