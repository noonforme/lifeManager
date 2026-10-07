import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart' show KeyKind;
import '../../../shared/workbench/office_controls.dart';
import '../application/agreement_correction.dart';
import '../data/projections/work_record_projection.dart' show AgreementUse;
import '../domain/agreement.dart';
import 'employment_agreement_forms.dart'
    show agreementOverlapMessage, agreementUsersPaid, staleMessage;
import 'work_formats.dart' show formatMoney;

/// The way to pay a planned day no agreement covers: "Set up pay
/// agreement…" when the employment has none, otherwise "Extend pay
/// agreement…" (schedules spec 6.6, added 2026-10-07).
typedef AgreementLink = ({String label, VoidCallback onPressed});

/// "Extend pay agreement…": asks before widening [agreement] to cover
/// [date] through [onExtend], its terms unchanged. The dialog stays open
/// and says what went wrong until the change commits; true once it has.
Future<bool> askExtendAgreement(
  BuildContext context, {
  required PayAgreement agreement,
  required LocalDate date,
  required Future<MutationOutcome<PayAgreement>> Function() onExtend,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _ExtendAgreementDialog(
        agreement: agreement,
        date: date,
        onExtend: onExtend,
      ),
    ) ??
    false;

/// "End agreement…": asks for [agreement]'s last day and ends it there
/// through [onEnd] (premiums spec 7, added 2026-10-07). [usedBy] names who
/// it pays in a refusal; null when unknown. The dialog stays open and says
/// what went wrong until the end commits; true once it has.
Future<bool> askEndAgreement(
  BuildContext context, {
  required PayAgreement agreement,
  required LocalDate today,
  required Future<MutationOutcome<PayAgreement>> Function(LocalDate lastDay)
  onEnd,
  AgreementUse? usedBy,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _EndAgreementDialog(
        agreement: agreement,
        today: today,
        usedBy: usedBy,
        onEnd: onEnd,
      ),
    ) ??
    false;

/// "Remove agreement…": asks before deleting an unused [agreement] through
/// [onRemove]. True once the removal commits.
Future<bool> askRemoveAgreement(
  BuildContext context, {
  required PayAgreement agreement,
  required Future<MutationOutcome<PayAgreement>> Function() onRemove,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RemoveAgreementDialog(agreement: agreement, onRemove: onRemove),
    ) ??
    false;

/// Asks before correcting [agreement] in place, naming what [impact]
/// reprices (premiums spec 7, added 2026-10-08). True on Correct; the
/// Properties then save and report the outcome.
Future<bool> askCorrectAgreement(
  BuildContext context, {
  required PayAgreement agreement,
  required AgreementCorrectionImpact impact,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => EraDialog(
        title: 'Correct agreement',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Correct pay agreement v${agreement.version}?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            const Text(
              'It is corrected as if it had always said this. Its history '
              'keeps the old terms.',
            ),
            const SizedBox(height: 7),
            Text(correctionImpactText(impact)),
            if (correctionReviewedText(impact) case final reviewed?) ...[
              const SizedBox(height: 7),
              InspectorNote(reviewed),
            ],
            const SizedBox(height: 7),
            const Text(
              'For new terms from a date, use Change terms from… instead.',
            ),
          ],
        ),
        actions: [
          KeyButton(
            label: 'Correct',
            kind: KeyKind.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          KeyButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ) ??
    false;

/// "3 finished shifts and 1 leave day paid by this agreement are
/// repriced. 2 other leave days change too: their 3-month average includes
/// these shifts. In all: EUR 600.00 → EUR 652.00 (difference EUR +52.00)."
String correctionImpactText(AgreementCorrectionImpact impact) {
  final shifts = impact.shifts;
  final leave = impact.leaveDays;
  final other = impact.otherLeaveDays;
  final own = [
    if (shifts > 0) '$shifts finished ${shifts == 1 ? 'shift' : 'shifts'}',
    if (leave > 0) '$leave leave ${leave == 1 ? 'day' : 'days'}',
  ].join(' and ');
  // "EUR +52.00" reads as a rise beside formatMoney's "EUR -3.00".
  final difference = formatMoney(impact.difference);
  final signed = impact.difference.minorUnits > 0
      ? difference.replaceFirst(' ', ' +')
      : difference;
  return [
    if (own.isNotEmpty)
      '$own paid by this agreement ${shifts + leave == 1 ? 'is' : 'are'} '
          'repriced.',
    if (other > 0)
      '$other other leave ${other == 1 ? 'day changes' : 'days change'} '
          'too: ${other == 1 ? 'its' : 'their'} 3-month average includes '
          '${shifts == 1 ? 'this shift' : 'these shifts'}.',
    'In all: ${formatMoney(impact.before)} → ${formatMoney(impact.after)} '
        '(difference $signed).',
  ].join(' ');
}

/// Which of them fall in reviewed pay periods; null when none does.
String? correctionReviewedText(AgreementCorrectionImpact impact) =>
    switch (impact.inReviewedPeriods) {
      0 => null,
      1 => '1 of them is in a reviewed pay period; its reconciliation changes.',
      final count =>
        '$count of them are in reviewed pay periods; their reconciliation '
            'changes.',
    };

/// What a failed agreement command says, when it is not about one field.
String agreementProblem(MutationOutcome<PayAgreement> outcome) =>
    switch (outcome) {
      Stale() => staleMessage,
      Missing() =>
        'This agreement is no longer available. Reload the register.',
      Uncertain() =>
        "LifeOS can't tell whether this was saved. Reload to check before "
            'trying again.',
      Invalid() => 'Check the agreement and try again.',
      Unavailable() => 'Local storage is unavailable. Nothing was changed.',
      // A committed command closes its dialog and has nothing to explain.
      Committed() => throw StateError('A committed outcome is no problem.'),
    };

final class _EndAgreementDialog extends StatefulWidget {
  const _EndAgreementDialog({
    required this.agreement,
    required this.today,
    required this.usedBy,
    required this.onEnd,
  });

  final PayAgreement agreement;
  final LocalDate today;
  final AgreementUse? usedBy;
  final Future<MutationOutcome<PayAgreement>> Function(LocalDate lastDay) onEnd;

  @override
  State<_EndAgreementDialog> createState() => _EndAgreementDialogState();
}

final class _EndAgreementDialogState extends State<_EndAgreementDialog> {
  // Its current end, or today when it runs on (never before its start).
  late LocalDate _lastDay =
      widget.agreement.effectiveEnd ??
      (widget.today.compareTo(widget.agreement.effectiveStart) < 0
          ? widget.agreement.effectiveStart
          : widget.today);
  String? _error;
  String? _problem;
  bool _ending = false;

  Future<void> _end() async {
    setState(() {
      _ending = true;
      _error = null;
      _problem = null;
    });
    final outcome = await widget.onEnd(_lastDay);
    if (!mounted) return;
    if (outcome is Committed<PayAgreement>) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _ending = false;
      switch (outcome) {
        case Invalid(:final fields) when fields.containsKey('effectiveRange'):
          _error = agreementOverlapMessage;
        case Invalid(:final fields) when fields.containsKey('effectiveEnd'):
          _error =
              fields['effectiveEnd']!.first.code == FieldIssueCode.outOfRange
              ? 'The last day must be on or after its start, '
                    '${widget.agreement.effectiveStart}.'
              : '${agreementUsersPaid(widget.usedBy)} under this agreement '
                    'after this day. Pick a later day.';
        case _:
          _problem = agreementProblem(outcome);
      }
    });
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'End agreement',
    body: EraFormScope(
      labelWidth: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'End pay agreement v${widget.agreement.version}?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text(
            'It pays up to and including the last day. Days after it are '
            'paid by no agreement until another covers them.',
          ),
          const SizedBox(height: 7),
          EraDateField(
            label: 'Last day',
            fieldKey: const ValueKey('end-agreement-last-day'),
            value: _lastDay,
            today: widget.today,
            error: _error,
            onChanged: (value) => setState(() => _lastDay = value!),
          ),
          if (_problem case final problem?)
            InspectorNote(problem, tone: FactTone.negative),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'End agreement',
        kind: KeyKind.primary,
        onPressed: _ending ? null : _end,
      ),
      // Closing mid-command would hide its outcome.
      KeyButton(
        label: 'Cancel',
        onPressed: _ending ? null : () => Navigator.of(context).pop(false),
      ),
    ],
  );
}

final class _ExtendAgreementDialog extends StatefulWidget {
  const _ExtendAgreementDialog({
    required this.agreement,
    required this.date,
    required this.onExtend,
  });

  final PayAgreement agreement;
  final LocalDate date;
  final Future<MutationOutcome<PayAgreement>> Function() onExtend;

  @override
  State<_ExtendAgreementDialog> createState() => _ExtendAgreementDialogState();
}

final class _ExtendAgreementDialogState extends State<_ExtendAgreementDialog> {
  String? _problem;
  bool _extending = false;

  Future<void> _extend() async {
    setState(() {
      _extending = true;
      _problem = null;
    });
    final outcome = await widget.onExtend();
    if (!mounted) return;
    if (outcome is Committed<PayAgreement>) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _extending = false;
      _problem = switch (outcome) {
        Invalid(:final fields) when fields.containsKey('effectiveRange') =>
          agreementOverlapMessage,
        _ => agreementProblem(outcome),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    // Before its start the start moves; after its end the end does.
    final earlier = widget.date.compareTo(widget.agreement.effectiveStart) < 0;
    return EraDialog(
      title: 'Extend agreement',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extend pay agreement v${widget.agreement.version} to '
            '${earlier ? 'start' : 'end'} on ${widget.date}?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text(
            'Its terms stay as they are. The planned days it then covers are '
            'priced by it and can be confirmed.',
          ),
          if (_problem case final problem?)
            InspectorNote(problem, tone: FactTone.negative),
        ],
      ),
      actions: [
        KeyButton(
          label: 'Extend',
          kind: KeyKind.primary,
          onPressed: _extending ? null : _extend,
        ),
        // Closing mid-command would hide its outcome.
        KeyButton(
          label: 'Cancel',
          onPressed: _extending ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

final class _RemoveAgreementDialog extends StatefulWidget {
  const _RemoveAgreementDialog({
    required this.agreement,
    required this.onRemove,
  });

  final PayAgreement agreement;
  final Future<MutationOutcome<PayAgreement>> Function() onRemove;

  @override
  State<_RemoveAgreementDialog> createState() => _RemoveAgreementDialogState();
}

final class _RemoveAgreementDialogState extends State<_RemoveAgreementDialog> {
  String? _problem;
  bool _removing = false;

  Future<void> _remove() async {
    setState(() {
      _removing = true;
      _problem = null;
    });
    final outcome = await widget.onRemove();
    if (!mounted) return;
    if (outcome is Committed<PayAgreement>) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _removing = false;
      _problem = switch (outcome) {
        // Something was confirmed under it since the link was offered.
        Invalid() =>
          'Finished shifts or confirmed leave now use this agreement, so it '
              "can't be removed.",
        _ => agreementProblem(outcome),
      };
    });
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Remove agreement',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Remove pay agreement v${widget.agreement.version}?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        const Text(
          "No finished shift or confirmed leave uses it. This can't be "
          'undone.',
        ),
        if (_problem case final problem?)
          InspectorNote(problem, tone: FactTone.negative),
      ],
    ),
    actions: [
      KeyButton(
        label: 'Remove',
        kind: KeyKind.primary,
        onPressed: _removing ? null : _remove,
      ),
      KeyButton(
        label: 'Cancel',
        onPressed: _removing ? null : () => Navigator.of(context).pop(false),
      ),
    ],
  );
}
