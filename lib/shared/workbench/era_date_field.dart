import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/time/local_date.dart';
import 'era_controls.dart';
import 'era_dates.dart';
import 'era_month_calendar.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// A date box in the era's Date/Time Picker shape (era pickers spec 3.1):
/// the label above a white box showing "Mon 2026-10-05" beside a blue drop
/// arrow that opens the month calendar. Dates are picked, never typed.
final class EraDateField extends StatefulWidget {
  const EraDateField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.today,
    this.optional = false,
    this.error,
    this.fieldKey,
    super.key,
  }) : assert(optional || value != null);

  final String label;

  /// The date; null only when [optional] and its check box is clear.
  final LocalDate? value;
  final ValueChanged<LocalDate?> onChanged;

  /// Circled in the calendar, and the date a ticked empty box starts on.
  final LocalDate today;

  /// Shows an era check box inside the box; clear means no date.
  final bool optional;
  final String? error;

  /// The key of the white box, which tests and forms address.
  final Key? fieldKey;

  @override
  State<EraDateField> createState() => _EraDateFieldState();
}

final class _EraDateFieldState extends State<EraDateField> {
  final _box = FocusNode(debugLabel: 'EraDateField');
  final _calendarNode = FocusNode(debugLabel: 'EraDateFieldCalendar');
  final _portal = OverlayPortalController();
  LocalDate? _lastShown;
  ScrollPosition? _scroll;
  bool _focused = false;

  bool get _enabled => widget.value != null;

