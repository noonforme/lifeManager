import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/era_icons.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/office_controls.dart';
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
  const PeriodInspector({
    required this.period,
    this.onSetState,
    this.onRecordPayslip,
    this.reconciliation = const [],
    super.key,
  }) : employmentId = null,
       onSubmit = null,
       today = null;

  const PeriodInspector.create({
    required this.employmentId,
    required this.onSubmit,
    required LocalDate this.today,
    super.key,
  }) : period = null,
       onSetState = null,
       onRecordPayslip = null,
       reconciliation = const [];

  final PayPeriod? period;
  final EmploymentId? employmentId;
  final SubmitPayPeriod? onSubmit;

  /// Seeds the default dates; null for the record view.
  final LocalDate? today;
  final SetPayPeriodState? onSetState;
  final VoidCallback? onRecordPayslip;
  final List<ReconciliationGroup> reconciliation;

  @override
  State<PeriodInspector> createState() => _PeriodInspectorState();
}

final class _PeriodInspectorState extends State<PeriodInspector> {
  late LocalDate _start = widget.today!.firstOfMonth;
  late LocalDate _end = widget.today!.lastOfMonth;
  final _label = TextEditingController();

  /// The stored label, shown greyed on the period's sheet.
  late final _shownLabel = TextEditingController(
    text: widget.period?.label ?? '',
  );
  Map<String, String> _errors = const {};
  bool _submitting = false;

