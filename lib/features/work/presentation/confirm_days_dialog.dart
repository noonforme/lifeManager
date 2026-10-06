import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../application/day_plan_service.dart';
import '../domain/agreement.dart';
import '../domain/ids.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import '../domain/planner.dart';
import 'day_sheet.dart' show confirmProblem;
import 'work_controller.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';

/// One day the dialog offers to confirm.
final class ConfirmRow {
  const ConfirmRow({
    required this.date,
    required this.what,
    required this.times,
    required this.paidSeconds,
    required this.pay,
  });

  final LocalDate date;

  /// "Day", "Night", "Extra", "Vacation" or "Sick".
  final String what;

  /// "07:00–19:00"; empty for leave.
  final String times;
  final int paidSeconds;

  /// Null when no agreement covers the date.
  final Money? pay;
}

List<ConfirmRow> confirmRows(
  List<PlannedDay> days, {
  required ExpectedPay? Function(PlannedShift shift) shiftPay,
  required LeavePay? Function(PlannedLeave leave) leavePay,
  required TimezoneService timezones,
}) => [
  for (final day in days)
    switch (day) {
      PlannedShift() => ConfirmRow(
        date: day.date,
        what: plannedShiftName(day),
        times: shiftTimes(day.startUtc, day.endUtc, day.timezoneId, timezones),
        paidSeconds: day.paidSeconds,
        pay: shiftPay(day)?.amount,
      ),
      PlannedLeave() => ConfirmRow(
        date: day.date,
        what: leaveTypeLabel(day.leaveType),
        times: '',
        paidSeconds: day.paidMinutes * 60,
        pay: leavePay(day)?.amount,
      ),
      _ => null,
    },
].nonNulls.toList();

/// "12 days · 138:00 paid · EUR 2714.40".
String confirmSummary(Iterable<ConfirmRow> rows) {
  final count = rows.length;
  final paid = rows.fold(0, (sum, row) => sum + row.paidSeconds);
  final pay = rows.fold(0, (sum, row) => sum + (row.pay?.minorUnits ?? 0));
  return '${count == 1 ? '1 day' : '$count days'} · '
      '${formatDuration(paid)} paid · ${formatMoney(Money(minorUnits: pay))}';
}

/// The Confirm worked days dialog (schedules spec 6.3).
final class ConfirmDaysDialog extends StatefulWidget {
  const ConfirmDaysDialog({
    required this.rows,
    required this.onConfirm,
    super.key,
  });

  final List<ConfirmRow> rows;

  /// Confirms each date in turn and says how each went.
  final Future<Map<LocalDate, MutationOutcome<ConfirmedDay>>> Function(
    List<LocalDate> dates,
  )
  onConfirm;

  @override
  State<ConfirmDaysDialog> createState() => _ConfirmDaysDialogState();
}

final class _ConfirmDaysDialogState extends State<ConfirmDaysDialog> {
  /// Days the owner unticked; every other listed day is ticked, including
  /// days that appear while the dialog is open.
  final _unticked = <LocalDate>{};
  final _problems = <LocalDate, String>{};
  bool _busy = false;

