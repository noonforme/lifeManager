import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/daos/shift_dao.dart';
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

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftShiftRepository(
      database,
      createBreakId: () => _replacementBreakId,
    );
    await _seedEmploymentAndAgreement(database);
  });

  tearDown(() => database.close());

  test('failed finalization rolls back agreement and state writes', () async {
    await _insertEndedDraft(database);

    await expectLater(
      repository.finalizeShift(
        _shiftA,
        expected: const Revision(0),
        failAfterAgreementLinkForTest: true,
      ),
      throwsStateError,
    );

    final persisted = (await repository.shiftById(_shiftA))!;
    expect(persisted.state, ShiftState.draft);
    expect(persisted.agreementId, isNull);
  });

  test(
    'correction atomically preserves original and copies break facts',
    () async {
      await _insertEndedDraft(database, withBreak: true);
      final finalized = await repository.finalizeShift(
        _shiftA,
        expected: const Revision(0),
      );
      final original = (finalized as Committed<WorkShift>).value;
      final replacement = original.replacementDraft(
        replacementId: _shiftB,
        nowUtc: DateTime.utc(2026, 9, 30),
      );

      final result = await repository.correctShift(
        original.id,
        expected: original.revision,
        replacement: replacement,
        voidReason: ' Synthetic correction ',
        nowUtc: DateTime.utc(2026, 9, 30),
      );

      expect(result, isA<Committed<WorkShift>>());
      final persistedOriginal = (await repository.shiftById(original.id))!;
      expect(persistedOriginal.state, ShiftState.voided);
      expect(persistedOriginal.replacementShiftId, replacement.id);
      final persistedReplacement = (await repository.shiftById(
        replacement.id,
      ))!;
      expect(persistedReplacement.replacedShiftId, original.id);
      final originalBreak = (await repository.breaksFor(original.id)).single;
      final copiedBreak = (await repository.breaksFor(replacement.id)).single;
      expect(copiedBreak.id, _replacementBreakId);
      expect(copiedBreak.startUtc, originalBreak.startUtc);
      expect(copiedBreak.endUtc, originalBreak.endUtc);
    },
  );

  test('replacement draft is revised and finalized atomically', () async {
    final draft = await _replacementDraftWithCopiedBreak(repository, database);
    final revised = draft.revisedFacts(
      startUtc: DateTime.utc(2026, 9, 29, 9),
      endUtc: DateTime.utc(2026, 9, 29, 17),
      timezoneId: 'Europe/Berlin',
      localStartDate: const LocalDate(2026, 9, 29),
      note: 'Corrected start',
    );
    final newBreak = ShiftBreak(
      id: _revisedBreakId,
      shiftId: draft.id,
      startUtc: DateTime.utc(2026, 9, 29, 13),
      endUtc: DateTime.utc(2026, 9, 29, 13, 45),
      createdAtUtc: DateTime.utc(2026, 9, 30),
      updatedAtUtc: DateTime.utc(2026, 9, 30),
      revision: const Revision(0),
    );

    final result = await repository.reviseAndFinalizeDraft(
      revised,
      expected: draft.revision,
      breaks: [newBreak],
    );

    final shift = (result as Committed<WorkShift>).value;
    expect(shift.state, ShiftState.finalized);
    expect(shift.startUtc, DateTime.utc(2026, 9, 29, 9));
    expect(shift.note, 'Corrected start');
    expect(shift.agreementId, _agreementId);
    expect(shift.replacedShiftId, _shiftA);
    final breaks = await repository.breaksFor(draft.id);
    expect(breaks.map((value) => value.id), [_revisedBreakId]);
  });

  test('stale draft revision leaves the draft and breaks unchanged', () async {
    final draft = await _replacementDraftWithCopiedBreak(repository, database);
    final revised = draft.revisedFacts(
      startUtc: DateTime.utc(2026, 9, 29, 9),
      endUtc: DateTime.utc(2026, 9, 29, 17),
      timezoneId: 'Europe/Berlin',
      localStartDate: const LocalDate(2026, 9, 29),
      note: null,
    );

    final result = await repository.reviseAndFinalizeDraft(
      revised,
      expected: const Revision(7),
      breaks: const [],
    );

    expect(result, isA<Stale<WorkShift>>());
    final persisted = (await repository.shiftById(draft.id))!;
    expect(persisted.state, ShiftState.draft);
    expect(persisted.startUtc, draft.startUtc);
    expect(await repository.breaksFor(draft.id), hasLength(1));
  });

  test('finalized shifts are never revised as drafts', () async {
    final draft = await _replacementDraftWithCopiedBreak(repository, database);
    final original = (await repository.shiftById(_shiftA))!;

    final result = await repository.reviseAndFinalizeDraft(
      original.revisedFacts(
        startUtc: DateTime.utc(2026, 9, 29, 9),
        endUtc: DateTime.utc(2026, 9, 29, 17),
        timezoneId: 'Europe/Berlin',
        localStartDate: const LocalDate(2026, 9, 29),
        note: null,
      ),
      expected: original.revision,
      breaks: const [],
    );

    expect(result, isA<Invalid<WorkShift>>());
    expect((await repository.shiftById(_shiftA))!.state, ShiftState.voided);
    expect((await repository.shiftById(draft.id))!.state, ShiftState.draft);
  });

  test('removal voids a finalized shift with no replacement', () async {
    await _insertEndedDraft(database, withBreak: true);
    final original = (await repository.finalizeShift(
      _shiftA,
      expected: const Revision(0),
    ) as Committed<WorkShift>).value;

    final result = await repository.commitVoid(
      _shiftA,
      expected: original.revision,
      voidReason: ' Entered twice ',
      nowUtc: DateTime.utc(2026, 10, 7),
    );

    final removed = (result as Committed<WorkShift>).value;
    expect(removed.state, ShiftState.voided);
    expect(removed.voidReason, 'Entered twice');
    expect(removed.replacementShiftId, isNull);
    expect(removed.revision, original.revision.next());
    final persisted = (await repository.shiftById(_shiftA))!;
    expect(persisted.state, ShiftState.voided);
    expect(persisted.agreementId, _agreementId);
    // Kept for history: the breaks stay with the void shift.
    expect(await repository.breaksFor(_shiftA), hasLength(1));
    final events = await database
        .customSelect(
          "SELECT kind, reason FROM record_events WHERE record_kind = 'shift' "
          'ORDER BY id',
        )
        .get();
    expect(events.last.read<String>('kind'), 'voided');
    expect(events.last.read<String>('reason'), 'Entered twice');
  });

  test('removal voids a draft the same way', () async {
    await _insertEndedDraft(database);

    final result = await repository.commitVoid(
      _shiftA,
      expected: const Revision(0),
      voidReason: 'Not worked',
      nowUtc: DateTime.utc(2026, 10, 7),
    );

    expect((result as Committed<WorkShift>).value.state, ShiftState.voided);
  });

  test('removal reports missing, stale, void and blank reason', () async {
    await _insertEndedDraft(database);
    Future<MutationOutcome<WorkShift>> remove(
      ShiftId id, {
      int expected = 0,
      String reason = 'Entered twice',
    }) => repository.commitVoid(
      id,
      expected: Revision(expected),
      voidReason: reason,
      nowUtc: DateTime.utc(2026, 10, 7),
    );

    expect(await remove(_shiftB), isA<Missing<WorkShift>>());
    expect(await remove(_shiftA, expected: 3), isA<Stale<WorkShift>>());
    expect(
      (await remove(_shiftA, reason: '  ') as Invalid<WorkShift>).fields.keys,
      ['voidReason'],
    );
    // Nothing was written by the refusals.
    expect((await repository.shiftById(_shiftA))!.state, ShiftState.draft);

    expect(await remove(_shiftA), isA<Committed<WorkShift>>());
    expect(
      (await remove(_shiftA, expected: 1) as Invalid<WorkShift>).fields.keys,
      ['state'],
    );
  });

  test(
    'stale correction creates no replacement and leaves original finalized',
    () async {
      await _insertEndedDraft(database);
      final finalized = await repository.finalizeShift(
        _shiftA,
        expected: const Revision(0),
      );
      expect(finalized, isA<Committed<WorkShift>>());
      final original = (finalized as Committed<WorkShift>).value;
      final replacement = original.replacementDraft(
        replacementId: _shiftB,
        nowUtc: DateTime.utc(2026, 9, 30),
      );

      final result = await repository.correctShift(
        original.id,
        expected: const Revision(0),
        replacement: replacement,
        voidReason: 'Synthetic correction',
        nowUtc: DateTime.utc(2026, 9, 30),
      );

      expect(result, isA<Stale<WorkShift>>());
      expect(await repository.shiftById(replacement.id), isNull);
      expect(
        (await repository.shiftById(original.id))!.state,
        ShiftState.finalized,
      );
    },
  );
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
const _shiftA = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const _shiftB = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');
const _breakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c39');
const _replacementBreakId = ShiftBreakId(
  '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c3a',
);

