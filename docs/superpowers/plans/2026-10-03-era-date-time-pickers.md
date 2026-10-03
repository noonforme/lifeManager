# Era Date and Time Pickers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every typed `YYYY-MM-DD` and `HH:MM` field in LifeOS with picked controls that look and behave like the 2001-era Date/Time Picker: a date box with a blue drop arrow and a Monday-first month calendar, and a time box with stacked spin arrows.

**Architecture:** There are three new LifeOS-owned controls in `lib/shared/workbench/`. `EraMonthCalendar` is a standalone keyboard-driven month grid. `EraDateField` shows a date and drops the calendar into an `OverlayPortal`, placed by a `SingleChildLayoutDelegate` that opens it below the box, or above when there is no room below. `EraTimeField` shows hour, minute and, when needed, second parts that spin. Pure helpers hold the date maths and the time stepping, so tests can check them without widgets. The forms keep `LocalDate`/`LocalTime` values in state instead of text controllers, and the parse messages are removed. The tests drive the real controls through `pickDate`/`setTime` in `test/support/`.

**Tech Stack:** Flutter 3.47.5, Dart 3.13, `flutter_test` (widget, semantics and golden tests). No new packages.

**Spec:** `docs/superpowers/specs/2026-10-03-era-date-time-pickers-design.md`

## Global Constraints

- Work on a new branch `feat/era-pickers` cut from `feat/work-schedules`. Part 2's schedule screens build on both.
- Flutter binary: `F=~/.local/opt/flutter-3.47.5/bin`. Tests: `$F/flutter test <path>`. Analysis: `$F/flutter analyze lib test tool`. Format: `$F/dart format lib test tool`.
- Every task ends with analyze reporting "No issues found!", `$F/dart format --output=none --set-exit-if-changed lib test tool` passing, and `$F/flutter test` green.
- The look is the 2001 desktop era (Millennium style) only. Never use vendor names, logos, icons, wallpapers or sounds.
- Colours come from `LifeOSTokens` / `MillenniumColors` only. No literal colours in widgets.
- The drop arrow, ◂ ▸ and ▴▾ are painted with `EraGlyph`, because the bundled Noto Sans lacks those glyphs.
- Date text in the box is `Mon 2026-10-05`: the weekday, then the ISO date, in the figure (tabular) face.
- Weeks start on Monday. Month and weekday names are English.
- The boxes are picked, never typed: no `TextField` inside a date or time box.
- Seconds are shown only when the value has them. New times are whole minutes. A value without seconds never gains them.
- The existing field keys stay on the new boxes (`agreement-effective-start`, `shift-start-time`, `period-start`, `range-from`, …).
- Targets are at least 24 × 24 px. The boxes and the open calendar hold at 200 % text, wrapping rather than clipping.
- Tests come first and are watched failing.
- Commit after every task. Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Decisions Made in Planning (confirm on review)

- **New manual shift times start empty** (`--:--`); the owner chose this on 2026-10-03. The first step of an empty shift start uses 09:00. The first step of an empty shift end uses the start time, or 09:00 when that is empty too. Saving with an empty start or end shows "Set a start time." / "Set an end time.". These are required-value checks, not parse messages.
- **The end date keeps its distance from the start date** until the owner picks the end date directly. For a new shift that distance is 0 days, which is the spec's "the end date follows the start date". An overnight template prefill keeps its +1 day.
- **A break with only one time set** is refused with "Set both break times, or neither.". A break with both times empty is ignored, as the spec says.
- **An agreement ending before it starts** is refused in the form with "The agreement must end on or after its start.". Picking makes that mistake one click away, and the domain only checks overlaps.
- **The optional check box is a separate control.** It is its own tab stop and its own checkbox semantics node, labelled with the box's label. The date box remains one button node, as the spec says.
- **Spin buttons are 17 × 12 px each**, stacked inside the 24 px box as in the era. The 24 × 24 target rule is met by the equivalent-control exception (WCAG 2.5.8): Up/Down on the focused box and the box's increase/decrease semantics actions do the same thing, and the box itself is at least 24 px tall.
- **The open calendar closes if its form scrolls.** Otherwise it would float away from its box.
- **The "Ends on (optional)" label becomes "Ends on"**, because the check box inside the box now says it is optional.

## Review Focus

