import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/shell/shell_dialog.dart';
import 'package:lifeos/shared/workbench/era_date_field.dart';
import 'package:lifeos/shared/workbench/era_icons.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

Widget _host(Widget child) => MaterialApp(
  home: LifeOSSkinScope(child: Scaffold(body: child)),
);

void main() {
  testWidgets('a dialog shows its caption and content over the window', (
    tester,
  ) async {
    var behind = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Shift 2026-09-08 Properties',
            onClose: () {},
            child: const Text('General'),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: KeyButton(label: 'Behind', onPressed: () => behind++),
          ),
        ),
      ),
    );
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    await tester.tap(find.text('Behind'), warnIfMissed: false);
    expect(behind, 0, reason: 'the window behind a dialog takes no input');
  });

  testWidgets('Escape and the close key close the dialog', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Record payslip',
            onClose: () => closed++,
            child: const SizedBox.shrink(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);
    await tester.tap(find.bySemanticsLabel('Close Record payslip'));
    expect(closed, 2);
  });

  testWidgets('a Properties sheet has OK and Cancel; both close it', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Pay period Properties',
            kind: ShellDialogKind.properties,
            onClose: () => closed++,
            child: const SizedBox.shrink(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.tap(find.text('OK'));
    await tester.tap(find.text('Cancel'));
    expect(closed, 2);
  });

  testWidgets('a form dialog adds no footer of its own', (tester) async {
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Manual shift',
            onClose: () {},
            child: const SizedBox.shrink(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('DialogCancelKey closes its dialog and is absent outside one', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Manual shift',
            onClose: () => closed++,
            child: const DialogCancelKey(),
          ),
          child: const DialogCancelKey(),
        ),
      ),
    );
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(closed, 1);
  });

  testWidgets('a dialog shrinks to 90 % of a small window', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Pay agreement',
            size: const Size(480, 600),
            onClose: () {},
            child: const SizedBox.expand(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    final size = tester.getSize(find.byKey(const ValueKey('shell-dialog')));
    expect(size.width, lessThanOrEqualTo(360));
    expect(size.height, lessThanOrEqualTo(360));
  });

  testWidgets('escape closes the calendar before the dialog', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Manual shift',
            onClose: () => closed++,
            child: EraDateField(
              label: 'Start date',
              fieldKey: const ValueKey('start'),
              value: const LocalDate(2026, 10, 3),
              today: const LocalDate(2026, 10, 3),
              onChanged: (_) {},
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsNothing);
    expect(closed, 0);
  });

  testWidgets('a message box has a warning icon and OK', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Work',
            kind: ShellDialogKind.message,
            size: const Size(380, 260),
            onClose: () => closed++,
            child: const Text('This record is no longer available.'),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.byType(EraIcon), findsOneWidget);
    await tester.tap(find.text('OK'));
    expect(closed, 1);
  });

  testWidgets('Enter presses OK on a Properties sheet, not a focused key', (
    tester,
  ) async {
    var closed = 0;
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Pay period Properties',
            kind: ShellDialogKind.properties,
            onClose: () => closed++,
            child: KeyButton(
              label: 'Mark reviewed',
              onPressed: () => pressed++,
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(closed, 1, reason: 'Enter is the default key, OK');
    // Tab to the record's own key: Enter now presses it instead.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, 1);
    expect(closed, 1);
  });

  testWidgets('a short dialog fits its content, up to its size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Work',
            kind: ShellDialogKind.message,
            size: const Size(380, 600),
            fitHeight: true,
            onClose: () {},
            child: const Text('This record is no longer available.'),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    final height = tester.getSize(find.byKey(const ValueKey('shell-dialog'))).height;
    expect(height, lessThan(200));
    expect(find.text('OK'), findsOneWidget);
  });
}
