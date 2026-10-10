import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/timezone_service.dart';
import '../../../ui/ui.dart';
import '../data/projections/work_record_projection.dart';
import '../domain/facts.dart';
import '../domain/pay.dart';
import '../domain/payslip.dart';
import '../domain/reconciliation.dart';
import '../domain/shift.dart';
import 'correction_confirmation.dart';
import 'period_payslip_forms.dart';
import 'shift_forms.dart';
import 'work_formats.dart';

typedef MutateShift = Future<MutationOutcome<WorkShift>> Function(
  WorkShift shift,
);

final class WorkInspector extends StatefulWidget {
  const WorkInspector.fromRecord({
    required this.projection,
    this.onSetPeriodState,
    this.onRecordPayslip,
    this.reconciliation = const [],
    this.onFinalize,
    this.onCorrect,
    this.onRemove,
    this.timezones,
    this.shiftFields,
    super.key,
  });

  final WorkRecordProjection projection;

  /// A shift's times as form fields, editable for a draft and greyed once
  /// finalized; they stand in for the read-only Shift facts.
  final Widget? shiftFields;
  final SetPayPeriodState? onSetPeriodState;
  final VoidCallback? onRecordPayslip;
  final List<ReconciliationGroup> reconciliation;
  final MutateShift? onFinalize;

  /// Reads a shift's facts on its own wall clock.
  final TimezoneService? timezones;

  /// Opens void-and-replace confirmation for a finalized shift or an
  /// effective payslip.
  final VoidCallback? onCorrect;

  /// Asks a reason and voids a draft or finalized shift with no
  /// replacement.
  final VoidCallback? onRemove;

  @override
  State<WorkInspector> createState() => _WorkInspectorState();
}

final class _WorkInspectorState extends State<WorkInspector> {
  MutationOutcome<WorkShift>? _lifecycleFailure;

  @override
  void didUpdateWidget(covariant WorkInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.projection;
    final after = widget.projection;
    if (before is ShiftRecordProjection &&
        after is ShiftRecordProjection &&
        (before.id != after.id ||
            before.shift.revision != after.shift.revision)) {
      _lifecycleFailure = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projection = widget.projection;
    return switch (projection) {
      ShiftRecordProjection() => _shiftInspector(projection),
      PayPeriodRecordProjection(:final period) => PeriodInspector(
        period: period,
        onSetState: widget.onSetPeriodState,
        onRecordPayslip: widget.onRecordPayslip,
        reconciliation: widget.reconciliation,
      ),
      PayslipRecordProjection(:final payslip) => _PayslipDetail(
        payslip: payslip,
        onCorrect: payslip.isEffective ? widget.onCorrect : null,
      ),
      EmploymentRecordProjection() ||
      AgreementRecordProjection() => const _UnavailableRecord(),
      LeaveRecordProjection() => const SizedBox.shrink(),
    };
  }

  Widget _shiftInspector(ShiftRecordProjection projection) {
    final failure = _lifecycleFailure;
    if (failure != null) {
      return _lifecycleOutcome(failure);
    }
    final shift = projection.shift;
    final onFinalize = widget.onFinalize;
    return switch (shift.state) {
      ShiftState.draft when shift.endUtc != null && onFinalize != null =>
        FinalizeShiftInspector(
          shift: shift,
          fields: widget.shiftFields,
          onRemove: widget.onRemove,
          onFinalize: () async {
            final outcome = await onFinalize(shift);
            if (outcome is! Committed<WorkShift> &&
                outcome is! Invalid<WorkShift> &&
                mounted) {
              setState(() => _lifecycleFailure = outcome);
            }
            return outcome;
          },
        ),
      ShiftState.draft when shift.endUtc != null =>
        const ValidationFailureInspector(
          message: 'Finalizing is unavailable.',
          child: _UnavailableShift(title: 'Finalizing is unavailable.'),
        ),
      ShiftState.finalized => Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Finalized shift',
        child: _FinalizedShift(
          shift: shift,
          fields: widget.shiftFields,
          breaks: projection.breaks,
          timezones: widget.timezones,
          pay: projection.pay,
          onCorrect: widget.onCorrect,
          onRemove: widget.onRemove,
        ),
      ),
      // Kept in history: its facts greyed, with why it is void.
      ShiftState.voided => Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Void shift',
        child: _FinalizedShift(
          shift: shift,
          fields: widget.shiftFields,
          breaks: projection.breaks,
          timezones: widget.timezones,
        ),
      ),
      ShiftState.draft => const _UnavailableShift(),
    };
  }

  Widget _lifecycleOutcome(MutationOutcome<WorkShift> outcome) =>
      switch (outcome) {
        Stale<WorkShift>() => StaleConflictInspector(
          draft: const SizedBox.shrink(),
          onReload: () => setState(() => _lifecycleFailure = null),
        ),
        Missing<WorkShift>() => const MissingRecordInspector(),
        Unavailable<WorkShift>(:final code) => UnavailableInspector(code: code),
        Uncertain<WorkShift>() => const UncertainOutcomeInspector(),
        Invalid<WorkShift>() => ValidationFailureInspector(
          message: 'This shift action was rejected.',
          child: _UnavailableShift(
            title: 'This shift action was rejected. Review the shift.',
            onDismiss: () => setState(() => _lifecycleFailure = null),
          ),
        ),
        Committed<WorkShift>() => const SizedBox.shrink(),
      };
}

