import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/shift_lifecycle_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
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
      timezones: const _Zones(),
    );
  });

  test('start captures one instant, timezone, and local start date', () async {
    final outcome = await service.startShift(
      const StartShiftCommand(
        employmentId: _employmentId,
        timezoneId: 'Europe/Berlin',
      ),
    );

    final shift = (outcome as Committed<WorkShift>).value;
    expect(shift.id, _shiftId);
    expect(shift.startUtc, _now);
    expect(shift.timezoneId, 'Europe/Berlin');
    expect(shift.localStartDate, const LocalDate(2026, 9, 30));
  });

  test('global active shift conflict returns field-safe invalid', () async {
    repository.startResult = const Invalid<WorkShift>({
      'activeShift': [FieldIssue(FieldIssueCode.conflict)],
    });

    final outcome = await service.startShift(
      const StartShiftCommand(
        employmentId: _employmentId,
        timezoneId: 'Europe/Berlin',
      ),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
  });

  test('start requires an active employment and effective agreement', () async {
    repository.startResult = const Invalid<WorkShift>({
      'employmentId': [FieldIssue(FieldIssueCode.unavailable)],
    });

    final outcome = await service.startShift(
      const StartShiftCommand(
        employmentId: _employmentId,
        timezoneId: 'Europe/Berlin',
      ),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
    expect(
      (outcome as Invalid<WorkShift>).fields,
      containsPair('employmentId', isNotEmpty),
    );
  });

  test('start break commits the authoritative on-break shift', () async {
    repository.startBreakResult = Committed<WorkShift>(
      _activeShift(state: ShiftState.onBreak, revision: const Revision(5)),
    );

    final outcome = await service.startBreak(
      const StartBreakCommand(
        shiftId: _shiftId,
        expectedShiftRevision: Revision(4),
      ),
    );

    expect((outcome as Committed<WorkShift>).value.state, ShiftState.onBreak);
    expect(repository.startedBreak!.id, _breakId);
    expect(repository.startedBreak!.startUtc, _now);
  });

  test('end break maps a stale authoritative write to stale', () async {
    repository.endBreakResult = const Stale<WorkShift>();

    final outcome = await service.endBreak(
      const EndBreakCommand(
        shiftId: _shiftId,
        breakId: _breakId,
        expectedShiftRevision: Revision(5),
        expectedBreakRevision: Revision(0),
      ),
    );

    expect(outcome, isA<Stale<WorkShift>>());
    expect(repository.endBreakAt, _now);
  });

  test('end shift exposes an on-break state error without mutation', () async {
    repository.endShiftResult = const Invalid<WorkShift>({
      'break': [FieldIssue(FieldIssueCode.conflict)],
    });

    final outcome = await service.endShift(
      const EndShiftCommand(id: _shiftId, expectedRevision: Revision(5)),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
    expect(repository.endShiftAt, _now);
  });

  test(
    'finalization commits agreement resolved from local start date',
    () async {
      repository.finalizeResult = Committed<WorkShift>(_finalizedShift());

      final result = await service.finalizeShift(
        const FinalizeShiftCommand(
          id: _shiftId,
          overtimeMinutes: 15,
          expectedRevision: Revision(4),
        ),
      );

      expect(result, isA<Committed<WorkShift>>());
      expect((result as Committed<WorkShift>).value.agreementId, _agreementId);
      expect(repository.finalizeOvertimeMinutes, 15);
    },
  );

  test('known storage failure returns unavailable', () async {
    repository.throwStorageUnavailable = true;

    final outcome = await service.startShift(
      const StartShiftCommand(
        employmentId: _employmentId,
        timezoneId: 'Europe/Berlin',
      ),
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

  test('Drift adapter rejects start without an active employment', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final driftRepository = DriftShiftRepository(database);
    final driftService = ShiftLifecycleService(
      driftRepository,
      idFactory: const _Ids(),
      clock: const _Clock(),
      timezones: const _Zones(),
    );

    final outcome = await driftService.startShift(
      const StartShiftCommand(
        employmentId: _employmentId,
        timezoneId: 'Europe/Berlin',
      ),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
    expect(await driftRepository.activeShift(), isNull);
  });

  test('Drift adapter commits a complete break cycle', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedReadyEmployment(database);
    final driftRepository = DriftShiftRepository(database);
    final driftService = ShiftLifecycleService(
      driftRepository,
      idFactory: const _Ids(),
      clock: _SequenceClock([
        _now,
        _now.add(const Duration(hours: 4)),
        _now.add(const Duration(hours: 4, minutes: 30)),
      ]),
      timezones: const _Zones(),
    );
    await driftService.startShift(
      const StartShiftCommand(
        employmentId: _employmentId,
        timezoneId: 'Europe/Berlin',
      ),
    );

    final started = await driftService.startBreak(
      const StartBreakCommand(
        shiftId: _shiftId,
        expectedShiftRevision: Revision(0),
      ),
    );
    expect((started as Committed<WorkShift>).value.state, ShiftState.onBreak);

    final ended = await driftService.endBreak(
      const EndBreakCommand(
        shiftId: _shiftId,
        breakId: _breakId,
        expectedShiftRevision: Revision(1),
        expectedBreakRevision: Revision(0),
      ),
    );
    expect((ended as Committed<WorkShift>).value.state, ShiftState.running);
    expect(
      (await driftRepository.breaksFor(_shiftId)).single.endUtc,
      isNotNull,
    );
  });

  test('Drift adapter rejects a nonpositive elapsed shift safely', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedReadyEmployment(database);
    final driftRepository = DriftShiftRepository(database);
    final driftService = ShiftLifecycleService(
      driftRepository,
      idFactory: const _Ids(),
      clock: const _Clock(),
      timezones: const _Zones(),
    );
    expect(
      await driftService.startShift(
        const StartShiftCommand(
          employmentId: _employmentId,
          timezoneId: 'Europe/Berlin',
        ),
      ),
      isA<Committed<WorkShift>>(),
    );

    final outcome = await driftService.endShift(
      const EndShiftCommand(id: _shiftId, expectedRevision: Revision(0)),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
    expect(
      (await driftRepository.shiftById(_shiftId))!.state,
      ShiftState.running,
    );
  });

  test('invalid finalization rolls back confirmed overtime', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedReadyEmployment(database);
    final driftRepository = DriftShiftRepository(database);
    final driftService = ShiftLifecycleService(
      driftRepository,
      idFactory: const _Ids(),
      clock: _SequenceClock([_now, _now.add(const Duration(hours: 8))]),
      timezones: const _Zones(),
    );
    await driftService.startShift(
      const StartShiftCommand(
        employmentId: _employmentId,
        timezoneId: 'Europe/Berlin',
      ),
    );
    await driftService.endShift(
      const EndShiftCommand(id: _shiftId, expectedRevision: Revision(0)),
    );

    final outcome = await driftService.finalizeShift(
      const FinalizeShiftCommand(
        id: _shiftId,
        overtimeMinutes: 600,
        expectedRevision: Revision(1),
      ),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
    final persisted = (await driftRepository.shiftById(_shiftId))!;
    expect(persisted.state, ShiftState.draft);
    expect(persisted.overtimeMinutes, 0);
  });

  test(
    'Drift adapter preserves overtime that differs from suggestion',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedReadyEmployment(database);
      final driftRepository = DriftShiftRepository(database);
      final driftService = ShiftLifecycleService(
        driftRepository,
        idFactory: const _Ids(),
        clock: _SequenceClock([_now, _now.add(const Duration(hours: 8))]),
        timezones: const _Zones(),
      );
      expect(
        await driftService.startShift(
          const StartShiftCommand(
            employmentId: _employmentId,
            timezoneId: 'Europe/Berlin',
          ),
        ),
        isA<Committed<WorkShift>>(),
      );
      expect(
        await driftService.endShift(
          const EndShiftCommand(id: _shiftId, expectedRevision: Revision(0)),
        ),
        isA<Committed<WorkShift>>(),
      );

      final outcome = await driftService.finalizeShift(
        const FinalizeShiftCommand(
          id: _shiftId,
          overtimeMinutes: 15,
          expectedRevision: Revision(1),
        ),
      );

      final finalized = (outcome as Committed<WorkShift>).value;
      expect(finalized.overtimeMinutes, 15);
      expect((await driftRepository.shiftById(_shiftId))!.overtimeMinutes, 15);
    },
  );
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
const _shiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const _replacementShiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');
const _breakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41');
final _now = DateTime.utc(2026, 9, 29, 22, 30);

WorkShift _activeShift({
  required ShiftState state,
  required Revision revision,
}) => WorkShift(
  id: _shiftId,
  employmentId: _employmentId,
  agreementId: null,
  state: state,
  startUtc: DateTime.utc(2026, 9, 29, 8),
  endUtc: null,
  timezoneId: 'Europe/Berlin',
  localStartDate: const LocalDate(2026, 9, 29),
  overtimeMinutes: 0,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 29, 8),
  updatedAtUtc: _now,
  revision: revision,
);

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
  overtimeMinutes: 15,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 29, 8),
  updatedAtUtc: _now,
  revision: const Revision(5),
);

final class _FakeShiftRepository implements ShiftLifecycleRepository {
  MutationOutcome<WorkShift>? startResult;
  MutationOutcome<WorkShift> startBreakResult = const Missing<WorkShift>();
  MutationOutcome<WorkShift> endBreakResult = const Missing<WorkShift>();
  MutationOutcome<WorkShift> endShiftResult = const Missing<WorkShift>();
  MutationOutcome<WorkShift> finalizeResult = const Missing<WorkShift>();
  ShiftBreak? startedBreak;
  DateTime? endBreakAt;
  DateTime? endShiftAt;
  int? finalizeOvertimeMinutes;
  bool throwCommitUnknown = false;
  bool throwStorageUnavailable = false;
  int correctionAttempts = 0;

  @override
  Future<MutationOutcome<WorkShift>> commitStart(WorkShift shift) async {
    if (throwStorageUnavailable) throw const DatabaseOpenFailure();
    return startResult ?? Committed<WorkShift>(shift);
  }

  @override
  Future<MutationOutcome<WorkShift>> commitStartBreak(
    ShiftBreak value, {
    required Revision expectedShift,
  }) async {
    startedBreak = value;
    return startBreakResult;
  }

  @override
  Future<MutationOutcome<WorkShift>> commitEndBreak(
    ShiftBreakId id, {
    required ShiftId shiftId,
    required DateTime endUtc,
    required Revision expectedBreak,
    required Revision expectedShift,
  }) async {
    endBreakAt = endUtc;
    return endBreakResult;
  }

  @override
  Future<MutationOutcome<WorkShift>> commitEndShift(
    ShiftId id, {
    required DateTime endUtc,
    required Revision expected,
  }) async {
    endShiftAt = endUtc;
    return endShiftResult;
  }

  @override
  Future<MutationOutcome<WorkShift>> commitFinalization(
    ShiftId id, {
    required int overtimeMinutes,
    required Revision expected,
  }) async {
    finalizeOvertimeMinutes = overtimeMinutes;
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

final class _SequenceClock implements AppClock {
  _SequenceClock(this.values);

  final List<DateTime> values;
  var _index = 0;

  @override
  DateTime nowUtc() => values[_index++];
}

final class _Zones implements TimezoneService {
  const _Zones();

  @override
  LocalDate localDateAt(DateTime utc, String zoneId) =>
      const LocalDate(2026, 9, 30);

  @override
  ZonedInstant resolveLocal(
    LocalDate date,
    LocalTime time,
    String zoneId, {
    FoldChoice? fold,
  }) => throw UnimplementedError();
}
