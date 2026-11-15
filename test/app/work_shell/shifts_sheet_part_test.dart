import 'dart:async';

import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/day_action.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart'
    show EmploymentsWords;
import 'package:lifeos/app/work_shell/shifts_edit.dart' show ShiftsField;
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_part.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart'
    show CloseAgreementCommand;
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/work_formats.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async => fixture = await ShiftsSheetFixture.create());
  tearDown(() => fixture.dispose());

  Future<ShiftsSheetController> open() async {
    final sheet = ShiftsSheetController(
      work: fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: ShiftsSheetFixture.month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: ScriptedConfirm().call,
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    return sheet;
  }

  PropertyItem link(ShiftsSheetPart part, String key) =>
      (part.properties(part.lines) as PropertyGrid).items.singleWhere(
        (item) => item.key == key,
      );

  ShiftsSheetPart partOf(
    ShiftsSheetController sheet, {
    void Function(ShiftId id)? followShift,
  }) {
    final editors = EditorSessionController();
    final part = ShiftsSheetPart(
      sheet: sheet,
      editors: editors,
      work: fixture.work,
      today: ShiftsSheetFixture.today,
      followShift:
          followShift ?? (id) => unawaited(sheet.select(shiftRowId(id))),
    );
    addTearDown(() {
      part.dispose();
      editors.dispose();
    });
    return part;
  }

  test("the sheet's lines are worked out once per change", () async {
    final sheet = await open();
    final part = partOf(sheet);
    final lines = part.allLines;
    expect(part.allLines, same(lines));
    await sheet.addShift();
    expect(part.allLines, isNot(same(lines)));
    expect(part.allLines.any((line) => line.id == newRowId), isTrue);
  });

  test('under another sort the new row stays where it was put', () async {
    final sheet = await open();
    final part = partOf(sheet)..sortBy('paid');
    await sheet.addShift();
    int at() => part.lines.indexWhere((line) => line.id == newRowId);
    final first = at();
    expect(first, part.lines.length - 1);
    sheet.editField(newRowId, ShiftsField.end, const LocalTime(9, 0));
    expect(at(), first);
    sheet.editField(newRowId, ShiftsField.end, const LocalTime(23, 0));
    expect(at(), first);
  });

  test('in the shell, a link to another month follows it', () async {
    final (original, replacement) = await fixture.correctIntoNovember(20);
    final sheet = await open();
    await sheet.show(storedRowId(original));
    final followed = <ShiftId>[];
    final replacedBy = link(
      partOf(sheet, followShift: followed.add),
      'replacedBy',
    );
    expect(replacedBy.value, 'Another month');
    expect(replacedBy.readOnlyReason, isNull);
    expect(replacedBy.description, ShiftsPropertyWords.otherMonthLink);
    replacedBy.onFollow!();
    expect(followed, [replacement.id]);
  });

  test(
    'a rejected open editor prevents following a replacement link',
    () async {
      final (original, _) = await fixture.correctIntoNovember(20);
      final sheet = await open();
      await sheet.show(storedRowId(original));
      final followed = <ShiftId>[];
      final part = partOf(sheet, followShift: followed.add);
      part.editors.begin(
        EditField(
          id: const EditIdentity(record: 'synthetic', field: 'blocked'),
          kind: ValueKind.text,
          value: 'before',
          commit: (_, _) => const EditResult.rejected('Keep editing'),
        ),
      );
      part.editors.update(
        const EditIdentity(record: 'synthetic', field: 'blocked'),
        'after',
      );
      link(part, 'replacedBy').onFollow!();
      await Future<void>.delayed(Duration.zero);
      expect(followed, isEmpty);
      expect(part.editors.session?.draft, 'after');
    },
  );

  test("the Record menu's greyed actions say why", () async {
    final sheet = await open();
    await sheet.select(plannedRowId(const LocalDate(2026, 10, 5)));
    final menu = partOf(sheet).recordMenu();
    String? reason(String label) =>
        menu.singleWhere((item) => item.label == label).disabledReason;
    expect(reason('Correct…'), sheet.correctBlocked);
    expect(reason('Correct…'), ShiftsCommandWords.correctOnlyFinalized);
    expect(reason('Void…'), sheet.voidBlocked);
    expect(reason('Remove change'), sheet.removeChangeBlocked);
    expect(reason('Void…'), isNotNull);
  });

  DataGrid<ShiftsLine> gridOf(ShiftsSheetPart part) =>
      part.grid(part.lines) as DataGrid<ShiftsLine>;

  test('the note names the filters set', () async {
    final part = partOf(await open());
    expect(gridOf(part).note, isNull);
    part.filter = const ShiftsFilter(status: ShiftsStatusFilter.finalized);
    part.find = 'night';
    expect(gridOf(part).note, 'Filtered: Status, Find');
    part.filter = const ShiftsFilter(type: 'Day', offDays: true);
    part.find = '';
    expect(gridOf(part).note, 'Filtered: Type, Off days');
  });

  test('totals follow the shown lines', () async {
    await fixture.finishShift(20);
    await fixture.finishShift(21);
    final sheet = await open();
    final part = partOf(sheet);
    final both = gridOf(part).footer!['paid'];
    part.find = '2026-10-20';
    final one = gridOf(part).footer!['paid'];
    expect(one, isNot(both));
    expect(gridOf(part).footerLabel, 'Total (1 shift)');
  });
  group('the property column of a day that is not work', () {
    Map<String, Object?> values(ShiftsSheetPart part) => {
      for (final item in (part.properties(part.lines) as PropertyGrid).items)
        item.key: item.display ?? item.value,
    };

    test('a leave day shows its leave and the shift it replaces', () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        leaveType: LeaveType.sick,
        illnessStartedOn: null,
      );
      final sheet = await open();
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 12)));
      final shown = values(partOf(sheet));
      expect(shown['leaveType'], LeaveType.sick);
      expect(shown['illnessStartedOn'], 'Worked out on confirm');
      expect(shown['insteadOf'], 'Night 19:00–07:00');
      expect(shown['hours'], '11:30');
      expect(shown['status'], 'Sick, to confirm');
      expect(shown.containsKey('start'), isFalse);
      // Change leave: the leave and its illness start are edited here.
      final items = {
        for (final item in (partOf(
          sheet,
        ).properties(partOf(sheet).lines) as PropertyGrid).items)
          item.key: item,
      };
      expect(items['leaveType']!.kind, ValueKind.choice);
      expect(items['leaveType']!.readOnlyReason, isNull);
      expect(items['illnessStartedOn']!.readOnlyReason, isNull);
    });

    test("a leave day's other cells and an archived one's fields say why "
        'in its own words', () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      final sheet = await open();
      final id = plannedRowId(const LocalDate(2026, 10, 12));
      await sheet.select(id);
      final line = partOf(sheet).lines.singleWhere((line) => line.id == id);
      for (final field in ['start', 'end', 'type', 'note']) {
        expect(
          shiftsReadOnlyReason(sheet, line, field),
          ShiftsReadOnly.leaveField,
          reason: field,
        );
      }
      sheet.archived = true;
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 13)));
      await sheet.select(id);
      final items = {
        for (final item in (partOf(
          sheet,
        ).properties(partOf(sheet).lines) as PropertyGrid).items)
          item.key: item,
      };
      expect(
        items['leaveType']!.readOnlyReason,
        EmploymentsWords.archivedReadOnly,
      );
      expect(
        items['illnessStartedOn']!.readOnlyReason,
        EmploymentsWords.archivedReadOnly,
      );
    });

    test('a cancelled day shows the shift, its reason and note', () async {
      await fixture.work.plans.cancelDay(
        fixtureEmployment,
        const LocalDate(2026, 10, 13),
        reason: CancelReason.dayOff,
        note: 'Asked for it',
      );
      final sheet = await open();
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 13)));
      final shown = values(partOf(sheet));
      expect(shown['shift'], 'Night 19:00–07:00');
      expect(shown['reason'], 'Day off');
      expect(shown['cancelNote'], 'Asked for it');
      expect(shown['status'], 'Cancelled · Day off');
    });

    test('confirmed leave is read-only with its hours', () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      await fixture.work.plans.confirm(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
      );
      final sheet = await open();
      final taken = sheet.rows.whereType<LeaveTakenRow>().single;
      await sheet.select(taken.id);
      final shown = values(partOf(sheet));
      expect(shown['leaveType'], 'Vacation');
      expect(shown['hours'], '11:30');
      expect(shown['status'], 'Vacation, confirmed');
      expect(sheet.readOnlyReason, ShiftsNotices.leaveTaken);
    });
  });
  test("the Type cell of the selected planned day is a combo of the schedule's "
      'types, and the status line names the change', () async {
    final sheet = await open();
    final id = plannedRowId(const LocalDate(2026, 10, 6));
    await sheet.select(id);
    final part = partOf(sheet);
    final type = gridOf(part).columns
        .singleWhere((column) => column.key == 'type');
    expect(type.kind, ValueKind.choice);
    expect(type.choices.map((item) => item.label), ['Day', 'Night']);
    final line = part.lines.singleWhere((value) => value.id == id);
    expect(shiftsReadOnlyReason(sheet, line, 'type'), isNull);
    sheet.editField(id, 'type', 'Night');
    expect(
      part.notice(part.lines),
      startsWith(
        'Unsaved plan change: Tue 2026-10-06, Type Day → Night, '
        'Start 07:00 → 19:00, End 19:00 → 07:00.',
      ),
    );
    final shown = (part.properties(part.lines) as PropertyGrid).items
        .singleWhere((item) => item.key == 'type');
    expect(shown.label, 'Shift type');
    expect(shown.was, 'Day');
  });
  group('the day panels', () {
    const night = LocalDate(2026, 10, 11);

    List<ActionField> fieldsOf(ActionPanel panel) => [
      for (final group in panel.groups()) ...group.fields,
    ];

    test('Cancel shift… shows the reason choices and the note', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(night));
      final part = partOf(sheet);
      final key = part
          .bands()
          .expand((band) => band.items)
          .singleWhere((item) => item.label == 'Cancel shift…');
      expect(key.onPressed, isNotNull);
      expect(
        part
            .recordMenu()
            .singleWhere((item) => item.label == 'Cancel shift…')
            .onSelected,
        isNotNull,
      );
      await sheet.openDayAction(DayActionKind.cancel);
      final panel = part.propertyColumn(part.lines) as ActionPanel;
      expect(panel.title, 'Cancel shift');
      expect(panel.primaryLabel, 'Cancel shift');
      // The day, what plans it and what it would have paid (mockup).
      final day = sheet.dayAction!.day;
      final schedule = (await fixture.work.plans.repository.planInputs(
        fixtureEmployment,
      )).schedules.singleWhere((value) => value.id == day.scheduleId);
      final pay = sheet.rows
          .whereType<PlannedRow>()
          .singleWhere((row) => row.date == night)
          .planned
          .pay!
          .amount;
      final said = [
        for (final group in panel.groups())
          for (final child in group.children)
            if (child is Text) child.data,
      ];
      expect(
        said,
        containsAll([
          predicate<String?>(
            (text) => text!.endsWith(
              ', planned by ${schedule.name} v${day.scheduleVersion}.',
            ),
          ),
          'Planned pay: ${formatMoney(pay)} → none',
        ]),
      );
      final fields = fieldsOf(panel);
      final reason = fields.singleWhere(
        (field) => field.id == DayActionField.reason,
      );
      expect(reason.kind, ValueKind.choice);
      expect(reason.choices.map((item) => item.label), [
        'Swapped',
        'Day off',
        'Other',
      ]);
      expect(
        fields.singleWhere((field) => field.id == DayActionField.note).optional,
        isTrue,
      );
      panel.onChanged(DayActionField.reason, CancelReason.dayOff);
      panel.onChanged(DayActionField.note, 'Asked for it');
      expect(sheet.dayAction!.reason, CancelReason.dayOff);
      expect(sheet.dayAction!.note, 'Asked for it');
      expect(part.notice(part.lines), DayActionWords.cancelHint);
    });

    test(
      'Mark as leave… enables Illness started on only for sick leave',
      () async {
        final sheet = await open();
        await sheet.select(plannedRowId(night));
        final part = partOf(sheet);
        await sheet.openDayAction(DayActionKind.leave);
        ActionField illness() =>
            fieldsOf(part.propertyColumn(part.lines) as ActionPanel)
                .singleWhere((field) => field.id == DayActionField.illness);
        expect(illness().enabled, isFalse);
        (part.propertyColumn(part.lines) as ActionPanel).onChanged(
          DayActionField.leaveType,
          LeaveType.sick,
        );
        expect(illness().enabled, isTrue);
      },
    );
  });
  test('a new shift opens its properties on Date', () async {
    final sheet = await open();
    await sheet.addShift();
    final part = partOf(sheet);
    expect((part.properties(part.lines) as PropertyGrid).openOn, 'date');
  });
  group('the status line of a pending change', () {
    test('a leave change says it is a leave change, not a finalize', () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      final sheet = await open();
      final id = plannedRowId(const LocalDate(2026, 10, 12));
      await sheet.select(id);
      sheet.editField(id, 'leaveType', LeaveType.sick);
      final part = partOf(sheet);
      expect(
        part.notice(part.lines),
        'Unsaved leave change: Mon 2026-10-12, Leave Vacation → Sick. Save, '
        'or leave the day, to keep it. Confirmation is separate.',
      );
    });

    test('a Counts as overtime change is named', () async {
      await fixture.work.plans.addExtra(
        fixtureEmployment,
        const LocalDate(2026, 10, 9),
        start: const LocalTime(8, 0),
        end: const LocalTime(14, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
        countsAsOvertime: false,
      );
      final sheet = await open();
      final id = plannedRowId(const LocalDate(2026, 10, 9));
      await sheet.select(id);
      sheet.editField(id, 'countsAsOvertime', true);
      final part = partOf(sheet);
      expect(
        part.notice(part.lines),
        'Unsaved plan change: Fri 2026-10-09, Counts as overtime No → Yes. '
        'Save, or leave the day, to keep it. Confirmation is separate.',
      );
    });

    test('a new extra shift says Save adds it', () async {
      final sheet = await open();
      await sheet.select('off:2026-10-09');
      await sheet.addExtra();
      final part = partOf(sheet);
      expect(
        part.notice(part.lines),
        'New extra shift on Fri 2026-10-09: Day 07:00–19:00. Save adds it.',
      );
    });
  });
  test(
    'a day no agreement covers links its pay to Extend pay agreement…',
    () async {
      final current = (await fixture.reads.agreementsOf(fixtureEmployment))
          .single;
      await fixture.work.agreement.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: fixtureEmployment,
          end: const LocalDate(2026, 10, 15),
          expectedRevision: current.revision,
        ),
      );
      final sheet = await open();
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 17)));
      final extended = <LocalDate>[];
      final editors = EditorSessionController();
      final part = ShiftsSheetPart(
        sheet: sheet,
        editors: editors,
        work: fixture.work,
        today: ShiftsSheetFixture.today,
        extendAgreement: extended.add,
        followShift: (id) => unawaited(sheet.select(shiftRowId(id))),
      );
      addTearDown(() {
        part.dispose();
        editors.dispose();
      });
      final pay = (part.properties(part.lines) as PropertyGrid).items
          .singleWhere((item) => item.key == 'pay');
      expect(pay.value, 'Extend pay agreement…');
      pay.onFollow!();
      await sheet.settled();
      await Future<void>.delayed(Duration.zero);
      expect(extended, [const LocalDate(2026, 10, 17)]);
    },
  );
}
