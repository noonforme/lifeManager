import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/timezone_service.dart';
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
typedef MutateBreak = Future<MutationOutcome<WorkShift>> Function(
  ShiftBreak value,
);

final class WorkInspector extends StatefulWidget {
  const WorkInspector.fromProjection({
    required this.projection,
    required this.onStartBreak,
    required this.onEndBreak,
    required this.onEndShift,
    required this.onFinalize,
    this.durationLabel,
    this.timezones,
    super.key,
  }) : onCorrect = null,
       onSetPeriodState = null,
       onRecordPayslip = null,
       reconciliation = const [];

  const WorkInspector.fromRecord({
    required this.projection,
    this.onSetPeriodState,
    this.onRecordPayslip,
    this.reconciliation = const [],
    this.onStartBreak,
    this.onEndBreak,
    this.onEndShift,
    this.onFinalize,
    this.onCorrect,
    this.timezones,
    super.key,
  }) : durationLabel = null;

  final WorkRecordProjection projection;
  final SetPayPeriodState? onSetPeriodState;
  final VoidCallback? onRecordPayslip;
  final List<ReconciliationGroup> reconciliation;
  final MutateShift? onStartBreak;
  final MutateBreak? onEndBreak;
  final MutateShift? onEndShift;
  final MutateShift? onFinalize;
  final String? durationLabel;

  /// Reads a shift's facts on its own wall clock.
  final TimezoneService? timezones;

  /// Opens void-and-replace confirmation for a finalized shift or an
  /// effective payslip.
  final VoidCallback? onCorrect;

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

  Future<MutationOutcome<WorkShift>> _runLifecycle(
    Future<MutationOutcome<WorkShift>> Function()? action,
  ) async {
    if (action == null) return const Missing<WorkShift>();
    final outcome = await action();
    if (mounted) {
      setState(() {
        _lifecycleFailure = outcome is Committed<WorkShift> ? null : outcome;
      });
    }
    return outcome;
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
    };
  }

  Widget _shiftInspector(ShiftRecordProjection projection) {
    final failure = _lifecycleFailure;
    if (failure != null) {
      return _lifecycleOutcome(failure);
    }
    final shift = projection.shift;
    final onStartBreak = widget.onStartBreak;
    final onEndBreak = widget.onEndBreak;
    final onEndShift = widget.onEndShift;
    final onFinalize = widget.onFinalize;
    return switch (shift.state) {
      ShiftState.running => RunningShiftInspector(
        shift: shift,
        durationLabel: widget.durationLabel,
        onStartBreak: () => _runLifecycle(
          onStartBreak == null ? null : () => onStartBreak(shift),
        ),
        onEndShift: () =>
            _runLifecycle(onEndShift == null ? null : () => onEndShift(shift)),
      ),
      ShiftState.onBreak => OnBreakShiftInspector(
        shift: shift,
        durationLabel: widget.durationLabel,
        onEndBreak: () => _runLifecycle(
          onEndBreak == null
              ? null
              : () => onEndBreak(
                  projection.breaks.singleWhere(
                    (value) => value.endUtc == null,
                  ),
                ),
        ),
      ),
      ShiftState.draft when shift.endUtc != null && onFinalize != null =>
        FinalizeShiftInspector(
          shift: shift,
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
          breaks: projection.breaks,
          timezones: widget.timezones,
          pay: projection.pay,
          onCorrect: widget.onCorrect,
        ),
      ),
      ShiftState.draft || ShiftState.voided => const _UnavailableShift(),
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
    this.timezones,
    this.pay,
    this.onCorrect,
  });

  final WorkShift shift;
  final List<ShiftBreak> breaks;
  final TimezoneService? timezones;
  final ExpectedPay? pay;
  final VoidCallback? onCorrect;

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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Shift finalized',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _Fact(label: 'Date', value: shift.localStartDate.toString()),
        _Fact(
          label: 'Time',
          value:
              '${clock(shift.startUtc)}–'
              '${shift.endUtc == null ? '' : clock(shift.endUtc!)}',
        ),
        _Fact(
          label: 'Breaks',
          value: breaks.isEmpty
              ? 'None'
              : '${breaks.length} · ${formatDuration(breakSeconds)}',
        ),
        _Fact(label: 'Timezone', value: shift.timezoneId),
        if (shift.note case final note?) _Fact(label: 'Note', value: note),
        const Divider(height: 20),
        if (pay case final pay?) ...[
          _Fact(label: 'Expected pay', value: formatMoney(pay.amount)),
          _Fact(
            label: 'Paid time',
            value: formatDuration(pay.totalPaidSeconds),
          ),
          _Fact(
            label: 'Regular hours',
            value: formatDuration(pay.regularPaidSeconds),
          ),
          _Fact(
            label: 'Night hours',
            value: formatDuration(pay.nightPaidSeconds),
          ),
          _Fact(
            label: 'Holiday hours',
            value: formatDuration(pay.holidayPaidSeconds),
          ),
          _Fact(
            label: 'Overtime hours',
            value: formatDuration(pay.overtimePaidSeconds),
          ),
          const SizedBox(height: 4),
          const Text(
            'Expected pay is an estimate until a payslip confirms it. '
            'Hours can count in more than one premium.',
          ),
        ] else
          const Text('The recorded agreement now determines the estimate.'),
        if (onCorrect != null) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onCorrect,
              child: const Text('Correct shift'),
            ),
          ),
        ],
      ],
    );
  }
}

final class _PayslipDetail extends StatelessWidget {
  const _PayslipDetail({required this.payslip, this.onCorrect});

  final Payslip payslip;
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Payslip',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Paid evidence', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        _Fact(label: 'Amount', value: _money(payslip.amount)),
        _Fact(label: 'Basis', value: _basis(payslip.basis)),
        _Fact(label: 'Issued', value: payslip.issuedDate.toString()),
        if (payslip.paidDate != null)
          _Fact(label: 'Paid', value: payslip.paidDate.toString()),
        if (payslip.reference != null)
          _Fact(label: 'Reference', value: payslip.reference!),
        if (onCorrect != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onCorrect,
              child: const Text('Correct payslip'),
            ),
          ),
        ],
      ],
    ),
  );
}

final class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

final class _UnavailableRecord extends StatelessWidget {
  const _UnavailableRecord();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(20),
    child: Text('This Work record is not available in this inspector.'),
  );
}

String _basis(RateBasis basis) => switch (basis) {
  GrossBasis() => 'Gross',
  NetBasis() => 'Net',
};

String _money(Money money) {
  final absolute = money.minorUnits.abs();
  final sign = money.minorUnits < 0 ? '-' : '';
  return '${money.currency.value} $sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
}

final class _UnavailableShift extends StatelessWidget {
  const _UnavailableShift({this.title, this.onDismiss});

  final String? title;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        const Text('This shift is not available for the live workflow.'),
        if (onDismiss != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onDismiss,
            child: const Text('Review shift'),
          ),
        ],
      ],
    ),
  );
}
