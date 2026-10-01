import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
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
  late AppDatabase database;
  late DriftShiftRepository repository;
  late ShiftDraftRevisionService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftShiftRepository(
      database,
      createBreakId: () => _copiedBreakId,
    );
    service = ShiftDraftRevisionService(
      repository,
      idFactory: const _Ids(),
      clock: const _Clock(),
      timezones: IanaTimezoneService(),
    );
    await _seed(database);
  });

  tearDown(() => database.close());

  test('revision resolves local times and finalizes the draft', () async {
    final draft = await _draft(repository);

    final outcome = await service.reviseAndFinalize(
      _command(draft, startTime: const LocalTime(9, 0)),
    );

    final shift = (outcome as Committed<WorkShift>).value;
    expect(shift.state, ShiftState.finalized);
    expect(shift.startUtc, DateTime.utc(2026, 9, 29, 7));
    expect(shift.endUtc, DateTime.utc(2026, 9, 29, 14));
    expect(shift.note, 'Revised');
    expect(shift.replacedShiftId, _originalId);
    final breaks = await repository.breaksFor(_draftId);
    expect(breaks.single.id, _newBreakId);
    expect(breaks.single.startUtc, DateTime.utc(2026, 9, 29, 10));
  });

  test('nonexistent local time is rejected without writing', () async {
    final draft = await _draft(repository);

    final outcome = await service.reviseAndFinalize(
      ReviseShiftDraftCommand(
        id: draft.id,
        expectedRevision: draft.revision,
        localStartDate: const LocalDate(2026, 3, 29),
        localStartTime: const LocalTime(2, 30),
        localEndDate: const LocalDate(2026, 3, 29),
        localEndTime: const LocalTime(6, 0),
        timezoneId: 'Europe/Berlin',
        startFold: null,
        endFold: null,
        overtimeMinutes: 0,
        note: null,
      ),
    );

    expect(outcome, isA<Invalid<WorkShift>>());
    expect((await repository.shiftById(_draftId))!.state, ShiftState.draft);
  });

  test('missing draft returns missing', () async {
    final draft = await _draft(repository);

    final outcome = await service.reviseAndFinalize(
      _command(draft, id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4cff')),
    );

    expect(outcome, isA<Missing<WorkShift>>());
  });
}

ReviseShiftDraftCommand _command(
  WorkShift draft, {
  ShiftId? id,
  LocalTime startTime = const LocalTime(9, 0),
}) => ReviseShiftDraftCommand(
  id: id ?? draft.id,
  expectedRevision: draft.revision,
  localStartDate: const LocalDate(2026, 9, 29),
  localStartTime: startTime,
  localEndDate: const LocalDate(2026, 9, 29),
  localEndTime: const LocalTime(16, 0),
  timezoneId: 'Europe/Berlin',
  startFold: null,
  endFold: null,
  breaks: const [
    ManualShiftBreak(
      localStartDate: LocalDate(2026, 9, 29),
      localStartTime: LocalTime(12, 0),
      localEndDate: LocalDate(2026, 9, 29),
      localEndTime: LocalTime(12, 30),
      startFold: null,
      endFold: null,
    ),
  ],
  overtimeMinutes: 0,
  note: '  Revised  ',
);

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
const _originalId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const _draftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');
const _copiedBreakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c3a');
const _newBreakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41');

Future<WorkShift> _draft(DriftShiftRepository repository) async {
  final created = await repository.createAndFinalizeManual(
    WorkShift(
      id: _originalId,
      employmentId: _employmentId,
      agreementId: null,
      state: ShiftState.draft,
      startUtc: DateTime.utc(2026, 9, 29, 8),
      endUtc: DateTime.utc(2026, 9, 29, 14),
      timezoneId: 'Europe/Berlin',
      localStartDate: const LocalDate(2026, 9, 29),
      overtimeMinutes: 0,
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: DateTime.utc(2026, 9, 29),
      updatedAtUtc: DateTime.utc(2026, 9, 29),
      revision: const Revision(0),
    ),
    const [],
  );
  final original = (created as Committed<WorkShift>).value;
  final corrected = await repository.correctShift(
    original.id,
    expected: original.revision,
    replacement: original.replacementDraft(
      replacementId: _draftId,
      nowUtc: DateTime.utc(2026, 9, 30),
    ),
    voidReason: 'Synthetic correction',
    nowUtc: DateTime.utc(2026, 9, 30),
  );
  return (corrected as Committed<WorkShift>).value;
}

Future<void> _seed(AppDatabase database) async {
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

final class _Ids implements ShiftIdFactory {
  const _Ids();

  @override
  ShiftId shiftId() => _draftId;

  @override
  ShiftBreakId shiftBreakId() => _newBreakId;
}

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 30, 1);
}
