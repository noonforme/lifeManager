import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/work_shell/shifts_action.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/shift_lifecycle_service.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show click, gridCell, press, pushKey, toolbarKey;
import '../../support/scripted_lifecycle.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/shifts_sheet_fixture.dart';

const _monday = LocalDate(2026, 10, 5);

/// The rotation starting with Night: the 5th, changed as a Day shift, is a
/// Night now.
const _nightFirst = [
  CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
  CycleBlock(count: 3, shiftTypeId: null),
  CycleBlock(count: 3, shiftTypeId: ShiftTypeId('day')),
  CycleBlock(count: 3, shiftTypeId: null),
];

void main() {
  KeyButton keyOf(WidgetTester tester, String label) =>
      tester.widget<KeyButton>(toolbarKey(label));

  final panel = find.byType(ActionPanel);
  final reason = find.byKey(const ValueKey('action-reason'));

  /// Finalizes a shift on the 20th while the sheet is open.
  Future<WorkShift> finish(WidgetTester tester, ShiftsSheetFixture fixture) =>
      tester.runAsync(() => fixture.finishShift(20)).then((shift) async {
        await settleSheet(tester);
        return shift!;
      });

  /// Types [text] into the panel's reason and presses Enter.
  Future<void> typeReason(WidgetTester tester, String text) async {
    await click(tester, reason);
    await tester.enterText(reason, text);
    await press(tester, LogicalKeyboardKey.enter);
  }

  for (final correct in [false, true]) {
    for (final write in [false, true]) {
      testWidgets(
        'uncertain action is locked and checks without retry (correct=$correct, write=$write)',
        (tester) async {
          late ScriptedLifecycle storage;
          final fixture = await pumpShiftsSheet(
            tester,
            work: (fixture) {
              storage = ScriptedLifecycle(fixture.schedule.shifts);
              return fixture.work.replacing(
                shifts: ShiftLifecycleService(
                  storage,
                  idFactory: fixture.schedule.ids,
                  clock: fixture.schedule.clock,
                ),
              );
            },
          );
          final shift = await finish(tester, fixture);
          await selectShiftsRow(tester, storedRowId(shift));
          await click(tester, toolbarKey(correct ? 'Correct…' : 'Void…'));
          await typeReason(tester, 'Synthetic correction');
          storage.next = (
            write: write,
            report: const Uncertain(SafeFailureCode.commitOutcomeUnknown),
          );
          await click(
            tester,
            pushKey(
              correct
                  ? ShiftsActionWords.correctPrimary
                  : ShiftsActionWords.voidPrimary,
            ),
          );
          await settleSheet(tester);
          expect(sheetOf(tester).action?.phase, ShiftsActionPhase.uncertain);
          final actionPanel = tester.widget<ActionPanel>(panel);
          expect(actionPanel.groups().last.fields.single.enabled, isFalse);
          expect(pushKey(ShiftsActionWords.check), findsOneWidget);
          await click(tester, pushKey(ShiftsActionWords.check));
          await settleSheet(tester);
          expect(storage.commits, 1);
          if (write) {
            expect(panel, findsNothing);
            final saved = await tester.runAsync(
              () => fixture.reads.shift(shift.id),
            );
            expect(saved!.shift.state, ShiftState.voided);
            if (correct) {
              expect(sheetOf(tester).selectedId, isNot(storedRowId(shift)));
            }
          } else {
            expect(sheetOf(tester).action?.phase, ShiftsActionPhase.input);
            expect(statusNotice(tester), ShiftsActionWords.notDone);
          }
          await closeShiftsSheet(tester, fixture);
        },
      );
    }
  }

  testWidgets('Correct… opens its panel in the property column; Void and '
      'replace selects the replacement draft, ready to edit', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final shift = await finish(tester, fixture);
    await selectShiftsRow(tester, storedRowId(shift));
    await click(tester, toolbarKey('Correct…'));
    expect(panel, findsOneWidget);
    expect(find.byType(PropertyGrid), findsNothing);
    expect(statusNotice(tester), ShiftsActionWords.correctHint);

    await click(tester, pushKey(ShiftsActionWords.correctPrimary));
    await settleSheet(tester);
    expect(statusNotice(tester), ShiftsActionWords.correctReason);
    expect(
      find.descendant(
        of: panel,
        matching: find.text(ShiftsActionWords.correctReason),
      ),
      findsOneWidget,
    );

    await typeReason(tester, 'Wrong end');
    await click(tester, pushKey(ShiftsActionWords.correctPrimary));
    await settleSheet(tester);
    expect(panel, findsNothing);
    expect(statusNotice(tester), ShiftsNotices.corrected);
    final draft = sheetOf(tester).selectedId!;
    expect(draft, isNot(storedRowId(shift)));
    expect(
      find.descendant(
        of: await gridCell(tester, storedRowId(shift), 'status'),
        matching: find.text('Void'),
      ),
      findsOneWidget,
    );
    await stepGridTime(tester, draft, 'end', 'up');
    expect(statusNotice(tester), startsWith('Unsaved shift:'));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a Void panel with a reason typed asks before another row is '
      'selected', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final shift = await finish(tester, fixture);
    await selectShiftsRow(tester, storedRowId(shift));
    await click(tester, toolbarKey('Void…'));
    await typeReason(tester, 'Not worked');

    await selectShiftsRow(tester, plannedRowId(_monday));
    expect(find.byType(ConfirmWindow<ConfirmAnswer>), findsOneWidget);
    await click(tester, pushKey('Keep editing'));
    expect(panel, findsOneWidget);
    expect(sheetOf(tester).selectedId, storedRowId(shift));

    await selectShiftsRow(tester, plannedRowId(_monday));
    await click(tester, pushKey('Discard'));
    await settleSheet(tester);
    expect(panel, findsNothing);
    expect(find.byType(PropertyGrid), findsOneWidget);
    expect(sheetOf(tester).selectedId, plannedRowId(_monday));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('record commands are greyed in place with their reason where '
      'they do not apply', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await selectShiftsRow(tester, plannedRowId(_monday));
    for (final (label, reason) in [
      ('Correct…', ShiftsCommandWords.correctOnlyFinalized),
      ('Void…', ShiftsCommandWords.voidOnlyStored),
      ('Remove change', ShiftsCommandWords.removeOnlyReview),
    ]) {
      expect(keyOf(tester, label).onPressed, isNull, reason: label);
      expect(keyOf(tester, label).tooltip, reason);
    }
    await closeShiftsSheet(tester, fixture);
  });

  for (final accepted in ['', 'Earlier reason']) {
    testWidgets('Cancel guards the active reason after "$accepted"', (
      tester,
    ) async {
      final fixture = await pumpShiftsSheet(tester);
      final shift = await finish(tester, fixture);
      await selectShiftsRow(tester, storedRowId(shift));
      await click(tester, toolbarKey('Void…'));
      if (accepted.isNotEmpty) await typeReason(tester, accepted);
      await click(tester, reason);
      await tester.enterText(reason, 'Latest reason still being typed');
      await click(tester, pushKey('Cancel'));
      expect(find.byType(ConfirmWindow<ConfirmAnswer>), findsOneWidget);
      await click(tester, pushKey('Keep editing'));
      expect(panel, findsOneWidget);
      expect(sheetOf(tester).action!.reason, 'Latest reason still being typed');
      expect(sheetOf(tester).selectedId, storedRowId(shift));
      await click(tester, pushKey('Cancel'));
      await click(tester, pushKey('Discard'));
      await settleSheet(tester);
      expect(panel, findsNothing);
      final stored = await tester.runAsync(() => fixture.reads.shift(shift.id));
      expect(stored!.shift.state, ShiftState.finalized);
      await closeShiftsSheet(tester, fixture);
    });
  }

  testWidgets('a Needs review day says why; Remove change opens it for '
      'editing', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(() => fixture.changeThenReshape(5, _nightFirst));
    await settleSheet(tester);
    final day = plannedRowId(_monday);
    expect(
      find.descendant(
        of: await gridCell(tester, day, 'status'),
        matching: find.text('Needs review'),
      ),
      findsOneWidget,
    );
    await selectShiftsRow(tester, day);
    expect(statusNotice(tester), ShiftsNotices.needsReview);
    expect(keyOf(tester, 'Remove change').onPressed, isNotNull);

    await click(tester, toolbarKey('Remove change'));
    await settleSheet(tester);
    expect(statusNotice(tester), ShiftsNotices.restored);
    expect(
      find.descendant(
        of: await gridCell(tester, day, 'start'),
        matching: find.text('19:00'),
      ),
      findsOneWidget,
    );
    await stepGridTime(tester, day, 'end', 'up');
    expect(statusNotice(tester), startsWith('Unsaved plan change:'));
    await closeShiftsSheet(tester, fixture);
  });
}
