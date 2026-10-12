import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/licences_page_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

void main() {
  Widget host(
    Widget child, {
    double scale = 1,
    Size size = const Size(400, 300),
  }) => MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );

  const entries = [
    LicenceEntry(packages: ['alpha', 'beta'], text: 'Alpha licence text.'),
    LicenceEntry(packages: ['gamma'], text: 'Gamma licence text.'),
  ];

  testWidgets('shows loading, then every entry read-only', (tester) async {
    final completer = Completer<List<LicenceEntry>>();
    await tester.pumpWidget(
      host(LicencesPage(onBack: () {}, loader: () => completer.future)),
    );
    expect(find.text('Loading licences'), findsOneWidget);
    completer.complete(entries);
    await tester.pump();
    await tester.pump();
    expect(find.text('Loading licences'), findsNothing);
    expect(find.text('alpha, beta'), findsOneWidget);
    expect(find.text('Gamma licence text.'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('a failed load says so and Retry loads again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        LicencesPage(
          onBack: () {},
          loader: () async {
            if (++calls == 1) throw StateError('boom');
            return entries;
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Licences could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Licences could not be loaded'), findsNothing);
    expect(find.text('gamma'), findsOneWidget);
  });

  testWidgets('a loader that throws synchronously shows the failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(LicencesPage(onBack: () {}, loader: () => throw StateError('x'))),
    );
    await tester.pump();
    expect(find.text('Licences could not be loaded'), findsOneWidget);
  });

  testWidgets('an empty list says so', (tester) async {
    await tester.pumpWidget(
      host(LicencesPage(onBack: () {}, loader: () async => const [])),
    );
    await tester.pump();
    expect(find.text('No licences'), findsOneWidget);
  });

  testWidgets('long text at 200 percent scrolls and Back stays reachable', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(
      host(
        LicencesPage(onBack: () => backs++, loader: _longLoader),
        scale: 2,
        size: const Size(320, 240),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Lazy: far fewer rows built than listed.
    expect(find.textContaining('package_29'), findsNothing);
    final back = tester.getRect(find.text('Back'));
    expect(back.top, greaterThanOrEqualTo(0));
    expect(back.bottom, lessThanOrEqualTo(240));
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Back'));
    expect(backs, 1);
  });

  testWidgets('a late result after disposal is ignored', (tester) async {
    final completer = Completer<List<LicenceEntry>>();
    await tester.pumpWidget(
      host(LicencesPage(onBack: () {}, loader: () => completer.future)),
    );
    await tester.pumpWidget(const SizedBox());
    completer.complete(entries);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final failing = Completer<List<LicenceEntry>>();
    await tester.pumpWidget(
      host(LicencesPage(onBack: () {}, loader: () => failing.future)),
    );
    await tester.pumpWidget(const SizedBox());
    failing.completeError(StateError('late'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale result after the loader changed is dropped', (
    tester,
  ) async {
    final first = Completer<List<LicenceEntry>>();
    final second = Completer<List<LicenceEntry>>();
    Widget page(Future<List<LicenceEntry>> Function() loader) =>
        host(LicencesPage(onBack: () {}, loader: loader));
    Future<List<LicenceEntry>> loadFirst() => first.future;
    Future<List<LicenceEntry>> loadSecond() => second.future;
    await tester.pumpWidget(page(loadFirst));
    await tester.pumpWidget(page(loadSecond));
    first.complete(entries);
    await tester.pump();
    expect(find.text('gamma'), findsNothing);
    second.complete(const [
      LicenceEntry(packages: ['delta'], text: 'D'),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('delta'), findsOneWidget);
  });

  testWidgets('Back and Retry are keyboard-inert and take no focus', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(
      host(LicencesPage(onBack: () => backs++, loader: () async => entries)),
    );
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.numpadEnter,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(backs, 0);
    expect(FocusManager.instance.primaryFocus?.context, isNull);
    await tester.tap(find.text('Back'));
    expect(backs, 1);

    var calls = 0;
    await tester.pumpWidget(
      host(
        LicencesPage(
          onBack: () {},
          loader: () async {
            calls++;
            throw StateError('x');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('the demo: Enabled off greys Back; Error shows the failure', (
    tester,
  ) async {
    await pumpGalleryDemo(tester, licencesPageDemo);
    expect(find.text('synthetic_core'), findsOneWidget);
    await pumpGalleryDemo(
      tester,
      licencesPageDemo,
      knobs: const GalleryKnobs(enabled: false),
    );
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Back')),
      isSemantics(isEnabled: false),
    );
    semantics.dispose();
    await pumpGalleryDemo(
      tester,
      licencesPageDemo,
      knobs: const GalleryKnobs(error: true),
    );
    expect(find.text('Licences could not be loaded'), findsOneWidget);
  });
}

Future<List<LicenceEntry>> _longLoader() async => [
  for (var i = 0; i < 40; i++)
    LicenceEntry(
      packages: ['package_$i'],
      text: 'Licence text for the synthetic package number $i. ' * 12,
    ),
];
