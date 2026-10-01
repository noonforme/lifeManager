import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/features/work/presentation/work_screen.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    AsyncValue<WorkViewState> state,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_TestScreen(state: state));
  }

  testWidgets('screen keeps frame mounted while Work is loading', (
    tester,
  ) async {
    await pumpScreen(tester, const AsyncLoading());

    expect(find.bySemanticsLabel('System navigation'), findsOneWidget);
    expect(find.text('Loading Work records'), findsOneWidget);
  });

  testWidgets('screen renders invalid scope without substituting a register', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const AsyncData(WorkInvalidScope(WorkRouteProblem.malformedScope)),
    );

    expect(find.text('Invalid Work scope'), findsOneWidget);
    expect(find.textContaining('today'), findsNothing);
  });

  testWidgets('selected payslip renders recorded evidence in the inspector', (
    tester,
  ) async {
    final route = WorkRouteState(
      employmentId: _employmentId,
      scope: const PayPeriodScope(_periodId),
      record: const WorkRecordRef(kind: WorkRecordKind.payslip, id: _payslipId),
      mode: WorkInspectorMode.inspect,
    );
    final ready = WorkReady(
      register: WorkRegisterProjection.empty(
        const WorkScope(
          employmentId: _employmentId,
          temporal: PayPeriodScope(_periodId),
        ),
      ),
      route: route,
      inspector: WorkInspectorRecord(PayslipRecordProjection(_payslip)),
    );

    await pumpScreen(tester, AsyncData(ready));

    final inspector = find.bySemanticsLabel('Payslip');
    expect(inspector, findsOneWidget);
    expect(
      find.descendant(of: inspector, matching: find.text('Paid evidence')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inspector, matching: find.text('EUR 1234.56')),
      findsOneWidget,
    );
    expect(find.text('Work record selected'), findsNothing);
  });

  testWidgets('missing selected record remains unavailable in the inspector', (
    tester,
  ) async {
    final route = WorkRouteState(
      employmentId: _employmentId,
      scope: null,
      record: const WorkRecordRef(kind: WorkRecordKind.shift, id: _shiftId),
      mode: WorkInspectorMode.inspect,
    );
    final ready = WorkReady(
      register: WorkRegisterProjection.empty(
        const WorkScope(employmentId: _employmentId, temporal: null),
      ),
      route: route,
      inspector: const WorkInspectorUnavailable(),
    );

    await pumpScreen(tester, AsyncData(ready));

    expect(find.text('Work record unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Work register'), findsOneWidget);
  });
}

final class _TestScreen extends StatelessWidget {
  const _TestScreen({required this.state});

  final AsyncValue<WorkViewState> state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: Scaffold(
        body: WorkScreen(
          state: state,
          onSelect: (_) {},
          onPrimaryAction: () {},
          onCreateEmployment: (_) async => throw UnimplementedError(),
          onCreateAgreement: (_) async => throw UnimplementedError(),
          onNavigate: (_) {},
        ),
      ),
    );
  }
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _payslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');

final _payslip = Payslip(
  id: _payslipId,
  periodId: _periodId,
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
