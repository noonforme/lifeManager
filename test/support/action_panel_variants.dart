import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

/// The action panel demo's states its default golden cannot show, shared
/// by its synthetic and real-font variant goldens.

Future<void> asIs(WidgetTester tester) async {}

Finder get _primary => find.byWidgetPredicate(
  (widget) => widget is KeyButton && widget.kind == KeyKind.primary,
);

/// Types "eleven" into Paid hours and presses Enter: rejected, the draft
/// and the keyboard stay in the red editor.
Future<void> rejectHours(WidgetTester tester) async {
  final hours = find.byKey(const ValueKey('action-hours'));
  await tester.tap(hours, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  await tester.enterText(hours, 'eleven');
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

/// Presses the primary key: the panel goes busy.
Future<void> submit(WidgetTester tester) async {
  await tester.tap(_primary, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Submits, then finishes the synthetic run: two days done, one failed,
/// the error row scrolled into view.
Future<void> partlyFail(WidgetTester tester) async {
  await submit(tester);
  await tester.tap(
    find.widgetWithText(KeyButton, 'Finish synthetic run'),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

final actionPanelVariants =
    <(String, GalleryKnobs, Future<void> Function(WidgetTester))>[
      ('shell_action_panel_rejected', const GalleryKnobs(), rejectHours),
      ('shell_action_panel_busy', const GalleryKnobs(), submit),
      ('shell_action_panel_partial', const GalleryKnobs(), partlyFail),
      (
        'shell_action_panel_disabled_error',
        const GalleryKnobs(enabled: false, error: true),
        asIs,
      ),
    ];
