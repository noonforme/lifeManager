import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';

void main() {
  Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: location);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(_EmptyRepository()),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Backup and export renders inside the shell', (tester) async {
    await pumpAt(tester, '/system/files');

    for (final landmark in [
      'Menu bar',
      'Toolbar',
      'Address',
      'Task pane',
      'Desk workspace',
      'Status line',
    ]) {
      expect(find.bySemanticsLabel(landmark), findsOneWidget, reason: landmark);
    }
    // Nothing here is a record, so there is no inspector.
    expect(find.bySemanticsLabel('Record inspector'), findsNothing);
    expect(find.text('File tools are not available yet.'), findsOneWidget);
    // Backup and export lives under File and in the Address bar, not in
    // the task pane (Millennium shell spec 8).
    expect(
      find.descendant(
        of: find.bySemanticsLabel('Address'),
        matching: find.text('Backup and export'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.bySemanticsLabel('Task pane'),
        matching: find.text('Backup and export'),
      ),
      findsNothing,
    );
  });

  testWidgets('Money and Habits redirect to Finance and Tracking', (
    tester,
  ) async {
    final router = await pumpAt(tester, '/money');
    expect(router.routeInformationProvider.value.uri.path, '/finance');
    expect(find.text('Finance is not built yet.'), findsOneWidget);

    router.go('/habits');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/tracking');
  });

  testWidgets('unbuilt areas open from the tree as honest sheets', (
    tester,
  ) async {
    final router = await pumpAt(tester, '/work');
    await tester.tap(find.text('Knowledge (not built yet)'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/knowledge');
    expect(find.text('Knowledge is not built yet.'), findsOneWidget);
  });
}

final class _EmptyRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}
