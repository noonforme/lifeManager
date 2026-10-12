import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/property_grid_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

/// The property grid demo's states its default golden cannot show, shared
/// by its synthetic and real-font variant goldens: an open editor with a
/// rejected value and its description, the A–Z order, and the narrow
/// 260 px column at 200 % text with the date editor open.

/// Pumps [demo] alone on a view as large as its canvas at [knobs]' text
/// scale, so a 200 % variant shows the whole column, not its top-left
/// quarter.
Future<void> pumpPropertyGridVariant(
  WidgetTester tester,
  GalleryDemo demo,
  GalleryKnobs knobs,
) async {
  tester.view.physicalSize = demo.size * knobs.textScale;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryHost(
      home: GalleryCanvas(key: ValueKey(demo.id), demo: demo, knobs: knobs),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Clears the Note and presses Enter: rejected, the draft and the error
/// stay in the editor, and the description pane leads with the error.
Future<void> rejectNote(WidgetTester tester) async {
  await _tap(tester, find.byKey(const ValueKey('property-value:note')));
  await tester.enterText(
    find.byKey(const ValueKey('property-editor:note')),
    '',
  );
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

Future<void> sortAlphabetically(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('property-order-alphabetical')));

/// Opens the date editor, which is wider than the narrow column's value
/// cell at 200 % text.
Future<void> openDate(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('property-value:date')));

final propertyGridVariants =
    <(String, GalleryDemo, GalleryKnobs, Future<void> Function(WidgetTester))>[
      (
        'data_property_grid_rejected',
        propertyGridDemo,
        const GalleryKnobs(),
        rejectNote,
      ),
      (
        'data_property_grid_alphabetical',
        propertyGridDemo,
        const GalleryKnobs(),
        sortAlphabetically,
      ),
      (
        'data_property_grid_260_200',
        propertyGridDemoAt(260),
        const GalleryKnobs(textScale: 2),
        openDate,
      ),
    ];
