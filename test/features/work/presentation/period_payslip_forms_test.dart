import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/presentation/period_payslip_forms.dart';
import 'package:lifeos/features/work/presentation/work_inspector.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets(
    'mixed gross and net evidence remains separate and has no combined difference',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: ReconciliationInspector(
            groups: [
              _group(
                basis: const GrossBasis(),
                expected: 10000,
                paid: 9500,
                difference: -500,
                status: const Difference(),
              ),
              _group(
                basis: const NetBasis(),
                expected: null,
                paid: 7200,
                difference: null,
                status: const UnmatchedPayslip(),
              ),
            ],
          ),
        ),
      );

      expect(
        find.text('Gross and net evidence cannot be combined.'),
        findsOneWidget,
      );
      expect(find.text('Gross · EUR'), findsOneWidget);
      expect(find.text('Net · EUR'), findsOneWidget);
      expect(find.text('Expected under recorded agreement'), findsNWidgets(2));
      expect(find.text('Paid evidence'), findsNWidgets(2));
      expect(find.text('Single difference'), findsNothing);
    },
  );

  testWidgets('multiple compatible payslips render one truthful paid total', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: ReconciliationInspector(
          groups: [
            _group(
              basis: const GrossBasis(),
              expected: 10000,
              paid: 10000,
              difference: 0,
              status: const Balanced(),
              payslipIds: const [payslipId, replacementPayslipId],
            ),
          ],
        ),
      ),
    );

    expect(find.text('Paid evidence'), findsOneWidget);
    expect(find.text('EUR 100.00'), findsNWidgets(2));
    expect(find.text('2 payslips'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
  });

  testWidgets('every reconciliation state explains the recorded evidence', (
    tester,
  ) async {
    const cases = <(ReconciliationStatus, String)>[
      (Balanced(), 'Expected and paid evidence balance.'),
      (Difference(), 'Paid evidence differs from the recorded agreement.'),
      (MissingPayslip(), 'No paid evidence is recorded for this estimate.'),
      (UnmatchedPayslip(), 'Paid evidence has no compatible estimate.'),
      (UnavailableReconciliation(), 'Reconciliation is unavailable.'),
      (EmptyReconciliation(), 'No compatible evidence is recorded.'),
    ];

    for (final entry in cases) {
      await tester.pumpWidget(
        _TestApp(
          child: ReconciliationInspector(
            groups: [
              _group(
                basis: const GrossBasis(),
                expected: null,
                paid: null,
                difference: null,
                status: entry.$1,
              ),
            ],
          ),
        ),
      );
      expect(find.text(entry.$2), findsOneWidget);
    }
  });

  testWidgets(
    'period creation submits explicit dates and retains invalid draft',
    (tester) async {
      PayPeriodDraft? submitted;
      await tester.pumpWidget(
        _TestApp(
          child: PeriodInspector.create(
            employmentId: employmentId,
            onSubmit: (draft) async {
              submitted = draft;
              return const Invalid<PayPeriod>({
                'range': [FieldIssue(FieldIssueCode.invalid)],
              });
            },
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('period-start')),
        '2026-10-01',
      );
      await tester.enterText(
        find.byKey(const ValueKey('period-end')),
        '2026-10-31',
      );
      await tester.enterText(
        find.byKey(const ValueKey('period-label')),
        'October',
      );
      await tester.tap(find.text('Create period'));
      await tester.pumpAndSettle();

      expect(submitted?.start, const LocalDate(2026, 10, 1));
      expect(submitted?.end, const LocalDate(2026, 10, 31));
      expect(submitted?.label, 'October');
      expect(find.text('October'), findsOneWidget);
      expect(find.text('Check the period date range.'), findsOneWidget);
    },
  );

  testWidgets('reviewed period can be reopened with its current revision', (
    tester,
  ) async {
    PayPeriod? reopened;
    await tester.pumpWidget(
      _TestApp(
        child: PeriodInspector(
          period: reviewedPeriod,
          onSetState: (period, state) async {
            expect(state, PayPeriodState.open);
            expect(period.revision, const Revision(3));
            reopened = period;
            return Committed(openPeriod);
          },
        ),
      ),
    );

    expect(find.text('Reviewed'), findsOneWidget);
    await tester.tap(find.text('Reopen period'));
    await tester.pumpAndSettle();
    expect(reopened?.id, periodId);
  });

  testWidgets(
    'record inspector does not offer period mutation without a callback',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: WorkInspector.fromRecord(
            projection: PayPeriodRecordProjection(reviewedPeriod),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Pay period'), findsOneWidget);
      expect(find.text('Reviewed'), findsOneWidget);
      expect(find.text('Reopen period'), findsNothing);
    },
  );

  testWidgets(
    'projection inspector renders selected period and payslip facts',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: WorkInspector.fromRecord(
            projection: PayPeriodRecordProjection(reviewedPeriod),
            onSetPeriodState: (_, _) async => Committed(openPeriod),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Pay period'), findsOneWidget);
      expect(find.text('October'), findsOneWidget);

      await tester.pumpWidget(
        _TestApp(
          child: WorkInspector.fromRecord(
            projection: PayslipRecordProjection(recordedPayslip),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Payslip'), findsOneWidget);
      expect(find.text('Paid evidence'), findsOneWidget);
      expect(find.text('EUR 1234.56'), findsOneWidget);
      expect(find.text('Gross'), findsOneWidget);
    },
  );

  testWidgets('invalid payslip save preserves entered evidence and errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: PayslipInspector.create(
          periodId: periodId,
          onSubmit: (_) async => const Invalid<Payslip>({
            'amount': [FieldIssue(FieldIssueCode.invalid)],
          }),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('payslip-issued-date')),
      '2026-10-31',
    );
    await tester.enterText(
      find.byKey(const ValueKey('payslip-amount')),
      '1234.56',
    );
    await tester.enterText(
      find.byKey(const ValueKey('payslip-reference')),
      'SYNTHETIC-10',
    );
    final save = find.text('Save payslip');
    await tester.scrollUntilVisible(
      save,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('1234.56'), findsOneWidget);
    expect(find.text('SYNTHETIC-10'), findsOneWidget);
    expect(find.text('Enter a valid amount.'), findsOneWidget);
  });
}

ReconciliationGroup _group({
  required RateBasis basis,
  required int? expected,
  required int? paid,
  required int? difference,
  required ReconciliationStatus status,
  List<PayslipId> payslipIds = const [],
}) => ReconciliationGroup(
  employmentId: employmentId,
  periodId: periodId,
  currency: const CurrencyCode.eur(),
  basis: basis,
  regularPaidSeconds: 0,
  overtimePaidSeconds: 0,
  expected: expected == null ? null : Money(minorUnits: expected),
  paid: paid == null ? null : Money(minorUnits: paid),
  difference: difference == null ? null : Money(minorUnits: difference),
  shiftIds: const [],
  payslipIds: payslipIds,
  status: status,
);

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
  updatedAtUtc: DateTime.utc(2026, 11, 1),
  revision: const Revision(4),
);

final recordedPayslip = Payslip(
  id: payslipId,
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
  replacedPayslipId: null,
  createdAtUtc: DateTime.utc(2026, 11, 1),
  updatedAtUtc: DateTime.utc(2026, 11, 1),
  revision: const Revision(0),
);

const employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const payslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const replacementPayslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c62');

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildLifeOSTheme(highContrast: false),
    home: Scaffold(body: SizedBox(width: 520, height: 760, child: child)),
  );
}
