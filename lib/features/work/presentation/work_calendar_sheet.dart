import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/era_combo.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/ids.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import 'work_calendar.dart';
import 'work_controller.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';

/// "15 shifts · 172:30 paid · planned EUR 3174.00 · confirmed EUR 0.00",
/// then " · 16 days without a pay agreement" when planned pay leaves some
/// out.
String monthTotalsLine(MonthTotals totals) =>
    '${totals.shifts == 1 ? '1 shift' : '${totals.shifts} shifts'} · '
    '${formatDuration(totals.paidSeconds)} paid · '
    'planned ${formatMoney(totals.planned)} · '
    'confirmed ${formatMoney(totals.confirmed)}'
    '${withoutAgreementSuffix(totals.withoutAgreement)}';

/// What the grid last had in full: the plan of one month with the records
/// read beside it.
typedef _Loaded = ({
  EmploymentId employment,
  LocalDate month,
  List<PlannedDay> plan,
  WorkRegisterProjection register,
});

/// The Calendar sheet (schedules spec 6.1): a month header, the month grid
/// and the month's figures, read live from the plan. It reads the
/// employment's whole register, so a pay-period or date-range scope on the
/// route never hides a confirmed day. While another month loads, the last
/// month stays on screen, so the cursor and focus are not lost.
final class WorkCalendarSheet extends ConsumerStatefulWidget {
  const WorkCalendarSheet({
    required this.employmentId,
    required this.month,
    required this.today,
    required this.onMonth,
    required this.onOpenDay,
    super.key,
  });

  final EmploymentId employmentId;

  /// The first of the month shown.
  final LocalDate month;
  final LocalDate today;
  final ValueChanged<LocalDate> onMonth;
  final ValueChanged<DayView> onOpenDay;

  @override
  ConsumerState<WorkCalendarSheet> createState() => _WorkCalendarSheetState();
}

final class _WorkCalendarSheetState extends ConsumerState<WorkCalendarSheet> {
  _Loaded? _last;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final employmentId = widget.employmentId;
    final month = widget.month;
    final grid = monthGridDays(month);
    final plan = ref.watch(
      workPlanProvider((
        employment: employmentId,
        // One day early: the night before the grid shows its tail on the
        // first cell.
        from: grid.first.addDays(-1),
        to: grid.last,
      )),
    );
    final registered = ref.watch(employmentRegisterProvider(employmentId));
    final schedules = switch (ref.watch(
      employmentSchedulesProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => const <WorkSchedule>[],
    };
    final timezones = ref.watch(timezoneServiceProvider);
    final zones = ref.watch(zoneClocksProvider);
    if (plan case AsyncData(:final value)) {
      if (registered case AsyncData(value: final register)) {
        _last = (
          employment: employmentId,
          month: month,
          plan: value,
          register: register,
        );
      }
    }
    final last = _last?.employment == employmentId ? _last : null;
    if (last == null) {
      if (plan is AsyncError || registered is AsyncError) {
        return const OperationalState(
          kind: OperationalStateKind.unavailable,
          title: 'Calendar unavailable',
          message: 'Reload Work to read the schedule again.',
        );
      }
      return const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the schedule',
        message: 'Planning the month from its schedule.',
      );
    }
    final shown = last.month;
    final agreements = [
      for (final row in last.register.agreementSheet) row.agreement,
    ];
    final days = dayViews(
      from: shown.firstOfMonth,
      to: shown.lastOfMonth,
      plan: last.plan,
      shifts: last.register.shiftSheet,
      leave: last.register.leaveSheet,
      schedules: [...schedules],
      timezones: timezones,
      withoutAgreement: (day) => lacksAgreement(
        day,
        employmentId: employmentId,
        agreements: agreements,
      ),
    );
    final totals = monthTotals(
      days.values,
      price: (shift) => plannedPay(
        shift,
        agreements: agreements,
        employmentId: employmentId,
        zoneClocks: zones,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthHeader(
          month: shown,
          today: widget.today,
          onMonth: widget.onMonth,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: WorkCalendar(
              // One calendar for every month, so its cursor and focus
              // carry across a month edge.
              key: const ValueKey('work-calendar'),
              month: shown,
              today: widget.today,
              days: days,
              autofocus: true,
              onMonth: widget.onMonth,
              onOpen: (date) {
                // A greyed neighbouring day moves to its month.
                final day = days[date];
                if (day == null) {
                  widget.onMonth(date.firstOfMonth);
                } else {
                  widget.onOpenDay(day);
                }
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Text(
            monthTotalsLine(totals),
            key: const ValueKey('work-calendar-totals'),
            style: skin.typography.body.copyWith(color: skin.tokens.ink),
          ),
        ),
      ],
    );
  }
}

/// ‹ [Month ▾] [Year ▾] › [Today] above the grid.
final class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.today,
    required this.onMonth,
  });

  final LocalDate month;
  final LocalDate today;
  final ValueChanged<LocalDate> onMonth;

  @override
  Widget build(BuildContext context) {
    final first = month.firstOfMonth;
    final years = {
      for (var year = today.year - 5; year <= today.year + 5; year++) year,
      first.year,
    }.toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StepKey(
            forward: false,
            semanticLabel: 'Previous month',
            onPressed: () => onMonth(first.addMonthsClamped(-1)),
          ),
          EraCombo<int>(
            key: const ValueKey('work-calendar-month'),
            semanticLabel: 'Month',
            value: first.month,
            minWidth: 96,
            items: [
              for (var index = 0; index < 12; index++)
                EraComboItem(index + 1, eraMonthNames[index]),
            ],
            onSelected: (value) => onMonth(LocalDate(first.year, value, 1)),
          ),
          EraCombo<int>(
            key: const ValueKey('work-calendar-year'),
            semanticLabel: 'Year',
            value: first.year,
            items: [for (final year in years) EraComboItem(year, '$year')],
            onSelected: (value) => onMonth(LocalDate(value, first.month, 1)),
          ),
          StepKey(
            forward: true,
            semanticLabel: 'Next month',
            onPressed: () => onMonth(first.addMonthsClamped(1)),
          ),
          KeyButton(
            label: 'Today',
            onPressed: () => onMonth(today.firstOfMonth),
          ),
          // The month in words, for the window title and screen readers.
          Text(eraMonthTitle(first)),
        ],
      ),
    );
  }
}
