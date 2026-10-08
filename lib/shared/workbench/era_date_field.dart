import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/time/local_date.dart';
import 'era_controls.dart';
import 'era_dates.dart';
import 'era_form.dart';
import 'era_month_calendar.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// The parts of a date box that take digits, left to right. The weekday
/// before them follows the date and is not one.
enum _DatePart { year, month, day }

/// [date] with [part] set to [value]. A day past the month's end becomes
/// its last day: 31 March with February typed is 28 or 29 February.
LocalDate _withPart(LocalDate date, _DatePart part, int value) {
  final year = part == _DatePart.year ? value : date.year;
  final month = part == _DatePart.month ? value : date.month;
  final day = part == _DatePart.day ? value : date.day;
  final last = LocalDate(year, month, 1).daysInMonth;
  return LocalDate(year, month, day < last ? day : last);
}

/// [date] with [part] moved by [delta], wrapping within the part without
/// carrying: December plus one month is January of the same year, and the
/// 31st plus one day is the 1st of the same month.
LocalDate _stepDate(
  LocalDate date,
  _DatePart part,
  int delta,
) => switch (part) {
  _DatePart.year => _withPart(date, part, (date.year + delta).clamp(1, 9999)),
  _DatePart.month => _withPart(date, part, (date.month - 1 + delta) % 12 + 1),
  _DatePart.day => _withPart(
    date,
    part,
    (date.day - 1 + delta) % date.daysInMonth + 1,
  ),
};

