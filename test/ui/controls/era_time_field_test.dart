import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

const _box = ValueKey('start-time');

final class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    required this.emptyStart,
    required this.enabled,
  });

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
  Widget Function(Widget field)? wrap,
}) async {
  final host = _Host(initial: value, emptyStart: emptyStart, enabled: enabled);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: LifeOSSkinScope(
          child: Scaffold(body: Center(child: wrap?.call(host) ?? host)),
        ),
      ),
    ),
  );
}

LocalTime? _value(WidgetTester tester) =>
    tester.widget<EraTimeField>(find.byType(EraTimeField)).value;

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, [
  int times = 1,
]) async {
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
    expect(
      stepTime(const LocalTime(0, 0), TimePart.hour, -1),
      const LocalTime(23, 0),
    );
    expect(
      stepTime(const LocalTime(0, 5), TimePart.minute, -10),
      const LocalTime(0, 55),
    );
    expect(
      stepTime(const LocalTime(1, 2, 59), TimePart.second, 1),
      const LocalTime(1, 2, 0),
    );
  });

  testWidgets('the box shows hours and minutes and a spin pair', (
    tester,
  ) async {
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
      isSemantics(
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

  testWidgets('left on the hours and right on the minutes stay in the box', (
    tester,
  ) async {
    await _pump(
      tester,
      wrap: (field) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Focus(child: SizedBox(width: 24, height: 24)),
          field,
          const Focus(child: SizedBox(width: 24, height: 24)),
        ],
      ),
    );
    await _select(tester, 'hour');
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(8, 0));
    await _select(tester, 'minute');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(8, 1));
  });

  testWidgets('only the primary button steps or selects', (tester) async {
    await _pump(tester);
    for (final key in ['era-time-up', 'era-time-minute']) {
      for (final buttons in [kSecondaryButton, kMiddleMouseButton]) {
        final press = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey(key))),
          kind: PointerDeviceKind.mouse,
          buttons: buttons,
        );
        await press.up();
        await tester.pump();
      }
    }
    expect(_value(tester), const LocalTime(7, 0));
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      isNot('EraTimeField'),
    );
  });

  testWidgets('a spin button looks pressed while held', (tester) async {
    await _pump(tester);
    List<Color>? colors() =>
        (tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(const ValueKey('era-time-up')),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .gradient
            ?.colors;
    final resting = colors();
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('era-time-up'))),
    );
    await tester.pump();
    expect(colors(), resting!.reversed.toList());
    await hold.up();
    await tester.pump();
    expect(colors(), resting);
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
      isSemantics(label: 'Start time, not set'),
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

  Future<void> type(WidgetTester tester, String digits) async {
    const keys = {
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
      // The harness has no physical key for a colon; the period moves on too.
      ':': LogicalKeyboardKey.period,
    };
    for (final digit in digits.split('')) {
      await _press(tester, keys[digit]!);
    }
  }

  testWidgets('typing 1930 into the focused box sets 19:30', (tester) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '1930');
    expect(_value(tester), const LocalTime(19, 30));
  });

  testWidgets('730 sets 07:30: a 7 commits and moves on at once', (
    tester,
  ) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '730');
    expect(_value(tester), const LocalTime(7, 30));
  });

  testWidgets('a first digit shows at once and the numpad types too', (
    tester,
  ) async {
    await _pump(tester, value: const LocalTime(7, 15));
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.numpad1);
    expect(_value(tester), const LocalTime(1, 15));
    await _press(tester, LogicalKeyboardKey.numpad9);
    expect(_value(tester), const LocalTime(19, 15));
  });

  testWidgets('25 in the hours is no hour: the 5 starts again', (tester) async {
    await _pump(tester, value: const LocalTime(7, 15));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '25');
    expect(_value(tester), const LocalTime(5, 15));
    // The 5 committed and moved on: the next digit is the minutes'.
    await type(tester, '4');
    expect(_value(tester), const LocalTime(5, 4));
  });

  testWidgets('a minute of 60 or more starts again, as 7 does', (tester) async {
    await _pump(tester, value: const LocalTime(7, 0));
    await _select(tester, 'minute');
    await type(tester, '6');
    expect(_value(tester), const LocalTime(7, 6));
    await _select(tester, 'minute');
    await type(tester, '59');
    expect(_value(tester), const LocalTime(7, 59));
  });

  testWidgets('a colon moves to the next part and stays on the last', (
    tester,
  ) async {
    await _pump(tester, value: const LocalTime(7, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '1:');
    await type(tester, '2');
    expect(_value(tester), const LocalTime(1, 2));
    await type(tester, '::');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(1, 3));
  });

  testWidgets('backspace drops the pending digit and keeps the value', (
    tester,
  ) async {
    await _pump(tester, value: const LocalTime(7, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '1');
    await _press(tester, LogicalKeyboardKey.backspace);
    expect(_value(tester), const LocalTime(1, 0));
    // No first digit pends now: this 3 is a first digit and moves on.
    await type(tester, '3');
    expect(_value(tester), const LocalTime(3, 0));
  });

  testWidgets('an arrow after a pending digit clears it', (tester) async {
    await _pump(tester, value: const LocalTime(7, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '1');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_value(tester), const LocalTime(2, 0));
    // 2 is pending no more: this 3 starts afresh, not as 23.
    await type(tester, '3');
    expect(_value(tester), const LocalTime(3, 0));
  });

  testWidgets('choosing another part clears the pending digit', (tester) async {
    await _pump(tester, value: const LocalTime(7, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '1');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await type(tester, '2');
    expect(_value(tester), const LocalTime(2, 0));
  });

  testWidgets('losing focus clears the pending digit', (tester) async {
    await _pump(tester, value: const LocalTime(7, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '1');
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '2');
    expect(_value(tester), const LocalTime(2, 0));
  });

  testWidgets('a digit into an empty box starts from emptyStart', (
    tester,
  ) async {
    await _pump(tester, value: null, emptyStart: const LocalTime(0, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '8');
    expect(_value(tester), const LocalTime(8, 0));
  });

  testWidgets('a digit into an empty box leaves the other parts at 00', (
    tester,
  ) async {
    await _pump(tester, value: null, emptyStart: const LocalTime(19, 30));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '7');
    expect(_value(tester), const LocalTime(7, 0));
  });

  testWidgets('a held digit key types once', (tester) async {
    await _pump(tester, value: const LocalTime(7, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(_value(tester), const LocalTime(1, 0));
    // The 1 still waits for its second digit.
    await type(tester, '9');
    expect(_value(tester), const LocalTime(19, 0));
  });

  testWidgets('a value set from outside clears the pending digit', (
    tester,
  ) async {
    LocalTime? sent;
    Future<void> show(LocalTime value) => tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: EraTimeField(
              label: 'Start time',
              value: value,
              onChanged: (next) => sent = next,
            ),
          ),
        ),
      ),
    );
    await show(const LocalTime(7, 0));
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '1');
    expect(sent, const LocalTime(1, 0));
    await show(const LocalTime(9, 0));
    await type(tester, '2');
    expect(sent, const LocalTime(2, 0));
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
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.digit1);
    // The host rebuilds still on 07:00, then takes 01:00.
    expect(_value(tester), const LocalTime(7, 0));
    host.currentState!.apply();
    await tester.pump();
    expect(_value(tester), const LocalTime(1, 0));
    await _press(tester, LogicalKeyboardKey.digit9);
    host.currentState!.apply();
    await tester.pump();
    expect(_value(tester), const LocalTime(19, 0));
  });

  testWidgets('a disabled box ignores digits', (tester) async {
    await _pump(tester, enabled: false);
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '19');
    expect(_value(tester), const LocalTime(7, 0));
  });

  testWidgets('a read-only form ignores digits', (tester) async {
    await _pump(
      tester,
      wrap: (field) => EraFormScope(enabled: false, child: field),
    );
    await _press(tester, LogicalKeyboardKey.tab);
    await type(tester, '19');
    expect(_value(tester), const LocalTime(7, 0));
  });

  testWidgets('Tab and letters stay with the focus system', (tester) async {
    await _pump(tester);
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.keyA);
    expect(_value(tester), const LocalTime(7, 0));
  });

  testWidgets('the box holds at 200 % text', (tester) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('07'), findsOneWidget);
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
  LocalTime value = const LocalTime(7, 0);
  LocalTime? waiting;

  void apply() => setState(() => value = waiting ?? value);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: EraTimeField(
      label: 'Start time',
      value: value,
      fieldKey: _box,
      onChanged: (next) => setState(() => waiting = next),
    ),
  );
}
