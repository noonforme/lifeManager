import 'package:flutter_test/flutter_test.dart';

import '../../../support/scheduled_app.dart';

void main() {
  Future<void> expectLink(
    WidgetTester tester,
    String sheet, {
    required bool present,
  }) async {
    await pumpScheduledApp(
      tester,
      location: '/work?employment={employment}&sheet=$sheet',
    );
    expect(
      find.text('Save this view…'),
      present ? findsOneWidget : findsNothing,
      reason: sheet,
    );
  }

  testWidgets('Save this view is left out on Calendar', (tester) async {
    await expectLink(tester, 'calendar', present: false);
  });

  testWidgets('Save this view is left out on Schedules', (tester) async {
    await expectLink(tester, 'schedules', present: false);
  });

  testWidgets('Save this view is offered on Shifts', (tester) async {
    await expectLink(tester, 'shifts', present: true);
  });
}