1. **Scrolling the inspector with the calendar open:** the calendar closes and does not float detached from its box. Test in Task 3.
2. **Picking an agreement end before its start:** it is refused with a message, not saved. Test in Task 6.
3. **A break with only one time set:** it is refused with a message. It must not be dropped silently or crash on a null `!`. Test in Task 9.
4. **Holding a spin button while the form closes:** the repeat timer stops, and nothing calls `onChanged` after dispose. Test in Task 4.
5. **Revising a draft and saving untouched:** prefilled overnight dates and times with seconds come back exactly as given. Test in Task 9.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/time/local_date.dart` | Adds `daysInMonth`, `lastOfMonth`, `addMonthsClamped`. |
| `lib/shared/workbench/era_dates.dart` (new) | English month and weekday names; `eraBoxDate`, `spokenDate`, `eraMonthTitle`, `monthGridDays`. |
| `lib/shared/workbench/era_controls.dart` | `EraGlyphKind.stepBack` / `stepForward` (◂ ▸). |
| `lib/shared/workbench/era_month_calendar.dart` (new) | `EraMonthCalendar`. |
| `lib/shared/workbench/era_date_field.dart` (new) | `EraDateField`, `EraDropLayout`, the private check box and drop button. |
| `lib/shared/workbench/era_time_field.dart` (new) | `TimePart`, `stepTime`, `eraTimeText`, `EraTimeField`. |
| `test/support/era_pickers.dart` (new) | `pickDate`, `setTime`, `dateIn`, `timeIn`. |
| `lib/features/work/presentation/employment_agreement_forms.dart` | Agreement dates and night window picked; `parseClock` removed. |
| `lib/features/work/presentation/period_payslip_forms.dart` | Period and payslip dates picked; `today` inputs. |
| `lib/features/work/presentation/work_toolbar_controls.dart` | The Date range dialog picks; `PeriodPicker.today`. |
| `lib/features/work/presentation/work_register.dart` | Passes `today` to `PeriodPicker`. |
| `lib/features/work/presentation/shift_forms.dart` | Shift and break dates and times picked; `ShiftEditInspector.today`. |
| `lib/features/work/presentation/work_screen.dart` | Passes `today` to every form and the register. |
| `test/support/synthetic_shell.dart`, `test/goldens/*` | `agreement` screen; calendar goldens. |
| `DESIGN.md` | The new controls under Components. |

---

### Task 1: Calendar date maths

**Files:**
- Modify: `lib/core/time/local_date.dart`
- Create: `lib/shared/workbench/era_dates.dart`
- Test: `test/core/time/local_date_test.dart`, `test/shared/workbench/era_dates_test.dart` (new)

**Interfaces:**
- Produces: `int LocalDate.daysInMonth`, `LocalDate LocalDate.lastOfMonth`, `LocalDate LocalDate.addMonthsClamped(int months)`; `const List<String> eraMonthNames`, `const List<String> eraWeekdayInitials`, `String eraBoxDate(LocalDate)`, `String spokenDate(LocalDate)`, `String eraMonthTitle(LocalDate)`, `List<LocalDate> monthGridDays(LocalDate month)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/time/local_date_test.dart` inside `main()`:

```dart
  test('months clamp to the last day of a shorter month', () {
    expect(const LocalDate(2027, 1, 31).addMonthsClamped(1), const LocalDate(2027, 2, 28));
    expect(const LocalDate(2028, 1, 31).addMonthsClamped(1), const LocalDate(2028, 2, 29));
    expect(const LocalDate(2026, 10, 5).addMonthsClamped(-12), const LocalDate(2025, 10, 5));
    expect(const LocalDate(2026, 12, 15).addMonthsClamped(1), const LocalDate(2027, 1, 15));
  });

  test('a month knows its length and last day', () {
    expect(const LocalDate(2028, 2, 10).daysInMonth, 29);
    expect(const LocalDate(2027, 2, 10).lastOfMonth, const LocalDate(2027, 2, 28));
    expect(const LocalDate(2026, 10, 5).lastOfMonth, const LocalDate(2026, 10, 31));
  });
```

Create `test/shared/workbench/era_dates_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/workbench/era_dates.dart';

void main() {
  const monday = LocalDate(2026, 10, 5);

  test('the box shows the weekday then the ISO date', () {
    expect(eraBoxDate(monday), 'Mon 2026-10-05');
    expect(eraBoxDate(const LocalDate(2026, 10, 11)), 'Sun 2026-10-11');
  });

  test('a date is announced in words', () {
    expect(spokenDate(monday), 'Monday 5 October 2026');
  });

  test('the calendar title names the month and year', () {
    expect(eraMonthTitle(monday), 'October 2026');
  });

  test('the grid is six Monday-first weeks', () {
    final days = monthGridDays(monday);
    expect(days, hasLength(42));
    expect(days.first, const LocalDate(2026, 9, 28));
    expect(days.first.weekday, 1);
    expect(days.last, const LocalDate(2026, 11, 8));
  });

  test('a month starting on Monday starts the grid on its first', () {
    expect(monthGridDays(const LocalDate(2026, 6, 20)).first, const LocalDate(2026, 6, 1));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/core/time/local_date_test.dart test/shared/workbench/era_dates_test.dart`
Expected: FAIL with compile errors ("The method 'addMonthsClamped' isn't defined", "Target of URI doesn't exist: era_dates.dart").

- [ ] **Step 3: Implement**

In `lib/core/time/local_date.dart`, after `addMonths`:

```dart
  /// The number of days in this date's month.
  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// The last day of this date's month.
  LocalDate get lastOfMonth => LocalDate(year, month, daysInMonth);

  /// The same day [months] later, or earlier when negative, clamped to the
  /// target month's last day: 31 January plus one month is 28 or 29
  /// February.
  LocalDate addMonthsClamped(int months) {
    final target = addMonths(months);
    final last = target.daysInMonth;
    return LocalDate(target.year, target.month, day < last ? day : last);
  }
```

Create `lib/shared/workbench/era_dates.dart`:

```dart
import '../../core/time/local_date.dart';

/// English month names, January first.
const eraMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

/// The calendar's column heads, Monday first.
const eraWeekdayInitials = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdayLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday',
];

/// "Mon 2026-10-05": what a date box shows.
String eraBoxDate(LocalDate date) => '${_weekdayShort[date.weekday - 1]} $date';

/// "Monday 5 October 2026": how a date is announced.
String spokenDate(LocalDate date) =>
    '${_weekdayLong[date.weekday - 1]} ${date.day} '
    '${eraMonthNames[date.month - 1]} ${date.year}';

/// "October 2026": the month calendar's title.
String eraMonthTitle(LocalDate date) =>
    '${eraMonthNames[date.month - 1]} ${date.year}';

/// The 42 days a month calendar shows for [month]'s month: six
/// Monday-first weeks starting on or before the first.
List<LocalDate> monthGridDays(LocalDate month) {
  final first = month.firstOfMonth;
  final start = first.addDays(1 - first.weekday);
  return [for (var index = 0; index < 42; index++) start.addDays(index)];
}
```

(`dart format` will reflow the name lists; keep whatever it produces.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `$F/flutter test test/core/time/local_date_test.dart test/shared/workbench/era_dates_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze, format, full suite, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test
git add lib/core/time/local_date.dart lib/shared/workbench/era_dates.dart test/core/time/local_date_test.dart test/shared/workbench/era_dates_test.dart
git commit -m "feat: add calendar date maths for the era pickers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The month calendar

**Files:**
- Modify: `lib/shared/workbench/era_controls.dart` (two glyph kinds)
- Create: `lib/shared/workbench/era_month_calendar.dart`
- Test: `test/shared/workbench/era_month_calendar_test.dart` (new), `test/shared/workbench/era_controls_test.dart`

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces:
  - `EraGlyphKind.stepBack`, `EraGlyphKind.stepForward`.
  - `EraMonthCalendar({required LocalDate today, required ValueChanged<LocalDate> onPicked, LocalDate? selected, VoidCallback? onCancel, bool autofocus = false, Key? key})`.
  - Fixed keys, used by tests and the helpers: `ValueKey('era-calendar-title')` (the title `Text`), `ValueKey('era-calendar-previous')`, `ValueKey('era-calendar-next')`, `ValueKey('era-calendar-today')`, `ValueKey('era-day-<ISO date>')` on each day cell, and `ValueKey('era-today-ring')` on the decoration that circles today.

- [ ] **Step 1: Write the failing tests**

Add to `test/shared/workbench/era_controls_test.dart`, inside `main()`:

```dart
  testWidgets('step glyphs paint at their size and stay silent', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: EraGlyph(EraGlyphKind.stepBack, color: Color(0xff000000)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(EraGlyph)), const Size(9, 9));
    expect(tester.getSemantics(find.byType(EraGlyph)).label, isEmpty);
  });
```

Create `test/shared/workbench/era_month_calendar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/workbench/era_month_calendar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

const _today = LocalDate(2026, 10, 5);

Future<List<LocalDate>> _pump(
  WidgetTester tester, {
  LocalDate? selected = _today,
  VoidCallback? onCancel,
  double textScale = 1,
}) async {
  final picked = <LocalDate>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: LifeOSSkinScope(
          child: Scaffold(
            body: Center(
              child: EraMonthCalendar(
                selected: selected,
                today: _today,
                onPicked: picked.add,
                onCancel: onCancel,
                autofocus: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return picked;
}

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('era-calendar-title'))).data!;

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Finder _day(String iso) => find.byKey(ValueKey('era-day-$iso'));

void main() {
  testWidgets('weeks start on Monday under their initials', (tester) async {
    await _pump(tester);
    expect(_title(tester), 'October 2026');
    expect(_day('2026-09-28'), findsOneWidget);
    expect(_day('2026-09-27'), findsNothing);
    expect(
      tester.getCenter(_day('2026-09-28')).dx,
      closeTo(tester.getCenter(find.text('Mo')).dx, 0.5),
    );
  });

  testWidgets('today is circled and outside days are muted', (tester) async {
    await _pump(tester, selected: null);
    expect(find.byKey(const ValueKey('era-today-ring')), findsOneWidget);
    expect(
      find.descendant(
        of: _day('2026-10-05'),
        matching: find.byKey(const ValueKey('era-today-ring')),
      ),
      findsOneWidget,
    );
    Color? ink(String iso) => tester
        .widget<Text>(find.descendant(of: _day(iso), matching: find.byType(Text)))
        .style!
        .color;
    expect(ink('2026-09-30'), LifeOSTokens.millennium.muted);
    expect(ink('2026-10-14'), LifeOSTokens.millennium.ink);
  });

  testWidgets('arrows move a day or a week and Enter picks', (tester) async {
    final picked = await _pump(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.space);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked, const [
      LocalDate(2026, 10, 6),
      LocalDate(2026, 10, 13),
      LocalDate(2026, 10, 5),
    ]);
  });

  testWidgets('pages move a month, with Shift a year', (tester) async {
    final picked = await _pump(tester);
    await _press(tester, LogicalKeyboardKey.pageDown);
    expect(_title(tester), 'November 2026');
    await _press(tester, LogicalKeyboardKey.pageUp);
    await _press(tester, LogicalKeyboardKey.pageUp, shift: true);
    expect(_title(tester), 'October 2025');
    await _press(tester, LogicalKeyboardKey.pageDown, shift: true);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked.single, _today);
  });

  testWidgets('Home and End go to the ends of the month', (tester) async {
    final picked = await _pump(tester);
    await _press(tester, LogicalKeyboardKey.home);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.end);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked, const [LocalDate(2026, 10, 1), LocalDate(2026, 10, 31)]);
  });

  testWidgets('moving past the month pages across a year end', (tester) async {
    final picked = await _pump(tester, selected: const LocalDate(2026, 12, 28));
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_title(tester), 'January 2027');
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked.single, const LocalDate(2027, 1, 4));
  });

  testWidgets('31 January pages to the last day of February', (tester) async {
    final picked = await _pump(tester, selected: const LocalDate(2028, 1, 31));
    await _press(tester, LogicalKeyboardKey.pageDown);
    expect(_day('2028-02-29'), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.pageDown, shift: true);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked, const [LocalDate(2028, 2, 29), LocalDate(2029, 2, 28)]);
  });

  testWidgets('the header keys page and a click picks', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('era-calendar-next')));
    await tester.pump();
    expect(_title(tester), 'November 2026');
    await tester.tap(find.byKey(const ValueKey('era-calendar-previous')));
    await tester.tap(find.byKey(const ValueKey('era-calendar-previous')));
    await tester.pump();
    expect(_title(tester), 'September 2026');
    await tester.tap(_day('2026-09-17'));
    expect(picked.single, const LocalDate(2026, 9, 17));
  });

  testWidgets('the Today link picks today', (tester) async {
    final picked = await _pump(tester, selected: const LocalDate(2026, 3, 1));
    expect(find.text('Today: 2026-10-05'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('era-calendar-today')));
    expect(picked.single, _today);
  });

  testWidgets('as a drop-down, Esc cancels and Tab stays inside', (
    tester,
  ) async {
    var cancelled = 0;
    await _pump(tester, onCancel: () => cancelled++);
    final focus = tester.binding.focusManager.primaryFocus;
    await _press(tester, LogicalKeyboardKey.tab);
    expect(tester.binding.focusManager.primaryFocus, same(focus));
    await _press(tester, LogicalKeyboardKey.escape);
    expect(cancelled, 1);
  });

  testWidgets('days are labelled and the chosen day is selected', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      tester.getSemantics(_day('2026-10-05')),
      containsSemantics(
        label: 'Monday 5 October 2026',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_day('2026-10-06')),
      containsSemantics(label: 'Tuesday 6 October 2026', isSelected: false),
    );
  });

  testWidgets('day cells are at least 24 px and hold at 200 % text', (
    tester,
  ) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    final cell = tester.getSize(_day('2026-10-05'));
    expect(cell.width, greaterThanOrEqualTo(24));
    expect(cell.height, greaterThanOrEqualTo(24));
    final calendar = tester.getRect(find.byType(EraMonthCalendar));
    expect(calendar.left, greaterThanOrEqualTo(0));
    expect(calendar.top, greaterThanOrEqualTo(0));
    expect(calendar.right, lessThanOrEqualTo(800));
    expect(calendar.bottom, lessThanOrEqualTo(600));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/shared/workbench/era_month_calendar_test.dart test/shared/workbench/era_controls_test.dart`
Expected: FAIL with compile errors (`stepBack` and `era_month_calendar.dart` missing).

- [ ] **Step 3: Add the step glyphs**

In `lib/shared/workbench/era_controls.dart`, extend the enum:

```dart
enum EraGlyphKind {
  dropDown,
  sortUp,
  sortDown,
  collapse,
  expand,
  tick,
  stepBack,
  stepForward,
}
```

Update the `EraGlyph` doc comment to "drop arrow, sort arrow, step arrow, collapse chevrons or a tick". In `_GlyphPainter.paint`, next to `triangle`, add:

```dart
    Path sideways({required bool back}) => Path()
      ..moveTo(w * (back ? 0.7 : 0.3), h * 0.1)
      ..lineTo(w * (back ? 0.7 : 0.3), h * 0.9)
      ..lineTo(w * (back ? 0.3 : 0.7), h * 0.5)
      ..close();
```

and a switch case:

```dart
      case EraGlyphKind.stepBack || EraGlyphKind.stepForward:
        canvas.drawPath(sideways(back: kind == EraGlyphKind.stepBack), fill);
```

- [ ] **Step 4: Write the calendar**

Create `lib/shared/workbench/era_month_calendar.dart`:

```dart
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
                            for (final day in days.sublist(week * 7, week * 7 + 7))
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
    final face = skin.painters.key(skin.tokens, KeyKind.small, const KeyState());
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$F/flutter test test/shared/workbench/era_month_calendar_test.dart test/shared/workbench/era_controls_test.dart`
Expected: PASS. If the 200 % test reports an overflow, give the title `Text` `softWrap: true` (the default) inside the `Expanded`. Do not clip. Check that the header key stays 24 × 24.

- [ ] **Step 6: Analyze, format, full suite, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test
git add lib/shared/workbench/era_controls.dart lib/shared/workbench/era_month_calendar.dart test/shared/workbench/era_controls_test.dart test/shared/workbench/era_month_calendar_test.dart
git commit -m "feat: add the era month calendar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The date box

**Files:**
- Create: `lib/shared/workbench/era_date_field.dart`
- Test: `test/shared/workbench/era_date_field_test.dart` (new)

**Interfaces:**
- Consumes: `EraMonthCalendar` (Task 2); `eraBoxDate`, `spokenDate` (Task 1).
- Produces:
  - `EraDateField({required String label, required LocalDate? value, required ValueChanged<LocalDate?> onChanged, required LocalDate today, bool optional = false, String? error, Key? fieldKey, Key? key})`. `value` may be null only when `optional`.
  - `EraDropLayout(Rect anchor)`, a `SingleChildLayoutDelegate`.
  - Fixed keys inside the box: `ValueKey('era-date-check')` (the optional check box) and `ValueKey('era-date-drop')` (the drop button). `fieldKey` sits on the white box.
  - The box's focus node has `debugLabel: 'EraDateField'`.

- [ ] **Step 1: Write the failing tests**

Create `test/shared/workbench/era_date_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/workbench/era_date_field.dart';
import 'package:lifeos/shared/workbench/era_month_calendar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

const _today = LocalDate(2026, 10, 5);
const _box = ValueKey('starts-on');

final class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.optional, this.child});

  final LocalDate? initial;
  final bool optional;

  /// Wraps the field, for example in a list that scrolls.
  final Widget Function(Widget field)? child;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  late LocalDate? value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final field = SizedBox(
      width: 240,
      child: EraDateField(
        label: widget.optional ? 'Ends on' : 'Starts on',
        value: value,
        today: _today,
        optional: widget.optional,
        fieldKey: _box,
        onChanged: (picked) => setState(() => value = picked),
      ),
    );
    return widget.child?.call(field) ?? field;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  LocalDate? value = _today,
  bool optional = false,
  Alignment alignment = Alignment.topCenter,
  double textScale = 1,
  Widget Function(Widget field)? wrap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: LifeOSSkinScope(
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: alignment,
                child: _Host(initial: value, optional: optional, child: wrap),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

LocalDate? _value(WidgetTester tester) =>
    tester.widget<EraDateField>(find.byType(EraDateField)).value;

Finder get _calendar => find.byType(EraMonthCalendar);

void main() {
  testWidgets('the box shows the weekday and ISO date', (tester) async {
    await _pump(tester);
    expect(find.text('Mon 2026-10-05'), findsOneWidget);
    expect(find.text('Starts on'), findsOneWidget);
    expect(tester.getSize(find.byKey(_box)).height, greaterThanOrEqualTo(24));
  });

  testWidgets('the box is one button named by label and date', (tester) async {
    await _pump(tester);
    expect(
      tester.getSemantics(find.byKey(_box)),
      containsSemantics(
        label: 'Starts on, Monday 5 October 2026',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
      ),
    );
  });

  testWidgets('a click opens the calendar below the box', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    expect(
      tester.getRect(_calendar).top,
      greaterThanOrEqualTo(tester.getRect(find.byKey(_box)).bottom - 0.5),
    );
  });

  testWidgets('Space, Enter and Alt+Down open; Esc closes', (tester) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    for (final open in [LogicalKeyboardKey.space, LogicalKeyboardKey.enter]) {
      await tester.sendKeyEvent(open);
      await tester.pumpAndSettle();
      expect(_calendar, findsOneWidget, reason: '$open opens');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_calendar, findsNothing);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
  });

  testWidgets('Enter picks the highlighted day and focus returns', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(_value(tester), const LocalDate(2026, 10, 6));
    expect(find.text('Tue 2026-10-06'), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateField',
    );
  });

  testWidgets('Esc and a click outside close without a change', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_value(tester), _today);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateField',
    );

    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(_value(tester), _today);
  });

  testWidgets('the calendar opens above a box near the bottom', (
    tester,
  ) async {
    await _pump(tester, alignment: Alignment.bottomCenter);
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(_calendar).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(_box)).top + 0.5),
    );
  });

  testWidgets('an optional box unticked is none, with the arrow disabled', (
    tester,
  ) async {
    await _pump(tester, value: null, optional: true);
    expect(
      tester.getSemantics(find.byKey(_box)),
      containsSemantics(label: 'Ends on, none', isEnabled: false),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('era-date-check'))),
      containsSemantics(label: 'Ends on', hasCheckedState: true, isChecked: false),
    );
    await tester.tap(find.byKey(const ValueKey('era-date-drop')));
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);

    await tester.tap(find.byKey(const ValueKey('era-date-check')));
    await tester.pump();
    expect(_value(tester), _today);
  });

  testWidgets('ticking again restores the last date shown', (tester) async {
    await _pump(tester, value: const LocalDate(2026, 12, 31), optional: true);
    await tester.tap(find.byKey(const ValueKey('era-date-check')));
    await tester.pump();
    expect(_value(tester), isNull);
    expect(find.text('Thu 2026-12-31'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('era-date-check')));
    await tester.pump();
    expect(_value(tester), const LocalDate(2026, 12, 31));
  });

  testWidgets('scrolling the form closes the calendar', (tester) async {
    await _pump(
      tester,
      wrap: (field) => SizedBox(
        height: 500,
        child: ListView(
          children: [field, const SizedBox(height: 2000)],
        ),
      ),
    );
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    // Scroll without a pointer: a press outside would close it anyway.
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(60);
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('box and calendar hold at 200 % text', (tester) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final calendar = tester.getRect(_calendar);
    expect(calendar.left, greaterThanOrEqualTo(0));
    expect(calendar.right, lessThanOrEqualTo(800));
    expect(calendar.bottom, lessThanOrEqualTo(600));
  });

  test('the drop layout prefers below, then above, and stays inside', () {
    const window = Size(960, 760);
    const calendar = Size(220, 250);
    Offset place(Rect anchor) =>
        EraDropLayout(anchor).getPositionForChild(window, calendar);
    expect(place(const Rect.fromLTWH(10, 100, 200, 24)), const Offset(10, 124));
    expect(place(const Rect.fromLTWH(10, 700, 200, 24)), const Offset(10, 450));
    expect(place(const Rect.fromLTWH(900, 100, 50, 24)).dx, 960 - 220);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/shared/workbench/era_date_field_test.dart`
Expected: FAIL with a compile error ("Target of URI doesn't exist: era_date_field.dart").

- [ ] **Step 3: Write the date box**

Create `lib/shared/workbench/era_date_field.dart`:

```dart
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
  final _portal = OverlayPortalController();
  final _anchor = GlobalKey();
  late LocalDate? _lastShown = widget.value;
  ScrollPosition? _scroll;
  bool _focused = false;

  bool get _enabled => widget.value != null;

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
    super.dispose();
  }

  void _open() {
    if (!_enabled || _portal.isShowing) return;
    setState(_portal.show);
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

  Widget _calendar(BuildContext context) {
    final anchor = _anchor.currentContext!.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final rect =
        anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size;
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: EraDropLayout(rect),
        child: TapRegion(
          groupId: this,
          onTapOutside: (_) => _close(),
          child: EraMonthCalendar(
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
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: _calendar,
            child: KeyedSubtree(
              key: _anchor,
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
                        child: MergeSemantics(
                          child: Focus(
                            focusNode: _box,
                            canRequestFocus: _enabled,
                            onKeyEvent: _onKey,
                            onFocusChange: (focused) =>
                                setState(() => _focused = focused),
                            child: Semantics(
                              button: true,
                              enabled: _enabled,
                              label: widget.error == null
                                  ? name
                                  : '$name, ${widget.error}',
                              onTap: _enabled ? _open : null,
                              excludeSemantics: true,
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
                                            horizontal: 3,
                                            vertical: 2,
                                          ),
                                          child: Container(
                                            color: highlighted
                                                ? t.selWash
                                                : null,
                                            padding:
                                                const EdgeInsets.symmetric(
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
    final left = anchor.left.clamp(
      0.0,
      math.max(0.0, size.width - childSize.width),
    );
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
```

The drop-layout test expects `Offset(10, 450)` for an anchor at y 700–724 in a 760 px window with a 250 px calendar: there is no room below (36 px) and room above (700 px), so top = 700 − 250 = 450.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `$F/flutter test test/shared/workbench/era_date_field_test.dart`
Expected: PASS.

If the "Space, Enter and Alt+Down" test fails because Tab lands elsewhere, check that `Focus.canRequestFocus` is true for a ticked box and that no other focusable widget comes first in the harness. If the scroll test fails, check that `didChangeDependencies` found the `ListView`'s position. The field must sit inside the list's subtree, as the harness's `wrap` does.

- [ ] **Step 5: Analyze, format, full suite, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test
git add lib/shared/workbench/era_date_field.dart test/shared/workbench/era_date_field_test.dart
git commit -m "feat: add the era date box with a drop-down calendar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The time box

**Files:**
- Create: `lib/shared/workbench/era_time_field.dart`
- Test: `test/shared/workbench/era_time_field_test.dart` (new)

**Interfaces:**
- Consumes: `EraGlyphKind.sortUp` / `sortDown` (existing).
- Produces:
  - `enum TimePart { hour, minute, second }`.
  - `LocalTime stepTime(LocalTime time, TimePart part, int delta)`.
  - `String eraTimeText(LocalTime time, {required bool withSeconds})`.
  - `EraTimeField({required LocalTime? value, required ValueChanged<LocalTime> onChanged, String? label, String? semanticLabel, LocalTime emptyStart = const LocalTime(0, 0), bool enabled = true, String? error, Key? fieldKey, Key? key})`. At least one of `label` and `semanticLabel` is required.
  - Fixed keys: `ValueKey('era-time-hour')`, `ValueKey('era-time-minute')`, `ValueKey('era-time-second')` on the parts; `ValueKey('era-time-up')` and `ValueKey('era-time-down')` on the spin buttons. The focus node has `debugLabel: 'EraTimeField'`.

- [ ] **Step 1: Write the failing tests**

Create `test/shared/workbench/era_time_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/shared/workbench/era_time_field.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

const _box = ValueKey('start-time');

final class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.emptyStart, required this.enabled});

  final LocalTime? initial;
  final LocalTime emptyStart;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  late LocalTime? value = widget.initial;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: EraTimeField(
      label: 'Start time',
      value: value,
      emptyStart: widget.emptyStart,
      enabled: widget.enabled,
      fieldKey: _box,
      onChanged: (next) => setState(() => value = next),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  LocalTime? value = const LocalTime(7, 0),
  LocalTime emptyStart = const LocalTime(12, 30),
  bool enabled = true,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: LifeOSSkinScope(
          child: Scaffold(
            body: Center(
              child: _Host(initial: value, emptyStart: emptyStart, enabled: enabled),
            ),
          ),
        ),
      ),
    ),
  );
}

LocalTime? _value(WidgetTester tester) =>
    tester.widget<EraTimeField>(find.byType(EraTimeField)).value;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }
}

Future<void> _select(WidgetTester tester, String part) async {
  await tester.tap(find.byKey(ValueKey('era-time-$part')));
  await tester.pump();
}

void main() {
  test('steps wrap within their part and never carry', () {
    const late = LocalTime(23, 59);
    expect(stepTime(late, TimePart.hour, 1), const LocalTime(0, 59));
    expect(stepTime(late, TimePart.minute, 1), const LocalTime(23, 0));
    expect(stepTime(const LocalTime(0, 0), TimePart.hour, -1), const LocalTime(23, 0));
    expect(stepTime(const LocalTime(0, 5), TimePart.minute, -10), const LocalTime(0, 55));
    expect(stepTime(const LocalTime(1, 2, 59), TimePart.second, 1), const LocalTime(1, 2, 0));
  });

  testWidgets('the box shows hours and minutes and a spin pair', (tester) async {
    await _pump(tester);
    expect(find.text('07'), findsOneWidget);
    expect(find.text('00'), findsOneWidget);
    expect(find.byKey(const ValueKey('era-time-second')), findsNothing);
    expect(find.byKey(const ValueKey('era-time-up')), findsOneWidget);
    expect(tester.getSize(find.byKey(_box)).height, greaterThanOrEqualTo(24));
  });

  testWidgets('the box is one node with increase and decrease', (tester) async {
    await _pump(tester);
    expect(
      tester.getSemantics(find.byKey(_box)),
      containsSemantics(
        label: 'Start time, 07:00',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
  });

  testWidgets('focus selects the hours; arrows step them', (tester) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(8, 0));
    await _press(tester, LogicalKeyboardKey.arrowDown, 2);
    expect(_value(tester), const LocalTime(6, 0));
  });

  testWidgets('a click selects a part; left and right switch parts', (
    tester,
  ) async {
    await _pump(tester);
    await _select(tester, 'minute');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(7, 1));
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(8, 1));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_value(tester), const LocalTime(8, 0));
  });

  testWidgets('PageUp and PageDown step by ten and wrap', (tester) async {
    await _pump(tester, value: const LocalTime(17, 5));
    await _select(tester, 'hour');
    await _press(tester, LogicalKeyboardKey.pageUp);
    expect(_value(tester), const LocalTime(3, 5));
    await _select(tester, 'minute');
    await _press(tester, LogicalKeyboardKey.pageDown);
    expect(_value(tester), const LocalTime(3, 55));
  });

  testWidgets('23 steps to 00 without changing the minutes', (tester) async {
    await _pump(tester, value: const LocalTime(23, 59));
    await _select(tester, 'hour');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(0, 59));
    await _select(tester, 'minute');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(0, 0));
  });

  testWidgets('the spin buttons step the selected part', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('era-time-up')));
    await tester.pump();
    expect(_value(tester), const LocalTime(8, 0));
    await _select(tester, 'minute');
    await tester.tap(find.byKey(const ValueKey('era-time-down')));
    await tester.pump();
    expect(_value(tester), const LocalTime(8, 59));
  });

  testWidgets('holding a spin button repeats after 400 ms, then every 60 ms', (
    tester,
  ) async {
    await _pump(tester);
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('era-time-up'))),
    );
    await tester.pump();
    expect(_value(tester), const LocalTime(8, 0));
    await tester.pump(const Duration(milliseconds: 399));
    expect(_value(tester), const LocalTime(8, 0));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_value(tester), const LocalTime(9, 0));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_value(tester), const LocalTime(10, 0));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_value(tester), const LocalTime(11, 0));
    await hold.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_value(tester), const LocalTime(11, 0));
  });

  testWidgets('a held spin button stops when the box goes away', (
    tester,
  ) async {
    await _pump(tester);
    await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('era-time-up'))),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seconds show only for a value that has them', (tester) async {
    await _pump(tester, value: const LocalTime(7, 0, 13));
    expect(find.text('13'), findsOneWidget);
    await _select(tester, 'second');
    await _press(tester, LogicalKeyboardKey.arrowUp, 47);
    expect(_value(tester), const LocalTime(7, 0, 0));
    expect(find.byKey(const ValueKey('era-time-second')), findsOneWidget);
  });

  testWidgets('a value without seconds never gains them', (tester) async {
    await _pump(tester);
    await _select(tester, 'minute');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(7, 1));
    expect(find.byKey(const ValueKey('era-time-second')), findsNothing);
  });

  testWidgets('an empty box shows dashes; its first step is emptyStart', (
    tester,
  ) async {
    await _pump(tester, value: null);
    expect(find.text('--'), findsNWidgets(2));
    expect(
      tester.getSemantics(find.byKey(_box)),
      containsSemantics(label: 'Start time, not set'),
    );
    await _select(tester, 'hour');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(12, 30));
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(13, 30));
  });

  testWidgets('a disabled box does not step', (tester) async {
    await _pump(tester, enabled: false);
    await tester.tap(find.byKey(const ValueKey('era-time-up')));
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(7, 0));
  });

  testWidgets('the box holds at 200 % text', (tester) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('07'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/shared/workbench/era_time_field_test.dart`
Expected: FAIL with a compile error ("Target of URI doesn't exist: era_time_field.dart").

- [ ] **Step 3: Write the time box**

Create `lib/shared/workbench/era_time_field.dart`:

```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/time/local_time.dart';
import 'era_controls.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// The parts of a time box, left to right.
enum TimePart { hour, minute, second }

/// [time] with [part] moved by [delta], wrapping within the part without
/// carrying: 23 plus one hour is 00 and the minutes stay.
LocalTime stepTime(LocalTime time, TimePart part, int delta) => switch (part) {
  TimePart.hour => LocalTime((time.hour + delta) % 24, time.minute, time.second),
  TimePart.minute => LocalTime(time.hour, (time.minute + delta) % 60, time.second),
  TimePart.second => LocalTime(time.hour, time.minute, (time.second + delta) % 60),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label case final label?) ...[
          ExcludeSemantics(
            child: Text(label, style: skin.typography.body.copyWith(color: t.ink)),
          ),
          const SizedBox(height: 2),
        ],
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
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                part(TimePart.hour),
                                colon,
                                part(TimePart.minute),
                                if (_withSeconds) ...[colon, part(TimePart.second)],
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `$F/flutter test test/shared/workbench/era_time_field_test.dart`
Expected: PASS.

If "focus selects the hours" fails because a click-chosen part leaks into the next Tab focus, check that `_pointerChosePart` is set only when the box did not already have focus (`_focusKeepingPart`).

- [ ] **Step 5: Analyze, format, full suite, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test
git add lib/shared/workbench/era_time_field.dart test/shared/workbench/era_time_field_test.dart
git commit -m "feat: add the era time box with spin buttons

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Test helpers that drive the real controls

**Files:**
- Create: `test/support/era_pickers.dart`
- Test: `test/support/era_pickers_test.dart` (new)

**Interfaces:**
- Consumes: `EraDateField`, `EraTimeField`, the fixed keys from Tasks 2–4, and `eraMonthNames`.
- Produces, all addressed by the field's key string:
  - `Future<void> pickDate(WidgetTester tester, String key, LocalDate date)`
  - `Future<void> setTime(WidgetTester tester, String key, LocalTime time)`
  - `LocalDate? dateIn(WidgetTester tester, String key)`
  - `LocalTime? timeIn(WidgetTester tester, String key)`

- [ ] **Step 1: Write the failing test**

Create `test/support/era_pickers_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/shared/workbench/era_date_field.dart';
import 'package:lifeos/shared/workbench/era_time_field.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

import 'era_pickers.dart';

final class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

final class _FormState extends State<_Form> {
  LocalDate? start = const LocalDate(2026, 10, 5);
  LocalDate? end;
  LocalTime? at;
  LocalTime? precise = const LocalTime(8, 0, 13);

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      EraDateField(
        label: 'Start',
        fieldKey: const ValueKey('start'),
        value: start,
        today: const LocalDate(2026, 10, 5),
        onChanged: (value) => setState(() => start = value),
      ),
      EraDateField(
        label: 'End',
        optional: true,
        fieldKey: const ValueKey('end'),
        value: end,
        today: const LocalDate(2026, 10, 5),
        onChanged: (value) => setState(() => end = value),
      ),
      EraTimeField(
        label: 'At',
        fieldKey: const ValueKey('at'),
        value: at,
        emptyStart: const LocalTime(9, 0),
        onChanged: (value) => setState(() => at = value),
      ),
      EraTimeField(
        label: 'Precise',
        fieldKey: const ValueKey('precise'),
        value: precise,
        onChanged: (value) => setState(() => precise = value),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    theme: buildLifeOSTheme(),
    home: const LifeOSSkinScope(
      child: Scaffold(body: SizedBox(width: 320, child: _Form())),
    ),
  ),
);

void main() {
  testWidgets('pickDate pages back across a year and picks the day', (
    tester,
  ) async {
    await _pump(tester);
    await pickDate(tester, 'start', const LocalDate(2025, 11, 30));
    expect(dateIn(tester, 'start'), const LocalDate(2025, 11, 30));
  });

  testWidgets('pickDate ticks an optional box first', (tester) async {
    await _pump(tester);
    expect(dateIn(tester, 'end'), isNull);
    await pickDate(tester, 'end', const LocalDate(2027, 2, 28));
    expect(dateIn(tester, 'end'), const LocalDate(2027, 2, 28));
  });

  testWidgets('setTime fills an empty box and wraps backwards', (
    tester,
  ) async {
    await _pump(tester);
    await setTime(tester, 'at', const LocalTime(6, 45));
    expect(timeIn(tester, 'at'), const LocalTime(6, 45));
    await setTime(tester, 'at', const LocalTime(22, 5));
    expect(timeIn(tester, 'at'), const LocalTime(22, 5));
  });

  testWidgets('setTime steps the seconds of a box that shows them', (
    tester,
  ) async {
    await _pump(tester);
    await setTime(tester, 'precise', const LocalTime(8, 30, 0));
    expect(timeIn(tester, 'precise'), const LocalTime(8, 30, 0));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$F/flutter test test/support/era_pickers_test.dart`
Expected: FAIL with a compile error ("Target of URI doesn't exist: era_pickers.dart").

- [ ] **Step 3: Write the helpers**

Create `test/support/era_pickers.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/shared/workbench/era_date_field.dart';
import 'package:lifeos/shared/workbench/era_dates.dart';
import 'package:lifeos/shared/workbench/era_time_field.dart';

/// Drive the era date and time boxes the way the owner does. Dates and
/// times are never typed (era pickers spec 5).

Finder _dateField(String key) => find.ancestor(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EraDateField),
);

Finder _timeField(String key) => find.ancestor(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EraTimeField),
);

/// The date in the box keyed [key]; null when an optional box is clear.
LocalDate? dateIn(WidgetTester tester, String key) =>
    tester.widget<EraDateField>(_dateField(key)).value;

/// The time in the box keyed [key]; null when it shows "--:--".
LocalTime? timeIn(WidgetTester tester, String key) =>
    tester.widget<EraTimeField>(_timeField(key)).value;

/// Ticks an optional box when clear, opens its calendar, pages to [date]'s
/// month with ◂ or ▸, and clicks the day.
Future<void> pickDate(WidgetTester tester, String key, LocalDate date) async {
  final box = find.byKey(ValueKey(key));
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  if (dateIn(tester, key) == null) {
    await tester.tap(
      find.descendant(
        of: _dateField(key),
        matching: find.byKey(const ValueKey('era-date-check')),
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(box);
  await tester.pumpAndSettle();
  final title = tester
      .widget<Text>(find.byKey(const ValueKey('era-calendar-title')))
      .data!;
  final [monthName, yearText] = title.split(' ');
  final months =
      (date.year - int.parse(yearText)) * 12 +
      date.month -
      (eraMonthNames.indexOf(monthName) + 1);
  final page = find.byKey(
    ValueKey(months < 0 ? 'era-calendar-previous' : 'era-calendar-next'),
  );
  for (var index = 0; index < months.abs(); index++) {
    await tester.tap(page);
    await tester.pump();
  }
  await tester.tap(find.byKey(ValueKey('era-day-$date')));
  await tester.pumpAndSettle();
}

/// Selects each part of the box keyed [key] and steps it up to [time]'s
/// value: PageUp for tens, Up for ones. An empty box takes its first step
/// before counting.
Future<void> setTime(WidgetTester tester, String key, LocalTime time) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  Future<void> select(String part) async {
    await tester.tap(
      find.descendant(
        of: _timeField(key),
        matching: find.byKey(ValueKey('era-time-$part')),
      ),
    );
    await tester.pump();
  }

  Future<void> press(LogicalKeyboardKey pressed, int times) async {
    for (var index = 0; index < times; index++) {
      await tester.sendKeyEvent(pressed);
      await tester.pump();
    }
  }

  Future<void> move(String part, int from, int to, int modulo) async {
    await select(part);
    final ahead = (to - from) % modulo;
    await press(LogicalKeyboardKey.pageUp, ahead ~/ 10);
    await press(LogicalKeyboardKey.arrowUp, ahead % 10);
  }

  await select('hour');
  if (timeIn(tester, key) == null) {
    await press(LogicalKeyboardKey.arrowUp, 1);
  }
  final now = timeIn(tester, key)!;
  await move('hour', now.hour, time.hour, 24);
  await move('minute', now.minute, time.minute, 60);
  if (time.second != 0 || now.second != 0) {
    expect(
      find.descendant(
        of: _timeField(key),
        matching: find.byKey(const ValueKey('era-time-second')),
      ),
      findsOneWidget,
      reason: 'the box keyed $key shows no seconds',
    );
    await move('second', now.second, time.second, 60);
  }
  await tester.pumpAndSettle();
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$F/flutter test test/support/era_pickers_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze, format, full suite, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test
git add test/support/era_pickers.dart test/support/era_pickers_test.dart
git commit -m "test: add helpers that pick dates and set times

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The agreement form picks its dates and night window

**Files:**
- Modify: `lib/features/work/presentation/employment_agreement_forms.dart` (state at 179–260, `_submit` at 267–360, the Rate group at 386–402, the Night group at 466–506, and `parseClock` at 1014–1022)
- Test: `test/features/work/presentation/employment_agreement_forms_test.dart`; migrate `test/integration/quick_add_flow_test.dart:155-158` and `test/integration/work_core_flow_test.dart:312-315`

**Interfaces:**
- Consumes: `EraDateField`, `EraTimeField` (Tasks 3–4); `pickDate`, `setTime`, `dateIn`, `timeIn` (Task 5).
- Produces: `const agreementRangeMessage = 'The agreement must end on or after its start.'` (public, next to `nightWindowMessage`). `parseClock` is removed; `formatClock` stays because `work_sheets.dart` uses it.

- [ ] **Step 1: Write the failing tests**

In `employment_agreement_forms_test.dart`, add `import '../../../support/era_pickers.dart';` and `import 'package:lifeos/core/time/local_time.dart';`. Then add these to the agreement-form group. `pumpAgreementForm` already passes `today: LocalDate(2026, 10, 1)`.

```dart
    testWidgets('dates and the night window are picked with defaults', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      expect(dateIn(tester, 'agreement-effective-start'), const LocalDate(2026, 10, 1));
      expect(dateIn(tester, 'agreement-effective-end'), isNull);
      expect(timeIn(tester, 'agreement-night-start'), const LocalTime(22, 0));
      expect(timeIn(tester, 'agreement-night-end'), const LocalTime(6, 0));

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await pickDate(tester, 'agreement-effective-end', const LocalDate(2026, 12, 31));
      await setTime(tester, 'agreement-night-start', const LocalTime(21, 30));
      await submitAgreement(tester);

      expect(submitted!.terms.effectiveStart, const LocalDate(2026, 10, 1));
      expect(submitted!.terms.effectiveEnd, const LocalDate(2026, 12, 31));
      expect(submitted!.terms.nightStartMinute, 21 * 60 + 30);
      expect(submitted!.terms.nightEndMinute, 6 * 60);
    });

    testWidgets('an end before the start is refused', (tester) async {
      var submitted = false;
      await pumpAgreementForm(tester, onSubmit: (_) => submitted = true);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await pickDate(tester, 'agreement-effective-end', const LocalDate(2026, 9, 30));
      await submitAgreement(tester);

      expect(submitted, isFalse);
      expect(find.text(agreementRangeMessage), findsOneWidget);
    });

    testWidgets('the night boxes are disabled with night pay off', (
      tester,
    ) async {
      await pumpAgreementForm(tester);
      final night = find.byKey(const ValueKey('agreement-night-enabled'));
      await tester.ensureVisible(night);
      await tester.pumpAndSettle();
      await tester.tap(night);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('agreement-night-start'))),
        containsSemantics(label: 'Night pay starts, 22:00', isEnabled: false),
      );
    });
```

Replace the body line `await enter(tester, 'agreement-night-start', '06:00');` in 'night start equal to its end is refused' with:

```dart
      await setTime(tester, 'agreement-night-start', const LocalTime(6, 0));
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/features/work/presentation/employment_agreement_forms_test.dart`
Expected: FAIL. `dateIn` finds no `EraDateField` ("Bad state: No element"), and `agreementRangeMessage` is undefined.

- [ ] **Step 3: Implement**

In `employment_agreement_forms.dart`:

1. Imports: add `'../../../core/time/local_time.dart'`, `'../../../shared/workbench/era_date_field.dart'` and `'../../../shared/workbench/era_time_field.dart'`.
2. Next to `nightWindowMessage`, add:

```dart
const agreementRangeMessage = 'The agreement must end on or after its start.';
```

3. In `_AgreementFormState`, replace the `_effectiveStart`, `_effectiveEnd`, `_nightStart` and `_nightEnd` controllers with values:

```dart
  late final LocalDate _today = widget.today ?? _localToday();
  late LocalDate _effectiveStart = _initial?.effectiveStart ?? _today;
  late LocalDate? _effectiveEnd = _initial?.effectiveEnd;
  late LocalTime _nightStart = _clockTime(
    _initial?.nightStartMinute ?? AgreementDefaults.nightStartMinute,
  );
  late LocalTime _nightEnd = _clockTime(
    _initial?.nightEndMinute ?? AgreementDefaults.nightEndMinute,
  );
```

   Remove those four from the `dispose` list.
4. In `_submit`, replace the parsing of the four values and their error entries:

```dart
    final start = _effectiveStart;
    final end = _effectiveEnd;
    final nightStart = _minuteOfDay(_nightStart);
    final nightEnd = _minuteOfDay(_nightEnd);
    // … rate, threshold, overtime, night, holiday, vacationPay, sickPay,
    // sickDays parse as before …
    final errors = <String, String>{
      if (end != null && end.compareTo(start) < 0)
        'effectiveEnd': agreementRangeMessage,
      if (rate == null || rate <= 0) 'hourlyRate': 'Enter a rate above zero.',
      if (threshold == null) 'overtimeHours': 'Enter hours above zero.',
      if (overtime == null) 'overtimeMultiplier': multiplierMessage,
      if (nightStart == nightEnd) 'nightEnd': nightWindowMessage,
      if (night == null) 'nightMultiplier': multiplierMessage,
      if (holiday == null) 'holidayMultiplier': multiplierMessage,
      if (vacationPay == null) 'vacationPercent': percentMessage,
      if (sickPay == null) 'sickPercent': percentMessage,
      if (sickDays == null || sickDays < 0 || sickDays > 30)
        'sickDays': sickDaysMessage,
    };
```

   In `AgreementTerms(...)`, use `effectiveStart: start`, `nightStartMinute: nightStart` and `nightEndMinute: nightEnd`. Drop the `!` on those three.
5. In the Rate group, replace the two date `_Field`s with:

```dart
                EraDateField(
                  label: 'Starts on',
                  fieldKey: const ValueKey('agreement-effective-start'),
                  value: _effectiveStart,
                  today: _today,
                  onChanged: (value) =>
                      setState(() => _effectiveStart = value!),
                ),
                const SizedBox(height: 12),
                EraDateField(
                  label: 'Ends on',
                  optional: true,
                  fieldKey: const ValueKey('agreement-effective-end'),
                  value: _effectiveEnd,
                  today: _today,
                  error: _errors['effectiveEnd'],
                  onChanged: (value) => setState(() => _effectiveEnd = value),
                ),
```

6. In the Night sentence, replace the two time `_Short`s with `_ClockBox`es:

```dart
                    _ClockBox(
                      fieldKey: const ValueKey('agreement-night-start'),
                      semanticLabel: 'Night pay starts',
                      value: _nightStart,
                      enabled: _nightEnabled,
                      error: _errors['nightStart'],
                      onChanged: (value) => setState(() => _nightStart = value),
                    ),
                    const Text('to'),
                    _ClockBox(
                      fieldKey: const ValueKey('agreement-night-end'),
                      semanticLabel: 'Night pay ends',
                      value: _nightEnd,
                      enabled: _nightEnabled,
                      error: _errors['nightEnd'],
                      onChanged: (value) => setState(() => _nightEnd = value),
                    ),
```

   Add the widget next to `_Short`:

```dart
/// A time box set in a sentence, widening to fit its error as `_Short`
/// does.
final class _ClockBox extends StatelessWidget {
  const _ClockBox({
    required this.fieldKey,
    required this.semanticLabel,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.error,
  });

  final Key fieldKey;
  final String semanticLabel;
  final LocalTime value;
  final bool enabled;
  final ValueChanged<LocalTime> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: error == null ? 88 : 240,
    child: EraTimeField(
      fieldKey: fieldKey,
      semanticLabel: semanticLabel,
      value: value,
      enabled: enabled,
      error: error,
      onChanged: onChanged,
    ),
  );
}
```

7. Delete `parseClock` (it now has no callers), and add next to `formatClock`:

```dart
LocalTime _clockTime(int minuteOfDay) =>
    LocalTime(minuteOfDay ~/ 60, minuteOfDay % 60);

int _minuteOfDay(LocalTime time) => time.hour * 60 + time.minute;
```

- [ ] **Step 4: Migrate the integration lines for this form**

In `test/integration/quick_add_flow_test.dart:155-158` and `test/integration/work_core_flow_test.dart:312-315`, replace each `tester.enterText(find.byKey(const ValueKey('agreement-effective-start')), '<ISO>')` with:

```dart
    await pickDate(tester, 'agreement-effective-start', LocalDate.parse('<ISO>'));
```

Add `import '../support/era_pickers.dart';` to both files, and the `local_date.dart` import where it is missing.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$F/flutter test test/features/work/presentation/employment_agreement_forms_test.dart test/integration/quick_add_flow_test.dart test/integration/work_core_flow_test.dart`
Expected: the agreement tests PASS. `work_core_flow_test` may still fail on period, payslip or shift lines; Tasks 7 and 9 migrate those. Confirm that any failure is "enterText … EditableText" on a key those tasks own, not an agreement key.

- [ ] **Step 6: Analyze, format, commit**

The full suite stays red only on the period, payslip, range and shift `enterText` lines until Tasks 7–9. Check analyze and format here and run the agreement-only files.

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add lib/features/work/presentation/employment_agreement_forms.dart test/features/work/presentation/employment_agreement_forms_test.dart test/integration/quick_add_flow_test.dart test/integration/work_core_flow_test.dart
git commit -m "feat: pick agreement dates and the night window

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Pay period and payslip forms pick their dates

**Files:**
- Modify: `lib/features/work/presentation/period_payslip_forms.dart` (`PeriodInspector.create` at 78–85, `_PeriodInspectorState` at 98–144 and 209–232, `PayslipInspector.create` at 248–255, `_PayslipInspectorState` at 261–378)
- Modify: `lib/features/work/presentation/work_screen.dart` (the `PeriodInspector.create` and `PayslipInspector.create` sites at 361, 368, 461 and 476; add a `_today` getter)
- Test: `test/features/work/presentation/period_payslip_forms_test.dart`; migrate `test/app/router_test.dart:444-451, 568-571` and `test/integration/work_core_flow_test.dart:63-70, 85-88`

**Interfaces:**
- Consumes: `EraDateField` (Task 3); `pickDate`, `dateIn` (Task 5); `LocalDate.lastOfMonth` (Task 1).
- Produces:
  - `PeriodInspector.create({required EmploymentId employmentId, required SubmitPayPeriod onSubmit, required LocalDate today, Key? key})`. `PeriodInspector.today` is `LocalDate?`, null for the record view.
  - `PayslipInspector.create({required PayPeriodId periodId, required SubmitPayslip onSubmit, required LocalDate today, Key? key})`.
  - The paid date box gets the key `ValueKey('payslip-paid-date')`.
  - `WorkScreen` gets `LocalDate get _today => widget.today ?? _deviceToday();`, which Tasks 8 and 9 reuse.

- [ ] **Step 1: Write the failing tests**

In `period_payslip_forms_test.dart`, add `import '../../../support/era_pickers.dart';`. Pass `today: const LocalDate(2026, 10, 5)` to every `PeriodInspector.create` and `today: const LocalDate(2026, 10, 31)` to every `PayslipInspector.create`. Then add:

```dart
  testWidgets('a new period spans today\'s month', (tester) async {
    PayPeriodDraft? submitted;
    await tester.pumpWidget(
      _TestApp(
        child: PeriodInspector.create(
          employmentId: employmentId,
          today: const LocalDate(2026, 2, 14),
          onSubmit: (draft) async {
            submitted = draft;
            return Committed(period);
          },
        ),
      ),
    );
    expect(dateIn(tester, 'period-start'), const LocalDate(2026, 2, 1));
    expect(dateIn(tester, 'period-end'), const LocalDate(2026, 2, 28));
    await tester.tap(find.text('Create period'));
    await tester.pumpAndSettle();
    expect(submitted!.start, const LocalDate(2026, 2, 1));
    expect(submitted!.end, const LocalDate(2026, 2, 28));
  });

  testWidgets('a payslip is issued today and paid only when ticked', (
    tester,
  ) async {
    PayslipDraft? submitted;
    await tester.pumpWidget(
      _TestApp(
        child: PayslipInspector.create(
          periodId: periodId,
          today: const LocalDate(2026, 10, 31),
          onSubmit: (draft) async {
            submitted = draft;
            return Committed(payslip);
          },
        ),
      ),
    );
    expect(dateIn(tester, 'payslip-issued-date'), const LocalDate(2026, 10, 31));
    expect(dateIn(tester, 'payslip-paid-date'), isNull);
    await tester.enterText(find.byKey(const ValueKey('payslip-amount')), '100');
    await pickDate(tester, 'payslip-paid-date', const LocalDate(2026, 11, 3));
    final save = find.text('Save payslip');
    await tester.scrollUntilVisible(save, 240, scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(submitted!.issuedDate, const LocalDate(2026, 10, 31));
    expect(submitted!.paidDate, const LocalDate(2026, 11, 3));
  });
```

`period` and `payslip` are the fixture records this file already declares for its view tests. Reuse whichever names the file uses; if it has no `Payslip` fixture, return `const Invalid<Payslip>({})` and assert only on `submitted`.

Rewrite the two existing tests:
- 'period creation submits explicit dates and retains invalid draft': delete the two `enterText` calls on `period-start`/`period-end`. The defaults for `today: 2026-10-05` are the same 2026-10-01…2026-10-31 the test typed. Keep the label entry and the assertions.
- 'invalid payslip save preserves entered evidence and errors': delete the `enterText` on `payslip-issued-date`. The default `today: 2026-10-31` is the date it typed.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/features/work/presentation/period_payslip_forms_test.dart`
Expected: FAIL with a compile error ("The named parameter 'today' isn't defined").

- [ ] **Step 3: Implement the forms**

In `period_payslip_forms.dart`:

1. Import `'../../../shared/workbench/era_date_field.dart'`.
2. `PeriodInspector`: add `final LocalDate? today;`. The record constructor sets `today = null`; `.create` takes `required LocalDate this.today`.
3. `_PeriodInspectorState`: remove the `_start`/`_end` controllers (and from `dispose`) and add:

```dart
  late LocalDate _start = widget.today!.firstOfMonth;
  late LocalDate _end = widget.today!.lastOfMonth;
```

   `_submit` loses its parse block:

```dart
  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errors = const {};
    });
    final outcome = await widget.onSubmit!(
      PayPeriodDraft(
        employmentId: widget.employmentId!,
        start: _start,
        end: _end,
        label: _optional(_label.text),
      ),
    );
    // … unchanged from `if (!mounted) return;` on …
  }
```

   In the Dates group, the two date `_Field`s become:

```dart
              EraDateField(
                label: 'Start date',
                fieldKey: const ValueKey('period-start'),
                value: _start,
                today: widget.today!,
                error: _errors['start'],
                onChanged: (value) => setState(() => _start = value!),
              ),
              EraDateField(
                label: 'End date',
                fieldKey: const ValueKey('period-end'),
                value: _end,
                today: widget.today!,
                error: _errors['end'],
                onChanged: (value) => setState(() => _end = value!),
              ),
```

4. `PayslipInspector.create`: add `required this.today` and `final LocalDate today;`. In the state, remove `_issuedDate`/`_paidDate` (and from `dispose`) and add:

```dart
  late LocalDate _issuedDate = widget.today;
  LocalDate? _paidDate;
```

   `_submit`: delete the issued/paid parsing and its two errors, so only the amount check remains, and pass `issuedDate: _issuedDate, paidDate: _paidDate`. The Payslip group's two date fields become:

```dart
              EraDateField(
                label: 'Issued date',
                fieldKey: const ValueKey('payslip-issued-date'),
                value: _issuedDate,
                today: widget.today,
                error: _errors['issuedDate'],
                onChanged: (value) => setState(() => _issuedDate = value!),
              ),
              EraDateField(
                label: 'Paid date',
                optional: true,
                fieldKey: const ValueKey('payslip-paid-date'),
                value: _paidDate,
                today: widget.today,
                error: _errors['paidDate'],
                onChanged: (value) => setState(() => _paidDate = value),
              ),
```

   (`_errors['issuedDate']`/`['paidDate']` can still come from the domain through `_payslipIssueMessage`.)

5. In `work_screen.dart`, add to the state class:

```dart
  LocalDate get _today => widget.today ?? _deviceToday();
```

   Pass `today: _today` to both `PeriodInspector.create(...)` sites and both `PayslipInspector.create(...)` sites.

- [ ] **Step 4: Migrate the integration lines for these forms**

- `test/app/router_test.dart:444-451` and `test/integration/work_core_flow_test.dart:63-70`: replace each `enterText` on `period-start`/`period-end` with `await pickDate(tester, 'period-start', const LocalDate(2026, 9, 1));` and `await pickDate(tester, 'period-end', const LocalDate(2026, 9, 30));`.
- `test/app/router_test.dart:568-571` and `test/integration/work_core_flow_test.dart:85-88`: replace with `await pickDate(tester, 'payslip-issued-date', const LocalDate(2026, 9, 30));`.

Add `import '../support/era_pickers.dart';` to `router_test.dart`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$F/flutter test test/features/work/presentation/period_payslip_forms_test.dart test/app/router_test.dart test/features/work/presentation/work_screen_test.dart`
Expected: the period and payslip tests PASS. Any remaining `router_test` failures are on `shift-*` keys only, which Task 9 owns.

- [ ] **Step 6: Analyze, format, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add lib/features/work/presentation/period_payslip_forms.dart lib/features/work/presentation/work_screen.dart test/features/work/presentation/period_payslip_forms_test.dart test/app/router_test.dart test/integration/work_core_flow_test.dart
git commit -m "feat: pick pay period and payslip dates

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The Date range dialog picks

**Files:**
- Modify: `lib/features/work/presentation/work_toolbar_controls.dart` (`PeriodPicker` at 115–127 and 161–167, `_RangeDialog` at 233–303)
- Modify: `lib/features/work/presentation/work_register.dart` (constructor and the `PeriodPicker(...)` at 185), `lib/features/work/presentation/work_screen.dart` (the `WorkRegister(...)` at 275)
- Test: `test/features/work/presentation/work_register_test.dart:360-401`

**Interfaces:**
- Consumes: `EraDateField` (Task 3); `pickDate`, `dateIn` (Task 5); `_today` in `WorkScreen` (Task 7).
- Produces: `PeriodPicker({…, LocalDate? today})` and `WorkRegister({…, LocalDate? today})`. Both are optional, so the 16 existing `WorkRegister` test sites still compile. Without `today`, the dialog uses the device date.

- [ ] **Step 1: Write the failing tests**

In `work_register_test.dart`, add `import '../../../support/era_pickers.dart';`. Add this test to the group with the range test:

```dart
    testWidgets('a new range starts on the first of this month and ends today', (
      tester,
    ) async {
      final scopes = <WorkTemporalScope?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: PeriodPicker(
                scope: null,
                periods: const [],
                today: const LocalDate(2026, 9, 15),
                onScope: scopes.add,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Period:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date range…'));
      await tester.pumpAndSettle();
      expect(dateIn(tester, 'range-from'), const LocalDate(2026, 9, 1));
      expect(dateIn(tester, 'range-to'), const LocalDate(2026, 9, 15));
      await tester.tap(find.byKey(const ValueKey('range-apply')));
      await tester.pumpAndSettle();
      final range = scopes.single! as DateRangeScope;
      expect(range.start, const LocalDate(2026, 9, 1));
      expect(range.end, const LocalDate(2026, 9, 15));
    });
```

Add the imports for `buildLifeOSTheme`, `LifeOSSkinScope` and `PeriodPicker` if the file lacks them. In 'an explicit date range is entered from the period menu', replace the three `enterText` calls:

```dart
      await pickDate(tester, 'range-from', const LocalDate(2026, 9, 10));
      await pickDate(tester, 'range-to', const LocalDate(2026, 9, 5));
      // … apply, expect the error, unchanged …
      await pickDate(tester, 'range-to', const LocalDate(2026, 9, 20));
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/features/work/presentation/work_register_test.dart`
Expected: FAIL with a compile error ("The named parameter 'today' isn't defined").

- [ ] **Step 3: Implement**

In `work_toolbar_controls.dart`:

1. Swap the `era_field.dart` import for `era_date_field.dart`.
2. `PeriodPicker`: add `this.today` and `final LocalDate? today;`. Its doc says "The date a new range ends on; the device date when null." `_askRange` builds `_RangeDialog(initial: scope, today: today ?? _deviceToday())`.
3. `_RangeDialog` takes `required this.today` (`final LocalDate today;`). Its state holds values:

```dart
  late LocalDate _from = switch (widget.initial) {
    DateRangeScope(:final start) => start,
    _ => widget.today.firstOfMonth,
  };
  late LocalDate _to = switch (widget.initial) {
    DateRangeScope(:final end) => end,
    _ => widget.today,
  };
  String? _error;

  void _apply() {
    if (_to.compareTo(_from) < 0) {
      setState(() => _error = 'The range must end on or after its start.');
      return;
    }
    Navigator.of(context).pop(DateRangeScope(start: _from, end: _to));
  }
```

   Delete `dispose` and the controllers. The body's two fields become:

```dart
        EraDateField(
          label: 'From',
          fieldKey: const ValueKey('range-from'),
          value: _from,
          today: widget.today,
          onChanged: (value) => setState(() => _from = value!),
        ),
        const SizedBox(height: 10),
        EraDateField(
          label: 'To',
          fieldKey: const ValueKey('range-to'),
          value: _to,
          today: widget.today,
          error: _error,
          onChanged: (value) => setState(() => _to = value!),
        ),
```

4. Add at the bottom of the file, beside `_addDays`:

```dart
LocalDate _deviceToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}
```

5. `WorkRegister`: add `this.today` and `final LocalDate? today;`, and pass `today: today` to `PeriodPicker`. In `work_screen.dart`, pass `today: _today` to `WorkRegister(...)`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `$F/flutter test test/features/work/presentation/work_register_test.dart`
Expected: PASS, including 'two-times text scale keeps all filter controls reachable'.

- [ ] **Step 5: Analyze, format, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add lib/features/work/presentation/work_toolbar_controls.dart lib/features/work/presentation/work_register.dart lib/features/work/presentation/work_screen.dart test/features/work/presentation/work_register_test.dart
git commit -m "feat: pick the Work date range

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Shift and break dates and times are picked

**Files:**
- Modify: `lib/features/work/presentation/shift_forms.dart` (`ShiftEditInspector` at 213–231, the whole `_ShiftEditInspectorState` at 233–452, and the helpers `_formatTime`, `_parseTime` and `_BreakControllers` at 501–535)
- Modify: `lib/features/work/presentation/work_screen.dart` (the `ShiftEditInspector(...)` sites at 395 and 634)
- Test: `test/features/work/presentation/shift_forms_test.dart`; migrate `test/app/router_test.dart:352-367, 914-930`, `test/integration/quick_add_flow_test.dart:113-121`, `test/integration/work_core_flow_test.dart:114-117, 189-195, 359-365` and `test/integration/shell_work_flow_test.dart:82-88`

**Interfaces:**
- Consumes: `EraDateField`, `EraTimeField` (Tasks 3–4); `pickDate`, `setTime`, `dateIn`, `timeIn` (Task 5); `_today` in `WorkScreen` (Task 7).
- Produces:
  - `ShiftEditInspector({…, required LocalDate today})`.
  - Public messages: `const shiftStartTimeMessage = 'Set a start time.'`, `const shiftEndTimeMessage = 'Set an end time.'`, `const breakTimesMessage = 'Set both break times, or neither.'`.

- [ ] **Step 1: Write the failing tests**

Rewrite `test/features/work/presentation/shift_forms_test.dart`. Keep `_save`, the fixtures and `_TestApp`; add `import '../../../support/era_pickers.dart';` and `import 'package:lifeos/core/time/local_time.dart';`. Add a pump helper:

```dart
const _today = LocalDate(2026, 10, 1);

Future<List<ManualShiftDraft>> _pumpShift(
  WidgetTester tester, {
  ShiftFormPrefill? prefill,
  MutationOutcome<WorkShift>? outcome,
}) async {
  final submitted = <ManualShiftDraft>[];
  await tester.pumpWidget(
    _TestApp(
      child: ShiftEditInspector(
        employmentId: employmentId,
        today: _today,
        initialTimezoneId: 'Europe/Vilnius',
        prefill: prefill,
        onSubmit: (draft) async {
          submitted.add(draft);
          return outcome ?? Committed(testShift);
        },
      ),
    ),
  );
  return submitted;
}
```

Tests (the first replaces 'manual overnight entry submits explicit local facts'; the second replaces 'validation preserves …' with the same assertions and `pickDate`/`setTime` in place of the four date and time `enterText`s):

```dart
  testWidgets('manual overnight entry submits picked local facts', (
    tester,
  ) async {
    final submitted = await _pumpShift(tester);
    await setTime(tester, 'shift-start-time', const LocalTime(22, 30));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-end-time', const LocalTime(6, 15));
    await tester.enterText(find.byKey(const ValueKey('shift-timezone')), 'Europe/Amsterdam');
    await tester.enterText(find.byKey(const ValueKey('shift-note')), 'Night coverage');
    await tester.tap(find.text('Add break'));
    await tester.pump();
    await pickDate(tester, 'shift-break-start-date-0', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-break-start-0', const LocalTime(1, 0));
    await pickDate(tester, 'shift-break-end-date-0', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-break-end-0', const LocalTime(1, 20));
    await _save(tester);

    final draft = submitted.single;
    expect(draft.localStartDate, _today);
    expect(draft.localStartTime, const LocalTime(22, 30));
    expect(draft.localEndDate, const LocalDate(2026, 10, 2));
    expect(draft.localEndTime, const LocalTime(6, 15));
    expect(draft.timezoneId, 'Europe/Amsterdam');
    expect(draft.note, 'Night coverage');
    final pause = draft.breaks.single;
    expect(pause.startDate, const LocalDate(2026, 10, 2));
    expect(pause.start, const LocalTime(1, 0));
    expect(pause.endDate, const LocalDate(2026, 10, 2));
    expect(pause.end, const LocalTime(1, 20));
  });

  testWidgets('a new shift starts today with empty times', (tester) async {
    final submitted = await _pumpShift(tester);
    expect(dateIn(tester, 'shift-start-date'), _today);
    expect(dateIn(tester, 'shift-end-date'), _today);
    expect(timeIn(tester, 'shift-start-time'), isNull);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('shift-start-time'))),
      containsSemantics(label: 'Start time, not set'),
    );
    await _save(tester);
    expect(submitted, isEmpty);
    expect(find.text(shiftStartTimeMessage), findsOneWidget);
    expect(find.text(shiftEndTimeMessage), findsOneWidget);
  });

  testWidgets('the end date follows the start date until picked', (
    tester,
  ) async {
    await _pumpShift(tester);
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 7));
    expect(dateIn(tester, 'shift-end-date'), const LocalDate(2026, 10, 7));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 8));
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 6));
    expect(dateIn(tester, 'shift-end-date'), const LocalDate(2026, 10, 8));
  });

  testWidgets('an overnight prefill keeps its next-day end as the start moves', (
    tester,
  ) async {
    await _pumpShift(
      tester,
      prefill: const ShiftFormPrefill(
        startDate: LocalDate(2026, 10, 3),
        startTime: LocalTime(22, 0),
        endDate: LocalDate(2026, 10, 4),
        endTime: LocalTime(6, 0),
        timezoneId: 'Europe/Vilnius',
        breaks: [],
        note: null,
      ),
    );
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 10));
    expect(dateIn(tester, 'shift-end-date'), const LocalDate(2026, 10, 11));
  });

  testWidgets('a break starts on the shift date, its first step at the shift start', (
    tester,
  ) async {
    await _pumpShift(tester);
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-start-time', const LocalTime(22, 30));
    await tester.tap(find.text('Add break'));
    await tester.pump();
    expect(dateIn(tester, 'shift-break-start-date-0'), const LocalDate(2026, 10, 2));
    expect(timeIn(tester, 'shift-break-start-0'), isNull);
    final up = find.descendant(
      of: find.ancestor(
        of: find.byKey(const ValueKey('shift-break-start-0')),
        matching: find.byType(EraTimeField),
      ),
      matching: find.byKey(const ValueKey('era-time-up')),
    );
    await tester.ensureVisible(up);
    await tester.tap(up);
    await tester.pump();
    expect(timeIn(tester, 'shift-break-start-0'), const LocalTime(22, 30));
  });

  testWidgets('an empty break is ignored; a half-set break is refused', (
    tester,
  ) async {
    final submitted = await _pumpShift(tester);
    await setTime(tester, 'shift-start-time', const LocalTime(9, 0));
    await setTime(tester, 'shift-end-time', const LocalTime(17, 0));
    await tester.tap(find.text('Add break'));
    await tester.pump();
    await _save(tester);
    expect(submitted.single.breaks, isEmpty);

    await setTime(tester, 'shift-break-start-0', const LocalTime(12, 0));
    await _save(tester);
    expect(submitted, hasLength(1));
    expect(find.text(breakTimesMessage), findsOneWidget);
  });

  testWidgets('a revised draft saves untouched exactly as prefilled', (
    tester,
  ) async {
    const prefill = ShiftFormPrefill(
      startDate: LocalDate(2026, 10, 3),
      startTime: LocalTime(22, 0, 13),
      endDate: LocalDate(2026, 10, 4),
      endTime: LocalTime(6, 0),
      timezoneId: 'Europe/Vilnius',
      breaks: [
        ManualBreakDraft(
          startDate: LocalDate(2026, 10, 4),
          start: LocalTime(1, 0),
          endDate: LocalDate(2026, 10, 4),
          end: LocalTime(1, 30),
        ),
      ],
      note: 'Synthetic',
    );
    final submitted = await _pumpShift(tester, prefill: prefill);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byKey(const ValueKey('shift-start-time')),
          matching: find.byType(EraTimeField),
        ),
        matching: find.byKey(const ValueKey('era-time-second')),
      ),
      findsOneWidget,
    );
    await _save(tester);
    final draft = submitted.single;
    expect(draft.localStartDate, prefill.startDate);
    expect(draft.localStartTime, const LocalTime(22, 0, 13));
    expect(draft.localEndDate, prefill.endDate);
    expect(draft.localEndTime, prefill.endTime);
    expect(draft.breaks.single.end, const LocalTime(1, 30));
  });
```

`ManualBreakDraft` and `ShiftFormPrefill` already have `const` constructors. Also import `package:lifeos/shared/workbench/era_time_field.dart` for the `EraTimeField` finder.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$F/flutter test test/features/work/presentation/shift_forms_test.dart`
Expected: FAIL with a compile error ("The named parameter 'today' isn't defined").

- [ ] **Step 3: Implement**

In `shift_forms.dart`:

1. Imports: add `era_date_field.dart` and `era_time_field.dart`. Keep `era_field.dart`, because `EraField` stays for the timezone and note.
2. Messages, above `ShiftCreateInspector`:

```dart
const shiftStartTimeMessage = 'Set a start time.';
const shiftEndTimeMessage = 'Set an end time.';
const breakTimesMessage = 'Set both break times, or neither.';

/// The first step of an empty shift start time.
const _firstShiftStep = LocalTime(9, 0);
```

3. `ShiftEditInspector`: add `required this.today` and `final LocalDate today;` with the doc "The date a new shift starts on, and the day circled in its calendars."
4. Replace `_ShiftEditInspectorState`'s fields, `dispose`, `_addBreak` and `_submit`:

```dart
final class _ShiftEditInspectorState extends State<ShiftEditInspector> {
  late LocalDate _startDate = widget.prefill?.startDate ?? widget.today;
  late LocalTime? _startTime = widget.prefill?.startTime;
  late LocalDate _endDate = widget.prefill?.endDate ?? _startDate;
  late LocalTime? _endTime = widget.prefill?.endTime;

  /// Days from the start date to the end date. The end date keeps this
  /// distance as the start date moves, until the end date is picked itself.
  late final int _endOffset = _endDate.daysSince(_startDate);
  bool _endDatePicked = false;
  late final _timezone = TextEditingController(
    text: widget.prefill?.timezoneId ?? widget.initialTimezoneId ?? '',
  );
  late final _note = TextEditingController(text: widget.prefill?.note ?? '');
  late final _breaks = <_BreakValues>[
    for (final value in widget.prefill?.breaks ?? const <ManualBreakDraft>[])
      _BreakValues(
        startDate: value.startDate,
        start: value.start,
        endDate: value.endDate,
        end: value.end,
      ),
  ];
  final _errors = <String, String>{};

  @override
  void dispose() {
    _timezone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _addBreak() => setState(
    () => _breaks.add(_BreakValues(startDate: _startDate, endDate: _startDate)),
  );

  void _setStartDate(LocalDate value) => setState(() {
    _startDate = value;
    if (!_endDatePicked) _endDate = value.addDays(_endOffset);
  });

  Future<void> _submit() async {
    final timezone = _timezone.text.trim();
    final breaks = <ManualBreakDraft>[];
    final errors = <String, String>{
      if (_startTime == null) 'startTime': shiftStartTimeMessage,
      if (_endTime == null) 'endTime': shiftEndTimeMessage,
      if (timezone.isEmpty) 'timezone': 'Enter an IANA timezone.',
    };
    for (final (index, value) in _breaks.indexed) {
      final (start, end) = (value.start, value.end);
      if (start == null && end == null) continue;
      if (start == null || end == null) {
        errors['break-$index'] = breakTimesMessage;
        continue;
      }
      breaks.add(
        ManualBreakDraft(
          startDate: value.startDate,
          start: start,
          endDate: value.endDate,
          end: end,
        ),
      );
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    final outcome = await widget.onSubmit(
      ManualShiftDraft(
        employmentId: widget.employmentId,
        localStartDate: _startDate,
        localStartTime: _startTime!,
        localEndDate: _endDate,
        localEndTime: _endTime!,
        timezoneId: timezone,
        startFold: null,
        endFold: null,
        breaks: List.unmodifiable(breaks),
        note: _trimOptional(_note.text),
      ),
    );
    // … unchanged from `if (!mounted) return;` on …
  }
```

5. In `build`, the Times group becomes:

```dart
        _group(context, 'Times', [
          _date('shift-start-date', 'Start date', _startDate, _setStartDate),
          _time(
            'shift-start-time',
            'Start time',
            _startTime,
            emptyStart: _firstShiftStep,
            error: _errors['startTime'],
            onChanged: (value) => setState(() => _startTime = value),
          ),
          _date(
            'shift-end-date',
            'End date',
            _endDate,
            (value) => setState(() {
              _endDate = value;
              _endDatePicked = true;
            }),
          ),
          _time(
            'shift-end-time',
            'End time',
            _endTime,
            emptyStart: _startTime ?? _firstShiftStep,
            error: _errors['endTime'],
            onChanged: (value) => setState(() => _endTime = value),
          ),
          _field(
            key: const ValueKey('shift-timezone'),
            label: 'Timezone',
            controller: _timezone,
            error: _errors['timezone'],
          ),
        ]),
```

   and the Breaks group's loop becomes:

```dart
          for (final (index, value) in _breaks.indexed) ...[
            _date(
              'shift-break-start-date-$index',
              'Break ${index + 1} start date',
              value.startDate,
              (picked) => setState(() => value.startDate = picked),
            ),
            _time(
              'shift-break-start-$index',
              'Break ${index + 1} start time',
              value.start,
              emptyStart: _startTime ?? _firstShiftStep,
              error: _errors['break-$index'],
              onChanged: (picked) => setState(() => value.start = picked),
            ),
            _date(
              'shift-break-end-date-$index',
              'Break ${index + 1} end date',
              value.endDate,
              (picked) => setState(() => value.endDate = picked),
            ),
            _time(
              'shift-break-end-$index',
              'Break ${index + 1} end time',
              value.end,
              emptyStart: value.start ?? _startTime ?? _firstShiftStep,
              onChanged: (picked) => setState(() => value.end = picked),
            ),
          ],
```

   Add these two methods to the state:

```dart
  Widget _date(
    String key,
    String label,
    LocalDate value,
    ValueChanged<LocalDate> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: EraDateField(
      fieldKey: ValueKey(key),
      label: label,
      value: value,
      today: widget.today,
      onChanged: (picked) => onChanged(picked!),
    ),
  );

  Widget _time(
    String key,
    String label,
    LocalTime? value, {
    required LocalTime emptyStart,
    required ValueChanged<LocalTime> onChanged,
    String? error,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: EraTimeField(
      fieldKey: ValueKey(key),
      label: label,
      value: value,
      emptyStart: emptyStart,
      error: error,
      onChanged: onChanged,
    ),
  );
```

6. Delete `_formatTime`, `_parseTime` and `_BreakControllers`. Add:

```dart
/// One break's picked values; times stay null until set.
final class _BreakValues {
  _BreakValues({
    required this.startDate,
    required this.endDate,
    this.start,
    this.end,
  });

  LocalDate startDate;
  LocalTime? start;
  LocalDate endDate;
  LocalTime? end;
}
```

7. `work_screen.dart`: pass `today: _today` to both `ShiftEditInspector(...)` sites. In the "from last time" prefill, change `widget.today ?? _deviceToday()` to `_today`.

- [ ] **Step 4: Migrate the remaining shift lines in the suite**

Use `pickDate`/`setTime` for writes and `dateIn`/`timeIn` for reads, with `LocalDate`/`LocalTime` values:

- `test/app/router_test.dart:352-367`: `pickDate(…'shift-start-date', LocalDate(2026, 9, 29))`, `setTime(…'shift-start-time', LocalTime(10, 0))`, `pickDate(…'shift-end-date', LocalDate(2026, 9, 29))`, `setTime(…'shift-end-time', LocalTime(18, 0))`.
- `test/app/router_test.dart:914-930`: the two controller reads become `expect(timeIn(tester, 'shift-start-time'), const LocalTime(H, M))` (use the values the strings held), and the `enterText` becomes `await setTime(tester, 'shift-end-time', const LocalTime(17, 0));`.
- `test/integration/quick_add_flow_test.dart:113-121`: delete the `field` helper's use for date and time keys and assert `dateIn(tester, 'shift-start-date') == LocalDate(2026, 10, 3)`, `timeIn(…'shift-start-time') == LocalTime(22, 0)`, `dateIn(…'shift-end-date') == LocalDate(2026, 10, 4)`, `timeIn(…'shift-end-time') == LocalTime(6, 0)`, `dateIn(…'shift-break-start-date-0') == LocalDate(2026, 10, 4)`, `timeIn(…'shift-break-start-0') == LocalTime(1, 0)` and `timeIn(…'shift-break-end-0') == LocalTime(1, 30)`. Keep `field('shift-timezone')` and `field('shift-note')` on the text fields.
- `test/integration/work_core_flow_test.dart:114-117`: `setTime(tester, 'shift-end-time', const LocalTime(17, 0))`.
- `test/integration/work_core_flow_test.dart:189-195`, `:359-365` and `test/integration/shell_work_flow_test.dart:82-88`: replace each `(key, value)` loop with four explicit calls. The `start`/`end` strings at 361/363 come from the helper's parameters; change those parameters to `LocalTime` and update its callers.

Add `import '../support/era_pickers.dart';` to `shell_work_flow_test.dart`, plus the `local_time.dart` imports where they are missing.

- [ ] **Step 5: Run the full suite**

Run: `$F/flutter test`
Expected: PASS. No `enterText` remains on a date or time key: a picked box has no `EditableText`, so a leftover would fail with "enterText … EditableText". Goldens may fail on `form_*.png` because the manual shift form changed. Task 10 regenerates them; confirm that those are the only failures.

- [ ] **Step 6: Analyze, format, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add lib/features/work/presentation/shift_forms.dart lib/features/work/presentation/work_screen.dart test/features/work/presentation/shift_forms_test.dart test/app/router_test.dart test/integration/quick_add_flow_test.dart test/integration/work_core_flow_test.dart test/integration/shell_work_flow_test.dart
git commit -m "feat: pick shift and break dates and times

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Goldens, guards, docs and app.sh

**Files:**
- Modify: `test/support/synthetic_shell.dart` (an `agreement` screen), `test/goldens/shell_goldens_test.dart` (calendar goldens)
- Create: `test/features/work/presentation/picked_values_test.dart` (a guard)
- Regenerate: `test/goldens/*.png`; new `agreement_1280x800.png`, `agreement_960x760.png`, `calendar_1280x800.png` and `calendar_960x760.png`
- Modify: `DESIGN.md` (Components)

**Interfaces:**
- Consumes: everything above.
- Produces: `syntheticScreens['agreement']`.

- [ ] **Step 1: Write the guard and golden tests**

Create `test/features/work/presentation/picked_values_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Picked dates and times are always well-formed, so no form may still
/// ask for a typed format (era pickers spec 4).
void main() {
  test('no parse message for dates or times remains in lib', () {
    const removed = [
      'Enter a valid ISO date.',
      'Enter a date as YYYY-MM-DD.',
      'Enter a time as HH:MM.',
      'Enter a valid local time.',
      'Enter valid break dates and times.',
      'Enter both dates as YYYY-MM-DD.',
      "hint: 'YYYY-MM-DD'",
    ];
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (removed.any(line.contains)) '${file.path}:${index + 1}',
    ];
    expect(offenders, isEmpty);
  });
}
```

In `test/support/synthetic_shell.dart`, add to `syntheticScreens`:

```dart
  'agreement': (employment, _) => '/work?employment=$employment&add=agreement',
```

In `test/goldens/shell_goldens_test.dart`, inside `main()` after the existing loop:

```dart
  for (final size in sizes) {
    final file = 'calendar_${size.width.round()}x${size.height.round()}';
    testWidgets(file, (tester) async {
      await pumpSyntheticShell(
        tester,
        size: size,
        screen: syntheticScreens['agreement']!,
      );
      await tester.tap(find.byKey(const ValueKey('agreement-effective-start')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(LifeOsApp), matchesGoldenFile('$file.png'));
    });
  }
```

- [ ] **Step 2: Run them to see the expected failures**

Run: `$F/flutter test test/features/work/presentation/picked_values_test.dart test/goldens/shell_goldens_test.dart`
Expected: the guard PASSES if Tasks 6–9 removed every message; fix any offender it names. The new goldens FAIL with "Could not be compared against non-existent file", and `form_*` fails on pixel differences.

- [ ] **Step 3: Regenerate and look at every golden**

```bash
$F/flutter test --update-goldens test/goldens/shell_goldens_test.dart
$F/flutter test --run-skipped -t real-font --update-goldens test/goldens/real_font_check_test.dart
```

Open each new or changed PNG with the Read tool: `test/goldens/agreement_*.png`, `calendar_*.png`, `form_*.png` and `real_font/agreement.png`, `real_font/form.png`. Check by eye:
- The date boxes show `Thu 2026-10-01` in a white box with a blue drop arrow. The time boxes show `22:00`/`06:00` with ▴▾.
- The calendar sits just below the Starts on box: a blue band with ◂ `October 2026` ▸, Mo–Su in blue, 3 October (the synthetic clock's day) circled red, 1 October filled blue, and grey September/November days.
- At 960 × 760, nothing overlaps the window edge.
- The Night sentence reads `[22:00 ⬍] to [06:00 ⬍] ×[1.5]`.

If anything reads as modern rather than 2001-era, fix it in the owning control before going on. Typical slips are rounded corners, drop shadows or Material ink.

- [ ] **Step 4: Document the controls**

In `DESIGN.md` under `## Components`, after the "Filter row and combos" bullet, add:

```markdown
- **Date and time boxes** (`EraDateField`, `EraTimeField`, `EraMonthCalendar`): a date shows as `Mon 2026-10-05` beside the blue drop arrow, which opens a Monday-first month calendar: the month on a Head-blue band between ◂ and ▸, today circled in red, the chosen day filled with selection blue, and a **Today:** link. A time shows `07:00` beside stacked ▴▾ spin arrows; the selected part fills with selection blue, and seconds appear only for times that have them. Both are picked, never typed. An optional date has a check box inside its box; clear means none.
```

In the "Forms" bullet, change "labelled white fields (`EraField` …)" to "labelled white fields (`EraField` for text, `EraDateField`/`EraTimeField` for dates and times …)".

- [ ] **Step 5: Verify app.sh**

`app.sh`'s commands did not change. Run its test and check options non-interactively:

```bash
printf '2\n4\n' | ./app.sh
printf '3\n4\n' | ./app.sh
```

Expected: "All tests passed!", then analyze "No issues found!" with the format and schema checks passing, and exit 0. Start the app once with `printf '1\n' | timeout 120 ./app.sh` or the `run` skill. Open Work › add agreement, click Starts on, page a month, pick a day, and step a night time with the spin arrows. Then stop it.

- [ ] **Step 6: Commit**

```bash
git add test/support/synthetic_shell.dart test/goldens test/features/work/presentation/picked_values_test.dart DESIGN.md
git commit -m "test: add calendar and agreement goldens; document the era pickers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review Notes

- **Spec coverage:** Each section maps to a task:
  - §3.1 → Task 3; §3.2 → Task 2; §3.3 → Task 4; §3.4 → semantics tests in Tasks 2–4.
  - §4 table: agreement → Task 6; pay period and payslip → Task 7; Date range → Task 8; shift and break → Task 9.
  - §4 bullets (removed parse messages, checks kept, empty break ignored) → Tasks 6–10.
  - §5 test helpers → Task 5; goldens → Task 10; `app.sh` → Task 10.
- **Fold choices** (§4, "unchanged"): `ShiftEditInspector` still sends `startFold: null, endFold: null`; nothing to do.
- **Out of scope** (§6) is respected. The timezone field stays a typed `EraField`, and no control holds a range.
