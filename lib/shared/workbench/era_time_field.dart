import 'dart:async';

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

String _two(int value) => value.toString().padLeft(2, '0');

/// A time box in the era's Date/Time Picker shape (era pickers spec 3.3):
/// hours and minutes, and seconds only for a value that has them, beside
/// stacked spin arrows. Times are stepped, never typed.
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

  List<TimePart> get _parts => [
    TimePart.hour,
    TimePart.minute,
    if (_withSeconds) TimePart.second,
  ];

  @override
  void didUpdateWidget(EraTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sent = null;
    if ((widget.value?.second ?? 0) != 0) _withSeconds = true;
    if (!widget.enabled) _stopRepeat();
  }

  @override
  void dispose() {
    _stopRepeat();
    _focus.dispose();
    super.dispose();
  }

  void _step(int delta) {
    if (!widget.enabled || !mounted) return;
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
    setState(() => _part = part);
  }

  void _onFocusChange(bool focused) => setState(() {
    _focused = focused;
    if (focused && !_pointerChosePart) _part = TimePart.hour;
    _pointerChosePart = false;
  });

  void _startRepeat(int delta) {
    if (!widget.enabled) return;
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
    final index = _parts.indexOf(_part);
    if (key == LogicalKeyboardKey.arrowLeft && index > 0) {
      setState(() => _part = _parts[index - 1]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && index < _parts.length - 1) {
      setState(() => _part = _parts[index + 1]);
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
    final ink = widget.enabled ? t.ink : t.muted;

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
        onPointerDown: widget.enabled ? (_) => _choose(part) : null,
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
            canRequestFocus: widget.enabled,
            onKeyEvent: _onKey,
            onFocusChange: _onFocusChange,
            child: Semantics(
              enabled: widget.enabled,
              label: widget.error == null ? spoken : '$spoken, ${widget.error}',
              onIncrease: widget.enabled ? () => _step(1) : null,
              onDecrease: widget.enabled ? () => _step(-1) : null,
              excludeSemantics: true,
              child: Container(
                key: widget.fieldKey,
                constraints: const BoxConstraints(minHeight: 24),
                decoration: BoxDecoration(
                  color: widget.enabled ? t.paper : t.chrome,
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
                                enabled: widget.enabled,
                                onDown: () => _startRepeat(1),
                                onUp: _stopRepeat,
                              ),
                            ),
                            Expanded(
                              child: _SpinKey(
                                key: const ValueKey('era-time-down'),
                                up: false,
                                enabled: widget.enabled,
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
/// it repeats, as in the era.
final class _SpinKey extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = LifeOSSkinScope.of(context).tokens;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled ? (_) => onDown() : null,
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: DecoratedBox(
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
          border: Border(
            top: up ? BorderSide.none : BorderSide(color: t.paper),
          ),
        ),
        child: Center(
          child: EraGlyph(
            up ? EraGlyphKind.sortUp : EraGlyphKind.sortDown,
            color: enabled ? MillenniumColors.comboArrowInk : t.muted,
            size: 7,
          ),
        ),
      ),
    );
  }
}
