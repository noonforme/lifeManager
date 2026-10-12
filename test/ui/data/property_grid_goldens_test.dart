import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/property_grid_variants.dart';

/// The property grid demo's variant states (see the support file).
/// Real-font twins are in property_grid_real_font_test.dart.
void main() {
  for (final (name, demo, knobs, act) in propertyGridVariants) {
    testWidgets(name, (tester) async {
      await pumpPropertyGridVariant(tester, demo, knobs);
      await act(tester);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/$name.png'),
      );
    });
  }
}
