import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_filter_strip.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_menus.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show
        click,
        drag,
        press,
        propertyEditor,
        propertyValue,
        pushKey,
        resizeTo,
        splitter,
        toolbarKey;
import '../../support/failing_work.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_driver.dart';

const _october = LocalDate(2026, 10, 1);
const _november = LocalDate(2026, 11, 1);

/// The tree node labelled [label].
Finder treeNode(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));

/// Whether the toolbar key [label] can be pressed.
bool keyEnabled(WidgetTester tester, String label) =>
    tester
        .widget<BandedToolbar>(find.byType(BandedToolbar))
        .bands
        .expand((band) => band.items)
        .firstWhere((item) => item.label == label)
        .onPressed !=
    null;

void main() {
  ProductionWorkProviders observedWork(
    ShiftsSheetFixture fixture,
    List<String> events,
  ) => fixture.work.replacing(
    plans: DayPlanService(
      repository: PlanReadGate(fixture.work.plans.repository, failing: false)
        ..onExceptionCommitted = () => events.add('commit'),
      shifts: fixture.schedule.shifts,
      ids: fixture.schedule.ids,
      clock: fixture.schedule.clock,
      zoneClocks: fixture.work.plans.zoneClocks,
    ),
  );

  group('a refused value in an open editor holds the menu bar', () {
    Future<(ShiftsSheetFixture, Finder)> typeRefused(
      WidgetTester tester,
    ) async {
      final fixture = await pumpShiftsSheet(
        tester,
        store: MemoryLocationStore(
          '${const WorkLocation.agreements(fixtureEmployment, agreement: fixtureAgreement).toUri()}',
        ),
      );
      await settleSheet(tester);
      await click(tester, propertyValue(AgreementField.hourlyRate));
      final text = find.descendant(
        of: propertyEditor(AgreementField.hourlyRate),
        matching: find.byType(EditableText),
      );
      await tester.enterText(text, 'abc');
      await tester.pump();
      return (fixture, text);
    }

    Future<void> choose(WidgetTester tester, String menu, String row) async {
      await click(tester, find.text(menu));
      await settleSheet(tester);
      await click(tester, find.text(row).last);
      await settleSheet(tester);
    }

    testWidgets('View › Shifts stays on the sheet', (tester) async {
      final (fixture, text) = await typeRefused(tester);
      await choose(tester, 'View', 'Shifts');
      expect(shellOf(tester).location.sheet, WorkSheetKind.agreements);
      expect(tester.widget<EditableText>(text).controller.text, 'abc');
      await press(tester, LogicalKeyboardKey.escape);
      await closeShiftsSheet(tester, fixture);
    });

    testWidgets('Restore pane sizes keeps the panes', (tester) async {
      final fixture = await pumpShiftsSheet(
        tester,
        store: MemoryLocationStore(
          '${const WorkLocation.agreements(fixtureEmployment, agreement: fixtureAgreement).toUri()}',
        ),
      );
      await settleSheet(tester);
      final lower = find.byType(Subform);
      final baseline = tester.getSize(lower).height;
      await drag(tester, splitter('lower'), const Offset(0, -30));
      final moved = tester.getSize(lower).height;
      expect(moved, greaterThan(baseline));
      await click(tester, propertyValue(AgreementField.hourlyRate));
      final text = find.descendant(
        of: propertyEditor(AgreementField.hourlyRate),
        matching: find.byType(EditableText),
      );
      await tester.enterText(text, 'abc');
      await tester.pump();
      await choose(tester, 'Window', 'Restore pane sizes');
      expect(tester.getSize(lower).height, moved);
      expect(tester.widget<EditableText>(text).controller.text, 'abc');
      // Once the value is dropped, the sizes go back.
      await press(tester, LogicalKeyboardKey.escape);
      await settleSheet(tester);
      await choose(tester, 'Window', 'Restore pane sizes');
      expect(tester.getSize(lower).height, baseline);
      await closeShiftsSheet(tester, fixture);
    });
  });
  testWidgets('Window › Tree follows the window and rests on Licences', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    EraMenuItem tree() => tester
        .widget<AppFrame>(find.byType(AppFrame))
        .menus
        .singleWhere((menu) => menu.label == 'Window')
        .items
        .singleWhere((item) => item.label == 'Tree');
    expect(tree().onSelected, isNull, reason: 'the tree is a column');
    expect(tree().disabledReason, WorkMenuWords.treeShown);
    await resizeTo(tester, const Size(900, 760));
    await settleSheet(tester);
    expect(tree().onSelected, isNotNull, reason: 'the tree is folded');
    await click(tester, find.text('Help'));
    await settleSheet(tester);
    await click(tester, find.text('Licences'));
    await settleSheet(tester);
    expect(find.byType(LicencesPage), findsOneWidget);
    expect(tree().onSelected, isNull, reason: 'Licences shows');
    expect(tree().disabledReason, WorkMenuWords.onLicences);
    await closeShiftsSheet(tester, fixture);
  });
  testWidgets('the tree goes to the overview and back to Shifts; Back and '
      'Forward walk it and grey at the ends', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final shell = shellOf(tester);
    expect(keyEnabled(tester, WorkShellWords.back), isFalse);
    expect(keyEnabled(tester, WorkShellWords.forward), isFalse);

    await click(tester, treeNode('Work'));
    await settleSheet(tester);
    expect(shell.location, const WorkLocation.overview());
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DataGrid && widget.label == 'Employments',
      ),
      findsOneWidget,
    );
    expect(keyEnabled(tester, WorkShellWords.back), isTrue);

    await click(tester, treeNode('Shifts'));
    await settleSheet(tester);
    expect(shell.location.month, _october);
    expect(shiftsGrid, findsOneWidget);

    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(shell.location, const WorkLocation.overview());
    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(shell.location.month, _october);
    expect(keyEnabled(tester, WorkShellWords.back), isFalse);
    expect(keyEnabled(tester, WorkShellWords.forward), isTrue);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Next month shows November; Back returns to October', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    expect(shellOf(tester).location.month, _november);
    expect(find.text('November 2026'), findsWidgets);
    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(shellOf(tester).location.month, _october);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("the Details box shows the employment's terms and month", (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    final box = find.byType(DetailsBox);
    expect(
      find.descendant(of: box, matching: find.text('EUR 18.40/h gross')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: box, matching: find.text('October 2026')),
      findsOneWidget,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Help › Licences shows the licences page and Back returns', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await selectShiftsRow(tester, plannedRowId(const LocalDate(2026, 10, 5)));
    final before = shellOf(tester).location;
    await click(tester, find.text('Help'));
    await settleSheet(tester);
    await click(tester, find.text('Licences'));
    await settleSheet(tester);
    expect(find.byType(LicencesPage), findsOneWidget);
    expect(shellOf(tester).location, const WorkLocation.licences());
    await click(
      tester,
      find.descendant(of: find.byType(LicencesPage), matching: pushKey('Back')),
    );
    await settleSheet(tester);
    expect(find.byType(LicencesPage), findsNothing);
    expect(shellOf(tester).location, before);
    expect(sheetOf(tester).selectedId, before.rowId);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("the hidden sheet's commands rest while Licences shows", (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, find.text('Help'));
    await settleSheet(tester);
    await click(tester, find.text('Licences'));
    await settleSheet(tester);
    for (final key in ['New shift', 'Save', 'Undo', 'Correct…']) {
      expect(toolbarKey(key), findsNothing, reason: key);
    }
    final menus = tester.widget<AppFrame>(find.byType(AppFrame)).menus;
    for (final label in ['Edit', 'Record']) {
      final items = menus
          .singleWhere((menu) => menu.label == label)
          .items
          .where((item) => !item.separator);
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.onSelected, isNull, reason: '$label › ${item.label}');
        expect(item.disabledReason, WorkMenuWords.onLicences);
      }
    }
    await click(tester, toolbarKey('Add'));
    await settleSheet(tester);
    expect(find.text('Manual shift'), findsNothing);
    await press(tester, LogicalKeyboardKey.escape);
    await settleSheet(tester);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('without a native close API File Quit is greyed', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final file = tester
        .widget<AppFrame>(find.byType(AppFrame))
        .menus
        .singleWhere((menu) => menu.label == 'File');
    expect(
      file.items.singleWhere((item) => item.label == 'Quit').onSelected,
      isNull,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the other areas are greyed and say why', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final areas = tester.widget<TabStrip>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TabStrip && widget.tabs.any((tab) => tab.id == 'finance'),
      ),
    );
    expect(
      [for (final tab in areas.tabs) tab.label],
      ['Work', 'Finance', 'Tracking', 'Knowledge'],
    );
    for (final tab in areas.tabs.skip(1)) {
      expect(tab.enabled, isFalse);
      expect(tab.disabledReason, 'Not built yet');
    }
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a greyed row of the menu bar says why', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, find.text('Tools'));
    await settleSheet(tester);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message == WorkMenuWords.noOptions,
      ),
      findsOneWidget,
    );
    await press(tester, LogicalKeyboardKey.escape);
    await settleSheet(tester);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the status bar warns of days to confirm', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    expect(find.text('9 days to confirm'), findsOneWidget);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('clicking an ended employment opens it', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    late EmploymentId cafe;
    await tester.runAsync(() async {
      final made = await fixture.work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Synthetic cafe', legalLabel: null),
      );
      final employment = (made as Committed<Employment>).value;
      cafe = employment.id;
      await fixture.work.employment.archiveEmployment(
        ArchiveEmploymentCommand(
          employmentId: cafe,
          expectedRevision: employment.revision,
        ),
      );
    });
    await settleSheet(tester);
    expect(treeNode('Ended employments'), findsOneWidget);
    await click(tester, find.byKey(const ValueKey('tree-box:ended')));
    await settleSheet(tester);
    await click(tester, treeNode('Synthetic cafe'));
    await settleSheet(tester);
    expect(shellOf(tester).location, WorkLocation.employment(cafe));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Pay periods and Payslips are live tree nodes', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    for (final (label, kind) in [
      ('Pay periods', WorkSheetKind.periods),
      ('Payslips', WorkSheetKind.payslips),
    ]) {
      await click(tester, treeNode(label));
      await settleSheet(tester);
      expect(shellOf(tester).location.sheet, kind);
      expect(shellOf(tester).paySheet, isNotNull);
    }
    await closeShiftsSheet(tester, fixture);
  });

  test('a command that throws is reported, not lost', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final editors = EditorSessionController();
    addTearDown(editors.dispose);
    runCommand(editors, () async => throw StateError('x'));
    await Future<void>.delayed(Duration.zero);
    expect(reported.single.library, 'work shell');
    expect(reported.single.exception, isA<StateError>());
  });

  test('a refused flush runs no command', () {
    final editors = EditorSessionController();
    addTearDown(editors.dispose);
    editors.begin(
      EditField(
        id: const EditIdentity(record: 'r', field: 'f'),
        kind: ValueKind.text,
        value: 'a',
        commit: (_, _) => const EditResult.rejected('No.'),
      ),
      host: Object(),
    );
    editors.update(const EditIdentity(record: 'r', field: 'f'), 'b');
    var ran = false;
    runCommand(editors, () async => ran = true);
    expect(ran, isFalse);
  });

  testWidgets('a restored shift that is gone says so until the sheet has '
      'something to say', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.shifts(fixtureEmployment, month: _october, shift: ShiftId('0190f5d2-6a00-7000-8000-00000000beef')).toUri()}',
      ),
    );
    expect(statusNotice(tester), WorkShellNotices.recordGone);
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    await stepGridTime(tester, newRowId, 'end', 'up');
    expect(statusNotice(tester), startsWith('New shift: '));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Replaced by opens the replacement in its own month; Back '
      'returns to the original', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    late WorkShift original;
    late WorkShift replacement;
    await tester.runAsync(() async {
      (original, replacement) = await fixture.correctIntoNovember(20);
    });
    await settleSheet(tester);
    await selectShiftsRow(tester, storedRowId(original));
    await click(tester, propertyValue('replacedBy'));
    await settleSheet(tester);
    final shell = shellOf(tester);
    expect(shell.location.month, _november);
    expect(shell.location.shift, replacement.id);
    expect(sheetOf(tester).selectedId, storedRowId(replacement));
    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(shell.location.month, _october);
    expect(sheetOf(tester).selectedId, storedRowId(original));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Back with a pending planned-day change saves it first', (
    tester,
  ) async {
    final events = <String>[];
    final fixture = await pumpShiftsSheet(
      tester,
      work: (fixture) => observedWork(fixture, events),
    );
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    await click(tester, stepKey(ShiftsFilterWords.previous));
    await settleSheet(tester);
    final day = plannedRowId(const LocalDate(2026, 10, 5));
    await selectShiftsRow(tester, day);
    await stepGridTime(tester, day, 'end', 'down');
    shellOf(tester).addListener(() {
      if (shellOf(tester).location.month == _november) events.add('move');
    });
    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(shellOf(tester).location.month, _november);
    late int changes;
    await tester.runAsync(() async {
      changes = (await fixture.work.plans.repository.planInputs(
        fixtureEmployment,
      )).exceptions.length;
    });
    expect(changes, 1);
    expect(events.take(2), ['commit', 'move']);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a tree node saves a pending planned-day change before it '
      'moves', (tester) async {
    final events = <String>[];
    final fixture = await pumpShiftsSheet(
      tester,
      work: (fixture) => observedWork(fixture, events),
    );
    final day = plannedRowId(const LocalDate(2026, 10, 5));
    await selectShiftsRow(tester, day);
    await stepGridTime(tester, day, 'end', 'down');
    shellOf(tester).addListener(() {
      if (shellOf(tester).location == const WorkLocation.overview()) {
        events.add('move');
      }
    });
    await click(tester, treeNode('Work'));
    await settleSheet(tester);
    expect(shellOf(tester).location, const WorkLocation.overview());
    late int changes;
    await tester.runAsync(() async {
      changes = (await fixture.work.plans.repository.planInputs(
        fixtureEmployment,
      )).exceptions.length;
    });
    expect(changes, 1);
    expect(events.take(2), ['commit', 'move']);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the employment node opens the employment', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, treeNode('Synthetic depot'));
    await settleSheet(tester);
    final place = shellOf(tester).location;
    expect(place, WorkLocation.employment(fixtureEmployment));
    expect(
      tester.widget<TreeView>(find.byType(TreeView)).selectedId,
      treeIdOf(place),
    );
    expect(treeIdOf(place), 'employment:${fixtureEmployment.value}');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Back and Forward are green with a place to go and grey '
      'without', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    OrbTone toneOf(String label) =>
        (tester
                    .widget<BandedToolbar>(find.byType(BandedToolbar))
                    .bands
                    .expand((band) => band.items)
                    .firstWhere((item) => item.label == label)
                    .leading!
                as Orb)
            .tone;
    expect(toneOf(WorkShellWords.back), OrbTone.grey);
    expect(toneOf(WorkShellWords.forward), OrbTone.grey);
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    expect(toneOf(WorkShellWords.back), OrbTone.green);
    expect(toneOf(WorkShellWords.forward), OrbTone.grey);
    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(toneOf(WorkShellWords.back), OrbTone.grey);
    expect(toneOf(WorkShellWords.forward), OrbTone.green);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the window title follows the place', (tester) async {
    final titles = <String>[];
    await pumpShiftsSheet(tester, onTitle: titles.add);
    expect(titles, ['Shifts - LifeOS']);
    final name = shellOf(tester).employment(fixtureEmployment)!.employment.name;

    await click(tester, treeNode('Work'));
    await settleSheet(tester);
    await click(tester, treeNode(name));
    await settleSheet(tester);
    await click(tester, find.text('Help'));
    await click(tester, find.text('Licences'));
    await settleSheet(tester);
    expect(titles, [
      'Shifts - LifeOS',
      'Work - LifeOS',
      '$name - LifeOS',
      'Licences - LifeOS',
    ]);
  });

  testWidgets('the mouse back and forward buttons travel the history', (
    tester,
  ) async {
    await pumpShiftsSheet(tester);
    final shell = shellOf(tester);
    await click(tester, treeNode('Work'));
    await settleSheet(tester);

    await mouseButton(tester, kBackMouseButton);
    expect(shell.location.month, _october);
    expect(shell.location.sheet, WorkSheetKind.shifts);

    await mouseButton(tester, kForwardMouseButton);
    expect(shell.location, const WorkLocation.overview());
  });

  testWidgets('the mouse back button over an invalid edit stays on the '
      'problem', (tester) async {
    await pumpShiftsSheet(tester);
    final shell = shellOf(tester);
    await click(tester, treeNode('Work'));
    await settleSheet(tester);
    await click(tester, find.text('File'));
    await click(tester, find.text(WorkShellWords.newEmployment));
    await settleSheet(tester);
    await typeProperty(tester, EmploymentField.legalLabel, 'UAB Synthetic');

    await mouseButton(tester, kBackMouseButton);
    expect(find.byType(ConfirmWindow), findsNothing);
    expect(statusNotice(tester), EditProblems.invalid);
    expect(shell.location, const WorkLocation.overview());
    expect(shell.canForward, isFalse);
    expect(
      shell.employmentsSheet?.employment?.draft.legalLabel,
      'UAB Synthetic',
    );
  });
}

/// Presses and releases the mouse's [button] over the status bar.
Future<void> mouseButton(WidgetTester tester, int button) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(StatusBar)),
    kind: PointerDeviceKind.mouse,
    buttons: button,
  );
  await gesture.up();
  await settleSheet(tester);
}
