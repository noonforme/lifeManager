import 'package:flutter/material.dart';

import 'era_form.dart';

/// A labelled text field in the era's shape (XP-authentic shell spec 8.1):
/// "Label:" in the dialog's label column, then a sunken white field. The pair is one
/// semantics node, named by the label and, when present, the error.
final class EraField extends StatelessWidget {
  const EraField({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.semanticLabel,
    this.error,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.onSubmitted,
    this.width = EraFieldWidth.text,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  /// The key of the text field itself, which tests and forms address.
  final Key? fieldKey;

  /// Announced instead of [label], for example without a unit sign.
  final String? semanticLabel;
  final String? error;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  /// The field's width by kind ([EraFieldWidth]); null fills the row. A
  /// multi-line field always fills the row.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final name = semanticLabel ?? label;
    return Semantics(
      label: error == null ? name : '$name, $error',
      textField: true,
      excludeSemantics: true,
      child: EraLabelled(
        label: label,
        fieldWidth: maxLines > 1 ? null : width,
        field: TextField(
          key: fieldKey,
          controller: controller,
          enabled: EraFormScope.enabledOf(context),
          autofocus: autofocus,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(hintText: hint, errorText: error),
        ),
      ),
    );
  }
}
