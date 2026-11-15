import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_app.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

/// Pumps one gallery demo alone on its canvas, at the demo's golden size.
Future<void> pumpGalleryDemo(
  WidgetTester tester,
  GalleryDemo demo, {
  GalleryKnobs knobs = const GalleryKnobs(),
}) async {
  tester.view.physicalSize = demo.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryHost(
      home: GalleryCanvas(key: ValueKey(demo.id), demo: demo, knobs: knobs),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the combo demo's list with a mouse click on its face.
Future<void> openComboDemoList(WidgetTester tester) async {
  await tester.tap(find.byType(EraComboFace), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Pumps a fresh gallery on a window of [size], including in a matrix loop.
/// To test resizing with a draft, change tester.view.physicalSize directly
/// after this mount; calling this helper again deliberately resets state.
Future<void> pumpGalleryApp(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  GalleryKnobs knobs = const GalleryKnobs(),
  List<GalleryDemo>? demos,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryApp(key: UniqueKey(), demos: demos, initialKnobs: knobs),
  );
  await tester.pumpAndSettle();
}

/// The gallery's demo canvas (the gallery's own, not a nested demo's).
GalleryCanvas galleryCanvas(WidgetTester tester) =>
    tester.widget<GalleryCanvas>(find.byType(GalleryCanvas).first);

/// The gallery's own frame state (the first AppFrame in the tree).
AppFrameState galleryFrame(WidgetTester tester) =>
    tester.state<AppFrameState>(find.byType(AppFrame).first);

/// Finds a folder or demo row in the gallery's lazy tree. Open the overlay
/// if needed, scroll back to the top, then wheel until the row is built.
/// ensureVisible alone cannot find rows that ListView has not built yet.
Future<Finder> galleryTreeRow(WidgetTester tester, String label) async {
  final frame = galleryFrame(tester);
  if ((frame.layout?.treeFolded ?? false) && !frame.treeOpen) {
    await tester.tap(find.text('Tree').first, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  }
  final tree = find.byType(TreeView).first;
  final list = find.descendant(of: tree, matching: find.byType(ListView));
  await tester.ensureVisible(list);
  await tester.pumpAndSettle();
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (
    var attempts = 0;
    position.pixels > position.minScrollExtent + 0.5;
    attempts++
  ) {
    expect(attempts, lessThan(100), reason: 'rewind tree for $label');
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(list),
        scrollDelta: const Offset(0, -160),
      ),
    );
    await tester.pumpAndSettle();
  }
  final row = find.descendant(of: tree, matching: find.text(label));
  for (var attempts = 0; row.evaluate().isEmpty; attempts++) {
    expect(attempts, lessThan(100), reason: 'build tree row $label');
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(list),
        scrollDelta: const Offset(0, 160),
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  expect(row.hitTestable(), findsOneWidget, reason: label);
  return row;
}

/// Clicks [widget]'s row, including rows initially outside the lazy list.
Future<void> openDemoInTree(WidgetTester tester, String widget) async {
  final row = await galleryTreeRow(tester, widget);
  await tester.tap(row, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Shows the docked Knobs tab beside Summary (windows under 860 px).
Future<void> showDockedKnobs(WidgetTester tester) async {
  final tab = find.descendant(
    of: find.byType(TabStrip),
    matching: find.text('Knobs'),
  );
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Clicks knob [key]'s value, opening its editor.
Future<void> openKnob(WidgetTester tester, String key) async {
  final value = find.byKey(ValueKey('property-value:$key'));
  await tester.ensureVisible(value);
  await tester.pumpAndSettle();
  expect(value.hitTestable(), findsOneWidget, reason: key);
  await tester.tap(value, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Ticks or unticks the check box of the open knob [key].
Future<void> tickOpenKnob(WidgetTester tester, String key) async {
  final box = find.descendant(
    of: find.byKey(ValueKey('property-editor:$key')),
    matching: find.byKey(const ValueKey('era-check-box')),
  );
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Picks [label] from the open Text size editor's list.
Future<void> pickOpenTextSize(WidgetTester tester, String label) async {
  final face = find.byKey(const ValueKey('property-editor:textScale'));
  await tester.ensureVisible(face);
  await tester.pumpAndSettle();
  await tester.tap(face, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}
