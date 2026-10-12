import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/record_navigator_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

Widget _host(Widget child, {double textScale = 1}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: MaterialApp(
    home: LifeOSSkinScope(
      child: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

Finder _key(String name) => find.byKey(ValueKey('record-$name'));

bool _enabled(WidgetTester tester, String name) => tester
    .widget<Semantics>(
      find.ancestor(of: _key(name), matching: find.byType(Semantics)).first,
    )
    .properties
    .enabled!;

void main() {
  late List<int> went;
  late int news;

  RecordNavigator nav(
    int position,
    int count, {
    bool go = true,
    bool allowNew = true,
    String? note,
  }) => RecordNavigator(
    label: 'Shifts',
    position: position,
    count: count,
    onGo: go ? (target) => went.add(target) : null,
    onNew: allowNew ? () => news++ : null,
    note: note,
  );

  setUp(() {
    went = [];
    news = 0;
  });

  Future<void> tapKey(WidgetTester tester, String name) async {
    await tester.tap(_key(name));
    await tester.pump();
  }

  group('position text', () {
    testWidgets('empty data shows 0 of 0 and moves nowhere', (tester) async {
      await tester.pumpWidget(_host(nav(0, 0)));
      expect(find.text('0 of 0'), findsOneWidget);
      for (final name in ['first', 'previous', 'next', 'last']) {
        await tapKey(tester, name);
        expect(_enabled(tester, name), isFalse, reason: name);
      }
      expect(went, isEmpty);
      expect(_enabled(tester, 'add'), isTrue);
    });

    testWidgets('one record: all moves disabled', (tester) async {
      await tester.pumpWidget(_host(nav(1, 1)));
      expect(find.text('1 of 1'), findsOneWidget);
      for (final name in ['first', 'previous', 'next', 'last']) {
        await tapKey(tester, name);
      }
      expect(went, isEmpty);
    });

    testWidgets('no selection among many shows 0 of N', (tester) async {
      await tester.pumpWidget(_host(nav(0, 4)));
      expect(find.text('0 of 4'), findsOneWidget);
      await tapKey(tester, 'previous');
      expect(went, isEmpty);
      await tapKey(tester, 'next');
      await tapKey(tester, 'first');
      await tapKey(tester, 'last');
      expect(went, [1, 1, 4]);
    });

    testWidgets('the position is a read-only box, not an editor', (
      tester,
    ) async {
      await tester.pumpWidget(_host(nav(2, 9)));
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('2 of 9'), findsOneWidget);
    });
  });

  group('moves', () {
    testWidgets('middle record emits targets within 1..count', (tester) async {
      await tester.pumpWidget(_host(nav(3, 5)));
      for (final name in ['first', 'previous', 'next', 'last']) {
        await tapKey(tester, name);
      }
      expect(went, [1, 2, 4, 5]);
      expect(went, everyElement(inInclusiveRange(1, 5)));
    });

    testWidgets('first and previous are off at 1', (tester) async {
      await tester.pumpWidget(_host(nav(1, 5)));
      await tapKey(tester, 'first');
      await tapKey(tester, 'previous');
      expect(went, isEmpty);
      await tapKey(tester, 'next');
      await tapKey(tester, 'last');
      expect(went, [2, 5]);
    });

    testWidgets('next and last are off at the end', (tester) async {
      await tester.pumpWidget(_host(nav(5, 5)));
      await tapKey(tester, 'next');
      await tapKey(tester, 'last');
      expect(went, isEmpty);
      await tapKey(tester, 'previous');
      await tapKey(tester, 'first');
      expect(went, [4, 1]);
    });

    testWidgets('a null onGo disables every move but not nothing else', (
      tester,
    ) async {
      await tester.pumpWidget(_host(nav(3, 5, go: false)));
      for (final name in ['first', 'previous', 'next', 'last']) {
        await tapKey(tester, name);
        expect(_enabled(tester, name), isFalse, reason: name);
      }
      expect(went, isEmpty);
      await tapKey(tester, 'add');
      expect(news, 1);
    });

    testWidgets('keys are 24 px click targets', (tester) async {
      await tester.pumpWidget(_host(nav(3, 5)));
      for (final name in ['first', 'previous', 'next', 'last', 'add']) {
        expect(tester.getSize(_key(name)), const Size(24, 24), reason: name);
      }
    });
  });

  group('new', () {
    testWidgets('needs a callback', (tester) async {
      await tester.pumpWidget(_host(nav(3, 5, allowNew: false)));
      await tapKey(tester, 'add');
      expect(news, 0);
      expect(_enabled(tester, 'add'), isFalse);
    });

    testWidgets('is off in a locked form scope, moves stay on', (tester) async {
      await tester.pumpWidget(
        _host(EraFormScope(enabled: false, child: nav(3, 5))),
      );
      await tapKey(tester, 'add');
      expect(news, 0);
      expect(_enabled(tester, 'add'), isFalse);
      await tapKey(tester, 'next');
      expect(went, [4]);
    });

    testWidgets('fires once per click', (tester) async {
      await tester.pumpWidget(_host(nav(3, 5)));
      await tapKey(tester, 'add');
      expect(news, 1);
    });
  });

  group('keyboard', () {
    testWidgets('keys take no focus and ignore keys', (tester) async {
      await tester.pumpWidget(_host(nav(3, 5)));
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.context, isNotNull);
        expect(
          find.descendant(
            of: find.byType(RecordNavigator),
            matching: find.byType(Focus),
          ),
          findsNothing,
        );
      }
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.pageDown,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await tester.pump();
      expect(went, isEmpty);
      expect(news, 0);
    });

    testWidgets('no focus highlight or focusable action detector', (
      tester,
    ) async {
      await tester.pumpWidget(_host(nav(3, 5)));
      expect(
        find.descendant(
          of: find.byType(RecordNavigator),
          matching: find.byType(FocusableActionDetector),
        ),
        findsNothing,
      );
    });
  });

  group('layout', () {
    testWidgets('has a finite intrinsic width in an unbounded parent', (
      tester,
    ) async {
      const long =
          'Filtered: open shifts in October 2026 for the night team, '
          'excluding planned and cancelled days and everything else too';
      await tester.pumpWidget(_host(Row(children: [nav(3, 12, note: long)])));
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(RecordNavigator));
      expect(size.width, lessThanOrEqualTo(RecordNavigator.noteWidth));
      expect(size.height, greaterThan(50));
    });

    testWidgets('works under IntrinsicWidth and UnconstrainedBox', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              IntrinsicWidth(child: nav(3, 12, note: 'Open')),
              UnconstrainedBox(child: nav(3, 12, note: 'Open')),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long note wraps at narrow width and 200 % text', (
      tester,
    ) async {
      const long =
          'Filtered: open shifts in October 2026 for the night team, '
          'excluding planned and cancelled days';
      await tester.pumpWidget(
        _host(
          SizedBox(width: 280, child: nav(3, 12, note: long)),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(RecordNavigator)).width,
        lessThanOrEqualTo(280),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('record-note'))).height,
        greaterThan(40),
      );
    });

    testWidgets('narrow width at 100 % text does not overflow', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(width: 200, child: nav(10, 120, note: 'A long note ' * 8)),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('asserts input bounds', () {
    expect(() => nav(6, 5), throwsAssertionError);
    expect(() => nav(-1, 5), throwsAssertionError);
    expect(() => nav(1, 0), throwsAssertionError);
    expect(() => nav(0, -1), throwsAssertionError);
  });

  group('gallery demo', () {
    final demo = recordNavigatorDemo;

    testWidgets('Enabled off: tapping every key changes nothing', (
      tester,
    ) async {
      await pumpGalleryDemo(
        tester,
        demo,
        knobs: const GalleryKnobs(enabled: false),
      );
      for (final name in ['first', 'previous', 'next', 'last', 'add']) {
        await tester.tap(_key(name).first);
        await tester.pump();
      }
      expect(find.text('3 of 12'), findsOneWidget);
      expect(find.text('13 of 13'), findsNothing);
    });

    testWidgets('Enabled on: new appends and selects a record', (tester) async {
      await pumpGalleryDemo(tester, demo);
      await tester.tap(_key('add').first);
      await tester.pump();
      expect(find.text('13 of 13'), findsOneWidget);
    });

    testWidgets('Enabled on moves the position', (tester) async {
      await pumpGalleryDemo(tester, demo);
      await tester.tap(find.byKey(const ValueKey('record-next')).first);
      await tester.pump();
      expect(find.text('4 of 12'), findsOneWidget);
    });
  });
}
