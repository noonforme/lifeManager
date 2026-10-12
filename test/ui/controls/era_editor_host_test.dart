import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

/// The editor host scope (database shell spec 4.6): inside it the shared
/// era controls take only data entry from the keyboard and hand plain
/// Enter, Tab and Esc to their host; outside it every legacy binding stays.

const _today = LocalDate(2026, 10, 8);
const _date = ValueKey('starts-on');
const _time = ValueKey('start-time');
const _combo = ValueKey('view');
const _text = ValueKey('note');

/// A form of every shared control, hosted or not, in a form that may be
/// disabled. It holds the values the controls send.
final class _Form extends StatefulWidget {
  const _Form({
    required this.hosted,
    required this.bare,
    required this.enabled,
    required this.keys,
    required this.submitted,
    this.error,
  });

  final bool hosted;
  final bool bare;
  final bool enabled;
  final String? error;

  /// What the scope handed its host, in order.
  final List<EraEditorKey> keys;

  /// What the text field's own submit action sent.
  final List<String> submitted;

  @override
  State<_Form> createState() => _FormState();
}

final class _FormState extends State<_Form> {
  LocalDate? date = _today;
  LocalTime? time = const LocalTime(7, 0);
  String combo = 'Pay periods';
  bool check = true;
  String radio = 'gross';
  final note = TextEditingController(text: 'Late');

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = EraFormScope(
      enabled: widget.enabled,
      child: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EraDateField(
              label: 'Starts on',
              value: date,
              today: _today,
              error: widget.error,
              fieldKey: _date,
              onChanged: (value) => setState(() => date = value),
            ),
            EraTimeField(
              label: 'Start time',
              value: time,
              error: widget.error,
              fieldKey: _time,
              onChanged: (value) => setState(() => time = value),
            ),
            EraLabelled(
              label: 'View',
              fieldWidth: EraFieldWidth.text,
              field: EraCombo<String>(
                key: _combo,
                semanticLabel: 'View',
                value: combo,
                items: const [
                  EraComboItem('Shifts', 'Shifts'),
                  EraComboItem('Pay periods', 'Pay periods'),
                  EraComboItem('Payslips', 'Payslips'),
                ],
                onSelected: (value) => setState(() => combo = value),
              ),
            ),
            EraCheckBox(
              value: check,
              label: 'Paid',
              onChanged: (value) => setState(() => check = value),
            ),
            EraRadioGroup<String>(
              groupValue: radio,
              options: const [
                EraRadioOption('gross', 'Gross'),
                EraRadioOption('net', 'Net'),
              ],
              onChanged: (value) => setState(() => radio = value),
            ),
            EraField(
              controller: note,
              label: 'Note',
              fieldKey: _text,
              error: widget.error,
              onSubmitted: widget.submitted.add,
            ),
          ],
        ),
      ),
    );
    if (!widget.hosted) return form;
    return EraEditorHostScope(
      bare: widget.bare,
      onKey: widget.keys.add,
      child: form,
    );
  }
}

