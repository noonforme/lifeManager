import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/era_icons.dart';
import '../../../shared/workbench/era_time_field.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import '../../../shared/workbench/office_controls.dart';
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
const percentMessage = 'Enter a percent above zero, e.g. 62.06';
const sickDaysMessage = 'Enter whole days from 0 to 30.';
const nightWindowMessage = 'Night pay start and end must differ';

/// Shown when the picked end date falls before the start date.
const agreementRangeMessage = 'The agreement must end on or after its start.';

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
        child: EraFormScope(
          labelWidth: 90,
          child: ListView(
            padding: inspectorInset,
            children: [
              _group(context, 'Employment', [
                _Field(
                  controller: _name,
                  label: 'Name',
                  fieldKey: const ValueKey('employment-name'),
                  error: _nameError,
                  hint: 'What you call this job, e.g. Warehouse',
                  autofocus: true,
                ),
                _Field(
                  controller: _legalLabel,
                  label: 'Legal name (optional)',
                  fieldKey: const ValueKey('employment-legal-name'),
                  hint: 'Employer name as it appears on payslips',
                ),
              ]),
              if (_formError case final error?) _ErrorText(error),
              FormFooter(
                children: [
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: const Text('Save employment'),
                  ),
                  const DialogCancelKey(),
                ],
              ),
            ],
          ),
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

  /// The open tab: Rate, Premiums, Leave or Notes.
  int _tab = 0;
  late final LocalDate _today = widget.today ?? _localToday();
  late LocalDate _effectiveStart = _initial?.effectiveStart ?? _today;
  late LocalDate? _effectiveEnd = _initial?.effectiveEnd;
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
  late LocalTime _nightStart = _clockTime(
    _initial?.nightStartMinute ?? AgreementDefaults.nightStartMinute,
  );
  late LocalTime _nightEnd = _clockTime(
    _initial?.nightEndMinute ?? AgreementDefaults.nightEndMinute,
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
  late final _vacationPercent = TextEditingController(
    text: formatPercent(_initial?.vacationPay ?? AgreementDefaults.vacationPay),
  );
  late final _sickPercent = TextEditingController(
    text: formatPercent(_initial?.sickPay ?? AgreementDefaults.sickPay),
  );
  late final _sickDays = TextEditingController(
    text: '${_initial?.sickEmployerDays ?? AgreementDefaults.sickEmployerDays}',
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
      _hourlyRate,
      _overtimeHours,
      _overtimeMultiplier,
      _nightMultiplier,
      _holidayMultiplier,
      _vacationPercent,
      _sickPercent,
      _sickDays,
      _label,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final start = _effectiveStart;
    final end = _effectiveEnd;
    final rate = _parseEurMicros(_hourlyRate.text.trim());
    final threshold = parseHoursAsMinutes(_overtimeHours.text);
    final overtime = parseMultiplier(_overtimeMultiplier.text);
    final nightStart = _minuteOfDay(_nightStart);
    final nightEnd = _minuteOfDay(_nightEnd);
    final night = parseMultiplier(_nightMultiplier.text);
    final holiday = parseMultiplier(_holidayMultiplier.text);
    final vacationPay = parsePercent(_vacationPercent.text);
    final sickPay = parsePercent(_sickPercent.text);
    final sickDays = int.tryParse(_sickDays.text.trim());
    final errors = <String, String>{
      if (end != null && end.compareTo(start) < 0)
        'effectiveEnd': agreementRangeMessage,
      if (rate == null || rate <= 0) 'hourlyRate': 'Enter a rate above zero.',
      if (threshold == null) 'overtimeHours': 'Enter hours above zero.',
      if (overtime == null) 'overtimeMultiplier': multiplierMessage,
      if (nightStart == nightEnd) 'nightEnd': nightWindowMessage,
      if (night == null) 'nightMultiplier': multiplierMessage,
      if (holiday == null) 'holidayMultiplier': multiplierMessage,
      if (vacationPay == null) 'vacationPercent': percentMessage,
      if (sickPay == null) 'sickPercent': percentMessage,
      if (sickDays == null || sickDays < 0 || sickDays > 30)
        'sickDays': sickDaysMessage,
    };
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _formError = null;
        _tab = errors.keys
            .map((key) => _tabOf[key] ?? 0)
            .reduce((best, tab) => tab < best ? tab : best);
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
          effectiveStart: start,
          effectiveEnd: end,
          hourlyRateMicroEur: rate!,
          basis: _basis,
          label: _optional(_label.text),
          note: _optional(_note.text),
          overtimeThresholdMinutes: threshold!,
          overtimeMultiplier: overtime!,
          nightEnabled: _nightEnabled,
          nightStartMinute: nightStart,
          nightEndMinute: nightEnd,
          nightMultiplier: night!,
          holidayCalendar: _holidays
              ? HolidayCalendar.lithuania
              : HolidayCalendar.none,
          holidayMultiplier: holiday!,
          premiumStacking: _stacking,
          vacationPay: vacationPay!,
          sickPay: sickPay!,
          sickEmployerDays: sickDays!,
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
            // The dates are on Rate; bring it forward to show the problem.
            _tab = _tabOf['effectiveEnd']!;
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

  /// The tab that holds each validated field, so a failed save brings the
  /// first problem forward (XP-authentic shell spec 4.4).
  static const _tabOf = {
    'effectiveEnd': 0,
    'hourlyRate': 0,
    'overtimeHours': 1,
    'overtimeMultiplier': 1,
    'nightEnd': 1,
    'nightMultiplier': 1,
    'holidayMultiplier': 1,
    'vacationPercent': 2,
    'sickPercent': 2,
    'sickDays': 2,
  };

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final tokens = LifeOSSkinScope.of(context).tokens;
    final pages = <List<Widget>>[
      [
        const InspectorText(
          'Defaults follow the Lithuanian Labour Code minimums. They are '
          'defaults, not legal advice.',
        ),
        const SizedBox(height: 8),
        _group(context, 'Rate', [
          EraDateField(
            label: 'Starts on',
            fieldKey: const ValueKey('agreement-effective-start'),
            value: _effectiveStart,
            today: _today,
            onChanged: (value) => setState(() => _effectiveStart = value!),
          ),
          EraDateField(
            label: 'Ends on',
            optional: true,
            fieldKey: const ValueKey('agreement-effective-end'),
            value: _effectiveEnd,
            today: _today,
            error: _errors['effectiveEnd'],
            onChanged: (value) => setState(() => _effectiveEnd = value),
          ),
          _Field(
            controller: _hourlyRate,
            label: 'Hourly rate (€)',
            fieldKey: const ValueKey('agreement-hourly-rate'),
            semanticLabel: 'Hourly rate',
            error: _errors['hourlyRate'],
            autofocus: !editing,
            width: EraFieldWidth.money,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          EraLabelled(
            label: 'Basis',
            field: EraRadioGroup<RateBasis>(
              direction: Axis.horizontal,
              options: const [
                EraRadioOption(GrossBasis(), 'Gross'),
                EraRadioOption(NetBasis(), 'Net'),
              ],
              groupValue: _basis,
              onChanged: (next) => setState(() => _basis = next),
            ),
          ),
        ]),
      ],
      [
        _group(context, 'Overtime', [
          _Sentence(
            children: [
              const Text('After'),
              _Short(
                controller: _overtimeHours,
                fieldKey: const ValueKey('agreement-overtime-hours'),
                semanticLabel: 'Overtime after hours',
                error: _errors['overtimeHours'],
              ),
              const Text('hours per shift, pay'),
              _Short(
                controller: _overtimeMultiplier,
                fieldKey: const ValueKey('agreement-overtime-multiplier'),
                semanticLabel: 'Overtime multiplier',
                error: _errors['overtimeMultiplier'],
              ),
              const Text('×'),
            ],
          ),
        ]),
        _group(context, 'Night', [
          EraCheckBox(
            key: const ValueKey('agreement-night-enabled'),
            value: _nightEnabled,
            label: 'Night pay',
            onChanged: (value) => setState(() => _nightEnabled = value),
          ),
          const SizedBox(height: 4),
          _Sentence(
            enabled: _nightEnabled,
            children: [
              _ClockBox(
                fieldKey: const ValueKey('agreement-night-start'),
                semanticLabel: 'Night pay starts',
                value: _nightStart,
                enabled: _nightEnabled,
                onChanged: (value) => setState(() => _nightStart = value),
              ),
              const Text('to'),
              _ClockBox(
                fieldKey: const ValueKey('agreement-night-end'),
                semanticLabel: 'Night pay ends',
                value: _nightEnd,
                enabled: _nightEnabled,
                error: _errors['nightEnd'],
                onChanged: (value) => setState(() => _nightEnd = value),
              ),
              const Text('pay'),
              _Short(
                controller: _nightMultiplier,
                fieldKey: const ValueKey('agreement-night-multiplier'),
                semanticLabel: 'Night multiplier',
                error: _errors['nightMultiplier'],
                enabled: _nightEnabled,
              ),
              const Text('×'),
            ],
          ),
        ]),
        _group(context, 'Holidays', [
          EraCheckBox(
            key: const ValueKey('agreement-holidays-enabled'),
            value: _holidays,
            label: 'Public holidays (Lithuania)',
            onChanged: (value) => setState(() => _holidays = value),
          ),
          const SizedBox(height: 4),
          _Sentence(
            enabled: _holidays,
            children: [
              const Text('Pay'),
              _Short(
                controller: _holidayMultiplier,
                fieldKey: const ValueKey('agreement-holiday-multiplier'),
                semanticLabel: 'Holiday multiplier',
                error: _errors['holidayMultiplier'],
                enabled: _holidays,
              ),
              const Text('×'),
            ],
          ),
        ]),
        _group(context, 'When several apply', [
          EraRadioGroup<PremiumStacking>(
            options: const [
              EraRadioOption(
                PremiumStacking.highest,
                'Highest wins',
                detail: 'A night hour on a holiday pays ×2.',
              ),
              EraRadioOption(
                PremiumStacking.additive,
                'Add the extras',
                detail: 'A night hour on a holiday pays ×2.5.',
              ),
              EraRadioOption(
                PremiumStacking.multiplicative,
                'Multiply',
                detail: 'A night hour on a holiday pays ×3.',
              ),
            ],
            groupValue: _stacking,
            onChanged: (next) => setState(() => _stacking = next),
          ),
        ]),
      ],
      [
        _group(context, 'Leave pay', [
          _Field(
            controller: _vacationPercent,
            label: 'Vacation %',
            fieldKey: const ValueKey('agreement-vacation-percent'),
            semanticLabel: 'Vacation percent',
            error: _errors['vacationPercent'],
            width: EraFieldWidth.short,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _Field(
            controller: _sickPercent,
            label: 'Sick, first days %',
            fieldKey: const ValueKey('agreement-sick-percent'),
            semanticLabel: 'Sick pay percent for the first days',
            error: _errors['sickPercent'],
            width: EraFieldWidth.short,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _Field(
            controller: _sickDays,
            label: 'Sick days the employer pays',
            fieldKey: const ValueKey('agreement-sick-days'),
            error: _errors['sickDays'],
            width: EraFieldWidth.short,
            keyboardType: TextInputType.number,
          ),
          const InspectorNote(
            'Paid from the average of the 3 months before. Defaults, '
            'not legal advice.',
          ),
        ]),
      ],
      [
        _group(context, 'Notes', [
          _Field(controller: _label, label: 'Label'),
          _Field(controller: _note, label: 'Note', maxLines: 3),
        ]),
      ],
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: editing ? 'Edit agreement' : 'Create agreement',
      child: Material(
        type: MaterialType.transparency,
        child: Form(
          child: EraFormScope(
            labelWidth: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PropertySheetTabs(
                  labels: const ['Rate', 'Premiums', 'Leave', 'Notes'],
                  selectedIndex: _tab,
                  onSelected: (index) => setState(() => _tab = index),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.chrome,
                      border: const Border(
                        left: BorderSide(color: MillenniumColors.tabLine),
                        right: BorderSide(color: MillenniumColors.tabLine),
                        bottom: BorderSide(color: MillenniumColors.tabLine),
                      ),
                    ),
                    child: IndexedStack(
                      index: _tab,
                      sizing: StackFit.expand,
                      children: [
                        for (final page in pages)
                          ListView(padding: inspectorInset, children: page),
                      ],
                    ),
                  ),
                ),
                if (_formError case final error?) _ErrorText(error),
                FormFooter(
                  children: [
                    FilledButton(
                      key: const ValueKey('save-agreement'),
                      onPressed: _submitting ? null : _submit,
                      child: const Text('Save agreement'),
                    ),
                    const DialogCancelKey(),
                  ],
                ),
              ],
            ),
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
      child: InspectorPane(
        children: [
          InspectorTitle(
            a.label ?? 'Agreement v${a.version}',
            icon: EraIconKind.agreement,
          ),
          InspectorFacts(legend: 'Terms', [
            Fact('Starts on', a.effectiveStart.toString()),
            if (a.effectiveEnd case final end?) Fact('Ends on', end.toString()),
            Fact(
              'Hourly rate',
              '${formatHourlyRate(a.hourlyRateMicroEur)} '
                  '${a.basis is GrossBasis ? 'gross' : 'net'}',
            ),
            Fact(
              'Overtime',
              'after ${formatHours(a.overtimeThresholdMinutes)} h, '
                  '×${formatMultiplier(a.overtimeMultiplier)}',
            ),
            Fact(
              'Night pay',
              a.nightEnabled
                  ? '${formatClock(a.nightStartMinute)} to '
                        '${formatClock(a.nightEndMinute)}, '
                        '×${formatMultiplier(a.nightMultiplier)}'
                  : 'Off',
            ),
            Fact(
              'Public holidays',
              holidays
                  ? 'Lithuania, ×${formatMultiplier(a.holidayMultiplier)}'
                  : 'Off',
            ),
            Fact.words('When several apply', switch (a.premiumStacking) {
              PremiumStacking.highest => 'Highest wins',
              PremiumStacking.additive => 'Add the extras',
              PremiumStacking.multiplicative => 'Multiply',
            }),
            if (a.note case final note?) Fact.words('Note', note),
          ]),
          if (finishedShifts > 0)
            InspectorNote(
              'Used by $finishedShifts finished '
              '${finishedShifts == 1 ? 'shift' : 'shifts'}.',
            )
          else if (onEdit != null)
            InspectorActions(
              children: [KeyButton(label: 'Edit agreement', onPressed: onEdit)],
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
    if (_confirming) {
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Confirm delete',
        child: InspectorPane(
          children: [
            InspectorText(
              'Delete ${employment.name}? Its unused agreement is removed '
              "too. This can't be undone.",
            ),
            FormFooter(
              children: [
                KeyButton(
                  label: 'Cancel',
                  onPressed: _deleting
                      ? null
                      : () => setState(() => _confirming = false),
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
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Employment',
      child: InspectorPane(
        children: [
          InspectorTitle(
            employment.name,
            meta: employment.legalLabel,
            icon: EraIconKind.employment,
          ),
          InspectorActions(
            children: [
              KeyButton(label: 'Edit', onPressed: widget.onEdit),
              if (!widget.agreementInUse && widget.onEditAgreement != null)
                KeyButton(
                  label: 'Edit agreement',
                  onPressed: widget.onEditAgreement,
                ),
              if (widget.agreementInUse && widget.onViewAgreement != null)
                KeyButton(
                  label: 'View agreement',
                  onPressed: widget.onViewAgreement,
                ),
              if (widget.canDelete)
                KeyButton(
                  label: 'Delete',
                  onPressed: () => setState(() {
                    _confirming = true;
                    _error = null;
                  }),
                ),
            ],
          ),
          if (_error case final error?) _ErrorText(error),
        ],
      ),
    );
  }
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

/// A time box set in a sentence, widening to fit its error as `_Short`
/// does.
final class _ClockBox extends StatelessWidget {
  const _ClockBox({
    required this.fieldKey,
    required this.semanticLabel,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.error,
  });

  final Key fieldKey;
  final String semanticLabel;
  final LocalTime value;
  final bool enabled;
  final ValueChanged<LocalTime> onChanged;
  final String? error;

  /// The era width of the box; it grows past this with its text, so the
  /// time never splits, and widens to fit an error as `_Short` does.
  static const _width = EraFieldWidth.time;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: error == null
        ? BoxConstraints(
            minWidth: MediaQuery.textScalerOf(context).scale(_width),
          )
        : const BoxConstraints.tightFor(width: 240),
    child: IntrinsicWidth(
      child: EraTimeField(
        fieldKey: fieldKey,
        semanticLabel: semanticLabel,
        value: value,
        enabled: enabled,
        error: error,
        onChanged: onChanged,
      ),
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
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String semanticLabel;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: error == null ? EraFieldWidth.short : 240,
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
          errorText: error,
          errorMaxLines: 2,
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
    this.width = EraFieldWidth.text,
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
  final double? width;

  @override
  Widget build(BuildContext context) => EraField(
    width: width,
    controller: controller,
    label: label,
    semanticLabel: semanticLabel,
    fieldKey: fieldKey,
    error: error,
    hint: hint,
    autofocus: autofocus,
    keyboardType: keyboardType,
    maxLines: maxLines,
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

/// A percent with up to two decimals, such as "62.06", as an exact
/// fraction of 1; null unless above zero.
RationalMultiplier? parsePercent(String text) {
  final match = RegExp(r'^(\d+)(?:[.,](\d{1,2}))?$').firstMatch(text.trim());
  if (match == null) return null;
  final decimals = match.group(2) ?? '';
  final numerator = int.parse('${match.group(1)}$decimals');
  if (numerator <= 0) return null;
  var denominator = 100;
  for (var i = 0; i < decimals.length; i++) {
    denominator *= 10;
  }
  final divisor = numerator.gcd(denominator);
  return RationalMultiplier(
    numerator: numerator ~/ divisor,
    denominator: denominator ~/ divisor,
  );
}

/// A fraction of 1 as a percent with up to two decimals: 3103/5000 is
/// "62.06".
String formatPercent(RationalMultiplier value) {
  final hundredths =
      (value.numerator * 10000 + value.denominator ~/ 2) ~/ value.denominator;
  final whole = hundredths ~/ 100;
  final fraction = hundredths % 100;
  if (fraction == 0) return '$whole';
  final text = fraction.toString().padLeft(2, '0');
  return '$whole.${text.endsWith('0') ? text[0] : text}';
}

String formatClock(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

LocalTime _clockTime(int minuteOfDay) =>
    LocalTime(minuteOfDay ~/ 60, minuteOfDay % 60);

int _minuteOfDay(LocalTime time) => time.hour * 60 + time.minute;

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

/// A form group box on the face colour.
Widget _group(BuildContext context, String legend, List<Widget> children) =>
    GroupBox(
      legend: legend,
      background: LifeOSSkinScope.of(context).tokens.chrome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
