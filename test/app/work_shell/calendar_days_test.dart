import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/work_shell/calendar_days.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/schedule.dart' show ShiftTypeId;
import 'package:lifeos/ui/ui.dart';

import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

LocalDate _oct(int day) => LocalDate(2026, 10, day);

/// The Calendar's words for each day (plan 4d-2, Task 4).
void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
  });

  tearDown(() => fixture.dispose());

  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  Future<ShiftsSheetController> open({
    LocalDate month = ShiftsSheetFixture.month,
  }) async {
    final sheet = ShiftsSheetController(
      work: fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      kind: WorkSheetKind.calendar,
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  Map<LocalDate, DayCalendarDay> days(
    ShiftsSheetController sheet, {
    String? type,
    String find = '',
  }) => calendarDays(
    sheet: sheet,
    lines: shiftsLines(sheet, fixture.work.timezones),
    timezones: fixture.work.timezones,
    type: type,
    find: find,
  );

  List<String> words(Map<LocalDate, DayCalendarDay> days, int date) => [
    for (final line in days[_oct(date)]?.lines ?? const <DayCalendarLine>[])
      line.spoken,
  ];

  test('a past planned day waits to be confirmed', () async {
    final shown = days(await open());
    expect(words(shown, 6), ['Day 07:00–19:00', 'To confirm']);
    final status = shown[_oct(6)]!.lines.last;
    expect(status.mark, DayCalendarMark.warning);
    expect(status.ink, DayCalendarInk.run);
    expect(shown[_oct(6)]!.lines.first.tone, DayTone.first);
  });

  test("a night's morning shows on the next day, muted", () async {
    final shown = days(await open());
    expect(words(shown, 12), [
      'Night until 07:00',
      'Night 19:00–07:00',
      'To confirm',
    ]);
    expect(shown[_oct(12)]!.lines.first.ink, DayCalendarInk.muted);
    expect(shown[_oct(12)]!.lines.first.tone, DayTone.second);
  });

  test('a night on the last day of the month before shows its morning on '
      'the 1st, and is not one of the rows', () async {
    // The depot's rotation works a night on Monday 30 November.
    const december = LocalDate(2026, 12, 1);
    final sheet = await open(month: december);
    final shown = days(sheet);
    expect(
      [for (final line in shown[december]!.lines) line.spoken],
      ['Night until 07:00'],
    );
    expect(shown[december]!.lines.single.ink, DayCalendarInk.muted);
    expect(
      sheet.rows.every((row) => row.date.compareTo(december) >= 0),
      isTrue,
    );
    expect(shown.keys.first, december);
  });

  test('leave, a cancelled day and a confirmed day', () async {
    await fixture.work.plans.markLeave(
      fixtureEmployment,
      _oct(12),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await fixture.work.plans.cancelDay(
      fixtureEmployment,
      _oct(17),
      reason: CancelReason.swapped,
      note: null,
    );
    await fixture.work.plans.confirm(fixtureEmployment, _oct(5));
    final sheet = await open();
    await until(() => words(days(sheet), 5).contains('Confirmed'));
    final shown = days(sheet);
    expect(words(shown, 12), [
      'Night until 07:00',
      'Vacation (Night)',
      'To confirm',
    ]);
    expect(
      words(shown, 13).first,
      'Night 19:00–07:00',
      reason: 'a leave day continues on no morning',
    );
    expect(shown[_oct(12)]!.lines[1].tone, DayTone.fourth);
    expect(words(shown, 17), ['Day 07:00–19:00', 'Cancelled · Swapped']);
    expect(shown[_oct(17)]!.lines.first.struck, 'Day 07:00–19:00');
    expect(words(shown, 5), ['Day 07:00–19:00', 'Confirmed']);
    expect(shown[_oct(5)]!.lines.last.mark, DayCalendarMark.confirmed);
    expect(words(shown, 23), ['Night 19:00–07:00']);
    expect(words(shown, 8), isEmpty);
  });

  test('Type and Find dim the other days', () async {
    final sheet = await open();
    final night = days(sheet, type: 'Night');
    expect(night[_oct(6)]!.dimmed, isTrue);
    expect(night[_oct(12)]!.dimmed, isFalse);
    await fixture.work.plans.cancelDay(
      fixtureEmployment,
      _oct(17),
      reason: CancelReason.swapped,
      note: null,
    );
    await until(() => words(days(sheet), 17).last.startsWith('Cancelled'));
    final found = days(sheet, find: 'cancel');
    expect(found[_oct(17)]!.dimmed, isFalse);
    expect(found[_oct(6)]!.dimmed, isTrue);
    expect(found[_oct(8)]!.dimmed, isTrue);
  });

  test(
    "Type keeps a night's morning lit, in the month and on the 1st",
    () async {
      // Audit 9pk.4.36: the morning was dimmed as a non-match.
      final sheet = await open();
      final night = days(sheet, type: 'Night');
      expect(words(night, 14), ['Night until 07:00']);
      expect(night[_oct(14)]!.dimmed, isFalse);
      expect(days(sheet, type: 'Day')[_oct(14)]!.dimmed, isTrue);
      // A cancelled night has no morning to light.
      await fixture.work.plans.cancelDay(
        fixtureEmployment,
        _oct(13),
        reason: CancelReason.swapped,
        note: null,
      );
      await until(() => words(days(sheet), 14).isEmpty);
      expect(days(sheet, type: 'Night')[_oct(14)]!.dimmed, isTrue);

      const december = LocalDate(2026, 12, 1);
      final shown = days(await open(month: december), type: 'Night');
      expect(shown[december]!.lines.single.spoken, 'Night until 07:00');
      expect(shown[december]!.dimmed, isFalse);
    },
  );

  test(
    'an extra shift says Extra on its tone, even with a shift type',
    () async {
      await fixture.work.plans.addExtra(
        fixtureEmployment,
        _oct(9),
        start: const LocalTime(7, 0),
        end: const LocalTime(19, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: const ShiftTypeId('day'),
        countsAsOvertime: false,
      );
      await fixture.work.plans.addExtra(
        fixtureEmployment,
        _oct(21),
        start: const LocalTime(7, 0),
        end: const LocalTime(19, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: const ShiftTypeId('day'),
        countsAsOvertime: false,
      );
      final sheet = await open();
      await until(() => words(days(sheet), 21).isNotEmpty);
      final shown = days(sheet);
      expect(words(shown, 9), ['Extra 07:00–19:00', 'To confirm']);
      expect(words(shown, 21), ['Extra 07:00–19:00']);
      expect(shown[_oct(21)]!.lines.first.tone, DayTone.third);
    },
  );

  test(
    'Type: Extra keeps every extra lit, typed or not, planned or confirmed',
    () async {
      // Audit 9pk.4.43: an extra from a shift type was dimmed under Extra.
      Future<void> extra(
        int day, {
        ShiftTypeId? type,
        LocalTime start = const LocalTime(7, 0),
        LocalTime end = const LocalTime(19, 0),
        int endDayOffset = 0,
      }) => fixture.work.plans.addExtra(
        fixtureEmployment,
        _oct(day),
        start: start,
        end: end,
        endDayOffset: endDayOffset,
        breaks: const [],
        shiftTypeId: type,
        countsAsOvertime: false,
      );
      await extra(9, type: const ShiftTypeId('day'));
      await fixture.work.plans.confirm(fixtureEmployment, _oct(9));
      await extra(21, type: const ShiftTypeId('day'));
      await extra(22);
      await extra(
        27,
        type: const ShiftTypeId('night'),
        start: const LocalTime(19, 0),
        end: const LocalTime(7, 0),
        endDayOffset: 1,
      );
      final sheet = await open();
      await until(() => words(days(sheet), 28).isNotEmpty);
      final shown = days(sheet, type: 'Extra');
      for (final day in [9, 21, 22, 27, 28]) {
        expect(shown[_oct(day)]!.dimmed, isFalse, reason: 'October $day');
      }
      expect(words(shown, 28), ['Extra until 07:00']);
      expect(shown[_oct(6)]!.dimmed, isTrue, reason: 'a planned Day');
      // The shift type the extra took still matches.
      final day = days(sheet, type: 'Day');
      expect(day[_oct(21)]!.dimmed, isFalse);
      // A confirmed extra keeps no shift type (ScheduleLink), only Extra.
      expect(day[_oct(9)]!.dimmed, isTrue);
      expect(day[_oct(22)]!.dimmed, isTrue);
      expect(days(sheet, type: 'Night')[_oct(28)]!.dimmed, isFalse);

      // The Shifts sheet keeps the same extras under Type: Extra.
      final kept = filterShiftsLines(
        shiftsLines(sheet, fixture.work.timezones),
        filter: const ShiftsFilter(
          status: ShiftsStatusFilter.all,
          type: 'Extra',
        ),
      );
      expect({for (final line in kept) line.date.day}, {9, 21, 22, 27});
    },
  );
}
