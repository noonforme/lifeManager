import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_shell/schedules_sheet_controller.dart';
import 'package:lifeos/app/work_shell/schedules_sheet_part.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_history.dart'
    show scheduleRecordId;
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/failing_work.dart' show LosingSchedules;
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

Future<void> until(bool Function() condition) async {
  for (var turn = 0; turn < 200 && !condition(); turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'condition never held');
}

void main() {
  late ShiftsSheetFixture fixture;
  late ScriptedConfirm confirm;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    confirm = ScriptedConfirm();
  });
  tearDown(() => fixture.dispose());

  Future<SchedulesSheetController> open({ProductionWorkProviders? work}) async {
    final sheet = SchedulesSheetController(
      work: work ?? fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      today: ShiftsSheetFixture.today,
      confirm: (request) => confirm(request),
      coordinator: LeaveCoordinator(confirm: (request) => confirm(request)),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    return sheet;
  }

  SchedulesSheetPart partOf(SchedulesSheetController sheet) {
    final editors = EditorSessionController();
    addTearDown(editors.dispose);
    return SchedulesSheetPart(
      sheet: sheet,
      editors: editors,
      work: fixture.work,
      today: ShiftsSheetFixture.today,
      employmentName: 'Synthetic depot',
      onEmployment: () {},
    );
  }

  ToolbarItem key(SchedulesSheetPart part, String label) =>
      [for (final band in part.bands()) ...band.items]
          .whereType<ToolbarItem>()
          .singleWhere((item) => item.label == label);

  Future<WorkSchedule> depot() async =>
      (await fixture.schedule.repository.schedulesFor(fixtureEmployment))
          .single;

  Future<SchedulesSheetController> usedSheet() async {
    await fixture.schedule.markUsed(await depot());
    final sheet = await open();
    await until(() => sheet.rows.single.used);
    await sheet.select(sheet.rows.single.rowId);
    return sheet;
  }

  /// Pumps [build] (rebuilt whenever [sheet] changes) in a desktop host.
  Future<void> pump(
    WidgetTester tester,
    SchedulesSheetController sheet,
    Widget Function(BuildContext context) build,
  ) async {
    tester.view.physicalSize = const Size(900, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GalleryHost(
        home: ListenableBuilder(
          listenable: sheet,
          builder: (context, _) =>
              SizedBox(width: 880, height: 340, child: Builder(builder: build)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('a stored schedule lists its properties', () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    final grid = partOf(sheet).properties() as PropertyGrid;
    final items = {for (final item in grid.items) item.key: item};
    for (final key in [
      ScheduleField.name,
      ScheduleField.timezone,
      ScheduleField.cycleStart,
      ScheduleField.inUseFrom,
      ScheduleField.inUseUntil,
    ]) {
      expect(items, contains(key));
      expect(items[key]!.readOnlyReason, isNull);
    }
    expect(items['length']!.value, '12 days');
    expect(items['shifts']!.value, '6 per cycle');
    expect(items['paid']!.value, '69:00 per cycle');
    await until(() => sheet.planInputs != null);
    final priced = {
      for (final item in (partOf(sheet).properties() as PropertyGrid).items)
        item.key: item,
    };
    // Three days at EUR 211.60 and three nights at EUR 280.60.
    expect(priced['cyclePay']!.value, 'EUR 1476.60 per cycle');
  });

  test('a used version is read-only with the reason', () async {
    final sheet = await usedSheet();
    final grid = partOf(sheet).properties() as PropertyGrid;
    final name = grid.items.singleWhere((i) => i.key == ScheduleField.name);
    expect(name.readOnlyReason, SchedulesCommandWords.used);
  });

  test("a type's Ends is worked out", () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    sheet.showTypes(true);
    sheet.selectType(const ShiftTypeId('night'));
    final part = partOf(sheet);
    final grid = part.properties() as PropertyGrid;
    expect(grid.record, 'type:night');
    expect(grid.items.singleWhere((i) => i.key == 'ends').value, 'Next day');
  });

  test('the grid lists versions with their state', () async {
    final sheet = await usedSheet();
    await sheet.changeFrom();
    sheet.editField(ScheduleField.versionFrom, const LocalDate(2026, 10, 21));
    await sheet.save();
    await until(() => sheet.rows.length == 2);
    final grid = partOf(sheet).middle() as DataGrid<ScheduleLine>;
    final lines = [
      for (final line in grid.lines)
        if (line is GridRow<ScheduleLine>) line.row,
    ];
    expect([for (final line in lines) line.version], ['v1', 'v2']);
    expect([for (final line in lines) line.state], ['In use', 'Later']);
    expect(lines.first.confirmed, '1 day');
  });

  test('Change schedule with nothing changed says so in its panel', () async {
    final sheet = await usedSheet();
    await sheet.changeFrom();
    final part = partOf(sheet);
    String? said() => (part.properties() as ActionPanel).error;
    expect(said(), isNull);
    expect(await sheet.save(), SaveResult.clean);
    expect(said(), SchedulesNotices.changeNothing);
    // Opened again, the panel starts without it.
    await sheet.cancelChange();
    await sheet.changeFrom();
    expect(said(), isNull);
    expect(await sheet.save(), SaveResult.clean);
    // A change makes it untrue.
    sheet.editBlock(0, ScheduleField.blockDays, '4');
    expect(said(), isNull);
  });

  test('Change schedule from shows its panel and pending row', () async {
    final sheet = await usedSheet();
    await sheet.changeFrom();
    final part = partOf(sheet);
    final panel = part.properties() as ActionPanel;
    expect(panel.title, SchedulesPartWords.changeTitle);
    expect(panel.primaryLabel, SchedulesPartWords.changePrimary);
    expect(part.notice(), SchedulesPartWords.changeHint);
    final grid = part.middle() as DataGrid<ScheduleLine>;
    expect(
      [
        for (final line in grid.lines)
          (line as GridRow<ScheduleLine>).row.version,
      ],
      ['v1', 'New'],
    );
  });

  testWidgets('the Cycle tab shows the strip and reorders by drag', (
    tester,
  ) async {
    late SchedulesSheetController sheet;
    await tester.runAsync(() async {
      sheet = await open();
      await sheet.select(scheduleRecordId(await depot()));
    });
    final part = partOf(sheet);
    await pump(
      tester,
      sheet,
      (context) => partOf(sheet).subformTabs().first.builder(context),
    );
    expect(part.subformTabs().first.id, SchedulesSubformTab.cycle);
    expect(find.byType(DayStrip), findsOneWidget);
    expect(find.text('Cycle, 12 days:'), findsOneWidget);
    // Each block of a shift type shows what one of its days pays.
    expect(find.text('EUR 211.60'), findsOneWidget);
    expect(find.text('EUR 280.60'), findsOneWidget);
    expect(find.text('7:30'), findsOneWidget);
    final grip = find.byKey(const ValueKey('grid-grip:block:2'));
    final gesture = await tester.startGesture(
      tester.getCenter(grip),
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(0, -2));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      [for (final b in sheet.session!.draft.blocks) b.shiftTypeId?.value],
      ['day', 'night', null, null],
    );
    expect(sheet.session!.dirty, isTrue);
  });

  testWidgets('a save whose result is not known stills the Cycle grips', (
    tester,
  ) async {
    late SchedulesSheetController sheet;
    await tester.runAsync(() async {
      sheet = await open(
        work: fixture.work.replacing(
          schedules: ScheduleService(
            repository: LosingSchedules(fixture.schedule.repository),
            ids: fixture.schedule.ids,
            clock: fixture.schedule.clock,
          ),
        ),
      );
      await sheet.select(scheduleRecordId(await depot()));
      sheet.editBlock(0, ScheduleField.blockDays, '4');
      await sheet.save();
    });
    // The lost answer is reported.
    expect(tester.takeException(), isA<StateError>());
    expect(sheet.session!.phase, EditPhase.uncertain);
    await pump(
      tester,
      sheet,
      (context) => partOf(sheet).subformTabs().first.builder(context),
    );
    final cycle = tester
        .widgetList<DataGrid<Object?>>(
          find.byWidgetPredicate((widget) => widget is DataGrid),
        )
        .singleWhere((grid) => grid.onReorder != null);
    expect(cycle.reorderReason, EditProblems.busy);
  });

  test('Shift types swaps the grid and back', () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    var part = partOf(sheet);
    expect(part.middleHeader(), isNull);
    key(part, SchedulesPartWords.shiftTypes).onPressed!();
    await until(() => sheet.showingTypes);
    part = partOf(sheet);
    expect(part.middleHeader(), isNotNull);
    expect(part.middle(), isA<DataGrid<TypeLine>>());
    expect(
      [for (final tab in part.subformTabs()) tab.label],
      ['Breaks', 'Used in cycle'],
    );
    expect(part.statusPanel(), '2 shift types');
    await until(() => sheet.planInputs != null);
    final types = partOf(sheet).middle() as DataGrid<TypeLine>;
    String cell(String type, String key) {
      final line = types.lines
          .whereType<GridRow<TypeLine>>()
          .map((row) => row.row)
          .singleWhere((line) => line.type.name == type);
      return '${types.columns.singleWhere((c) => c.key == key).value(line)}';
    }

    expect(cell('Day', 'night'), '0:00');
    expect(cell('Day', 'pay'), 'EUR 211.60');
    expect(cell('Night', 'night'), '7:30');
    expect(cell('Night', 'pay'), 'EUR 280.60');
    sheet.showTypes(false);
    expect(partOf(sheet).middle(), isA<DataGrid<ScheduleLine>>());
  });

  testWidgets('Preview shows four months', (tester) async {
    late SchedulesSheetController sheet;
    await tester.runAsync(() async {
      sheet = await open();
      await sheet.select(scheduleRecordId(await depot()));
      await until(() => sheet.planInputs != null);
    });
    await pump(
      tester,
      sheet,
      (context) =>
          partOf(sheet)
              .subformTabs()
              .singleWhere((tab) => tab.id == SchedulesSubformTab.preview)
              .builder(context),
    );
    final strip = tester.widget<MonthStrip>(find.byType(MonthStrip));
    expect(
      [for (final row in strip.rows) row.label],
      ['Oct 2026', 'Nov 2026', 'Dec 2026', 'Jan 2027'],
    );
    expect(strip.rows.first.totals.take(2), ['15', '173:30']);
  });

  test('the toolbar greys what does not apply and says why', () async {
    final sheet = await open();
    var part = partOf(sheet);
    expect(key(part, SchedulesPartWords.change).onPressed, isNull);
    expect(
      key(part, SchedulesPartWords.change).tooltip,
      SchedulesCommandWords.selectFirst,
    );
    await fixture.schedule.markUsed(await depot());
    await until(() => sheet.rows.single.used);
    await sheet.select(sheet.rows.single.rowId);
    part = partOf(sheet);
    expect(key(part, 'Delete').tooltip, SchedulesCommandWords.deleteUsed);
    expect(key(part, SchedulesPartWords.change).onPressed, isNotNull);
    final menu = part.recordMenu();
    expect(
      menu
          .singleWhere((i) => i.label == SchedulesPartWords.delete)
          .disabledReason,
      SchedulesCommandWords.deleteUsed,
    );
    expect(part.addItems().single.label, 'Schedule');
  });

  test('an empty sheet is an empty grid with its * row', () async {
    final empty = await EmptyWorkFixture.create();
    addTearDown(empty.dispose);
    final created = await empty.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic site', legalLabel: null),
    );
    final site = (created as Committed<Employment>).value;
    final sheet = SchedulesSheetController(
      work: empty.work,
      reads: empty.reads,
      employmentId: site.id,
      today: ShiftsSheetFixture.today,
      confirm: (request) => confirm(request),
      coordinator: LeaveCoordinator(confirm: (request) => confirm(request)),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    final editors = EditorSessionController();
    addTearDown(editors.dispose);
    SchedulesSheetPart part() => SchedulesSheetPart(
      sheet: sheet,
      editors: editors,
      work: empty.work,
      today: ShiftsSheetFixture.today,
      employmentName: 'Synthetic site',
      onEmployment: () {},
    );
    final grid = part().middle() as DataGrid<ScheduleLine>;
    expect(grid.lines, isEmpty);
    expect(grid.onNew, isNotNull);
    await sheet.addSchedule();
    expect(part().notice(), SchedulesNotices.newSchedule);
    expect(part().statusPanel(), '1 schedule');
  });

  test("the panel's From refuses a day the rules refuse, in words", () async {
    final sheet = await usedSheet();
    await sheet.changeFrom();
    final panel = partOf(sheet).properties() as ActionPanel;
    final from = panel
        .groups()
        .expand((group) => group.fields)
        .singleWhere((field) => field.id == ScheduleField.versionFrom);
    expect(
      from.validate!(const LocalDate(2026, 10, 5)),
      ScheduleProblems.confirmedUpTo(const LocalDate(2026, 10, 5)),
    );
    expect(from.validate!(const LocalDate(2026, 10, 25)), isNull);
  });

  test('a break left outside its shift is shown and named', () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    sheet.showTypes(true);
    // Day 07:00–19:00 keeps its 12:00 break; ending at 11:00 strands it.
    expect(
      sheet.editType(
        const ShiftTypeId('day'),
        ScheduleField.typeEnd,
        const LocalTime(11, 0),
      ),
      isNull,
    );
    final grid = partOf(sheet).middle() as DataGrid<TypeLine>;
    expect(
      grid.errors[const GridCell('day', 'break')],
      ScheduleProblems.breaks,
    );
    sheet.showTypes(false);
    await sheet.save();
    expect(partOf(sheet).notice(), contains('Day: ${ScheduleProblems.breaks}'));
  });
}
