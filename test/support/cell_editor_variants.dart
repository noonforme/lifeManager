import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';

/// The cell editor demo's states its default golden cannot show, shared by
/// its synthetic and real-font variant goldens: a rejected draft in an
/// open editor (the panel row and the grid cell share it), and a
/// read-only form with errors.

Future<void> asIs(WidgetTester tester) async {}

/// Types "8x" into the panel's Hours and presses Enter: rejected, the
/// draft and the keyboard stay in the red editor.
Future<void> rejectHours(WidgetTester tester) async {
  final hours = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.controller?.text == '8',
  );
  await tester.enterText(hours.first, '8x');
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

final cellEditorVariants =
    <(String, GalleryKnobs, Future<void> Function(WidgetTester))>[
      ('controls_cell_editor_rejected', const GalleryKnobs(), rejectHours),
      (
        'controls_cell_editor_disabled_error',
        const GalleryKnobs(enabled: false, error: true),
        asIs,
      ),
    ];
