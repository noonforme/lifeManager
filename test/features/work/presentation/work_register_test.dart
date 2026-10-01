import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/daos/shift_dao.dart';
import 'package:lifeos/features/work/data/projections/reconciliation_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_register.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets('empty register gives a first-run employment action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestWorkRegister(
        projection: WorkRegisterProjection.empty(
          const WorkScope(employmentId: null, temporal: null),
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
    expect(
      find.text(
        'Track shifts, see what you should be paid, and compare it with '
        'your payslips. Start by adding where you work.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Create employment'),
      findsOneWidget,
    );
  });

  testWidgets('first launch Create employment opens the form in one press', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(
      _TestWorkRegister(
        projection: WorkRegisterProjection.empty(
          const WorkScope(employmentId: null, temporal: null),
        ),
        onCreateEmployment: () => created++,
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create employment'));
    expect(created, 1);
  });

  testWidgets('the Employment control switches, lists all and creates', (
    tester,
  ) async {
    final opened = <EmploymentId>[];
    var all = 0;
    var created = 0;
    await tester.pumpWidget(
      _TestWorkRegister(
        projection: _withEmployments(),
        onOpenEmployment: opened.add,
        onAllEmployments: () => all++,
        onCreateEmployment: () => created++,
      ),
    );

    Future<void> choose(String label) async {
      await tester.tap(find.text('Employment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Employment'));
    await tester.pumpAndSettle();
    final current = find.ancestor(
      of: find.text('Warehouse').last,
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: current.first, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(find.text('All employments'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await choose('Café');
    await choose('All employments');
    await choose('Create employment');
    expect(opened, [_otherEmploymentId]);
    expect(all, 1);
    expect(created, 1);
  });

  testWidgets('unavailable projection is explicit and recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestWorkRegister(projection: null));

    expect(find.text('Work records unavailable'), findsOneWidget);
    expect(
      find.text('Reload Work to inspect the current records.'),
      findsOneWidget,
    );
  });

  testWidgets('single click selects a typed shift record', (tester) async {
    final selected = <WorkRecordRef>[];
    await tester.pumpWidget(
      _TestWorkRegister(projection: _projection(), onSelect: selected.add),
    );

    await tester.tap(find.bySemanticsLabel('Shift on 2026-09-29'));

    expect(selected, hasLength(1));
    expect(selected.single.kind, WorkRecordKind.shift);
    expect(selected.single.id, _shiftId);
  });

  testWidgets('summary labels expected and paid evidence truthfully', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestWorkRegister(projection: _reconciliationProjection()),
    );

    expect(find.text('Expected under recorded agreement'), findsOneWidget);
    expect(find.text('Paid evidence'), findsOneWidget);
    final paid = tester.widget<Text>(find.text('EUR 95.00'));
    expect(
      paid.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('summary never combines gross and net differences', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestWorkRegister(projection: _mixedBasisProjection()),
    );

    expect(find.text('Gross · EUR'), findsOneWidget);
    expect(find.text('Net · EUR'), findsOneWidget);
    expect(find.text('Expected under recorded agreement'), findsNWidgets(2));
    expect(find.text('Paid evidence'), findsNWidgets(2));
    expect(find.text('Combined difference'), findsNothing);
  });

  testWidgets('two-times text scale keeps all toolbar controls reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _TestWorkRegister(projection: _projection(), textScale: 2),
    );

    for (final label in ['Employment', 'Scope', 'Status']) {
      final control = find.widgetWithText(OutlinedButton, label);
      expect(control, findsOneWidget);
      await tester.ensureVisible(control);
    }
    final primaryAction = find.widgetWithText(FilledButton, 'Add shift');
    expect(primaryAction, findsOneWidget);
    await tester.ensureVisible(primaryAction);
    expect(tester.takeException(), isNull);
  });
}

final class _TestWorkRegister extends StatelessWidget {
  const _TestWorkRegister({
    required this.projection,
    this.onSelect,
    this.textScale = 1,
    this.onOpenEmployment,
    this.onAllEmployments,
    this.onCreateEmployment,
  });

