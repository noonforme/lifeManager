import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart' show click, pushKey, toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

/// The tree node labelled [label].
Finder treeNode(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));

/// The key labelled [label] in the confirmation window.
Finder windowKey(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is ConfirmWindow),
  matching: pushKey(label),
);

/// The open menu's row labelled [label].
Finder menuRow(String label) =>
    find.descendant(of: find.byType(EraMenuLabel), matching: find.text(label));

void main() {
  testWidgets('deleting the current employment shows the overview; Back to '
      'it falls back with its notice', (tester) async {
    await pumpEmptyShell(tester, store: MemoryLocationStore());
    final shell = shellOf(tester);
    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    await typeProperty(tester, EmploymentField.name, 'Synthetic bakery');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    final employment = shell.location.employmentId!;
    await click(tester, treeNode('Shifts'));
    await settleSheet(tester);
    await click(tester, treeNode('Synthetic bakery'));
    await settleSheet(tester);
    expect(shell.location, WorkLocation.employment(employment));

    await click(tester, find.text('Record'));
    await settleSheet(tester);
    await click(tester, menuRow(EmploymentsPropertyWords.delete));
    await settleSheet(tester);
    await click(tester, windowKey('Delete'));
    await settleSheet(tester);
    expect(shell.location, const WorkLocation.overview());
    expect(statusNotice(tester), EmploymentsCommandWords.deleted);
    expect(treeNode('Synthetic bakery'), findsNothing);

    await click(tester, toolbarKey('Back'));
    await settleSheet(tester);
    expect(shell.location, const WorkLocation.overview());
    expect(statusNotice(tester), WorkShellNotices.employmentGone);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('archiving the current employment moves it into an open '
      'Ended employments folder', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.employment(fixtureEmployment).toUri()}',
      ),
    );
    final shell = shellOf(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settleSheet(tester);
    expect(shell.daysToConfirm, 9);
    await click(tester, find.text('Record'));
    await settleSheet(tester);
    await click(tester, menuRow(EmploymentsPropertyWords.archive));
    await settleSheet(tester);
    final window = tester.widget<ConfirmWindow<Object?>>(
      find.byWidgetPredicate((widget) => widget is ConfirmWindow),
    );
    expect(window.message, endsWith('It still has 9 days to confirm.'));
    await click(tester, windowKey('Archive'));
    await settleSheet(tester);
    expect(shell.location, const WorkLocation.employment(fixtureEmployment));
    expect(statusNotice(tester), EmploymentsCommandWords.archivedDone);
    expect(treeNode('Ended employments'), findsOneWidget);
    expect(treeNode('Synthetic depot'), findsOneWidget);
    final tree = tester.widget<TreeView>(find.byType(TreeView));
    expect(tree.selectedId, 'employment:${fixtureEmployment.value}');
    expect(shell.daysToConfirm, 0);
    expect(tester.widget<StatusBar>(find.byType(StatusBar)).warning, isNull);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('archiving into an Ended folder that is already there and '
      'closed opens it', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.employment(fixtureEmployment).toUri()}',
      ),
    );
    await tester.runAsync(() async {
      final created = await fixture.work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Synthetic cafe', legalLabel: null),
      );
      final cafe = (created as Committed<Employment>).value;
      await fixture.work.employment.archiveEmployment(
        ArchiveEmploymentCommand(
          employmentId: cafe.id,
          expectedRevision: cafe.revision,
        ),
      );
    });
    await settleSheet(tester);
    expect(treeNode('Ended employments'), findsOneWidget);
    expect(treeNode('Synthetic cafe'), findsNothing);
    await click(tester, find.text('Record'));
    await settleSheet(tester);
    await click(tester, menuRow(EmploymentsPropertyWords.archive));
    await settleSheet(tester);
    await click(tester, windowKey('Archive'));
    await settleSheet(tester);
    expect(treeNode('Synthetic depot'), findsOneWidget);
    await closeShiftsSheet(tester, fixture);
  });
}