/// A date box in the era's Date/Time Picker shape (era pickers spec 3.1):
/// the label above a white box showing "Mon 2026-10-05" beside a blue drop
/// arrow that opens the month calendar. Dates are picked from the calendar
/// or typed into the selected part, year, month or day, as the era's
/// picker took them (amended 2026-10-08 at the owner's request).
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
  _DatePart _part = _DatePart.year;

  /// Set while a click on a part, or the calendar closing, focuses the box,
  /// so the part stays selected instead of the year.
  bool _keepPart = false;

  /// The digits typed into the selected part while more may follow: up to
  /// three of a year, or the first of a month or day.
  String _typed = '';

  /// The value last sent, until the parent rebuilds with it: two keys may
  /// land in one frame.
  LocalDate? _sent;

  /// Select a part on a click on its digits. They win the click from the
  /// box, which would open the calendar.
  late final _choosers = {
    for (final part in _DatePart.values)
      part: TapGestureRecognizer(debugOwner: this)
        ..onTapDown = (_) => _choose(part),
  };

  /// Off for a clear optional box, or one in a read-only form.
  bool get _enabled => widget.value != null && EraFormScope.enabledOf(context);

  @override
  void initState() {
    super.initState();
    _lastShown = widget.value;
    _calendarNode.addListener(_onCalendarFocus);
  }

  /// Any way focus leaves the open calendar closes it, so it never stays
  /// open without the keyboard. Focus stays where it went.
  void _onCalendarFocus() {
    if (mounted && !_calendarNode.hasFocus) _dismiss();
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
    // A value from outside discards half-typed digits.
    if (widget.value != oldWidget.value && widget.value != _sent) _typed = '';
    _sent = null;
  }

  @override
  void dispose() {
    for (final chooser in _choosers.values) {
      chooser.dispose();
    }
    _scroll?.removeListener(_dismiss);
    _box.dispose();
    _calendarNode
      ..removeListener(_onCalendarFocus)
      ..dispose();
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

  /// Closes the calendar and gives focus back to the box, on the part it
  /// had selected.
  void _close() {
    _dismiss();
    _focusKeepingPart();
  }

  void _pick(LocalDate day) {
    _close();
    _send(day);
  }

  /// Sends [next] unless the box already holds it.
  void _send(LocalDate next) {
    if (next == (_sent ?? widget.value)) return;
    _sent = next;
    widget.onChanged(next);
  }

  void _focusKeepingPart() {
    if (_box.hasFocus) return;
    _keepPart = true;
    _box.requestFocus();
  }

  void _onFocusChange(bool focused) => setState(() {
    _focused = focused;
    _typed = '';
    if (focused && !_keepPart) _part = _DatePart.year;
    _keepPart = false;
  });

  /// A click on a part selects it. Focus leaving an open calendar for the
  /// box closes it.
  void _choose(_DatePart part) {
    _focusKeepingPart();
    setState(() {
      _part = part;
      _typed = '';
    });
  }

  void _step(int delta) {
    _send(_stepDate(_sent ?? widget.value!, _part, delta));
    setState(() => _typed = '');
  }

  void _movePart(int delta) => setState(() {
    _typed = '';
    _part = _DatePart.values[(_part.index + delta).clamp(0, 2)];
  });

  /// Types [digit] into the selected part. A year waits for its fourth
  /// digit. A month or day takes a first digit at once and, when it could
  /// begin a two-digit value (a month's 0 or 1, a day's 0 to 3), waits for
  /// the second; a value that is no month or day starts again from the
  /// last digit. A finished part passes the selection on.
  void _type(int digit) {
    final current = _sent ?? widget.value!;
    final typed = '$_typed$digit';
    if (_part == _DatePart.year) {
      if (typed.length < 4) {
        setState(() => _typed = typed);
        return;
      }
      final year = int.parse(typed);
      // Year 0000 is no year: the last 0 is a first digit again.
      if (year == 0) {
        setState(() => _typed = '$digit');
        return;
      }
      _send(_withPart(current, _part, year));
      _movePart(1);
      return;
    }
    final month = _part == _DatePart.month;
    final joined = _typed.isEmpty ? null : int.parse(typed);
    final whole = joined != null && joined >= 1 && joined <= (month ? 12 : 31);
    final value = whole ? joined : digit;
    final done = whole || digit > (month ? 1 : 3);
    if (value >= 1) _send(_withPart(current, _part, value));
    if (done) {
      _movePart(1);
    } else {
      setState(() => _typed = '$digit');
    }
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
    if (event is KeyUpEvent || !_enabled) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final press = event is KeyDownEvent;
    // Alt+Down opens; held, it never steps the month as plain Down would.
    if (key == LogicalKeyboardKey.arrowDown && keyboard.isAltPressed) {
      if (press) _open();
      return KeyEventResult.handled;
    }
    if (press &&
        (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _open();
      return KeyEventResult.handled;
    }
    // A shortcut is not typing.
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _step(key == LogicalKeyboardKey.arrowUp ? 1 : -1);
      return KeyEventResult.handled;
    }
    // Left and Right stay in the box at its ends, as the time box's do.
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _movePart(key == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      return KeyEventResult.handled;
    }
    // Typing acts once per press; a held key does not repeat, nor reach
    // a shortcut above the box.
    final digit = eraTypedDigit(key);
    if (digit != null && !keyboard.isShiftPressed) {
      if (press) _type(digit);
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.numpadDivide ||
        key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal ||
        character == '-' ||
        character == '/' ||
        character == '.') {
      if (press) _movePart(1);
      return KeyEventResult.handled;
    }
    // Backspace drops the digits waiting for more; the part keeps its
    // value, as a box never goes empty once set.
    if (key == LogicalKeyboardKey.backspace) {
      setState(() => _typed = '');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
          // Runs after a control taking focus on press has asked for it.
          // That request is settled first, or the calendar going away would
          // hand focus back to the box. With nothing focusable clicked, the
          // calendar's focus returns to the box as it goes.
          onTapOutside: (_) {
            FocusManager.instance.applyFocusChangesIfNeeded();
            _dismiss();
          },
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
    final style = skin.typography.figure.copyWith(
      color: _enabled ? t.ink : t.muted,
    );

    /// One part of the date, filled with selection blue while selected.
    /// A click on it selects it rather than opening the calendar.
    TextSpan part(_DatePart part) {
      final selected = _focused && _enabled && _part == part;
      return TextSpan(
        text: selected && _typed.isNotEmpty
            ? _typed
            : switch (part) {
                _DatePart.year => shown.year.toString().padLeft(4, '0'),
                _DatePart.month => shown.month.toString().padLeft(2, '0'),
                _DatePart.day => shown.day.toString().padLeft(2, '0'),
              },
        style: selected
            ? TextStyle(color: t.selInk, backgroundColor: t.selWash)
            : null,
        recognizer: _enabled ? _choosers[part] : null,
      );
    }

    // "Label:" in the dialog's label column, the box after it (XP-authentic
    // shell spec 8.1). The optional check box widens the box a little.
    return EraLabelled(
      label: widget.label,
      fieldWidth: widget.optional
          ? EraFieldWidth.date + 20
          : EraFieldWidth.date,
      field: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TapRegion(
            groupId: this,
            child: OverlayPortal.overlayChildLayoutBuilder(
              controller: _portal,
              overlayChildBuilder: _calendar,
              child: Semantics(
                container: true,
                button: true,
                enabled: _enabled,
                // The Focus below is excluded with the box's inner text, so
                // the button reports focus itself, as EraTimeField does. A
                // non-null value also marks it focusable; a clear box is not.
                focused: _enabled ? _focused : null,
                label: widget.error == null ? name : '$name, ${widget.error}',
                onTap: _enabled ? _open : null,
                child: Container(
                  key: widget.fieldKey,
                  constraints: const BoxConstraints(minHeight: 24),
                  decoration: BoxDecoration(
                    // A read-only form greys the box onto the face colour.
                    color: EraFormScope.enabledOf(context) ? t.paper : t.chrome,
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
                            onToggle: EraFormScope.enabledOf(context)
                                ? _toggle
                                : null,
                          ),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Focus(
                              focusNode: _box,
                              canRequestFocus: _enabled,
                              onKeyEvent: _onKey,
                              onFocusChange: _onFocusChange,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _enabled ? _tapBox : null,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          child: Text.rich(
                                            TextSpan(
                                              style: style,
                                              children: [
                                                TextSpan(
                                                  text:
                                                      '${eraWeekdayShort(shown)} ',
                                                ),
                                                part(_DatePart.year),
                                                const TextSpan(text: '-'),
                                                part(_DatePart.month),
                                                const TextSpan(text: '-'),
                                                part(_DatePart.day),
                                              ],
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
      ),
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

  /// Null locks the check box, in a read-only form.
  final VoidCallback? onToggle;

  @override
  State<_EraCheck> createState() => _EraCheckState();
}

final class _EraCheckState extends State<_EraCheck> {
  final _node = FocusNode(debugLabel: 'EraDateFieldCheck');
  bool _focused = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  /// A click focuses the check box, as in the era, so unticking with the
  /// calendar open leaves focus on a control.
  void _tap() {
    if (widget.onToggle == null) return;
    _node.requestFocus();
    widget.onToggle!();
  }

  @override
  Widget build(BuildContext context) {
    final t = LifeOSSkinScope.of(context).tokens;
    return MergeSemantics(
      child: Semantics(
        container: true,
        checked: widget.checked,
        label: widget.label,
        child: FocusableActionDetector(
          focusNode: _node,
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onToggle?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
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
