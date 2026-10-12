@Tags(['real-font'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/era_editor_host_scope_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/era_editor_host_variants.dart';
import '../../support/gallery.dart';

/// The editor host demo's variant states in the bundled EraSans, for a
/// look by eye. Skipped by default; run:
/// flutter test --run-skipped -t real-font --update-goldens
///   test/ui/controls/era_editor_host_real_font_test.dart
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

  for (final (name, knobs, open) in eraEditorHostVariants) {
    testWidgets('real_font/$name', (tester) async {
      await pumpGalleryDemo(tester, eraEditorHostScopeDemo, knobs: knobs);
      await open(tester);
      await expectLater(
        open == noPopup ? find.byType(GalleryCanvas) : find.byType(GalleryHost),
        matchesGoldenFile('../goldens/real_font/$name.png'),
      );
    });
  }
}
