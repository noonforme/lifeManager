import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/data/work_converters.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  late AppDatabase database;
  late DriftWorkRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWorkRepository(database);
    await repository.insertEmployment(_employment());
    await repository.insertAgreement(_agreement);
    await repository.createPeriod(_period);
  });

  tearDown(() => database.close());

  test(
    'void payslip remains inspectable but leaves active paid total',
    () async {
      await repository.insertPayslip(_original);
      final replacement = _payslip(
        id: _replacementId,
        amountMinorUnits: 125000,
        replacedPayslipId: _original.id,
        createdAtUtc: DateTime.utc(2026, 10, 2),
      );

      expect(
        await repository.correctPayslip(
          _original.id,
          expected: const Revision(0),
          replacement: replacement,
          voidReason: 'Synthetic correction',
          nowUtc: DateTime.utc(2026, 10, 2),
        ),
        isA<Committed<Payslip>>(),
      );

      final original = await repository.payslipById(_original.id);
      expect(original!.state, PayslipState.voided);
      final register = await repository
          .watchRegister(
            const WorkScope(
              employmentId: _employmentId,
              temporal: PayPeriodScope(_periodId),
            ),
          )
          .first;
      expect(register.paid, const Money(minorUnits: 125000));
      expect(register.payslipRows.map((row) => row.id), [_replacementId]);

      final detail = await repository.watchRecord(_original.id).first;
      expect(detail, isA<PayslipRecordProjection>());
      expect(
        (detail! as PayslipRecordProjection).payslip.replacementPayslipId,
        _replacementId,
      );
    },
  );

  test(
    'register is employment and period bounded and omits row notes',
    () async {
      await repository.insertPayslip(_original);
      final register = await repository
          .watchRegister(
            const WorkScope(
              employmentId: _employmentId,
              temporal: PayPeriodScope(_periodId),
            ),
          )
          .first;

      expect(register.period?.id, _period.id);
      expect(register.period?.start, _period.start);
      expect(register.period?.end, _period.end);
      expect(register.payslipRows.single.note, isNull);
      final detail = await repository.watchRecord(_original.id).first;
      expect(
        (detail! as PayslipRecordProjection).payslip.note,
        'Selected note',
      );
    },
  );

  test('date range scope is inclusive and excludes outside shifts', () async {
    await database
        .into(database.workShifts)
        .insert(
          shiftToCompanion(
            _finalizedShift(_insideShiftId, const LocalDate(2026, 9, 10)),
          ),
        );
    await database
        .into(database.workShifts)
        .insert(
          shiftToCompanion(
            _finalizedShift(_outsideShiftId, const LocalDate(2026, 9, 11)),
          ),
        );

    final register = await repository
        .watchRegister(
          const WorkScope(
            employmentId: _employmentId,
            temporal: DateRangeScope(
              start: LocalDate(2026, 9, 10),
              end: LocalDate(2026, 9, 10),
            ),
          ),
        )
        .first;

    expect(register.shiftRows.map((row) => row.id), [_insideShiftId]);
    expect(register.shiftRows.single.note, isNull);
  });

  test('selected shift detail loads note only for that record', () async {
    await database
        .into(database.workShifts)
        .insert(
          shiftToCompanion(
            _finalizedShift(_insideShiftId, const LocalDate(2026, 9, 10)),
          ),
        );

    final detail = await repository.watchRecord(_insideShiftId).first;

    expect(detail, isA<ShiftRecordProjection>());
    final shiftDetail = detail! as ShiftRecordProjection;
    expect(shiftDetail.shift.note, 'Private shift note');
    expect(shiftDetail.breaks, isEmpty);
  });

  test(
    'ended draft shift detail carries the agreement overtime suggestion',
    () async {
      final draft = _draftShift(
        _insideShiftId,
        start: DateTime.utc(2026, 9, 10, 6),
        end: DateTime.utc(2026, 9, 10, 15, 30),
      );
      await database.into(database.workShifts).insert(shiftToCompanion(draft));
      await database
          .into(database.shiftBreaks)
          .insert(
            shiftBreakToCompanion(
              ShiftBreak(
                id: _breakId,
                shiftId: _insideShiftId,
                startUtc: DateTime.utc(2026, 9, 10, 11),
                endUtc: DateTime.utc(2026, 9, 10, 11, 30),
                createdAtUtc: DateTime.utc(2026, 9, 10, 11),
                updatedAtUtc: DateTime.utc(2026, 9, 10, 11, 30),
                revision: const Revision(1),
              ),
            ),
          );

      final detail =
          await repository.watchRecord(_insideShiftId).first
              as ShiftRecordProjection;

      expect(detail.suggestedOvertimeMinutes, 60);
    },
  );

  test('active shift projection follows the single running shift', () async {
    final running = WorkShift(
      id: _insideShiftId,
      employmentId: _employmentId,
      agreementId: null,
      state: ShiftState.running,
      startUtc: DateTime.utc(2026, 9, 10, 8),
      endUtc: null,
      timezoneId: 'Europe/Berlin',
      localStartDate: const LocalDate(2026, 9, 10),
      overtimeMinutes: 0,
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: DateTime.utc(2026, 9, 10, 8),
      updatedAtUtc: DateTime.utc(2026, 9, 10, 8),
      revision: const Revision(0),
    );

    expect(await repository.watchActiveShift().first, isNull);
    await database.into(database.workShifts).insert(shiftToCompanion(running));

    final active = await repository.watchActiveShift().first;
    expect(active?.shift.id, _insideShiftId);
    expect(active?.breaks, isEmpty);
  });

  test('selected period record refreshes after a committed state change', () async {
    final updates = repository.watchRecord(_periodId).take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await repository.setPeriodState(
      _periodId,
      state: PayPeriodState.reviewed,
      expected: _period.revision,
      nowUtc: DateTime.utc(2026, 10, 2),
    );

    final values = await updates.timeout(const Duration(seconds: 2));
    expect(
      (values.last! as PayPeriodRecordProjection).period.state,
      PayPeriodState.reviewed,
    );
  });

  test('employment scope without a period lists its pay periods', () async {
    final register = await repository
        .watchRegister(
          const WorkScope(employmentId: _employmentId, temporal: null),
        )
        .first;

    expect(register.periodRows.map((period) => period.id), [_periodId]);
  });

  test('stale payslip correction rolls back replacement insertion', () async {
    await repository.insertPayslip(_original);
    final replacement = _payslip(
      id: _replacementId,
      amountMinorUnits: 125000,
      replacedPayslipId: _original.id,
      createdAtUtc: DateTime.utc(2026, 10, 2),
    );

    final outcome = await repository.correctPayslip(
      _original.id,
      expected: const Revision(1),
      replacement: replacement,
      voidReason: 'Synthetic correction',
      nowUtc: DateTime.utc(2026, 10, 2),
    );

    expect(outcome, isA<Stale<Payslip>>());
    expect(await repository.payslipById(_replacementId), isNull);
    expect((await repository.payslipById(_originalId))!.isEffective, isTrue);
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _originalId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const _replacementId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c62');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
const _insideShiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const _breakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c33');
const _outsideShiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');

Employment _employment() => Employment.create(
  id: _employmentId,
  name: 'Synthetic employer',
  legalLabel: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final _agreement = PayAgreement(
  id: _agreementId,
  employmentId: _employmentId,
  version: 1,
  effectiveStart: const LocalDate(2026, 9, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 20000000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026, 9, 1),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);

final _period = PayPeriod.create(
  id: _periodId,
  employmentId: _employmentId,
  start: const LocalDate(2026, 9, 1),
  end: const LocalDate(2026, 9, 30),
  label: 'September',
  nowUtc: DateTime.utc(2026, 9, 1),
);

final _original = _payslip(
  id: _originalId,
  amountMinorUnits: 100000,
  createdAtUtc: DateTime.utc(2026, 10, 1),
);

WorkShift _finalizedShift(ShiftId id, LocalDate date) => WorkShift(
  id: id,
  employmentId: _employmentId,
  agreementId: _agreementId,
  state: ShiftState.finalized,
  startUtc: DateTime.utc(date.year, date.month, date.day, 8),
  endUtc: DateTime.utc(date.year, date.month, date.day, 16),
  timezoneId: 'Europe/Berlin',
  localStartDate: date,
  overtimeMinutes: 0,
  note: 'Private shift note',
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(date.year, date.month, date.day, 8),
  updatedAtUtc: DateTime.utc(date.year, date.month, date.day, 16),
  revision: const Revision(1),
);

Payslip _payslip({
  required PayslipId id,
  required int amountMinorUnits,
  required DateTime createdAtUtc,
  PayslipId? replacedPayslipId,
}) => Payslip(
  id: id,
  periodId: _periodId,
  issuedDate: const LocalDate(2026, 9, 30),
  paidDate: const LocalDate(2026, 10, 1),
  amount: Money(minorUnits: amountMinorUnits),
  basis: const GrossBasis(),
  grossMinorUnits: amountMinorUnits,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: 'Synthetic reference',
  note: 'Selected note',
  state: PayslipState.effective,
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: replacedPayslipId,
  createdAtUtc: createdAtUtc,
  updatedAtUtc: createdAtUtc,
  revision: const Revision(0),
);

WorkShift _draftShift(
  ShiftId id, {
  required DateTime start,
  required DateTime end,
}) => WorkShift(
  id: id,
  employmentId: _employmentId,
  agreementId: null,
  state: ShiftState.draft,
  startUtc: start,
  endUtc: end,
  timezoneId: 'Europe/Berlin',
  localStartDate: LocalDate(start.year, start.month, start.day),
  overtimeMinutes: 0,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: start,
  updatedAtUtc: end,
  revision: const Revision(2),
);
