import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/core/time/wall_clock.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/work_converters.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../../support/schedule_fixture.dart';

/// The four agreement commands the owner asked for: change terms from a
/// date, widen in place, remove an unused agreement and end one
/// (premiums spec 7, added 2026-10-07).
void main() {
  const employment = fixtureEmployment;
  late ScheduleFixture fixture;
  late DriftWorkRepository work;
  late AgreementService service;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    work = DriftWorkRepository(fixture.database, clock: fixture.clock);
    service = AgreementService(
      work,
      idFactory: UuidV7WorkIdFactory(),
      clock: fixture.clock,
    );
  });
  tearDown(() => fixture.dispose());

  Future<PayAgreement> agreement([AgreementId id = fixtureAgreement]) async =>
      (await work.agreementsFor(employment))
          .singleWhere((value) => value.id == id);

  /// Confirms the planned Day on [date] (the depot rotation starts
  /// 2026-10-05 with three Days).
  Future<WorkShift> confirmShift(LocalDate date) async {
    final outcome = await fixture.plans.confirm(employment, date);
    return ((outcome as Committed<ConfirmedDay>).value as ConfirmedShift).shift;
  }

  Future<void> confirmLeave(LocalDate date) async {
    await fixture.plans.markLeave(
      employment,
      date,
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    expect(
      await fixture.plans.confirm(employment, date),
      isA<Committed<ConfirmedDay>>(),
    );
  }

  Future<PayAgreement> createSecond({
    required LocalDate start,
    LocalDate? end,
  }) async {
    final outcome = await service.createAgreement(
      CreateAgreementCommand(
        employmentId: employment,
        version: 2,
        terms: _terms(start: start, end: end),
      ),
    );
    return (outcome as Committed<PayAgreement>).value;
  }

  group('change terms from a date', () {
    ChangeAgreementTermsCommand change(
      PayAgreement current, {
      required LocalDate from,
      int rate = 25000000,
      Revision? expected,
      AgreementId? id,
    }) => ChangeAgreementTermsCommand(
      agreementId: id ?? current.id,
      employmentId: employment,
      expectedRevision: expected ?? current.revision,
      from: from,
      terms: _terms(start: from, rate: rate),
    );

    test('ends the current version the day before and starts the next '
        'on the date, keeping confirmed pay', () async {
      await fixture.saveDepot();
      final confirmed = await confirmShift(const LocalDate(2026, 10, 5));
      final payBefore = await _payOf(work, confirmed.id);
      final current = await agreement();

      final outcome = await service.changeAgreementTerms(
        change(current, from: const LocalDate(2026, 10, 10)),
      );

      final next = (outcome as Committed<PayAgreement>).value;
      expect(next.id, isNot(current.id));
      expect(next.version, 2);
      expect(next.effectiveStart, const LocalDate(2026, 10, 10));
      expect(next.effectiveEnd, isNull);
      expect(next.hourlyRateMicroEur, 25000000);
      final ended = await agreement();
      expect(ended.effectiveEnd, const LocalDate(2026, 10, 9));
      expect(ended.hourlyRateMicroEur, 18400000);
      expect(ended.revision, current.revision.next());
      // The confirmed shift keeps its agreement and its pay.
      expect(await _payOf(work, confirmed.id), payBefore);
      final stored = (await work.watchRecord(confirmed.id).first)!;
      expect(
        (stored as ShiftRecordProjection).shift.agreementId,
        fixtureAgreement,
      );
      // A planned day from the date on is paid on the new terms.
      final agreements = await work.agreementsFor(employment);
      final planned =
          (await fixture.plans.plan(
                employment,
                const LocalDate(2026, 10, 17),
                const LocalDate(2026, 10, 17),
              )).single
              as PlannedShift;
      final pay = plannedPay(
        planned,
        agreements: agreements,
        employmentId: employment,
        zoneClocks: zoneClocksOf(IanaTimezoneService()),
      );
      // 11.5 paid daytime hours at EUR 25.00, never overtime.
      expect(pay?.amount.minorUnits, 28750);
    });

    test('the next version keeps the current end', () async {
      final current = await agreement();
      final ended = (await service.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: employment,
          end: const LocalDate(2026, 12, 31),
          expectedRevision: current.revision,
        ),
      ) as Committed<PayAgreement>).value;

      final outcome = await service.changeAgreementTerms(
        change(ended, from: const LocalDate(2026, 11, 1)),
      );

      final next = (outcome as Committed<PayAgreement>).value;
      expect(next.effectiveEnd, const LocalDate(2026, 12, 31));
      expect((await agreement()).effectiveEnd, const LocalDate(2026, 10, 31));
    });

    test('a date on or before a finished shift is refused on From', () async {
      await fixture.saveDepot();
      await confirmShift(const LocalDate(2026, 10, 6));
      final current = await agreement();

      for (final from in const [
        LocalDate(2026, 10, 6),
        LocalDate(2026, 10, 2),
      ]) {
        final outcome = await service.changeAgreementTerms(
          change(current, from: from),
        );
        expect((outcome as Invalid<PayAgreement>).fields['from'], [
          const FieldIssue(FieldIssueCode.conflict),
        ]);
      }
      expect(await work.agreementsFor(employment), hasLength(1));
      expect((await agreement()).effectiveEnd, isNull);
    });

    test('a date on or before confirmed leave is refused on From', () async {
      await fixture.saveDepot();
      await confirmLeave(const LocalDate(2026, 10, 6));
      final current = await agreement();

      final outcome = await service.changeAgreementTerms(
        change(current, from: const LocalDate(2026, 10, 6)),
      );

      expect((outcome as Invalid<PayAgreement>).fields['from'], [
        const FieldIssue(FieldIssueCode.conflict),
      ]);
    });

    test('a date outside the current range is refused on From', () async {
      final current = await agreement();
      expect(
        (await service.changeAgreementTerms(
          change(current, from: const LocalDate(2026, 9, 1)),
        ) as Invalid<PayAgreement>).fields['from'],
        [const FieldIssue(FieldIssueCode.outOfRange)],
      );
      final ended = (await service.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: employment,
          end: const LocalDate(2026, 12, 31),
          expectedRevision: current.revision,
        ),
      ) as Committed<PayAgreement>).value;
      expect(
        (await service.changeAgreementTerms(
          change(ended, from: const LocalDate(2027, 1, 1)),
        ) as Invalid<PayAgreement>).fields['from'],
        [const FieldIssue(FieldIssueCode.outOfRange)],
      );
    });

    test('invalid terms, stale and missing write nothing', () async {
      final current = await agreement();
      expect(
        (await service.changeAgreementTerms(
          change(current, from: const LocalDate(2026, 11, 1), rate: 0),
        ) as Invalid<PayAgreement>).fields.keys,
        contains('agreement'),
      );
      expect(
        await service.changeAgreementTerms(
          change(
            current,
            from: const LocalDate(2026, 11, 1),
            expected: const Revision(5),
          ),
        ),
        isA<Stale<PayAgreement>>(),
      );
      expect(
        await service.changeAgreementTerms(
          change(
            current,
            from: const LocalDate(2026, 11, 1),
            id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c29'),
          ),
        ),
        isA<Missing<PayAgreement>>(),
      );
      expect(await work.agreementsFor(employment), hasLength(1));
    });
  });

  group('widen an agreement in use', () {
    UpdateAgreementCommand update(
      PayAgreement current, {
      required LocalDate start,
      LocalDate? end,
      int rate = 18400000,
      Revision? expected,
    }) => UpdateAgreementCommand(
      agreementId: current.id,
      employmentId: employment,
      expectedRevision: expected ?? current.revision,
      // Fixture terms are the defaults, so only a new rate needs _terms.
      terms: rate == current.hourlyRateMicroEur
          ? AgreementTerms.of(
              current,
              effectiveStart: start,
              effectiveEnd: () => end,
            )
          : _terms(start: start, end: end, rate: rate),
    );

    Future<PayAgreement> used({LocalDate? end}) async {
      await fixture.saveDepot();
      await confirmShift(const LocalDate(2026, 10, 5));
      if (end != null) {
        final current = await agreement();
        await service.closeAgreement(
          CloseAgreementCommand(
            agreementId: current.id,
            employmentId: employment,
            end: end,
            expectedRevision: current.revision,
          ),
        );
      }
      final value = await agreement();
      expect(value.usedByFinalizedShift, isTrue);
      return value;
    }

    test('an earlier start, a later end and no end are accepted', () async {
      final current = await used(end: const LocalDate(2026, 12, 31));

      final earlier = await service.updateAgreement(
        update(
          current,
          start: const LocalDate(2026, 8, 1),
          end: const LocalDate(2026, 12, 31),
        ),
      );
      expect(earlier, isA<Committed<PayAgreement>>());
      expect((await agreement()).effectiveStart, const LocalDate(2026, 8, 1));

      final later = await service.updateAgreement(
        update(
          await agreement(),
          start: const LocalDate(2026, 8, 1),
          end: const LocalDate(2027, 3, 31),
        ),
      );
      expect(later, isA<Committed<PayAgreement>>());
      expect((await agreement()).effectiveEnd, const LocalDate(2027, 3, 31));

      final open = await service.updateAgreement(
        update(await agreement(), start: const LocalDate(2026, 8, 1)),
      );
      expect(open, isA<Committed<PayAgreement>>());
      final stored = await agreement();
      expect(stored.effectiveEnd, isNull);
      expect(stored.hourlyRateMicroEur, 18400000);
      expect(stored.revision, current.revision.next().next().next());
    });

    test('another change to terms in use is still refused', () async {
      final current = await used();

      final outcome = await service.updateAgreement(
        update(current, start: const LocalDate(2026, 8, 1), rate: 25000000),
      );

      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('agreement.inUse'),
      );
      expect((await agreement()).effectiveStart, const LocalDate(2026, 9, 1));
    });

    test('invalid dates are invalid terms, not a change in use', () async {
      final current = await used();

      final outcome = await service.updateAgreement(
        update(
          current,
          start: const LocalDate(2026, 8, 1),
          end: const LocalDate(2026, 7, 31),
        ),
      );

      final fields = (outcome as Invalid<PayAgreement>).fields;
      expect(fields.keys, contains('agreement'));
      expect(fields.keys, isNot(contains('agreement.inUse')));
      expect((await agreement()).effectiveStart, const LocalDate(2026, 9, 1));
    });

    test('narrowing in place is refused on the date moved', () async {
      final current = await used(end: const LocalDate(2026, 12, 31));

      final later = await service.updateAgreement(
        update(
          current,
          start: const LocalDate(2026, 9, 2),
          end: const LocalDate(2026, 12, 31),
        ),
      );
      expect((later as Invalid<PayAgreement>).fields['effectiveStart'], [
        const FieldIssue(FieldIssueCode.conflict),
      ]);
      final earlier = await service.updateAgreement(
        update(
          current,
          start: const LocalDate(2026, 9, 1),
          end: const LocalDate(2026, 12, 30),
        ),
      );
      expect((earlier as Invalid<PayAgreement>).fields['effectiveEnd'], [
        const FieldIssue(FieldIssueCode.conflict),
      ]);
    });

    test('widening into another agreement is an overlap', () async {
      final current = await used(end: const LocalDate(2026, 12, 31));
      await createSecond(start: const LocalDate(2027, 1, 1));

      final outcome = await service.updateAgreement(
        update(
          current,
          start: const LocalDate(2026, 9, 1),
          end: const LocalDate(2027, 1, 15),
        ),
      );

      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('effectiveRange'),
      );
    });

    test('a stale widen is reported', () async {
      final current = await used();
      expect(
        await service.updateAgreement(
          update(
            current,
            start: const LocalDate(2026, 8, 1),
            expected: const Revision(9),
          ),
        ),
        isA<Stale<PayAgreement>>(),
      );
    });

    test('an earlier start lets a refused day before it confirm', () async {
      // A rotation from 24 August, a week before the agreement starts.
      await fixture.saveDepot(from: const LocalDate(2026, 8, 24));
      await confirmShift(const LocalDate(2026, 9, 5));
      expect(
        await fixture.plans.confirm(employment, const LocalDate(2026, 8, 24)),
        isA<Invalid<ConfirmedDay>>(),
      );
      final current = await agreement();
      expect(current.usedByFinalizedShift, isTrue);

      expect(
        await service.updateAgreement(
          update(current, start: const LocalDate(2026, 8, 1)),
        ),
        isA<Committed<PayAgreement>>(),
      );

      expect(
        await fixture.plans.confirm(employment, const LocalDate(2026, 8, 24)),
        isA<Committed<ConfirmedDay>>(),
      );
    });
  });

  group('remove an unused agreement', () {
    DeleteAgreementCommand remove(
      PayAgreement current, {
      Revision? expected,
      AgreementId? id,
    }) => DeleteAgreementCommand(
      agreementId: id ?? current.id,
      employmentId: employment,
      expectedRevision: expected ?? current.revision,
    );

    test('removes it and its history', () async {
      final current = await agreement();

      final outcome = await service.deleteAgreement(remove(current));

      expect((outcome as Committed<PayAgreement>).value.id, current.id);
      expect(await work.agreementsFor(employment), isEmpty);
      final events = await fixture.database
          .select(fixture.database.recordEvents)
          .get();
      expect(events.where((row) => row.recordId == current.id.value), isEmpty);
    });

    test('a draft shift does not hold it; the draft resolves again at '
        'finalize', () async {
      await fixture.database
          .into(fixture.database.workShifts)
          .insert(shiftToCompanion(_draft()));

      final outcome = await service.deleteAgreement(remove(await agreement()));

      expect(outcome, isA<Committed<PayAgreement>>());
      expect(
        await fixture.database.select(fixture.database.workShifts).get(),
        hasLength(1),
      );
    });

    test('a finished shift keeps it', () async {
      await fixture.saveDepot();
      await confirmShift(const LocalDate(2026, 10, 5));

      final outcome = await service.deleteAgreement(remove(await agreement()));

      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('agreement.inUse'),
      );
      expect(await work.agreementsFor(employment), hasLength(1));
    });

    test('confirmed leave keeps it', () async {
      await fixture.saveDepot();
      await confirmLeave(const LocalDate(2026, 10, 6));
      final record =
          (await work.watchRecord(fixtureAgreement).first)!
              as AgreementRecordProjection;
      expect(record.use, AgreementUse.leave);

      final outcome = await service.deleteAgreement(remove(await agreement()));

      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('agreement.inUse'),
      );
    });

    test('stale and missing are reported', () async {
      final current = await agreement();
      expect(
        await service.deleteAgreement(
          remove(current, expected: const Revision(3)),
        ),
        isA<Stale<PayAgreement>>(),
      );
      expect(
        await service.deleteAgreement(
          remove(
            current,
            id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c29'),
          ),
        ),
        isA<Missing<PayAgreement>>(),
      );
      expect(await work.agreementsFor(employment), hasLength(1));
    });
  });

  group('end an agreement', () {
    CloseAgreementCommand end(
      PayAgreement current,
      LocalDate lastDay, {
      Revision? expected,
      AgreementId? id,
    }) => CloseAgreementCommand(
      agreementId: id ?? current.id,
      employmentId: employment,
      end: lastDay,
      expectedRevision: expected ?? current.revision,
    );

    test('an agreement in use ends on or after its last used day', () async {
      await fixture.saveDepot();
      await confirmShift(const LocalDate(2026, 10, 6));
      final current = await agreement();

      final outcome = await service.closeAgreement(
        end(current, const LocalDate(2026, 10, 6)),
      );

      expect(
        (outcome as Committed<PayAgreement>).value.effectiveEnd,
        const LocalDate(2026, 10, 6),
      );
      expect((await agreement()).effectiveEnd, const LocalDate(2026, 10, 6));
    });

    test('a last day before a finished shift is refused on it', () async {
      await fixture.saveDepot();
      await confirmShift(const LocalDate(2026, 10, 6));

      final outcome = await service.closeAgreement(
        end(await agreement(), const LocalDate(2026, 10, 5)),
      );

      expect((outcome as Invalid<PayAgreement>).fields['effectiveEnd'], [
        const FieldIssue(FieldIssueCode.conflict),
      ]);
      expect((await agreement()).effectiveEnd, isNull);
    });

    test('a last day before confirmed leave is refused on it', () async {
      await fixture.saveDepot();
      await confirmLeave(const LocalDate(2026, 10, 7));

      final outcome = await service.closeAgreement(
        end(await agreement(), const LocalDate(2026, 10, 6)),
      );

      expect((outcome as Invalid<PayAgreement>).fields['effectiveEnd'], [
        const FieldIssue(FieldIssueCode.conflict),
      ]);
    });

    test('a last day before the start is refused on it', () async {
      final outcome = await service.closeAgreement(
        end(await agreement(), const LocalDate(2026, 8, 31)),
      );

      expect((outcome as Invalid<PayAgreement>).fields['effectiveEnd'], [
        const FieldIssue(FieldIssueCode.outOfRange),
      ]);
    });

    test('a later last day must not overlap the next agreement', () async {
      final current = await agreement();
      final ended = (await service.closeAgreement(
        end(current, const LocalDate(2026, 12, 31)),
      ) as Committed<PayAgreement>).value;
      await createSecond(start: const LocalDate(2027, 1, 1));

      final outcome = await service.closeAgreement(
        end(ended, const LocalDate(2027, 1, 31)),
      );

      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('effectiveRange'),
      );
    });

    test('stale and missing are reported', () async {
      final current = await agreement();
      expect(
        await service.closeAgreement(
          end(
            current,
            const LocalDate(2026, 12, 31),
            expected: const Revision(2),
          ),
        ),
        isA<Stale<PayAgreement>>(),
      );
      expect(
        await service.closeAgreement(
          end(
            current,
            const LocalDate(2026, 12, 31),
            id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c29'),
          ),
        ),
        isA<Missing<PayAgreement>>(),
      );
    });
  });
}

Future<int?> _payOf(DriftWorkRepository work, ShiftId id) async =>
    ((await work.watchRecord(id).first)! as ShiftRecordProjection)
        .pay
        ?.amount
        .minorUnits;

AgreementTerms _terms({
  required LocalDate start,
  LocalDate? end,
  int rate = 18400000,
}) => AgreementTerms(
  effectiveStart: start,
  effectiveEnd: end,
  hourlyRateMicroEur: rate,
  basis: const GrossBasis(),
  label: null,
  note: null,
);

WorkShift _draft() => WorkShift(
  id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  employmentId: fixtureEmployment,
  agreementId: null,
  state: ShiftState.draft,
  startUtc: DateTime.utc(2026, 9, 10, 6),
  endUtc: DateTime.utc(2026, 9, 10, 14),
  timezoneId: 'Europe/Vilnius',
  localStartDate: const LocalDate(2026, 9, 10),
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 10),
  updatedAtUtc: DateTime.utc(2026, 9, 10),
  revision: const Revision(0),
);
