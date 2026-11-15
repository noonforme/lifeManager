import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';

import '../support/app_frame_harness.dart' show click, pushKey, toolbarKey;
import '../support/production_app.dart';
import '../support/shifts_sheet_driver.dart' show settleSheet;
import '../support/work_shell_driver.dart' show typeProperty;
import '../support/work_shell_fixture.dart';

void main() {
  testWidgets('the window title names the place, then LifeOS', (tester) async {
    late EmptyWorkFixture fixture;
    await tester.runAsync(
      () async => fixture = await EmptyWorkFixture.create(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(fixture.dispose);
    });
    final titles = <String>[];
    await pumpProductionApp(
      tester,
      work: fixture.work,
      reads: fixture.reads,
      store: MemoryLocationStore(),
      onTitle: titles.add,
    );
    expect(titles, ['Work - LifeOS']);

    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    await typeProperty(tester, EmploymentField.name, 'Synthetic bakery');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    expect(titles.last, 'Synthetic bakery - LifeOS');
  });
}
