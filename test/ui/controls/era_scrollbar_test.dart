import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_scrollbar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

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
}
