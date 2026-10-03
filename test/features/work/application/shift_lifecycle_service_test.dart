import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/shift_lifecycle_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/daos/shift_dao.dart';
import 'package:lifeos/features/work/data/shift_repository.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  late _FakeShiftRepository repository;
  late ShiftLifecycleService service;

  setUp(() {
    repository = _FakeShiftRepository();
    service = ShiftLifecycleService(
      repository,
      idFactory: const _Ids(),
      clock: const _Clock(),
    );
  });

  test(
    'finalization commits agreement resolved from local start date',
    () async {
      repository.finalizeResult = Committed<WorkShift>(_finalizedShift());

      final result = await service.finalizeShift(
        const FinalizeShiftCommand(id: _shiftId, expectedRevision: Revision(4)),
      );

      expect(result, isA<Committed<WorkShift>>());
      expect((result as Committed<WorkShift>).value.agreementId, _agreementId);
      expect(repository.finalizedId, _shiftId);
    },
  );

  test('known storage failure returns unavailable', () async {
    repository.throwStorageUnavailable = true;

    final outcome = await service.finalizeShift(
      const FinalizeShiftCommand(id: _shiftId, expectedRevision: Revision(1)),
    );

    expect(
      outcome,
      isA<Unavailable<WorkShift>>().having(
        (value) => value.code,
        'code',
        SafeFailureCode.storageUnavailable,
      ),
    );
  });

  test('commit-exit ambiguity returns uncertain and does not retry', () async {
    repository.throwCommitUnknown = true;

    final outcome = await service.correctShift(
      const CorrectShiftCommand(
        originalId: _shiftId,
        replacementId: _replacementShiftId,
        expectedRevision: Revision(4),
        voidReason: 'Synthetic correction',
      ),
    );

    expect(outcome, isA<Uncertain<WorkShift>>());
    expect(repository.correctionAttempts, 1);
  });

  test('Drift adapter finalizes a finished draft with derived pay', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedReadyEmployment(database);
    await ShiftDao(database).insert(_draftShift());
    final driftRepository = DriftShiftRepository(database);
    final driftService = ShiftLifecycleService(
      driftRepository,
      idFactory: const _Ids(),
      clock: const _Clock(),
    );

    final outcome = await driftService.finalizeShift(
      const FinalizeShiftCommand(id: _shiftId, expectedRevision: Revision(0)),
    );

    final finalized = (outcome as Committed<WorkShift>).value;
    expect(finalized.state, ShiftState.finalized);
    expect(finalized.agreementId, _agreementId);
    expect(
      (await driftRepository.shiftById(_shiftId))!.state,
      ShiftState.finalized,
    );
  });

  test('Drift adapter refuses a draft without an end', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedReadyEmployment(database);
    await ShiftDao(database).insert(_draftShift(withEnd: false));
    final driftService = ShiftLifecycleService(
      DriftShiftRepository(database),
      idFactory: const _Ids(),
      clock: const _Clock(),
    );

    final outcome = await driftService.finalizeShift(
      const FinalizeShiftCommand(id: _shiftId, expectedRevision: Revision(0)),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
const _shiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const _replacementShiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');
const _breakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41');
final _now = DateTime.utc(2026, 9, 29, 22, 30);

Future<void> _seedReadyEmployment(AppDatabase database) async {
  final work = DriftWorkRepository(database);
  await work.insertEmployment(
    Employment.create(
      id: _employmentId,
      name: 'Synthetic employer',
      legalLabel: null,
      nowUtc: DateTime.utc(2026, 9, 1),
    ),
  );
  await work.insertAgreement(
    PayAgreement(
      id: _agreementId,
      employmentId: _employmentId,
      version: 1,
      effectiveStart: const LocalDate(2026, 9, 1),
      effectiveEnd: null,
      hourlyRateMicroEur: 20000000,
      basis: const GrossBasis(),
      overtimeThresholdMinutes: 480,
      overtimeMultiplier: const RationalMultiplier(
        numerator: 3,
        denominator: 2,
      ),
      label: null,
      note: null,
      createdAtUtc: DateTime.utc(2026, 9, 1),
      revision: const Revision(0),
      usedByFinalizedShift: false,
    ),
  );
}

WorkShift _finalizedShift() => WorkShift(
  id: _shiftId,
  employmentId: _employmentId,
  agreementId: _agreementId,
  state: ShiftState.finalized,
  startUtc: DateTime.utc(2026, 9, 29, 8),
  endUtc: DateTime.utc(2026, 9, 29, 16),
  timezoneId: 'Europe/Berlin',
  localStartDate: const LocalDate(2026, 9, 29),
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 29, 8),
  updatedAtUtc: _now,
  revision: const Revision(5),
);

WorkShift _draftShift({bool withEnd = true}) => WorkShift(
  id: _shiftId,
  employmentId: _employmentId,
  agreementId: null,
  state: ShiftState.draft,
  startUtc: DateTime.utc(2026, 9, 29, 6),
  endUtc: withEnd ? DateTime.utc(2026, 9, 29, 15) : null,
  timezoneId: 'Europe/Berlin',
  localStartDate: const LocalDate(2026, 9, 29),
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 29, 6),
  updatedAtUtc: _now,
  revision: const Revision(0),
);

final class _FakeShiftRepository implements ShiftLifecycleRepository {
  MutationOutcome<WorkShift> finalizeResult = const Missing<WorkShift>();
  ShiftId? finalizedId;
  bool throwCommitUnknown = false;
  bool throwStorageUnavailable = false;
  int correctionAttempts = 0;

  @override
  Future<MutationOutcome<WorkShift>> commitFinalization(
    ShiftId id, {
    required Revision expected,
  }) async {
    if (throwStorageUnavailable) throw const DatabaseOpenFailure();
    finalizedId = id;
    return finalizeResult;
  }

  @override
  Future<MutationOutcome<WorkShift>> commitCorrection(
    ShiftId originalId, {
    required Revision expected,
    required ShiftId replacementId,
    required String voidReason,
    required DateTime nowUtc,
  }) async {
    correctionAttempts++;
    if (throwCommitUnknown) throw const CommitOutcomeUnknown();
    return const Missing<WorkShift>();
  }
}

final class _Ids implements ShiftIdFactory {
  const _Ids();

  @override
  ShiftId shiftId() => _shiftId;

  @override
  ShiftBreakId shiftBreakId() => _breakId;
}

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => _now;
}
