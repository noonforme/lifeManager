import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart';
import '../domain/payslip.dart';
import '../domain/reconciliation.dart';

final class PayPeriodDraft {
  const PayPeriodDraft({
    required this.employmentId,
    required this.start,
    required this.end,
    required this.label,
  });

  final EmploymentId employmentId;
  final LocalDate start;
  final LocalDate end;
  final String? label;
}

final class PayslipDraft {
  const PayslipDraft({
    required this.periodId,
    required this.issuedDate,
    required this.paidDate,
    required this.amountMinorUnits,
    required this.basis,
    required this.grossMinorUnits,
    required this.netMinorUnits,
    required this.deductionMinorUnits,
    required this.reference,
    required this.note,
  });

  final PayPeriodId periodId;
  final LocalDate issuedDate;
  final LocalDate? paidDate;
  final int amountMinorUnits;
  final RateBasis basis;
  final int? grossMinorUnits;
  final int? netMinorUnits;
  final int? deductionMinorUnits;
  final String? reference;
  final String? note;
}

typedef SubmitPayPeriod = Future<MutationOutcome<PayPeriod>> Function(
  PayPeriodDraft draft,
);
typedef SetPayPeriodState = Future<MutationOutcome<PayPeriod>> Function(
  PayPeriod period,
  PayPeriodState state,
);
typedef SubmitPayslip = Future<MutationOutcome<Payslip>> Function(
  PayslipDraft draft,
);

final class PeriodInspector extends StatefulWidget {
  const PeriodInspector({required this.period, this.onSetState, super.key})
    : employmentId = null,
      onSubmit = null;

  const PeriodInspector.create({
    required this.employmentId,
    required this.onSubmit,
    super.key,
  }) : period = null,
       onSetState = null;

  final PayPeriod? period;
  final EmploymentId? employmentId;
  final SubmitPayPeriod? onSubmit;
  final SetPayPeriodState? onSetState;

  @override
  State<PeriodInspector> createState() => _PeriodInspectorState();
}