  @override
  void initState() {
    super.initState();
    _lastShown = widget.value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_dismiss);
      _scroll = scroll?..addListener(_dismiss);
    }
  }

  @override
  void didUpdateWidget(EraDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value case final value?) _lastShown = value;
  }

  @override
  void dispose() {
    _scroll?.removeListener(_dismiss);
    _box.dispose();
    _calendarNode.dispose();
    super.dispose();
  }

  void _open() {
    if (!_enabled || _portal.isShowing) return;
    setState(_portal.show);
    // The box already holds focus, so the calendar's autofocus would be
    // ignored; hand focus over once it is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_portal.isShowing) return;
      _calendarNode.requestFocus();
    });
  }

  /// Closes the calendar without a change and without moving focus.
  void _dismiss() {
    if (_portal.isShowing) setState(_portal.hide);
  }

  /// Closes the calendar and gives focus back to the box.
  void _close() {
    _dismiss();
    _box.requestFocus();
  }

  void _pick(LocalDate day) {
    _close();
    if (day != widget.value) widget.onChanged(day);
  }

  void _toggle() {
    if (widget.value == null) {
      widget.onChanged(_lastShown ?? widget.today);
    } else {
      _dismiss();
      widget.onChanged(null);
    }
  }

  void _tapBox() {
    if (_portal.isShowing) {
      _close();
    } else {
      _box.requestFocus();
      _open();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_enabled) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final opens =
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        (key == LogicalKeyboardKey.arrowDown &&
            HardwareKeyboard.instance.isAltPressed);
    if (!opens) return KeyEventResult.ignored;
    _open();
    return KeyEventResult.handled;
  }

  /// Built at layout time, so the calendar follows the box when the window
  /// resizes or the box moves for any other reason.
  Widget _calendar(BuildContext context, OverlayChildLayoutInfo info) {
    final rect = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: EraDropLayout(rect),
        child: TapRegion(
          groupId: this,
          onTapOutside: (_) => _close(),
          child: EraMonthCalendar(
            focusNode: _calendarNode,
            selected: widget.value,
            today: widget.today,
            onPicked: _pick,
            onCancel: _close,
            autofocus: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final t = skin.tokens;
    final value = widget.value;
    final shown = value ?? _lastShown ?? widget.today;
    final name =
        '${widget.label}, ${value == null ? 'none' : spokenDate(value)}';
    final highlighted = _focused && _enabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: skin.typography.body.copyWith(color: t.ink),
          ),
        ),
        const SizedBox(height: 2),
        TapRegion(
          groupId: this,
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portal,
            overlayChildBuilder: _calendar,
            child: Semantics(
              container: true,
              button: true,
              enabled: _enabled,
              label: widget.error == null ? name : '$name, ${widget.error}',
              onTap: _enabled ? _open : null,
              child: Container(
                key: widget.fieldKey,
                constraints: const BoxConstraints(minHeight: 24),
                decoration: BoxDecoration(
                  color: t.paper,
                  border: Border.all(
                    color: widget.error == null
                        ? MillenniumColors.fieldLine
                        : t.negative,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.optional)
                        _EraCheck(
                          key: const ValueKey('era-date-check'),
                          label: widget.label,
                          checked: value != null,
                          onToggle: _toggle,
                        ),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Focus(
                            focusNode: _box,
                            canRequestFocus: _enabled,
                            onKeyEvent: _onKey,
                            onFocusChange: (focused) =>
                                setState(() => _focused = focused),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _enabled ? _tapBox : null,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                          vertical: 2,
                                        ),
                                        child: Container(
                                          color: highlighted ? t.selWash : null,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Text(
                                            eraBoxDate(shown),
                                            style: skin.typography.figure
                                                .copyWith(
                                                  color: !_enabled
                                                      ? t.muted
                                                      : highlighted
                                                      ? t.selInk
                                                      : t.ink,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _DropButton(
                                    key: const ValueKey('era-date-drop'),
                                    enabled: _enabled,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ExcludeSemantics(
              child: Text(
                error,
                style: skin.typography.small.copyWith(color: t.negative),
              ),
            ),
          ),
      ],
    );
  }
}

/// Places a drop-down below [anchor]. It goes above when there is no room
/// below, or on the side with more room when neither fits. It is kept
/// inside the window from left to right.
final class EraDropLayout extends SingleChildLayoutDelegate {
  const EraDropLayout(this.anchor);

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final roomBelow = size.height - anchor.bottom;
    final roomAbove = anchor.top;
    final below =
        childSize.height <= roomBelow ||
        (childSize.height > roomAbove && roomBelow >= roomAbove);
    final top = below
        ? math.min(anchor.bottom, math.max(0.0, size.height - childSize.height))
        : math.max(0.0, anchor.top - childSize.height);
    final left = anchor.left
        .clamp(0.0, math.max(0.0, size.width - childSize.width))
        .toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(EraDropLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

/// The blue drop-arrow button at the box's right edge; grey when the box
/// has no date. The box handles the click.
final class _DropButton extends StatelessWidget {
  const _DropButton({required this.enabled, super.key});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = LifeOSSkinScope.of(context).tokens;
    return Container(
      width: 17,
      decoration: BoxDecoration(
        color: enabled ? null : t.chrome,
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MillenniumColors.comboArrowTop,
                  MillenniumColors.comboArrowBottom,
                ],
              )
            : null,
      ),
      child: Center(
        child: EraGlyph(
          EraGlyphKind.dropDown,
          color: enabled ? MillenniumColors.comboArrowInk : t.muted,
        ),
      ),
    );
  }
}

/// The era check box inside an optional date box: a white square with a
/// green tick. A tab stop of its own; Space or a click toggles it.
final class _EraCheck extends StatefulWidget {
  const _EraCheck({
    required this.label,
    required this.checked,
    required this.onToggle,
    super.key,
  });

  final String label;
  final bool checked;
  final VoidCallback onToggle;

  @override
  State<_EraCheck> createState() => _EraCheckState();
}

final class _EraCheckState extends State<_EraCheck> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = LifeOSSkinScope.of(context).tokens;
    return MergeSemantics(
      child: Semantics(
        container: true,
        checked: widget.checked,
        label: widget.label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onToggle();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: ExcludeSemantics(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: _focused
                    ? DottedFocusRectangle(color: t.focus, inset: 3.5)
                    : const BoxDecoration(),
                child: SizedBox(
                  width: 24,
                  child: Center(
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: t.paper,
                        border: Border.all(color: MillenniumColors.fieldLine),
                      ),
                      child: widget.checked
                          ? const Center(
                              child: EraGlyph(
                                EraGlyphKind.tick,
                                color: MillenniumColors.orbGreen,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
