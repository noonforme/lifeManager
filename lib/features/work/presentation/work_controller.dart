import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../application/work_commands.dart';
import '../application/work_query_service.dart';
import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/ids.dart';
import '../domain/shift.dart';
import 'employment_agreement_forms.dart';
import 'shift_forms.dart';
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

typedef StartShift = Future<MutationOutcome<WorkShift>> Function(
  StartShiftCommand command,
);
typedef StartBreak = Future<MutationOutcome<WorkShift>> Function(
  StartBreakCommand command,
);
typedef EndBreak = Future<MutationOutcome<WorkShift>> Function(
  EndBreakCommand command,
);
typedef EndShift = Future<MutationOutcome<WorkShift>> Function(
  EndShiftCommand command,
);
typedef FinalizeShift = Future<MutationOutcome<WorkShift>> Function(
  FinalizeShiftCommand command,
);
typedef SaveManualShift = Future<MutationOutcome<WorkShift>> Function(
  CreateManualShiftCommand command,
);
typedef ReplaceWorkRoute = void Function(WorkRouteState route);

final startShiftProvider = Provider<StartShift>(
  (ref) => throw StateError('StartShift has not been provided.'),
);
final startBreakProvider = Provider<StartBreak>(
  (ref) => throw StateError('StartBreak has not been provided.'),
);
final endBreakProvider = Provider<EndBreak>(
  (ref) => throw StateError('EndBreak has not been provided.'),
);
final endShiftProvider = Provider<EndShift>(
  (ref) => throw StateError('EndShift has not been provided.'),
);
final finalizeShiftProvider = Provider<FinalizeShift>(
  (ref) => throw StateError('FinalizeShift has not been provided.'),
);
final saveManualShiftProvider = Provider<SaveManualShift>(
  (ref) => throw StateError('SaveManualShift has not been provided.'),
);
final replaceWorkRouteProvider = Provider<ReplaceWorkRoute>((ref) => (_) {});

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

  Future<MutationOutcome<WorkShift>> startShift({
    required EmploymentId employmentId,
    required String timezoneId,
    String? note,
  }) => _replaceRouteOnCommit(
    ref.read(startShiftProvider)(
      StartShiftCommand(
        employmentId: employmentId,
        timezoneId: timezoneId.trim(),
        note: _trimOptional(note),
      ),
    ),
  );

  Future<MutationOutcome<WorkShift>> startBreak(WorkShift shift) =>
      _replaceRouteOnCommit(
        ref.read(startBreakProvider)(
          StartBreakCommand(
            shiftId: shift.id,
            expectedShiftRevision: shift.revision,
          ),
        ),
      );

  Future<MutationOutcome<WorkShift>> endBreak(
    WorkShift shift,
    ShiftBreak value,
  ) => _replaceRouteOnCommit(
    ref.read(endBreakProvider)(
      EndBreakCommand(
        shiftId: shift.id,
        breakId: value.id,
        expectedShiftRevision: shift.revision,
        expectedBreakRevision: value.revision,
      ),
    ),
  );

  Future<MutationOutcome<WorkShift>> endShift(WorkShift shift) =>
      _replaceRouteOnCommit(
        ref.read(endShiftProvider)(
          EndShiftCommand(id: shift.id, expectedRevision: shift.revision),
        ),
      );

  Future<MutationOutcome<WorkShift>> finalizeShift(
    WorkShift shift, {
    required int overtimeMinutes,
  }) => _replaceRouteOnCommit(
    ref.read(finalizeShiftProvider)(
      FinalizeShiftCommand(
        id: shift.id,
        overtimeMinutes: overtimeMinutes,
        expectedRevision: shift.revision,
      ),
    ),
  );

  Future<MutationOutcome<WorkShift>> saveManualShift(ManualShiftDraft value) {
    draft = value;
    return _replaceRouteOnCommit(
      ref.read(saveManualShiftProvider)(
        CreateManualShiftCommand(
          employmentId: value.employmentId,
          localStartDate: value.localStartDate,
          localStartTime: value.localStartTime,
          localEndDate: value.localEndDate,
          localEndTime: value.localEndTime,
          timezoneId: value.timezoneId.trim(),
          startFold: value.startFold,
          endFold: value.endFold,
          breaks: [
            for (final item in value.breaks)
              ManualShiftBreak(
                localStartDate: item.startDate,
                localStartTime: item.start,
                localEndDate: item.endDate,
                localEndTime: item.end,
                startFold: null,
                endFold: null,
              ),
          ],
          overtimeMinutes: value.overtimeMinutes,
          note: _trimOptional(value.note),
        ),
      ),
    );
  }

  Future<MutationOutcome<WorkShift>> _replaceRouteOnCommit(
    Future<MutationOutcome<WorkShift>> pending,
  ) async {
    final outcome = await pending;
    if (outcome case Committed<WorkShift>(:final value)) {
      ref.read(replaceWorkRouteProvider)(routeForCommittedShift(value));
    }
    return outcome;
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
