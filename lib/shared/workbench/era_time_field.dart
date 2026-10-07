import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/time/local_time.dart';
import 'era_controls.dart';
import 'era_form.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// The parts of a time box, left to right.
enum TimePart { hour, minute, second }

/// [time] with [part] moved by [delta], wrapping within the part without
/// carrying: 23 plus one hour is 00 and the minutes stay.
LocalTime stepTime(LocalTime time, TimePart part, int delta) => switch (part) {
  TimePart.hour => LocalTime(
    (time.hour + delta) % 24,
    time.minute,
    time.second,
  ),
  TimePart.minute => LocalTime(
    time.hour,
    (time.minute + delta) % 60,
    time.second,
  ),
  TimePart.second => LocalTime(
    time.hour,
    time.minute,
    (time.second + delta) % 60,
  ),
};

/// "07:00", or "07:00:13" when [withSeconds].
String eraTimeText(LocalTime time, {required bool withSeconds}) {
  final text = time.toString();
  return withSeconds ? text : text.substring(0, 5);
}

/// The digit a key types, from the main row or the numpad; null for others.
int? _digitOf(LogicalKeyboardKey key) {
  const rows = [
    [LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0],
    [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
    [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
    [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
    [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
    [LogicalKeyboardKey.digit5, LogicalKeyboardKey.numpad5],
    [LogicalKeyboardKey.digit6, LogicalKeyboardKey.numpad6],
    [LogicalKeyboardKey.digit7, LogicalKeyboardKey.numpad7],
    [LogicalKeyboardKey.digit8, LogicalKeyboardKey.numpad8],
    [LogicalKeyboardKey.digit9, LogicalKeyboardKey.numpad9],
  ];
  for (final (digit, keys) in rows.indexed) {
    if (keys.contains(key)) return digit;
  }
  return null;
}

String _two(int value) => value.toString().padLeft(2, '0');

/// A time box in the era's Date/Time Picker shape (era pickers spec 3.3):
/// hours and minutes, and seconds only for a value that has them, beside
/// stacked spin arrows. Times are stepped with the arrows or typed into the
/// selected part, as the era's Date/Time Picker took them (amended
/// 2026-10-07 at the owner's request); dates stay pick-only.
final class EraTimeField extends StatefulWidget {
  const EraTimeField({
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
    this.emptyStart = const LocalTime(0, 0),
    this.enabled = true,
    this.error,
    this.fieldKey,
    super.key,
  }) : assert(label != null || semanticLabel != null);

  /// The time, or null for an empty box showing "--:--".
  final LocalTime? value;
  final ValueChanged<LocalTime> onChanged;

  /// Shown above the box; none in a sentence such as "22:00 to 06:00".
  final String? label;

  /// Announced instead of [label].
  final String? semanticLabel;

  /// What the first step of an empty box sets, in whole minutes.
  final LocalTime emptyStart;
  final bool enabled;
  final String? error;

  /// The key of the white box, which tests and forms address.
  final Key? fieldKey;

  @override
  State<EraTimeField> createState() => _EraTimeFieldState();
}

final class _EraTimeFieldState extends State<EraTimeField> {
  final _focus = FocusNode(debugLabel: 'EraTimeField');

  /// Off for a disabled box or one in a read-only form.
  bool get _enabled => widget.enabled && EraFormScope.enabledOf(context);
  TimePart _part = TimePart.hour;
  bool _focused = false;

  /// Set while a click, not Tab, is focusing the box, so the clicked part
  /// stays selected instead of the hours.
  bool _pointerChosePart = false;
  late bool _withSeconds = (widget.value?.second ?? 0) != 0;

  /// The value last sent, until the parent rebuilds with it: a held spin
  /// button may tick twice in one frame.
  LocalTime? _sent;
  Timer? _repeat;

  /// The first digit typed into the selected part, while a second may
  /// still follow; null when none waits.
  int? _pending;

  List<TimePart> get _parts => [
    TimePart.hour,
    TimePart.minute,
    if (_withSeconds) TimePart.second,
  ];

  @override
  void didUpdateWidget(EraTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A value from outside discards a half-typed digit.
    if (widget.value != oldWidget.value && widget.value != _sent) {
      _pending = null;
    }
    _sent = null;
    if ((widget.value?.second ?? 0) != 0) _withSeconds = true;
    if (!_enabled) _stopRepeat();
  }

  @override
  void dispose() {
    _stopRepeat();
    _focus.dispose();
    super.dispose();
  }

  void _step(int delta) {
    if (!_enabled || !mounted) return;
    _pending = null;
    final current = _sent ?? widget.value;
    final start = widget.emptyStart;
    final next = current == null
        ? LocalTime(start.hour, start.minute)
        : stepTime(current, _part, delta);
    _sent = next;
    widget.onChanged(next);
  }

  void _focusKeepingPart() {
    if (_focus.hasFocus) return;
    _pointerChosePart = true;
    _focus.requestFocus();
  }

  void _choose(TimePart part) {
    _focusKeepingPart();
    setState(() {
      _part = part;
      _pending = null;
    });
  }

  void _onFocusChange(bool focused) => setState(() {
    _focused = focused;
    _pending = null;
    if (focused && !_pointerChosePart) _part = TimePart.hour;
    _pointerChosePart = false;
  });

  void _startRepeat(int delta) {
    if (!_enabled) return;
    _focusKeepingPart();
    _step(delta);
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 400), () {
      _step(delta);
      _repeat = Timer.periodic(
        const Duration(milliseconds: 60),
        (_) => _step(delta),
      );
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  /// Types [digit] into the selected part. A first digit that could begin
  /// a two-digit value waits for its second; any other commits at once, and
  /// either way a finished part passes the selection on.
  void _type(int digit) {
    final first = _part == TimePart.hour ? 2 : 5;
    final limit = _part == TimePart.hour ? 24 : 60;
    final pending = _pending;
    final joined = pending == null ? null : pending * 10 + digit;
    final value = joined != null && joined < limit ? joined : digit;
    final done = value == joined || digit > first;
    final current =
        _sent ??
        widget.value ??
        const LocalTime(0, 0); // only a step starts from emptyStart
    final next = switch (_part) {
      TimePart.hour => LocalTime(value, current.minute, current.second),
      TimePart.minute => LocalTime(current.hour, value, current.second),
      TimePart.second => LocalTime(current.hour, current.minute, value),
    };
    _sent = next;
    widget.onChanged(next);
    _pending = done ? null : digit;
    if (done) _nextPart();
    setState(() {});
  }

  void _nextPart() {
    final index = _parts.indexOf(_part);
    if (index < _parts.length - 1) _part = _parts[index + 1];
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final delta = key == LogicalKeyboardKey.arrowUp
        ? 1
        : key == LogicalKeyboardKey.arrowDown
        ? -1
        : key == LogicalKeyboardKey.pageUp
        ? 10
        : key == LogicalKeyboardKey.pageDown
        ? -10
        : 0;
    if (delta != 0) {
      _step(delta);
      return KeyEventResult.handled;
    }
    // Left and Right stay in the box at its ends, as in the era: passed
    // on, they would move focus and the next Up would step another box.
    final index = _parts.indexOf(_part);
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _pending = null;
        if (index > 0) _part = _parts[index - 1];
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _pending = null;
        _nextPart();
      });
      return KeyEventResult.handled;
    }
    // Typing acts once per press; a held key does not repeat.
    if (!_enabled || event is! KeyDownEvent) return KeyEventResult.ignored;
    // Typed digits, as in the era's picker. A shortcut is not typing.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final digit = _digitOf(key);
    if (digit != null && !keyboard.isShiftPressed) {
      _type(digit);
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (key == LogicalKeyboardKey.colon ||
        key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal ||
        character == ':' ||
        character == '.') {
      setState(() {
        _pending = null;
        _nextPart();
      });
      return KeyEventResult.handled;
    }
    // Backspace drops the digit waiting for a second; the part keeps its
    // value, as a box never goes empty once set.
    if (key == LogicalKeyboardKey.backspace) {
      setState(() => _pending = null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final t = skin.tokens;
    final value = widget.value;
    final name = widget.semanticLabel ?? widget.label!;
    final spoken =
        '$name, ${value == null ? 'not set' : eraTimeText(value, withSeconds: _withSeconds)}';
    final ink = _enabled ? t.ink : t.muted;

    Widget part(TimePart part) {
      final digits = value == null
          ? '--'
          : _two(switch (part) {
              TimePart.hour => value.hour,
              TimePart.minute => value.minute,
              TimePart.second => value.second,
            });
      final selected = _focused && _part == part;
      return Listener(
        key: ValueKey('era-time-${part.name}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _enabled
            ? (event) {
                if (event.buttons == kPrimaryButton) _choose(part);
              }
            : null,
        child: Container(
          color: selected ? t.selWash : null,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            digits,
            style: skin.typography.figure.copyWith(
              color: selected ? t.selInk : ink,
            ),
          ),
        ),
      );
    }

    final colon = Text(':', style: skin.typography.figure.copyWith(color: ink));
    final box = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Focus(
            focusNode: _focus,
            canRequestFocus: _enabled,
            onKeyEvent: _onKey,
            onFocusChange: _onFocusChange,
            child: Semantics(
              enabled: _enabled,
              label: widget.error == null ? spoken : '$spoken, ${widget.error}',
              onIncrease: _enabled ? () => _step(1) : null,
              onDecrease: _enabled ? () => _step(-1) : null,
              excludeSemantics: true,
              child: Container(
                key: widget.fieldKey,
                constraints: const BoxConstraints(minHeight: 24),
                decoration: BoxDecoration(
                  color: _enabled ? t.paper : t.chrome,
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
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            // One unbreakable run: "22:00" never splits
                            // into "22:" and "00"; the box grows instead.
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                part(TimePart.hour),
                                colon,
                                part(TimePart.minute),
                                if (_withSeconds) ...[
                                  colon,
                                  part(TimePart.second),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 17,
                        child: Column(
                          children: [
                            Expanded(
                              child: _SpinKey(
                                key: const ValueKey('era-time-up'),
                                up: true,
                                enabled: _enabled,
                                onDown: () => _startRepeat(1),
                                onUp: _stopRepeat,
                              ),
                            ),
                            Expanded(
                              child: _SpinKey(
                                key: const ValueKey('era-time-down'),
                                up: false,
                                enabled: _enabled,
                                onDown: () => _startRepeat(-1),
                                onUp: _stopRepeat,
                              ),
                            ),
                          ],
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
    // A labelled box sits after "Label:" in the dialog's label column
    // (XP-authentic shell spec 8.1); a box set in a sentence has no label.
    final label = widget.label;
    if (label == null) return box;
    return EraLabelled(
      label: label,
      fieldWidth: EraFieldWidth.time,
      grow: true,
      field: box,
    );
  }
}

/// One of the stacked ▴▾ buttons. It reacts on pointer down so that holding
/// it repeats, as in the era, and looks pressed while held.
final class _SpinKey extends StatefulWidget {
  const _SpinKey({
    required this.up,
    required this.enabled,
    required this.onDown,
    required this.onUp,
    super.key,
  });

  final bool up;
  final bool enabled;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<_SpinKey> createState() => _SpinKeyState();
}

final class _SpinKeyState extends State<_SpinKey> {
  bool _pressed = false;

  void _press(PointerDownEvent event) {
    // Only the main button spins; a right or middle press does nothing.
    if (event.buttons != kPrimaryButton) return;
    setState(() => _pressed = true);
    widget.onDown();
  }

  void _release() {
    if (_pressed) setState(() => _pressed = false);
    widget.onUp();
  }

  @override
  void didUpdateWidget(_SpinKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = LifeOSSkinScope.of(context).tokens;
    const resting = [
      MillenniumColors.comboArrowTop,
      MillenniumColors.comboArrowBottom,
    ];
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.enabled ? _press : null,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.enabled ? null : t.chrome,
          // Pressing inverts the gradient, as on the era's keys.
          gradient: widget.enabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _pressed ? resting.reversed.toList() : resting,
                )
              : null,
          border: Border(
            top: widget.up ? BorderSide.none : BorderSide(color: t.paper),
          ),
        ),
        child: Center(
          child: EraGlyph(
            widget.up ? EraGlyphKind.sortUp : EraGlyphKind.sortDown,
            color: widget.enabled ? MillenniumColors.comboArrowInk : t.muted,
            size: 7,
          ),
        ),
      ),
    );
  }
}