/// Pumps the form and returns the keys its host receives.
Future<List<EraEditorKey>> _pump(
  WidgetTester tester, {
  bool hosted = true,
  bool bare = false,
  bool enabled = true,
  String? error,
  List<String>? submitted,
}) async {
  final keys = <EraEditorKey>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: LifeOSSkinScope(
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _Form(
                  hosted: hosted,
                  bare: bare,
                  enabled: enabled,
                  error: error,
                  keys: keys,
                  submitted: submitted ?? [],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return keys;
}

_FormState _form(WidgetTester tester) => tester.state(find.byType(_Form));

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Finder get _calendar => find.byType(EraMonthCalendar);

/// The month the open calendar shows, from its band.
String _calendarTitle(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: _calendar,
        matching: find.byKey(const ValueKey('era-calendar-title')),
      ),
    )
    .data!;

/// The day [day] inside the open calendar only.
Finder _day(LocalDate day) => find.descendant(
  of: _calendar,
  matching: find.byKey(ValueKey('era-day-$day')),
);

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// [key] pressed while [modifier] is held.
Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

/// A mouse click on the date box's drop arrow, the real target that opens
/// the calendar (the box's centre may select a date part instead).
Future<void> _clickDropArrow(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(_date),
      matching: find.byKey(const ValueKey('era-date-drop')),
    ),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

/// A mouse click on the year digits of the date box, which focuses it
/// without opening the calendar.
Future<void> _clickYear(WidgetTester tester) async {
  final text = find.descendant(
    of: find.byKey(_date),
    matching: find.byType(RichText),
  );
  final paragraph = tester.renderObject<RenderParagraph>(text.first);
  // "Thu 2026-10-08": the year is characters 4 to 8.
  final box = paragraph
      .getBoxesForSelection(const TextSelection(baseOffset: 4, extentOffset: 8))
      .first;
  await tester.tapAt(
    paragraph.localToGlobal(box.toRect().center),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
}

/// A mouse click on the time box's hours, which focuses it.
Future<void> _clickHours(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(_time),
      matching: find.byKey(const ValueKey('era-time-hour')),
    ),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
}

Future<void> _clickCombo(WidgetTester tester) async {
  await tester.tap(find.byKey(_combo), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Gives keyboard focus to the control around [finder] the way traversal
/// would, without a click that would change its value.
Future<void> _focusInside(WidgetTester tester, Finder finder) async {
  final nodes = [
    for (final element
        in find.descendant(of: finder, matching: find.byType(Focus)).evaluate())
      Focus.of(_firstChild(element), createDependency: false),
  ];
  final node = nodes.firstWhere((node) => node.canRequestFocus);
  node.requestFocus();
  await tester.pump();
  expect(node.hasPrimaryFocus, isTrue);
}

Element _firstChild(Element element) {
  Element? child;
  element.visitChildElements((each) => child ??= each);
  return child!;
}

bool get _comboOpen => find.byType(MenuItemButton).evaluate().isNotEmpty;

void main() {
  group('outside the scope, legacy keys stay', () {
    testWidgets('Enter in a date box opens its calendar', (tester) async {
      await _pump(tester, hosted: false);
      await _clickYear(tester);
      expect(_calendar, findsNothing);
      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_calendar, findsOneWidget);
    });

    testWidgets('Page Up and Alt+Up still step a time box', (tester) async {
      await _pump(tester, hosted: false);
      await _clickHours(tester);
      await _press(tester, LogicalKeyboardKey.pageUp);
      expect(_form(tester).time, const LocalTime(17, 0));
      await _chord(
        tester,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.arrowUp,
      );
      expect(_form(tester).time, const LocalTime(18, 0));
    });

    testWidgets('the arrow keys move and Enter picks in an open calendar', (
      tester,
    ) async {
      await _pump(tester, hosted: false);
      await _clickDropArrow(tester);
      expect(_focused, 'EraDateFieldCalendar');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_form(tester).date, _today.addDays(1));
    });

    testWidgets('Enter opens a combo and Down steps it', (tester) async {
      await _pump(tester, hosted: false);
      await _clickCombo(tester);
      await _press(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_comboOpen, isFalse);
      await _focusInside(tester, find.byKey(_combo));
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_form(tester).combo, 'Payslips');
      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_comboOpen, isTrue);
    });

    testWidgets('Space toggles a focused check box', (tester) async {
      await _pump(tester, hosted: false);
      await _focusInside(tester, find.byType(EraCheckBox));
      await _press(tester, LogicalKeyboardKey.space);
      expect(_form(tester).check, isFalse);
    });

    testWidgets("Enter runs the text field's submit action", (tester) async {
      final submitted = <String>[];
      await _pump(tester, hosted: false, submitted: submitted);
      await tester.tap(find.byKey(_text));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, ['Late']);
    });
  });

  group('labels', () {
    testWidgets('stay beside their fields outside the scope and in a '
        'normal host', (tester) async {
      await _pump(tester, hosted: false);
      final legacy = tester.getSize(find.byKey(_date));
      for (final label in ['Starts on:', 'Start time:', 'View:', 'Note:']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await _pump(tester);
      for (final label in ['Starts on:', 'Start time:', 'View:', 'Note:']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.getSize(find.byKey(_date)), legacy);
    });

    testWidgets('go only in a bare host, which keeps names, errors and the '
        'disabled look', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, bare: true, enabled: false, error: 'Too early.');
      for (final label in ['Starts on:', 'Start time:', 'View:', 'Note:']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(
        find.bySemanticsLabel(RegExp(r'^Starts on, .*Too early\.$')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Start time, 07:00, Too early\.$')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Note, Too early.'), findsOneWidget);
      expect(find.text('Too early.'), findsNWidgets(3));
      final box = tester.widget<Container>(find.byKey(_date));
      final skin = LifeOSSkinScope.of(tester.element(find.byKey(_date)));
      expect((box.decoration! as BoxDecoration).color, skin.tokens.chrome);
      semantics.dispose();
    });

    testWidgets('a bare field is never narrower than its kind width while '
        'its cell allows', (tester) async {
      await _pump(tester, bare: true);
      // A bare date box fills its 400 px cell.
      expect(tester.getSize(find.byKey(_date)).width, 400);
      // The time box keeps its digits on one line: its width holds the
      // painted digits, their 3 px padding, the 17 px spin keys and the
      // 1 px border on each side.
      final parts = [
        for (final part in ['hour', 'minute'])
          tester.getRect(
            find.descendant(
              of: find.byKey(_time),
              matching: find.byKey(ValueKey('era-time-$part')),
            ),
          ),
      ];
      expect(parts[0].top, parts[1].top);
      final width = tester.getSize(find.byKey(_time)).width;
      expect(width, greaterThanOrEqualTo(EraFieldWidth.time));
      expect(
        width,
        greaterThanOrEqualTo(parts[1].right - parts[0].left + 2 * 3 + 17 + 2),
      );
    });

    testWidgets('a bare date box in a cell of its kind width is the size '
        'of the labelled one', (tester) async {
      Future<Size> pumpCell({required bool bare}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLifeOSTheme(),
            home: LifeOSSkinScope(
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: EraEditorHostScope(
                    bare: bare,
                    child: SizedBox(
                      width: bare ? EraFieldWidth.date : 400,
                      child: EraDateField(
                        label: 'Starts on',
                        value: _today,
                        today: _today,
                        fieldKey: _date,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.getSize(find.byKey(_date));
      }

      final labelled = await pumpCell(bare: false);
      expect(labelled.width, EraFieldWidth.date);
      expect(await pumpCell(bare: true), labelled);
    });
  });

  group('inside the scope', () {
    testWidgets('Enter, Space and Alt+Down never open a date calendar', (
      tester,
    ) async {
      final keys = await _pump(tester);
      await _clickYear(tester);
      expect(_focused, 'EraDateField');
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.numpadEnter);
      await _press(tester, LogicalKeyboardKey.space);
      await _chord(
        tester,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.arrowDown,
      );
      await tester.pumpAndSettle();
      expect(_calendar, findsNothing);
      expect(_form(tester).date, _today);
      expect(keys, [EraEditorKey.enter, EraEditorKey.enter]);
    });

    testWidgets('a date box takes digits and part steps; Tab and Esc go to '
        'the host and focus stays', (tester) async {
      final keys = await _pump(tester);
      await _clickYear(tester);
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_form(tester).date, const LocalDate(2027, 10, 8));
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.digit1);
      await _press(tester, LogicalKeyboardKey.digit2);
      expect(_form(tester).date, const LocalDate(2027, 12, 8));
      await _chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.arrowUp,
      );
      await _press(tester, LogicalKeyboardKey.pageUp);
      await _press(tester, LogicalKeyboardKey.f4);
      expect(_form(tester).date, const LocalDate(2027, 12, 8));
      await _chord(
        tester,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.tab,
      );
      expect(_focused, 'EraDateField');
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(_focused, 'EraDateField');
      expect(keys, [EraEditorKey.tab, EraEditorKey.escape]);
    });

    testWidgets('Page Up/Down and modified arrows do not change a time', (
      tester,
    ) async {
      final keys = await _pump(tester);
      await _clickHours(tester);
      await _press(tester, LogicalKeyboardKey.pageUp);
      await _press(tester, LogicalKeyboardKey.pageDown);
      for (final modifier in [
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        for (final arrow in [
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
        ]) {
          await _chord(tester, modifier, arrow);
          expect(_form(tester).time, const LocalTime(7, 0), reason: '$arrow');
        }
      }
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_form(tester).time, const LocalTime(8, 0));
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.digit4);
      await _press(tester, LogicalKeyboardKey.digit5);
      expect(_form(tester).time, const LocalTime(8, 45));
      // ":" is typed with Shift on many layouts; it still moves on a part.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.semicolon, character: ':');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(_focused, 'EraTimeField');
      expect(keys, [EraEditorKey.enter, EraEditorKey.tab, EraEditorKey.escape]);
    });

    testWidgets('a calendar opens and picks by mouse; focus stays on the box', (
      tester,
    ) async {
      final keys = await _pump(tester);
      await _clickDropArrow(tester);
      expect(_calendar, findsOneWidget);
      expect(_focused, 'EraDateField');
      expect(_calendarTitle(tester), 'October 2026');
      await tester.tap(
        find.descendant(
          of: _calendar,
          matching: find.byKey(const ValueKey('era-calendar-next')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(_calendarTitle(tester), 'November 2026');
      await tester.tap(
        _day(const LocalDate(2026, 11, 17)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_calendar, findsNothing);
      expect(_form(tester).date, const LocalDate(2026, 11, 17));
      expect(_focused, 'EraDateField');
      expect(keys, isEmpty);
      // The pick is a draft: the next Enter goes to the host, and opens
      // nothing.
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_calendar, findsNothing);
      expect(keys, [EraEditorKey.enter]);
    });

    testWidgets('a click on a date part closes a mouse-opened calendar, so '
        'the part takes typing', (tester) async {
      final keys = await _pump(tester);
      await _clickDropArrow(tester);
      expect(_calendar, findsOneWidget);
      // "Thu 2026-10-08": the month is characters 9 to 11.
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(of: find.byKey(_date), matching: find.byType(RichText))
            .first,
      );
      final month = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 9, extentOffset: 11),
          )
          .first;
      await tester.tapAt(
        paragraph.localToGlobal(month.toRect().center),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_calendar, findsNothing);
      expect(_focused, 'EraDateField');
      await _press(tester, LogicalKeyboardKey.digit7);
      expect(_form(tester).date, const LocalDate(2026, 7, 8));
      expect(keys, isEmpty);
    });

    testWidgets('banned keys cannot operate a mouse-opened calendar; Enter, '
        'Tab and Esc close it without picking', (tester) async {
      final keys = await _pump(tester);
      for (final (close, reported) in [
        (LogicalKeyboardKey.enter, EraEditorKey.enter),
        (LogicalKeyboardKey.tab, EraEditorKey.tab),
        (LogicalKeyboardKey.escape, EraEditorKey.escape),
      ]) {
        await _clickDropArrow(tester);
        expect(_calendar, findsOneWidget);
        for (final key in [
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.pageDown,
          LogicalKeyboardKey.home,
          LogicalKeyboardKey.end,
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.digit5,
        ]) {
          await _press(tester, key);
        }
        await _chord(
          tester,
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.pageDown,
        );
        await _chord(
          tester,
          LogicalKeyboardKey.altLeft,
          LogicalKeyboardKey.arrowDown,
        );
        expect(_calendar, findsOneWidget);
        expect(_calendarTitle(tester), 'October 2026');
        expect(_form(tester).date, _today);
        expect(keys, isEmpty);
        await _press(tester, close);
        await tester.pumpAndSettle();
        expect(_calendar, findsNothing, reason: '$close');
        expect(_form(tester).date, _today, reason: '$close');
        expect(_focused, 'EraDateField');
        expect(keys, [reported]);
        keys.clear();
      }
    });

    testWidgets('a combo neither opens nor steps from the keyboard', (
      tester,
    ) async {
      final keys = await _pump(tester);
      await _clickCombo(tester);
      expect(_comboOpen, isTrue);
      await _press(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_comboOpen, isFalse);
      expect(keys, [EraEditorKey.escape]);
      expect(_focused, 'EraCombo');
      for (final key in [
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.f4,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
      ]) {
        await _press(tester, key);
      }
      await _chord(
        tester,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.arrowDown,
      );
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_comboOpen, isFalse);
      expect(_form(tester).combo, 'Pay periods');
      expect(_focused, 'EraCombo');
      expect(keys, [EraEditorKey.escape, EraEditorKey.enter, EraEditorKey.tab]);
    });

    testWidgets('a mouse-opened combo list cannot be operated by keys; Enter '
        'closes it without taking the lit row', (tester) async {
      final keys = await _pump(tester);
      // One mouse clicks and hovers throughout.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      Future<void> click(Finder target) async {
        await mouse.moveTo(tester.getCenter(target));
        await tester.pump();
        await mouse.down(tester.getCenter(target));
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();
      }

      Finder row(String label) => find.widgetWithText(MenuItemButton, label);
      final wash = LifeOSSkinScope.of(tester.element(find.byKey(_combo)))
          .tokens
          .selWash;
      // Which rows are lit, unfocused and unhovered as far as their own
      // state goes: the list lights them without focus.
      List<String> lit() => [
        for (final label in ['Shifts', 'Pay periods', 'Payslips'])
          if (tester
                  .widget<MenuItemButton>(row(label))
                  .style!
                  .backgroundColor!
                  .resolve(const {}) ==
              wash)
            label,
      ];

      await click(find.byKey(_combo));
      expect(_comboOpen, isTrue);
      expect(_focused, 'EraCombo');
      expect(lit(), ['Pay periods']);
      // The pointer lights a row; the keys must not take it.
      await mouse.moveTo(tester.getCenter(row('Payslips')));
      await tester.pump();
      expect(lit(), ['Payslips']);
      for (final key in [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.home,
      ]) {
        await _press(tester, key);
        expect(_focused, 'EraCombo', reason: '$key');
      }
      expect(_comboOpen, isTrue);
      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_comboOpen, isFalse);
      expect(_form(tester).combo, 'Pay periods');
      expect(keys, [EraEditorKey.enter]);
      // A click picks, and focus returns to the box.
      await click(find.byKey(_combo));
      await click(row('Shifts'));
      expect(_comboOpen, isFalse);
      expect(_form(tester).combo, 'Shifts');
      expect(_focused, 'EraCombo');
      expect(keys, [EraEditorKey.enter]);
    });

    testWidgets('check boxes and radios change only by mouse', (tester) async {
      final keys = await _pump(tester);
      await _focusInside(tester, find.byType(EraCheckBox));
      await _press(tester, LogicalKeyboardKey.space);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_form(tester).check, isTrue);
      await _focusInside(tester, find.byType(EraRadioGroup<String>));
      for (final key in [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.space,
      ]) {
        await _press(tester, key);
      }
      await _press(tester, LogicalKeyboardKey.tab);
      expect(_form(tester).radio, 'gross');
      expect(keys, [EraEditorKey.enter, EraEditorKey.tab]);
      await tester.tap(find.text('Paid'), kind: PointerDeviceKind.mouse);
      await tester.tap(find.text('Net'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(_form(tester).check, isFalse);
      expect(_form(tester).radio, 'net');
    });

    testWidgets('a text field types; Enter and Tab go to the host instead of '
        'its submit action or traversal', (tester) async {
      final submitted = <String>[];
      final keys = await _pump(tester, submitted: submitted);
      await tester.tap(find.byKey(_text));
      await tester.pump();
      final field = FocusManager.instance.primaryFocus;
      await tester.enterText(find.byKey(_text), 'Late shift');
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.tab);
      for (final modifier in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
      ]) {
        await _chord(tester, modifier, LogicalKeyboardKey.enter);
        await _chord(tester, modifier, LogicalKeyboardKey.tab);
      }
      for (final key in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.f2,
      ]) {
        await _press(tester, key);
      }
      await _press(tester, LogicalKeyboardKey.escape);
      expect(FocusManager.instance.primaryFocus, field);
      expect(_form(tester).note.text, 'Late shift');
      expect(submitted, isEmpty);
      expect(keys, [EraEditorKey.enter, EraEditorKey.tab, EraEditorKey.escape]);
      // The platform's own submit action does not commit either.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, isEmpty);
      expect(FocusManager.instance.primaryFocus, field);
      expect(keys, hasLength(3));
    });

    testWidgets('accepting an input method candidate is not Enter', (
      tester,
    ) async {
      final keys = await _pump(tester);
      await tester.tap(find.byKey(_text));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'かな',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.tab);
      expect(keys, isEmpty);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '仮名',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_form(tester).note.text, '仮名');
      expect(keys, [EraEditorKey.enter]);
    });

    testWidgets("an optional date box's check box ticks by mouse only", (
      tester,
    ) async {
      final keys = <EraEditorKey>[];
      final sent = <LocalDate?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: EraEditorHostScope(
                  onKey: keys.add,
                  child: SizedBox(
                    width: 400,
                    child: EraDateField(
                      label: 'Ends on',
                      value: _today,
                      today: _today,
                      optional: true,
                      fieldKey: _date,
                      onChanged: sent.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final check = find.byKey(const ValueKey('era-date-check'));
      await _focusInside(tester, check);
      expect(_focused, 'EraDateFieldCheck');
      await _press(tester, LogicalKeyboardKey.space);
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.tab);
      expect(sent, isEmpty);
      expect(_focused, 'EraDateFieldCheck');
      expect(keys, [EraEditorKey.enter, EraEditorKey.tab]);
      await tester.tap(check, kind: PointerDeviceKind.mouse);
      expect(sent, [null]);
    });

    testWidgets('an inline calendar moves and picks by mouse only', (
      tester,
    ) async {
      final keys = <EraEditorKey>[];
      final picked = <LocalDate>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: EraEditorHostScope(
                  onKey: keys.add,
                  child: EraMonthCalendar(
                    today: _today,
                    selected: _today,
                    autofocus: true,
                    onPicked: picked.add,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_focused, 'EraMonthCalendar');
      for (final key in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
      ]) {
        await _press(tester, key);
      }
      expect(_calendarTitle(tester), 'October 2026');
      expect(picked, isEmpty);
      expect(keys, [EraEditorKey.enter]);
      await tester.tap(
        _day(const LocalDate(2026, 10, 20)),
        kind: PointerDeviceKind.mouse,
      );
      expect(picked, [const LocalDate(2026, 10, 20)]);
    });

    testWidgets('a scope without a host callback still holds the keys', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: EraEditorHostScope(
                child: EraDateField(
                  label: 'Starts on',
                  value: _today,
                  today: _today,
                  fieldKey: _date,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await _clickYear(tester);
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_calendar, findsNothing);
      expect(_focused, 'EraDateField');
      expect(tester.takeException(), isNull);
    });
  });

  group('disabled controls change nothing', () {
    for (final hosted in [false, true]) {
      testWidgets(hosted ? 'in a host' : 'outside a host', (tester) async {
        final keys = await _pump(tester, hosted: hosted, enabled: false);
        await _clickDropArrow(tester);
        expect(_calendar, findsNothing);
        await _clickHours(tester);
        await _press(tester, LogicalKeyboardKey.arrowUp);
        await _press(tester, LogicalKeyboardKey.pageUp);
        await tester.tap(find.text('Paid'), kind: PointerDeviceKind.mouse);
        await tester.tap(find.text('Net'), kind: PointerDeviceKind.mouse);
        await tester.pump();
        final form = _form(tester);
        expect(form.date, _today);
        expect(form.time, const LocalTime(7, 0));
        expect(form.check, isTrue);
        expect(form.radio, 'gross');
        expect(keys, isEmpty);
        if (hosted) {
          // A hosted combo follows its form; a legacy one keeps its
          // existing behaviour.
          await _clickCombo(tester);
          expect(_comboOpen, isFalse);
          await _press(tester, LogicalKeyboardKey.enter);
          await _press(tester, LogicalKeyboardKey.arrowDown);
          expect(_form(tester).combo, 'Pay periods');
        }
      });
    }
  });
}
