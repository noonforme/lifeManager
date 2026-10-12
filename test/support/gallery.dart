import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
