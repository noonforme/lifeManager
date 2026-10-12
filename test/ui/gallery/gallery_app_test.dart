import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/control_demos.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

void main() {
  GalleryKnobs knobs(WidgetTester tester) => galleryCanvas(tester).knobs;

  Finder knobEditor(String key) => find.byKey(ValueKey('property-editor:$key'));

  testWidgets('the gallery is an AppFrame with the tree, Details, the demo '
      'and the knobs', (tester) async {
    await pumpGalleryApp(tester);
    expect(find.byType(AppFrame), findsOneWidget);
    expect(find.byType(TreeView), findsOneWidget);
    expect(find.byType(PropertyGrid), findsOneWidget);
    expect(find.byType(DataRegister), findsNothing, reason: 'old list gone');
    expect(galleryCanvas(tester).demo.id, galleryDemos.first.id);
    for (final folder in ['Foundation', 'Controls', 'Data', 'Shell']) {
      final row = await galleryTreeRow(tester, folder);
      expect(row.hitTestable(), findsOneWidget);
    }
    expect(
      find.text('Synthetic data only; no database is open.'),
      findsOneWidget,
    );
  });

  testWidgets('a demo opens from the tree; a folder click keeps the demo', (
    tester,
  ) async {
    await pumpGalleryApp(tester);
    await openDemoInTree(tester, galleryDemos[1].widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
    expect(
      find.descendant(
        of: find.byType(DetailsBox),
        matching: find.text(galleryDemos[1].id),
      ),
      findsOneWidget,
    );
    final folder = await galleryTreeRow(tester, 'Data');
    await tester.tap(folder, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
  });

  testWidgets('the knobs reach the demo through the property grid; Enter '
      'walks them in order', (tester) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'enabled');
    await tickOpenKnob(tester, 'enabled');
    expect(knobs(tester).enabled, isFalse, reason: 'previewed before Enter');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobEditor('error'), findsOneWidget, reason: 'Enter opens next');
    await tickOpenKnob(tester, 'error');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'longText');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await pickOpenTextSize(tester, '200 %');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobEditor('textScale'), findsNothing, reason: 'last closes');
    final shown = knobs(tester);
    expect(
      (shown.enabled, shown.error, shown.longText, shown.textScale),
      (false, true, true, 2.0),
    );
    expect(find.text('Text 200 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Esc drops a previewed knob; the demo returns to the kept '
      'knobs', (tester) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'error');
    await tickOpenKnob(tester, 'error');
    expect(knobs(tester).error, isTrue);
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(knobs(tester).error, isFalse);
    expect(knobEditor('error'), findsNothing);
  });

  testWidgets('picking another demo keeps an open knob draft first', (
    tester,
  ) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'longText');
    await tickOpenKnob(tester, 'longText');
    await openDemoInTree(tester, galleryDemos[1].widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
    expect(knobs(tester).longText, isTrue);
    expect(knobEditor('longText'), findsNothing);
  });

  testWidgets('picking the current demo flushes its knob, closes the folded '
      'tree and keeps demo state', (tester) async {
    final demo = controlDemos.singleWhere(
      (demo) => demo.id == 'controls/era_check_box',
    );
    await pumpGalleryApp(tester, size: const Size(800, 600), demos: [demo]);
    final box = find.descendant(
      of: find.byType(GalleryCanvas),
      matching: find.byType(EraCheckBox),
    );
    await tester.tap(find.text('Off days'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.widget<EraCheckBox>(box).value, isFalse);
    await showDockedKnobs(tester);
    await openKnob(tester, 'error');
    await tickOpenKnob(tester, 'error');
    await openDemoInTree(tester, demo.widget);
    expect(galleryFrame(tester).treeOpen, isFalse);
    expect(knobEditor('error'), findsNothing, reason: 'draft flushed');
    expect(knobs(tester).error, isTrue);
    expect(galleryCanvas(tester).demo.id, demo.id);
    expect(tester.widget<EraCheckBox>(box).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distant tree demos and the first demo are reachable by mouse '
      'at wide and folded sizes, at both text scales', (tester) async {
    for (final size in const [Size(1280, 800), Size(800, 600)]) {
      for (final scale in [1.0, 2.0]) {
        await pumpGalleryApp(
          tester,
          size: size,
          knobs: GalleryKnobs(textScale: scale),
        );
        await openDemoInTree(tester, galleryDemos.last.widget);
        expect(galleryCanvas(tester).demo.id, galleryDemos.last.id);
        await openDemoInTree(tester, galleryDemos.first.widget);
        expect(galleryCanvas(tester).demo.id, galleryDemos.first.id);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Reset knobs drops the draft and restores the opening knobs', (
    tester,
  ) async {
    await pumpGalleryApp(tester, knobs: const GalleryKnobs(longText: true));
    await openKnob(tester, 'enabled');
    await tickOpenKnob(tester, 'enabled');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'error');
    await tester.tap(find.text('Reset knobs'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final shown = knobs(tester);
    expect((shown.enabled, shown.error, shown.longText), (true, false, true));
    expect(knobEditor('error'), findsNothing);
  });

  testWidgets("a demo's own state does not survive leaving it", (tester) async {
    final checkBox = controlDemos.singleWhere(
      (demo) => demo.id == 'controls/era_check_box',
    );
    final keys = controlDemos.singleWhere(
      (demo) => demo.id == 'controls/key_button',
    );
    await pumpGalleryApp(tester, demos: [checkBox, keys]);
    EraCheckBox box() => tester.widget<EraCheckBox>(
      find.descendant(
        of: find.byType(GalleryCanvas),
        matching: find.byType(EraCheckBox),
      ),
    );
    expect(box().value, isTrue);
    await tester.tap(find.text('Off days'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(box().value, isFalse);
    await openDemoInTree(tester, 'KeyButton');
    await openDemoInTree(tester, 'EraCheckBox');
    expect(box().value, isTrue);
  });

  testWidgets('narrowing with a knob editor open shows the docked Knobs tab '
      'and keeps the draft', (tester) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'error');
    await tickOpenKnob(tester, 'error');
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    expect(galleryFrame(tester).layout?.propertiesDocked, isTrue);
    expect(knobEditor('error'), findsOneWidget);
    expect(knobs(tester).error, isTrue, reason: 'still previewed');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobs(tester).error, isTrue);
  });

  testWidgets('at 800 x 600 every knob and the tree are reachable, also '
      'at 200 % text', (tester) async {
    await pumpGalleryApp(tester, size: const Size(800, 600));
    expect(galleryFrame(tester).layout?.treeFolded, isTrue);
    await openDemoInTree(tester, galleryDemos[1].widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
    expect(galleryFrame(tester).treeOpen, isFalse, reason: 'a pick closes');

    await showDockedKnobs(tester);
    await openKnob(tester, 'enabled');
    await tickOpenKnob(tester, 'enabled');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'error');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'longText');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await pickOpenTextSize(tester, '200 %');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobs(tester).textScale, 2);
    expect(tester.takeException(), isNull);

    // At 200 % text, untick each check again. Enter keeps it and opens the
    // next knob unchanged; Esc closes that one, so the next click lands on
    // a plain value.
    for (final key in ['enabled', 'error', 'longText']) {
      await openKnob(tester, key);
      await tickOpenKnob(tester, key);
      await pressKey(tester, LogicalKeyboardKey.enter);
      await pressKey(tester, LogicalKeyboardKey.escape);
    }
    final shown = knobs(tester);
    expect(
      (shown.enabled, shown.error, shown.longText, shown.textScale),
      (true, false, false, 2.0),
    );
    await openDemoInTree(tester, galleryDemos.first.widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos.first.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the gallery holds at 200 % text with long labels', (
    tester,
  ) async {
    await pumpGalleryApp(
      tester,
      knobs: const GalleryKnobs(longText: true, textScale: 2),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryCanvas), findsOneWidget);
  });

  testWidgets('every demo builds alone without errors', (tester) async {
    for (final demo in galleryDemos) {
      await pumpGalleryDemo(tester, demo);
      expect(tester.takeException(), isNull, reason: demo.id);
    }
  });

  testWidgets('every demo runs inside the gallery shell across the full '
      'size and text-scale matrix', (tester) async {
    for (final size in const [
      Size(1280, 800),
      Size(1025, 768),
      Size(1024, 768),
      Size(1023, 768),
      Size(960, 760),
      Size(861, 600),
      Size(860, 600),
      Size(859, 600),
      Size(800, 600),
    ]) {
      for (final scale in [1.0, 2.0]) {
        for (final demo in galleryDemos) {
          final reason = '${demo.id} at $size x$scale';
          await pumpGalleryApp(
            tester,
            size: size,
            knobs: GalleryKnobs(textScale: scale, longText: true, error: true),
            demos: [demo],
          );
          expect(tester.takeException(), isNull, reason: reason);
          final canvas = galleryCanvas(tester);
          expect(canvas.demo.id, demo.id, reason: reason);
          expect(canvas.knobs.textScale, scale, reason: reason);
          final context = tester.element(find.byType(AppFrame).first);
          expect(
            MediaQuery.textScalerOf(context).scale(100),
            100 * scale,
            reason: reason,
          );
        }
      }
    }
  });
}
