import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';

void main() {
  testWidgets('shows the provider-backed native Work workbench', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: '/work');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _EmptyWorkQueryRepository(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Books'), findsOneWidget);
    expect(find.bySemanticsLabel('Work register'), findsOneWidget);
    expect(find.bySemanticsLabel('Record inspector'), findsOneWidget);
    expect(find.text('Create an employment to begin.'), findsOneWidget);
    expect(find.text('Work records will appear here.'), findsNothing);
    expect(find.text('Flutter Demo'), findsNothing);
  });
}

final class _EmptyWorkQueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);

  @override
  Stream<ShiftRecordProjection?> watchActiveShift() => Stream.value(null);
}
