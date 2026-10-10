import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/trailing_frame.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/ui/ui.dart';

/// With a real mouse on the owner's desktop (KDE Plasma on Wayland, an
/// NVIDIA card), the window showed each frame only once the next was drawn
/// (bead lifeManager-7qj). A click on the calendar's ▸ drew exactly one
/// frame, and the screen kept the month before it until something else
/// repainted: the trace said December, the screen said November. The app's
/// binding therefore draws one more frame after the last frame of every
/// change, which carries that change to the screen.

final class _Binding extends AutomatedTestWidgetsFlutterBinding
    with TrailingFrame {}

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

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('era-calendar-title'))).data!;

/// Opens the calendar with the drop arrow and leaves the mouse resting on
/// ▸, everything drawn.
Future<TestGesture> _openOnNext(WidgetTester tester) async {
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
  final drop = tester.getCenter(find.byKey(const ValueKey('era-date-drop')));
  await mouse.moveTo(drop);
  await mouse.down(drop);
  await tester.pump(const Duration(milliseconds: 90));
  await mouse.up();
  await tester.pumpAndSettle();
  await mouse.moveTo(
    tester.getCenter(find.byKey(const ValueKey('era-calendar-next'))),
  );
  await tester.pumpAndSettle();
  expect(_title(tester), 'October 2026');
  return mouse;
}

/// A click as the virtual mouse made it: pressed 90 ms, released, and no
/// frame in between that changes anything.
Future<void> _click(WidgetTester tester, TestGesture mouse) async {
  await mouse.down(
    tester.getCenter(find.byKey(const ValueKey('era-calendar-next'))),
  );
  await tester.pump(const Duration(milliseconds: 90));
  await mouse.up();
}

void main() {
  final binding = _Binding();

  testWidgets('a click on ▸ draws its frame, then one more, then nothing', (
    tester,
  ) async {
    final mouse = await _openOnNext(tester);
    await _click(tester, mouse);
    expect(binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 6));
    expect(_title(tester), 'November 2026');
    // The trace showed this was the only frame the click drew, and the
    // screen kept October: a trailing frame must follow it.
    expect(binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 6));
    expect(_title(tester), 'November 2026');
    // The trailing frame changes nothing and asks for no other.
    expect(binding.hasScheduledFrame, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'a click landing before the trailing frame gets a trailing frame too',
    (tester) async {
      final mouse = await _openOnNext(tester);
      await _click(tester, mouse);
      await tester.pump(const Duration(milliseconds: 6));
      expect(binding.hasScheduledFrame, isTrue);
      // The second click comes while only the trailing frame is pending, so
      // that frame is its frame: another must follow.
      final next = tester.getCenter(
        find.byKey(const ValueKey('era-calendar-next')),
      );
      await mouse.down(next);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 6));
      expect(_title(tester), 'December 2026');
      expect(binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 6));
      expect(binding.hasScheduledFrame, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('an idle window draws no frames', (tester) async {
    await _openOnNext(tester);
    expect(binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(binding.hasScheduledFrame, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
