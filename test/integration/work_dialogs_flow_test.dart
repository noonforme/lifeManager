import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../support/era_pickers.dart';
import '../support/synthetic_shell.dart';
import '../support/work_dialogs.dart';

void main() {
  testWidgets('selecting a row opens no dialog; Enter opens its Properties', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('mouse Back closes Properties and Forward reopens it', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);

    // The toolbar is behind the modal sheet; the mouse buttons still travel.
    Future<void> mouse(int button) async {
      final gesture = await tester.startGesture(
        const Offset(5, 400),
        kind: PointerDeviceKind.mouse,
        buttons: button,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await mouse(kBackMouseButton);
    expect(find.text('Shift 2026-09-08 Properties'), findsNothing);
    await mouse(kForwardMouseButton);
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
  });

  testWidgets('closing Properties and pressing Back reopens it', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel('Close Shift 2026-09-08 Properties'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
  });

  testWidgets('a saved manual shift closes the dialog and says so', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['form']!,
    );
    await setTime(tester, 'shift-start-time', const LocalTime(8, 0));
    await setTime(tester, 'shift-end-time', const LocalTime(16, 0));
    await tapInDialog(tester, find.byKey(const ValueKey('save-manual-shift')));
    expect(find.text('Save manual shift'), findsNothing);
    expect(find.text('Shift saved.'), findsOneWidget);
  });

  testWidgets('an invalid manual shift keeps the dialog and its values', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['form']!,
    );
    await setTime(tester, 'shift-start-time', const LocalTime(8, 0));
    await tapInDialog(tester, find.byKey(const ValueKey('save-manual-shift')));
    expect(find.byKey(const ValueKey('save-manual-shift')), findsOneWidget);
    expect(find.text('Shift saved.'), findsNothing);
    expect(timeIn(tester, 'shift-start-time'), const LocalTime(8, 0));
  });

  testWidgets('right-click › Properties opens the sheet', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Properties').last);
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
  });

  testWidgets('closing a dialog gives the keyboard back to the list', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsNothing);
    // Down to the next row, then Enter opens its Properties.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-09 Properties'), findsOneWidget);
  });

  testWidgets('the one-key Record work step fits its content', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('Add a shift'));
    await tester.pumpAndSettle();
    expect(find.text('Add manual shift'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('shell-dialog'))).height,
      lessThan(220),
    );
  });

  testWidgets('a form keeps era keys of one size at the window foot', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['form']!,
    );
    final dialog = tester.getRect(find.byKey(const ValueKey('shell-dialog')));
    final save = find.byKey(const ValueKey('save-manual-shift'));
    final cancel = find.widgetWithText(KeyButton, 'Cancel');
    expect(tester.widget(save), isA<KeyButton>());
    final saveRect = tester.getRect(save);
    final cancelRect = tester.getRect(cancel);
    expect(saveRect.height, cancelRect.height);
    expect(saveRect.top, cancelRect.top);
    // Bottom-right, as the era's OK and Cancel sat, not under the fields.
    expect(dialog.bottom - cancelRect.bottom, lessThanOrEqualTo(12));
    expect(dialog.right - cancelRect.right, lessThanOrEqualTo(12));
  });
}
