import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  Widget host(Widget child, {double scale = 1}) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 200, height: 600, child: child),
        ),
      ),
    ),
  );

  testWidgets('a group collapses and expands from its header key', (
    tester,
  ) async {
    var added = 0;
    await tester.pumpWidget(
      host(
        TaskPane(
          groups: [
            TaskGroup(
              title: 'Work tasks',
              special: true,
              child: TaskLink(label: 'Add a shift', onPressed: () => added++),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Add a shift'));
    expect(added, 1);
    await tester.tap(find.bySemanticsLabel('Collapse Work tasks'));
    await tester.pump();
    expect(find.text('Add a shift'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Expand Work tasks'));
    await tester.pump();
    expect(find.text('Add a shift'), findsOneWidget);
  });

  testWidgets('long links wrap at 200 % text without overflow', (tester) async {
    await tester.pumpWidget(
      host(
        TaskPane(
          groups: [
            TaskGroup(
              title: 'Synthetic depot with a very long employment name',
              child: TaskLink(
                label: 'Record a payslip for the selected pay period',
                onPressed: () {},
              ),
            ),
          ],
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
