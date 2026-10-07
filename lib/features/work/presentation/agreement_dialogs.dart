import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart' show KeyKind;
import '../../../shared/workbench/office_controls.dart';
import '../domain/agreement.dart';
import 'employment_agreement_forms.dart'
    show agreementOverlapMessage, staleMessage;

/// "End agreement…": asks for [agreement]'s last day and ends it there
/// through [onEnd] (premiums spec 7, added 2026-10-07). The dialog stays
/// open and says what went wrong until the end commits; true once it has.
Future<bool> askEndAgreement(
  BuildContext context, {
  required PayAgreement agreement,
  required LocalDate today,
  required Future<MutationOutcome<PayAgreement>> Function(LocalDate lastDay)
  onEnd,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          _EndAgreementDialog(agreement: agreement, today: today, onEnd: onEnd),
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
      Unavailable() ||
      Committed() => 'Local storage is unavailable. Nothing was changed.',
    };

final class _EndAgreementDialog extends StatefulWidget {
  const _EndAgreementDialog({
    required this.agreement,
    required this.today,
    required this.onEnd,
  });

  final PayAgreement agreement;
  final LocalDate today;
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
              : 'Finished shifts or confirmed leave are paid under this '
                    'agreement after this day. Pick a later day.';
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
