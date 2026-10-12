import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../foundation/era_dates.dart';
import '../foundation/lifeos_skin.dart';
import 'era_combo.dart';
import 'era_date_field.dart';
import 'era_field.dart';
import 'era_form.dart';
import 'era_time_field.dart';

/// What an editable value holds (database shell spec 6): how it is shown,
/// aligned and edited.
enum ValueKind {
  /// Free text, edited as typed.
  text,

  /// A plain number, edited as raw text the caller parses.
  number,

  /// An amount, edited as raw text; the caller owns currency and rounding.
  money,

  /// A length of time, edited as raw text the caller parses.
  duration,

  /// A [LocalDate], in an [EraDateField].
  date,

  /// A [LocalTime], in an [EraTimeField].
  time,

  /// One of the caller's choices, in an [EraCombo].
  choice,

  /// Yes or no, in an [EraCheckBox].
  check;

  /// Number, money and duration: right-aligned, in tabular figures.
  bool get isNumeric => switch (this) {
    number || money || duration => true,
    text || date || time || choice || check => false,
  };

  /// Numeric kinds, dates and times are drawn in tabular figures.
  bool get usesFigures => isNumeric || this == date || this == time;

  /// Edited as raw text in an [EraField]: the draft is the typed [String]
  /// until the caller's commit parses it.
  bool get typedAsText => this == text || isNumeric;

  /// Numeric kinds align right; everything else aligns left.
  TextAlign get align => isNumeric ? TextAlign.right : TextAlign.left;

  /// The field width an editor of this kind is never narrower than.
  double get fieldWidth => switch (this) {
    text || choice => EraFieldWidth.text,
    number || money => EraFieldWidth.money,
    duration || time => EraFieldWidth.time,
    date => EraFieldWidth.date,
    check => EraFieldWidth.short,
  };
}

/// [value] as a cell or property shows it: empty for null; a date as its
/// box shows it ("Mon 2026-10-05"), a time as "07:00" (with seconds when it
/// has them); a check as Yes or No; a choice by its label in [choices].
///
/// [display] supplies the caller's text for any other value, such as an
/// amount or a duration: the library invents no currency or rounding
/// rules. Without it a [String] is shown as it is and anything else by its
/// `toString()`.
String formatValue(
  ValueKind kind,
  Object? value, {
  List<EraComboItem<Object?>> choices = const [],
  String Function(Object value)? display,
}) {
  if (value == null) return '';
  return switch ((kind, value)) {
    (ValueKind.date, final LocalDate date) => eraBoxDate(date),
    (ValueKind.time, final LocalTime time) => eraTimeText(
      time,
      withSeconds: time.second != 0,
    ),
    (ValueKind.check, final bool checked) => checked ? 'Yes' : 'No',
    (ValueKind.choice, _) when choices.any((item) => item.value == value) =>
      choices.firstWhere((item) => item.value == value).label,
    _ => display?.call(value) ?? (value is String ? value : '$value'),
  };
}

/// The era editor for a value of [kind], reusing the shared controls:
/// [EraField] for text, number, money and duration; [EraDateField];
/// [EraTimeField]; [EraCombo] over [choices]; [EraCheckBox].
///
/// Every editor is controlled. Text kinds edit [controller], which the
/// caller owns, so typing, selection and composition survive rebuilds;
/// [value] is ignored for them. The other kinds show [value] and report a
/// change through [onChanged]; the caller rebuilds them with the new
/// value. A date needs an explicit [today] (circled in the calendar, and
/// where an empty optional box starts), never the wall clock.
///
/// [label] is the "Label:" of a labelled row and the editor's semantic
/// name; inside a bare [EraEditorHostScope] only the name remains.
/// [enabled] false greys and locks the editor, as a read-only form does.
/// [focusNode] is the node of the box that takes the keyboard.
Widget valueEditor({
  required ValueKind kind,
  required String label,
  Object? value,
  TextEditingController? controller,
  ValueChanged<Object?>? onChanged,
  List<EraComboItem<Object?>> choices = const [],
  LocalDate? today,
  bool optional = false,
  String? error,
  bool enabled = true,
  FocusNode? focusNode,
  Key? fieldKey,
}) {
  assert(
    !kind.typedAsText || controller != null,
    'A $kind editor edits a TextEditingController.',
  );
  assert(kind != ValueKind.date || today != null, 'A date needs today.');
  final change = onChanged ?? (_) {};
  final Widget editor = switch (kind) {
    ValueKind.text ||
    ValueKind.number ||
    ValueKind.money ||
    ValueKind.duration => EraField(
      controller: controller!,
      label: label,
      fieldKey: fieldKey,
      error: error,
      focusNode: focusNode,
      textAlign: kind.align,
      figures: kind.usesFigures,
      width: kind.fieldWidth,
    ),
    ValueKind.date => EraDateField(
      label: label,
      value: value as LocalDate?,
      today: today!,
      // A required date with no value yet starts from an empty box.
      optional: optional || value == null,
      error: error,
      fieldKey: fieldKey,
      focusNode: focusNode,
      onChanged: change,
    ),
    ValueKind.time => EraTimeField(
      label: label,
      value: value as LocalTime?,
      error: error,
      fieldKey: fieldKey,
      focusNode: focusNode,
      onChanged: change,
    ),
    ValueKind.choice => _ChoiceEditor(
      label: label,
      value: value,
      choices: choices,
      error: error,
      fieldKey: fieldKey,
      focusNode: focusNode,
      onChanged: change,
    ),
    ValueKind.check => EraCheckBox(
      key: fieldKey,
      value: value as bool? ?? false,
      label: label,
      focusNode: focusNode,
      onChanged: change,
    ),
  };
  if (enabled) return editor;
  return Builder(
    builder: (context) => EraFormScope(
      labelWidth: EraFormScope.labelWidthOf(context),
      enabled: false,
      child: editor,
    ),
  );
}

/// A combo in a labelled row (bare: the combo alone), with its error under
/// it as the other boxes show theirs.
final class _ChoiceEditor extends StatelessWidget {
  const _ChoiceEditor({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.error,
    this.fieldKey,
    this.focusNode,
  });

  final String label;
  final Object? value;
  final List<EraComboItem<Object?>> choices;
  final ValueChanged<Object?> onChanged;
  final String? error;
  final Key? fieldKey;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final combo = EraCombo<Object?>(
      key: fieldKey,
      items: choices,
      value: value,
      semanticLabel: error == null ? label : '$label, $error',
      focusNode: focusNode,
      onSelected: onChanged,
    );
    return EraLabelled(
      label: label,
      fieldWidth: EraFieldWidth.text,
      field: error == null
          ? combo
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                combo,
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ExcludeSemantics(
                    child: Text(
                      error!,
                      style: skin.typography.small.copyWith(
                        color: skin.tokens.negative,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
