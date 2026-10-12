import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/action_panel_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/action_panel_variants.dart';
import '../../support/gallery.dart';

/// The action panel demo's variant states (see the support file). Real-font
/// twins are in action_panel_real_font_test.dart.
void main() {
  for (final (name, knobs, act) in actionPanelVariants) {
    testWidgets(name, (tester) async {
      await pumpGalleryDemo(tester, actionPanelDemo, knobs: knobs);
      await act(tester);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/$name.png'),
      );
    });
  }
}