final class _PeriodInspectorState extends State<PeriodInspector> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _label = TextEditingController();
  Map<String, String> _errors = const {};
  bool _submitting = false;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final start = LocalDate.tryParse(_start.text.trim());
    final end = LocalDate.tryParse(_end.text.trim());
    final localErrors = <String, String>{};
    if (start == null) localErrors['start'] = 'Enter a valid ISO date.';
    if (end == null) localErrors['end'] = 'Enter a valid ISO date.';
    if (localErrors.isNotEmpty) {
      setState(() => _errors = localErrors);
      return;
    }
    setState(() {
      _submitting = true;
      _errors = const {};
    });
    final outcome = await widget.onSubmit!(
      PayPeriodDraft(
        employmentId: widget.employmentId!,
        start: start!,
        end: end!,
        label: _optional(_label.text),
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (outcome case Invalid<PayPeriod>(:final fields)) {
        if (fields.containsKey('range')) {
          _errors = const {'end': 'Check the period date range.'};
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final period = widget.period;
    if (period != null) {
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Pay period',
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              period.label ?? '${period.start} – ${period.end}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${period.start} – ${period.end}'),
            const SizedBox(height: 8),
            Text(period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open'),
            if (widget.onSetState != null) ...[
              const SizedBox(height: 20),
              if (period.state == PayPeriodState.reviewed)
                OutlinedButton(
                  onPressed: () =>
                      widget.onSetState!(period, PayPeriodState.open),
                  child: const Text('Reopen period'),
                )
              else
                FilledButton(
                  onPressed: () =>
                      widget.onSetState!(period, PayPeriodState.reviewed),
                  child: const Text('Mark reviewed'),
                ),
            ],
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Create pay period',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Pay period', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _Field(
            controller: _start,
            label: 'Start date',
            fieldKey: const ValueKey('period-start'),
            error: _errors['start'],
            hint: 'YYYY-MM-DD',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _end,
            label: 'End date',
            fieldKey: const ValueKey('period-end'),
            error: _errors['end'],
            hint: 'YYYY-MM-DD',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _label,
            label: 'Label',
            fieldKey: const ValueKey('period-label'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('Create period'),
          ),
        ],
      ),
    );
  }
}

final class PayslipInspector extends StatefulWidget {
  const PayslipInspector.create({
    required this.periodId,
    required this.onSubmit,
    super.key,
  });

  final PayPeriodId periodId;
  final SubmitPayslip onSubmit;

  @override
  State<PayslipInspector> createState() => _PayslipInspectorState();
}

final class _PayslipInspectorState extends State<PayslipInspector> {
  final _issuedDate = TextEditingController();
  final _paidDate = TextEditingController();
  final _amount = TextEditingController();
  final _gross = TextEditingController();
  final _net = TextEditingController();
  final _deductions = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  RateBasis _basis = const GrossBasis();
  Map<String, String> _errors = const {};
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in [
      _issuedDate,
      _paidDate,
      _amount,
      _gross,
      _net,
      _deductions,
      _reference,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final issuedDate = LocalDate.tryParse(_issuedDate.text.trim());
    final paidDateText = _paidDate.text.trim();
    final paidDate = paidDateText.isEmpty
        ? null
        : LocalDate.tryParse(paidDateText);
    final amount = _parseMoney(_amount.text);
    final localErrors = <String, String>{};
    if (issuedDate == null) {
      localErrors['issuedDate'] = 'Enter a valid ISO date.';
    }
    if (paidDateText.isNotEmpty && paidDate == null) {
      localErrors['paidDate'] = 'Enter a valid ISO date.';
    }
    if (amount == null || amount <= 0) {
      localErrors['amount'] = 'Enter a valid amount.';
    }
    if (localErrors.isNotEmpty) {
      setState(() => _errors = localErrors);
      return;
    }

    setState(() {
      _submitting = true;
      _errors = const {};
    });
    final outcome = await widget.onSubmit(
      PayslipDraft(
        periodId: widget.periodId,
        issuedDate: issuedDate!,
        paidDate: paidDate,
        amountMinorUnits: amount!,
        basis: _basis,
        grossMinorUnits: _parseOptionalMoney(_gross.text),
        netMinorUnits: _parseOptionalMoney(_net.text),
        deductionMinorUnits: _parseOptionalMoney(_deductions.text),
        reference: _optional(_reference.text),
        note: _optional(_note.text),
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (outcome case Invalid<Payslip>(:final fields)) {
        _errors = {
          for (final entry in fields.entries)
            entry.key: _payslipIssueMessage(entry.key, entry.value.firstOrNull),
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Record payslip',
    child: Form(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Paid evidence',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _issuedDate,
            label: 'Issued date',
            fieldKey: const ValueKey('payslip-issued-date'),
            error: _errors['issuedDate'],
            hint: 'YYYY-MM-DD',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _paidDate,
            label: 'Paid date',
            error: _errors['paidDate'],
            hint: 'Optional YYYY-MM-DD',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _amount,
            label: 'Paid amount',
            fieldKey: const ValueKey('payslip-amount'),
            error: _errors['amount'],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          SegmentedButton<RateBasis>(
            segments: const [
              ButtonSegment(value: GrossBasis(), label: Text('Gross')),
              ButtonSegment(value: NetBasis(), label: Text('Net')),
            ],
            selected: {_basis},
            onSelectionChanged: (values) =>
                setState(() => _basis = values.single),
          ),
          const SizedBox(height: 12),
          _Field(controller: _gross, label: 'Gross amount'),
          const SizedBox(height: 12),
          _Field(controller: _net, label: 'Net amount'),
          const SizedBox(height: 12),
          _Field(controller: _deductions, label: 'Deductions'),
          const SizedBox(height: 12),
          _Field(
            controller: _reference,
            label: 'Reference',
            fieldKey: const ValueKey('payslip-reference'),
          ),
          const SizedBox(height: 12),
          _Field(controller: _note, label: 'Note', maxLines: 3),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('Save payslip'),
          ),
        ],
      ),
    ),
  );
}

final class ReconciliationInspector extends StatelessWidget {
  const ReconciliationInspector({required this.groups, super.key});

  final List<ReconciliationGroup> groups;

  @override
  Widget build(BuildContext context) {
    final basisTypes = groups.map((group) => group.basis.runtimeType).toSet();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Reconciliation',
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: groups.length + (basisTypes.length > 1 ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 25),
        itemBuilder: (context, index) {
          if (basisTypes.length > 1 && index == 0) {
            return const Text('Gross and net evidence cannot be combined.');
          }
          final group = groups[index - (basisTypes.length > 1 ? 1 : 0)];
          return _ReconciliationGroupView(group: group);
        },
      ),
    );
  }
}

