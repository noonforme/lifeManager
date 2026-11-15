import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/lifeos_skin.dart';
import 'era_editor_host.dart';
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
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.figures = false,
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

  /// The text field's focus node, for a host that moves the keyboard to it.
  final FocusNode? focusNode;

  /// Right for a number, as a grid aligns its figures.
  final TextAlign textAlign;

  /// Draws the text in tabular figures, for numbers, amounts and durations.
  final bool figures;

  @override
  Widget build(BuildContext context) {
    final name = semanticLabel ?? label;
    final hosted = EraEditorHostScope.watch(context) != null;
    Widget field = TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      textAlign: textAlign,
      style: figures
          ? TextStyle(
              fontFeatures: LifeOSSkinScope.of(context)
                  .typography
                  .figure
                  .fontFeatures,
            )
          : null,
      enabled: EraFormScope.enabledOf(context),
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLines: maxLines,
      // In an editor host, Enter reaches the host as a key; the platform's
      // submit action neither submits nor drops focus.
      onSubmitted: hosted ? null : onSubmitted,
      onEditingComplete: hosted ? () {} : null,
      decoration: hosted && error != null
          ? _hostedError(context)
          : InputDecoration(hintText: hint, errorText: error),
    );
    if (hosted) {
      field = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (_, event) => _onHostedKey(context, event),
        child: field,
      );
      // As the date and time boxes show theirs: under the box, from its
      // left edge, wrapping in a narrow cell.
      if (error case final error?) {
        final skin = LifeOSSkinScope.of(context);
        field = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ExcludeSemantics(
                child: Text(
                  error,
                  style: skin.typography.small.copyWith(
                    color: skin.tokens.negative,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }
    return Semantics(
      label: error == null ? name : '$name, $error',
      textField: true,
      excludeSemantics: true,
      child: EraLabelled(
        label: label,
        fieldWidth: maxLines > 1 ? null : width,
        field: field,
      ),
    );
  }

  /// A hosted field's red border, its error drawn under it instead of in
  /// the decoration, which would align it with the text and cut it short.
  InputDecoration _hostedError(BuildContext context) {
    final theme = Theme.of(context).inputDecorationTheme;
    return InputDecoration(
      hintText: hint,
      enabledBorder: theme.errorBorder,
      focusedBorder: theme.focusedErrorBorder,
      disabledBorder: theme.errorBorder,
    );
  }

  /// The text field's keys in an editor host (database shell spec 4.6):
  /// typing (Shift and AltGr layouts included), Backspace/Delete and
  /// Left/Right reach the field; plain Enter, Tab and Esc go to the host;
  /// everything else is held. While an input method composes, every key is
  /// its own, so accepting a candidate is never Enter.
  KeyEventResult _onHostedKey(BuildContext context, KeyEvent event) {
    final composing = controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isControlPressed || keyboard.isMetaPressed;
    final character = event.character;
    // AltGr may arrive as Ctrl+Alt; a printable character is still text.
    if (character != null &&
        character.isNotEmpty &&
        character.runes.every((rune) => rune >= 0x20 && rune != 0x7f) &&
        (!command || (keyboard.isAltPressed && !keyboard.isMetaPressed))) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (!command &&
        !keyboard.isAltPressed &&
        (key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      return KeyEventResult.ignored;
    }
    return EraEditorHostScope.handleKey(context, event);
  }
}
