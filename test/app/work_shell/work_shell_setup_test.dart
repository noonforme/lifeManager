import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show
        click,
        liveToolbarKey,
        propertyEditor,
        propertyValue,
        pushKey,
        toolbarKey;
import '../../support/read_gate.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';
import '../../support/work_shell_fixture.dart';

/// The tree node labelled [label].
Finder treeNode(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));

void main() {
  testWidgets('unreadable storage shows the Employments sheet as unreadable, '
      'with nothing to add', (tester) async {
    late EmptyWorkFixture fixture;
    await tester.runAsync(() async {
      fixture = await EmptyWorkFixture.create(
        executor: NativeDatabase.memory().interceptWith(
          ReadGate(failing: true),
        ),
      );
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(fixture.dispose);
    });
    await pumpShellOver(tester, fixture, store: MemoryLocationStore());
    expect(find.text(EmploymentsWords.unreadable), findsOneWidget);
    expect(pushKey(EmploymentsPropertyWords.addEmployment), findsNothing);
    expect(statusNotice(tester), WorkShellNotices.unreadable);
    // Nothing else offers a new employment either (bead 9pk.4.4.1 item 5).
    expect(toolbarKey('New employment'), findsOneWidget);
    expect(liveToolbarKey('New employment'), findsNothing);
    final file = tester
        .widget<AppFrame>(find.byType(AppFrame))
        .menus
        .singleWhere((menu) => menu.label == 'File');
    final item = file.items.singleWhere(
      (item) => item.label == WorkShellWords.newEmployment,
    );
    expect(item.onSelected, isNull);
    expect(item.disabledReason, EmploymentsWords.unreadable);
  });

  testWidgets('Licences waits for an invalid edit; restoring pane sizes '
      'leaves it alone', (tester) async {
    await pumpEmptyShell(tester, store: MemoryLocationStore());
    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    await typeProperty(tester, EmploymentField.legalLabel, 'UAB Synthetic');
    await click(tester, find.text('Help'));
    await settleSheet(tester);
    await click(tester, find.text('Licences'));
    await settleSheet(tester);
    expect(find.byType(LicencesPage), findsNothing);
    expect(shellOf(tester).location, const WorkLocation.overview());
    expect(statusNotice(tester), EditProblems.invalid);
    await click(tester, find.text('Window'));
    await settleSheet(tester);
    await click(tester, find.text('Restore pane sizes'));
    await settleSheet(tester);
    final sheet = shellOf(tester).employmentsSheet!;
    expect(sheet.employment?.draft.legalLabel, 'UAB Synthetic');
  });

  testWidgets('Undo on a new employment keeps the name being typed: the '
      'window asks, and Save stores it', (tester) async {
    final fixture = await pumpEmptyShell(tester, store: MemoryLocationStore());
    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    await click(tester, propertyValue(EmploymentField.name));
    await tester.enterText(
      find.descendant(
        of: propertyEditor(EmploymentField.name),
        matching: find.byType(EditableText),
      ),
      'Synthetic bakery',
    );
    await click(tester, toolbarKey('Undo'));
    await settleSheet(tester);
    final window = find.byWidgetPredicate((widget) => widget is ConfirmWindow);
    await click(tester, find.descendant(of: window, matching: pushKey('Save')));
    await settleSheet(tester);
    final stored = await tester.runAsync(fixture.reads.employments);
    expect(stored!.single.name, 'Synthetic bakery');
  });

  testWidgets('from an empty database: Add employment, Set up pay '
      'agreement, a shift on Shifts; the next start opens it again', (
    tester,
  ) async {
    final store = MemoryLocationStore();
    final fixture = await pumpEmptyShell(tester, store: store);
    final shell = shellOf(tester);
    expect(shell.location, const WorkLocation.overview());
    expect(statusNotice(tester), EmploymentsNotices.empty);

    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    expect(statusNotice(tester), EmploymentsNotices.newEmployment);
    await typeProperty(tester, EmploymentField.name, 'Synthetic bakery');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    final employment = shell.location.employmentId!;
    expect(shell.location, WorkLocation.employment(employment));
    expect(treeNode('Synthetic bakery'), findsOneWidget);
    expect(statusNotice(tester), EmploymentsNotices.noAgreement);

    await click(tester, propertyValue('agreement'));
    await settleSheet(tester);
    expect(statusNotice(tester), EmploymentsNotices.newAgreement);
    await typeProperty(tester, AgreementField.hourlyRate, '18.40');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    // The setup is done: the employment shows again, its agreement a link.
    expect(shell.location, WorkLocation.employment(employment));
    expect(statusNotice(tester), EmploymentsNotices.agreementSaved);
    expect(
      find.textContaining('18.40/h from', findRichText: true),
      findsOneWidget,
      reason: 'the stored rate',
    );

    await click(tester, treeNode('Shifts'));
    await settleSheet(tester);
    expect(
      shell.location,
      WorkLocation.shifts(employment, month: const LocalDate(2026, 10, 1)),
    );
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    await stepGridTime(tester, newRowId, 'end', 'down');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    await click(tester, pushKey('Save and finalize'));
    await settleSheet(tester);
    final saved = shell.location;
    expect(saved.shift, isNotNull);
    expect(sheetOf(tester).selectedId, saved.rowId);

    await tester.runAsync(shell.remember);
    await pumpShellOver(tester, fixture, store: store);
    expect(shellOf(tester).location, saved);
    expect(sheetOf(tester).selectedId, saved.rowId);
  });

  testWidgets('File › New employment… from Shifts goes to the overview and '
      'opens a new employment', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, find.text('File'));
    await settleSheet(tester);
    await click(tester, find.text(WorkShellWords.newEmployment));
    await settleSheet(tester);
    final shell = shellOf(tester);
    expect(shell.location, const WorkLocation.overview());
    expect(shell.employmentsSheet?.employment?.isNew, isTrue);
    await closeShiftsSheet(tester, fixture);
  });
}
