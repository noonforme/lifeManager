import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';

final class EmploymentDraft {
  const EmploymentDraft({required this.name, required this.legalLabel});

  final String name;
  final String? legalLabel;
}

final class AgreementDraft {
  const AgreementDraft({
    required this.employmentId,
    required this.effectiveStart,
    required this.effectiveEnd,
    required this.hourlyRateMicroEur,
    required this.basis,
    required this.overtimeThresholdMinutes,
    required this.multiplierNumerator,
    required this.multiplierDenominator,
    required this.label,
    required this.note,
  });

  final EmploymentId employmentId;
  final LocalDate effectiveStart;
  final LocalDate? effectiveEnd;
  final int hourlyRateMicroEur;
  final RateBasis basis;
  final int overtimeThresholdMinutes;
  final int multiplierNumerator;
  final int multiplierDenominator;
  final String? label;
  final String? note;
}

typedef SubmitEmployment = Future<MutationOutcome<Employment>> Function(
  EmploymentDraft draft,
);
typedef SubmitAgreement = Future<MutationOutcome<PayAgreement>> Function(
  AgreementDraft draft,
);

final class EmploymentForm extends StatefulWidget {
  const EmploymentForm({required this.onSubmit, super.key});

  final SubmitEmployment onSubmit;

  @override
  State<EmploymentForm> createState() => _EmploymentFormState();
}

final class _EmploymentFormState extends State<EmploymentForm> {
  final _name = TextEditingController();
  final _legalLabel = TextEditingController();
  String? _nameError;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _legalLabel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _nameError = null;
    });
    final outcome = await widget.onSubmit(
      EmploymentDraft(
        name: _name.text.trim(),
        legalLabel: _optional(_legalLabel.text),
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (outcome case Invalid<Employment>(:final fields)) {
        _nameError = _issueMessage(fields['name']?.firstOrNull);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Create employment',
      child: Form(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Employment details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _name,
              label: 'Employment name',
              fieldKey: const ValueKey('employment-name'),
              error: _nameError,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _Field(controller: _legalLabel, label: 'Legal label'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Save employment'),
            ),
          ],
        ),
      ),
    );
  }
}

final class AgreementForm extends StatefulWidget {
  const AgreementForm({
    required this.employmentId,
    required this.onSubmit,
    super.key,
  });

  final EmploymentId employmentId;
  final SubmitAgreement onSubmit;

  @override
  State<AgreementForm> createState() => _AgreementFormState();
}

