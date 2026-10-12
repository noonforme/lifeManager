import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_app.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/gallery.dart';

void main() {
  Future<void> pumpGallery(
    WidgetTester tester, {
    GalleryKnobs knobs = const GalleryKnobs(),
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GalleryApp(initialKnobs: knobs));
    await tester.pumpAndSettle();
  }

  GalleryCanvas canvas(WidgetTester tester) =>
      tester.widget<GalleryCanvas>(find.byType(GalleryCanvas));

  testWidgets('opens on the first demo and opens another from the list', (
    tester,
  ) async {
    await pumpGallery(tester);
    expect(canvas(tester).demo.id, galleryDemos.first.id);

    await tester.tap(find.text(galleryDemos[1].widget).first);
    await tester.pumpAndSettle();
    expect(canvas(tester).demo.id, galleryDemos[1].id);
  });

  testWidgets('the knobs reach the demo', (tester) async {
    await pumpGallery(tester);
    await tester.tap(find.text('Enabled'));
    await tester.tap(find.text('Show an error'));
    await tester.tap(find.text('Long text'));
    await tester.tap(find.text('200 % text'));
    await tester.pumpAndSettle();
    final knobs = canvas(tester).knobs;
    expect(knobs.enabled, isFalse);
    expect(knobs.error, isTrue);
    expect(knobs.longText, isTrue);
    expect(knobs.textScale, 2);
  });

  testWidgets('the gallery holds at 200 % text with long labels', (
    tester,
  ) async {
    await pumpGallery(
      tester,
      knobs: const GalleryKnobs(longText: true, textScale: 2),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryCanvas), findsOneWidget);
  });

  testWidgets(
    'all knobs remain reachable at 800 by 600 with 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const GalleryApp());
      await tester.pumpAndSettle();
      for (final label in [
        'Enabled',
        'Show an error',
        'Long text',
        '200 % text',
      ]) {
        final knob = find.text(label);
        await tester.ensureVisible(knob);
        await tester.pumpAndSettle();
        expect(knob.hitTestable(), findsOneWidget);
        await tester.tap(knob);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(canvas(tester).knobs.enabled, isFalse);
      expect(canvas(tester).knobs.error, isTrue);
      expect(canvas(tester).knobs.longText, isTrue);
      expect(canvas(tester).knobs.textScale, 2);
      for (final label in ['Enabled', 'Show an error', 'Long text']) {
        final knob = find.text(label);
        await tester.ensureVisible(knob);
        await tester.pumpAndSettle();
        expect(knob.hitTestable(), findsOneWidget);
        await tester.tap(knob);
        await tester.pumpAndSettle();
      }
      expect(canvas(tester).knobs.enabled, isTrue);
      expect(canvas(tester).knobs.error, isFalse);
      expect(canvas(tester).knobs.longText, isFalse);
      expect(canvas(tester).knobs.textScale, 2);
    },
  );

  testWidgets('every demo builds alone without errors', (tester) async {
    for (final demo in galleryDemos) {
      await pumpGalleryDemo(tester, demo);
      expect(tester.takeException(), isNull, reason: demo.id);
    }
  });
}
