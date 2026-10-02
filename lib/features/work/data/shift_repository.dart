import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/history/record_events.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
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
import 'work_history.dart';

final class DriftShiftRepository
    implements
        ShiftLifecycleRepository,
        ManualShiftRepository,
        ShiftDraftRevisionRepository {
  /// History entries are stamped by [clock].
  DriftShiftRepository(
    this._database, {
    ShiftBreakId Function()? createBreakId,
    AppClock? clock,
  }) : _createBreakId = createBreakId ?? _missingBreakIdFactory,
       _history = WorkHistoryWriter(_database, clock ?? SystemAppClock()),
       _shifts = ShiftDao(_database),
       _agreements = AgreementDao(_database),
       _employments = EmploymentDao(_database);

  final AppDatabase _database;
  final ShiftBreakId Function() _createBreakId;
  final WorkHistoryWriter _history;
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
      await _recordShift(shift.id, RecordEventKind.created);
      return Committed<WorkShift>(shift);
    });
  }

  Future<WorkShift?> activeShift() => _shifts.active();

  Stream<WorkShift?> watchActiveShift() => _shifts.watchActive();

  @override
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
      final before = await _factsOf(value.shiftId);
      if (await startBreak(value, expectedShift: expectedShift) == 0) {
        return const Stale<WorkShift>();
      }
      return Committed<WorkShift>(
        await _recordShift(
          value.shiftId,
          RecordEventKind.changed,
          before: before,
        ),
      );
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
      final before = await _factsOf(shiftId);
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
      return Committed<WorkShift>(
        await _recordShift(shiftId, RecordEventKind.changed, before: before),
      );
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
      final before = await _factsOf(id);
      if (await endShift(id, endUtc: endUtc, expected: expected) == 0) {
        return const Stale<WorkShift>();
      }
      return Committed<WorkShift>(
        await _recordShift(id, RecordEventKind.changed, before: before),
      );
    });
  }

  Future<MutationOutcome<WorkShift>> finalizeShift(
    ShiftId id, {
    required Revision expected,
    bool failAfterAgreementLinkForTest = false,
  }) {
    return _database.transaction(() async {
      final before = await _factsOf(id);
      final outcome = await _finalize(id, expected: expected);
      if (outcome is! Committed<WorkShift>) return outcome;
      final finalized = await _recordShift(
        id,
        RecordEventKind.finalized,
        before: before,
      );
      if (failAfterAgreementLinkForTest) {
        throw StateError('Synthetic finalization failure.');
      }
      return Committed<WorkShift>(finalized);
    });
  }

  /// Finalizes without a history entry; callers record their own event.
  Future<MutationOutcome<WorkShift>> _finalize(
    ShiftId id, {
    required Revision expected,
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
      return Committed<WorkShift>((await _shifts.byId(id))!);
    });
  }

  @override
  Future<MutationOutcome<WorkShift>> commitFinalization(
    ShiftId id, {
    required Revision expected,
  }) => finalizeShift(id, expected: expected);

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
      final outcome = await _finalize(draft.id, expected: draft.revision);
      if (outcome is! Committed<WorkShift>) return outcome;
      return Committed<WorkShift>(
        await _recordShift(draft.id, RecordEventKind.created),
      );
    });
  }

  /// Replaces a draft's facts and breaks and finalizes it in one transaction.
  /// Nothing is written unless the revised facts finalize.
  @override
  Future<MutationOutcome<WorkShift>> reviseAndFinalizeDraft(
    WorkShift revised, {
    required Revision expected,
    required List<ShiftBreak> breaks,
  }) async {
    try {
      return await _database.transaction(() async {
        final current = await _shifts.byId(revised.id);
        if (current == null) return const Missing<WorkShift>();
        if (current.state != ShiftState.draft ||
            breaks.any((value) => value.shiftId != revised.id)) {
          return const Invalid<WorkShift>({
            'shift': [FieldIssue(FieldIssueCode.invalid)],
          });
        }
        if (current.revision != expected) return const Stale<WorkShift>();
        final before = await _factsOf(current.id);
        final agreements = await _agreements.forEmployment(
          current.employmentId,
        );
        final validation = validateFinalization(
          shift: revised,
          breaks: breaks,
          agreements: agreements,
        );
        if (!validation.isValid) {
          return const Invalid<WorkShift>({
            'shift': [FieldIssue(FieldIssueCode.invalid)],
          });
        }
        if (await _shifts.reviseDraft(revised, expected: expected) == 0) {
          return const Stale<WorkShift>();
        }
        await _shifts.deleteBreaksFor(revised.id);
        for (final value in breaks) {
          await _shifts.insertBreak(value);
        }
        final finalized = await _finalize(
          revised.id,
          expected: expected.next(),
        );
        if (finalized is! Committed<WorkShift>) {
          throw _RevisionRejected(finalized);
        }
        return Committed<WorkShift>(
          await _recordShift(
            revised.id,
            RecordEventKind.finalized,
            before: before,
          ),
        );
      });
    } on _RevisionRejected catch (rejected) {
      return rejected.outcome;
    }
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
        final before = await _factsOf(originalId);
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
        await _recordShift(
          originalId,
          RecordEventKind.voided,
          before: before,
          reason: correction.voidedOriginal.voidReason,
        );
        await _recordShift(replacement.id, RecordEventKind.replaced);
        return Committed<WorkShift>(replacement);
      });
    } on _StaleCorrection {
      return const Stale<WorkShift>();
    }
  }
}

/// Rolls back a draft revision whose finalization did not commit.
final class _RevisionRejected implements Exception {
  const _RevisionRejected(this.outcome);

  final MutationOutcome<WorkShift> outcome;
}

final class _StaleCorrection implements Exception {
  const _StaleCorrection();
}

final class _StaleBreakEnd implements Exception {
  const _StaleBreakEnd();
}

extension on DriftShiftRepository {
  Future<Map<String, String?>> _factsOf(ShiftId id) async {
    final shift = await _shifts.byId(id);
    return shift == null
        ? const {}
        : shiftFacts(shift, await _shifts.breaksFor(id));
  }

  /// Appends the shift's event against its committed state and returns it.
  Future<WorkShift> _recordShift(
    ShiftId id,
    RecordEventKind kind, {
    Map<String, String?> before = const {},
    String? reason,
  }) async {
    final shift = (await _shifts.byId(id))!;
    await _history.record(
      WorkRecordKinds.shift,
      id.value,
      kind: kind,
      before: before,
      after: shiftFacts(shift, await _shifts.breaksFor(id)),
      revisionAfter: shift.revision,
      reason: reason,
    );
    return shift;
  }
}

ShiftBreakId _missingBreakIdFactory() {
  throw StateError('A break ID factory is required for shift correction.');
}
