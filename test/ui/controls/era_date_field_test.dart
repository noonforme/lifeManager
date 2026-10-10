import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/ui/ui.dart';

const _today = LocalDate(2026, 10, 5);
const _box = ValueKey('starts-on');

final class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    required this.optional,
    this.child,
    this.onChanged,
  });

  final LocalDate? initial;
  final bool optional;

  /// Told of every change the box sends, before the host takes it.
  final ValueChanged<LocalDate?>? onChanged;

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
        onChanged: (picked) {
          widget.onChanged?.call(picked);
          setState(() => value = picked);
        },
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
  ValueChanged<LocalDate?>? onChanged,
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
                child: _Host(
                  initial: value,
                  optional: optional,
                  child: wrap,
                  onChanged: onChanged,
                ),
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

Finder get _text =>
    find.descendant(of: find.byKey(_box), matching: find.byType(Text));

/// What the box reads: "Mon 2026-10-05".
String _shown(WidgetTester tester) =>
    tester.widget<Text>(_text).textSpan!.toPlainText();

/// Where the box's text from [start] to [end] is drawn: in "Mon
/// 2026-10-05" the weekday is 0–3, the year 4–8, the month 9–11 and the
/// day 12–14.
Offset _at(WidgetTester tester, int start, int end) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: _text, matching: find.byType(RichText)),
  );
  final box = paragraph
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
      .first;
  return paragraph.localToGlobal(box.toRect().center);
}

const _parts = {'year': (4, 8), 'month': (9, 11), 'day': (12, 14)};

/// Clicks the drop arrow, which opens and closes the calendar.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('era-date-drop')));
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Types [keys] into the focused box: digits, and - / . between parts.
Future<void> _type(WidgetTester tester, String keys) async {
  const named = {
    '0': LogicalKeyboardKey.digit0,
    '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2,
    '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4,
    '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6,
    '7': LogicalKeyboardKey.digit7,
    '8': LogicalKeyboardKey.digit8,
    '9': LogicalKeyboardKey.digit9,
    '-': LogicalKeyboardKey.minus,
    '/': LogicalKeyboardKey.slash,
    '.': LogicalKeyboardKey.period,
  };
  for (final key in keys.split('')) {
    await _press(tester, named[key]!);
  }
}

/// Selects a part by clicking its digits.
Future<void> _select(WidgetTester tester, String part) async {
  final (start, end) = _parts[part]!;
  await tester.tapAt(_at(tester, start, end));
  await tester.pump();
}

