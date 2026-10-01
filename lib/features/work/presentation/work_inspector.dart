import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../data/projections/work_record_projection.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/pay.dart';
import '../domain/payslip.dart';
import '../domain/shift.dart';
import 'employment_agreement_forms.dart';
import 'period_payslip_forms.dart';
import 'shift_forms.dart';

enum _SetupStep { introduction, employment, agreement, ready }

typedef MutateShift = Future<MutationOutcome<WorkShift>> Function(
  WorkShift shift,
);
typedef MutateBreak = Future<MutationOutcome<WorkShift>> Function(
  ShiftBreak value,
);

final class WorkInspector extends StatefulWidget {
  const WorkInspector({
    required this.onCreateEmployment,
    required this.onCreateAgreement,
    this.onStartShift,
    this.onAddManualShift,
    super.key,
  }) : projection = null,
       onSetPeriodState = null,
       onStartBreak = null,
       onEndBreak = null,
       onEndShift = null,
       onFinalize = null,
       durationLabel = null,
       suggestedOvertimeMinutes = null;

  const WorkInspector.fromProjection({
    required this.projection,
    required this.onStartBreak,
    required this.onEndBreak,
    required this.onEndShift,
    required this.onFinalize,
    this.durationLabel,
    this.suggestedOvertimeMinutes,
    super.key,
  }) : onSetPeriodState = null,
       onCreateEmployment = null,
       onCreateAgreement = null,
       onStartShift = null,
       onAddManualShift = null;

  const WorkInspector.fromRecord({
    required this.projection,
    this.onSetPeriodState,
    super.key,
  }) : onCreateEmployment = null,
       onCreateAgreement = null,
       onStartShift = null,
       onAddManualShift = null,
       onStartBreak = null,
       onEndBreak = null,
       onEndShift = null,
       onFinalize = null,
       durationLabel = null,
       suggestedOvertimeMinutes = null;

  final SubmitEmployment? onCreateEmployment;
  final SubmitAgreement? onCreateAgreement;
  final VoidCallback? onStartShift;
  final VoidCallback? onAddManualShift;
  final WorkRecordProjection? projection;
  final SetPayPeriodState? onSetPeriodState;
  final MutateShift? onStartBreak;
  final MutateBreak? onEndBreak;
  final MutateShift? onEndShift;
  final FinalizeOvertime? onFinalize;
  final String? durationLabel;
  final int? suggestedOvertimeMinutes;

  @override
  State<WorkInspector> createState() => _WorkInspectorState();
}

final class _WorkInspectorState extends State<WorkInspector> {
  _SetupStep _step = _SetupStep.introduction;
  Employment? _employment;
  PayAgreement? _agreement;

  Future<MutationOutcome<Employment>> _createEmployment(
    EmploymentDraft draft,
  ) async {
    final outcome = await widget.onCreateEmployment!(draft);
    if (mounted) {
      if (outcome case Committed<Employment>(:final value)) {
        setState(() {
          _employment = value;
          _step = _SetupStep.agreement;
        });
      }
    }
    return outcome;
  }

  Future<MutationOutcome<PayAgreement>> _createAgreement(
    AgreementDraft draft,
  ) async {
    final outcome = await widget.onCreateAgreement!(draft);
    if (mounted) {
      if (outcome case Committed<PayAgreement>(:final value)) {
        setState(() {
          _agreement = value;
          _step = _SetupStep.ready;
        });
      }
    }
    return outcome;
  }

  @override
  Widget build(BuildContext context) {
    final projection = widget.projection;
    if (projection != null) {
      return switch (projection) {
        ShiftRecordProjection() => _shiftInspector(projection),
        PayPeriodRecordProjection(:final period) => PeriodInspector(
          period: period,
          onSetState: widget.onSetPeriodState,
        ),
        PayslipRecordProjection(:final payslip) => _PayslipDetail(
          payslip: payslip,
        ),
        EmploymentRecordProjection() => const _UnavailableRecord(),
      };
    }
    return switch (_step) {
      _SetupStep.introduction => _Introduction(
        onCreate: () => setState(() => _step = _SetupStep.employment),
      ),
      _SetupStep.employment => EmploymentForm(onSubmit: _createEmployment),
      _SetupStep.agreement => AgreementForm(
        employmentId: _employment!.id,
        onSubmit: _createAgreement,
      ),
      _SetupStep.ready => _Ready(
        employment: _employment!,
        agreement: _agreement!,
        onStartShift: widget.onStartShift,
        onAddManualShift: widget.onAddManualShift,
      ),
    };
  }

  Widget _shiftInspector(ShiftRecordProjection projection) {
    final shift = projection.shift;
    return switch (shift.state) {
      ShiftState.running => RunningShiftInspector(
        shift: shift,
        durationLabel: widget.durationLabel,
        onStartBreak: () => widget.onStartBreak!(shift),
        onEndShift: () => widget.onEndShift!(shift),
      ),
      ShiftState.onBreak => OnBreakShiftInspector(
        shift: shift,
        durationLabel: widget.durationLabel,
        onEndBreak: () => widget.onEndBreak!(
          projection.breaks.singleWhere((value) => value.endUtc == null),
        ),
      ),
      ShiftState.draft
          when shift.endUtc != null &&
              widget.suggestedOvertimeMinutes != null =>
        OvertimeConfirmationInspector(
          shift: shift,
          suggestedOvertimeMinutes: widget.suggestedOvertimeMinutes!,
          enteredOvertimeMinutes: shift.overtimeMinutes,
          onFinalize: widget.onFinalize!,
        ),
      ShiftState.draft when shift.endUtc != null =>
        const ValidationFailureInspector(
          message: 'Overtime suggestion unavailable.',
          child: _UnavailableShift(),
        ),
      ShiftState.finalized => Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Finalized shift',
        child: const _FinalizedShift(),
      ),
      ShiftState.draft || ShiftState.voided => const _UnavailableShift(),
    };
  }
}

final class _Introduction extends StatelessWidget {
  const _Introduction({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set up Work', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        const Text(
          'Create an employment and an agreement before recording paid work.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onCreate,
          child: const Text('Create employment'),
        ),
      ],
    ),
  );
}

final class _Ready extends StatelessWidget {
  const _Ready({
    required this.employment,
    required this.agreement,
    required this.onStartShift,
    required this.onAddManualShift,
  });

  final Employment employment;
  final PayAgreement agreement;
  final VoidCallback? onStartShift;
  final VoidCallback? onAddManualShift;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(employment.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Agreement ${agreement.version} is effective.'),
        const SizedBox(height: 18),
        FilledButton(onPressed: onStartShift, child: const Text('Start shift')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onAddManualShift,
          child: const Text('Add manual shift'),
        ),
      ],
    ),
  );
}

final class _FinalizedShift extends StatelessWidget {
  const _FinalizedShift();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift finalized',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('The recorded agreement now determines the estimate.'),
      ],
    ),
  );
}

final class _PayslipDetail extends StatelessWidget {
  const _PayslipDetail({required this.payslip});

  final Payslip payslip;

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
  const _UnavailableShift();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(20),
    child: Text('This shift is not available for the live workflow.'),
  );
}
