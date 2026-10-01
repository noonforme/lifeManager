import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';

void main() {
  test(
    'controller preserves an invalid scope without substituting today',
    () async {
      final repository = _FakeWorkQueryRepository();
      final container = ProviderContainer(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(repository),
          workRouteProvider.overrideWithValue(
            const InvalidWorkRoute(WorkRouteProblem.malformedScope),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(workControllerProvider.future),
        isA<WorkInvalidScope>(),
      );
      expect(repository.watchedScopes, isEmpty);
    },
  );

  test('controller remains subscribed to register changes', () async {
    final repository = _ReactiveWorkQueryRepository();
    final container = ProviderContainer(
      overrides: [
        workQueryRepositoryProvider.overrideWithValue(repository),
        workRouteProvider.overrideWithValue(
          const ValidWorkRoute(
            WorkRouteState(
              employmentId: _employmentId,
              scope: null,
              record: null,
              mode: WorkInspectorMode.inspect,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repository.close);

    final updated = WorkRegisterProjection.empty(repository.scope);
    final updatedState = Completer<WorkReady>();
    final subscription = container.listen(workControllerProvider, (_, next) {
      if (next case AsyncData(value: final WorkReady value)
          when identical(value.register, updated)) {
        updatedState.complete(value);
      }
    });
    addTearDown(subscription.close);
    repository.add(WorkRegisterProjection.empty(repository.scope));
    await container.read(workControllerProvider.future);

    repository.add(updated);

    expect(
      (await updatedState.future.timeout(const Duration(seconds: 1))).register,
      same(updated),
    );
  });

  test('controller subscribes to explicit scope and selected record', () async {
    final repository = _FakeWorkQueryRepository();
    final route = WorkRouteState(
      employmentId: _employmentId,
      scope: const PayPeriodScope(_periodId),
      record: const WorkRecordRef(kind: WorkRecordKind.payslip, id: _payslipId),
      mode: WorkInspectorMode.inspect,
    );
    final container = ProviderContainer(
      overrides: [
        workQueryRepositoryProvider.overrideWithValue(repository),
        workRouteProvider.overrideWithValue(ValidWorkRoute(route)),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(workControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(workControllerProvider.future);

    expect(repository.watchedScopes.single.employmentId, _employmentId);
    expect(repository.watchedScopes.single.temporal, isA<PayPeriodScope>());
    expect(repository.watchedRecords, [_payslipId]);
    final state = container.read(workControllerProvider).requireValue;
    expect(state, isA<WorkReady>());
    expect((state as WorkReady).inspector, isA<WorkInspectorUnavailable>());
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _payslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');

final class _ReactiveWorkQueryRepository implements WorkQueryRepository {
  final controller = StreamController<WorkRegisterProjection>();
  final scope = const WorkScope(employmentId: _employmentId, temporal: null);

  void add(WorkRegisterProjection value) => controller.add(value);

  Future<void> close() => controller.close();

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      controller.stream;

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);

  @override
  Stream<ShiftRecordProjection?> watchActiveShift() => Stream.value(null);
}

final class _FakeWorkQueryRepository implements WorkQueryRepository {
  final watchedScopes = <WorkScope>[];
  final watchedRecords = <WorkRecordId>[];

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) {
    watchedScopes.add(scope);
    return Stream.value(WorkRegisterProjection.empty(scope));
  }

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) {
    watchedRecords.add(id);
    return Stream.value(null);
  }

  @override
  Stream<ShiftRecordProjection?> watchActiveShift() => Stream.value(null);
}
