import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/task_pane.dart';
import '../../../ui/ui.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart';
import '../domain/shift.dart';
import 'leave_sheet.dart';
import 'schedules_sheet.dart';
import 'work_calendar_sheet.dart';
import 'work_plan_view.dart';
import 'work_route_state.dart';
import 'work_sheets.dart';
import 'work_toolbar_controls.dart';

final class WorkRegister extends StatelessWidget {
  const WorkRegister({
    required this.projection,
    required this.selectedRecord,
    required this.onSelect,
    this.onProperties,
    required this.onPrimaryAction,
    this.onOpenEmployment,
    this.today,
    this.onAllEmployments,
    this.onCreateEmployment,
    this.route,
    this.onRoute,
    this.timezones,
    this.defaultSheet = WorkSheet.shifts,
    this.plannedShifts = const [],
    super.key,
  });

  final WorkRegisterProjection? projection;
  final WorkRecordRef? selectedRecord;
  final ValueChanged<WorkRecordRef> onSelect;

  /// Opens a row's Properties sheet.
  final ValueChanged<WorkRecordRef>? onProperties;
  final VoidCallback onPrimaryAction;
  final ValueChanged<EmploymentId>? onOpenEmployment;

  /// The date a new range ends on; the device date when null.
  final LocalDate? today;

  /// Clears the employment from the route.
  final VoidCallback? onAllEmployments;

  /// Opens the employment form in the inspector.
  final VoidCallback? onCreateEmployment;

  /// The current route; its sheet, scope and void filter shape the desk.
  final WorkRouteState? route;

  /// Applies a sheet, scope or filter change.
  final ValueChanged<WorkRouteState>? onRoute;

  /// Reads shift times on their own wall clock.
  final TimezoneService? timezones;

  /// The sheet shown when the route names none (schedules spec 5).
  final WorkSheet defaultSheet;

  /// The planned days the Shifts sheet lists among its shifts.
  final List<PlannedShiftRow> plannedShifts;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final value = projection;
    if (value == null) {
      return const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Work records unavailable',
        message: 'Reload Work to inspect the current records.',
      );
    }
    final open = onOpenEmployment;
    final create = onCreateEmployment ?? onPrimaryAction;
    if (value.scope.employmentId == null &&
        value.availableEmployments.isNotEmpty &&
        open != null) {
      return OperationalState(
        kind: OperationalStateKind.empty,
        title: 'Choose an employment',
        message: 'Open an employment to continue, or create another one.',
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final employment in value.availableEmployments)
              KeyButton(
                label: employment.name,
                onPressed: () => open(employment.id),
              ),
            KeyButton(
              label: 'Create employment',
              kind: KeyKind.primary,
              onPressed: create,
            ),
          ],
        ),
      );
    }
    if (value.scope.employmentId == null) {
      return OperationalState(
        kind: OperationalStateKind.empty,
        title: 'Work',
        message:
            'Track shifts, see what you should be paid, and compare it with '
            'your payslips. Start by adding where you work.',
        action: KeyButton(
          label: 'Create employment',
          kind: KeyKind.primary,
          onPressed: create,
        ),
      );
    }

    final route =
        this.route ??
        WorkRouteState(
          employmentId: value.scope.employmentId,
          scope: value.scope.temporal,
          record: selectedRecord,
          mode: WorkInspectorMode.inspect,
        );
    void change(WorkRouteState next) => onRoute?.call(next);
    // A planned day is selected by date, as it has no record yet.
    final selectedId = selectedRecord != null
        ? workRowId(selectedRecord!)
        : route.day != null
        ? plannedRowId(route.day!)
        : null;
    final shown = route.sheet ?? defaultSheet;
    final Widget sheet = switch (shown) {
      WorkSheet.shifts => ShiftsSheet(
        rows: value.shiftSheet,
        timezones: timezones ?? IanaTimezoneService(),
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
        showVoid: route.showVoid,
        planned: plannedShifts,
        onOpenDay: (day) => change(
          route.copyWith(
            record: () => null,
            day: () => day,
            mode: WorkInspectorMode.inspect,
          ),
        ),
        onDayProperties: (day) => change(
          route.copyWith(
            record: () => null,
            day: () => day,
            mode: WorkInspectorMode.properties,
          ),
        ),
      ),
      WorkSheet.periods => PeriodsSheet(
        rows: value.periodSheet,
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
      ),
      WorkSheet.payslips => PayslipsSheet(
        payslips: value.payslipSheet,
        periods: value.periodSheet,
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
        showVoid: route.showVoid,
      ),
      WorkSheet.agreements => AgreementsSheet(
        rows: value.agreementSheet,
        employmentName: value.employment?.name ?? 'Employment',
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
      ),
      WorkSheet.calendar => WorkCalendarSheet(
        employmentId: value.scope.employmentId!,
        month: switch (route.scope) {
          DateRangeScope(:final start) => start.firstOfMonth,
          _ => (today ?? _deviceToday()).firstOfMonth,
        },
        today: today ?? _deviceToday(),
        onMonth: (month) => change(
          route.copyWith(
            sheet: WorkSheet.calendar,
            scope: () => DateRangeScope(
              start: month.firstOfMonth,
              end: month.lastOfMonth,
            ),
            record: () => null,
          ),
        ),
        onOpenDay: (day) => _openDay(day, route, change),
      ),
      WorkSheet.leave => LeaveSheet(
        rows: value.leaveSheet,
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
        showVoid: route.showVoid,
      ),
      WorkSheet.schedules => SchedulesSheetHost(
        employmentId: value.scope.employmentId!,
        today: today ?? _deviceToday(),
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
        onNew: value.hasAgreement
            ? () => change(route.copyWith(adding: () => WorkAddKind.schedule))
            : null,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: skin.painters.toolbar(skin.tokens),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SheetPicker(
                sheet: shown,
                onSheet: (sheet) => change(route.copyWith(sheet: sheet)),
              ),
              EmploymentSwitcher(
                current: value.employment?.id,
                currentName: value.employment?.name,
                employments: value.availableEmployments,
                onOpen: onOpenEmployment,
                onAll: onAllEmployments,
                onCreate: create,
              ),
              if (shown != WorkSheet.calendar &&
                  shown != WorkSheet.schedules) ...[
                PeriodPicker(
                  scope: route.scope,
                  periods: [for (final row in value.periodSheet) row.period],
                  today: today,
                  onScope: (scope) => change(
                    route.copyWith(scope: () => scope, record: () => null),
                  ),
                ),
                StateFilter(
                  showVoid: route.showVoid,
                  onChanged: (show) => change(route.copyWith(showVoid: show)),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: skin.tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: sheet,
          ),
        ),
      ],
    );
  }
}

