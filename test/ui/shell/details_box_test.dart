import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/details_box_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

void main() {
  Widget host(
    Widget child, {
    double scale = 1,
    double width = 240,
    double? height = 200,
  }) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  );

  List<DetailsFact> many(int n) => [
    for (var i = 0; i < n; i++) DetailsFact('Fact $i', 'Value $i'),
  ];

  testWidgets('facts show as label and value; links report taps', (
    tester,
  ) async {
    var agreement = 0;
    var schedule = 0;
    await tester.pumpWidget(
      host(
        DetailsBox(
          caption: 'Details',
          sections: [
            DetailsSection(
              facts: [
                DetailsFact(
                  'Agreement',
                  'Pay from 2026-10-01',
                  figure: false,
                  onFollow: () => agreement++,
                ),
                const DetailsFact('Hourly rate', 'EUR 18.40'),
                DetailsFact(
                  'Schedule',
                  'Four on, three off',
                  onFollow: () => schedule++,
                ),
              ],
            ),
            const DetailsSection(
              title: 'October 2026',
              facts: [DetailsFact('To confirm', '3')],
            ),
          ],
        ),
      ),
    );
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Hourly rate:'), findsOneWidget);
    expect(find.text('EUR 18.40'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.byType(EtchedLine), findsOneWidget, reason: 'between blocks');

    await tester.tap(find.text('Pay from 2026-10-01'));
    await tester.tap(find.text('Four on, three off'));
    await tester.tap(find.text('EUR 18.40'));
    await tester.tap(find.text('Hourly rate:'));
    expect((agreement, schedule), (1, 1));
  });

  testWidgets('the mouse shows a click cursor over links only', (tester) async {
    await tester.pumpWidget(
      host(
        DetailsBox(
          caption: 'Details',
          sections: [
            DetailsSection(
              facts: [
                DetailsFact('Agreement', 'Pay', onFollow: () {}),
                const DetailsFact('Rate', 'EUR 18.40'),
              ],
            ),
          ],
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Pay')));
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await mouse.moveTo(tester.getCenter(find.text('EUR 18.40')));
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      isNot(SystemMouseCursors.click),
    );
  });

  testWidgets('the sections scroll on their own under the pinned caption', (
    tester,
  ) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          controller: page,
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: DetailsBox(
                  caption: 'Details',
                  sections: [DetailsSection(facts: many(20))],
                ),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
        height: 300,
      ),
    );
    final caption = tester.getRect(find.text('Details'));
    final first = tester.getTopLeft(find.text('Fact 0:'));
    expect(find.text('Fact 19:'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Fact 19:')).dy, greaterThan(120));

    await tester.drag(find.text('Fact 3:'), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Details')), caption);
    expect(tester.getTopLeft(find.text('Fact 0:')).dy, lessThan(first.dy));
    expect(page.offset, 0, reason: 'the page behind did not move');
    expect(find.byKey(const ValueKey('era-scrollbar')), findsOneWidget);
  });

  testWidgets('an unbounded height takes the content height', (tester) async {
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: DetailsBox(
            caption: 'Details',
            sections: [DetailsSection(facts: many(3))],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(DetailsBox)).height, lessThan(150));
  });

  testWidgets('warnings are announced as warnings and links are links', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var followed = 0;
    await tester.pumpWidget(
      host(
        DetailsBox(
          caption: 'Details',
          sections: [
            DetailsSection(
              facts: const [DetailsFact('Rate', 'EUR 18.40')],
              warnings: [
                DetailsWarning('3 days to confirm', onFollow: () => followed++),
                const DetailsWarning('Agreement ends soon'),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Warning: 3 days to confirm'), findsOneWidget);
    expect(
      find.semantics.byLabel('Warning: 3 days to confirm'),
      isSemantics(isLink: true, hasTapAction: true),
    );
    expect(
      find.semantics.byLabel('Warning: Agreement ends soon'),
      isSemantics(isLink: false),
    );
    expect(find.bySemanticsLabel('Rate: EUR 18.40'), findsOneWidget);
    expect(find.byType(EraIcon), findsNWidgets(2));
    await tester.tap(find.text('3 days to confirm'));
    expect(followed, 1);
    semantics.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('long labels and values wrap at ${scale * 100} % text and '
        'keep the label visible', (tester) async {
      const label = 'Night premium paid on holidays';
      const value =
          'Synthetic-depot-agreement-from-2026-10-01-night-premium-included '
          'and a long explanation that must wrap';
      await tester.pumpWidget(
        host(
          DetailsBox(
            caption: 'Details',
            sections: [
              DetailsSection(
                title: 'A rather long section title for the left pane',
                facts: [
                  const DetailsFact(label, value, figure: false),
                  DetailsFact('Schedule', value, onFollow: () {}),
                ],
                warnings: const [
                  DetailsWarning(
                    'A warning that is long enough to need several lines',
                  ),
                ],
              ),
            ],
          ),
          scale: scale,
          height: 600,
        ),
      );
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byType(DetailsBox));
      final labelRect = tester.getRect(find.text('$label:'));
      expect(labelRect.left, greaterThanOrEqualTo(box.left));
      expect(labelRect.right, lessThanOrEqualTo(box.right));
      expect(labelRect.height, greaterThan(0));
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final rect = tester.getRect(find.byWidget(text));
        expect(rect.right, lessThanOrEqualTo(box.right + 0.5), reason: '$text');
      }
      // A value never overlaps the label above or beside it.
      final valueRect = tester.getRect(find.text(value).first);
      expect(valueRect.overlaps(labelRect), isFalse);
    });
  }

  testWidgets('nothing in the box takes keyboard focus or reacts to keys', (
    tester,
  ) async {
    var followed = 0;
    await tester.pumpWidget(
      host(
        DetailsBox(
          caption: 'Details',
          sections: [
            DetailsSection(
              facts: [
                DetailsFact('Agreement', 'Pay', onFollow: () => followed++),
              ],
              warnings: [DetailsWarning('Warn', onFollow: () => followed++)],
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(followed, 0);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<Focus>().having((f) => f.canRequestFocus, 'can', isTrue)),
    );
    final focusables = find.descendant(
      of: find.byType(DetailsBox),
      matching: find.byWidgetPredicate(
        (w) =>
            (w is Focus && w.canRequestFocus && w.focusNode != null) ||
            w is FocusableActionDetector,
      ),
    );
    expect(focusables, findsNothing);
  });

  testWidgets('the demo: Enabled off makes links plain text; Error warns', (
    tester,
  ) async {
    List<DetailsFact> facts() => [
      for (final s
          in tester.widget<DetailsBox>(find.byType(DetailsBox)).sections)
        ...s.facts,
    ];
    await pumpGalleryDemo(tester, detailsBoxDemo);
    expect(facts().where((f) => f.onFollow != null), hasLength(2));
    expect(find.byType(EraIcon), findsNothing);
    await pumpGalleryDemo(
      tester,
      detailsBoxDemo,
      knobs: const GalleryKnobs(enabled: false, error: true, longText: true),
    );
    expect(facts().where((f) => f.onFollow != null), isEmpty);
    expect(find.byType(EraIcon), findsOneWidget);
  });
}
