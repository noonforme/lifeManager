import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_shell/correct_leave_action.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/leave_sheet_controller.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart'
    show LeaveSheetRow;
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/leave_sheet_driver.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';

/// Picks [choice] from the filter strip's combo [label] by mouse.
Future<void> pick(WidgetTester tester, String label, String choice) async {
  await click(
    tester,
    find.descendant(
      of: find.byType(FilterStrip),
      matching: find.byWidgetPredicate(
        (widget) => widget is EraCombo && widget.semanticLabel == label,
      ),
    ),
  );
  await settleSheet(tester);
  await click(tester, comboChoice(choice));
  await settleSheet(tester);
}

void main() {
  testWidgets(
    'priced facts, Working, inline correction, validation and record links',
    (tester) async {
      final fixture = await pumpShiftsSheet(tester);
      final original = await openLeave(tester, fixture);
      final shell = shellOf(tester);
      final sheet = shell.leaveSheet!;
      expect(sheet.selectedId, original.id);
      expect(sheet.rows.single.pay!.usedFallback, isTrue);
      expect(
        tester
            .widget<PropertyGrid>(find.byType(PropertyGrid))
            .items
            .where((item) => item.editable),
        isEmpty,
        reason: 'confirmed facts never open an editor',
      );
      await click(tester, dockTab('Working'));
      expect(find.text('Why agreement rate'), findsOneWidget);
      expect(find.text('EUR 211.60'), findsWidgets);
      await click(tester, toolbarKey('Correct…'));
      await settleSheet(tester);
      final action = sheet.action!;
      // Choose Sick in the action's cell, using the mouse.
      final choice = find.descendant(
        of: find.byType(ActionPanel),
        matching: find.byType(EraCombo<Object?>),
      );
      await click(tester, choice);
      await click(tester, comboChoice('Sick'));
      await press(tester, LogicalKeyboardKey.enter);
      await settleSheet(tester);
      expect(action.type, LeaveType.sick);
      // An empty illness start ticks on the leave day, never after it.
      final check = find.descendant(
        of: find.byType(ActionPanel),
        matching: find.byKey(const ValueKey('era-date-check')),
      );
      await click(tester, check);
      await press(tester, LogicalKeyboardKey.enter);
      await settleSheet(tester);
      expect(action.illness, original.date);
      action.set('illness', const LocalDate(2026, 10, 5));
      await tester.pump();
      await click(tester, panelKey(CorrectLeaveWords.primary));
      await settleSheet(tester);
      expect(sheet.action, same(action));
      expect(action.errors['reason'], CorrectLeaveWords.reason);
      expect(action.illness, const LocalDate(2026, 10, 5));
      expect(sheet.rows, hasLength(1));
      await reasonText(tester, 'Was ill');
      // Primary flushes the currently typed value before sending it.
      await click(tester, panelKey(CorrectLeaveWords.primary));
      await settleSheet(tester);
      expect(sheet.action, isNull);
      final replacement = sheet.selectedRow!.record;
      expect(replacement.id, isNot(original.id));
      expect(replacement.leaveType, LeaveType.sick);
      expect(replacement.replacedId, original.id);
      expect(sheet.rows, hasLength(2));
      expect(shell.location.leave, replacement.id);
      expect(shell.location.filter.status, ShiftsStatusFilter.effective);
      await click(tester, propertyValue('original'));
      await settleSheet(tester);
      expect(sheet.selectedRow!.record.isEffective, isFalse);
      expect(shell.location.filter.status, ShiftsStatusFilter.all);
      expect(statusNotice(tester), LeaveSheetWords.voidedStatus);
      expect(
        tester.widget<KeyButton>(toolbarKey('Correct…')).onPressed,
        isNull,
      );
      await click(tester, dockTab('History'));
      await settleSheet(tester);
      expect(find.text('Was ill'), findsWidgets);
      await click(tester, propertyValue('replacement'));
      await settleSheet(tester);
      expect(sheet.selectedId, replacement.id);
      expect(tester.takeException(), isNull);
      await closeShiftsSheet(tester, fixture);
    },
  );

  testWidgets(
    'Cancel and navigation take typed input through the discard guard',
    (tester) async {
      final fixture = await pumpShiftsSheet(tester);
      final original = await openLeave(tester, fixture);
      await tester.runAsync(() => confirmLeave(fixture, 7));
      await settleSheet(tester);
      final shell = shellOf(tester);
      final sheet = shell.leaveSheet!;
      await click(tester, toolbarKey('Correct…'));
      await settleSheet(tester);
      await reasonText(tester, 'Still typing');
      await click(tester, panelKey('Cancel'));
      expect(find.byWidgetPredicate((w) => w is ConfirmWindow), findsOneWidget);
      await click(tester, windowKey('Keep editing'));
      expect(sheet.action!.reason, 'Still typing');
      await click(tester, toolbarKey('Back'));
      expect(find.byWidgetPredicate((w) => w is ConfirmWindow), findsOneWidget);
      await click(tester, windowKey('Keep editing'));
      expect(sheet.selectedId, original.id);
      await click(tester, panelKey('Cancel'));
      await click(tester, windowKey('Discard'));
      await settleSheet(tester);
      expect(sheet.action, isNull);
      expect(sheet.rows, hasLength(2));
      await closeShiftsSheet(tester, fixture);
    },
  );

  testWidgets(
    'routes restore Leave, normalize the scope and fall back for missing/foreign records',
    (tester) async {
      final fixture = await pumpShiftsSheet(tester);
      final original = await openLeave(tester, fixture);
      final shell = shellOf(tester);
      // A persisted record outside the requested scope moves to its month.
      await tester.runAsync(
        () => shell.go(
          WorkLocation.leave(
            fixtureEmployment,
            month: const LocalDate(2026, 11, 1),
            leave: original.id,
            sub: 'working',
          ),
        ),
      );
      await settleSheet(tester);
      expect(shell.location.month, const LocalDate(2026, 10, 1));
      expect(shell.location.sub, 'working');
      await tester.runAsync(
        () => shell.go(
          WorkLocation.leave(
            fixtureEmployment,
            month: const LocalDate(2026, 10, 1),
            leave: const LeaveRecordId('0190f5d2-6a00-7000-8000-000000000999'),
          ),
        ),
      );
      await settleSheet(tester);
      expect(shell.location.leave, isNull);
      expect(shell.location.sheet, WorkSheetKind.leave);
      expect(statusNotice(tester), contains('no longer exists'));
      await closeShiftsSheet(tester, fixture);
    },
  );

  testWidgets('archiving locks a correction that is already open', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await openLeave(tester, fixture);
    final sheet = shellOf(tester).leaveSheet!;
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    sheet.action!.set('reason', 'Fix');
    final employment = shellOf(tester).employments.single.employment;
    final archiving = fixture.work.employment.archiveEmployment(
      ArchiveEmploymentCommand(
        employmentId: fixtureEmployment,
        expectedRevision: employment.revision,
      ),
    );
    await settleSheet(tester);
    await archiving;
    expect(sheet.archived, isTrue);
    expect(
      tester.widget<KeyButton>(panelKey(CorrectLeaveWords.primary)).onPressed,
      isNull,
    );
    await tester.runAsync(sheet.submitAction);
    expect(sheet.rows, hasLength(1));
    expect(sheet.correctBlocked, EmploymentsWords.archivedReadOnly);
    await closeShiftsSheet(tester, fixture);
  });

  for (final size in [
    const Size(1280, 800),
    const Size(1024, 768),
    const Size(900, 600),
    const Size(800, 600),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Leave ${size.width}x${size.height} at $scale: properties, Working and correction remain reachable',
        (tester) async {
          final fixture = await pumpShiftsSheet(
            tester,
            size: size,
            scale: scale,
          );
          expect(tester.takeException(), isNull, reason: 'before Leave');
          await openLeave(tester, fixture);
          expect(tester.takeException(), isNull, reason: 'opening Leave');
          await showProperties(tester);
          await click(tester, propertyValue('date'));
          await click(tester, dockTab('Working'));
          expect(tester.takeException(), isNull, reason: 'Working');
          await click(tester, toolbarKey('Correct…'));
          await settleSheet(tester);
          await showProperties(tester);
          expect(tester.takeException(), isNull, reason: 'open correction');
          await reasonText(tester, 'Retain this typed value');
          await press(tester, LogicalKeyboardKey.enter);
          await click(tester, panelKey(CorrectLeaveWords.primary));
          await settleSheet(tester);
          expect(shellOf(tester).leaveSheet!.action, isNull);
          expect(tester.takeException(), isNull);
          await closeShiftsSheet(tester, fixture);
        },
      );
    }
  }

  testWidgets('gross September work never prices net October leave', (
    tester,
  ) async {
    // Audit 9pk.4.34: 8 h gross at EUR 18.40 in September, net EUR 10.00
    // from October 1, then vacation on October 6.
    final fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(() async {
      final first = await fixture.work.manualShifts.createAndFinalize(
        CreateManualShiftCommand(
          employmentId: fixtureEmployment,
          localStartDate: const LocalDate(2026, 9, 15),
          localStartTime: const LocalTime(8, 0),
          localEndDate: const LocalDate(2026, 9, 15),
          localEndTime: const LocalTime(16, 0),
          timezoneId: 'Europe/Vilnius',
          startFold: null,
          endFold: null,
          note: null,
        ),
      );
      expect(first, isA<Committed<WorkShift>>());
      final v1 = (await fixture.reads.agreement(
        fixtureEmployment,
        fixtureAgreement,
      ))!.value;
      final changed = await fixture.work.agreement.changeAgreementTerms(
        ChangeAgreementTermsCommand(
          agreementId: v1.id,
          employmentId: fixtureEmployment,
          expectedRevision: v1.revision,
          from: const LocalDate(2026, 10, 1),
          terms: AgreementTerms.of(v1)
              .change(basis: const NetBasis(), hourlyRateMicroEur: 10000000),
        ),
      );
      expect(changed, isA<Committed<PayAgreement>>());
    });
    await settleSheet(tester);
    await openLeave(tester, fixture);
    final pay = shellOf(tester).leaveSheet!.selectedRow!.pay!;
    // 11:30 × the net agreement rate, never × the gross EUR 18.40 average.
    expect(pay.amount.minorUnits, 11500);
    expect(pay.basis, const NetBasis());
    expect(pay.usedFallback, isTrue);
    expect(pay.otherBasisLeftOut, isTrue);
    await click(tester, dockTab('Working'));
    expect(find.text('Left out'), findsOneWidget);
    expect(
      find.text(
        'No confirmed net paid time in the three months before this day.',
      ),
      findsOneWidget,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('empty Leave is an empty grid at 200% text in a short window', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(
      tester,
      size: const Size(800, 600),
      scale: 2,
      store: MemoryLocationStore(
        '${const WorkLocation.leave(fixtureEmployment, month: LocalDate(2026, 10, 1)).toUri()}',
      ),
    );
    final grid = tester.widget<DataGrid<LeaveSheetRow>>(subformGrid('Leave'));
    expect(grid.lines, isEmpty);
    expect(tester.takeException(), isNull);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('docking preserves the correction draft and its focus', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await openLeave(tester, fixture);
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    await reasonText(tester, 'Unsaved draft');
    await resizeTo(tester, const Size(800, 600));
    final editors = tester
        .widget<ActionPanel>(find.byType(ActionPanel))
        .controller;
    expect(editors.session?.draft, 'Unsaved draft');
    await resizeTo(tester, const Size(1280, 800));
    expect(editors.session?.draft, 'Unsaved draft');
    await click(tester, panelKey(CorrectLeaveWords.primary));
    await settleSheet(tester);
    expect(shellOf(tester).leaveSheet!.action, isNull);
    await closeShiftsSheet(tester, fixture);
  });

  for (final (label, choice) in [('Type', 'Sick'), ('Status', 'Void')]) {
    testWidgets('$label: $choice hiding the selected leave selects the sheet', (
      tester,
    ) async {
      final fixture = await pumpShiftsSheet(tester);
      await openLeave(tester, fixture);
      final shell = shellOf(tester);
      final sheet = shell.leaveSheet!;
      await pick(tester, label, choice);
      final grid = tester.widget<DataGrid<LeaveSheetRow>>(subformGrid('Leave'));
      expect(grid.lines, isEmpty);
      expect(grid.selectedId, isNull);
      expect(sheet.selectedId, isNull);
      expect(shell.location.leave, isNull);
      expect(
        tester.widget<KeyButton>(toolbarKey('Correct…')).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await closeShiftsSheet(tester, fixture);
    });
  }

  testWidgets('a filter keeps a selected leave it still admits', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    final original = await openLeave(tester, fixture);
    final shell = shellOf(tester);
    await pick(tester, 'Type', 'Vacation');
    expect(shell.leaveSheet!.selectedId, original.id);
    expect(shell.location.leave, original.id);
    expect(
      tester.widget<KeyButton>(toolbarKey('Correct…')).onPressed,
      isNotNull,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('an open correction keeps its leave shown through a filter', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    final original = await openLeave(tester, fixture);
    final shell = shellOf(tester);
    final sheet = shell.leaveSheet!;
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    final action = sheet.action!;
    await pick(tester, 'Type', 'Sick');
    final grid = tester.widget<DataGrid<LeaveSheetRow>>(subformGrid('Leave'));
    expect(grid.lines, hasLength(1));
    expect(grid.selectedId, original.id.value);
    expect(sheet.selectedId, original.id);
    expect(sheet.action, same(action));
    expect(find.byType(ActionPanel), findsOneWidget);
    await click(tester, panelKey('Cancel'));
    await settleSheet(tester);
    expect(sheet.action, isNull);
    await closeShiftsSheet(tester, fixture);
  });
}
