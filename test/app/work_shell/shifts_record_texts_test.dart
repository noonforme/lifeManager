import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart' show click, propertyValue;
import '../../support/shifts_sheet_driver.dart';

const _twentieth = LocalDate(2026, 10, 20);

/// The rotation starting with Night: the 5th, changed as a Day shift, is a
/// Night now.
const _nightFirst = [
  CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
  CycleBlock(count: 3, shiftTypeId: null),
  CycleBlock(count: 3, shiftTypeId: ShiftTypeId('day')),
  CycleBlock(count: 3, shiftTypeId: null),
];

void main() {
  /// The property [key]'s value showing [text]; values are rich text.
  Finder shows(String key, String text) => find.descendant(
    of: propertyValue(key),
    matching: find.text(text, findRichText: true),
  );

  testWidgets('a corrected shift shows its void reason; it and its '
      'replacement link to each other', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    late WorkShift original;
    late WorkShift draft;
    await tester.runAsync(() async {
      original = await fixture.finishShift(20);
      final outcome = await fixture.work.shifts.correctShift(
        CorrectShiftCommand(
          originalId: original.id,
          replacementId: fixture.schedule.ids.shiftId(),
          expectedRevision: original.revision,
          voidReason: 'Wrong end',
        ),
      );
      draft = (outcome as Committed<WorkShift>).value;
    });
    await settleSheet(tester);

    await selectShiftsRow(tester, storedRowId(original));
    expect(shows('voidReason', 'Wrong end'), findsOneWidget);
    expect(
      shows('replacedBy', 'Draft ${eraBoxDate(_twentieth)}'),
      findsOneWidget,
    );
    await click(tester, propertyValue('replacedBy'));
    await settleSheet(tester);
    expect(sheetOf(tester).selectedId, storedRowId(draft));
    expect(shows('replaces', 'Void ${eraBoxDate(_twentieth)}'), findsOneWidget);
    expect(propertyValue('voidReason'), findsNothing);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a Needs review day says what its change was and has no Note', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(() => fixture.changeThenReshape(5, _nightFirst));
    await settleSheet(tester);
    await selectShiftsRow(tester, plannedRowId(const LocalDate(2026, 10, 5)));
    expect(shows('change', 'Changed times'), findsOneWidget);
    expect(shows('status', 'Needs review'), findsOneWidget);
    expect(propertyValue('note'), findsNothing);
    expect(statusNotice(tester), ShiftsNotices.needsReview);
    await closeShiftsSheet(tester, fixture);
  });
}