final class _FinalizedShift extends StatelessWidget {
  const _FinalizedShift({
    required this.shift,
    required this.breaks,
    this.fields,
    this.timezones,
    this.pay,
    this.onCorrect,
    this.onRemove,
  });

  final WorkShift shift;
  final List<ShiftBreak> breaks;
  final Widget? fields;
  final TimezoneService? timezones;
  final ExpectedPay? pay;
  final VoidCallback? onCorrect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final zones = timezones;
    String clock(DateTime utc) => zones == null
        ? '${utc.toIso8601String().substring(11, 16)} UTC'
        : zones.localTimeAt(utc, shift.timezoneId).toString().substring(0, 5);
    final breakSeconds = breaks.fold(
      0,
      (total, item) => item.endUtc == null
          ? total
          : total + item.endUtc!.difference(item.startUtc).inSeconds,
    );
    final isVoid = shift.state == ShiftState.voided;
    return InspectorPane(
      children: [
        InspectorTitle(
          isVoid ? 'Shift void' : 'Shift finalized',
          icon: EraIconKind.shift,
        ),
        if (fields case final fields?)
          fields
        else
          InspectorFacts([
            Fact('Date', shift.localStartDate.toString()),
            Fact(
              'Time',
              '${clock(shift.startUtc)}–'
                  '${shift.endUtc == null ? '' : clock(shift.endUtc!)}',
            ),
            breaks.isEmpty
                ? const Fact.words('Breaks', 'None')
                : Fact(
                    'Breaks',
                    '${breaks.length} · ${formatDuration(breakSeconds)}',
                  ),
            Fact.words('Timezone', shift.timezoneId),
            if (shift.note case final note?) Fact.words('Note', note),
          ], legend: 'Shift'),
        if (isVoid) ...[
          InspectorFacts(legend: 'Void', [
            const Fact.words('State', 'Void'),
            Fact.words('Void reason', shift.voidReason ?? ''),
            if (shift.replacementShiftId != null)
              const Fact.words('Replaced by', 'A corrected shift'),
          ]),
          const InspectorNote(
            'A void shift stays in history and no longer counts in the '
            'totals.',
          ),
        ] else if (pay case final pay?) ...[
          InspectorFacts(legend: 'Expected pay', [
            Fact('Expected pay', formatMoney(pay.amount)),
            Fact('Paid time', formatDuration(pay.totalPaidSeconds)),
            Fact('Regular hours', formatDuration(pay.regularPaidSeconds)),
            Fact('Night hours', formatDuration(pay.nightPaidSeconds)),
            Fact('Holiday hours', formatDuration(pay.holidayPaidSeconds)),
            Fact('Overtime hours', formatDuration(pay.overtimePaidSeconds)),
          ]),
          const InspectorNote(
            'Expected pay is an estimate until a payslip confirms it. '
            'Hours can count in more than one premium.',
          ),
        ] else
          const InspectorNote(
            'The recorded agreement now determines the estimate.',
          ),
        if (onCorrect != null || onRemove != null)
          InspectorActions(
            children: [
              if (onCorrect != null)
                KeyButton(label: 'Correct shift', onPressed: onCorrect),
              if (onRemove != null)
                KeyButton(label: 'Remove shift…', onPressed: onRemove),
            ],
          ),
      ],
    );
  }
}