/// The Details group for a Work scope (spec 5.2): employment, period,
/// shift count and the reconciliation per basis, worded as the summary was.
final class WorkDetails extends StatelessWidget {
  const WorkDetails({
    required this.projection,
    this.plannedShifts = 0,
    super.key,
  });

  final WorkRegisterProjection projection;

  /// The planned shifts the Shifts sheet lists, counted beside the
  /// recorded ones; zero on every other sheet.
  final int plannedShifts;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final figure = skin.typography.figure.copyWith(color: skin.tokens.ink);
    final period = projection.period;
    final groups = projection.reconciliation?.groups ?? const [];
    // Void shifts stay in history but leave the count, as they leave pay.
    final shifts = projection.shiftSheet
        .where((row) => row.shift.state != ShiftState.voided)
        .length;
    // Label and value share a line when they fit, otherwise the value
    // moves under its label (the property sheet's fact row).
    Widget pair(String label, String value) =>
        InspectorFactRow(fact: Fact(label, value));
    return TaskDetails(
      lines: [
        if (projection.employment case final employment?)
          Text(
            employment.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        if (period != null) ...[
          Text('${period.start} – ${period.end}', style: figure),
          Text(period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open'),
        ],
        Text(shifts == 1 ? '1 shift' : '$shifts shifts'),
        // Planned days are counted apart: they are not records yet.
        if (plannedShifts > 0)
          Text(
            plannedShifts == 1
                ? '1 planned shift'
                : '$plannedShifts planned shifts',
          ),
        if (projection.plannedNotConfirmed case final n when n > 0)
          Text(
            n == 1
                ? '1 planned day not yet confirmed'
                : '$n planned days not yet confirmed',
          ),
        // Not confirmable, so counted apart from the days above.
        if (projection.plannedWithoutAgreement case final n when n > 0)
          Text(
            n == 1
                ? '1 day without a pay agreement'
                : '$n days without a pay agreement',
          ),
        if (groups.isEmpty) ...[
          if (_estimatedTotal(projection) case final total?)
            pair('Estimated pay', _money(total)),
          pair('Paid evidence', _money(projection.paid)),
        ],
        for (final group in groups) ...[
          Text(
            '${_basis(group.basis)} · ${group.currency.value}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          pair(
            'Expected under recorded agreement',
            _optionalMoney(group.expected),
          ),
          pair('Paid evidence', _optionalMoney(group.paid)),
          if (group.difference case final difference?)
            pair('Difference', _money(difference)),
        ],
      ],
    );
  }
}

/// The expected pay of the effective shifts in scope, or null when none has
/// an estimate yet. Only one currency is summed; Work records are in euros.
Money? _estimatedTotal(WorkRegisterProjection projection) {
  final pays = [
    for (final row in projection.shiftSheet)
      if (row.shift.state != ShiftState.voided) ?row.pay?.amount,
  ];
  if (pays.isEmpty) return null;
  return Money(
    minorUnits: pays.fold(0, (sum, pay) => sum + pay.minorUnits),
    currency: pays.first.currency,
  );
}

String _basis(RateBasis? basis) => switch (basis) {
  GrossBasis() => 'Gross',
  NetBasis() => 'Net',
  null => 'Mixed basis',
};

String _optionalMoney(Money? money) =>
    money == null ? 'Not recorded' : _money(money);

String _money(Money money) {
  final negative = money.minorUnits < 0;
  final absolute = money.minorUnits.abs();
  final major = absolute ~/ 100;
  final minor = absolute.remainder(100).toString().padLeft(2, '0');
  return '${money.currency.value} ${negative ? '-' : ''}$major.$minor';
}

LocalDate _deviceToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}

/// A confirmed day opens what was recorded on it; any other day opens its
/// own Properties.
void _openDay(
  DayView day,
  WorkRouteState route,
  ValueChanged<WorkRouteState> change,
) {
  final shift = day.shifts.firstOrNull;
  final leave = day.leave;
  final WorkRecordRef? record = shift != null
      ? WorkRecordRef(kind: WorkRecordKind.shift, id: shift.shift.id)
      : leave != null
      ? WorkRecordRef(kind: WorkRecordKind.leave, id: leave.record.id)
      : null;
  change(
    route.copyWith(
      sheet: WorkSheet.calendar,
      record: () => record,
      day: () => record == null ? day.date : null,
      mode: WorkInspectorMode.properties,
    ),
  );
}
