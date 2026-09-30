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
}
