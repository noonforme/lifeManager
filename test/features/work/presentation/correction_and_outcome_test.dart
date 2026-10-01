import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/correction_confirmation.dart';
import 'package:lifeos/features/work/presentation/period_payslip_forms.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets('stale save keeps register and draft visible and offers reload', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'Work register',
                child: const Text('Existing register row'),
              ),
            ),
            Expanded(
              child: StaleConflictInspector(
                draft: const Text('Preserved correction draft'),
                onReload: () {},
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Work register'), findsOneWidget);
    expect(find.text('Preserved correction draft'), findsOneWidget);
    expect(
      find.text(
        'Your record is out of date. Reload and review before trying again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reload record'), findsOneWidget);
  });

  testWidgets(
    'finalized shift correction names the record and explains replacement history',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: CorrectionConfirmationInspector<WorkShift>(
            recordName: 'Shift on 2026-10-01',
            original: finalizedShift,
            onConfirm: (_, _) async => Committed(replacementShift),
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('Correct Shift on 2026-10-01'), findsOneWidget);
      expect(
        find.text(
          'The original remains in history and is excluded from active totals. A linked replacement will be created.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          FilledButton,
          'Void original and create replacement',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('committed correction selects the editable replacement', (
    tester,
  ) async {
    WorkShift? selected;
    await tester.pumpWidget(
      _TestApp(
        child: CorrectionConfirmationInspector<WorkShift>(
          recordName: 'Shift on 2026-10-01',
          original: finalizedShift,
          onConfirm: (_, reason) async {
            expect(reason, 'Correct synthetic shift');
            return Committed(replacementShift);
          },
          onCommitted: (value) => selected = value,
          onCancel: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      ' Correct synthetic shift ',
    );
    await tester.tap(find.text('Void original and create replacement'));
    await tester.pumpAndSettle();

    expect(selected?.id, replacementShiftId);
    expect(selected?.state, ShiftState.draft);
  });

  testWidgets('cancel preserves scope without invoking mutation', (
    tester,
  ) async {
    var mutationCount = 0;
    var cancelled = false;
    await tester.pumpWidget(
      _TestApp(
        child: CorrectionConfirmationInspector<WorkShift>(
          recordName: 'Shift on 2026-10-01',
          original: finalizedShift,
          onConfirm: (_, _) async {
            mutationCount += 1;
            return Committed(replacementShift);
          },
          onCancel: () => cancelled = true,
        ),
      ),
    );

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(cancelled, isTrue);
    expect(mutationCount, 0);
  });

  testWidgets('uncertain outcome requires reload and inspection', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestApp(child: UncertainOutcomeInspector()));

    expect(
      find.text(
        'The save result is uncertain. Reload and inspect the record before trying again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Do not retry yet.'), findsOneWidget);
  });

  test(
    'controller adapts review commands and navigates only on commit',
    () async {
      CreatePayPeriodCommand? createPeriod;
      SetPayPeriodStateCommand? setPeriodState;
      RecordPayslipCommand? recordPayslip;
      CorrectPayslipCommand? correctPayslip;
      CorrectShiftCommand? correctShift;
      final replaced = <WorkRouteState>[];
      final container = ProviderContainer(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(_QueryRepository()),
          workRouteProvider.overrideWithValue(
            const ValidWorkRoute(
              WorkRouteState(
                employmentId: employmentId,
                scope: PayPeriodScope(periodId),
                record: null,
                mode: WorkInspectorMode.inspect,
              ),
            ),
          ),
          replaceWorkRouteProvider.overrideWithValue(replaced.add),
          createPayPeriodProvider.overrideWithValue((command) async {
            createPeriod = command;
            return const Stale<PayPeriod>();
          }),
          setPayPeriodStateProvider.overrideWithValue((command) async {
            setPeriodState = command;
            return Committed(openPeriod);
          }),
          recordPayslipProvider.overrideWithValue((command) async {
            recordPayslip = command;
            return const Unavailable<Payslip>(
              SafeFailureCode.storageUnavailable,
            );
          }),
          correctPayslipProvider.overrideWithValue((command) async {
            correctPayslip = command;
            return Committed(replacementPayslip);
          }),
          correctShiftProvider.overrideWithValue((command) async {
            correctShift = command;
            return Committed(replacementShift);
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(workControllerProvider.future);
      final controller = container.read(workControllerProvider.notifier);

      const periodDraft = PayPeriodDraft(
        employmentId: employmentId,
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
        label: ' October ',
      );
      const payslipDraft = PayslipDraft(
        periodId: periodId,
        issuedDate: LocalDate(2026, 10, 31),
        paidDate: LocalDate(2026, 11, 1),
        amountMinorUnits: 123456,
        basis: GrossBasis(),
        grossMinorUnits: 150000,
        netMinorUnits: 123456,
        deductionMinorUnits: 26544,
        reference: ' SYNTHETIC-10 ',
        note: ' evidence ',
      );

      await controller.createPayPeriod(periodDraft);
      expect(controller.draft, same(periodDraft));
      expect(replaced, isEmpty);
      await controller.setPayPeriodState(reviewedPeriod, PayPeriodState.open);
      await controller.recordPayslip(payslipDraft);
      expect(controller.draft, same(payslipDraft));
      expect(replaced, hasLength(1));
      await controller.correctPayslip(
        originalPayslip,
        replacementId: replacementPayslipId,
        voidReason: ' Correct synthetic evidence ',
      );
      await controller.correctShift(
        finalizedShift,
        replacementId: replacementShiftId,
        voidReason: ' Correct synthetic shift ',
      );

      expect(createPeriod?.label, 'October');
      expect(setPeriodState?.id, periodId);
      expect(setPeriodState?.state, PayPeriodState.open);
      expect(setPeriodState?.expectedRevision, const Revision(3));
      expect(recordPayslip?.amountMinorUnits, 123456);
      expect(recordPayslip?.reference, 'SYNTHETIC-10');
      expect(recordPayslip?.note, 'evidence');
      expect(correctPayslip?.originalId, payslipId);
      expect(correctPayslip?.replacementId, replacementPayslipId);
      expect(correctPayslip?.expectedRevision, originalPayslip.revision);
      expect(correctPayslip?.voidReason, 'Correct synthetic evidence');
      expect(correctShift?.originalId, shiftId);
      expect(correctShift?.expectedRevision, finalizedShift.revision);
      expect(correctShift?.voidReason, 'Correct synthetic shift');
      expect(replaced, hasLength(3));
      expect(replaced[1].record?.id, replacementPayslipId);
      expect(replaced[1].employmentId, employmentId);
      expect(replaced[1].mode, WorkInspectorMode.inspect);
      expect(replaced[2].record?.id, replacementShiftId);
      expect(replaced[2].mode, WorkInspectorMode.edit);
    },
  );

  testWidgets('missing and unavailable outcomes provide distinct guidance', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestApp(child: MissingRecordInspector()));
    expect(
      find.text('This record is no longer available. Reload the register.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const _TestApp(
        child: UnavailableInspector(code: SafeFailureCode.storageUnavailable),
      ),
    );
    expect(
      find.text('Local storage is unavailable. Your draft has been kept.'),
      findsOneWidget,
    );
  });
}

const employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const shiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const replacementShiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');
const agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
const periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const payslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const replacementPayslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c62');

final reviewedPeriod = PayPeriod.rehydrate(
  id: periodId,
  employmentId: employmentId,
  start: const LocalDate(2026, 10, 1),
  end: const LocalDate(2026, 10, 31),
  label: 'October',
  state: PayPeriodState.reviewed,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 11, 1),
  revision: const Revision(3),
);

final openPeriod = PayPeriod.rehydrate(
  id: periodId,
  employmentId: employmentId,
  start: const LocalDate(2026, 10, 1),
  end: const LocalDate(2026, 10, 31),
  label: 'October',
  state: PayPeriodState.open,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 11, 2),
  revision: const Revision(4),
);

final originalPayslip = _payslip(id: payslipId, revision: const Revision(2));
final replacementPayslip = _payslip(
  id: replacementPayslipId,
  revision: const Revision(0),
  replacedPayslipId: payslipId,
);

Payslip _payslip({
  required PayslipId id,
  required Revision revision,
  PayslipId? replacedPayslipId,
}) => Payslip(
  id: id,
  periodId: periodId,
  issuedDate: const LocalDate(2026, 10, 31),
  paidDate: const LocalDate(2026, 11, 1),
  amount: const Money(minorUnits: 123456),
  basis: const GrossBasis(),
  grossMinorUnits: 150000,
  netMinorUnits: 123456,
  deductionMinorUnits: 26544,
  reference: 'SYNTHETIC-10',
  note: null,
  state: PayslipState.effective,
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: replacedPayslipId,
  createdAtUtc: DateTime.utc(2026, 11, 1),
  updatedAtUtc: DateTime.utc(2026, 11, 1),
  revision: revision,
);

WorkShift _shift({
  required ShiftId id,
  required ShiftState state,
  required Revision revision,
  ShiftId? replacedShiftId,
}) => WorkShift(
  id: id,
  employmentId: employmentId,
  agreementId: state == ShiftState.finalized ? agreementId : null,
  state: state,
  startUtc: DateTime.utc(2026, 10, 1, 8),
  endUtc: DateTime.utc(2026, 10, 1, 16),
  timezoneId: 'Europe/Amsterdam',
  localStartDate: const LocalDate(2026, 10, 1),
  overtimeMinutes: 0,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: replacedShiftId,
  createdAtUtc: DateTime.utc(2026, 10, 1, 8),
  updatedAtUtc: DateTime.utc(2026, 10, 1, 16),
  revision: revision,
);

final finalizedShift = _shift(
  id: shiftId,
  state: ShiftState.finalized,
  revision: const Revision(2),
);
final replacementShift = _shift(
  id: replacementShiftId,
  state: ShiftState.draft,
  revision: const Revision(0),
  replacedShiftId: shiftId,
);

final class _QueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildLifeOSTheme(highContrast: false),
    home: Scaffold(body: SizedBox(width: 900, height: 760, child: child)),
  );
}
