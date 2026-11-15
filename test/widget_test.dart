import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/ui/ui.dart';

import 'support/app_frame_harness.dart' show pushKey;
import 'support/production_app.dart';
import 'support/work_shell_fixture.dart';

void main() {
  testWidgets('a fresh install opens the Work overview in the new shell', (
    tester,
  ) async {
    late EmptyWorkFixture fixture;
    await tester.runAsync(
      () async => fixture = await EmptyWorkFixture.create(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(fixture.dispose);
    });
    await pumpProductionApp(
      tester,
      work: fixture.work,
      reads: fixture.reads,
      store: MemoryLocationStore(),
    );

    expect(find.byType(AppFrame), findsOneWidget);
    expect(pushKey(EmploymentsPropertyWords.addEmployment), findsOneWidget);
    final areas = tester.widget<AppFrame>(find.byType(AppFrame)).areas;
    expect(areas.map((tab) => tab.label), [
      'Work',
      'Finance',
      'Tracking',
      'Knowledge',
    ]);
    expect(areas.where((tab) => tab.enabled).map((tab) => tab.label), ['Work']);
  });
}
