import 'package:flutter_test/flutter_test.dart';

import '../../support/data_grid_variants.dart';

void main() {
  for (final (name, knobs, act) in dataGridVariants) {
    testWidgets(name, (tester) async {
      await pumpDataGridVariant(tester, knobs);
      await act(tester);
      await expectLater(
        find.byKey(dataGridVariantCanvas),
        matchesGoldenFile('../goldens/$name.png'),
      );
    });
  }
}
