import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/employment_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/data/work_converters.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  late AppDatabase database;
  late DriftWorkRepository repository;
  late EmploymentService employments;
  late AgreementService agreements;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWorkRepository(database);
    final ids = _Ids();
    employments = EmploymentService(
      repository,
      idFactory: ids,
      clock: const _Clock(),
    );
    agreements = AgreementService(
      repository,
      idFactory: ids,
      clock: const _Clock(),
    );
    await employments.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic', legalLabel: null),
    );
  });

  tearDown(() => database.close());

  Future<PayAgreement> createAgreement({
    LocalDate start = const LocalDate(2026, 9, 1),
    LocalDate? end,
  }) async {
    final outcome = await agreements.createAgreement(
      CreateAgreementCommand(
        employmentId: _employmentId,
        version: 1,
        terms: _terms(start: start, end: end),
      ),
    );
    return (outcome as Committed<PayAgreement>).value;
  }

  group('update employment', () {
    test('renames with trimmed facts and a new revision', () async {
      final outcome = await employments.updateEmployment(
        const UpdateEmploymentCommand(
          employmentId: _employmentId,
          expectedRevision: Revision(0),
          name: '  Warehouse  ',
          legalLabel: '  Synthetic Logistics UAB ',
        ),
      );

      final value = (outcome as Committed<Employment>).value;
      expect(value.name, 'Warehouse');
      expect(value.legalLabel, 'Synthetic Logistics UAB');
      final stored = (await repository.employmentById(_employmentId))!;
      expect(stored.name, 'Warehouse');
      expect(stored.revision, const Revision(1));
    });

    test('stale, missing and empty names are refused', () async {
      expect(
        await employments.updateEmployment(
          const UpdateEmploymentCommand(
            employmentId: _employmentId,
            expectedRevision: Revision(4),
            name: 'Warehouse',
            legalLabel: null,
          ),
        ),
        isA<Stale<Employment>>(),
      );
      expect(
        await employments.updateEmployment(
          const UpdateEmploymentCommand(
            employmentId: EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c19'),
            expectedRevision: Revision(0),
            name: 'Warehouse',
            legalLabel: null,
          ),
        ),
        isA<Missing<Employment>>(),
      );
      expect(
        await employments.updateEmployment(
          const UpdateEmploymentCommand(
            employmentId: _employmentId,
            expectedRevision: Revision(0),
            name: '  ',
            legalLabel: null,
          ),
        ),
        isA<Invalid<Employment>>(),
      );
    });
  });

  group('delete employment', () {
    const command = DeleteEmploymentCommand(
      employmentId: _employmentId,
      expectedRevision: Revision(0),
    );

    test('deletes the employment and its agreements together', () async {
      await createAgreement();

      expect(
        await employments.deleteEmployment(command),
        isA<Committed<Employment>>(),
      );
      expect(await repository.employmentById(_employmentId), isNull);
      expect(await repository.agreementsFor(_employmentId), isEmpty);
    });

    test('a shift is history', () async {
      final agreement = await createAgreement();
      await database
          .into(database.workShifts)
          .insert(shiftToCompanion(_finalizedShift(agreement.id)));

      final outcome = await employments.deleteEmployment(command);

      expect(
        (outcome as Invalid<Employment>).fields.keys,
        contains('employment.hasHistory'),
      );
      expect(await repository.employmentById(_employmentId), isNotNull);
      expect(await repository.agreementsFor(_employmentId), hasLength(1));
    });

    test('a pay period is history', () async {
      await repository.createPeriod(_period());

      final outcome = await employments.deleteEmployment(command);

      expect(
        (outcome as Invalid<Employment>).fields.keys,
        contains('employment.hasHistory'),
      );
    });

    test('stale and missing are reported', () async {
      expect(
        await employments.deleteEmployment(
          const DeleteEmploymentCommand(
            employmentId: _employmentId,
            expectedRevision: Revision(3),
          ),
        ),
        isA<Stale<Employment>>(),
      );
      expect(
        await employments.deleteEmployment(
          const DeleteEmploymentCommand(
            employmentId: EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c19'),
            expectedRevision: Revision(0),
          ),
        ),
        isA<Missing<Employment>>(),
      );
    });
  });

  group('update agreement', () {
    UpdateAgreementCommand update(
      PayAgreement agreement, {
      AgreementTerms? terms,
      Revision? expected,
    }) => UpdateAgreementCommand(
      agreementId: agreement.id,
      employmentId: _employmentId,
      expectedRevision: expected ?? agreement.revision,
      terms: terms ?? _terms(),
    );

    test('rewrites every term of an unused agreement', () async {
      final agreement = await createAgreement();

      final outcome = await agreements.updateAgreement(
        update(
          agreement,
          terms: _terms(
            rate: 21000000,
            nightEnabled: false,
            stacking: PremiumStacking.additive,
            calendar: HolidayCalendar.none,
          ),
        ),
      );

      expect(outcome, isA<Committed<PayAgreement>>());
      final stored = (await repository.agreementsFor(_employmentId)).single;
      expect(stored.hourlyRateMicroEur, 21000000);
      expect(stored.nightEnabled, isFalse);
      expect(stored.premiumStacking, PremiumStacking.additive);
      expect(stored.holidayCalendar, HolidayCalendar.none);
      expect(stored.revision, const Revision(1));
    });

    test('an agreement used by a finalized shift stays as it is', () async {
      final agreement = await createAgreement();
      await database
          .into(database.workShifts)
          .insert(shiftToCompanion(_finalizedShift(agreement.id)));

      final outcome = await agreements.updateAgreement(
        update(agreement, terms: _terms(rate: 25000000)),
      );

      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('agreement.inUse'),
      );
      expect(
        (await repository.agreementsFor(_employmentId))
            .single
            .hourlyRateMicroEur,
        18400000,
      );
    });

    test('a new range must not overlap another agreement', () async {
      final first = await createAgreement(end: const LocalDate(2026, 9, 30));
      final secondOutcome = await agreements.createAgreement(
        CreateAgreementCommand(
          employmentId: _employmentId,
          version: 2,
          terms: _terms(start: const LocalDate(2026, 10, 1)),
        ),
      );
      expect(secondOutcome, isA<Committed<PayAgreement>>());

      final outcome = await agreements.updateAgreement(
        update(first, terms: _terms(end: const LocalDate(2026, 10, 15))),
      );

      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('effectiveRange'),
      );
    });

    test('a multiplier below 1 is invalid terms', () async {
      final agreement = await createAgreement();
      final outcome = await agreements.updateAgreement(
        update(
          agreement,
          terms: _terms(
            night: const RationalMultiplier(numerator: 1, denominator: 2),
          ),
        ),
      );
      expect(
        (outcome as Invalid<PayAgreement>).fields.keys,
        contains('agreement'),
      );
    });

    test('stale and missing are reported', () async {
      final agreement = await createAgreement();
      expect(
        await agreements.updateAgreement(
          update(agreement, expected: const Revision(7)),
        ),
        isA<Stale<PayAgreement>>(),
      );
      expect(
        await agreements.updateAgreement(
          UpdateAgreementCommand(
            agreementId: const AgreementId(
              '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c29',
            ),
            employmentId: _employmentId,
            expectedRevision: const Revision(0),
            terms: _terms(),
          ),
        ),
        isA<Missing<PayAgreement>>(),
      );
    });
  });

  test('a new agreement takes the premium defaults', () async {
    final agreement = await createAgreement();
    expect(agreement.overtimeThresholdMinutes, 480);
    expect(agreement.nightEnabled, isTrue);
    expect(agreement.nightStartMinute, 22 * 60);
    expect(agreement.nightEndMinute, 6 * 60);
    expect(agreement.holidayCalendar, HolidayCalendar.lithuania);
    expect(agreement.premiumStacking, PremiumStacking.highest);
  });

  group('register projection', () {
    Future<WorkRegisterProjection> setup() => repository
        .watchRegister(
          const WorkScope(employmentId: _employmentId, temporal: null),
        )
        .first;

    test(
      'reports the current agreement and that setup can be deleted',
      () async {
        expect((await setup()).currentAgreement, isNull);
        expect((await setup()).canDeleteEmployment, isTrue);

        await createAgreement(end: const LocalDate(2026, 9, 30));
        await agreements.createAgreement(
          CreateAgreementCommand(
            employmentId: _employmentId,
            version: 2,
            terms: _terms(start: const LocalDate(2026, 10, 1)),
          ),
        );

        final projection = await setup();
        expect(projection.currentAgreement?.version, 2);
        expect(projection.agreementInUse, isFalse);
        expect(projection.canDeleteEmployment, isTrue);
      },
    );

    test('a finalized shift record carries its expected pay', () async {
      final agreement = await createAgreement();
      await database
          .into(database.workShifts)
          .insert(shiftToCompanion(_finalizedShift(agreement.id)));

      final record =
          await repository
                  .watchRecord(
                    const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
                  )
                  .first
              as ShiftRecordProjection;
      // 09:00 to 17:00 in Vilnius at EUR 18.40/h.
      expect(record.pay?.totalPaidSeconds, 8 * 3600);
      expect(record.pay?.amount.minorUnits, 14720);
      expect(record.facts?.agreement.id, agreement.id);

      final agreementRecord =
          await repository.watchRecord(agreement.id).first
              as AgreementRecordProjection;
      expect(agreementRecord.finishedShifts, 1);
      expect(agreementRecord.inUse, isTrue);
    });

    test('history blocks delete and use locks the agreement', () async {
      final agreement = await createAgreement();
      await database
          .into(database.workShifts)
          .insert(shiftToCompanion(_finalizedShift(agreement.id)));

      final projection = await setup();
      expect(projection.canDeleteEmployment, isFalse);
      expect(projection.agreementInUse, isTrue);
    });
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');

AgreementTerms _terms({
  LocalDate start = const LocalDate(2026, 9, 1),
  LocalDate? end,
  int rate = 18400000,
  bool nightEnabled = true,
  RationalMultiplier night = AgreementDefaults.nightMultiplier,
  HolidayCalendar calendar = HolidayCalendar.lithuania,
  PremiumStacking stacking = PremiumStacking.highest,
}) => AgreementTerms(
  effectiveStart: start,
  effectiveEnd: end,
  hourlyRateMicroEur: rate,
  basis: const GrossBasis(),
  label: null,
  note: null,
  nightEnabled: nightEnabled,
  nightMultiplier: night,
  holidayCalendar: calendar,
  premiumStacking: stacking,
);

WorkShift _finalizedShift(AgreementId agreement) => WorkShift(
  id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  employmentId: _employmentId,
  agreementId: agreement,
  state: ShiftState.finalized,
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
  revision: const Revision(1),
);

PayPeriod _period() => PayPeriod.create(
  id: const PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51'),
  employmentId: _employmentId,
  start: const LocalDate(2026, 9, 1),
  end: const LocalDate(2026, 9, 30),
  label: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final class _Ids implements WorkIdFactory {
  var _agreements = 0;

  @override
  EmploymentId employmentId() => _employmentId;

  @override
  AgreementId agreementId() =>
      AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c2${_agreements++}');
}

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 30, 10);
}
