import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

import '../support/app_frame_harness.dart'
    show click, propertyValue, pushKey, toolbarKey;
import '../support/production_app.dart';
import '../support/schedule_fixture.dart' show fixtureEmployment;
import '../support/shifts_sheet_driver.dart';
import '../support/shifts_sheet_fixture.dart';
import '../support/work_shell_driver.dart';
import '../support/work_shell_fixture.dart';

LocalDate _oct(int day) => LocalDate(2026, 10, day);

Finder _treeNode(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));

Finder _day(LocalDate date) => find.byKey(ValueKey('day-calendar-$date'));

/// The production app (`LifeOsApp`, its one `/work` route, the Work shell)
/// over a real place file, closed by its window and started again.
void main() {
  late Directory folder;
  setUp(() => folder = Directory.systemTemp.createTempSync('lifeos-prod'));
  tearDown(() => folder.deleteSync(recursive: true));

  /// Presses the window's close button and lets the place file be written
  /// with real IO.
  Future<void> closeWindow(WidgetTester tester, FakeWindowClose window) async {
    await tester.runAsync(window.pressClose);
    await settleSheet(tester);
  }

  /// Starts the app again over the same database and place file.
  Future<void> restart(
    WidgetTester tester,
    EmptyWorkFixture fixture,
    LocationStore store,
    FakeWindowClose window,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await pumpProductionApp(
      tester,
      work: fixture.work,
      reads: fixture.reads,
      store: store,
      closeApi: window,
      settle: false,
    );
    // The place file is read with real IO, outside the test's clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleSheet(tester);
  }

  testWidgets('from an empty database to a confirmed day; each start '
      'returns to where the window was closed', (tester) async {
    late EmptyWorkFixture fixture;
    await tester.runAsync(
      () async => fixture = await EmptyWorkFixture.create(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(fixture.dispose);
    });
    final store = FileLocationStore.beside(
      File('${folder.path}/lifeos-native-v1.sqlite'),
    );
    final window = FakeWindowClose();
    var released = 0;
    await pumpProductionApp(
      tester,
      work: fixture.work,
      reads: fixture.reads,
      store: store,
      closeApi: window,
      release: () async => released++,
      settle: false,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleSheet(tester);
    final first = shellOf(tester);
    expect(first.location, const WorkLocation.overview());

    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    await typeProperty(tester, EmploymentField.name, 'Synthetic bakery');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    await click(tester, propertyValue('agreement'));
    await settleSheet(tester);
    await typeProperty(tester, AgreementField.hourlyRate, '18.40');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    await click(tester, propertyValue('schedule'));
    await settleSheet(tester);
    final schedules = first.schedulesSheet!;
    await typeProperty(tester, ScheduleField.name, 'Bakery rotation');
    await tester.runAsync(() async {
      schedules
        ..editField(ScheduleField.cycleStart, _oct(5))
        ..editField(ScheduleField.inUseFrom, _oct(5))
        ..addType();
      final day = schedules.session!.draft.types.single;
      schedules
        ..editType(day.id, ScheduleField.typeName, 'Day')
        ..editType(day.id, ScheduleField.typeStart, const LocalTime(7, 0))
        ..editType(day.id, ScheduleField.typeEnd, const LocalTime(19, 0));
      for (final (count, type) in [(3, day.id), (4, null)]) {
        schedules.addBlock();
        final last = schedules.session!.draft.blocks.length - 1;
        schedules
          ..editBlock(last, ScheduleField.blockDays, '$count')
          ..editBlock(last, ScheduleField.blockType, type);
      }
    });
    await tester.pump();
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    final employment = first.location.employmentId!;
    final placed = first.location;
    expect(placed.sheet, WorkSheetKind.schedules);

    // Closing remembers the place beside the database and releases it.
    await closeWindow(tester, window);
    expect(window.destroyed, 1);
    expect(released, 1);
    expect(
      store.file.path,
      '${folder.path}/${FileLocationStore.placeFilename}',
    );
    expect(store.file.readAsStringSync(), '${placed.toUri()}');

    await restart(tester, fixture, store, window);
    expect(shellOf(tester).location, placed);

    // Confirm a past day on the Calendar, close, and start there again.
    await click(tester, _treeNode('Calendar'));
    await settleSheet(tester);
    await click(tester, _day(_oct(6)));
    await settleSheet(tester);
    await click(tester, toolbarKey('Confirm'));
    await settleSheet(tester);
    final confirmedOn = shellOf(tester).location;
    expect(confirmedOn.sheet, WorkSheetKind.calendar);
    expect(confirmedOn.employmentId, employment);

    await closeWindow(tester, window);
    expect(window.destroyed, 2);
    await restart(tester, fixture, store, window);
    expect(shellOf(tester).location, confirmedOn);
    expect(
      tester
          .widget<DayCalendar>(find.byType(DayCalendar))
          .days[_oct(6)]!
          .lines
          .last
          .spoken,
      'Confirmed',
    );
  });

  testWidgets('a current database opens on the Calendar and '
      'preserves preferences', (tester) async {
    late ShiftsSheetFixture fixture;
    await tester.runAsync(() async {
      fixture = await ShiftsSheetFixture.create();
      final database = fixture.schedule.database;
      await database.customStatement(
        "INSERT INTO preferences (key, value) VALUES ('appearance', 'night')",
      );
    });
    addTearDown(() => closeShiftsSheet(tester, fixture));

    await pumpProductionApp(
      tester,
      work: fixture.work,
      reads: fixture.reads,
      store: MemoryLocationStore(),
    );
    final shell = shellOf(tester);
    expect(
      shell.location,
      WorkLocation.calendar(fixtureEmployment, month: _oct(1)),
    );
    final context = tester.element(find.byType(AppFrame));
    expect(LifeOSSkinScope.of(context).tokens, same(LifeOSTokens.millennium));

    await tester.runAsync(() async {
      final preference = await fixture.schedule.database
          .customSelect(
            "SELECT value FROM preferences WHERE key = 'appearance'",
          )
          .getSingle();
      expect(preference.data['value'], 'night');
    });
    await closeShiftsSheet(tester, fixture);
  });
}
