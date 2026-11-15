import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart' show ShiftsField;
import 'package:lifeos/app/work_shell/shifts_filter_strip.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show
        click,
        comboChoice,
        propertyColumn,
        propertyEditor,
        propertyValue,
        toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

const _tuesday = LocalDate(2026, 10, 6);

Finder _day(LocalDate date) => find.byKey(ValueKey('day-calendar-$date'));

DayCalendar _calendar(WidgetTester tester) =>
    tester.widget<DayCalendar>(find.byType(DayCalendar));

List<String> _words(WidgetTester tester, LocalDate date) => [
  for (final line in _calendar(tester).days[date]!.lines) line.spoken,
];

Finder _combo(String label) => find.byWidgetPredicate(
  (widget) => widget is EraCombo && widget.semanticLabel == label,
);

/// The Calendar sheet with the mouse (plan 4d-2, Task 4).
void main() {
  Future<void> pumpCalendar(WidgetTester tester) => pumpShiftsSheet(
    tester,
    store: MemoryLocationStore(
      '${const WorkLocation.calendar(fixtureEmployment, month: LocalDate(2026, 10, 1)).toUri()}',
    ),
  );

  testWidgets('clicking a day selects it; the property column and subform '
      'follow', (tester) async {
    await pumpCalendar(tester);
    expect(find.byType(DayCalendar), findsOneWidget);
    expect(shiftsGrid, findsNothing);
    await click(tester, _day(_tuesday));
    await settleSheet(tester);
    expect(sheetOf(tester).selectedId, plannedRowId(_tuesday));
    expect(_calendar(tester).selected, _tuesday);
    expect(
      find.descendant(
        of: propertyColumn,
        matching: find.textContaining('2026-10-06', findRichText: true),
      ),
      findsWidgets,
    );
    expect(
      tester.widget<Subform>(find.byType(Subform)).trailing,
      isA<Text>().having(
        (text) => text.data,
        'caption',
        endsWith('Tue 2026-10-06'),
      ),
    );
    expect(shellOf(tester).location.day, _tuesday);
    expect('${shellOf(tester).location.toUri()}', contains('day=2026-10-06'));
  });

  testWidgets('a time typed in the property column shows on the day', (
    tester,
  ) async {
    await pumpCalendar(tester);
    await click(tester, _day(_tuesday));
    await settleSheet(tester);
    sheetOf(tester).editField(
      plannedRowId(_tuesday),
      ShiftsField.end,
      const LocalTime(18, 0),
    );
    await tester.pump();
    expect(_words(tester, _tuesday).first, 'Day 07:00–18:00');
    // Leaving the day saves it.
    await click(tester, _day(const LocalDate(2026, 10, 7)));
    await settleSheet(tester);
    expect(_words(tester, _tuesday).first, 'Day 07:00–18:00');
    expect(sheetOf(tester).edit?.dirty ?? false, isFalse);
  });

  testWidgets('Confirm on a calendar day', (tester) async {
    await pumpCalendar(tester);
    final before = shellOf(tester).pastDays[fixtureEmployment]!.toConfirm;
    await click(tester, _day(_tuesday));
    await settleSheet(tester);
    await click(tester, toolbarKey('Confirm'));
    await settleSheet(tester);
    expect(_words(tester, _tuesday), ['Day 07:00–19:00', 'Confirmed']);
    expect(shellOf(tester).pastDays[fixtureEmployment]!.toConfirm, before - 1);
    expect(sheetOf(tester).selectedRow, isA<StoredRow>());
  });

  testWidgets('◂ ▸ and the combo change the month', (tester) async {
    await pumpCalendar(tester);
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    expect(shellOf(tester).location.from, const LocalDate(2026, 11, 1));
    expect(shellOf(tester).location.sheet, WorkSheetKind.calendar);
    expect(_calendar(tester).month, const LocalDate(2026, 11, 1));
    await click(tester, _combo('Period'));
    await settleSheet(tester);
    await click(tester, comboChoice('September 2026'));
    await settleSheet(tester);
    expect(shellOf(tester).location.from, const LocalDate(2026, 9, 1));
  });

  testWidgets('Status and Off days are not in the strip; Type dims', (
    tester,
  ) async {
    await pumpCalendar(tester);
    expect(_combo('Status'), findsNothing);
    expect(find.text('Off days'), findsNothing);
    expect(find.byType(DayCalendarKey), findsOneWidget);
    await click(tester, _combo('Type'));
    await settleSheet(tester);
    await click(tester, comboChoice('Night'));
    await settleSheet(tester);
    expect(shellOf(tester).location.filter.type, 'Night');
    expect(_calendar(tester).days[_tuesday]!.dimmed, isTrue);
    expect(
      _calendar(tester).days[const LocalDate(2026, 10, 12)]!.dimmed,
      isFalse,
    );
  });

  testWidgets('an Off day offers Add extra shift', (tester) async {
    await pumpCalendar(tester);
    await click(tester, _day(const LocalDate(2026, 10, 8)));
    await settleSheet(tester);
    expect(sheetOf(tester).selectedId, 'off:2026-10-08');
    await click(tester, toolbarKey('Add'));
    await settleSheet(tester);
    await click(tester, find.text('Extra shift on Thu 2026-10-08'));
    await settleSheet(tester);
    expect(sheetOf(tester).selectedId, newExtraRowId);
    expect(_words(tester, const LocalDate(2026, 10, 8)), [
      'Extra 07:00–19:00',
      'New, not saved',
    ]);
  });

  testWidgets('a time stepped in the property column is kept when another '
      'day is clicked', (tester) async {
    await pumpCalendar(tester);
    await click(tester, _day(_tuesday));
    await settleSheet(tester);
    final end = propertyValue(ShiftsField.end);
    await click(tester, end);
    await click(
      tester,
      find.descendant(
        of: end,
        matching: find.byKey(const ValueKey('era-time-up')),
      ),
    );
    // No Enter: the click on another day takes the typed value first.
    await click(tester, _day(const LocalDate(2026, 10, 7)));
    await settleSheet(tester);
    expect(_words(tester, _tuesday).first, isNot('Day 07:00–19:00'));
  });

  testWidgets('past midnight the Calendar rings the new day and counts the '
      'night just past', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.calendar(fixtureEmployment, month: LocalDate(2026, 10, 1)).toUri()}',
      ),
    );
    DayCalendar calendar() =>
        tester.widget<DayCalendar>(find.byType(DayCalendar));
    expect(calendar().today, const LocalDate(2026, 10, 20));
    expect(statusWarning(tester), '9 days to confirm');

    fixture.schedule.clock.value = DateTime.utc(2026, 10, 24, 6);
    unawaited(shellOf(tester).checkDay());
    await settleSheet(tester);
    expect(calendar().today, const LocalDate(2026, 10, 24));
    expect(statusWarning(tester), '10 days to confirm');
  });

  testWidgets('a value typed in an open editor holds the new day back', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.calendar(fixtureEmployment, month: LocalDate(2026, 10, 1)).toUri()}',
      ),
    );
    await click(tester, _day(const LocalDate(2026, 10, 7)));
    await settleSheet(tester);
    await click(tester, propertyValue(ShiftsField.end));
    await settleSheet(tester);
    final before = shellOf(tester).sheet;

    fixture.schedule.clock.value = DateTime.utc(2026, 10, 24, 6);
    unawaited(shellOf(tester).checkDay());
    await settleSheet(tester);
    expect(shellOf(tester).sheet, same(before));
    expect(propertyEditor(ShiftsField.end), findsOneWidget);
  });
}

String? statusWarning(WidgetTester tester) =>
    tester.widget<StatusBar>(find.byType(StatusBar)).warning;