  @override
  void dispose() {
    _label.dispose();
    _shownLabel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errors = const {};
    });
    final outcome = await widget.onSubmit!(
      PayPeriodDraft(
        employmentId: widget.employmentId!,
        start: _start,
        end: _end,
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
        child: InspectorPane(
          children: [
            InspectorTitle(
              period.label ?? 'Pay period',
              icon: EraIconKind.payPeriod,
            ),
            // The period's own fields, greyed: it changes only through
            // Mark reviewed and Reopen.
            EraFormScope(
              labelWidth: 100,
              enabled: false,
              child: _FormGroup(
                legend: 'Period',
                children: [
                  EraDateField(
                    label: 'Start date',
                    fieldKey: const ValueKey('period-start'),
                    value: period.start,
                    today: period.start,
                    onChanged: (_) {},
                  ),
                  EraDateField(
                    label: 'End date',
                    fieldKey: const ValueKey('period-end'),
                    value: period.end,
                    today: period.start,
                    onChanged: (_) {},
                  ),
                  _Field(
                    controller: _shownLabel,
                    label: 'Label',
                    fieldKey: const ValueKey('period-label'),
                  ),
                ],
              ),
            ),
            InspectorFacts([
              Fact.words(
                'State',
                period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open',
              ),
            ]),
            if (widget.onSetState != null || widget.onRecordPayslip != null)
              InspectorActions(
                children: [
                  if (widget.onSetState case final setPeriodState?)
                    if (period.state == PayPeriodState.reviewed)
                      KeyButton(
                        label: 'Reopen period',
                        onPressed: () =>
                            setPeriodState(period, PayPeriodState.open),
                      )
                    else
                      KeyButton(
                        label: 'Mark reviewed',
                        kind: KeyKind.primary,
                        onPressed: () =>
                            setPeriodState(period, PayPeriodState.reviewed),
                      ),
                  if (widget.onRecordPayslip case final record?)
                    KeyButton(label: 'Record payslip', onPressed: record),
                ],
              ),
            if (widget.reconciliation.isNotEmpty) ...[
              if (widget.reconciliation
                      .map((group) => group.basis.runtimeType)
                      .toSet()
                      .length >
                  1)
                const InspectorNote(
                  'Gross and net evidence cannot be combined.',
                ),
              for (final group in widget.reconciliation)
                _ReconciliationGroupView(group: group),
            ],
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Create pay period',
      child: EraFormScope(
        labelWidth: 100,
        child: DialogForm(
          fields: [
            _FormGroup(
              legend: 'Dates',
              children: [
                EraDateField(
                  label: 'Start date',
                  fieldKey: const ValueKey('period-start'),
                  value: _start,
                  today: widget.today!,
                  error: _errors['start'],
                  onChanged: (value) => setState(() => _start = value!),
                ),
                EraDateField(
                  label: 'End date',
                  fieldKey: const ValueKey('period-end'),
                  value: _end,
                  today: widget.today!,
                  error: _errors['end'],
                  onChanged: (value) => setState(() => _end = value!),
                ),
                _Field(
                  controller: _label,
                  label: 'Label',
                  fieldKey: const ValueKey('period-label'),
                ),
              ],
            ),
          ],
          keys: [
            KeyButton(
              label: 'Create period',
              kind: KeyKind.primary,
              onPressed: _submitting ? null : _submit,
            ),
            const DialogCancelKey(),
          ],
        ),
      ),
    );
  }
}

final class PayslipInspector extends StatefulWidget {
  const PayslipInspector.create({
    required this.periodId,
    required this.onSubmit,
    required this.today,
    super.key,
  });

  final PayPeriodId periodId;
  final SubmitPayslip onSubmit;
  final LocalDate today;

  @override
  State<PayslipInspector> createState() => _PayslipInspectorState();
}

final class _PayslipInspectorState extends State<PayslipInspector> {
  late LocalDate _issuedDate = widget.today;
  LocalDate? _paidDate;
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
    final amount = _parseMoney(_amount.text);
    final localErrors = <String, String>{};
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
        issuedDate: _issuedDate,
        paidDate: _paidDate,
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
      child: EraFormScope(
        labelWidth: 100,
        child: DialogForm(
          fields: [
            _FormGroup(
              legend: 'Payslip',
              children: [
                EraDateField(
                  label: 'Issued date',
                  fieldKey: const ValueKey('payslip-issued-date'),
                  value: _issuedDate,
                  today: widget.today,
                  error: _errors['issuedDate'],
                  onChanged: (value) => setState(() => _issuedDate = value!),
                ),
                EraDateField(
                  label: 'Paid date',
                  optional: true,
                  fieldKey: const ValueKey('payslip-paid-date'),
                  value: _paidDate,
                  today: widget.today,
                  error: _errors['paidDate'],
                  onChanged: (value) => setState(() => _paidDate = value),
                ),
                _Field(
                  controller: _amount,
                  label: 'Paid amount',
                  fieldKey: const ValueKey('payslip-amount'),
                  error: _errors['amount'],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
            _FormGroup(
              legend: 'Basis',
              children: [
                EraRadioGroup<RateBasis>(
                  direction: Axis.horizontal,
                  options: const [
                    EraRadioOption(GrossBasis(), 'Gross'),
                    EraRadioOption(NetBasis(), 'Net'),
                  ],
                  groupValue: _basis,
                  onChanged: (next) => setState(() => _basis = next),
                ),
              ],
            ),
            _FormGroup(
              legend: 'Breakdown',
              children: [
                _Field(controller: _gross, label: 'Gross amount'),
                _Field(controller: _net, label: 'Net amount'),
                _Field(controller: _deductions, label: 'Deductions'),
              ],
            ),
            _FormGroup(
              legend: 'Reference',
              children: [
                _Field(
                  controller: _reference,
                  label: 'Reference',
                  fieldKey: const ValueKey('payslip-reference'),
                ),
                _Field(controller: _note, label: 'Note', maxLines: 3),
              ],
            ),
          ],
          keys: [
            KeyButton(
              label: 'Save payslip',
              kind: KeyKind.primary,
              onPressed: _submitting ? null : _submit,
            ),
            const DialogCancelKey(),
          ],
        ),
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
      child: InspectorPane(
        children: [
          if (basisTypes.length > 1)
            const InspectorNote('Gross and net evidence cannot be combined.'),
          for (final group in groups) _ReconciliationGroupView(group: group),
        ],
      ),
    );
  }
}

final class _ReconciliationGroupView extends StatelessWidget {
  const _ReconciliationGroupView({required this.group});

  final ReconciliationGroup group;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorFacts(
        legend: '${_basisLabel(group.basis)} · ${group.currency.value}',
        [
          _amount('Expected under recorded agreement', group.expected),
          _amount('Paid evidence', group.paid),
          if (group.difference != null) _amount('Difference', group.difference),
          Fact.words('Status', _statusLabel(group.status)),
        ],
      ),
      InspectorNote(_statusExplanation(group.status)),
      if (group.payslipIds.length > 1)
        InspectorNote('${group.payslipIds.length} payslips'),
    ],
  );
}

Fact _amount(String label, Money? value) => value == null
    ? Fact.words(label, 'Not recorded')
    : Fact(label, _formatMoney(value));

/// A form's group box on the face colour, its fields 10 px apart.
final class _FormGroup extends StatelessWidget {
  const _FormGroup({required this.legend, required this.children});

  final String legend;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GroupBox(
    legend: legend,
    background: LifeOSSkinScope.of(context).tokens.chrome,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // Label rows carry their own 7 px between them.
      children: children,
    ),
  );
}

final class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.error,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final String? error;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) => EraField(
    controller: controller,
    label: label,
    fieldKey: fieldKey,
    error: error,
    keyboardType: keyboardType,
    maxLines: maxLines,
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
