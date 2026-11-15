import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_filter_strip.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show click, liveToolbarKey, press, pushKey, toolbarKey;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_driver.dart';

/// Presses the window's close button and lets the guard ask.
Future<void> pressClose(WidgetTester tester, FakeWindowClose window) async {
  unawaited(window.pressClose());
  await settleSheet(tester);
}

/// Chooses File › Quit with the mouse.
Future<void> fileQuit(WidgetTester tester) async {
  await click(tester, find.text('File'));
  await settleSheet(tester);
  await click(tester, find.text(WorkShellWords.quit));
  await settleSheet(tester);
}

/// A place store that records its writes in [events] and may refuse them.
final class RecordingStore implements LocationStore {
  RecordingStore(this.events, {this.fails = false});

  final List<String> events;
  final bool fails;

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String route) async {
    events.add('write');
    if (fails) throw StateError('disk full');
  }
}

/// The confirmation window's key [label]; the toolbar may have one too.
Finder windowKey(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is ConfirmWindow),
  matching: pushKey(label),
);

/// Runs [body], returning the errors it reported; expectations come after.
Future<List<FlutterErrorDetails>> reporting(
  Future<void> Function() body,
) async {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}

/// Pumps the depot's October Shifts over a database file, the shell
/// reading through a second connection that [ReadGate] can make
/// unreadable.
Future<(ShiftsSheetFixture, ReadGate)> pumpOverTwoConnections(
  WidgetTester tester,
  FakeWindowClose window,
) async {
  final warned = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final dir = Directory.systemTemp.createTempSync('work_shell_close');
  final file = File('${dir.path}/work.sqlite');
  final gate = ReadGate();
  final readsDb = AppDatabase(NativeDatabase(file).interceptWith(gate));
  // Runs after the shell unmounts and the fixture's database closes.
  addTearDown(() async {
    await tester.runAsync(readsDb.close);
    dir.deleteSync(recursive: true);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = warned;
  });
  final fixture = await pumpShiftsSheet(
    tester,
    closeApi: window,
    executor: NativeDatabase(file),
    reads: WorkReads(readsDb),
  );
  return (fixture, gate);
}

/// Enters a new shift and saves it; its read-back after the commit fails,
/// so the save may have gone through.
Future<void> saveUncertainNewShift(WidgetTester tester, ReadGate gate) async {
  await click(tester, toolbarKey('New shift'));
  await settleSheet(tester);
  await stepGridTime(tester, newRowId, 'end', 'up');
  await click(tester, toolbarKey('Save'));
  await settleSheet(tester);
  gate.failing = true;
  final reported = await reporting(() async {
    await click(tester, pushKey('Save and finalize'));
    await settleSheet(tester);
  });
  expect(reported, hasLength(1), reason: 'the failed read-back');
  expect(sheetOf(tester).edit?.phase, EditPhase.uncertain);
}

