import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/features/work/presentation/work_screen.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    AsyncValue<WorkViewState> state, {
    ValueChanged<String>? onNavigate,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _TestScreen(state: state, onNavigate: onNavigate ?? (_) {}),
    );
  }

  WorkReady setupState({
    WorkRecordRef? record,
    WorkInspectorMode mode = WorkInspectorMode.inspect,
    WorkInspectorState inspector = const WorkInspectorEmpty(),
    bool canDelete = true,
    bool used = false,
  }) => WorkReady(
    register: WorkRegisterProjection(
      scope: const WorkScope(employmentId: _employmentId, temporal: null),
      period: null,
      shiftRows: const [],
      payslipRows: const [],
      paid: const Money(minorUnits: 0),
      reconciliation: null,
      employment: _employment,
      hasAgreement: true,
      currentAgreement: _agreement(used: used),
      canDeleteEmployment: canDelete,
      availableEmployments: [_employment],
    ),
    route: WorkRouteState(
      employmentId: _employmentId,
      scope: null,
      record: record,
      mode: mode,
    ),
    inspector: inspector,
  );

  group('employment setup', () {
    testWidgets('a selected employment shows its header', (tester) async {
      final routes = <String>[];
      await pumpScreen(tester, AsyncData(setupState()), onNavigate: routes.add);

      final header = find.bySemanticsLabel('Employment');
      expect(header, findsOneWidget);
      expect(
        find.descendant(of: header, matching: find.text('Warehouse')),
        findsOneWidget,
      );

      await tester.tap(find.text('Edit'));
      await tester.tap(find.text('Edit agreement'));
      expect(routes, [
        '/work?employment=${_employmentId.value}'
            '&record=employment:${_employmentId.value}&mode=edit',
        '/work?employment=${_employmentId.value}'
            '&record=agreement:${_agreementId.value}&mode=edit',
      ]);
    });

    testWidgets('an employment record in edit mode opens its form', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        AsyncData(
          setupState(
            record: const WorkRecordRef(
              kind: WorkRecordKind.employment,
              id: _employmentId,
            ),
            mode: WorkInspectorMode.edit,
            inspector: WorkInspectorRecord(
              EmploymentRecordProjection(_employment),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('employment-name')), findsOneWidget);
      expect(find.text('Warehouse'), findsWidgets);
    });

    testWidgets('an unused agreement edits; one in use stays read-only', (
      tester,
    ) async {
      WorkReady agreementState(int finished) => setupState(
        record: const WorkRecordRef(
          kind: WorkRecordKind.agreement,
          id: _agreementId,
        ),
        mode: WorkInspectorMode.edit,
        inspector: WorkInspectorRecord(
          AgreementRecordProjection(
            _agreement(used: finished > 0),
            finishedShifts: finished,
          ),
        ),
      );

      await pumpScreen(tester, AsyncData(agreementState(0)));
      expect(
        find.byKey(const ValueKey('agreement-hourly-rate')),
        findsOneWidget,
      );

      await pumpScreen(tester, AsyncData(agreementState(2)));
      expect(find.byKey(const ValueKey('agreement-hourly-rate')), findsNothing);
      expect(
        find.text(
          'Used by 2 finished shifts. New versions arrive in a later update.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a finalized shift shows expected pay and its breakdown', (
    tester,
  ) async {
    final shift = WorkShift(
      id: _shiftId,
      employmentId: _employmentId,
      agreementId: _agreementId,
      state: ShiftState.finalized,
      startUtc: DateTime.utc(2026, 9, 29, 18),
      endUtc: DateTime.utc(2026, 9, 30, 4),
      timezoneId: 'Europe/Vilnius',
      localStartDate: const LocalDate(2026, 9, 29),
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: DateTime.utc(2026, 9, 30),
      updatedAtUtc: DateTime.utc(2026, 9, 30),
      revision: const Revision(1),
    );
    const pay = ExpectedPay(
      totalPaidSeconds: 36000,
      nightPaidSeconds: 28800,
      holidayPaidSeconds: 0,
      overtimePaidSeconds: 7200,
      regularPaidSeconds: 7200,
      amount: Money(minorUnits: 25760),
    );
    await pumpScreen(
      tester,
      AsyncData(
        setupState(
          record: const WorkRecordRef(kind: WorkRecordKind.shift, id: _shiftId),
          inspector: WorkInspectorRecord(
            ShiftRecordProjection(shift, breaks: const [], pay: pay),
          ),
        ),
      ),
    );

    final inspector = find.bySemanticsLabel('Finalized shift');
    String fact(String label) {
      final row = find.ancestor(
        of: find.descendant(of: inspector, matching: find.text(label)),
        matching: find.byType(Row),
      );
      return (tester
              .widgetList<Text>(
                find.descendant(of: row.first, matching: find.byType(Text)),
              )
              .last)
          .data!;
    }

    expect(fact('Expected pay'), 'EUR 257.60');
    expect(fact('Regular hours'), '2:00');
    expect(fact('Night hours'), '8:00');
    expect(fact('Holiday hours'), '0:00');
    expect(fact('Overtime hours'), '2:00');
    expect(
      find.textContaining('Expected pay is an estimate until a payslip'),
      findsOneWidget,
    );
  });

  testWidgets('screen keeps frame mounted while Work is loading', (
    tester,
  ) async {
    await pumpScreen(tester, const AsyncLoading());

    expect(find.bySemanticsLabel('Books'), findsOneWidget);
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
  const _TestScreen({required this.state, required this.onNavigate});

  final AsyncValue<WorkViewState> state;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: LifeOSSkinScope(
        child: Scaffold(
          body: WorkScreen(
            state: state,
            onSelect: (_) {},
            onPrimaryAction: () {},
            onCreateEmployment: (_) async => throw UnimplementedError(),
            onCreateAgreement: (_) async => throw UnimplementedError(),
            onNavigate: onNavigate,
            onUpdateEmployment: (_, _) async => throw UnimplementedError(),
            onDeleteEmployment: (_) async => throw UnimplementedError(),
            onUpdateAgreement: (_, _) async => throw UnimplementedError(),
          ),
        ),
      ),
    );
  }
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _payslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');

final _employment = Employment(
  id: _employmentId,
  name: 'Warehouse',
  legalLabel: 'Synthetic Logistics UAB',
  status: EmploymentStatus.active,
  createdAtUtc: DateTime.utc(2026, 9),
  updatedAtUtc: DateTime.utc(2026, 9),
  revision: const Revision(0),
);

PayAgreement _agreement({required bool used}) => PayAgreement(
  id: _agreementId,
  employmentId: _employmentId,
  version: 1,
  effectiveStart: const LocalDate(2026, 9, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 18400000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026, 9),
  revision: const Revision(0),
  usedByFinalizedShift: used,
);

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
