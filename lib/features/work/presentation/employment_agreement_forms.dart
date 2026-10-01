import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../application/work_commands.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import 'work_formats.dart';

final class EmploymentDraft {
  const EmploymentDraft({required this.name, required this.legalLabel});

  final String name;
  final String? legalLabel;
}

final class AgreementDraft {
  const AgreementDraft({required this.employmentId, required this.terms});

  final EmploymentId employmentId;
  final AgreementTerms terms;
}

typedef SubmitEmployment = Future<MutationOutcome<Employment>> Function(
  EmploymentDraft draft,
);
typedef SubmitAgreement = Future<MutationOutcome<PayAgreement>> Function(
  AgreementDraft draft,
);
typedef DeleteEmployment = Future<MutationOutcome<Employment>> Function(
  Employment employment,
);

/// Section 9 messages for outcomes that are not about one field.
const staleMessage =
    'This changed since you opened it. Reload to see the latest.';
const agreementInUseMessage =
    "This agreement is used by finished shifts and can't be edited.";
const employmentHistoryMessage =
    "This employment has work history and can't be deleted.";
const multiplierMessage = 'Enter a multiplier of 1 or more, e.g. 1.5';
const nightWindowMessage = 'Night pay start and end must differ';

/// Creates an employment, or edits [initial] with the same fields.
final class EmploymentForm extends StatefulWidget {
  const EmploymentForm({required this.onSubmit, this.initial, super.key});

  final SubmitEmployment onSubmit;
  final Employment? initial;

  @override
  State<EmploymentForm> createState() => _EmploymentFormState();
}

