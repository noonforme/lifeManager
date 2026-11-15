import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/era_editor_host_scope_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/era_editor_host_variants.dart';
import '../../support/gallery.dart';

/// The editor host demo's variant states (see the support file), the
/// popups over the whole window as they paint over the canvas. Real-font
/// twins are in era_editor_host_real_font_test.dart.
void main() {
  for (final (name, knobs, open) in eraEditorHostVariants) {
    testWidgets(name, (tester) async {
      await pumpGalleryDemo(tester, eraEditorHostScopeDemo, knobs: knobs);
      await open(tester);
      await expectLater(
        open == noPopup ? find.byType(GalleryCanvas) : find.byType(GalleryHost),
        matchesGoldenFile('../goldens/$name.png'),
      );
    });
  }
}
