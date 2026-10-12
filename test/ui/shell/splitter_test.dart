import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/splitter_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

/// A parent that applies and clamps what the splitter reports, as AppFrame
/// does: the size is `sizeAtPress + offset`, clamped to [lo, hi].
final class _Parent extends StatefulWidget {
  const _Parent({required this.axis, required this.log});

  final Axis axis;
  final List<String> log;

  @override
  State<_Parent> createState() => _ParentState();
}

final class _ParentState extends State<_Parent> {
  double size = 100;
  double _start = 100;

  @override
  Widget build(BuildContext context) {
    final splitter = Splitter(
      axis: widget.axis,
      onDragStart: () {
        _start = size;
        widget.log.add('start');
      },
      onDrag: (offset) {
        widget.log.add('drag ${offset.toStringAsFixed(1)}');
        setState(() => size = (_start + offset).clamp(50, 250));
      },
      onDragEnd: () => widget.log.add('end $size'),
    );
    final first = SizedBox(
      key: const ValueKey('first'),
      width: widget.axis == Axis.horizontal ? size : null,
      height: widget.axis == Axis.vertical ? size : null,
    );
    const second = Expanded(child: SizedBox(key: ValueKey('second')));
    return SizedBox(
      width: 600,
      height: 400,
      child: widget.axis == Axis.horizontal
          ? Row(children: [first, splitter, second])
          : Column(children: [first, splitter, second]),
    );
  }
}

Widget _host(Widget child) => MaterialApp(
  home: LifeOSSkinScope(
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

Future<TestGesture> _mouseDown(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: at);
  await tester.pump();
  await gesture.down(at);
  await tester.pump();
  return gesture;
}

Future<void> _dragTo(
  WidgetTester tester,
  TestGesture gesture,
  Offset from,
  Offset to, {
  int steps = 6,
}) async {
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump();
  }
}

void main() {
  for (final axis in Axis.values) {
    final horizontal = axis == Axis.horizontal;
    double along(Rect r) => horizontal ? r.width : r.height;
    Offset shift(Offset o, double d) =>
        horizontal ? o + Offset(d, 0) : o + Offset(0, d);

    testWidgets(
      '$axis: a 5 px bar that fills the cross axis, with its cursor',
      (tester) async {
        await tester.pumpWidget(_host(_Parent(axis: axis, log: [])));
        final rect = tester.getRect(find.byType(Splitter));
        expect(horizontal ? rect.width : rect.height, 5);
        expect(horizontal ? rect.height : rect.width, horizontal ? 400 : 600);
        final region = tester.widget<MouseRegion>(
          find.descendant(
            of: find.byType(Splitter),
            matching: find.byType(MouseRegion),
          ),
        );
        expect(
          region.cursor,
          horizontal
              ? SystemMouseCursors.resizeColumn
              : SystemMouseCursors.resizeRow,
        );
      },
    );

    testWidgets('$axis: a mouse drag moves the pane by exactly the pointer', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(_host(_Parent(axis: axis, log: log)));
      final from = tester.getCenter(find.byType(Splitter));
      final gesture = await _mouseDown(tester, from);
      await _dragTo(tester, gesture, from, shift(from, 60));
      expect(
        along(tester.getRect(find.byKey(const ValueKey('first')))),
        160,
        reason: 'the first pixels count: no touch slop is swallowed',
      );
      await gesture.up();
      await tester.pump();
      expect(log.first, 'start');
      expect(log.last, 'end 160.0', reason: 'reported equals applied');
      expect(log.where((e) => e.startsWith('drag')).length, greaterThan(3));
      // The cross-axis movement reports nothing.
      log.clear();
      await gesture.down(tester.getCenter(find.byType(Splitter)));
      await gesture.moveBy(
        horizontal ? const Offset(0, 30) : const Offset(30, 0),
      );
      await tester.pump();
      expect(log.where((e) => e.startsWith('drag')), isEmpty);
      await gesture.up();
    });

    testWidgets(
      '$axis: dragging far past either clamp and back is reversible',
      (tester) async {
        final log = <String>[];
        await tester.pumpWidget(_host(_Parent(axis: axis, log: log)));
        final from = tester.getCenter(find.byType(Splitter));
        final gesture = await _mouseDown(tester, from);
        double first() =>
            along(tester.getRect(find.byKey(const ValueKey('first'))));
        await _dragTo(tester, gesture, from, shift(from, 500));
        expect(first(), 250, reason: 'clamped at the high end');
        await _dragTo(tester, gesture, shift(from, 500), shift(from, 100));
        expect(first(), 200, reason: 'follows the pointer once back in range');
        await _dragTo(tester, gesture, shift(from, 100), shift(from, -500));
        expect(first(), 50, reason: 'clamped at the low end');
        await _dragTo(tester, gesture, shift(from, -500), shift(from, -20));
        expect(first(), 80);
        await gesture.up();
        await tester.pump();
        expect(log.last, 'end 80.0');
      },
    );

    testWidgets('$axis: the keyboard does nothing to a splitter', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(_host(_Parent(axis: axis, log: log)));
      for (final key in [
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      expect(log, isEmpty);
      expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      expect(
        find.descendant(
          of: find.byType(Splitter),
          matching: find.byType(Focus),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('a secondary-button press does not start a drag', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_host(_Parent(axis: Axis.horizontal, log: log)));
    final from = tester.getCenter(find.byType(Splitter));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.addPointer(location: from);
    await gesture.down(from);
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    expect(log, isEmpty);
  });

  testWidgets('a cancelled drag still reports its end', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_host(_Parent(axis: Axis.horizontal, log: log)));
    final from = tester.getCenter(find.byType(Splitter));
    final gesture = await _mouseDown(tester, from);
    await gesture.moveBy(const Offset(20, 0));
    await gesture.cancel();
    await tester.pump();
    expect(log.last, startsWith('end'));
  });

  testWidgets('it is announced by its label', (tester) async {
    await tester.pumpWidget(_host(_Parent(axis: Axis.horizontal, log: [])));
    expect(find.bySemanticsLabel('Resize panes'), findsOneWidget);
  });

  testWidgets('the demo drags and clamps by mouse', (tester) async {
    await pumpGalleryDemo(tester, splitterDemo);
    final bar = find.byType(Splitter).first;
    final from = tester.getCenter(bar);
    final gesture = await _mouseDown(tester, from);
    await _dragTo(tester, gesture, from, from + const Offset(500, 0));
    await gesture.up();
    await tester.pump();
    expect(tester.getRect(bar).left, lessThan(440));
    expect(find.text('Left 395 px'), findsOneWidget);
  });
}