final class _ReconciliationGroupView extends StatelessWidget {
  const _ReconciliationGroupView({required this.group});

  final ReconciliationGroup group;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${_basisLabel(group.basis)} · ${group.currency.value}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      _AmountLine(
        label: 'Expected under recorded agreement',
        value: group.expected,
      ),
      const SizedBox(height: 8),
      _AmountLine(label: 'Paid evidence', value: group.paid),
      if (group.difference != null) ...[
        const SizedBox(height: 8),
        _AmountLine(label: 'Difference', value: group.difference),
      ],
      const SizedBox(height: 10),
      Text(
        _statusLabel(group.status),
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 4),
      Text(_statusExplanation(group.status)),
      if (group.payslipIds.length > 1) ...[
        const SizedBox(height: 6),
        Text('${group.payslipIds.length} payslips'),
      ],
    ],
  );
}

final class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.value});

  final String label;
  final Money? value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: Text(label)),
      const SizedBox(width: 16),
      Text(
        value == null ? 'Not recorded' : _formatMoney(value!),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    ],
  );
}

final class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.error,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final String? error;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Semantics(
    label: error == null ? label : '$label, $error',
    textField: true,
    excludeSemantics: true,
    child: TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

String _basisLabel(RateBasis? basis) => switch (basis) {
  GrossBasis() => 'Gross',
  NetBasis() => 'Net',
  null => 'Mixed basis',
};

String _statusLabel(ReconciliationStatus status) => switch (status) {
  Balanced() => 'Balanced',
  Difference() => 'Difference',
  MissingPayslip() => 'Missing payslip',
  UnmatchedPayslip() => 'Unmatched payslip',
  MixedBasis() => 'Mixed basis',
  UnavailableReconciliation() => 'Unavailable',
  EmptyReconciliation() => 'No evidence',
};

String _statusExplanation(ReconciliationStatus status) => switch (status) {
  Balanced() => 'Expected and paid evidence balance.',
  Difference() => 'Paid evidence differs from the recorded agreement.',
  MissingPayslip() => 'No paid evidence is recorded for this estimate.',
  UnmatchedPayslip() => 'Paid evidence has no compatible estimate.',
  MixedBasis() => 'Gross and net evidence cannot be combined.',
  UnavailableReconciliation() => 'Reconciliation is unavailable.',
  EmptyReconciliation() => 'No compatible evidence is recorded.',
};

String _formatMoney(Money money) {
  final absolute = money.minorUnits.abs();
  final sign = money.minorUnits < 0 ? '-' : '';
  return '${money.currency.value} $sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
}

String _payslipIssueMessage(String field, FieldIssue? issue) {
  if (field == 'amount') return 'Enter a valid amount.';
  return switch (issue?.code) {
    FieldIssueCode.required => 'This field is required.',
    FieldIssueCode.invalid => 'Enter a valid value.',
    FieldIssueCode.conflict => 'This value conflicts with an existing record.',
    FieldIssueCode.outOfRange => 'Enter a value in the allowed range.',
    FieldIssueCode.unavailable => 'This value is unavailable.',
    null => 'Check this value.',
  };
}

int? _parseMoney(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final major = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return major * 100 + int.parse(fraction.isEmpty ? '0' : fraction);
}

int? _parseOptionalMoney(String value) {
  if (value.trim().isEmpty) return null;
  return _parseMoney(value);
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
