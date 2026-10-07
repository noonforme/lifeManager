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
import 'agreement_dialogs.dart' show AgreementLink;
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
    this.unavailable = const [],
    this.agreementFor,
    super.key,
  });

  /// The days to confirm, by date.
  final List<ConfirmRow> rows;

  /// Past days no pay agreement covers, by date: listed after [rows] in a
  /// group of their own, never ticked, never counted (added 2026-10-07).
  final List<ConfirmRow> unavailable;

  /// The way to pay an unavailable day; null offers none.
  final AgreementLink? Function(LocalDate date)? agreementFor;

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
    final Map<LocalDate, MutationOutcome<ConfirmedDay>> results;
    try {
      results = await widget.onConfirm([for (final row in _ticked) row.date]);
    } on Object {
      if (mounted) setState(() => _busy = false);
      rethrow;
    }
    if (!mounted) return;
    // A day confirmed elsewhere is as good as confirmed here, and has
    // usually left the live list already, so it never holds the dialog open.
    final problems = {
      for (final MapEntry(key: date, value: outcome) in results.entries)
        if (outcome is! Stale<ConfirmedDay>) date: ?confirmProblem(outcome),
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
    final unpaid = widget.unavailable;
    if (widget.rows.isEmpty && unpaid.isEmpty) {
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
    Widget note(String text, Color ink) => Padding(
      padding: const EdgeInsets.fromLTRB(184, 0, 4, 4),
      child: Text(text, style: style.copyWith(color: ink)),
    );
    // An unavailable day is listed with its reason, never ticked.
    Widget line(ConfirmRow row, {required bool available}) => Column(
      key: ValueKey('confirm-row-${row.date}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              SizedBox(
                width: 180,
                child: EraCheckBox(
                  label: eraBoxDate(row.date),
                  value: available && !_unticked.contains(row.date),
                  onChanged: _busy || !available
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
              cell(formatDuration(row.paidSeconds), 52, end: true),
              cell(
                row.pay == null ? '—' : formatMoney(row.pay!),
                82,
                end: true,
              ),
            ],
          ),
        ),
        if (!available) note('No pay agreement covers this day.', tokens.muted),
        if (_problems[row.date] case final problem?)
          note(problem, tokens.negative),
      ],
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
                    key: const ValueKey('confirm-days-list'),
                    children: [
                      for (final row in widget.rows) line(row, available: true),
                      if (unpaid.isNotEmpty)
                        Semantics(
                          header: true,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 22),
                            padding: const EdgeInsets.fromLTRB(5, 9, 5, 1),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: MillenniumColors.groupRowRule,
                                ),
                              ),
                            ),
                            child: Text(
                              'Without a pay agreement',
                              style: style.copyWith(
                                color: tokens.head,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      for (final row in unpaid) line(row, available: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        if (unpaid.isNotEmpty) ...[
          // One link pays the earliest: widening to it usually pays the
          // rest, and any left over stay listed for the next.
          Row(
            children: [
              Expanded(
                child: Text(
                  unpaid.length == 1
                      ? '1 day without a pay agreement'
                      : '${unpaid.length} days without a pay agreement',
                  style: style,
                ),
              ),
              if (widget.agreementFor?.call(unpaid.first.date) case final link?)
                KeyButton(
                  label: link.label,
                  onPressed: _busy ? null : link.onPressed,
                ),
            ],
          ),
          const SizedBox(height: 7),
        ],
        Text(confirmSummary(_ticked), style: style),
        FormFooter(
          children: [
            KeyButton(
              label: 'Confirm',
              kind: KeyKind.primary,
              onPressed: _busy || _ticked.isEmpty ? null : _confirm,
            ),
            DialogCancelKey(enabled: !_busy),
          ],
        ),
      ],
    );
  }
}

/// Lists the employment's days to confirm, live, and confirms them one
/// transaction at a time.
final class ConfirmDaysHost extends ConsumerWidget {
  const ConfirmDaysHost({
    required this.employmentId,
    this.agreementFor,
    super.key,
  });

  final EmploymentId employmentId;

  /// The way to pay a day no agreement covers; null offers none.
  final AgreementLink? Function(LocalDate date)? agreementFor;

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
    ExpectedPay? shiftPay(PlannedShift shift) => plannedPay(
      shift,
      agreements: agreements,
      employmentId: employmentId,
      zoneClocks: zones,
    );
    LeavePay? leavePay(PlannedLeave leave) => register == null
        ? null
        : plannedLeavePay(
            leave,
            employmentId: employmentId,
            agreements: agreements,
            shifts: register.shiftSheet,
            leave: register.leaveSheet,
          );
    // One plan gives both lists, so a day widened into pay moves between
    // them in one step and is never listed twice.
    return switch (ref.watch(pastPlannedDaysProvider(employmentId))) {
      AsyncData(:final value) => ConfirmDaysDialog(
        agreementFor: agreementFor,
        rows: confirmRows(
          value.toConfirm,
          timezones: timezones,
          shiftPay: shiftPay,
          leavePay: leavePay,
        ),
        unavailable: confirmRows(
          value.withoutAgreement,
          timezones: timezones,
          shiftPay: shiftPay,
          leavePay: leavePay,
        ),
        onConfirm: (dates) async {
          final service = ref.read(dayPlanServiceProvider);
          final notice = StatusNoticeScope.read(context);
          final results = <LocalDate, MutationOutcome<ConfirmedDay>>{};
          for (final date in dates) {
            results[date] = await service.confirm(employmentId, date);
          }
          // A day confirmed elsewhere is done, so nothing reads as failed.
          final done = results.values
              .where(
                (outcome) =>
                    outcome is Committed<ConfirmedDay> ||
                    outcome is Stale<ConfirmedDay>,
              )
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
