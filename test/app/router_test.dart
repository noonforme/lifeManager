import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/daos/shift_dao.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';

void main() {
  test(
    'invalid record UUID remains unavailable instead of selecting a row',
    () {
      final result = parseWorkRoute(Uri.parse('/work?record=shift:not-a-uuid'));

      expect(result, isA<InvalidWorkRoute>());
      expect((result as InvalidWorkRoute).reason, WorkRouteProblem.malformedId);
    },
  );

  test('serializes only safe structural Work route state', () {
    final uri = workRouteUri(
      WorkRouteState(
        employmentId: _employmentId,
        scope: null,
        record: const WorkRecordRef(kind: WorkRecordKind.shift, id: _shiftId),
        mode: WorkInspectorMode.inspect,
      ),
    );

    expect(
      uri.toString(),
      '/work?employment=${_employmentId.value}'
      '&record=shift:${_shiftId.value}&mode=inspect',
    );
  });

  test('route parser rejects malformed and conflicting temporal scopes', () {
    expect(
      parseWorkRoute(Uri.parse('/work?period=not-a-uuid')),
      isA<InvalidWorkRoute>().having(
        (value) => value.reason,
        'reason',
        WorkRouteProblem.malformedScope,
      ),
    );
    expect(
      parseWorkRoute(
        Uri.parse(
          '/work?period=018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51'
          '&from=2026-09-01&to=2026-09-30',
        ),
      ),
      isA<InvalidWorkRoute>().having(
        (value) => value.reason,
        'reason',
        WorkRouteProblem.malformedScope,
      ),
    );
  });

  testWidgets('valid Work route renders the provider-backed workbench', (
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

    expect(find.bySemanticsLabel('System navigation'), findsOneWidget);
    expect(find.bySemanticsLabel('Work register'), findsOneWidget);
    expect(find.bySemanticsLabel('Record inspector'), findsOneWidget);
    expect(find.text('Create an employment to begin.'), findsOneWidget);
    expect(find.text('Work records will appear here.'), findsNothing);
  });

  testWidgets(
    'empty Work primary action opens setup through safe route state',
    (tester) async {
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
            createEmploymentProvider.overrideWithValue(
              (_) async => Committed(_employment),
            ),
          ],
          child: LifeOsApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create employment'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/work?mode=create',
      );
      expect(
        find.text(
          'Create an employment and an agreement before recording paid work.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.bySemanticsLabel('Record inspector'),
          matching: find.text('Create employment'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('employment-name')),
        'Synthetic studio',
      );
      await tester.tap(find.text('Save employment'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Create agreement'), findsOneWidget);
    },
  );

  testWidgets('selecting a Work row writes only safe structural route state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    final repository = _ShiftWorkQueryRepository();
    final initialLocation = '/work?employment=${_employmentId.value}';
    final parsed = parseWorkRoute(Uri.parse(initialLocation));
    expect(parsed, isA<ValidWorkRoute>());
    expect((parsed as ValidWorkRoute).state.employmentId, _employmentId);
    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workQueryRepositoryProvider.overrideWithValue(repository)],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedScopes.single.employmentId, _employmentId);

    await tester.tap(find.text('2026-09-29'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}'
      '&record=shift:${_shiftId.value}&mode=inspect',
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      isNot(contains('Synthetic private note')),
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      isNot(contains('12345')),
    );
  });

  testWidgets('safe top-level navigation remains available from Work', (
    tester,
  ) async {
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

    router.go('/money');
    await tester.pumpAndSettle();

    expect(
      find.text('Money is not available in this release.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid Work date scope is explicit and not replaced', (
    tester,
  ) async {
    final router = createAppRouter(
      initialLocation: '/work?from=2026-09-31&to=2026-10-01',
    );
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Invalid Work scope'), findsOneWidget);
    expect(find.textContaining('today'), findsNothing);
  });

  testWidgets('routes never render unknown query content', (tester) async {
    final router = createAppRouter(
      initialLocation: '/work?note=private-marker&mode=inspect',
    );
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

    expect(find.textContaining('private-marker'), findsNothing);
  });
}

final class _EmptyWorkQueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

final class _ShiftWorkQueryRepository implements WorkQueryRepository {
  final requestedScopes = <WorkScope>[];

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) {
    requestedScopes.add(scope);
    return Stream.value(
      WorkRegisterProjection(
        scope: scope,
        period: null,
        shiftRows: [
          ShiftRegisterRow(
            id: _shiftId,
            localStartDate: '2026-09-29',
            startUtc: DateTime.utc(2026, 9, 29, 8),
            endUtc: DateTime.utc(2026, 9, 29, 16),
            state: ShiftState.finalized,
          ),
        ],
        payslipRows: const [],
        paid: const Money(minorUnits: 12345),
        reconciliation: null,
      ),
    );
  }

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');
final _employment = Employment(
  id: _employmentId,
  name: 'Synthetic studio',
  legalLabel: null,
  status: EmploymentStatus.active,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 10, 1),
  revision: const Revision(0),
);
