import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart' show click, toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

/// The Work shell at 1280 x 800 and 100 % text (spec 10): the empty
/// database's overview, Shifts with a selected record, an open action
/// panel, and the Agreements sheet. Synthetic data and the test font.
void main() {
  testWidgets('the empty database', (tester) async {
    await pumpEmptyShell(tester, store: MemoryLocationStore());
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_empty_1280x800.png'),
    );
  });

  testWidgets('Shifts with a selected record', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    late WorkShift shift;
    await tester.runAsync(() async {
      shift = await fixture.finishShift(20);
    });
    await settleSheet(tester);
    await selectShiftsRow(tester, storedRowId(shift));
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_shifts_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('an open action panel', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    late WorkShift shift;
    await tester.runAsync(() async {
      shift = await fixture.finishShift(20);
    });
    await settleSheet(tester);
    await selectShiftsRow(tester, storedRowId(shift));
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_action_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a day panel: Mark as leave…', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await selectShiftsRow(tester, plannedRowId(const LocalDate(2026, 10, 12)));
    await click(tester, toolbarKey('Mark as leave…'));
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_day_panel_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the Calendar sheet', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.calendar(fixtureEmployment, month: LocalDate(2026, 10, 1), day: LocalDate(2026, 10, 19)).toUri()}',
      ),
    );
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_calendar_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Confirm worked days in pick mode', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile(
        '../../goldens/work_shell_to_confirm_pick_1280x800.png',
      ),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the Agreements sheet', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.agreements(fixtureEmployment, agreement: fixtureAgreement).toUri()}',
      ),
    );
    await tester.runAsync(() => fixture.finishShift(20));
    // The sheet's reads of that change run in the test's time; the next
    // write waits for them.
    await settleSheet(tester);
    await tester.runAsync(() async {
      final v1 = (await fixture.reads.agreement(
        fixtureEmployment,
        fixtureAgreement,
      ))!.value;
      await fixture.work.agreement.changeAgreementTerms(
        ChangeAgreementTermsCommand(
          agreementId: v1.id,
          employmentId: fixtureEmployment,
          expectedRevision: v1.revision,
          from: const LocalDate(2026, 11, 1),
          terms: AgreementTerms.of(v1)
              .change(hourlyRateMicroEur: 19200000, label: () => 'Winter rate'),
        ),
      );
    });
    await settleSheet(tester);
    await tester.runAsync(
      () => shellOf(tester).agreementsSheet!.select(fixtureAgreement),
    );
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_agreements_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the Schedules sheet', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.schedules(fixtureEmployment).toUri()}',
      ),
    );
    final sheet = shellOf(tester).schedulesSheet!;
    await tester.runAsync(() async {
      final depot = sheet.rows.single.schedule;
      final ended = await fixture.work.schedules.update(
        depot.id,
        expected: depot.revision,
        draft: depotDraft(until: const LocalDate(2026, 12, 31)),
      );
      await fixture.work.schedules.create(
        depotDraft(name: 'Winter rotation', from: const LocalDate(2027, 1, 1)),
      );
      await fixture.schedule.markUsed((ended as Committed<WorkSchedule>).value);
    });
    await settleSheet(tester);
    await tester.runAsync(() async {
      final depot = sheet.rows.first.schedule;
      await sheet.show(depot.id, version: depot.version);
    });
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_schedules_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });
}
