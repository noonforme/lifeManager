import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/presentation/schedules_sheet.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/ui/ui.dart';

import '../../../support/schedule_views.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_sheets.dart';

WorkSchedule _version(int version, LocalDate from, LocalDate? until) {
  final base = depotSchedule();
  return WorkSchedule(
    id: base.id,
    employmentId: base.employmentId,
    name: base.name,
    timezoneId: base.timezoneId,
    version: version,
    cycleStart: base.cycleStart,
    inUseFrom: from,
    inUseUntil: until,
    shiftTypes: base.shiftTypes,
    blocks: base.blocks,
    createdAtUtc: base.createdAtUtc,
    revision: const Revision(0),
  );
}

void main() {
  test('a version is in use, ended or future on a date', () {
    final version = _version(
      1,
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 31),
    );
    expect(scheduleState(version, const LocalDate(2026, 10, 7)), 'In use');
    expect(scheduleState(version, const LocalDate(2026, 11, 1)), 'Ended');
    expect(scheduleState(version, const LocalDate(2026, 10, 1)), 'Future');
  });

  testWidgets('each version is a row; opening one opens its schedule', (
    tester,
  ) async {
    WorkRecordRef? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SchedulesSheet(
              versions: [
                _version(
                  1,
                  const LocalDate(2026, 10, 5),
                  const LocalDate(2026, 10, 31),
                ),
                _version(2, const LocalDate(2026, 11, 1), null),
              ],
              today: const LocalDate(2026, 10, 7),
              selectedId: null,
              onOpen: (_) {},
              onProperties: (record) => opened = record,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Depot rotation'), findsNWidgets(2));
    expect(find.text('In use'), findsOneWidget);
    expect(find.text('Future'), findsOneWidget);
    expect(find.text('12 days'), findsNWidgets(2));
    await tester.tap(find.text('2026-11-01'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened?.kind, WorkRecordKind.schedule);
    expect(opened?.id, depotScheduleId);
  });

  testWidgets('the sheet lists the employment\'s schedule', (tester) async {
    await pumpScheduledApp(tester);
    await chooseSheet(tester, 'Schedules');
    expect(find.text('Depot rotation'), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);
  });

  testWidgets('with no schedule it offers a new one', (tester) async {
    await pumpScheduledApp(
      tester,
      withSchedule: false,
      location: '/work?employment={employment}&sheet=schedules',
    );
    expect(find.text('No schedules yet'), findsOneWidget);
    expect(find.text('New schedule…'), findsWidgets);
  });
}