void main() {
  testWidgets('the box shows the weekday and ISO date', (tester) async {
    await _pump(tester);
    expect(find.text('Mon 2026-10-05'), findsOneWidget);
    expect(find.text('Starts on:'), findsOneWidget);
    expect(tester.getSize(find.byKey(_box)).height, greaterThanOrEqualTo(24));
  });

  testWidgets('the box is one button named by label and date', (tester) async {
    await _pump(tester);
    expect(
      tester.getSemantics(find.byKey(_box)),
      isSemantics(
        label: 'Starts on, Monday 5 October 2026',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        isFocusable: true,
        isFocused: false,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(_box)),
      isSemantics(
        label: 'Starts on, Monday 5 October 2026',
        isButton: true,
        isFocusable: true,
        isFocused: true,
      ),
    );
  });

  testWidgets('a click on the arrow or the weekday opens below the box', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tapAt(_at(tester, 0, 3));
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    await _open(tester);
    expect(_calendar, findsNothing);
    await _open(tester);
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
    await _open(tester);
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

  testWidgets('a keyboard-opened calendar takes focus: arrows, Enter, Esc', (
    tester,
  ) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateFieldCalendar',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(_value(tester), const LocalDate(2026, 10, 6));
  });

  testWidgets('Esc and a click outside close without a change', (tester) async {
    await _pump(tester);
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_value(tester), _today);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateField',
    );

    await _open(tester);
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(_value(tester), _today);
  });

  testWidgets('a click on another control keeps the focus it takes', (
    tester,
  ) async {
    final other = FocusNode(debugLabel: 'Other');
    addTearDown(other.dispose);
    await _pump(
      tester,
      wrap: (field) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field,
          // Takes focus on press, as the time box's parts do.
          Listener(
            key: const ValueKey('other'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => other.requestFocus(),
            child: Focus(
              focusNode: other,
              child: const SizedBox(width: 40, height: 24),
            ),
          ),
        ],
      ),
    );
    await _open(tester);
    expect(_calendar, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('other')));
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(tester.binding.focusManager.primaryFocus, other);
  });

  testWidgets('a click on nothing focusable gives focus back to the box', (
    tester,
  ) async {
    await _pump(tester);
    await _open(tester);
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateField',
    );
  });

  testWidgets('a held Tab keeps focus in the open calendar', (tester) async {
    await _pump(tester);
    await _open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    for (var index = 0; index < 3; index++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateFieldCalendar',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
  });

  testWidgets('focus moving elsewhere closes the calendar and stays there', (
    tester,
  ) async {
    final elsewhere = FocusNode(debugLabel: 'Elsewhere');
    addTearDown(elsewhere.dispose);
    await _pump(
      tester,
      wrap: (field) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          Focus(focusNode: elsewhere, child: const SizedBox(height: 24)),
        ],
      ),
    );
    await _open(tester);
    expect(_calendar, findsOneWidget);
    elsewhere.requestFocus();
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(tester.binding.focusManager.primaryFocus, elsewhere);
    expect(_value(tester), _today);
  });

  testWidgets('a click on a day picks once and focus returns to the box', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                child: StatefulBuilder(
                  builder: (context, setState) => EraDateField(
                    label: 'Starts on',
                    value: _today,
                    today: _today,
                    fieldKey: _box,
                    onChanged: (_) => changes++,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('era-day-2026-10-07')));
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(_calendar, findsNothing);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateField',
    );
  });

  testWidgets('the calendar opens above a box near the bottom', (tester) async {
    await _pump(tester, alignment: Alignment.bottomCenter);
    await _open(tester);
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
      isSemantics(label: 'Ends on, none', isEnabled: false, isFocusable: false),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('era-date-check'))),
      isSemantics(label: 'Ends on', hasCheckedState: true, isChecked: false),
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

  testWidgets('a click on the check box focuses it, open calendar or not', (
    tester,
  ) async {
    await _pump(tester, optional: true);
    await _open(tester);
    expect(_calendar, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('era-date-check')));
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    expect(_value(tester), isNull);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateFieldCheck',
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('era-date-check')));
    await tester.pumpAndSettle();
    expect(_value(tester), _today);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateFieldCheck',
    );
  });

  testWidgets('scrolling the form closes the calendar', (tester) async {
    await _pump(
      tester,
      wrap: (field) => SizedBox(
        height: 500,
        child: ListView(children: [field, const SizedBox(height: 2000)]),
      ),
    );
    await _open(tester);
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
    await _open(tester);
    expect(tester.takeException(), isNull);
    final calendar = tester.getRect(_calendar);
    expect(calendar.left, greaterThanOrEqualTo(0));
    expect(calendar.right, lessThanOrEqualTo(800));
    expect(calendar.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('the calendar stays on its box when the window resizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: const LifeOSSkinScope(
          child: Scaffold(
            body: Center(child: _Host(initial: _today, optional: false)),
          ),
        ),
      ),
    );
    await _open(tester);
    expect(_calendar, findsOneWidget);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    final box = tester.getRect(find.byKey(_box));
    final calendar = tester.getRect(_calendar);
    expect(calendar.left, moreOrLessEquals(box.left, epsilon: 0.5));
    expect(calendar.top, moreOrLessEquals(box.bottom, epsilon: 0.5));
  });

  // Typed dates (era pickers spec 2, amended 2026-10-08 at the owner's
  // request): digits fill the selected part, year, month, then day.

  testWidgets('20261105 typed from the year sets 2026-11-05', (tester) async {
    final sent = <LocalDate?>[];
    await _pump(tester, onChanged: sent.add);
    await _press(tester, LogicalKeyboardKey.tab);
    await _type(tester, '20261105');
    expect(_value(tester), const LocalDate(2026, 11, 5));
    expect(_shown(tester), 'Thu 2026-11-05');
    // 2026 and 05 change nothing; the 1 sets January, then 11 November.
    expect(sent, const [LocalDate(2026, 1, 5), LocalDate(2026, 11, 5)]);
  });

  testWidgets('the year waits for its fourth digit, then moves on', (
    tester,
  ) async {
    final sent = <LocalDate?>[];
    await _pump(tester, onChanged: sent.add);
    await _press(tester, LogicalKeyboardKey.tab);
    await _type(tester, '202');
    expect(sent, isEmpty);
    expect(_shown(tester), 'Mon 202-10-05');
    await _type(tester, '7');
    expect(sent, const [LocalDate(2027, 10, 5)]);
    await _type(tester, '3');
    expect(_value(tester), const LocalDate(2027, 3, 5));
  });

  testWidgets('3 in the month sets March and moves to the day', (tester) async {
    await _pump(tester);
    await _select(tester, 'month');
    await _type(tester, '3');
    expect(_value(tester), const LocalDate(2026, 3, 5));
    await _type(tester, '9');
    expect(_value(tester), const LocalDate(2026, 3, 9));
  });

  testWidgets('a 1 in the month waits; 15 is no month and the 5 starts again', (
    tester,
  ) async {
    await _pump(tester);
    await _select(tester, 'month');
    await _type(tester, '1');
    expect(_value(tester), const LocalDate(2026, 1, 5));
    await _type(tester, '5');
    expect(_value(tester), const LocalDate(2026, 5, 5));
    // The 5 committed and moved on: the next digit is the day's.
    await _type(tester, '7');
    expect(_value(tester), const LocalDate(2026, 5, 7));
  });

  testWidgets('31 typed into a February day gives its last day', (
    tester,
  ) async {
    await _pump(tester, value: const LocalDate(2026, 2, 10));
    await _select(tester, 'day');
    await _type(tester, '31');
    expect(_value(tester), const LocalDate(2026, 2, 28));
  });

  testWidgets('a day past the new month\'s end clamps to its last day', (
    tester,
  ) async {
    await _pump(tester, value: const LocalDate(2028, 3, 31));
    await _select(tester, 'month');
    await _type(tester, '2');
    expect(_value(tester), const LocalDate(2028, 2, 29));
    await _select(tester, 'year');
    await _type(tester, '2027');
    expect(_value(tester), const LocalDate(2027, 2, 28));
  });

  testWidgets('- / and . move to the next part and stay on the last', (
    tester,
  ) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await _type(tester, '-4');
    expect(_value(tester), const LocalDate(2026, 4, 5));
    await _select(tester, 'year');
    await _type(tester, '/');
    await _type(tester, '.');
    await _type(tester, '.8');
    expect(_value(tester), const LocalDate(2026, 4, 8));
  });

  testWidgets('Left and Right move between parts and stay at the ends', (
    tester,
  ) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _type(tester, '6');
    expect(_value(tester), const LocalDate(2026, 6, 5));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _type(tester, '9');
    expect(_value(tester), const LocalDate(2026, 9, 5));
  });

  testWidgets('Up and Down step the part, wrapping without carrying', (
    tester,
  ) async {
    await _pump(tester, value: const LocalDate(2026, 12, 31));
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalDate(2027, 12, 31));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    // December to January keeps the year.
    expect(_value(tester), const LocalDate(2027, 1, 31));
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    // 31 November is no day: the 30th.
    expect(_value(tester), const LocalDate(2027, 11, 30));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalDate(2027, 11, 1));
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_value(tester), const LocalDate(2027, 11, 30));
  });

  testWidgets('Alt+Down still opens the calendar from any part', (
    tester,
  ) async {
    await _pump(tester);
    await _select(tester, 'month');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    expect(_value(tester), _today);
  });

  testWidgets('a click selects the part clicked and leaves the calendar shut', (
    tester,
  ) async {
    await _pump(tester);
    await _select(tester, 'day');
    expect(_calendar, findsNothing);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'EraDateField',
    );
    await _type(tester, '7');
    expect(_value(tester), const LocalDate(2026, 10, 7));
  });

  testWidgets('a click on a part closes an open calendar and selects it', (
    tester,
  ) async {
    await _pump(tester);
    await _open(tester);
    await _select(tester, 'month');
    await tester.pumpAndSettle();
    expect(_calendar, findsNothing);
    await _type(tester, '7');
    expect(_value(tester), const LocalDate(2026, 7, 5));
  });

  testWidgets('the selected part is filled with selection blue', (
    tester,
  ) async {
    await _pump(tester);
    // The box's spans: weekday, year, -, month, -, day.
    Color? fill(String part) {
      final spans =
          (tester.widget<Text>(_text).textSpan! as TextSpan).children!;
      final index = {'year': 1, 'month': 3, 'day': 5}[part]!;
      return spans[index].style?.backgroundColor;
    }

    expect(fill('year'), isNull);
    await _press(tester, LogicalKeyboardKey.tab);
    expect(fill('year'), LifeOSSkinData.standard.tokens.selWash);
    expect(fill('month'), isNull);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(fill('year'), isNull);
    expect(fill('month'), LifeOSSkinData.standard.tokens.selWash);
  });

  testWidgets('backspace drops the waiting digits and keeps the value', (
    tester,
  ) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await _type(tester, '19');
    await _press(tester, LogicalKeyboardKey.backspace);
    expect(_shown(tester), 'Mon 2026-10-05');
    await _type(tester, '2031');
    expect(_value(tester), const LocalDate(2031, 10, 5));
  });

  testWidgets('losing focus or stepping drops the waiting digits', (
    tester,
  ) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await _type(tester, '20');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_shown(tester), 'Mon 2026-10-05');
    await _press(tester, LogicalKeyboardKey.tab);
    await _type(tester, '30');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalDate(2027, 10, 5));
    await _type(tester, '2030');
    expect(_value(tester), const LocalDate(2030, 10, 5));
  });

  testWidgets('a held digit key types once and stays with the box', (
    tester,
  ) async {
    var shortcut = 0;
    await _pump(
      tester,
      wrap: (field) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.digit3): () => shortcut++,
        },
        child: field,
      ),
    );
    await _select(tester, 'month');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(_value(tester), const LocalDate(2026, 3, 5));
    expect(shortcut, 0);
  });

  testWidgets('a digit with Ctrl or Alt is a shortcut, not typing', (
    tester,
  ) async {
    await _pump(tester);
    await _select(tester, 'month');
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.altLeft,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
    }
    expect(_value(tester), _today);
  });

  testWidgets('a read-only form ignores digits', (tester) async {
    final sent = <LocalDate?>[];
    await _pump(
      tester,
      onChanged: sent.add,
      wrap: (field) => EraFormScope(enabled: false, child: field),
    );
    await _press(tester, LogicalKeyboardKey.tab);
    await _select(tester, 'year');
    await _type(tester, '2031');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(sent, isEmpty);
    expect(_value(tester), _today);
  });

  testWidgets('a clear optional box ignores digits until ticked', (
    tester,
  ) async {
    await _pump(tester, value: null, optional: true);
    await _select(tester, 'day');
    await _type(tester, '7');
    expect(_value(tester), isNull);
    await tester.tap(find.byKey(const ValueKey('era-date-check')));
    await tester.pump();
    await _select(tester, 'day');
    await _type(tester, '7');
    expect(_value(tester), const LocalDate(2026, 10, 7));
  });

  testWidgets('a value from outside drops the waiting digits', (tester) async {
    LocalDate? sent;
    Future<void> show(LocalDate value) => tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: EraDateField(
              label: 'Starts on',
              value: value,
              today: _today,
              fieldKey: _box,
              onChanged: (next) => sent = next,
            ),
          ),
        ),
      ),
    );
    await show(_today);
    await _select(tester, 'month');
    await _type(tester, '1');
    expect(sent, const LocalDate(2026, 1, 5));
    await show(const LocalDate(2026, 9, 9));
    await _type(tester, '2');
    expect(sent, const LocalDate(2026, 2, 9));
  });

  testWidgets('a host that applies a change a rebuild late keeps the digit', (
    tester,
  ) async {
    final host = GlobalKey<_LateHostState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(body: _LateHost(key: host)),
        ),
      ),
    );
    await _select(tester, 'month');
    await _type(tester, '1');
    // The host rebuilds still on 5 October, then takes January.
    expect(_value(tester), _today);
    host.currentState!.apply();
    await tester.pump();
    expect(_value(tester), const LocalDate(2026, 1, 5));
    await _type(tester, '1');
    expect(_value(tester), const LocalDate(2026, 1, 5));
    host.currentState!.apply();
    await tester.pump();
    expect(_value(tester), const LocalDate(2026, 11, 5));
  });

  testWidgets('held arrows repeat; held digits, - and Backspace act once', (
    tester,
  ) async {
    await _pump(tester);
    await _select(tester, 'day');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_value(tester), const LocalDate(2026, 10, 8));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    // Two moves left from the day: the year.
    await _type(tester, '2031');
    expect(_value(tester), const LocalDate(2031, 10, 8));

    // A held - moves on once: from the month to the day, not past it.
    await _select(tester, 'year');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    await _type(tester, '7');
    expect(_value(tester), const LocalDate(2031, 7, 8));

    // A Backspace repeat after a new digit leaves that digit waiting.
    await _select(tester, 'year');
    await _type(tester, '20');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    await _type(tester, '1');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await _type(tester, '999');
    expect(_value(tester), const LocalDate(1999, 7, 8));
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

/// Takes a change only when told to, after rebuilding on the old value
/// first, as a form that saves through a stream would.
final class _LateHost extends StatefulWidget {
  const _LateHost({super.key});

  @override
  State<_LateHost> createState() => _LateHostState();
}

final class _LateHostState extends State<_LateHost> {
  LocalDate value = _today;
  LocalDate? waiting;

  void apply() => setState(() => value = waiting ?? value);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: EraDateField(
      label: 'Starts on',
      value: value,
      today: _today,
      fieldKey: _box,
      onChanged: (next) => setState(() => waiting = next),
    ),
  );
}
