import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../application/work_commands.dart';
import '../application/work_query_service.dart';
import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import 'employment_agreement_forms.dart';
import 'work_route_state.dart';

final workQueryRepositoryProvider = Provider<WorkQueryRepository>(
  (ref) => throw StateError('WorkQueryRepository has not been provided.'),
);

typedef CreateEmployment = Future<MutationOutcome<Employment>> Function(
  CreateEmploymentCommand command,
);
typedef CreateAgreement = Future<MutationOutcome<PayAgreement>> Function(
  CreateAgreementCommand command,
);

final createEmploymentProvider = Provider<CreateEmployment>(
  (ref) => throw StateError('CreateEmployment has not been provided.'),
);

final createAgreementProvider = Provider<CreateAgreement>(
  (ref) => throw StateError('CreateAgreement has not been provided.'),
);

final workRouteProvider = Provider<WorkRouteParseResult>(
  (ref) => const ValidWorkRoute(
    WorkRouteState(
      employmentId: null,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
    ),
  ),
);

final workControllerProvider =
    AsyncNotifierProvider.autoDispose<WorkController, WorkViewState>(
      WorkController.new,
    );

sealed class WorkViewState {
  const WorkViewState();
}

final class WorkReady extends WorkViewState {
  const WorkReady({
    required this.register,
    required this.route,
    required this.inspector,
  });

  final WorkRegisterProjection register;
  final WorkRouteState route;
  final WorkInspectorState inspector;
}

final class WorkInvalidScope extends WorkViewState {
  const WorkInvalidScope(this.problem);

  final WorkRouteProblem problem;
}

sealed class WorkInspectorState {
  const WorkInspectorState();
}

final class WorkInspectorEmpty extends WorkInspectorState {
  const WorkInspectorEmpty();
}

final class WorkInspectorRecord extends WorkInspectorState {
  const WorkInspectorRecord(this.record);

  final WorkRecordProjection record;
}

final class WorkInspectorUnavailable extends WorkInspectorState {
  const WorkInspectorUnavailable();
}

final class WorkController extends AsyncNotifier<WorkViewState> {
  Object? draft;

  Future<MutationOutcome<Employment>> submitEmployment(EmploymentDraft value) {
    draft = value;
    return ref.read(createEmploymentProvider)(
      CreateEmploymentCommand(
        name: value.name.trim(),
        legalLabel: _trimOptional(value.legalLabel),
      ),
    );
  }

  Future<MutationOutcome<PayAgreement>> submitAgreement(AgreementDraft value) {
    draft = value;
    return ref.read(createAgreementProvider)(
      CreateAgreementCommand(
        employmentId: value.employmentId,
        version: 1,
        effectiveStart: value.effectiveStart,
        effectiveEnd: value.effectiveEnd,
        hourlyRateMicroEur: value.hourlyRateMicroEur,
        basis: value.basis,
        overtimeThresholdMinutes: value.overtimeThresholdMinutes,
        overtimeMultiplierNumerator: value.multiplierNumerator,
        overtimeMultiplierDenominator: value.multiplierDenominator,
        label: _trimOptional(value.label),
        note: _trimOptional(value.note),
      ),
    );
  }

  @override
  Future<WorkViewState> build() async {
    final parsed = ref.watch(workRouteProvider);
    if (parsed case InvalidWorkRoute(:final reason)) {
      return WorkInvalidScope(reason);
    }
    final route = (parsed as ValidWorkRoute).state;
    final repository = ref.watch(workQueryRepositoryProvider);
    final register = await repository
        .watchRegister(
          WorkScope(employmentId: route.employmentId, temporal: route.scope),
        )
        .first;
    final recordRef = route.record;
    final WorkInspectorState inspector;
    if (recordRef == null) {
      inspector = const WorkInspectorEmpty();
    } else {
      final record = await repository.watchRecord(recordRef.id).first;
      inspector = record == null
          ? const WorkInspectorUnavailable()
          : WorkInspectorRecord(record);
    }
    return WorkReady(register: register, route: route, inspector: inspector);
  }
}

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
