@Tags(['real-font'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/data_grid_variants.dart';

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
  for (final (name, knobs, act) in dataGridVariants) {
    testWidgets('real_font/$name', (tester) async {
      await pumpDataGridVariant(tester, knobs);
      await act(tester);
      await expectLater(
        find.byKey(dataGridVariantCanvas),
        matchesGoldenFile('../goldens/real_font/$name.png'),
      );
    });
  }
}
