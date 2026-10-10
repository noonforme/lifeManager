@Tags(['real-font'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/gallery.dart';

/// Every gallery demo in the bundled EraSans, for a look by eye. Skipped by
/// default; run:
/// flutter test --run-skipped -t real-font --update-goldens
///   test/ui/gallery/gallery_real_font_test.dart
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

  for (final demo in galleryDemos) {
    testWidgets('real_font/${demo.goldenName}', (tester) async {
      await pumpGalleryDemo(tester, demo);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/real_font/${demo.goldenName}.png'),
      );
    });
  }
}