  List<ConfirmRow> get _ticked => [
    for (final row in widget.rows)
      if (!_unticked.contains(row.date)) row,
  ];

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _problems.clear();
    });
    final results = await widget.onConfirm([
      for (final row in _ticked) row.date,
    ]);
    if (!mounted) return;
    final problems = {
      for (final MapEntry(key: date, value: outcome) in results.entries)
        date: ?confirmProblem(outcome),
    };
    if (problems.isEmpty) {
      ShellDialogScope.closeOf(context)?.call();
      return;
    }
    setState(() {
      _busy = false;
      _problems.addAll(problems);
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final close = ShellDialogScope.closeOf(context);
    if (widget.rows.isEmpty) {
      return DialogForm(
        fields: const [InspectorText('Every past planned day is confirmed.')],
        keys: [
          KeyButton(label: 'Close', kind: KeyKind.primary, onPressed: close),
        ],
      );
    }
    final style = skin.typography.body.copyWith(color: tokens.ink);
    Widget head(String text, double width, {bool end = false}) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(right: BorderSide(color: tokens.chromeLine)),
      ),
      child: Text(
        text,
        style: skin.typography.label.copyWith(color: tokens.ink),
      ),
    );
    Widget cell(String text, double width, {bool end = false, Color? ink}) =>
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ink == null ? style : style.copyWith(color: ink),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Tick the days you worked as planned, then Confirm.'),
        const SizedBox(height: 7),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    head('Date', 180),
                    head('What', 70),
                    head('Times', 90),
                    head('Paid', 52, end: true),
                    head('Pay', 82, end: true),
                    Expanded(child: head('', 0)),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final row in widget.rows)
                        SizedBox(
                          key: ValueKey('confirm-row-${row.date}'),
                          height: 24,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 180,
                                child: EraCheckBox(
                                  label: eraBoxDate(row.date),
                                  value: !_unticked.contains(row.date),
                                  onChanged: _busy
                                      ? null
                                      : (ticked) => setState(
                                          () => ticked
                                              ? _unticked.remove(row.date)
                                              : _unticked.add(row.date),
                                        ),
                                ),
                              ),
                              cell(row.what, 70),
                              cell(row.times, 90),
                              cell(
                                formatDuration(row.paidSeconds),
                                52,
                                end: true,
                              ),
                              cell(
                                row.pay == null ? '—' : formatMoney(row.pay!),
                                82,
                                end: true,
                              ),
                              Expanded(
                                child: cell(
                                  _problems[row.date] ?? '',
                                  0,
                                  ink: tokens.negative,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(confirmSummary(_ticked), style: style),
        FormFooter(
          children: [
            KeyButton(
              label: 'Confirm',
              kind: KeyKind.primary,
              onPressed: _busy || _ticked.isEmpty ? null : _confirm,
            ),
            const DialogCancelKey(),
          ],
        ),
      ],
    );
  }
}

/// Lists the employment's days to confirm, live, and confirms them one
/// transaction at a time.
final class ConfirmDaysHost extends ConsumerWidget {
  const ConfirmDaysHost({required this.employmentId, super.key});

  final EmploymentId employmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final register = switch (ref.watch(
      employmentRegisterProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final zones = ref.watch(zoneClocksProvider);
    final timezones = ref.watch(timezoneServiceProvider);
    final agreements = switch (ref.watch(planInputsProvider(employmentId))) {
      AsyncData(:final value) => value.agreements,
      _ => const <PayAgreement>[],
    };
    return switch (ref.watch(daysToConfirmProvider(employmentId))) {
      AsyncData(:final value) => ConfirmDaysDialog(
        rows: confirmRows(
          value,
          timezones: timezones,
          shiftPay: (shift) => plannedPay(
            shift,
            agreements: agreements,
            employmentId: employmentId,
            zoneClocks: zones,
          ),
          leavePay: (leave) => register == null
              ? null
              : plannedLeavePay(
                  leave,
                  employmentId: employmentId,
                  agreements: agreements,
                  shifts: register.shiftSheet,
                  leave: register.leaveSheet,
                ),
        ),
        onConfirm: (dates) async {
          final service = ref.read(dayPlanServiceProvider);
          final notice = StatusNoticeScope.read(context);
          final results = <LocalDate, MutationOutcome<ConfirmedDay>>{};
          for (final date in dates) {
            results[date] = await service.confirm(employmentId, date);
          }
          final done = results.values
              .whereType<Committed<ConfirmedDay>>()
              .length;
          String days(int n) => n == 1 ? '1 day' : '$n days';
          notice?.value = done == dates.length
              ? '${days(done)} confirmed.'
              : '$done of ${days(dates.length)} confirmed.';
          return results;
        },
      ),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Days unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the days',
        message: 'Finding past planned days not yet confirmed.',
      ),
    };
  }
}
