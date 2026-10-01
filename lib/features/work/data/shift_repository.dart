import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/outcomes/mutation_outcome.dart';
import '../application/manual_shift_service.dart';
import '../application/shift_lifecycle_service.dart';
import '../domain/agreement.dart';
import '../domain/correction.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/shift.dart';
import 'daos/agreement_dao.dart';
import 'daos/employment_dao.dart';
import 'daos/shift_dao.dart';

final class DriftShiftRepository
    implements ShiftLifecycleRepository, ManualShiftRepository {
  DriftShiftRepository(this._database, {ShiftBreakId Function()? createBreakId})
    : _createBreakId = createBreakId ?? _missingBreakIdFactory,
      _shifts = ShiftDao(_database),
      _agreements = AgreementDao(_database),
      _employments = EmploymentDao(_database);

  final AppDatabase _database;
  final ShiftBreakId Function() _createBreakId;
  final ShiftDao _shifts;
  final AgreementDao _agreements;
  final EmploymentDao _employments;

  Future<int> start(WorkShift shift) async {
    try {
      return await _shifts.insert(shift);
    } on SqliteException catch (error) {
      if (error.extendedResultCode == 2067 || error.resultCode == 19) return 0;
      rethrow;
    }
  }

  @override
  Future<MutationOutcome<WorkShift>> commitStart(WorkShift shift) {
    return _database.transaction(() async {
      final employment = await _employments.byId(shift.employmentId);
      if (employment == null || employment.status != EmploymentStatus.active) {
        return const Invalid<WorkShift>({
          'employmentId': [FieldIssue(FieldIssueCode.unavailable)],
        });
      }
      final resolution = resolveAgreement(
        employmentId: shift.employmentId,
        localStartDate: shift.localStartDate,
        agreements: await _agreements.forEmployment(shift.employmentId),
      );
      if (resolution is! ResolvedAgreement) {
        return const Invalid<WorkShift>({
          'agreement': [FieldIssue(FieldIssueCode.unavailable)],
        });
      }
      if (await start(shift) == 0) {
        return const Invalid<WorkShift>({
          'activeShift': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      return Committed<WorkShift>(shift);
    });
  }

  Future<WorkShift?> activeShift() => _shifts.active();

  Stream<WorkShift?> watchActiveShift() => _shifts.watchActive();

  Future<WorkShift?> shiftById(ShiftId id) => _shifts.byId(id);

  Future<List<ShiftBreak>> breaksFor(ShiftId id) => _shifts.breaksFor(id);

  Future<int> startBreak(ShiftBreak value, {required Revision expectedShift}) {
    return _database.transaction(() async {
      final changed = await _shifts.setOnBreak(
        value.shiftId,
        expectedShift,
        value.startUtc,
      );
      if (changed == 0) return 0;
      await _shifts.insertBreak(value);
      return 1;
    });
  }

  @override
  Future<MutationOutcome<WorkShift>> commitStartBreak(
    ShiftBreak value, {
    required Revision expectedShift,
  }) {
    return _database.transaction(() async {
      final shift = await _shifts.byId(value.shiftId);
      if (shift == null) return const Missing<WorkShift>();
      if (shift.revision != expectedShift) return const Stale<WorkShift>();
      if (shift.state != ShiftState.running) {
        return const Invalid<WorkShift>({
          'break': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      if (await startBreak(value, expectedShift: expectedShift) == 0) {
        return const Stale<WorkShift>();
      }
      return Committed<WorkShift>((await _shifts.byId(value.shiftId))!);
    });
  }

  Future<int> endBreak(
    ShiftBreakId id, {
    required ShiftId shiftId,
    required DateTime endUtc,
    required Revision expectedBreak,
    required Revision expectedShift,
  }) {
    return _database
        .transaction(() async {
          final breakChanged = await _shifts.closeBreak(
            id,
            shiftId: shiftId,
            endUtc: endUtc,
            expected: expectedBreak,
          );
          if (breakChanged == 0) return 0;
          final shiftChanged = await _shifts.setRunning(
            shiftId,
            expectedShift,
            endUtc,
          );
          if (shiftChanged == 0) throw const _StaleBreakEnd();
          return 1;
        })
        .onError<_StaleBreakEnd>((_, _) => 0);
  }

  @override
  Future<MutationOutcome<WorkShift>> commitEndBreak(
    ShiftBreakId id, {
    required ShiftId shiftId,
    required DateTime endUtc,
    required Revision expectedBreak,
    required Revision expectedShift,
  }) {
    return _database.transaction(() async {
      final shift = await _shifts.byId(shiftId);
      if (shift == null) return const Missing<WorkShift>();
      if (shift.revision != expectedShift) return const Stale<WorkShift>();
      if (shift.state != ShiftState.onBreak) {
        return const Invalid<WorkShift>({
          'break': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      final breaks = await _shifts.breaksFor(shiftId);
      ShiftBreak? matching;
      for (final item in breaks) {
        if (item.id == id) {
          matching = item;
          break;
        }
      }
      if (matching == null) return const Missing<WorkShift>();
      if (matching.revision != expectedBreak) return const Stale<WorkShift>();
      if (matching.endUtc != null) {
        return const Invalid<WorkShift>({
          'break': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      if (await endBreak(
            id,
            shiftId: shiftId,
            endUtc: endUtc,
            expectedBreak: expectedBreak,
            expectedShift: expectedShift,
          ) ==
          0) {
        return const Stale<WorkShift>();
      }
      return Committed<WorkShift>((await _shifts.byId(shiftId))!);
    });
  }

  Future<int> endShift(
    ShiftId id, {
    required DateTime endUtc,
    required Revision expected,
  }) => _shifts.endShift(id, endUtc: endUtc, expected: expected);

  @override
  Future<MutationOutcome<WorkShift>> commitEndShift(
    ShiftId id, {
    required DateTime endUtc,
    required Revision expected,
  }) {
    return _database.transaction(() async {
      final shift = await _shifts.byId(id);
      if (shift == null) return const Missing<WorkShift>();
      if (shift.revision != expected) return const Stale<WorkShift>();
      if (shift.state != ShiftState.running) {
        return const Invalid<WorkShift>({
          'break': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      if (!endUtc.isAfter(shift.startUtc)) {
        return const Invalid<WorkShift>({
          'endUtc': [FieldIssue(FieldIssueCode.outOfRange)],
        });
      }
      if (await endShift(id, endUtc: endUtc, expected: expected) == 0) {
        return const Stale<WorkShift>();
      }
      return Committed<WorkShift>((await _shifts.byId(id))!);
    });
  }

  Future<MutationOutcome<WorkShift>> finalizeShift(
    ShiftId id, {
    required Revision expected,
    bool failAfterAgreementLinkForTest = false,
  }) {
    return _database.transaction(() async {
      final shift = await _shifts.byId(id);
      if (shift == null) return const Missing<WorkShift>();
      if (shift.revision != expected) return const Stale<WorkShift>();
      final breaks = await _shifts.breaksFor(id);
      final agreements = await _agreements.forEmployment(shift.employmentId);
      final validation = validateFinalization(
        shift: shift,
        breaks: breaks,
        agreements: agreements,
      );
      final facts = validation.facts;
      if (facts == null) {
        return Invalid<WorkShift>({
          'shift': [
            for (final _ in validation.issues)
              const FieldIssue(FieldIssueCode.invalid),
          ],
        });
      }
      final changed = await _shifts.finalize(facts.shift, expected: expected);
      if (changed == 0) return const Stale<WorkShift>();
      if (failAfterAgreementLinkForTest) {
        throw StateError('Synthetic finalization failure.');
      }
      return Committed<WorkShift>((await _shifts.byId(id))!);
    });
  }

  @override
  Future<MutationOutcome<WorkShift>> commitFinalization(
    ShiftId id, {
    required int overtimeMinutes,
    required Revision expected,
  }) {
    return _database.transaction(() async {
      final shift = await _shifts.byId(id);
      if (shift == null) return const Missing<WorkShift>();
      if (shift.revision != expected) return const Stale<WorkShift>();
      final candidate = _withOvertime(shift, overtimeMinutes);
      final validation = validateFinalization(
        shift: candidate,
        breaks: await _shifts.breaksFor(id),
        agreements: await _agreements.forEmployment(shift.employmentId),
      );
      final facts = validation.facts;
      if (facts == null) {
        return Invalid<WorkShift>({
          'shift': [
            for (final _ in validation.issues)
              const FieldIssue(FieldIssueCode.invalid),
          ],
        });
      }
      if (await _shifts.setOvertime(
            id,
            overtimeMinutes: overtimeMinutes,
            expected: expected,
            updatedAtUtc: shift.updatedAtUtc,
          ) ==
          0) {
        return const Stale<WorkShift>();
      }
      if (await _shifts.finalize(facts.shift, expected: expected) == 0) {
        return const Stale<WorkShift>();
      }
      return Committed<WorkShift>((await _shifts.byId(id))!);
    });
  }

  @override
  Future<MutationOutcome<WorkShift>> createAndFinalizeManual(
    WorkShift draft,
    List<ShiftBreak> breaks,
  ) {
    return _database.transaction(() async {
      final employment = await _employments.byId(draft.employmentId);
      if (employment == null || employment.status != EmploymentStatus.active) {
        return const Invalid<WorkShift>({
          'employmentId': [FieldIssue(FieldIssueCode.unavailable)],
        });
      }
      final agreements = await _agreements.forEmployment(draft.employmentId);
      final validation = validateFinalization(
        shift: draft,
        breaks: breaks,
        agreements: agreements,
      );
      if (!validation.isValid) {
        return const Invalid<WorkShift>({
          'shift': [FieldIssue(FieldIssueCode.invalid)],
        });
      }
      await _shifts.insert(draft);
      for (final value in breaks) {
        await _shifts.insertBreak(value);
      }
      return finalizeShift(draft.id, expected: draft.revision);
    });
  }

  @override
  Future<MutationOutcome<WorkShift>> commitCorrection(
    ShiftId originalId, {
    required Revision expected,
    required ShiftId replacementId,
    required String voidReason,
    required DateTime nowUtc,
  }) async {
    final original = await _shifts.byId(originalId);
    if (original == null) return const Missing<WorkShift>();
    if (original.revision != expected) return const Stale<WorkShift>();
    final replacement = original.replacementDraft(
      replacementId: replacementId,
      nowUtc: nowUtc,
    );
    return correctShift(
      originalId,
      expected: expected,
      replacement: replacement,
      voidReason: voidReason,
      nowUtc: nowUtc,
    );
  }

  Future<MutationOutcome<WorkShift>> correctShift(
    ShiftId originalId, {
    required Revision expected,
    required WorkShift replacement,
    required String voidReason,
    required DateTime nowUtc,
  }) async {
    try {
      return await _database.transaction(() async {
        final original = await _shifts.byId(originalId);
        if (original == null) return const Missing<WorkShift>();
        if (original.revision != expected) return const Stale<WorkShift>();
        final correction = prepareShiftCorrection(
          original: original,
          replacementId: replacement.id,
          voidReason: voidReason,
          nowUtc: nowUtc,
        );
        await _shifts.insert(replacement);
        final changed = await _shifts.voidForCorrection(
          correction.voidedOriginal,
          expected: expected,
        );
        if (changed == 0) {
          throw const _StaleCorrection();
        }
        for (final item in await _shifts.breaksFor(originalId)) {
          await _shifts.insertBreak(
            ShiftBreak(
              id: _createBreakId(),
              shiftId: replacement.id,
              startUtc: item.startUtc,
              endUtc: item.endUtc,
              createdAtUtc: nowUtc,
              updatedAtUtc: nowUtc,
              revision: const Revision(0),
            ),
          );
        }
        return Committed<WorkShift>(replacement);
      });
    } on _StaleCorrection {
      return const Stale<WorkShift>();
    }
  }
}

WorkShift _withOvertime(WorkShift shift, int overtimeMinutes) => WorkShift(
  id: shift.id,
  employmentId: shift.employmentId,
  agreementId: shift.agreementId,
  state: shift.state,
  startUtc: shift.startUtc,
  endUtc: shift.endUtc,
  timezoneId: shift.timezoneId,
  localStartDate: shift.localStartDate,
  overtimeMinutes: overtimeMinutes,
  note: shift.note,
  voidReason: shift.voidReason,
  replacementShiftId: shift.replacementShiftId,
  replacedShiftId: shift.replacedShiftId,
  createdAtUtc: shift.createdAtUtc,
  updatedAtUtc: shift.updatedAtUtc,
  revision: shift.revision,
);

final class _StaleCorrection implements Exception {
  const _StaleCorrection();
}

final class _StaleBreakEnd implements Exception {
  const _StaleBreakEnd();
}

ShiftBreakId _missingBreakIdFactory() {
  throw StateError('A break ID factory is required for shift correction.');
}
