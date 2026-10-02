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
      'Formula bar',
      'Books',
      'Desk workspace',
      'Status line',
    ]) {
      expect(find.bySemanticsLabel(landmark), findsOneWidget, reason: landmark);
    }
    // Nothing here is a record, so there is no inspector.
    expect(find.bySemanticsLabel('Record inspector'), findsNothing);
    expect(find.text('File tools are not available yet.'), findsOneWidget);
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.bySemanticsLabel('Books'),
          matching: find.bySemanticsLabel('Backup and export'),
        ),
      ),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('Money and Habits redirect to Finance and Tracking', (
    tester,
  ) async {
    final router = await pumpAt(tester, '/money');
    expect(router.routeInformationProvider.value.uri.path, '/finance');
    expect(
      find.text('Finance is not built yet. It arrives in a later update.'),
      findsOneWidget,
    );

    router.go('/habits');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/tracking');
  });

  testWidgets('unbuilt areas open from the tree as honest sheets', (
    tester,
  ) async {
    final router = await pumpAt(tester, '/work');
    await tester.tap(find.text('Knowledge'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/knowledge');
    expect(
      find.text('Knowledge is not built yet. It arrives in a later update.'),
      findsOneWidget,
    );
  });
}

final class _EmptyRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);

  @override
  Stream<ShiftRecordProjection?> watchActiveShift() => Stream.value(null);
}
