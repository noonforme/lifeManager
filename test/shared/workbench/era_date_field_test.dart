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
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(_box));
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    final box = tester.getRect(find.byKey(_box));
    final calendar = tester.getRect(_calendar);
    expect(calendar.left, moreOrLessEquals(box.left, epsilon: 0.5));
    expect(calendar.top, moreOrLessEquals(box.bottom, epsilon: 0.5));
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
