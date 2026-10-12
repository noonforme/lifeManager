import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';
import 'era_controls.dart';
import 'era_editor_host.dart';

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
  const EraFormScope({
    this.labelWidth = 110,
    this.enabled = true,
    required super.child,
    super.key,
  });

  final double labelWidth;

  /// False greys and locks every era field inside, as a read-only
  /// property sheet shows its values.
  final bool enabled;

  static double labelWidthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EraFormScope>()?.labelWidth ??
      110;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EraFormScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(EraFormScope oldWidget) =>
      labelWidth != oldWidget.labelWidth || enabled != oldWidget.enabled;
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
    final width = fieldWidth;
    // A bare editor (a grid or property cell) shows the field alone: its
    // semantics already carry the name, and it fills the cell, never
    // narrower than its kind width while the cell allows.
    if (EraEditorHostScope.bareOf(context)) {
      if (width == null) return field;
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: width),
        child: grow ? IntrinsicWidth(child: field) : field,
      );
    }
    final skin = LifeOSSkinScope.of(context);
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
///
/// Inside an [EraEditorHostScope] a click also focuses it, so the host's
/// Enter, Tab and Esc reach it; a bare scope shows the box alone, its
/// label kept as its semantic name.
final class EraCheckBox extends StatelessWidget {
  const EraCheckBox({
    required this.value,
    required this.onChanged,
    required this.label,
    this.focusNode,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  /// The check box's focus node, for a host that moves the keyboard to it.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => _Choice(
    label: label,
    focusNode: focusNode,
    checked: value,
    radio: false,
    onPressed: onChanged == null || !EraFormScope.enabledOf(context)
        ? null
        : () => onChanged!(!value),
    mark: _Box(
      checked: value,
      enabled: onChanged != null && EraFormScope.enabledOf(context),
    ),
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
    this.focusable = true,
    this.highlighted = false,
    this.focusNode,
    super.key,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T>? onChanged;
  final String label;

  /// A muted line under the label, such as an example.
  final String? detail;

  /// False inside an [EraRadioGroup], which is the one Tab stop.
  final bool focusable;

  /// Draws the focus rectangle for a group that has focus.
  final bool highlighted;

  /// The radio's focus node, for a host that moves the keyboard to it.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => _Choice(
    label: label,
    focusNode: focusNode,
    detail: detail,
    focusable: focusable,
    highlighted: highlighted,
    checked: value == groupValue,
    radio: true,
    onPressed: onChanged == null || !EraFormScope.enabledOf(context)
        ? null
        : () => onChanged!(value),
    mark: _Dot(
      selected: value == groupValue,
      enabled: onChanged != null && EraFormScope.enabledOf(context),
    ),
  );
}

/// One choice in an [EraRadioGroup].
@immutable
final class EraRadioOption<T> {
  const EraRadioOption(this.value, this.label, {this.detail});

  final T value;
  final String label;
  final String? detail;
}

/// Era radios that are one Tab stop together (XP-authentic shell spec
/// 8.1): Tab enters the group at the chosen radio, the arrow keys move the
/// choice, and Tab leaves for the next control.
final class EraRadioGroup<T> extends StatefulWidget {
  const EraRadioGroup({
    required this.options,
    required this.groupValue,
    required this.onChanged,
    this.direction = Axis.vertical,
    super.key,
  });

  final List<EraRadioOption<T>> options;
  final T groupValue;
  final ValueChanged<T>? onChanged;
  final Axis direction;

  @override
  State<EraRadioGroup<T>> createState() => _EraRadioGroupState<T>();
}

final class _EraRadioGroupState<T> extends State<EraRadioGroup<T>> {
  bool _focused = false;

  /// The group's change, or null while it or its form is locked.
  ValueChanged<T>? get _change =>
      EraFormScope.enabledOf(context) ? widget.onChanged : null;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // A hosted choice changes by mouse only (database shell spec 4.6).
    if (EraEditorHostScope.maybeOf(context) != null) {
      return EraEditorHostScope.handleKey(context, event);
    }
    final change = _change;
    if (change == null || widget.options.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final step = switch (key) {
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowLeft => -1,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final values = [for (final option in widget.options) option.value];
    final at = values.indexOf(widget.groupValue);
    final next = (at < 0 ? 0 : at + step) % values.length;
    change(values[next < 0 ? next + values.length : next]);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final radios = [
      for (final option in widget.options)
        EraRadio<T>(
          value: option.value,
          groupValue: widget.groupValue,
          label: option.label,
          detail: option.detail,
          focusable: false,
          highlighted: _focused && option.value == widget.groupValue,
          onChanged: _change,
        ),
    ];
    return Focus(
      canRequestFocus: _change != null,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _onKey,
      child: widget.direction == Axis.vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: radios,
            )
          : Wrap(spacing: 12, children: radios),
    );
  }
}

final class _Choice extends StatefulWidget {
  const _Choice({
    required this.label,
    required this.checked,
    required this.radio,
    required this.onPressed,
    required this.mark,
    this.detail,
    this.focusable = true,
    this.highlighted = false,
    this.focusNode,
  });

  final String label;
  final String? detail;
  final FocusNode? focusNode;
  final bool focusable;
  final bool highlighted;
  final bool checked;
  final bool radio;
  final VoidCallback? onPressed;
  final Widget mark;

  @override
  State<_Choice> createState() => _ChoiceState();
}

final class _ChoiceState extends State<_Choice> {
  bool _focused = false;

  /// The node a hosted choice focuses on a click, when its owner gave none.
  FocusNode? _ownNode;

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final enabled = widget.onPressed != null;
    final host = EraEditorHostScope.watch(context);
    final bare = host?.bare ?? false;
    // A hosted choice takes focus on a click, so its host's keys reach it.
    final node = host == null
        ? widget.focusNode
        : widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'EraChoice'));
    final onTap = host == null || node == null || !widget.focusable
        ? widget.onPressed
        : widget.onPressed == null
        ? null
        : () {
            node.requestFocus();
            widget.onPressed!();
          };
    final lit = _focused || widget.highlighted;
    final choice = Semantics(
      container: true,
      label: widget.label,
      checked: widget.checked,
      inMutuallyExclusiveGroup: widget.radio ? true : null,
      enabled: enabled,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: node,
        enabled: enabled && widget.focusable,
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
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            // A bare choice (a grid or property cell) is its mark alone,
            // ringed while focused.
            child: bare
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Container(
                      width: 19,
                      height: 19,
                      alignment: Alignment.center,
                      foregroundDecoration: lit
                          ? DottedFocusRectangle(color: tokens.focus, inset: 0)
                          : null,
                      child: widget.mark,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.mark,
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          foregroundDecoration: lit
                              ? DottedFocusRectangle(
                                  color: tokens.focus,
                                  inset: 0,
                                )
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
    return _hostedKeys(context, choice);
  }
}

/// [child] with its keys held inside an editor host, where Space and Enter
/// no longer activate a choice (database shell spec 4.6); [child] alone
/// outside one.
Widget _hostedKeys(BuildContext context, Widget child) {
  if (EraEditorHostScope.watch(context) == null) return child;
  return Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onKeyEvent: (_, event) => EraEditorHostScope.handleKey(context, event),
    child: child,
  );
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
