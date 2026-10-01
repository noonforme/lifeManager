import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/timezone_service.dart';
import '../domain/facts.dart';
import '../domain/shift.dart';
import 'work_commands.dart';

abstract interface class ManualShiftRepository {
  Future<MutationOutcome<WorkShift>> createAndFinalizeManual(
    WorkShift draft,
    List<ShiftBreak> breaks,
  );
}

final class ManualShiftService {
  const ManualShiftService(
    this._repository, {
    required this.idFactory,
    required this.clock,
    required this.timezones,
  });

  final ManualShiftRepository _repository;
  final ShiftIdFactory idFactory;
  final AppClock clock;
  final TimezoneService timezones;

  Future<MutationOutcome<WorkShift>> createAndFinalize(
    CreateManualShiftCommand command,
  ) async {
    try {
      final start = timezones.resolveLocal(
        command.localStartDate,
        command.localStartTime,
        command.timezoneId,
        fold: command.startFold,
      );
      final end = timezones.resolveLocal(
        command.localEndDate,
        command.localEndTime,
        command.timezoneId,
        fold: command.endFold,
      );
      final nowUtc = clock.nowUtc();
      final shiftId = idFactory.shiftId();
      final breaks = <ShiftBreak>[
        for (final value in command.breaks)
          ShiftBreak(
            id: idFactory.shiftBreakId(),
            shiftId: shiftId,
            startUtc: timezones
                .resolveLocal(
                  value.localStartDate,
                  value.localStartTime,
                  command.timezoneId,
                  fold: value.startFold,
                )
                .utc,
            endUtc: timezones
                .resolveLocal(
                  value.localEndDate,
                  value.localEndTime,
                  command.timezoneId,
                  fold: value.endFold,
                )
                .utc,
            createdAtUtc: nowUtc,
            updatedAtUtc: nowUtc,
            revision: const Revision(0),
          ),
      ];
      final draft = WorkShift(
        id: shiftId,
        employmentId: command.employmentId,
        agreementId: null,
        state: ShiftState.draft,
        startUtc: start.utc,
        endUtc: end.utc,
        timezoneId: command.timezoneId,
        localStartDate: command.localStartDate,
        overtimeMinutes: command.overtimeMinutes,
        note: _trimOptional(command.note),
        voidReason: null,
        replacementShiftId: null,
        replacedShiftId: null,
        createdAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
        revision: const Revision(0),
      );
      return await _repository.createAndFinalizeManual(draft, breaks);
    } on AmbiguousLocalTime {
      return const Invalid<WorkShift>({
        'localTime': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on NonexistentLocalTime {
      return const Invalid<WorkShift>({
        'localTime': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on UnknownTimezone {
      return const Invalid<WorkShift>({
        'localTime': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on ArgumentError {
      return const Invalid<WorkShift>({
        'shift': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on DatabaseOpenFailure {
      return const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable);
    }
  }
}

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
