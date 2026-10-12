import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/pane_caption_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

Widget _host(Widget child, {double width = 240, double textScale = 1}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('Close and each action are labelled mouse targets of 24 px', (
    tester,
  ) async {
    var closed = 0;
    var added = 0;
    await tester.pumpWidget(
      _host(
        PaneCaption(
          icon: EraIconKind.work,
          title: 'Work',
          actions: [
            PaneCaptionAction(
              icon: EraIconKind.add,
              semanticLabel: 'Add record',
              onPressed: () => added++,
            ),
            const PaneCaptionAction(
              icon: EraIconKind.delete,
              semanticLabel: 'Delete record',
              onPressed: null,
            ),
          ],
          onClose: () => closed++,
        ),
      ),
    );
    for (final label in ['Add record', 'Delete record', 'Close Work']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(24), reason: label);
      expect(size.height, greaterThanOrEqualTo(24), reason: label);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Delete record')),
      matchesSemantics(
        label: 'Delete record',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Add record'));
    await tester.tap(find.bySemanticsLabel('Delete record'));
    await tester.tap(find.bySemanticsLabel('Close Work'));
    expect(added, 1);
    expect(closed, 1);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'a long title wraps and Close stays visible at ${scale * 100}%',
      (tester) async {
        var closed = 0;
        await tester.pumpWidget(
          _host(
            PaneCaption(
              icon: EraIconKind.agreement,
              title: 'Pay agreement from 2026-10-01 for Synthetic depot',
              trailing: const CountBadge(count: 12, semanticLabel: 'open'),
              actions: [
                PaneCaptionAction(
                  icon: EraIconKind.add,
                  semanticLabel: 'Add',
                  onPressed: () {},
                ),
              ],
              onClose: () => closed++,
            ),
            width: 180,
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        final caption = tester.getRect(find.byType(PaneCaption));
        final close = tester.getRect(find.bySemanticsLabel(RegExp('^Close ')));
        expect(caption.contains(close.topLeft), isTrue);
        expect(close.right, lessThanOrEqualTo(caption.right));
        expect(
          tester.getRect(find.textContaining('Pay agreement')).right,
          lessThanOrEqualTo(close.left),
          reason: 'the title wraps beside Close, never under it',
        );
        await tester.tap(find.bySemanticsLabel(RegExp('^Close ')));
        expect(closed, 1);
      },
    );
  }

  testWidgets('trailing keys work by mouse but never by keyboard', (
    tester,
  ) async {
    var smuggled = 0;
    var closed = 0;
    await tester.pumpWidget(
      _host(
        PaneCaption(
          title: 'Details',
          trailing: KeyButton(label: 'Sneaky', onPressed: () => smuggled++),
          onClose: () => closed++,
        ),
        width: 400,
      ),
    );
    for (final key in [
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(smuggled, 0);
    expect(closed, 0);
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    await tester.tap(find.text('Sneaky'));
    expect(smuggled, 1, reason: 'the mouse still works');
  });

  testWidgets('with no Close handler there is no Close key', (tester) async {
    await tester.pumpWidget(_host(const PaneCaption(title: 'Details')));
    expect(find.bySemanticsLabel(RegExp('^Close')), findsNothing);
  });

  testWidgets('the demo: Enabled off greys actions and removes Close', (
    tester,
  ) async {
    await pumpGalleryDemo(
      tester,
      paneCaptionDemo,
      knobs: const GalleryKnobs(enabled: false, longText: true, textScale: 2),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('^Close')), findsNothing);
    expect(
      tester
          .widgetList<PaneCaption>(find.byType(PaneCaption))
          .expand((caption) => caption.actions.map((a) => a.onPressed)),
      everyElement(isNull),
    );
  });
}
