import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/ui/ui.dart';

/// The opt-in trace of the era date boxes (bead lifeManager-7qj): off unless
/// LIFEOS_TRACE_DATES=1, one line per event in
/// ~/.local/share/lifeos/date-trace.log when on.

const _today = LocalDate(2026, 10, 5);

final class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  LocalDate value = _today;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: EraDateField(
      label: 'Starts on',
      value: value,
      today: _today,
      fieldKey: const ValueKey('starts-on'),
      onChanged: (picked) => setState(() => value = picked!),
    ),
  );
}

/// Opens the box with the mouse, pages ▸ once and picks the 12th of
/// November, as the owner would.
Future<void> _driveWithMouse(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: const LifeOSSkinScope(
        child: Scaffold(
          body: Align(alignment: Alignment.topCenter, child: _Host()),
        ),
      ),
    ),
  );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  Future<void> click(Finder target) async {
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 16));
    await mouse.down(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 96));
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 200));
  }

  await click(find.byKey(const ValueKey('era-date-drop')));
  await click(find.byKey(const ValueKey('era-calendar-next')));
  await click(find.byKey(const ValueKey('era-day-2026-11-12')));
  await tester.pumpAndSettle();
  expect(find.text('Thu 2026-11-12'), findsOneWidget);
}

void main() {
  late Directory home;

  setUp(() => home = Directory.systemTemp.createTempSync('lifeos-trace-'));
  tearDown(() {
    dateTrace?.close();
    dateTrace = null;
    home.deleteSync(recursive: true);
  });

  File logIn(Directory home) =>
      File('${home.path}/.local/share/lifeos/date-trace.log');

  test('the trace is off unless LIFEOS_TRACE_DATES is 1', () {
    expect(DateTrace.fromEnvironment({'HOME': home.path}), isNull);
    expect(
      DateTrace.fromEnvironment({'HOME': home.path, 'LIFEOS_TRACE_DATES': '0'}),
      isNull,
    );
    expect(logIn(home).existsSync(), isFalse);
  });

  test('on, it writes to ~/.local/share/lifeos/date-trace.log', () {
    final trace = DateTrace.fromEnvironment({
      'HOME': home.path,
      'LIFEOS_TRACE_DATES': '1',
    })!;
    addTearDown(trace.close);
    trace.log('Starts on', 'hello');
    final [line] = logIn(home).readAsLinesSync();
    expect(line, matches(RegExp(r'^\d{13} \[Starts on\] hello$')));
  });

  testWidgets('off, a mouse-driven box writes nothing', (tester) async {
    expect(dateTrace, isNull);
    await _driveWithMouse(tester);
    expect(home.listSync(recursive: true), isEmpty);
  });

  testWidgets('on, the box and its calendar log each event', (tester) async {
    dateTrace = DateTrace.fromEnvironment({
      'HOME': home.path,
      'LIFEOS_TRACE_DATES': '1',
    }, hooks: false);
    await _driveWithMouse(tester);
    final log = logIn(home).readAsStringSync();
    for (final event in [
      // The arrow click opens the calendar and hands it focus.
      RegExp(r'\[Starts on\] pointer down mouse buttons=1 .* on arrow'),
      RegExp(r'\[Starts on\] open \(click\)'),
      RegExp(r'\[Starts on\] anchor Rect\.fromLTRB'),
      RegExp(r'\[Starts on\] calendar created on 2026-10-05'),
      RegExp(r'\[Starts on\] calendar focus true'),
      // ▸ pages the cursor a month on.
      RegExp(r'\[Starts on\] calendar pointer down mouse buttons=1 .* on ▸'),
      RegExp(r'\[Starts on\] cursor 2026-10-05 → 2026-11-05 \(▸\)'),
      // The day click picks, sends and closes.
      RegExp(r'\[Starts on\] calendar pointer down .* on day 2026-11-12'),
      RegExp(r'\[Starts on\] pick 2026-11-12'),
      RegExp(r'\[Starts on\] onChanged 2026-11-12'),
      RegExp(r'\[Starts on\] close \(pick\)'),
      RegExp(r'\[Starts on\] value 2026-10-05 → 2026-11-12'),
      RegExp(r'\[Starts on\] calendar disposed'),
    ]) {
      expect(log, contains(event));
    }
  });

  testWidgets('on, the global hooks log lifecycle and focus', (tester) async {
    dateTrace = DateTrace.fromEnvironment({
      'HOME': home.path,
      'LIFEOS_TRACE_DATES': '1',
    });
    await _driveWithMouse(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final log = logIn(home).readAsStringSync();
    expect(log, contains(RegExp(r'\[app\] pointer down mouse buttons=1')));
    expect(log, contains(RegExp(r'\[app\] primary focus .*EraDateField')));
    expect(log, contains('[app] lifecycle AppLifecycleState.inactive'));
  });
}