final class _EmploymentFormState extends State<EmploymentForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _legalLabel = TextEditingController(
    text: widget.initial?.legalLabel,
  );
  String? _nameError;
  String? _formError;
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
      _formError = null;
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
      switch (outcome) {
        case Invalid<Employment>(:final fields) when fields.containsKey('name'):
          _nameError = 'Enter a name.';
        case Invalid<Employment>():
          _formError = 'Check the employment details.';
        case Stale<Employment>():
          _formError = staleMessage;
        case Missing<Employment>():
          _formError = 'This employment no longer exists.';
        case Unavailable<Employment>() || Uncertain<Employment>():
          _formError = 'Local storage is unavailable. Try again.';
        case Committed<Employment>():
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: editing ? 'Edit employment' : 'Create employment',
      child: Form(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              editing ? 'Edit employment' : 'Employment details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _Field(
              controller: _name,
              label: 'Name',
              fieldKey: const ValueKey('employment-name'),
              error: _nameError,
              hint: 'What you call this job, e.g. Warehouse',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _legalLabel,
              label: 'Legal name (optional)',
              fieldKey: const ValueKey('employment-legal-name'),
              hint: 'Employer name as it appears on payslips',
            ),
            if (_formError case final error?) ...[
              const SizedBox(height: 12),
              _ErrorText(error),
            ],
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

/// Creates an agreement with the Labour Code defaults filled in, or edits
/// an unused [initial] agreement with the same fields.
final class AgreementForm extends StatefulWidget {
  const AgreementForm({
    required this.employmentId,
    required this.onSubmit,
    this.initial,
    this.today,
    super.key,
  });

  final EmploymentId employmentId;
  final SubmitAgreement onSubmit;
  final PayAgreement? initial;

  /// The default start date for a new agreement; the local date when null.
  final LocalDate? today;

  @override
  State<AgreementForm> createState() => _AgreementFormState();
}

final class _AgreementFormState extends State<AgreementForm> {
  late final PayAgreement? _initial = widget.initial;
  late final _effectiveStart = TextEditingController(
    text: (_initial?.effectiveStart ?? widget.today ?? _localToday())
        .toString(),
  );
  late final _effectiveEnd = TextEditingController(
    text: _initial?.effectiveEnd?.toString() ?? '',
  );
  late final _hourlyRate = TextEditingController(
    text: _initial == null ? '' : _eurText(_initial.hourlyRateMicroEur),
  );
  late final _overtimeHours = TextEditingController(
    text: formatHours(
      _initial?.overtimeThresholdMinutes ??
          AgreementDefaults.overtimeThresholdMinutes,
    ),
  );
  late final _overtimeMultiplier = TextEditingController(
    text: formatMultiplier(
      _initial?.overtimeMultiplier ?? AgreementDefaults.overtimeMultiplier,
    ),
  );
  late final _nightStart = TextEditingController(
    text: formatClock(
      _initial?.nightStartMinute ?? AgreementDefaults.nightStartMinute,
    ),
  );
  late final _nightEnd = TextEditingController(
    text: formatClock(
      _initial?.nightEndMinute ?? AgreementDefaults.nightEndMinute,
    ),
  );
  late final _nightMultiplier = TextEditingController(
    text: formatMultiplier(
      _initial?.nightMultiplier ?? AgreementDefaults.nightMultiplier,
    ),
  );
  late final _holidayMultiplier = TextEditingController(
    text: formatMultiplier(
      _initial?.holidayMultiplier ?? AgreementDefaults.holidayMultiplier,
    ),
  );
  late final _label = TextEditingController(text: _initial?.label);
  late final _note = TextEditingController(text: _initial?.note);
  late RateBasis _basis = _initial?.basis ?? const GrossBasis();
  late bool _nightEnabled =
      _initial?.nightEnabled ?? AgreementDefaults.nightEnabled;
  late bool _holidays =
      (_initial?.holidayCalendar ?? AgreementDefaults.holidayCalendar) !=
      HolidayCalendar.none;
  late PremiumStacking _stacking =
      _initial?.premiumStacking ?? AgreementDefaults.premiumStacking;
  Map<String, String> _errors = const {};
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in [
      _effectiveStart,
      _effectiveEnd,
      _hourlyRate,
      _overtimeHours,
      _overtimeMultiplier,
      _nightStart,
      _nightEnd,
      _nightMultiplier,
      _holidayMultiplier,
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
    final threshold = parseHoursAsMinutes(_overtimeHours.text);
    final overtime = parseMultiplier(_overtimeMultiplier.text);
    final nightStart = parseClock(_nightStart.text);
    final nightEnd = parseClock(_nightEnd.text);
    final night = parseMultiplier(_nightMultiplier.text);
    final holiday = parseMultiplier(_holidayMultiplier.text);
    final errors = <String, String>{
      if (start == null) 'effectiveStart': 'Enter a date as YYYY-MM-DD.',
      if (endText.isNotEmpty && end == null)
        'effectiveEnd': 'Enter a date as YYYY-MM-DD.',
      if (rate == null || rate <= 0) 'hourlyRate': 'Enter a rate above zero.',
      if (threshold == null) 'overtimeHours': 'Enter hours above zero.',
      if (overtime == null) 'overtimeMultiplier': multiplierMessage,
      if (nightStart == null) 'nightStart': 'Enter a time as HH:MM.',
      if (nightEnd == null) 'nightEnd': 'Enter a time as HH:MM.',
      if (nightStart != null && nightStart == nightEnd)
        'nightEnd': nightWindowMessage,
      if (night == null) 'nightMultiplier': multiplierMessage,
      if (holiday == null) 'holidayMultiplier': multiplierMessage,
    };
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _formError = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errors = const {};
      _formError = null;
    });
    final outcome = await widget.onSubmit(
      AgreementDraft(
        employmentId: widget.employmentId,
        terms: AgreementTerms(
          effectiveStart: start!,
          effectiveEnd: end,
          hourlyRateMicroEur: rate!,
          basis: _basis,
          label: _optional(_label.text),
          note: _optional(_note.text),
          overtimeThresholdMinutes: threshold!,
          overtimeMultiplier: overtime!,
          nightEnabled: _nightEnabled,
          nightStartMinute: nightStart!,
          nightEndMinute: nightEnd!,
          nightMultiplier: night!,
          holidayCalendar: _holidays
              ? HolidayCalendar.lithuania
              : HolidayCalendar.none,
          holidayMultiplier: holiday!,
          premiumStacking: _stacking,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      switch (outcome) {
        case Invalid<PayAgreement>(:final fields):
          if (fields.containsKey('agreement.inUse')) {
            _formError = agreementInUseMessage;
          } else if (fields.containsKey('effectiveRange')) {
            _errors = {
              'effectiveEnd': 'These dates overlap another agreement.',
            };
          } else {
            _formError = 'Check the agreement values.';
          }
        case Stale<PayAgreement>():
          _formError = staleMessage;
        case Missing<PayAgreement>():
          _formError = 'This agreement no longer exists.';
        case Unavailable<PayAgreement>() || Uncertain<PayAgreement>():
          _formError = 'Local storage is unavailable. Try again.';
        case Committed<PayAgreement>():
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: editing ? 'Edit agreement' : 'Create agreement',
      // Switch and radio tiles paint their ink on this Material, above the
      // inspector's background.
      child: Material(
        type: MaterialType.transparency,
        child: Form(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                editing ? 'Edit agreement' : 'Pay agreement',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Defaults follow the Lithuanian Labour Code minimums. They are '
                'defaults, not legal advice.',
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _effectiveStart,
                label: 'Starts on',
                fieldKey: const ValueKey('agreement-effective-start'),
                error: _errors['effectiveStart'],
                hint: 'YYYY-MM-DD',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _effectiveEnd,
                label: 'Ends on (optional)',
                fieldKey: const ValueKey('agreement-effective-end'),
                error: _errors['effectiveEnd'],
                hint: 'YYYY-MM-DD',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _hourlyRate,
                label: 'Hourly rate (€)',
                fieldKey: const ValueKey('agreement-hourly-rate'),
                semanticLabel: 'Hourly rate',
                error: _errors['hourlyRate'],
                autofocus: !editing,
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
              const SizedBox(height: 20),
              Text('Overtime', style: text.titleMedium),
              const SizedBox(height: 8),
              _Sentence(
                children: [
                  const Text('after'),
                  _Short(
                    controller: _overtimeHours,
                    fieldKey: const ValueKey('agreement-overtime-hours'),
                    semanticLabel: 'Overtime after hours',
                    error: _errors['overtimeHours'],
                  ),
                  const Text('hours per shift,'),
                  _Short(
                    prefix: '×',
                    controller: _overtimeMultiplier,
                    fieldKey: const ValueKey('agreement-overtime-multiplier'),
                    semanticLabel: 'Overtime multiplier',
                    error: _errors['overtimeMultiplier'],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                key: const ValueKey('agreement-night-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Night pay'),
                value: _nightEnabled,
                onChanged: (value) => setState(() => _nightEnabled = value),
              ),
              _Sentence(
                enabled: _nightEnabled,
                children: [
                  _Short(
                    controller: _nightStart,
                    fieldKey: const ValueKey('agreement-night-start'),
                    width: 88,
                    semanticLabel: 'Night pay starts',
                    error: _errors['nightStart'],
                    enabled: _nightEnabled,
                  ),
                  const Text('to'),
                  _Short(
                    controller: _nightEnd,
                    fieldKey: const ValueKey('agreement-night-end'),
                    width: 88,
                    semanticLabel: 'Night pay ends',
                    error: _errors['nightEnd'],
                    enabled: _nightEnabled,
                  ),
                  _Short(
                    prefix: '×',
                    controller: _nightMultiplier,
                    fieldKey: const ValueKey('agreement-night-multiplier'),
                    semanticLabel: 'Night multiplier',
                    error: _errors['nightMultiplier'],
                    enabled: _nightEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('agreement-holidays-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Public holidays (Lithuania)'),
                value: _holidays,
                onChanged: (value) => setState(() => _holidays = value),
              ),
              _Sentence(
                enabled: _holidays,
                children: [
                  _Short(
                    prefix: '×',
                    controller: _holidayMultiplier,
                    fieldKey: const ValueKey('agreement-holiday-multiplier'),
                    semanticLabel: 'Holiday multiplier',
                    error: _errors['holidayMultiplier'],
                    enabled: _holidays,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('When several apply', style: text.titleMedium),
              RadioGroup<PremiumStacking>(
                groupValue: _stacking,
                onChanged: (value) {
                  if (value != null) setState(() => _stacking = value);
                },
                child: const Column(
                  children: [
                    _StackingOption(
                      value: PremiumStacking.highest,
                      title: 'Highest wins',
                      example: 'A night hour on a holiday pays ×2.',
                    ),
                    _StackingOption(
                      value: PremiumStacking.additive,
                      title: 'Add the extras',
                      example: 'A night hour on a holiday pays ×2.5.',
                    ),
                    _StackingOption(
                      value: PremiumStacking.multiplicative,
                      title: 'Multiply',
                      example: 'A night hour on a holiday pays ×3.',
                    ),
                  ],
                ),
              ),
              ExpansionTile(
                key: const ValueKey('agreement-more'),
                tilePadding: EdgeInsets.zero,
                title: const Text('More'),
                initiallyExpanded:
                    _initial?.label != null || _initial?.note != null,
                children: [
                  _Field(controller: _label, label: 'Label'),
                  const SizedBox(height: 12),
                  _Field(controller: _note, label: 'Note', maxLines: 3),
                  const SizedBox(height: 8),
                ],
              ),
              if (_formError case final error?) ...[
                const SizedBox(height: 12),
                _ErrorText(error),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('save-agreement'),
                onPressed: _submitting ? null : _submit,
                child: const Text('Save agreement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An agreement's terms, read-only. An agreement in use is evidence for
/// finished shifts and cannot change.
final class AgreementView extends StatelessWidget {
  const AgreementView({
    required this.agreement,
    required this.finishedShifts,
    this.onEdit,
    super.key,
  });

  final PayAgreement agreement;
  final int finishedShifts;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final a = agreement;
    final holidays = a.holidayCalendar != HolidayCalendar.none;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Agreement',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            a.label ?? 'Agreement v${a.version}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _Fact('Starts on', a.effectiveStart.toString()),
          if (a.effectiveEnd case final end?) _Fact('Ends on', end.toString()),
          _Fact(
            'Hourly rate',
            '${formatHourlyRate(a.hourlyRateMicroEur)} '
                '${a.basis is GrossBasis ? 'gross' : 'net'}',
          ),
          _Fact(
            'Overtime',
            'after ${formatHours(a.overtimeThresholdMinutes)} h, '
                '×${formatMultiplier(a.overtimeMultiplier)}',
          ),
          _Fact(
            'Night pay',
            a.nightEnabled
                ? '${formatClock(a.nightStartMinute)} to '
                      '${formatClock(a.nightEndMinute)}, '
                      '×${formatMultiplier(a.nightMultiplier)}'
                : 'Off',
          ),
          _Fact(
            'Public holidays',
            holidays
                ? 'Lithuania, ×${formatMultiplier(a.holidayMultiplier)}'
                : 'Off',
          ),
          _Fact('When several apply', switch (a.premiumStacking) {
            PremiumStacking.highest => 'Highest wins',
            PremiumStacking.additive => 'Add the extras',
            PremiumStacking.multiplicative => 'Multiply',
          }),
          if (a.note case final note?) _Fact('Note', note),
          const SizedBox(height: 8),
          if (finishedShifts > 0)
            Text(
              'Used by $finishedShifts finished '
              '${finishedShifts == 1 ? 'shift' : 'shifts'}. '
              'New versions arrive in a later update.',
            )
          else if (onEdit != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onEdit,
                child: const Text('Edit agreement'),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the inspector shows for a selected employment with no record open.
final class EmploymentHeader extends StatefulWidget {
  const EmploymentHeader({
    required this.employment,
    required this.canDelete,
    required this.agreementInUse,
    required this.onEdit,
    required this.onDelete,
    this.onEditAgreement,
    this.onViewAgreement,
    super.key,
  });

  final Employment employment;
  final bool canDelete;
  final bool agreementInUse;
  final VoidCallback onEdit;
  final DeleteEmployment onDelete;
  final VoidCallback? onEditAgreement;
  final VoidCallback? onViewAgreement;

  @override
  State<EmploymentHeader> createState() => _EmploymentHeaderState();
}

final class _EmploymentHeaderState extends State<EmploymentHeader> {
  bool _confirming = false;
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    final outcome = await widget.onDelete(widget.employment);
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _confirming = false;
      _error = switch (outcome) {
        Committed<Employment>() => null,
        Invalid<Employment>() => employmentHistoryMessage,
        Stale<Employment>() => staleMessage,
        Missing<Employment>() => 'This employment no longer exists.',
        Unavailable<Employment>() ||
        Uncertain<Employment>() => 'Local storage is unavailable. Try again.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final employment = widget.employment;
    final text = Theme.of(context).textTheme;
    if (_confirming) {
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Confirm delete',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete ${employment.name}? Its unused agreement is removed '
                "too. This can't be undone.",
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _deleting
                        ? null
                        : () => setState(() => _confirming = false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const ValueKey('confirm-delete-employment'),
                    onPressed: _deleting ? null : _delete,
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Employment',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(employment.name, style: text.headlineSmall),
          if (employment.legalLabel case final legal?) ...[
            const SizedBox(height: 4),
            Text(legal),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.onEdit,
                child: const Text('Edit'),
              ),
              if (!widget.agreementInUse && widget.onEditAgreement != null)
                OutlinedButton(
                  onPressed: widget.onEditAgreement,
                  child: const Text('Edit agreement'),
                ),
              if (widget.agreementInUse && widget.onViewAgreement != null)
                OutlinedButton(
                  onPressed: widget.onViewAgreement,
                  child: const Text('View agreement'),
                ),
              if (widget.canDelete)
                OutlinedButton(
                  onPressed: () => setState(() {
                    _confirming = true;
                    _error = null;
                  }),
                  child: const Text('Delete'),
                ),
            ],
          ),
          if (!widget.canDelete) ...[
            const SizedBox(height: 12),
            const Text(
              'Has work history — archiving arrives in a later update.',
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            _ErrorText(error),
          ],
        ],
      ),
    );
  }
}

final class _StackingOption extends StatelessWidget {
  const _StackingOption({
    required this.value,
    required this.title,
    required this.example,
  });

  final PremiumStacking value;
  final String title;
  final String example;

  @override
  Widget build(BuildContext context) => RadioListTile<PremiumStacking>(
    value: value,
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(example),
  );
}

/// A row of short fields read as one sentence, e.g. "after [8] hours".
final class _Sentence extends StatelessWidget {
  const _Sentence({required this.children, this.enabled = true});

  final List<Widget> children;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.5,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

final class _Short extends StatelessWidget {
  const _Short({
    required this.controller,
    required this.fieldKey,
    required this.semanticLabel,
    this.error,
    this.enabled = true,
    this.prefix,
    this.width = 72,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String semanticLabel;
  final String? error;
  final bool enabled;
  final String? prefix;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: error == null ? width : 240,
    child: Semantics(
      label: error == null ? semanticLabel : '$semanticLabel, $error',
      textField: true,
      excludeSemantics: true,
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          isDense: true,
          prefixText: prefix,
          errorText: error,
          errorMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
  );
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

final class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

final class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

/// A decimal multiplier of at most three places, as an exact fraction; null
/// when it is unparseable or below 1. "1.5" is 3/2.
RationalMultiplier? parseMultiplier(String text) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(text.trim());
  if (match == null) return null;
  final decimals = match.group(2) ?? '';
  var denominator = 1;
  for (var i = 0; i < decimals.length; i++) {
    denominator *= 10;
  }
  final numerator = int.parse('${match.group(1)}$decimals');
  if (numerator < denominator) return null;
  final divisor = numerator.gcd(denominator);
  return RationalMultiplier(
    numerator: numerator ~/ divisor,
    denominator: denominator ~/ divisor,
  );
}

/// Decimal hours as whole minutes ("7.5" is 450); null unless above zero.
int? parseHoursAsMinutes(String text) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text.trim());
  if (match == null) return null;
  final hundredths =
      int.parse(match.group(1)!) * 100 +
      int.parse((match.group(2) ?? '').padRight(2, '0'));
  final minutes = (hundredths * 60 + 50) ~/ 100;
  return minutes > 0 ? minutes : null;
}

/// "HH:MM" as the minute of the day.
int? parseClock(String text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String formatClock(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

/// Minutes as decimal hours: 480 is "8", 450 is "7.5".
String formatHours(int minutes) {
  if (minutes % 60 == 0) return '${minutes ~/ 60}';
  final hundredths = (minutes * 100 + 30) ~/ 60;
  var text =
      '${hundredths ~/ 100}.${(hundredths % 100).toString().padLeft(2, '0')}';
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

LocalDate _localToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}

String _eurText(int micros) {
  final whole = micros ~/ 1000000;
  var fraction = (micros % 1000000).toString().padLeft(6, '0');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '$whole.$fraction';
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _parseEurMicros(String value) {
  final match = RegExp(r'^(\d+)(?:[.,](\d{1,6}))?$').firstMatch(value);
  if (match == null) return null;
  final major = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(6, '0');
  return major * 1000000 + int.parse(fraction);
}
