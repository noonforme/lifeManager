import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/manual_shift_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/shift_repository.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  test(
    'manual overnight shift preserves elapsed UTC facts and breaks',
    () async {
      final repository = _FakeManualRepository();
      final service = ManualShiftService(
        repository,
        idFactory: const _Ids(),
        clock: const _Clock(),
        timezones: IanaTimezoneService(),
      );

      final outcome = await service.createAndFinalize(
        const CreateManualShiftCommand(
          employmentId: _employmentId,
          localStartDate: LocalDate(2026, 10, 24),
          localStartTime: LocalTime(23, 30),
          localEndDate: LocalDate(2026, 10, 25),
          localEndTime: LocalTime(3, 30),
          timezoneId: 'Europe/Berlin',
          startFold: FoldChoice.earlier,
          endFold: FoldChoice.later,
          breaks: [
            ManualShiftBreak(
              localStartDate: LocalDate(2026, 10, 25),
              localStartTime: LocalTime(1, 30),
              localEndDate: LocalDate(2026, 10, 25),
              localEndTime: LocalTime(1, 50),
              startFold: FoldChoice.earlier,
              endFold: FoldChoice.earlier,
            ),
          ],
          note: '  Overnight synthetic shift  ',
        ),
      );

      final shift = (outcome as Committed<WorkShift>).value;
      expect(
        shift.endUtc!.difference(shift.startUtc),
        const Duration(hours: 5),
      );
      expect(shift.localStartDate, const LocalDate(2026, 10, 24));
      expect(shift.note, 'Overnight synthetic shift');
      expect(repository.breaks, hasLength(1));
      expect(
        repository.breaks.single.endUtc!.difference(
          repository.breaks.single.startUtc,
        ),
        const Duration(minutes: 20),
      );
    },
  );

  test('manual breaks persist atomically with finalized shift', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedReadyEmployment(database);
    final repository = DriftShiftRepository(database);
    final service = ManualShiftService(
      repository,
      idFactory: const _Ids(),
      clock: const _Clock(),
      timezones: IanaTimezoneService(),
    );

    final outcome = await service.createAndFinalize(
      const CreateManualShiftCommand(
        employmentId: _employmentId,
        localStartDate: LocalDate(2026, 10, 24),
        localStartTime: LocalTime(22, 0),
        localEndDate: LocalDate(2026, 10, 25),
        localEndTime: LocalTime(6, 0),
        timezoneId: 'Europe/Berlin',
        startFold: null,
        endFold: FoldChoice.later,
        breaks: [
          ManualShiftBreak(
            localStartDate: LocalDate(2026, 10, 25),
            localStartTime: LocalTime(1, 0),
            localEndDate: LocalDate(2026, 10, 25),
            localEndTime: LocalTime(1, 30),
            startFold: FoldChoice.earlier,
            endFold: FoldChoice.earlier,
          ),
        ],
        note: null,
      ),
    );

    expect(outcome, isA<Committed<WorkShift>>());
    expect((await repository.shiftById(_shiftId))?.state, ShiftState.finalized);
    final persistedBreaks = await repository.breaksFor(_shiftId);
    expect(persistedBreaks, hasLength(1));
    expect(
      persistedBreaks.single.endUtc!.difference(
        persistedBreaks.single.startUtc,
      ),
      const Duration(minutes: 30),
    );
  });

  test('known storage failure returns unavailable', () async {
    final service = ManualShiftService(
      const _UnavailableManualRepository(),
      idFactory: const _Ids(),
      clock: const _Clock(),
      timezones: IanaTimezoneService(),
    );

    final outcome = await service.createAndFinalize(
      const CreateManualShiftCommand(
        employmentId: _employmentId,
        localStartDate: LocalDate(2026, 10, 24),
        localStartTime: LocalTime(9, 0),
        localEndDate: LocalDate(2026, 10, 24),
        localEndTime: LocalTime(17, 0),
        timezoneId: 'Europe/Berlin',
        startFold: null,
        endFold: null,
        note: null,
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

  test('invalid manual finalization leaves no draft row', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedReadyEmployment(database);
    final repository = DriftShiftRepository(database);
    final service = ManualShiftService(
      repository,
      idFactory: const _Ids(),
      clock: const _Clock(),
      timezones: IanaTimezoneService(),
    );

    final outcome = await service.createAndFinalize(
      const CreateManualShiftCommand(
        employmentId: _employmentId,
        localStartDate: LocalDate(2026, 10, 24),
        localStartTime: LocalTime(9, 0),
        localEndDate: LocalDate(2026, 10, 24),
        localEndTime: LocalTime(10, 0),
        timezoneId: 'Europe/Berlin',
        startFold: null,
        endFold: null,
        // A break over the whole shift leaves no paid time.
        breaks: [
          ManualShiftBreak(
            localStartDate: LocalDate(2026, 10, 24),
            localStartTime: LocalTime(9, 0),
            localEndDate: LocalDate(2026, 10, 24),
            localEndTime: LocalTime(10, 0),
            startFold: null,
            endFold: null,
          ),
        ],
        note: null,
      ),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
    expect(await repository.shiftById(_shiftId), isNull);
  });

  test('nonexistent local time returns a safe invalid outcome', () async {
    final service = ManualShiftService(
      _FakeManualRepository(),
      idFactory: const _Ids(),
      clock: const _Clock(),
      timezones: IanaTimezoneService(),
    );

    final outcome = await service.createAndFinalize(
      const CreateManualShiftCommand(
        employmentId: _employmentId,
        localStartDate: LocalDate(2026, 3, 29),
        localStartTime: LocalTime(2, 30),
        localEndDate: LocalDate(2026, 3, 29),
        localEndTime: LocalTime(4, 30),
        timezoneId: 'Europe/Berlin',
        startFold: null,
        endFold: null,
        note: null,
      ),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _shiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
final _now = DateTime.utc(2026, 9, 30);

const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');

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
      effectiveStart: const LocalDate(2026, 1, 1),
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
      createdAtUtc: DateTime.utc(2026, 1, 1),
      revision: const Revision(0),
      usedByFinalizedShift: false,
    ),
  );
}

final class _UnavailableManualRepository implements ManualShiftRepository {
  const _UnavailableManualRepository();

  @override
  Future<MutationOutcome<WorkShift>> createAndFinalizeManual(
    WorkShift draft,
    List<ShiftBreak> breaks,
  ) => throw const DatabaseOpenFailure();
}

final class _FakeManualRepository implements ManualShiftRepository {
  List<ShiftBreak> breaks = const [];

  @override
  Future<MutationOutcome<WorkShift>> createAndFinalizeManual(
    WorkShift draft,
    List<ShiftBreak> breaks,
  ) async {
    this.breaks = breaks;
    return Committed<WorkShift>(
      WorkShift(
        id: draft.id,
        employmentId: draft.employmentId,
        agreementId: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
        state: ShiftState.finalized,
        startUtc: draft.startUtc,
        endUtc: draft.endUtc,
        timezoneId: draft.timezoneId,
        localStartDate: draft.localStartDate,
        note: draft.note,
        voidReason: null,
        replacementShiftId: null,
        replacedShiftId: null,
        createdAtUtc: draft.createdAtUtc,
        updatedAtUtc: draft.updatedAtUtc,
        revision: const Revision(1),
      ),
    );
  }
}

final class _Ids implements ShiftIdFactory {
  const _Ids();

  @override
  ShiftId shiftId() => _shiftId;

  @override
  ShiftBreakId shiftBreakId() =>
      const ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41');
}

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => _now;
}
