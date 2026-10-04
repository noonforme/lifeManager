import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/task_pane.dart';

/// Opens the selected record's Properties from its task link.
Future<void> openProperties(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TaskLink, 'Properties'));
  await tester.pumpAndSettle();
}

/// The open dialog, found by its caption.
Finder dialogTitled(String title) => find.bySemanticsLabel(title);

/// Scrolls the open dialog until [target] is built and on screen.
Future<void> revealInDialog(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('shell-dialog')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// Scrolls [target] into view inside its dialog, then taps it. Dialogs
/// have a fixed size, so a long form's keys may start below the fold.
Future<void> tapInDialog(WidgetTester tester, Finder target) async {
  await revealInDialog(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Selects the register row showing [cellText] and opens its Properties
/// with Enter, as the owner does after a save.
Future<void> openRowProperties(WidgetTester tester, String cellText) async {
  await tester.tap(
    find
        .descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Work register',
          ),
          matching: find.text(cellText),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}