/// A payslip's General page: its recorded evidence in the payslip's own
/// fields, greyed, since a payslip changes only through Correct.
final class _PayslipDetail extends StatefulWidget {
  const _PayslipDetail({required this.payslip, this.onCorrect});

  final Payslip payslip;
  final VoidCallback? onCorrect;

  @override
  State<_PayslipDetail> createState() => _PayslipDetailState();
}

final class _PayslipDetailState extends State<_PayslipDetail> {
  late final _amount = TextEditingController(
    text: _decimal(widget.payslip.amount.minorUnits),
  );
  late final _reference = TextEditingController(
    text: widget.payslip.reference ?? '',
  );

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payslip = widget.payslip;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Payslip',
      child: InspectorPane(
        children: [
          const InspectorTitle('Paid evidence', icon: EraIconKind.payslip),
          EraFormScope(
            labelWidth: 100,
            enabled: false,
            child: GroupBox(
              legend: 'Payslip details',
              background: LifeOSSkinScope.of(context).tokens.chrome,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EraDateField(
                    label: 'Issued date',
                    fieldKey: const ValueKey('payslip-issued-date'),
                    value: payslip.issuedDate,
                    today: payslip.issuedDate,
                    onChanged: (_) {},
                  ),
                  EraDateField(
                    label: 'Paid date',
                    optional: true,
                    fieldKey: const ValueKey('payslip-paid-date'),
                    value: payslip.paidDate,
                    today: payslip.issuedDate,
                    onChanged: (_) {},
                  ),
                  EraField(
                    controller: _amount,
                    label: 'Paid amount',
                    fieldKey: const ValueKey('payslip-amount'),
                    width: EraFieldWidth.money,
                  ),
                  EraLabelled(
                    label: 'Basis',
                    field: EraRadioGroup<RateBasis>(
                      direction: Axis.horizontal,
                      options: const [
                        EraRadioOption(GrossBasis(), 'Gross'),
                        EraRadioOption(NetBasis(), 'Net'),
                      ],
                      groupValue: payslip.basis,
                      onChanged: (_) {},
                    ),
                  ),
                  EraField(
                    controller: _reference,
                    label: 'Reference',
                    fieldKey: const ValueKey('payslip-reference'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.onCorrect != null)
            InspectorActions(
              children: [
                KeyButton(
                  label: 'Correct payslip',
                  onPressed: widget.onCorrect,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 123456 minor units as "1234.56".
String _decimal(int minorUnits) {
  final absolute = minorUnits.abs();
  final sign = minorUnits < 0 ? '-' : '';
  return '$sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
}

final class _UnavailableRecord extends StatelessWidget {
  const _UnavailableRecord();

  @override
  Widget build(BuildContext context) => const InspectorPane(
    children: [
      InspectorText('This Work record is not available in this inspector.'),
    ],
  );
}

final class _UnavailableShift extends StatelessWidget {
  const _UnavailableShift({this.title, this.onDismiss});

  final String? title;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => InspectorPane(
    children: [
      if (title case final title?) InspectorTitle(title),
      const InspectorText('This shift is not available for the live workflow.'),
      if (onDismiss != null)
        InspectorActions(
          children: [KeyButton(label: 'Review shift', onPressed: onDismiss)],
        ),
    ],
  );
}