const _revisedBreakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c3b');

Future<WorkShift> _replacementDraftWithCopiedBreak(
  DriftShiftRepository repository,
  AppDatabase database,
) async {
  await _insertEndedDraft(database, withBreak: true);
  final finalized = await repository.finalizeShift(
    _shiftA,
    expected: const Revision(0),
  );
  final original = (finalized as Committed<WorkShift>).value;
  final corrected = await repository.correctShift(
    original.id,
    expected: original.revision,
    replacement: original.replacementDraft(
      replacementId: _shiftB,
      nowUtc: DateTime.utc(2026, 9, 30),
    ),
    voidReason: 'Synthetic correction',
    nowUtc: DateTime.utc(2026, 9, 30),
  );
  return (corrected as Committed<WorkShift>).value;
}

Future<void> _seedEmploymentAndAgreement(AppDatabase database) async {
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

/// A finished draft, 08:00–16:00 UTC, at revision 0.
WorkShift _endedDraft(ShiftId id) => WorkShift(
  id: id,
  employmentId: _employmentId,
  agreementId: null,
  state: ShiftState.draft,
  startUtc: DateTime.utc(2026, 9, 29, 8),
  endUtc: DateTime.utc(2026, 9, 29, 16),
  timezoneId: 'Europe/Berlin',
  localStartDate: const LocalDate(2026, 9, 29),
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 29, 8),
  updatedAtUtc: DateTime.utc(2026, 9, 29, 16),
  revision: const Revision(0),
);

Future<void> _insertEndedDraft(
  AppDatabase database, {
  bool withBreak = false,
}) async {
  final dao = ShiftDao(database);
  await dao.insert(_endedDraft(_shiftA));
  if (withBreak) await dao.insertBreak(_closedBreak());
}

ShiftBreak _closedBreak() => ShiftBreak(
  id: _breakId,
  shiftId: _shiftA,
  startUtc: DateTime.utc(2026, 9, 29, 12),
  endUtc: DateTime.utc(2026, 9, 29, 12, 30),
  createdAtUtc: DateTime.utc(2026, 9, 29, 12),
  updatedAtUtc: DateTime.utc(2026, 9, 29, 12, 30),
  revision: const Revision(1),
);
