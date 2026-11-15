import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

Widget _host(Widget child) => MaterialApp(
  scrollBehavior: const EraScrollBehavior(),
  home: LifeOSSkinScope(
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

Widget _list(int count, ScrollController controller) => SizedBox(
  height: 200,
  width: 300,
  child: ListView(
    controller: controller,
    children: [
      for (var i = 0; i < count; i++)
        SizedBox(height: 20, child: Text('Row $i')),
    ],
  ),
);

/// [child] without the bar the app's scroll behaviour would add: the test
/// draws its own.
Widget _ownBarOnly(Widget child) => Builder(
  builder: (context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: child,
  ),
);

const _thumb = ValueKey('era-scrollbar-thumb');
const _track = ValueKey('era-scrollbar-track');

void main() {
  testWidgets('a list that overflows gets a 17 px bar; a short one none', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_list(100, controller)));
    await tester.pump();
    expect(find.byKey(_thumb), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('era-scrollbar'))).width,
      EraScrollbar.thickness,
    );
    final short = ScrollController();
    addTearDown(short.dispose);
    await tester.pumpWidget(_host(_list(3, short)));
    await tester.pump();
    expect(find.byKey(_thumb), findsNothing);
  });

  testWidgets('arrows step a row; the track pages', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_list(100, controller)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('era-scrollbar-forward')));
    await tester.pump();
    expect(controller.offset, 20);
    final track = tester.getRect(find.byKey(_track));
    await tester.tapAt(Offset(track.center.dx, track.bottom - 4));
    await tester.pump();
    expect(controller.offset, greaterThanOrEqualTo(200));
  });

  testWidgets('dragging the thumb scrolls', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_list(100, controller)));
    await tester.pump();
    await tester.drag(find.byKey(_thumb), const Offset(0, 40));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('a one-line text field never gets a bar', (tester) async {
    final text = TextEditingController(text: 'x' * 200);
    addTearDown(text.dispose);
    await tester.pumpWidget(
      _host(SizedBox(width: 80, child: TextField(controller: text))),
    );
    await tester.pump();
    expect(find.byKey(_thumb), findsNothing);
  });

  for (final axis in Axis.values) {
    for (final length in [31.4, 34.0, 80.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$axis rail $length px at $scale text fits and scrolls', (
          tester,
        ) async {
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final vertical = axis == Axis.vertical;
          await tester.pumpWidget(
            _host(
              MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: vertical ? 160 : length,
                  height: vertical ? length : 60,
                  child: ListView(
                    controller: controller,
                    scrollDirection: axis,
                    padding: EdgeInsets.zero,
                    children: const [
                      SizedBox(width: 1000, height: 1000, child: Text('Rows')),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final bar = tester.getRect(
            find.byKey(const ValueKey('era-scrollbar')),
          );
          final back = find.byKey(const ValueKey('era-scrollbar-back'));
          final forward = find.byKey(const ValueKey('era-scrollbar-forward'));
          final backRect = tester.getRect(back);
          final forwardRect = tester.getRect(forward);
          expect(vertical ? bar.width : bar.height, EraScrollbar.thickness);
          expect(bar.contains(backRect.center), isTrue);
          expect(bar.contains(forwardRect.center), isTrue);
          expect(
            vertical ? backRect.bottom : backRect.right,
            lessThanOrEqualTo(vertical ? forwardRect.top : forwardRect.left),
          );
          if (length >= 2 * EraScrollbar.thickness) {
            expect(backRect.size, const Size(17, 17));
            expect(forwardRect.size, const Size(17, 17));
          }
          expect(forward.hitTestable(), findsOneWidget);
          await tester.tap(forward, kind: PointerDeviceKind.mouse);
          await tester.pumpAndSettle();
          expect(controller.offset, EraScrollbar.step);
          await tester.tap(back, kind: PointerDeviceKind.mouse);
          await tester.pumpAndSettle();
          expect(controller.offset, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('content that is taller when wider does not flip the bar on '
      'every frame; the bar stays until the box changes size', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    // Without the bar the content is 210 wide and 120 tall: it overflows.
    // With it, 193 wide and 90 tall: it fits. Text that wraps at a hyphen
    // can do this.
    Widget box(double height) => SizedBox(
      width: 210,
      height: height,
      child: EraScrollbar(
        controller: controller,
        axis: Axis.vertical,
        child: _ownBarOnly(
          SingleChildScrollView(
            controller: controller,
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  SizedBox(height: constraints.maxWidth >= 200 ? 120 : 90),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(_host(box(100)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-scrollbar')), findsOneWidget);
    // A taller box: nothing overflows, with or without the bar.
    await tester.pumpWidget(_host(box(150)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-scrollbar')), findsNothing);
  });
  testWidgets('new content that fits releases a pin at the same box size', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget box(bool flipping) => SizedBox(
      width: 210,
      height: 100,
      child: EraScrollbar(
        controller: controller,
        axis: Axis.vertical,
        child: _ownBarOnly(
          SingleChildScrollView(
            controller: controller,
            child: LayoutBuilder(
              builder: (_, constraints) => SizedBox(
                height: flipping
                    ? (constraints.maxWidth >= 200 ? 120 : 90)
                    : 60,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(_host(box(true)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-scrollbar')), findsOneWidget);
    await tester.pumpWidget(_host(box(false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-scrollbar')), findsNothing);
  });

  testWidgets('content that overflows again later is not pinned', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget box(int count) => SizedBox(
      width: 210,
      height: 100,
      child: EraScrollbar(
        controller: controller,
        axis: Axis.vertical,
        child: _ownBarOnly(
          SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                for (var i = 0; i < count; i++) const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(_host(box(10)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-scrollbar')), findsOneWidget);
    await tester.pumpWidget(_host(box(2)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-scrollbar')), findsNothing);
    await tester.pumpWidget(_host(box(10)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(box(2)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-scrollbar')), findsNothing);
  });
}
