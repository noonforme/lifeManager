import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/control_demos.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';
import '../../support/ui_library.dart';

void main() {
  testWidgets('every demo builds alone, plain and with every knob', (
    tester,
  ) async {
    for (final demo in galleryDemos) {
      for (final knobs in const [
        GalleryKnobs(),
        GalleryKnobs(error: true, longText: true),
        GalleryKnobs(enabled: false, error: true, longText: true),
        GalleryKnobs(enabled: false, error: true, longText: true, textScale: 2),
      ]) {
        await pumpGalleryDemo(tester, demo, knobs: knobs);
        expect(tester.takeException(), isNull, reason: demo.id);
      }
    }
  });

  test('demo ids are sorted by folder and id', () {
    final ids = galleryDemos.map((demo) => demo.id).toList();
    expect(ids, orderedEquals([...ids]..sort()));
  });

  testWidgets("the Enabled knob disables the key demo's keys", (tester) async {
    final demo = controlDemos.singleWhere((d) => d.id == 'controls/key_button');
    await pumpGalleryDemo(
      tester,
      demo,
      knobs: const GalleryKnobs(enabled: false),
    );
    final keys = tester.widgetList<KeyButton>(find.byType(KeyButton)).toList();
    expect(keys, hasLength(KeyKind.values.length));
    expect(keys.map((key) => key.onPressed), everyElement(isNull));
  });

  testWidgets('the check box demo toggles', (tester) async {
    final demo = controlDemos.singleWhere(
      (d) => d.id == 'controls/era_check_box',
    );
    await pumpGalleryDemo(tester, demo);
    expect(tester.widget<EraCheckBox>(find.byType(EraCheckBox)).value, isTrue);
    await tester.tap(find.text('Off days'));
    await tester.pump();
    expect(tester.widget<EraCheckBox>(find.byType(EraCheckBox)).value, isFalse);
  });

  test('every library widget has exactly one demo, in its own folder', () {
    final classes = libraryWidgetClasses();
    expect(classes.length, greaterThanOrEqualTo(44));
    final byWidget = <String, List<GalleryDemo>>{};
    for (final demo in galleryDemos) {
      byWidget.putIfAbsent(demo.widget, () => []).add(demo);
    }
    expect(byWidget.keys.toSet(), classes.keys.toSet());
    for (final MapEntry(key: name, value: demos) in byWidget.entries) {
      expect(demos, hasLength(1), reason: name);
      expect(
        demos.single.folder,
        classes[name]!.split('/').first,
        reason: name,
      );
    }
    expect(
      galleryDemos.map((demo) => demo.id).toSet(),
      hasLength(galleryDemos.length),
    );
  });

  testWidgets('every demo holds at 200 % text with long labels and errors', (
    tester,
  ) async {
    final broken = <String>[];
    for (final demo in galleryDemos) {
      await pumpGalleryDemo(
        tester,
        demo,
        knobs: const GalleryKnobs(longText: true, error: true, textScale: 2),
      );
      if (tester.takeException() != null) broken.add(demo.id);
    }
    expect(broken, isEmpty);
  });

  testWidgets('with Enabled off, no demo leaves a key or step key live', (
    tester,
  ) async {
    final live = <String>[];
    for (final demo in galleryDemos) {
      await pumpGalleryDemo(
        tester,
        demo,
        knobs: const GalleryKnobs(enabled: false),
      );
      if (tester
              .widgetList<KeyButton>(find.byType(KeyButton))
              .any((key) => key.onPressed != null) ||
          tester
              .widgetList<StepKey>(find.byType(StepKey))
              .any((key) => key.onPressed != null)) {
        live.add(demo.id);
      }
    }
    expect(live, isEmpty);
  });

  testWidgets('with Enabled off, the caption bar demo has no close key', (
    tester,
  ) async {
    final demo = galleryDemos.singleWhere((d) => d.id == 'shell/caption_bar');
    await pumpGalleryDemo(
      tester,
      demo,
      knobs: const GalleryKnobs(enabled: false),
    );
    expect(tester.widget<CaptionBar>(find.byType(CaptionBar)).onClose, isNull);
  });
}
