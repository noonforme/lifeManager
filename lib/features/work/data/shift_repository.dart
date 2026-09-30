import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/outcomes/mutation_outcome.dart';
import '../domain/correction.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/shift.dart';
import 'daos/agreement_dao.dart';
import 'daos/shift_dao.dart';

final class DriftShiftRepository {
  DriftShiftRepository(this._database, {ShiftBreakId Function()? createBreakId})
    : _createBreakId = createBreakId ?? _missingBreakIdFactory,
      _shifts = ShiftDao(_database),
      _agreements = AgreementDao(_database);

  final AppDatabase _database;
  final ShiftBreakId Function() _createBreakId;
  final ShiftDao _shifts;
  final AgreementDao _agreements;

  Future<int> start(WorkShift shift) async {
    try {
      return await _shifts.insert(shift);
    } on SqliteException catch (error) {
      if (error.extendedResultCode == 2067 || error.resultCode == 19) return 0;
      rethrow;
    }
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

  Future<int> endShift(
    ShiftId id, {
    required DateTime endUtc,
    required Revision expected,
  }) => _shifts.endShift(id, endUtc: endUtc, expected: expected);

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

final class _StaleCorrection implements Exception {
  const _StaleCorrection();
}

final class _StaleBreakEnd implements Exception {
  const _StaleBreakEnd();
}

ShiftBreakId _missingBreakIdFactory() {
  throw StateError('A break ID factory is required for shift correction.');
}
