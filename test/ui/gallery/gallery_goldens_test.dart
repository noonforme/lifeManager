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
}
