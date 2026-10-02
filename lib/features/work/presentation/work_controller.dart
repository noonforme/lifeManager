import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/history/record_events.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../application/work_commands.dart';
import '../application/work_query_service.dart';
import '../application/work_templates.dart';
import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';
import '../domain/payslip.dart';
import '../domain/shift.dart';
import 'employment_agreement_forms.dart';
import 'period_payslip_forms.dart';
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

typedef UpdateEmployment = Future<MutationOutcome<Employment>> Function(
  UpdateEmploymentCommand command,
);
typedef RemoveEmployment = Future<MutationOutcome<Employment>> Function(
  DeleteEmploymentCommand command,
);
typedef UpdateAgreement = Future<MutationOutcome<PayAgreement>> Function(
  UpdateAgreementCommand command,
);

final updateEmploymentProvider = Provider<UpdateEmployment>(
  (ref) => throw StateError('UpdateEmployment has not been provided.'),
);
final deleteEmploymentProvider = Provider<RemoveEmployment>(
  (ref) => throw StateError('DeleteEmployment has not been provided.'),
);
final updateAgreementProvider = Provider<UpdateAgreement>(
  (ref) => throw StateError('UpdateAgreement has not been provided.'),
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
typedef CreatePayPeriod = Future<MutationOutcome<PayPeriod>> Function(
  CreatePayPeriodCommand command,
);
typedef SetPayPeriodState = Future<MutationOutcome<PayPeriod>> Function(
  SetPayPeriodStateCommand command,
);
typedef RecordPayslip = Future<MutationOutcome<Payslip>> Function(
  RecordPayslipCommand command,
);
typedef CorrectPayslip = Future<MutationOutcome<Payslip>> Function(
  CorrectPayslipCommand command,
);
typedef CorrectShift = Future<MutationOutcome<WorkShift>> Function(
  CorrectShiftCommand command,
);
typedef ReviseShiftDraft = Future<MutationOutcome<WorkShift>> Function(
  ReviseShiftDraftCommand command,
);
typedef ReplaceWorkRoute = void Function(WorkRouteState route);
typedef CurrentTimezoneId = String? Function();

/// The operating system's IANA zone, or null when it is unknown. Shifts never
/// start in a guessed zone.
final currentTimezoneIdProvider = Provider<CurrentTimezoneId>(
  (ref) =>
      () => null,
);

final createPayPeriodProvider = Provider<CreatePayPeriod>(
  (ref) => throw StateError('CreatePayPeriod has not been provided.'),
);
final setPayPeriodStateProvider = Provider<SetPayPeriodState>(
  (ref) => throw StateError('SetPayPeriodState has not been provided.'),
);
final recordPayslipProvider = Provider<RecordPayslip>(
  (ref) => throw StateError('RecordPayslip has not been provided.'),
);
final correctPayslipProvider = Provider<CorrectPayslip>(
  (ref) => throw StateError('CorrectPayslip has not been provided.'),
);
final correctShiftProvider = Provider<CorrectShift>(
  (ref) => throw StateError('CorrectShift has not been provided.'),
);

/// Supplies the typed ID for a correction's replacement record.
final nextReplacementShiftIdProvider = Provider<ShiftId Function()>(
  (ref) => throw StateError('Replacement shift IDs have not been provided.'),
);
final nextReplacementPayslipIdProvider = Provider<PayslipId Function()>(
  (ref) => throw StateError('Replacement payslip IDs have not been provided.'),
);

final reviseShiftDraftProvider = Provider<ReviseShiftDraft>(
  (ref) => throw StateError('ReviseShiftDraft has not been provided.'),
);

/// Record history, read for the inspector's History tab.
final recordHistoryProvider = Provider<RecordHistory>(
  (ref) => const _NoHistory(),
);

final class _NoHistory implements RecordHistory {
  const _NoHistory();

  @override
  Stream<List<RecordEvent>> watch(String recordKind, String recordId) =>
      Stream.value(const []);
}

/// One record's events, oldest first.
final recordEventsProvider = StreamProvider.autoDispose
    .family<List<RecordEvent>, WorkRecordRef>(
      (ref, record) => ref
          .watch(recordHistoryProvider)
          .watch(record.kind.name, record.id.value),
    );

/// One employment's records across every date, for desk tiles and
/// templates.
final employmentRegisterProvider = StreamProvider.autoDispose
    .family<WorkRegisterProjection, EmploymentId>(
      (ref, employment) => ref
          .watch(workQueryRepositoryProvider)
          .watchRegister(WorkScope(employmentId: employment, temporal: null)),
    );

/// The records a saved view shows, keyed by its Work route so equal views
/// share one stream.
final workRouteRegisterProvider = StreamProvider.autoDispose
    .family<WorkRegisterProjection, String>((ref, route) {
      final state = switch (parseWorkRoute(Uri.parse(route))) {
        ValidWorkRoute(:final state) => state,
        InvalidWorkRoute() => throw ArgumentError.value(route, 'route'),
      };
      return ref
          .watch(workQueryRepositoryProvider)
          .watchRegister(
            WorkScope(employmentId: state.employmentId, temporal: state.scope),
          );
    });

/// "From last time": the employment's latest finalized shift as a
/// template, computed from the current records; null when there is none.
final lastShiftTemplateProvider = Provider.autoDispose
    .family<AsyncValue<ShiftTemplate?>, EmploymentId>((ref, employment) {
      final zones = ref.watch(timezoneServiceProvider);
      return ref
          .watch(employmentRegisterProvider(employment))
          .whenData(
            (register) => shiftTemplateFromLast([
              for (final row in register.shiftSheet)
                (shift: row.shift, breaks: row.breaks),
            ], zones),
          );
    });

/// Today's local date, the default start of a new agreement.
final todayProvider = Provider<LocalDate Function()>(
  (ref) => () {
    final now = DateTime.now();
    return LocalDate(now.year, now.month, now.day);
  },
);

/// Converts stored UTC facts into wall-clock values for prefilled forms.
final timezoneServiceProvider = Provider<TimezoneService>(
  (ref) => IanaTimezoneService(),
);

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
final replaceWorkRouteProvider = Provider<ReplaceWorkRoute>(
  (ref) => (_) {},
  dependencies: const [],
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
  dependencies: const [],
);

final workRegisterProjectionProvider =
    StreamProvider.autoDispose<WorkRegisterProjection>((ref) {
      final parsed = ref.watch(workRouteProvider);
      if (parsed case InvalidWorkRoute()) {
        return const Stream.empty();
      }
      final route = (parsed as ValidWorkRoute).state;
      return ref
          .watch(workQueryRepositoryProvider)
          .watchRegister(
            WorkScope(employmentId: route.employmentId, temporal: route.scope),
          );
    }, dependencies: [workRouteProvider]);

final workRecordProjectionProvider = StreamProvider.autoDispose
    .family<WorkRecordProjection?, WorkRecordId>(
      (ref, id) => ref.watch(workQueryRepositoryProvider).watchRecord(id),
    );

final workActiveShiftProvider =
    StreamProvider.autoDispose<ShiftRecordProjection?>(
      (ref) => ref.watch(workQueryRepositoryProvider).watchActiveShift(),
    );

final workControllerProvider =
    AsyncNotifierProvider.autoDispose<WorkController, WorkViewState>(
      WorkController.new,
      dependencies: [
        workRouteProvider,
        replaceWorkRouteProvider,
        workRegisterProjectionProvider,
      ],
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

  /// Creates an employment and selects it, so setup continues with its
  /// first agreement.
  Future<MutationOutcome<Employment>> submitEmployment(
    EmploymentDraft value,
  ) async {
    draft = value;
    final outcome = await ref.read(createEmploymentProvider)(
      CreateEmploymentCommand(
        name: value.name.trim(),
        legalLabel: _trimOptional(value.legalLabel),
      ),
    );
    if (outcome case Committed<Employment>(:final value)) {
      ref.read(replaceWorkRouteProvider)(
        WorkRouteState(
          employmentId: value.id,
          scope: null,
          record: null,
          mode: WorkInspectorMode.create,
        ),
      );
    }
    return outcome;
  }

  /// Saves a new agreement. One added from + Add returns to the
  /// employment; during setup the route moves on by itself.
  Future<MutationOutcome<PayAgreement>> submitAgreement(
    AgreementDraft value,
  ) async {
    draft = value;
    final outcome = await ref.read(createAgreementProvider)(
      CreateAgreementCommand(
        employmentId: value.employmentId,
        version: _nextAgreementVersion(),
        terms: value.terms,
      ),
    );
    final parsed = ref.read(workRouteProvider);
    if (outcome is Committed<PayAgreement> &&
        parsed is ValidWorkRoute &&
        parsed.state.adding == WorkAddKind.agreement) {
      _showEmployment(value.employmentId);
    }
    return outcome;
  }

  /// Renames an employment and returns to its header.
  Future<MutationOutcome<Employment>> updateEmployment(
    Employment current,
    EmploymentDraft value,
  ) async {
    draft = value;
    final outcome = await ref.read(updateEmploymentProvider)(
      UpdateEmploymentCommand(
        employmentId: current.id,
        expectedRevision: current.revision,
        name: value.name.trim(),
        legalLabel: _trimOptional(value.legalLabel),
      ),
    );
    if (outcome is Committed<Employment>) _showEmployment(current.id);
    return outcome;
  }

  /// Deletes an employment with no history and clears it from the route.
  Future<MutationOutcome<Employment>> deleteEmployment(
    Employment current,
  ) async {
    final outcome = await ref.read(deleteEmploymentProvider)(
      DeleteEmploymentCommand(
        employmentId: current.id,
        expectedRevision: current.revision,
      ),
    );
    if (outcome is Committed<Employment>) {
      ref.read(replaceWorkRouteProvider)(
        const WorkRouteState(
          employmentId: null,
          scope: null,
          record: null,
          mode: WorkInspectorMode.inspect,
        ),
      );
    }
    return outcome;
  }

  /// Rewrites an unused agreement and returns to the employment header.
  Future<MutationOutcome<PayAgreement>> updateAgreement(
    PayAgreement current,
    AgreementDraft value,
  ) async {
    draft = value;
    final outcome = await ref.read(updateAgreementProvider)(
      UpdateAgreementCommand(
        agreementId: current.id,
        employmentId: current.employmentId,
        expectedRevision: current.revision,
        terms: value.terms,
      ),
    );
    if (outcome is Committed<PayAgreement>) {
      _showEmployment(current.employmentId);
    }
    return outcome;
  }

  /// One past the highest version the selected employment has.
  int _nextAgreementVersion() {
    final ready = state.value;
    if (ready is! WorkReady) return 1;
    return ready.register.agreementSheet.fold(
          0,
          (highest, row) =>
              row.agreement.version > highest ? row.agreement.version : highest,
        ) +
        1;
  }

  void _showEmployment(EmploymentId id) => ref.read(replaceWorkRouteProvider)(
    WorkRouteState(
      employmentId: id,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
    ),
  );

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

  Future<MutationOutcome<WorkShift>> startShiftInSystemZone(
    EmploymentId employmentId,
  ) async {
    final zone = ref.read(currentTimezoneIdProvider)();
    if (zone == null) {
      return const Invalid<WorkShift>({
        'timezoneId': [FieldIssue(FieldIssueCode.unavailable)],
      });
    }
    return startShift(employmentId: employmentId, timezoneId: zone);
  }

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

  Future<MutationOutcome<WorkShift>> finalizeShift(WorkShift shift) =>
      _replaceRouteOnCommit(
        ref.read(finalizeShiftProvider)(
          FinalizeShiftCommand(id: shift.id, expectedRevision: shift.revision),
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
          note: _trimOptional(value.note),
        ),
      ),
    );
  }

  /// Revises a draft shift (such as a correction's replacement) and selects
  /// the finalized result for inspection.
  Future<MutationOutcome<WorkShift>> reviseDraftShift(
    WorkShift draftShift,
    ManualShiftDraft value,
  ) {
    draft = value;
    return _replaceRouteOnCommit(
      ref.read(reviseShiftDraftProvider)(
        ReviseShiftDraftCommand(
          id: draftShift.id,
          expectedRevision: draftShift.revision,
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
          note: _trimOptional(value.note),
        ),
      ),
    );
  }

  Future<MutationOutcome<PayPeriod>> createPayPeriod(PayPeriodDraft value) {
    draft = value;
    return _replacePayPeriodRouteOnCommit(
      ref.read(createPayPeriodProvider)(
        CreatePayPeriodCommand(
          employmentId: value.employmentId,
          start: value.start,
          end: value.end,
          label: _trimOptional(value.label),
        ),
      ),
    );
  }

  Future<MutationOutcome<PayPeriod>> setPayPeriodState(
    PayPeriod period,
    PayPeriodState state,
  ) => _replacePayPeriodRouteOnCommit(
    ref.read(setPayPeriodStateProvider)(
      SetPayPeriodStateCommand(
        id: period.id,
        state: state,
        expectedRevision: period.revision,
      ),
    ),
  );

  Future<MutationOutcome<Payslip>> recordPayslip(PayslipDraft value) {
    draft = value;
    return _replacePayslipRouteOnCommit(
      ref.read(recordPayslipProvider)(
        RecordPayslipCommand(
          periodId: value.periodId,
          issuedDate: value.issuedDate,
          paidDate: value.paidDate,
          amountMinorUnits: value.amountMinorUnits,
          basis: value.basis,
          grossMinorUnits: value.grossMinorUnits,
          netMinorUnits: value.netMinorUnits,
          deductionMinorUnits: value.deductionMinorUnits,
          reference: _trimOptional(value.reference),
          note: _trimOptional(value.note),
        ),
      ),
    );
  }

  Future<MutationOutcome<Payslip>> correctPayslip(
    Payslip original, {
    required PayslipId replacementId,
    required String voidReason,
  }) => _replacePayslipRouteOnCommit(
    ref.read(correctPayslipProvider)(
      CorrectPayslipCommand(
        originalId: original.id,
        replacementId: replacementId,
        expectedRevision: original.revision,
        voidReason: voidReason.trim(),
      ),
    ),
  );

  Future<MutationOutcome<WorkShift>> correctShift(
    WorkShift original, {
    required ShiftId replacementId,
    required String voidReason,
  }) => _replaceRouteOnCommit(
    ref.read(correctShiftProvider)(
      CorrectShiftCommand(
        originalId: original.id,
        replacementId: replacementId,
        expectedRevision: original.revision,
        voidReason: voidReason.trim(),
      ),
    ),
    mode: WorkInspectorMode.edit,
  );

  Future<MutationOutcome<WorkShift>> correctShiftWithReason(
    WorkShift original,
    String reason,
  ) => correctShift(
    original,
    replacementId: ref.read(nextReplacementShiftIdProvider)(),
    voidReason: reason,
  );

  Future<MutationOutcome<Payslip>> correctPayslipWithReason(
    Payslip original,
    String reason,
  ) => correctPayslip(
    original,
    replacementId: ref.read(nextReplacementPayslipIdProvider)(),
    voidReason: reason,
  );

  Future<MutationOutcome<PayPeriod>> _replacePayPeriodRouteOnCommit(
    Future<MutationOutcome<PayPeriod>> pending,
  ) async {
    final outcome = await pending;
    if (outcome case Committed<PayPeriod>(:final value)) {
      ref.read(replaceWorkRouteProvider)(routeForCommittedPayPeriod(value));
    }
    return outcome;
  }

  Future<MutationOutcome<Payslip>> _replacePayslipRouteOnCommit(
    Future<MutationOutcome<Payslip>> pending,
  ) async {
    final outcome = await pending;
    if (outcome case Committed<Payslip>(:final value)) {
      final parsed = ref.read(workRouteProvider);
      final employmentId = switch (parsed) {
        ValidWorkRoute(:final state) => state.employmentId,
        InvalidWorkRoute() => null,
      };
      ref.read(replaceWorkRouteProvider)(
        routeForCommittedPayslip(value, employmentId: employmentId),
      );
    }
    return outcome;
  }

  Future<MutationOutcome<WorkShift>> _replaceRouteOnCommit(
    Future<MutationOutcome<WorkShift>> pending, {
    WorkInspectorMode mode = WorkInspectorMode.inspect,
  }) async {
    final outcome = await pending;
    if (outcome case Committed<WorkShift>(:final value)) {
      ref.read(replaceWorkRouteProvider)(
        routeForCommittedShift(value, mode: mode),
      );
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
    final unselected =
        route.record == null &&
        route.scope == null &&
        route.mode == WorkInspectorMode.inspect &&
        route.adding == null;
    var restoring = false;
    if (unselected) {
      final active = await _valueOf(
        ref.watch(workActiveShiftProvider),
        ref.watch(workActiveShiftProvider.future),
      );
      if (active != null &&
          (route.employmentId == null ||
              route.employmentId == active.shift.employmentId)) {
        restoring = true;
        final restored = routeForCommittedShift(active.shift);
        final replace = ref.read(replaceWorkRouteProvider);
        unawaited(
          Future.microtask(() {
            if (ref.mounted) replace(restored);
          }),
        );
      }
    }
    final register = await _valueOf(
      ref.watch(workRegisterProjectionProvider),
      ref.watch(workRegisterProjectionProvider.future),
    );
    // Reopen the only employment instead of restarting setup.
    if (unselected &&
        !restoring &&
        route.employmentId == null &&
        register.availableEmployments.length == 1) {
      final reopened = WorkRouteState(
        employmentId: register.availableEmployments.single.id,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
      );
      final replace = ref.read(replaceWorkRouteProvider);
      unawaited(
        Future.microtask(() {
          if (ref.mounted) replace(reopened);
        }),
      );
    }
    final recordRef = route.record;
    final WorkInspectorState inspector;
    if (recordRef == null) {
      inspector = const WorkInspectorEmpty();
    } else {
      final recordProvider = workRecordProjectionProvider(recordRef.id);
      final record = await _valueOf(
        ref.watch(recordProvider),
        ref.watch(recordProvider.future),
      );
      inspector = record == null
          ? const WorkInspectorUnavailable()
          : WorkInspectorRecord(record);
    }
    return WorkReady(register: register, route: route, inspector: inspector);
  }
}

Future<T> _valueOf<T>(AsyncValue<T> value, Future<T> loading) =>
    switch (value) {
      AsyncData(:final value) => Future.value(value),
      AsyncError(:final error, :final stackTrace) => Future.error(
        error,
        stackTrace,
      ),
      AsyncLoading() => loading,
    };

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
