import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../ui/ui.dart';
import '../domain/shift.dart';
import 'employment_agreement_forms.dart' show staleMessage;

/// "Remove this shift…": asks why, then voids [shift] with no replacement
/// through [onRemove] (foundation spec 10.7). The dialog stays open and
/// says what went wrong until the removal commits; true once it has.
Future<bool> askRemoveShift(
  BuildContext context, {
  required WorkShift shift,
  required Future<MutationOutcome<WorkShift>> Function(String reason) onRemove,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveShiftDialog(shift: shift, onRemove: onRemove),
    ) ??
    false;

final class _RemoveShiftDialog extends StatefulWidget {
  const _RemoveShiftDialog({required this.shift, required this.onRemove});

  final WorkShift shift;
  final Future<MutationOutcome<WorkShift>> Function(String reason) onRemove;

  @override
  State<_RemoveShiftDialog> createState() => _RemoveShiftDialogState();
}

final class _RemoveShiftDialogState extends State<_RemoveShiftDialog> {
  final _reason = TextEditingController();
  String? _reasonError;
  String? _problem;
  bool _removing = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _reasonError = 'Enter why this shift is removed.');
      return;
    }
    setState(() {
      _removing = true;
      _reasonError = null;
      _problem = null;
    });
    final outcome = await widget.onRemove(_reason.text.trim());
    if (!mounted) return;
    if (outcome is Committed<WorkShift>) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _removing = false;
      switch (outcome) {
        case Invalid(:final fields) when fields.containsKey('voidReason'):
          _reasonError = 'Enter why this shift is removed.';
        case Invalid():
          _problem = 'This shift is already void.';
        case Stale():
          _problem = staleMessage;
        case Missing():
          _problem = 'This shift is no longer available. Reload the register.';
        case Uncertain():
          _problem =
              "LifeOS can't tell whether this was saved. Reload to check "
              'before trying again.';
        case Unavailable() || Committed():
          _problem = 'Local storage is unavailable. Nothing was removed.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Remove shift',
    body: EraFormScope(
      labelWidth: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remove the shift on ${widget.shift.localStartDate}?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text(
            'The shift stays in history as Void and no longer counts in the '
            'totals.',
          ),
          // A day confirmed from the schedule is planned again.
          if (widget.shift.schedule != null) ...[
            const SizedBox(height: 7),
            const Text('Its day goes back to the days to confirm.'),
          ],
          const SizedBox(height: 7),
          EraField(
            fieldKey: const ValueKey('remove-shift-reason'),
            controller: _reason,
            label: 'Reason',
            autofocus: true,
            error: _reasonError,
            onSubmitted: (_) => _remove(),
          ),
          if (_problem case final problem?)
            InspectorNote(problem, tone: FactTone.negative),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'Remove',
        kind: KeyKind.primary,
        onPressed: _removing ? null : _remove,
      ),
      // Closing mid-removal would hide its outcome.
      KeyButton(
        label: 'Cancel',
        onPressed: _removing ? null : () => Navigator.of(context).pop(false),
      ),
    ],
  );
}
