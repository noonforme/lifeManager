import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/cell_editor_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/cell_editor_variants.dart';
import '../../support/gallery.dart';

/// The cell editor demo's variant states (see the support file). Real-font
/// twins are in cell_editor_real_font_test.dart.
void main() {
  for (final (name, knobs, act) in cellEditorVariants) {
    testWidgets(name, (tester) async {
      await pumpGalleryDemo(tester, cellEditorDemo, knobs: knobs);
      await act(tester);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/$name.png'),
      );
    });
  }
}
