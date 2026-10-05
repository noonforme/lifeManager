import 'package:flutter/material.dart';

import 'era_controls.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// Field widths by kind (XP-authentic shell spec 8.1).
abstract final class EraFieldWidth {
  static const date = 120.0;
  static const time = 72.0;
  static const money = 88.0;
  static const short = 48.0;
  static const text = 200.0;
}

/// The width of a dialog's "Label:" column.
final class EraFormScope extends InheritedWidget {
  const EraFormScope({this.labelWidth = 110, required super.child, super.key});

  final double labelWidth;

  static double labelWidthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EraFormScope>()?.labelWidth ??
      110;

  @override
  bool updateShouldNotify(EraFormScope oldWidget) =>
      labelWidth != oldWidget.labelWidth;
}

/// "Label:" in the label column, then the field, as an era dialog lays out
/// its rows.
final class EraLabelled extends StatelessWidget {
  const EraLabelled({
    required this.label,
    required this.field,
    this.fieldWidth,
    this.grow = false,
    super.key,
  });

  final String label;
  final Widget field;

  /// Null gives the field the rest of the row.
  final double? fieldWidth;

  /// Treats [fieldWidth] as a minimum: the field widens to its own content,
  /// as a time box does rather than split "22:00".
  final bool grow;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final width = fieldWidth;
    final labelWidth = EraFormScope.labelWidthOf(context);
    final text = ExcludeSemantics(
      child: Text(
        '$label:',
        style: skin.typography.body.copyWith(color: skin.tokens.ink),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Too narrow for the label column (a slim pane, or 200 % text):
          // the label moves above its field, which keeps its width.
          // A growing field may run past its width, so it asks for slack.
          final needed = labelWidth + 4 + (width ?? 80) + (grow ? 32 : 0);
          if (constraints.maxWidth < needed) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 2),
                if (width == null)
                  field
                else
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: grow
                        ? IntrinsicWidth(child: field)
                        : SizedBox(
                            width: width > constraints.maxWidth
                                ? constraints.maxWidth
                                : width,
                            child: field,
                          ),
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: text,
                ),
              ),
              const SizedBox(width: 4),
              if (width == null)
                Expanded(child: field)
              else if (grow)
                // Never past the row: an error under the box wraps instead.
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: width),
                    child: IntrinsicWidth(child: field),
                  ),
                )
              else
                SizedBox(width: width, child: field),
            ],
          );
        },
      ),
    );
  }
}

/// A 13 px era check box with its label; the whole row toggles it.
final class EraCheckBox extends StatelessWidget {
  const EraCheckBox({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => _Choice(
    label: label,
    checked: value,
    radio: false,
    onPressed: onChanged == null ? null : () => onChanged!(!value),
    mark: _Box(checked: value, enabled: onChanged != null),
  );
}

/// A 13 px era radio with its label; the whole row selects it.
final class EraRadio<T> extends StatelessWidget {
  const EraRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
    this.detail,
    super.key,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T>? onChanged;
  final String label;

  /// A muted line under the label, such as an example.
  final String? detail;

  @override
  Widget build(BuildContext context) => _Choice(
    label: label,
    detail: detail,
    checked: value == groupValue,
    radio: true,
    onPressed: onChanged == null ? null : () => onChanged!(value),
    mark: _Dot(selected: value == groupValue, enabled: onChanged != null),
  );
}

final class _Choice extends StatefulWidget {
  const _Choice({
    required this.label,
    required this.checked,
    required this.radio,
    required this.onPressed,
    required this.mark,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool checked;
  final bool radio;
  final VoidCallback? onPressed;
  final Widget mark;

  @override
  State<_Choice> createState() => _ChoiceState();
}

final class _ChoiceState extends State<_Choice> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final enabled = widget.onPressed != null;
    return Semantics(
      container: true,
      label: widget.label,
      checked: widget.checked,
      inMutuallyExclusiveGroup: widget.radio ? true : null,
      enabled: enabled,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.mark,
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    foregroundDecoration: _focused
                        ? DottedFocusRectangle(color: tokens.focus, inset: 0)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: skin.typography.body.copyWith(
                            color: enabled ? tokens.ink : tokens.muted,
                          ),
                        ),
                        if (widget.detail case final detail?)
                          Text(
                            detail,
                            style: skin.typography.small.copyWith(
                              color: tokens.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _Box extends StatelessWidget {
  const _Box({required this.checked, required this.enabled});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      key: const ValueKey('era-check-box'),
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: enabled ? tokens.paper : tokens.chrome,
        border: Border.all(color: MillenniumColors.choiceLine),
      ),
      child: checked
          ? const Center(
              child: EraGlyph(
                EraGlyphKind.tick,
                color: MillenniumColors.choiceMark,
                size: 9,
              ),
            )
          : null,
    );
  }
}

final class _Dot extends StatelessWidget {
  const _Dot({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      key: const ValueKey('era-radio'),
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? tokens.paper : tokens.chrome,
        border: Border.all(color: MillenniumColors.choiceLine),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MillenniumColors.choiceMarkLight,
                      MillenniumColors.choiceMark,
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