void main() {
  testWidgets('the database is released after the place is written', (
    tester,
  ) async {
    final events = <String>[];
    final window = FakeWindowClose();
    await pumpEmptyShell(
      tester,
      store: RecordingStore(events),
      closeApi: window,
      release: () async => events.add('release'),
    );
    await pressClose(tester, window);
    expect(window.destroyed, 1);
    expect(events, ['write', 'release']);
  });

  testWidgets('the database is released and the failure reported when '
      'remembering the place fails', (tester) async {
    final events = <String>[];
    final window = FakeWindowClose();
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    await pumpEmptyShell(
      tester,
      store: RecordingStore(events, fails: true),
      closeApi: window,
      release: () async => events.add('release'),
    );
    await pressClose(tester, window);
    expect(events, ['write', 'release']);
    expect(window.destroyed, 1);
    expect(reported, hasLength(1));
    expect(reported.single.exception, isA<StateError>());
  });

  testWidgets('an unmounted shell lets go of the close button', (tester) async {
    final window = FakeWindowClose();
    final events = <String>[];
    await pumpEmptyShell(
      tester,
      store: RecordingStore(events),
      closeApi: window,
      release: () async => events.add('release'),
    );
    await tester.pumpWidget(const SizedBox());
    final reported = await reporting(() async {
      await window.pressClose();
      await tester.pump();
    });
    expect(reported, isEmpty);
    expect(window.destroyed, 1);
    expect(
      events,
      isEmpty,
      reason:
          'a disposed shell neither remembers '
          'its place nor releases the database',
    );
  });

  testWidgets('a shell started again keeps the close button when the one '
      'before it goes', (tester) async {
    final window = FakeWindowClose();
    final events = <String>[];
    final fixture = await pumpEmptyShell(
      tester,
      store: MemoryLocationStore(),
      closeApi: window,
    );
    // The new shell takes the button before the old one is disposed.
    await pumpShellOver(
      tester,
      fixture,
      store: RecordingStore(events),
      closeApi: window,
    );
    await pressClose(tester, window);
    expect(window.destroyed, 1);
    expect(events, ['write'], reason: 'the new shell remembered its place');
  });

  testWidgets('File › Quit with nothing pending closes at once and '
      'remembers the place', (tester) async {
    final window = FakeWindowClose();
    final store = MemoryLocationStore(
      '${const WorkLocation.shifts(fixtureEmployment, month: LocalDate(2026, 10, 1)).toUri()}',
    );
    final fixture = await pumpShiftsSheet(
      tester,
      closeApi: window,
      store: store,
    );
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    await fileQuit(tester);
    expect(window.destroyed, 1);
    expect(store.route, '${shellOf(tester).location.toUri()}');
    expect(shellOf(tester).location.month, const LocalDate(2026, 11, 1));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('closing with a pending planned-day change saves it, then '
      'closes', (tester) async {
    final window = FakeWindowClose();
    final fixture = await pumpShiftsSheet(tester, closeApi: window);
    final day = plannedRowId(const LocalDate(2026, 10, 5));
    await selectShiftsRow(tester, day);
    await stepGridTime(tester, day, 'end', 'down');
    await pressClose(tester, window);
    expect(window.destroyed, 1);
    late int changes;
    await tester.runAsync(() async {
      changes = (await fixture.work.plans.repository.planInputs(
        fixtureEmployment,
      )).exceptions.length;
    });
    expect(changes, 1);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('closing with a new shift asks to finalize it: Cancel keeps '
      'the window and the shift; Discard closes and stores nothing', (
    tester,
  ) async {
    final window = FakeWindowClose();
    final fixture = await pumpShiftsSheet(tester, closeApi: window);
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    await stepGridTime(tester, newRowId, 'end', 'down');
    await pressClose(tester, window);
    expect(pushKey('Save and finalize'), findsOneWidget);
    await click(tester, pushKey('Cancel'));
    await settleSheet(tester);
    expect(window.destroyed, 0);
    expect(sheetOf(tester).selectedId, newRowId);
    expect(sheetOf(tester).edit?.dirty, isTrue);

    await pressClose(tester, window);
    await click(tester, pushKey('Discard'));
    await settleSheet(tester);
    expect(window.destroyed, 1);
    late List<WorkShift> shifts;
    await tester.runAsync(() async {
      shifts = await fixture.reads.shiftsOf(fixtureEmployment);
    });
    expect(shifts, isEmpty);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('closing with a reason typed in Correct asks Discard input and '
      'quit or Keep editing', (tester) async {
    final window = FakeWindowClose();
    final fixture = await pumpShiftsSheet(tester, closeApi: window);
    late WorkShift shift;
    await tester.runAsync(() async {
      shift = await fixture.finishShift(20);
    });
    await settleSheet(tester);
    await selectShiftsRow(tester, storedRowId(shift));
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    final reason = find.byKey(const ValueKey('action-reason'));
    await click(tester, reason);
    await tester.enterText(reason, 'Wrong end');
    await press(tester, LogicalKeyboardKey.enter);
    await settleSheet(tester);

    await pressClose(tester, window);
    await click(tester, pushKey('Keep editing'));
    await settleSheet(tester);
    expect(window.destroyed, 0);
    expect(find.byType(ActionPanel), findsOneWidget);
    expect(sheetOf(tester).action?.reason, 'Wrong end');

    await pressClose(tester, window);
    await click(tester, pushKey('Discard input and quit'));
    await settleSheet(tester);
    expect(window.destroyed, 1);
    late WorkShift now;
    await tester.runAsync(() async {
      now = (await fixture.reads.shift(shift.id))!.shift;
    });
    expect(now.state, ShiftState.finalized);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('closing with an invalid new employment offers Discard and '
      'quit or Keep editing', (tester) async {
    final window = FakeWindowClose();
    await pumpEmptyShell(
      tester,
      store: MemoryLocationStore(),
      closeApi: window,
    );
    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    await typeProperty(tester, EmploymentField.legalLabel, 'UAB Synthetic');

    await pressClose(tester, window);
    await click(tester, pushKey('Keep editing'));
    await settleSheet(tester);
    expect(window.destroyed, 0);
    expect(
      shellOf(tester).employmentsSheet?.employment?.draft.legalLabel,
      'UAB Synthetic',
    );

    await pressClose(tester, window);
    await click(tester, pushKey('Discard and quit'));
    await settleSheet(tester);
    expect(window.destroyed, 1);
  });

  testWidgets('quitting after an uncertain new shift: Reload and check finds '
      'it saved; the window stays, and the shift is listed once and in the '
      'route', (tester) async {
    final window = FakeWindowClose();
    final (fixture, gate) = await pumpOverTwoConnections(tester, window);
    await saveUncertainNewShift(tester, gate);
    gate.failing = false;

    await fileQuit(tester);
    await click(tester, windowKey('Reload and check'));
    await settleSheet(tester);
    expect(window.destroyed, 0);
    late WorkShift stored;
    await tester.runAsync(() async {
      stored = (await fixture.reads.shiftsOf(fixtureEmployment)).single;
    });
    final ids = shiftsLines(
      sheetOf(tester),
      fixture.work.timezones,
    ).map((line) => line.id);
    expect(ids.where((id) => id == newRowId), isEmpty);
    expect(ids.where((id) => id == storedRowId(stored)), hasLength(1));
    expect(shellOf(tester).location.shift, stored.id);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("the toolbar's Reload and check after an uncertain new shift "
      'finds it saved and selects it under its id', (tester) async {
    final window = FakeWindowClose();
    final (fixture, gate) = await pumpOverTwoConnections(tester, window);
    await saveUncertainNewShift(tester, gate);
    expect(liveToolbarKey('Reload record'), findsNothing);
    gate.failing = false;

    await click(tester, liveToolbarKey('Reload and check'));
    await settleSheet(tester);
    late WorkShift stored;
    await tester.runAsync(() async {
      stored = (await fixture.reads.shiftsOf(fixtureEmployment)).single;
    });
    expect(sheetOf(tester).edit?.phase, isNot(EditPhase.uncertain));
    expect(sheetOf(tester).selectedId, storedRowId(stored));
    expect(liveToolbarKey('Reload and check'), findsNothing);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('quitting after a check that could not tell offers Quit '
      'anyway, which closes', (tester) async {
    final window = FakeWindowClose();
    final (fixture, gate) = await pumpOverTwoConnections(tester, window);
    await saveUncertainNewShift(tester, gate);

    await fileQuit(tester);
    final reported = await reporting(() async {
      await click(tester, windowKey('Reload and check'));
      await settleSheet(tester);
    });
    expect(reported, hasLength(1), reason: 'the check could not read');
    expect(window.destroyed, 0);
    expect(sheetOf(tester).edit?.session.unresolved, isTrue);

    await fileQuit(tester);
    await click(tester, windowKey('Quit anyway'));
    await settleSheet(tester);
    expect(window.destroyed, 1);
    await closeShiftsSheet(tester, fixture);
  });
}