  final WorkRegisterProjection? projection;
  final ValueChanged<WorkRecordRef>? onSelect;
  final double textScale;
  final ValueChanged<EmploymentId>? onOpenEmployment;
  final VoidCallback? onAllEmployments;
  final VoidCallback? onCreateEmployment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: LifeOSSkinScope(
          child: Scaffold(
            body: WorkRegister(
              projection: projection,
              selectedRecord: null,
              onSelect: onSelect ?? (_) {},
              onPrimaryAction: () {},
              onOpenEmployment: onOpenEmployment,
              onAllEmployments: onAllEmployments,
              onCreateEmployment: onCreateEmployment,
            ),
          ),
        ),
      ),
    );
  }
}

WorkRegisterProjection _reconciliationProjection() => WorkRegisterProjection(
  scope: const WorkScope(
    employmentId: _employmentId,
    temporal: PayPeriodScope(_periodId),
  ),
  period: _period,
  shiftRows: const [],
  payslipRows: const [],
  paid: const Money(minorUnits: 9500),
  reconciliation: ReconciliationProjection(
    period: _period,
    shiftFacts: const [],
    payslipEvidence: const [],
    groups: [
      _group(
        basis: const GrossBasis(),
        expected: 10000,
        paid: 9500,
        difference: -500,
      ),
    ],
  ),
);

WorkRegisterProjection _mixedBasisProjection() => WorkRegisterProjection(
  scope: const WorkScope(
    employmentId: _employmentId,
    temporal: PayPeriodScope(_periodId),
  ),
  period: _period,
  shiftRows: const [],
  payslipRows: const [],
  paid: const Money(minorUnits: 16700),
  reconciliation: ReconciliationProjection(
    period: _period,
    shiftFacts: const [],
    payslipEvidence: const [],
    groups: [
      _group(
        basis: const GrossBasis(),
        expected: 10000,
        paid: 9500,
        difference: -500,
      ),
      _group(
        basis: const NetBasis(),
        expected: null,
        paid: 7200,
        difference: null,
      ),
    ],
  ),
);

ReconciliationGroup _group({
  required RateBasis basis,
  required int? expected,
  required int? paid,
  required int? difference,
}) => ReconciliationGroup(
  employmentId: _employmentId,
  periodId: _periodId,
  currency: const CurrencyCode.eur(),
  basis: basis,
  regularPaidSeconds: 0,
  overtimePaidSeconds: 0,
  expected: expected == null ? null : Money(minorUnits: expected),
  paid: paid == null ? null : Money(minorUnits: paid),
  difference: difference == null ? null : Money(minorUnits: difference),
  shiftIds: const [],
  payslipIds: const [],
  status: difference == null ? const UnmatchedPayslip() : const Difference(),
);

final _period = PayPeriod.create(
  id: _periodId,
  employmentId: _employmentId,
  start: const LocalDate(2026, 9, 1),
  end: const LocalDate(2026, 9, 30),
  label: 'September',
  nowUtc: DateTime.utc(2026, 9, 1),
);

WorkRegisterProjection _projection() => WorkRegisterProjection(
  scope: const WorkScope(employmentId: _employmentId, temporal: null),
  period: null,
  shiftRows: [
    ShiftRegisterRow(
      id: _shiftId,
      localStartDate: '2026-09-29',
      startUtc: DateTime.utc(2026, 9, 29, 8),
      endUtc: DateTime.utc(2026, 9, 29, 16),
      state: ShiftState.finalized,
    ),
  ],
  payslipRows: const [],
  paid: const Money(minorUnits: 12345),
  reconciliation: null,
);

WorkRegisterProjection _withEmployments() {
  Employment employment(EmploymentId id, String name) => Employment(
    id: id,
    name: name,
    legalLabel: null,
    status: EmploymentStatus.active,
    createdAtUtc: DateTime.utc(2026, 9),
    updatedAtUtc: DateTime.utc(2026, 9),
    revision: const Revision(0),
  );
  final warehouse = employment(_employmentId, 'Warehouse');
  return WorkRegisterProjection(
    scope: const WorkScope(employmentId: _employmentId, temporal: null),
    period: null,
    shiftRows: const [],
    payslipRows: const [],
    paid: const Money(minorUnits: 0),
    reconciliation: null,
    employment: warehouse,
    availableEmployments: [warehouse, employment(_otherEmploymentId, 'Café')],
  );
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _otherEmploymentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c12');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');
