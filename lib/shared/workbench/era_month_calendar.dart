import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/time/local_date.dart';
import 'era_controls.dart';
import 'era_dates.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// The era's month calendar (era pickers spec 3.2): the month on a blue
/// band between ◂ and ▸, six Monday-first weeks with today circled, and a
/// Today link. A date box drops it down; it also stands alone.
final class EraMonthCalendar extends StatefulWidget {
  const EraMonthCalendar({
    required this.today,
    required this.onPicked,
    this.selected,
    this.onCancel,
    this.autofocus = false,
    super.key,
  });

  final LocalDate today;
  final ValueChanged<LocalDate> onPicked;

  /// The chosen day, filled with selection blue. The cursor starts here.
  final LocalDate? selected;

  /// Esc. When set, the calendar is a drop-down and keeps Tab inside it.
  final VoidCallback? onCancel;
  final bool autofocus;

  @override
  State<EraMonthCalendar> createState() => _EraMonthCalendarState();
}

final class _EraMonthCalendarState extends State<EraMonthCalendar> {
  late LocalDate _cursor = widget.selected ?? widget.today;
  bool _focused = false;

  void _moveTo(LocalDate day) => setState(() => _cursor = day);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final years = HardwareKeyboard.instance.isShiftPressed;
    LocalDate? target() {
      if (key == LogicalKeyboardKey.arrowLeft) return _cursor.addDays(-1);
      if (key == LogicalKeyboardKey.arrowRight) return _cursor.addDays(1);
      if (key == LogicalKeyboardKey.arrowUp) return _cursor.addDays(-7);
      if (key == LogicalKeyboardKey.arrowDown) return _cursor.addDays(7);
      if (key == LogicalKeyboardKey.pageUp) {
        return _cursor.addMonthsClamped(years ? -12 : -1);
      }
      if (key == LogicalKeyboardKey.pageDown) {
        return _cursor.addMonthsClamped(years ? 12 : 1);
      }
      if (key == LogicalKeyboardKey.home) return _cursor.firstOfMonth;
      if (key == LogicalKeyboardKey.end) return _cursor.lastOfMonth;
      return null;
    }

    if (target() case final day?) {
      _moveTo(day);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      widget.onPicked(_cursor);
      return KeyEventResult.handled;
    }
    if (widget.onCancel case final cancel?) {
      if (key == LogicalKeyboardKey.escape) {
        cancel();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab) return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final t = skin.tokens;
    final month = _cursor.firstOfMonth;
    final days = monthGridDays(month);
    return Focus(
      autofocus: widget.autofocus,
      debugLabel: 'EraMonthCalendar',
      onKeyEvent: _onKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: eraMonthTitle(month),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.paper,
            border: Border.all(color: t.ink),
          ),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(skin, month),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: t.chromeLine),
                          ),
                        ),
                        children: [
                          for (final initial in eraWeekdayInitials)
                            _initial(skin, initial),
                        ],
                      ),
                      for (var week = 0; week < 6; week++)
                        TableRow(
                          children: [
                            for (final day in days.sublist(
                              week * 7,
                              week * 7 + 7,
                            ))
                              _day(skin, day, month),
                          ],
                        ),
                    ],
                  ),
                ),
                _footer(skin),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(LifeOSSkinData skin, LocalDate month) {
    final t = skin.tokens;
    return Container(
      color: t.head,
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _HeaderKey(
            key: const ValueKey('era-calendar-previous'),
            label: 'Previous month',
            glyph: EraGlyphKind.stepBack,
            onPressed: () => _moveTo(_cursor.addMonthsClamped(-1)),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                eraMonthTitle(month),
                key: const ValueKey('era-calendar-title'),
                textAlign: TextAlign.center,
                style: skin.typography.body.copyWith(
                  color: t.headInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _HeaderKey(
            key: const ValueKey('era-calendar-next'),
            label: 'Next month',
            glyph: EraGlyphKind.stepForward,
            onPressed: () => _moveTo(_cursor.addMonthsClamped(1)),
          ),
        ],
      ),
    );
  }

  Widget _initial(LifeOSSkinData skin, String text) => ExcludeSemantics(
    child: Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 20),
      alignment: Alignment.center,
      child: Text(
        text,
        style: skin.typography.small.copyWith(color: skin.tokens.head),
      ),
    ),
  );

  Widget _day(LifeOSSkinData skin, LocalDate day, LocalDate month) {
    final t = skin.tokens;
    final chosen = day == widget.selected;
    final inMonth = day.year == month.year && day.month == month.month;
    Widget cell = Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: chosen ? t.selWash : null,
      child: Text(
        '${day.day}',
        style: skin.typography.figure.copyWith(
          color: chosen ? t.selInk : (inMonth ? t.ink : t.muted),
        ),
      ),
    );
    if (day == widget.today) {
      cell = DecoratedBox(
        key: const ValueKey('era-today-ring'),
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: OvalBorder(side: BorderSide(color: t.negative, width: 1.5)),
        ),
        child: cell,
      );
    }
    if (_focused && day == _cursor) {
      cell = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: DottedFocusRectangle(
          color: chosen ? t.selInk : t.focus,
          inset: 1.5,
        ),
        child: cell,
      );
    }
    return Semantics(
      button: true,
      selected: chosen,
      label: spokenDate(day),
      onTap: () => widget.onPicked(day),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('era-day-$day'),
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onPicked(day),
        child: cell,
      ),
    );
  }

  Widget _footer(LifeOSSkinData skin) {
    final t = skin.tokens;
    final label = 'Today: ${widget.today}';
    return Semantics(
      link: true,
      label: label,
      onTap: () => widget.onPicked(widget.today),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('era-calendar-today'),
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onPicked(widget.today),
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 11,
                decoration: BoxDecoration(
                  border: Border.all(color: t.negative, width: 1.5),
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: skin.typography.body.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ◂ or ▸ on the calendar band: a small push-button face. Not a tab stop;
/// PageUp and PageDown do the same from the keyboard.
final class _HeaderKey extends StatelessWidget {
  const _HeaderKey({
    required this.label,
    required this.glyph,
    required this.onPressed,
    super.key,
  });

  final String label;
  final EraGlyphKind glyph;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final face = skin.painters.key(
      skin.tokens,
      KeyKind.small,
      const KeyState(),
    );
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: 24,
          height: 24,
          decoration: face.decoration,
          child: Center(child: EraGlyph(glyph, color: face.ink)),
        ),
      ),
    );
  }
}
