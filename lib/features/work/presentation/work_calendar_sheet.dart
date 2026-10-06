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

/// "15 shifts · 172:30 paid · planned EUR 3174.00 · confirmed EUR 0.00".
String monthTotalsLine(MonthTotals totals) =>
    '${totals.shifts == 1 ? '1 shift' : '${totals.shifts} shifts'} · '
    '${formatDuration(totals.paidSeconds)} paid · '
    'planned ${formatMoney(totals.planned)} · '
    'confirmed ${formatMoney(totals.confirmed)}';

/// The Calendar sheet (schedules spec 6.1): a month header, the month grid
/// and the month's figures, read live from the plan.
final class WorkCalendarSheet extends ConsumerWidget {
  const WorkCalendarSheet({
    required this.employmentId,
    required this.month,
    required this.today,
    required this.register,
    required this.onMonth,
    required this.onOpenDay,
    super.key,
  });

  final EmploymentId employmentId;

  /// The first of the month shown.
  final LocalDate month;
  final LocalDate today;

  /// The month's recorded shifts and leave.
  final WorkRegisterProjection register;
  final ValueChanged<LocalDate> onMonth;
  final ValueChanged<DayView> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = LifeOSSkinScope.of(context);
    final grid = monthGridDays(month);
    final plan = ref.watch(
      workPlanProvider((
        employment: employmentId,
        from: grid.first,
        to: grid.last,
      )),
    );
    final schedules = switch (ref.watch(
      employmentSchedulesProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => const <WorkSchedule>[],
    };
    final timezones = ref.watch(timezoneServiceProvider);
    final zones = ref.watch(zoneClocksProvider);
    final agreements = [
      for (final row in register.agreementSheet) row.agreement,
    ];
    return switch (plan) {
      AsyncData(:final value) => () {
        final days = dayViews(
          from: month.firstOfMonth,
          to: month.lastOfMonth,
          plan: value,
          shifts: register.shiftSheet,
          leave: register.leaveSheet,
          schedules: [...schedules],
          timezones: timezones,
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
            _MonthHeader(month: month, today: today, onMonth: onMonth),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: WorkCalendar(
                  key: ValueKey(('work-calendar', month)),
                  month: month,
                  today: today,
                  days: days,
                  autofocus: true,
                  onMonth: onMonth,
                  onOpen: (date) {
                    // A greyed neighbouring day moves to its month.
                    final day = days[date];
                    if (day == null) {
                      onMonth(date.firstOfMonth);
                    } else {
                      onOpenDay(day);
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
      }(),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Calendar unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the schedule',
        message: 'Planning the month from its schedule.',
      ),
    };
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
