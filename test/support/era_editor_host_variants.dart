import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

/// The editor host demo's states its default golden cannot show, shared by
/// its synthetic and real-font variant goldens: a read-only form with
/// errors, and a calendar and a list opened by mouse.

Future<void> noPopup(WidgetTester tester) async {}

Finder get _bare => find.byWidgetPredicate(
  (widget) => widget is EraEditorHostScope && widget.bare,
);

/// A mouse click on the labelled host's date drop arrow; the calendar
/// drops below with room to spare.
Future<void> openCalendar(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is EraEditorHostScope && !widget.bare,
      ),
      matching: find.byKey(const ValueKey('era-date-drop')),
    ),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

/// A mouse click on the bare combo cell, then the pointer resting on its
/// last row, which lights while focus stays on the box.
Future<void> openList(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  final combo = find.descendant(of: _bare, matching: find.byType(EraComboFace));
  await mouse.moveTo(tester.getCenter(combo));
  await mouse.down(tester.getCenter(combo));
  await mouse.up();
  await tester.pumpAndSettle();
  await mouse.moveTo(
    tester.getCenter(find.widgetWithText(MenuItemButton, 'Payslips')),
  );
  await tester.pumpAndSettle();
}

final eraEditorHostVariants =
    <(String, GalleryKnobs, Future<void> Function(WidgetTester))>[
      (
        'controls_era_editor_host_scope_disabled_error',
        const GalleryKnobs(enabled: false, error: true),
        noPopup,
      ),
      (
        'controls_era_editor_host_scope_open_calendar',
        const GalleryKnobs(),
        openCalendar,
      ),
      (
        'controls_era_editor_host_scope_open_list',
        const GalleryKnobs(),
        openList,
      ),
    ];
