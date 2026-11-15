import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

Widget _host(Widget child, {double width = 640}) => MaterialApp(
  home: LifeOSSkinScope(
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

FilterStrip _strip({VoidCallback? onClear}) => FilterStrip(
  items: const [
    FilterStripItem(label: 'Period', child: SizedBox(width: 120, height: 20)),
    FilterStripItem(label: 'Status', child: SizedBox(width: 90, height: 20)),
    FilterStripItem(label: 'Type', child: SizedBox(width: 70, height: 20)),
    FilterStripItem(child: Text('Off days')),
  ],
  onClear: onClear,
);

void main() {
  testWidgets('items wrap and Clear stays at the right', (tester) async {
    await tester.pumpWidget(_host(_strip(onClear: () {}), width: 320));
    final strip = tester.getRect(find.byType(FilterStrip));
    final period = tester.getRect(find.text('Period:'));
    final off = tester.getRect(find.text('Off days'));
    expect(off.top, greaterThan(period.top), reason: 'wrapped');
    final clear = tester.getRect(find.widgetWithText(KeyButton, 'Clear'));
    expect(strip.right - clear.right, lessThanOrEqualTo(8));
    expect(clear.top, lessThan(off.top), reason: 'on the first row');
  });

  testWidgets('one row at full width, at least the pane header tall', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_strip(onClear: () {}), width: 1200));
    final strip = tester.getRect(find.byType(FilterStrip));
    expect(strip.height, greaterThanOrEqualTo(LifeOSMetrics.paneHeader));
    expect(
      tester.getRect(find.text('Off days')).top,
      closeTo(tester.getRect(find.text('Period:')).top, 4),
    );
  });

  testWidgets('Clear greys without onClear and runs with one', (tester) async {
    await tester.pumpWidget(_host(_strip()));
    expect(
      tester
          .widget<KeyButton>(find.widgetWithText(KeyButton, 'Clear'))
          .onPressed,
      isNull,
    );
    var cleared = 0;
    await tester.pumpWidget(_host(_strip(onClear: () => cleared++)));
    await tester.tap(find.text('Clear'));
    expect(cleared, 1);
  });

  testWidgets('labels read "Label:"', (tester) async {
    await tester.pumpWidget(_host(_strip()));
    expect(find.text('Status:'), findsOneWidget);
    expect(find.text('Type:'), findsOneWidget);
  });

  testWidgets('only editor items take keyboard focus', (tester) async {
    final control = FocusNode();
    final editor = FocusNode();
    addTearDown(control.dispose);
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      _host(
        FilterStrip(
          items: [
            FilterStripItem(
              label: 'Status',
              child: Focus(focusNode: control, child: const Text('combo')),
            ),
            FilterStripItem(
              label: 'From',
              editor: true,
              child: Focus(focusNode: editor, child: const Text('date')),
            ),
          ],
        ),
      ),
    );
    control.requestFocus();
    await tester.pump();
    expect(control.hasFocus, isFalse);
    editor.requestFocus();
    await tester.pump();
    expect(editor.hasFocus, isTrue);
  });
}
