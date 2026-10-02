import 'package:flutter/material.dart';

import '../workbench/era_dialog.dart';
import '../workbench/era_field.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/office_controls.dart';

/// Asks for a name, for example of a desk or a view; null when cancelled.
Future<String?> askForName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _NameDialog(title: title, action: action, initial: initial),
);

final class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.action,
    required this.initial,
  });

  final String title;
  final String action;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

final class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_name.text);

  @override
  Widget build(BuildContext context) => EraDialog(
    title: widget.title,
    body: EraField(
      fieldKey: const ValueKey('name-field'),
      controller: _name,
      label: 'Name',
      autofocus: true,
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      KeyButton(
        label: widget.action,
        kind: KeyKind.primary,
        onPressed: _submit,
      ),
    ],
  );
}
