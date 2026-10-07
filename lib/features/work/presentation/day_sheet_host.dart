import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart' show KeyKind;
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../domain/day_exception.dart';
import '../domain/ids.dart';
import '../domain/planner.dart';
import 'agreement_dialogs.dart' show AgreementLink;
import 'day_sheet.dart';
import 'work_controller.dart';
import 'work_plan_view.dart';

/// Reads one date's plan and binds its Properties to [DayPlanService].
final class DaySheetHost extends ConsumerWidget {
  const DaySheetHost({
    required this.employmentId,
    required this.date,
    required this.today,
    this.agreementFor,
    super.key,
  });

  final EmploymentId employmentId;
  final LocalDate date;
  final LocalDate today;

  /// The way to pay a day no agreement covers; null offers none.
  final AgreementLink? Function(LocalDate date)? agreementFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zoneClocksProvider);
    final timezones = ref.watch(timezoneServiceProvider);
    final register = switch (ref.watch(
      employmentRegisterProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final service = ref.read(dayPlanServiceProvider);
    Future<MutationOutcome<T>> noted<T>(
      Future<MutationOutcome<T>> pending,
      String notice,
    ) async {
      final outcome = await pending;
      if (outcome is Committed<T> && context.mounted) {
        StatusNoticeScope.read(context)?.value = notice;
      }
      return outcome;
    }

    return switch (ref.watch(planInputsProvider(employmentId))) {
      AsyncData(value: final inputs) => () {
        final day = planDays(
          from: date,
          to: date,
          schedules: inputs.schedules,
          exceptions: inputs.exceptions,
          confirmedDates: inputs.confirmedDates,
          zoneClocks: zones,
        ).firstOrNull;
        final exception = inputs.exceptions
            .where((value) => value.date == date)
            .firstOrNull;
        final expected = exception?.revision;
        final withoutAgreement =
            day != null &&
            lacksAgreement(
              day,
              employmentId: employmentId,
              agreements: inputs.agreements,
            );
        return DaySheet(
          key: ValueKey(('day', date, exception?.updatedAtUtc)),
          date: date,
          today: today,
          day: day,
          confirmed: inputs.confirmedDates.contains(date),
          withoutAgreement: withoutAgreement,
          agreement: withoutAgreement ? agreementFor?.call(date) : null,
          schedule: inputs.schedules
              .where((value) => value.isInUseOn(date))
              .firstOrNull,
          pay: day is PlannedShift
              ? plannedPay(
                  day,
                  agreements: inputs.agreements,
                  employmentId: employmentId,
                  zoneClocks: zones,
                )
              : null,
          leavePay: day is PlannedLeave && register != null
              ? plannedLeavePay(
                  day,
                  employmentId: employmentId,
                  agreements: inputs.agreements,
                  shifts: register.shiftSheet,
                  leave: register.leaveSheet,
                )
              : null,
          timezones: timezones,
          onConfirm: () =>
              noted(service.confirm(employmentId, date), 'Day confirmed.'),
          onChange: (times) => noted(
            service.changeDay(
              employmentId,
              date,
              start: times.start,
              end: times.end,
              endDayOffset: times.endDayOffset,
              breaks: times.breaks,
              shiftTypeId: times.shiftTypeId,
              expected: expected,
            ),
            'Day changed.',
          ),
          onCancelShift: (reason, note) => noted(
            service.cancelDay(
              employmentId,
              date,
              reason: reason,
              note: note,
              expected: expected,
            ),
            'Shift cancelled.',
          ),
          onMarkLeave: (type, illness) => noted(
            service.markLeave(
              employmentId,
              date,
              leaveType: type,
              illnessStartedOn: illness,
              expected: expected,
            ),
            'Marked as leave.',
          ),
          onAddExtra: (times) => noted(
            service.addExtra(
              employmentId,
              date,
              start: times.start,
              end: times.end,
              endDayOffset: times.endDayOffset,
              breaks: times.breaks,
              shiftTypeId: times.shiftTypeId,
              countsAsOvertime: times.countsAsOvertime,
              expected: expected,
            ),
            'Extra shift added.',
          ),
          onRemoveException: () => exception == null
              ? Future.value(const Missing<DayException>())
              : noted(
                  service.removeException(
                    exception.id,
                    expected: exception.revision,
                  ),
                  'Day restored to its schedule.',
                ),
        );
      }(),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Day unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the day',
        message: 'Planning this date from its schedule.',
      ),
    };
  }
}

enum AddDayKind { extraShift, leave }

