import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/employment_agreement_forms.dart'
    show staleMessage;
import 'package:lifeos/features/work/presentation/remove_shift_dialog.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../../../support/synthetic_shell.dart';
import '../../../support/work_dialogs.dart';

Finder _link(String label) => find.widgetWithText(TaskLink, label);
Finder _inDetails(Finder finder) => find.descendant(
  of: find.widgetWithText(TaskGroup, 'Details'),
  matching: finder,
);

/// Sets the register's Status filter to "Including void".
Future<void> _showVoid(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^Status, ')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Including void'));
  await tester.pumpAndSettle();
}

Future<void> _selectShift(WidgetTester tester) async {
  await pumpSyntheticShell(
    tester,
    size: const Size(1280, 800),
    screen: syntheticScreens['shell']!,
  );
  await tester.tap(find.text('2026-09-08'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Remove this shift… asks a reason, then voids the shift', (
    tester,
  ) async {
    await _selectShift(tester);
    expect(_inDetails(find.text('3 shifts')), findsOneWidget);
    expect(_inDetails(find.text('EUR 542.80')), findsOneWidget);

    await tester.tap(_link('Remove this shift…'));
    await tester.pumpAndSettle();
    expect(dialogTitled('Remove shift'), findsOneWidget);
    expect(
      find.text(
        'The shift stays in history as Void and no longer counts in the '
        'totals.',
      ),
      findsOneWidget,
    );

    // The reason is required, and said so on its field.
    await tester.tap(find.widgetWithText(KeyButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Enter why this shift is removed.'), findsOneWidget);
    expect(find.text('Shift removed.'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('remove-shift-reason')),
      'Entered twice',
    );
    await tester.tap(find.widgetWithText(KeyButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(dialogTitled('Remove shift'), findsNothing);
    expect(find.text('Shift removed.'), findsOneWidget);
    // The selection clears; with void rows hidden the row leaves the list,
    // and the shift leaves the totals.
    expect(find.widgetWithText(TaskGroup, 'Shift tasks'), findsNothing);
    expect(find.text('2026-09-08'), findsNothing);
    expect(_inDetails(find.text('2 shifts')), findsOneWidget);
    expect(_inDetails(find.text('EUR 322.00')), findsOneWidget);

    // Shown again, it reads Void, is not offered for removal again, and
    // its Properties say why it is void.
    await _showVoid(tester);
    expect(find.text('2026-09-08'), findsOneWidget);
    expect(find.text('Void'), findsOneWidget);
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    expect(_link('Remove this shift…'), findsNothing);
    expect(_link('Correct this shift…'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Shift void'), findsOneWidget);
    await revealInDialog(tester, find.text('Entered twice'));
    expect(find.text('Entered twice'), findsOneWidget);
    expect(find.text('Remove shift…'), findsNothing);
  });

  testWidgets('Cancel closes the dialog and removes nothing', (tester) async {
    await _selectShift(tester);
    await tester.tap(_link('Remove this shift…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KeyButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(dialogTitled('Remove shift'), findsNothing);
    expect(find.text('Shift removed.'), findsNothing);
    expect(_link('Remove this shift…'), findsOneWidget);
    expect(_inDetails(find.text('3 shifts')), findsOneWidget);
  });

  testWidgets('a shift removed from its Properties closes the sheet', (
    tester,
  ) async {
    await _selectShift(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tapInDialog(tester, find.text('Remove shift…'));
    await tester.enterText(
      find.byKey(const ValueKey('remove-shift-reason')),
      'Did not work it',
    );
    await tester.tap(find.widgetWithText(KeyButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Shift removed.'), findsOneWidget);
    expect(find.text('Shift 2026-09-08 Properties'), findsNothing);
    expect(_inDetails(find.text('2 shifts')), findsOneWidget);
  });

  testWidgets('Cancel waits while the removal is in flight', (tester) async {
    final pending = Completer<MutationOutcome<WorkShift>>();
    await _openDialog(tester, (_) => pending.future);
    await tester.enterText(
      find.byKey(const ValueKey('remove-shift-reason')),
      'Entered twice',
    );
    await tester.tap(find.widgetWithText(KeyButton, 'Remove'));
    await tester.pump();

    KeyButton key(String label) =>
        tester.widget<KeyButton>(find.widgetWithText(KeyButton, label));
    expect(key('Cancel').onPressed, isNull);
    expect(key('Remove').onPressed, isNull);

    pending.complete(const Stale<WorkShift>());
    await tester.pumpAndSettle();
    expect(key('Cancel').onPressed, isNotNull);
  });

  testWidgets('removing a replacement draft leaves the original void', (
    tester,
  ) async {
    await _selectShift(tester);
    await tester.tap(_link('Correct this shift…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      'Wrong end time',
    );
    await tapInDialog(
      tester,
      find.widgetWithText(KeyButton, 'Void original and create replacement'),
    );
    // The replacement draft opens on its sheet, where it can be removed.
    await tapInDialog(tester, find.text('Remove shift…'));
    await tester.enterText(
      find.byKey(const ValueKey('remove-shift-reason')),
      'Not needed after all',
    );
    await tester.tap(find.widgetWithText(KeyButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Shift removed.'), findsOneWidget);
    // The correction scoped the view to the shift's date, where nothing
    // effective is left.
    expect(_inDetails(find.text('0 shifts')), findsOneWidget);

    // Both are void and in history; the original reads as replaced.
    await _showVoid(tester);
    final rows = find.text('2026-09-08');
    expect(rows, findsNWidgets(2));
    final reasons = <String>{};
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('2026-09-08').at(i));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Shift void'), findsOneWidget);
      for (final reason in ['Wrong end time', 'Not needed after all']) {
        if (find.text(reason).evaluate().isNotEmpty) reasons.add(reason);
      }
      if (find.text('Wrong end time').evaluate().isNotEmpty) {
        expect(find.text('A corrected shift'), findsOneWidget);
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.text('Voided'), findsOneWidget);
        expect(find.text('Reason: Wrong end time'), findsOneWidget);
      } else {
        expect(find.text('A corrected shift'), findsNothing);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
    expect(reasons, {'Wrong end time', 'Not needed after all'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused removal keeps the dialog open and says why', (
    tester,
  ) async {
    final outcomes = <MutationOutcome<WorkShift>>[
      const Stale<WorkShift>(),
      const Invalid<WorkShift>({
        'state': [FieldIssue(FieldIssueCode.conflict)],
      }),
    ];
    final removed = await _openDialog(
      tester,
      (_) async => outcomes.removeAt(0),
    );
    await tester.enterText(
      find.byKey(const ValueKey('remove-shift-reason')),
      'Entered twice',
    );

    await tester.tap(find.widgetWithText(KeyButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text(staleMessage), findsOneWidget);
    expect(dialogTitled('Remove shift'), findsOneWidget);

    await tester.tap(find.widgetWithText(KeyButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('This shift is already void.'), findsOneWidget);
    expect(find.text(staleMessage), findsNothing);

    await tester.tap(find.widgetWithText(KeyButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(removed.value, isFalse);
  });
}

/// Opens "Remove shift" for [_shift] over a bare app; the result holds
/// what the dialog returned once it closes.
Future<ValueNotifier<bool?>> _openDialog(
  WidgetTester tester,
  Future<MutationOutcome<WorkShift>> Function(String reason) onRemove,
) async {
  final result = ValueNotifier<bool?>(null);
  addTearDown(result.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result.value = await askRemoveShift(
            context,
            shift: _shift,
            onRemove: onRemove,
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

final _shift = WorkShift(
  id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  agreementId: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  state: ShiftState.finalized,
  startUtc: DateTime.utc(2026, 9, 8, 19),
  endUtc: DateTime.utc(2026, 9, 9, 3),
  timezoneId: 'Europe/Vilnius',
  localStartDate: const LocalDate(2026, 9, 8),
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 9),
  updatedAtUtc: DateTime.utc(2026, 9, 9),
  revision: const Revision(1),
);
