import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';

final class CorrectionConfirmationInspector<T> extends StatefulWidget {
  const CorrectionConfirmationInspector({
    required this.recordName,
    required this.original,
    required this.onConfirm,
    required this.onCancel,
    this.onCommitted,
    super.key,
  });

  final String recordName;
  final T original;
  final Future<MutationOutcome<T>> Function(T original, String reason)
  onConfirm;
  final VoidCallback onCancel;
  final ValueChanged<T>? onCommitted;

  @override
  State<CorrectionConfirmationInspector<T>> createState() =>
      _CorrectionConfirmationInspectorState<T>();
}

final class _CorrectionConfirmationInspectorState<T>
    extends State<CorrectionConfirmationInspector<T>> {
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _reasonError;
  MutationOutcome<T>? _outcome;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Explain why this correction is needed.');
      return;
    }
    setState(() {
      _submitting = true;
      _reasonError = null;
      _outcome = null;
    });
    final outcome = await widget.onConfirm(widget.original, reason);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _outcome = outcome;
    });
    if (outcome case Committed<T>(:final value)) {
      widget.onCommitted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Confirm correction',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Correct ${widget.recordName}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'The original remains in history and is excluded from active totals. A linked replacement will be created.',
        ),
        const SizedBox(height: 16),
        Semantics(
          label: _reasonError == null
              ? 'Correction reason'
              : 'Correction reason, $_reasonError',
          textField: true,
          excludeSemantics: true,
          child: TextField(
            key: const ValueKey('correction-reason'),
            controller: _reason,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Correction reason',
              errorText: _reasonError,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _confirm,
          child: const Text('Void original and create replacement'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        if (_outcome case Stale<T>()) ...[
          const SizedBox(height: 16),
          StaleConflictInspector(
            draft: const SizedBox.shrink(),
            onReload: () {},
          ),
        ] else if (_outcome case Missing<T>()) ...[
          const SizedBox(height: 16),
          const MissingRecordInspector(),
        ] else if (_outcome case Unavailable<T>(:final code)) ...[
          const SizedBox(height: 16),
          UnavailableInspector(code: code),
        ] else if (_outcome case Uncertain<T>()) ...[
          const SizedBox(height: 16),
          const UncertainOutcomeInspector(),
        ],
      ],
    ),
  );
}

final class StaleConflictInspector extends StatelessWidget {
  const StaleConflictInspector({
    required this.draft,
    required this.onReload,
    super.key,
  });

  final Widget draft;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Stale record',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        draft,
        const Text(
          'Your record is out of date. Reload and review before trying again.',
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onReload, child: const Text('Reload record')),
      ],
    ),
  );
}

final class MissingRecordInspector extends StatelessWidget {
  const MissingRecordInspector({super.key});

  @override
  Widget build(BuildContext context) => const _OutcomeMessage(
    semanticLabel: 'Record missing',
    message: 'This record is no longer available. Reload the register.',
  );
}

final class UnavailableInspector extends StatelessWidget {
  const UnavailableInspector({required this.code, super.key});

  final SafeFailureCode code;

  @override
  Widget build(BuildContext context) => _OutcomeMessage(
    semanticLabel: 'Work unavailable',
    message: switch (code) {
      SafeFailureCode.storageUnavailable =>
        'Local storage is unavailable. Your draft has been kept.',
      SafeFailureCode.databaseIdentityMismatch => 'The local database identity could not be verified. Your draft has been kept.',
      SafeFailureCode.migrationFailed ||
      SafeFailureCode.databaseFromEarlierBuild =>
        'The local database could not be prepared. Your draft has been kept.',
      SafeFailureCode.invalidTimezone =>
        'The recorded timezone is unavailable. Your draft has been kept.',
      SafeFailureCode.commitOutcomeUnknown =>
        'The save result is unavailable. Reload and inspect the record.',
    },
  );
}

final class UncertainOutcomeInspector extends StatelessWidget {
  const UncertainOutcomeInspector({super.key});

  @override
  Widget build(BuildContext context) => const _OutcomeMessage(
    semanticLabel: 'Save outcome uncertain',
    message:
        "LifeOS can't tell whether this was saved. Reload to check before "
        'trying again.',
  );
}

final class _OutcomeMessage extends StatelessWidget {
  const _OutcomeMessage({required this.semanticLabel, required this.message});

  final String semanticLabel;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: semanticLabel,
    child: Text(message),
  );
}
