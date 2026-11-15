import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/gallery.dart';

/// One golden per library widget (database shell spec 5.3), in the test
/// font: colour, painting and layout rather than glyphs.
void main() {
  for (final demo in galleryDemos) {
    testWidgets(demo.goldenName, (tester) async {
      await pumpGalleryDemo(tester, demo);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/${demo.goldenName}.png'),
      );
    });
  }

  testWidgets('controls_era_combo_open', (tester) async {
    await pumpGalleryDemo(
      tester,
      galleryDemos.singleWhere((demo) => demo.id == 'controls/era_combo'),
    );
    await openComboDemoList(tester);
    expect(find.text('All records'), findsOneWidget, reason: 'list open');
    await expectLater(
      find.byType(GalleryHost),
      matchesGoldenFile('../goldens/controls_era_combo_open.png'),
    );
  });

  testWidgets('gallery_shell', (tester) async {
    await pumpGalleryApp(tester);
    await expectLater(
      find.byType(GalleryHost),
      matchesGoldenFile('../goldens/gallery_shell.png'),
    );
  });

  testWidgets('gallery_shell_docked', (tester) async {
    await pumpGalleryApp(tester, size: const Size(800, 600));
    await showDockedKnobs(tester);
    await expectLater(
      find.byType(GalleryHost),
      matchesGoldenFile('../goldens/gallery_shell_docked.png'),
    );
  });
}