/// + Add › Extra shift… and Leave…: a date, then the day's times or leave
/// type (schedules spec 5).
final class AddDayHost extends ConsumerStatefulWidget {
  const AddDayHost({
    required this.employmentId,
    required this.kind,
    required this.today,
    super.key,
  });

  final EmploymentId employmentId;
  final AddDayKind kind;
  final LocalDate today;

  @override
  ConsumerState<AddDayHost> createState() => _AddDayHostState();
}

final class _AddDayHostState extends ConsumerState<AddDayHost> {
  late LocalDate _date = widget.today;
  var _type = LeaveType.vacation;
  LocalDate? _illness;
  String? _error;
  bool _busy = false;

  String? _words(MutationOutcome<DayException> outcome) => switch (outcome) {
    Invalid(:final fields)
        when fields['date']?.any(
              (issue) => issue.code == FieldIssueCode.conflict,
            ) ??
            false =>
      'This day is already confirmed.',
    Invalid(:final fields) when fields.containsKey('date') =>
      widget.kind == AddDayKind.extraShift
          ? 'The schedule plans a shift on this date. Open the day to '
                'change it instead.'
          : 'The schedule plans no shift on this date.',
    _ => dayProblem(outcome),
  };

  @override
  Widget build(BuildContext context) {
    final inputs = switch (ref.watch(planInputsProvider(widget.employmentId))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final schedule = inputs?.schedules
        .where((value) => value.isInUseOn(_date))
        .firstOrNull;
    final exception = inputs?.exceptions
        .where((value) => value.date == _date)
        .firstOrNull;
    final service = ref.read(dayPlanServiceProvider);
    final date = EraFormScope(
      labelWidth: 110,
      child: EraDateField(
        fieldKey: const ValueKey('add-day-date'),
        label: 'Date',
        value: _date,
        today: widget.today,
        onChanged: (value) => setState(() {
          _date = value ?? _date;
          _error = null;
        }),
      ),
    );
    final noSchedule = inputs != null && schedule == null
        ? const InspectorNote('No schedule is in use on this date.')
        : null;
    if (widget.kind == AddDayKind.extraShift) {
      return DayTimesForm(
        key: ValueKey(('add-extra', _date, schedule?.version)),
        types: schedule?.shiftTypes ?? const [],
        initial: dayTimesOfType(schedule?.shiftTypes.firstOrNull),
        extra: true,
        submitLabel: 'Add extra shift',
        leading: [date, const SizedBox(height: 7), ?noSchedule],
        describe: _words,
        onSubmit: (times) async {
          final outcome = await service.addExtra(
            widget.employmentId,
            _date,
            start: times.start,
            end: times.end,
            endDayOffset: times.endDayOffset,
            breaks: times.breaks,
            shiftTypeId: times.shiftTypeId,
            countsAsOvertime: times.countsAsOvertime,
            expected: exception?.revision,
          );
          if (outcome is Committed<DayException> && mounted) {
            StatusNoticeScope.read(this.context)?.value = 'Extra shift added.';
          }
          return outcome;
        },
      );
    }
    Future<void> mark() async {
      setState(() {
        _busy = true;
        _error = null;
      });
      final outcome = await service.markLeave(
        widget.employmentId,
        _date,
        leaveType: _type,
        illnessStartedOn: _type == LeaveType.sick ? _illness : null,
        expected: exception?.revision,
      );
      if (!mounted) return;
      if (outcome is Committed<DayException>) {
        StatusNoticeScope.read(this.context)?.value = 'Marked as leave.';
        ShellDialogScope.closeOf(this.context)?.call();
        return;
      }
      setState(() {
        _busy = false;
        _error = _words(outcome);
      });
    }

    return DialogForm(
      fields: [
        date,
        const SizedBox(height: 7),
        ?noSchedule,
        EraRadioGroup<LeaveType>(
          options: const [
            EraRadioOption(LeaveType.vacation, 'Vacation'),
            EraRadioOption(LeaveType.sick, 'Sick'),
          ],
          groupValue: _type,
          onChanged: (value) => setState(() => _type = value),
        ),
        if (_type == LeaveType.sick)
          EraFormScope(
            labelWidth: 110,
            child: EraDateField(
              fieldKey: const ValueKey('add-day-illness'),
              label: 'Illness started on',
              value: _illness,
              optional: true,
              today: widget.today,
              onChanged: (value) => setState(() => _illness = value),
            ),
          ),
        if (_error case final error?)
          InspectorNote(error, tone: FactTone.negative),
      ],
      keys: [
        KeyButton(
          label: 'Mark as leave',
          kind: KeyKind.primary,
          onPressed: _busy ? null : mark,
        ),
        const DialogCancelKey(),
      ],
    );
  }
}
