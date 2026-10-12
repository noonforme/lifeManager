import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/app_frame_variants.dart';
import '../../support/gallery.dart';

/// The frame demo's variant states (see the support file). Real-font twins
/// are in app_frame_real_font_test.dart.
void main() {
  for (final (name, demo, knobs, act) in appFrameVariants) {
    testWidgets(name, (tester) async {
      await pumpGalleryDemo(tester, demo, knobs: knobs);
      await act(tester);
      expectVariantState(tester, name);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/$name.png'),
      );
    });
  }
}
