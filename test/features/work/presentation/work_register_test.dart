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
import 'package:lifeos/features/work/presentation/work_toolbar_controls.dart';
import 'package:lifeos/ui/ui.dart';

import '../../../support/era_pickers.dart';
import '../../../support/work_sheets.dart';

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
    expect(find.widgetWithText(KeyButton, 'Create employment'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(KeyButton, 'Create employment'));
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
      await tester.tap(_combo('Employment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await tester.tap(_combo('Employment'));
    await tester.pumpAndSettle();
    // The current employment is the lit row of the list.
    final current = find.descendant(
      of: find.ancestor(
        of: find.text('Warehouse').last,
        matching: find.byType(MenuItemButton),
      ),
      matching: find.byType(Material),
    );
    expect(
      tester.widget<Material>(current.first).color,
      LifeOSSkinData.standard.tokens.selWash,
    );
    expect(find.text('All employments'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await choose('Café');
    await choose('All employments');
    await choose('Create employment…');
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

    await tester.tap(find.text('2026-09-29'));

    expect(selected, hasLength(1));
    expect(selected.single.kind, WorkRecordKind.shift);
    expect(selected.single.id, _shiftId);
  });

  testWidgets('Details labels expected and paid evidence truthfully', (
    tester,
  ) async {
    await tester.pumpWidget(_TestDetails(_reconciliationProjection()));

    expect(find.text('Expected under recorded agreement:'), findsOneWidget);
    expect(find.text('Paid evidence:'), findsOneWidget);
    final paid = tester.widget<Text>(find.text('EUR 95.00'));
    expect(
      paid.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('Details names the period state and the estimated total', (
    tester,
  ) async {
    final base = _reconciliationProjection();
    await tester.pumpWidget(
      _TestDetails(
        WorkRegisterProjection(
          scope: base.scope,
          period: _period,
          shiftRows: const [],
          payslipRows: const [],
          paid: const Money(minorUnits: 0),
          reconciliation: null,
          shiftSheet: [
            _sheetRow(_shiftId, ShiftState.finalized, payMinorUnits: 10000),
            _sheetRow(_otherShiftId, ShiftState.voided, payMinorUnits: 99900),
            _sheetRow(
              _shiftId,
              ShiftState.finalized,
              date: const LocalDate(2026, 9, 30),
              payMinorUnits: 5480,
            ),
          ],
        ),
      ),
    );
    expect(find.textContaining('Open'), findsOneWidget);
    expect(find.text('Estimated pay:'), findsOneWidget);
    // Voided shifts are not counted.
    expect(find.text('EUR 154.80'), findsOneWidget);
  });

  testWidgets('Details holds at 200 % text in the task pane', (tester) async {
    await tester.pumpWidget(
      _TestDetails(_reconciliationProjection(), textScale: 2),
    );
    expect(tester.takeException(), isNull);
    final label = tester.getSize(
      find.text('Expected under recorded agreement:'),
    );
    // The label keeps a usable width instead of one letter per line.
    expect(label.width, greaterThan(100));
  });

  testWidgets('Details never combines gross and net differences', (
    tester,
  ) async {
    await tester.pumpWidget(_TestDetails(_mixedBasisProjection()));

    expect(find.bySemanticsLabel('Gross · EUR'), findsOneWidget);
    expect(find.bySemanticsLabel('Net · EUR'), findsOneWidget);
    expect(find.text('Expected under recorded agreement:'), findsNWidgets(2));
    expect(find.text('Paid evidence:'), findsNWidgets(2));
    expect(find.text('Combined difference'), findsNothing);
  });

  group('Work sheets', () {
    WorkRouteState route({
      WorkTemporalScope? scope,
      WorkSheet sheet = WorkSheet.shifts,
      bool showVoid = false,
    }) => WorkRouteState(
      employmentId: _employmentId,
      scope: scope,
      record: null,
      mode: WorkInspectorMode.inspect,
      sheet: sheet,
      showVoid: showVoid,
    );

    WorkRegisterProjection sheets() => WorkRegisterProjection(
      scope: const WorkScope(employmentId: _employmentId, temporal: null),
      period: null,
      shiftRows: const [],
      payslipRows: const [],
      paid: const Money(minorUnits: 0),
      reconciliation: null,
      shiftSheet: [
        _sheetRow(_shiftId, ShiftState.finalized, period: _period),
        _sheetRow(_otherShiftId, ShiftState.voided, period: _period),
        _sheetRow(
          const ShiftId('00000000-0000-7000-8000-000000000003'),
          ShiftState.draft,
          date: const LocalDate(2026, 10, 2),
          withoutEnd: true,
        ),
      ],
      periodSheet: [
        PeriodSheetRow(period: _period, shiftCount: 1, groups: const []),
        PeriodSheetRow(period: _october, shiftCount: 0, groups: const []),
      ],
    );

    testWidgets('shift columns follow the spec and states read as words', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _TestWorkRegister(projection: sheets(), route: route()),
      );

      for (final column in [
        'Date',
        'Start',
        'End',
        'Break',
        'Paid',
        'Night',
        'Holiday',
        'OT',
        'Est. pay',
        'State',
      ]) {
        // The Shifts list is ordered by date, which its header says.
        expect(find.text(column), findsOneWidget, reason: column);
      }
      expect(find.text('Finalized'), findsOneWidget);
      // A draft without an end, as a migrated running shift is.
      expect(find.text('Draft'), findsOneWidget);
      // Vilnius is UTC+3 in September: 06:00Z is 09:00.
      expect(find.text('09:00'), findsWidgets);
      expect(find.text('0:30'), findsOneWidget);
      // Grouped by pay period, then by month.
      expect(find.text('September'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('void rows are hidden until the filter shows them', (
      tester,
    ) async {
      final routes = <WorkRouteState>[];
      await tester.pumpWidget(
        _TestWorkRegister(
          projection: sheets(),
          route: route(),
          onRoute: routes.add,
        ),
      );
      expect(find.text('Void'), findsNothing);

      await tester.tap(_combo('Status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Including void'));
      await tester.pumpAndSettle();
      expect(routes.single.showVoid, isTrue);

      await tester.pumpWidget(
        _TestWorkRegister(projection: sheets(), route: route(showVoid: true)),
      );
      expect(find.text('Void'), findsOneWidget);
    });

    testWidgets('tabs switch the sheet in the route', (tester) async {
      final routes = <WorkRouteState>[];
      await tester.pumpWidget(
        _TestWorkRegister(
          projection: sheets(),
          route: route(),
          onRoute: routes.add,
        ),
      );
      await chooseSheet(tester, 'Pay periods');
      await chooseSheet(tester, 'Agreements');
      expect(routes.map((value) => value.sheet), [
        WorkSheet.periods,
        WorkSheet.agreements,
      ]);

      await tester.pumpWidget(
        _TestWorkRegister(
          projection: sheets(),
          route: route(sheet: WorkSheet.periods),
        ),
      );
      expect(find.text('Shifts'), findsWidgets);
      expect(find.text('Expected'), findsOneWidget);
      expect(find.text('Open'), findsNWidgets(2));
    });

    testWidgets('‹ and › step between pay periods', (tester) async {
      final routes = <WorkRouteState>[];
      await tester.pumpWidget(
        _TestWorkRegister(
          projection: sheets(),
          route: route(scope: PayPeriodScope(_october.id)),
          onRoute: routes.add,
        ),
      );
      expect(find.bySemanticsLabel('Next period, unavailable'), findsOne);

      // The step keys are painted arrows, not font characters.
      expect(find.text('‹'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Previous period'));
      expect((routes.single.scope! as PayPeriodScope).periodId, _periodId);
    });

    testWidgets('a date range steps by its own length', (tester) async {
      final routes = <WorkRouteState>[];
      await tester.pumpWidget(
        _TestWorkRegister(
          projection: sheets(),
          route: route(
            scope: const DateRangeScope(
              start: LocalDate(2026, 9, 1),
              end: LocalDate(2026, 9, 7),
            ),
          ),
          onRoute: routes.add,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Next period'));
      final next = routes.single.scope! as DateRangeScope;
      expect(next.start, const LocalDate(2026, 9, 8));
      expect(next.end, const LocalDate(2026, 9, 14));
    });

    testWidgets(
      'a new range starts on the first of this month and ends today',
      (tester) async {
        final scopes = <WorkTemporalScope?>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLifeOSTheme(),
            home: LifeOSSkinScope(
              child: Scaffold(
                body: PeriodPicker(
                  scope: null,
                  periods: const [],
                  today: const LocalDate(2026, 9, 15),
                  onScope: scopes.add,
                ),
              ),
            ),
          ),
        );
        await tester.tap(_combo('Period'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Date range…'));
        await tester.pumpAndSettle();
        expect(dateIn(tester, 'range-from'), const LocalDate(2026, 9, 1));
        expect(dateIn(tester, 'range-to'), const LocalDate(2026, 9, 15));
        await tester.tap(find.byKey(const ValueKey('range-apply')));
        await tester.pumpAndSettle();
        final range = scopes.single! as DateRangeScope;
        expect(range.start, const LocalDate(2026, 9, 1));
        expect(range.end, const LocalDate(2026, 9, 15));
      },
    );

    testWidgets('a click beside the range dialog keeps it and its picks', (
      tester,
    ) async {
      final scopes = <WorkTemporalScope?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: PeriodPicker(
                scope: null,
                periods: const [],
                today: const LocalDate(2026, 9, 15),
                onScope: scopes.add,
              ),
            ),
          ),
        ),
      );
      await tester.tap(_combo('Period'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date range…'));
      await tester.pumpAndSettle();
      await pickDate(tester, 'range-from', const LocalDate(2026, 9, 3));
      await tester.tap(find.byKey(const ValueKey('range-to')));
      await tester.pumpAndSettle();
      expect(find.byType(EraMonthCalendar), findsOneWidget);

      // The barrier, away from both the dialog and the open calendar.
      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();
      expect(find.byType(EraMonthCalendar), findsNothing);
      expect(dateIn(tester, 'range-from'), const LocalDate(2026, 9, 3));

      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();
      expect(dateIn(tester, 'range-from'), const LocalDate(2026, 9, 3));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('range-from')), findsNothing);
      expect(scopes, isEmpty);
    });

    testWidgets('an explicit date range is entered from the period menu', (
      tester,
    ) async {
      final routes = <WorkRouteState>[];
      await tester.pumpWidget(
        _TestWorkRegister(
          projection: sheets(),
          route: route(),
          onRoute: routes.add,
        ),
      );
      await tester.tap(_combo('Period'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date range…'));
      await tester.pumpAndSettle();
      await pickDate(tester, 'range-from', const LocalDate(2026, 9, 10));
      await pickDate(tester, 'range-to', const LocalDate(2026, 9, 5));
      await tester.tap(find.byKey(const ValueKey('range-apply')));
      await tester.pumpAndSettle();
      expect(
        find.text('The range must end on or after its start.'),
        findsOneWidget,
      );
      await pickDate(tester, 'range-to', const LocalDate(2026, 9, 20));
      await tester.tap(find.byKey(const ValueKey('range-apply')));
      await tester.pumpAndSettle();

      final range = routes.single.scope! as DateRangeScope;
      expect(range.start, const LocalDate(2026, 9, 10));
      expect(range.end, const LocalDate(2026, 9, 20));
    });
  });

  testWidgets('two-times text scale keeps all filter controls reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _TestWorkRegister(projection: _projection(), textScale: 2),
    );

    for (final label in ['View:', 'Employment:', 'Period:', 'Status:']) {
      final control = find.text(label);
      expect(control, findsOneWidget);
      await tester.ensureVisible(control);
    }
    expect(tester.takeException(), isNull);
  });
}

/// The toolbar combo box named [label], by its announced name.
Finder _combo(String label) => find.bySemanticsLabel(RegExp('^$label, '));

final class _TestWorkRegister extends StatelessWidget {
  const _TestWorkRegister({
    required this.projection,
    this.onSelect,
    this.textScale = 1,
    this.onOpenEmployment,
    this.onAllEmployments,
    this.onCreateEmployment,
    this.route,
    this.onRoute,
  });

  final WorkRegisterProjection? projection;
  final ValueChanged<WorkRecordRef>? onSelect;
  final double textScale;
  final ValueChanged<EmploymentId>? onOpenEmployment;
  final VoidCallback? onAllEmployments;
  final VoidCallback? onCreateEmployment;
  final WorkRouteState? route;
  final ValueChanged<WorkRouteState>? onRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(),
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
              route: route,
              onRoute: onRoute,
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
  shiftSheet: [_sheetRow(_shiftId, ShiftState.finalized)],
);

ShiftSheetRow _sheetRow(
  ShiftId id,
  ShiftState state, {
  LocalDate date = const LocalDate(2026, 9, 29),
  PayPeriod? period,
  int? payMinorUnits,
  bool withoutEnd = false,
}) => ShiftSheetRow(
  shift: WorkShift(
    id: id,
    employmentId: _employmentId,
    agreementId: state == ShiftState.draft ? null : _agreementId,
    state: state,
    startUtc: DateTime.utc(date.year, date.month, date.day, 6),
    endUtc: withoutEnd
        ? null
        : DateTime.utc(date.year, date.month, date.day, 14, 30),
    timezoneId: 'Europe/Vilnius',
    localStartDate: date,
    note: null,
    voidReason: state == ShiftState.voided ? 'Synthetic' : null,
    replacementShiftId: state == ShiftState.voided ? _otherShiftId : null,
    replacedShiftId: null,
    createdAtUtc: DateTime.utc(2026, 9),
    updatedAtUtc: DateTime.utc(2026, 9),
    revision: const Revision(1),
  ),
  breakSeconds: withoutEnd ? 0 : 1800,
  paidSeconds: withoutEnd ? null : 8 * 3600,
  period: period,
  pay: payMinorUnits == null
      ? null
      : ExpectedPay(
          totalPaidSeconds: 8 * 3600,
          nightPaidSeconds: 0,
          holidayPaidSeconds: 0,
          overtimePaidSeconds: 0,
          regularPaidSeconds: 8 * 3600,
          amount: Money(minorUnits: payMinorUnits),
        ),
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

final _october = PayPeriod.create(
  id: const PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c52'),
  employmentId: _employmentId,
  start: const LocalDate(2026, 10, 1),
  end: const LocalDate(2026, 10, 31),
  label: null,
  nowUtc: DateTime.utc(2026, 10),
);

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _otherEmploymentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c12');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');
const _otherShiftId = ShiftId('00000000-0000-7000-8000-000000000002');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');

/// The Work Details group on its own, as the task pane shows it.
final class _TestDetails extends StatelessWidget {
  const _TestDetails(this.projection, {this.textScale = 1});

  final WorkRegisterProjection projection;
  final double textScale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildLifeOSTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: LifeOSSkinScope(
      child: Scaffold(
        // The task pane scrolls; so does this stand-in.
        body: SingleChildScrollView(
          child: SizedBox(
            width: 176,
            child: WorkDetails(projection: projection),
          ),
        ),
      ),
    ),
  );
}
