import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

const _longNotice =
    'Unsaved plan change: 2026-10-07, End 19:00 → 19:45. Save, or leave the '
    'day, to keep it. Confirmation is separate. Unsaved plan change: '
    '2026-10-08, Start 06:00 → 06:30. Save, or leave the day, to keep it.';

const _panels = [
  StatusPanel('15 shifts (synthetic depot, October 2026)'),
  StatusPanel('Break 1:15'),
  StatusPanel('Paid 112:30'),
  StatusPanel('Night 24:00'),
  StatusPanel('Holiday 8:00'),
  StatusPanel('Est. pay EUR 2,070.00'),
  StatusPanel('Local database'),
];

void main() {
  /// Sizes the test surface as the window, at 1 px per logical pixel.
  void window(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// A bounded page: a Column with the status bar under filler.
  Widget page(Widget bar, {required Size size, double scale = 1}) => MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    key: const ValueKey('content'),
                    color: const Color(0xffffffff),
                  ),
                ),
                bar,
              ],
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a short notice and panels share one 22 px row', (tester) async {
    window(tester, const Size(1280, 800));
    await tester.pumpWidget(
      page(
        const StatusBar(
          notice: 'Saved.',
          panels: [StatusPanel('15 shifts'), StatusPanel('Local database')],
        ),
        size: const Size(1280, 800),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StatusBar)).height, 22);
    expect(
      tester.getTopLeft(find.text('15 shifts')).dy,
      tester.getTopLeft(find.text('Local database')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Saved.')).dy,
      tester.getTopLeft(find.text('15 shifts')).dy,
    );
  });

  for (final size in const [Size(640, 480), Size(800, 600), Size(1280, 800)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('a long notice and many totals stay bounded at '
          '${size.width.toInt()} wide and ${scale * 100} % text', (
        tester,
      ) async {
        window(tester, size);
        await tester.pumpWidget(
          page(
            const StatusBar(
              notice: _longNotice,
              panels: _panels,
              warning: '3 days to confirm',
            ),
            size: size,
            scale: scale,
          ),
        );
        expect(tester.takeException(), isNull, reason: 'no flex overflow');
        final bar = tester.getRect(find.byType(StatusBar));
        expect(bar.width, size.width);
        expect(bar.height, greaterThanOrEqualTo(22));
        expect(bar.height, lessThanOrEqualTo(size.height * 0.3 + 0.01));
        expect(
          tester.getSize(find.byKey(const ValueKey('content'))).height,
          greaterThanOrEqualTo(size.height * 0.7 - 0.01),
          reason: 'the bar cannot consume the page',
        );
        // Every panel text sits inside the bar.
        for (final panel in _panels) {
          final text = find.text(panel.text);
          if (tester.any(text)) {
            final rect = tester.getRect(text);
            expect(rect.left, greaterThanOrEqualTo(bar.left));
            expect(rect.right, lessThanOrEqualTo(bar.right));
          }
        }
      });
    }
  }

  testWidgets('an unusually long notice is capped and scrolls in the bar', (
    tester,
  ) async {
    window(tester, const Size(800, 600));
    final notice = List.filled(60, _longNotice).join(' ');
    await tester.pumpWidget(
      page(
        StatusBar(notice: notice, panels: _panels),
        size: const Size(800, 600),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(StatusBar)).height,
      lessThanOrEqualTo(180),
    );
    expect(find.byType(CustomScrollView), findsNWidgets(2));
    final before = tester.getTopLeft(find.text(notice));
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text(notice)).dy, lessThan(before.dy));
    expect(find.byKey(const ValueKey('era-scrollbar')), findsWidgets);
  });

  testWidgets('one very long panel wraps inside the bar', (tester) async {
    final text = 'Panel ${'wide ' * 80}';
    await tester.pumpWidget(
      page(
        StatusBar(notice: 'Saved.', panels: [StatusPanel(text.trim())]),
        size: const Size(640, 480),
      ),
    );
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(StatusBar));
    final panel = tester.getRect(find.text(text.trim()));
    expect(panel.right, lessThanOrEqualTo(bar.right - 16));
    expect(bar.height, lessThanOrEqualTo(480 * 0.3 + 0.01));
  });

  testWidgets('the size grip is a fixed decorative mark', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      page(
        const StatusBar(notice: 'Saved.', panels: [StatusPanel('Local')]),
        size: const Size(640, 480),
      ),
    );
    final grip = find.descendant(
      of: find.byType(StatusBar),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == Size.zero && w.painter != null,
      ),
    );
    expect(tester.getSize(grip.first), const Size(16, 16));
    expect(tester.getBottomRight(grip.first).dx, 640 - 2);
    // Not in the semantics tree, and absent when switched off.
    expect(find.bySemanticsLabel('Local'), findsOneWidget);
    await tester.pumpWidget(
      page(
        const StatusBar(notice: 'Saved.', sizeGrip: false),
        size: const Size(640, 480),
      ),
    );
    expect(grip, findsNothing);
    semantics.dispose();
  });

  testWidgets('the grip does not expand in an unbounded row', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LifeOSSkinScope(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 500,
                  child: StatusBar(
                    notice: 'Saved.',
                    panels: const [StatusPanel('Local')],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StatusBar)), const Size(500, 22));
  });

  testWidgets('warning text is run ink with a mark and announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      page(
        const StatusBar(notice: 'Saved.', warning: '3 days to confirm'),
        size: const Size(640, 480),
      ),
    );
    final style = tester.widget<Text>(find.text('3 days to confirm')).style!;
    expect(style.color, LifeOSTokens.millennium.runInk);
    expect(find.byType(EraIcon), findsOneWidget);
    expect(
      find.semantics.byLabel('Warning: 3 days to confirm'),
      isSemantics(isLiveRegion: true),
    );
    expect(find.semantics.byLabel('Saved.'), isSemantics(isLiveRegion: true));
    semantics.dispose();
  });

  testWidgets('panels read their semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      page(
        const StatusBar(
          panels: [StatusPanel('15', semanticLabel: '15 shifts')],
        ),
        size: const Size(640, 480),
      ),
    );
    expect(find.bySemanticsLabel('15 shifts'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('no part of the bar takes keyboard focus or is tappable', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        const StatusBar(notice: _longNotice, panels: _panels, warning: 'Warn'),
        size: const Size(800, 600),
      ),
    );
    final before = FocusManager.instance.primaryFocus;
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    expect(FocusManager.instance.primaryFocus, before);
    expect(
      find.descendant(
        of: find.byType(StatusBar),
        matching: find.byWidgetPredicate(
          (w) =>
              w is FocusableActionDetector ||
              w is GestureDetector ||
              (w is Focus && w.canRequestFocus),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('maxHeight caps the bar', (tester) async {
    await tester.pumpWidget(
      page(
        const StatusBar(notice: _longNotice, panels: _panels, maxHeight: 60),
        size: const Size(640, 600),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StatusBar)).height, 60);
  });
}