final class _AgreementFormState extends State<AgreementForm> {
  final _effectiveStart = TextEditingController();
  final _effectiveEnd = TextEditingController();
  final _hourlyRate = TextEditingController();
  final _threshold = TextEditingController();
  final _numerator = TextEditingController();
  final _denominator = TextEditingController();
  final _label = TextEditingController();
  final _note = TextEditingController();
  RateBasis _basis = const GrossBasis();
  Map<String, String> _errors = const {};
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in [
      _effectiveStart,
      _effectiveEnd,
      _hourlyRate,
      _threshold,
      _numerator,
      _denominator,
      _label,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final start = LocalDate.tryParse(_effectiveStart.text.trim());
    final endText = _effectiveEnd.text.trim();
    final end = endText.isEmpty ? null : LocalDate.tryParse(endText);
    final rate = _parseEurMicros(_hourlyRate.text.trim());
    final threshold = int.tryParse(_threshold.text.trim());
    final numerator = int.tryParse(_numerator.text.trim());
    final denominator = int.tryParse(_denominator.text.trim());
    final localErrors = <String, String>{};
    if (start == null) {
      localErrors['effectiveStart'] = 'Enter a valid ISO date.';
    }
    if (endText.isNotEmpty && end == null) {
      localErrors['effectiveEnd'] = 'Enter a valid ISO date.';
    }
    if (rate == null || rate <= 0) {
      localErrors['hourlyRate'] = 'Enter a rate above zero.';
    }
    if (threshold == null || threshold <= 0) {
      localErrors['overtimeThreshold'] = 'Enter paid minutes above zero.';
    }
    if (numerator == null || numerator <= 0) {
      localErrors['multiplierNumerator'] = 'Enter a positive numerator.';
    }
    if (denominator == null || denominator <= 0) {
      localErrors['multiplierDenominator'] = 'Enter a positive denominator.';
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
      AgreementDraft(
        employmentId: widget.employmentId,
        effectiveStart: start!,
        effectiveEnd: end,
        hourlyRateMicroEur: rate!,
        basis: _basis,
        overtimeThresholdMinutes: threshold!,
        multiplierNumerator: numerator!,
        multiplierDenominator: denominator!,
        label: _optional(_label.text),
        note: _optional(_note.text),
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (outcome case Invalid<PayAgreement>(:final fields)) {
        _errors = _agreementErrors(fields);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Create agreement',
      child: Form(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Agreement facts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _effectiveStart,
              label: 'Effective start',
              fieldKey: const ValueKey('agreement-effective-start'),
              error: _errors['effectiveStart'],
              hint: 'YYYY-MM-DD',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _effectiveEnd,
              label: 'Effective end',
              error: _errors['effectiveEnd'],
              hint: 'Optional YYYY-MM-DD',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _hourlyRate,
              label: 'Hourly rate in EUR',
              fieldKey: const ValueKey('agreement-hourly-rate'),
              semanticLabel: 'Hourly rate',
              error: _errors['hourlyRate'],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
            _Field(
              controller: _threshold,
              label: 'Overtime threshold minutes',
              fieldKey: const ValueKey('agreement-threshold'),
              error: _errors['overtimeThreshold'],
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _numerator,
              label: 'Multiplier numerator',
              fieldKey: const ValueKey('agreement-multiplier-numerator'),
              error: _errors['multiplierNumerator'],
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _denominator,
              label: 'Multiplier denominator',
              fieldKey: const ValueKey('agreement-multiplier-denominator'),
              error: _errors['multiplierDenominator'],
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _Field(controller: _label, label: 'Agreement label'),
            const SizedBox(height: 12),
            _Field(controller: _note, label: 'Agreement note', maxLines: 3),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('save-agreement'),
              onPressed: _submitting ? null : _submit,
              child: const Text('Save agreement'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.semanticLabel,
    this.fieldKey,
    this.error,
    this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? semanticLabel;
  final Key? fieldKey;
  final String? error;
  final String? hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final baseLabel = semanticLabel ?? label;
    return Semantics(
      label: error == null ? baseLabel : '$baseLabel, $error',
      textField: true,
      excludeSemantics: true,
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        autofocus: autofocus,
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
}

Map<String, String> _agreementErrors(Map<String, List<FieldIssue>> fields) {
  final errors = <String, String>{};
  for (final entry in fields.entries) {
    final message = _issueMessage(entry.value.firstOrNull);
    if (message == null) continue;
    switch (entry.key) {
      case 'hourlyRate':
        errors['hourlyRate'] = 'Enter a rate above zero.';
      case 'effectiveRange':
        errors['effectiveEnd'] = 'This effective range overlaps an agreement.';
      case 'agreement':
        errors['hourlyRate'] = 'Check the agreement values.';
      default:
        errors[entry.key] = message;
    }
  }
  return errors;
}

String? _issueMessage(FieldIssue? issue) => switch (issue?.code) {
  FieldIssueCode.required => 'This field is required.',
  FieldIssueCode.invalid => 'Enter a valid value.',
  FieldIssueCode.conflict => 'This value conflicts with an existing record.',
  FieldIssueCode.outOfRange => 'Enter a value in the allowed range.',
  FieldIssueCode.unavailable => 'This value is unavailable.',
  null => null,
};

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _parseEurMicros(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,6}))?$').firstMatch(value);
  if (match == null) return null;
  final major = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(6, '0');
  return major * 1000000 + int.parse(fraction.isEmpty ? '0' : fraction);
}
