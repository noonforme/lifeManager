import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/preferences/preference_repository.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';
import 'package:lifeos/shared/workbench/skins/millennium_skin.dart';

void main() {
  group('Millennium contrast', () {
    const t = MillenniumSkin.tokens;
    final painters = const MillenniumSkin().painters;
    final status = painters.statusLine(t);

    // Selected rows draw every cell in selInk, so muted, run, negative and
    // positive text never sits on the saturated selWash.
    final text = <String, (Color, List<Color>)>{
      'ink': (t.ink, [t.paper, t.band, t.chrome, MillenniumSkin.paneBody]),
      'muted': (t.muted, [t.paper, t.band, t.chrome, MillenniumSkin.paneBody]),
      'runInk': (t.runInk, [t.paper, t.band]),
      'negative': (t.negative, [t.paper, t.band, t.chrome]),
      'positive': (t.positive, [t.paper, t.band, t.chrome]),
      'selInk': (t.selInk, [t.selWash]),
      'actionInk': (t.actionInk, [t.actionFill, t.chrome]),
      'headInk': (t.headInk, [t.head]),
      'link': (MillenniumSkin.link, [MillenniumSkin.paneBody]),
      'badge': (painters.countBadgeInk(t), [t.runInk]),
      'status': (status.ink, [t.chrome]),
      'status alert': (status.alertInk, [t.chrome]),
    };
    for (final MapEntry(key: name, value: (ink, surfaces)) in text.entries) {
      test('$name text meets 4.5:1', () {
        for (final surface in surfaces) {
          expect(
            contrastRatio(ink, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name on $surface',
          );
        }
      });
    }

    test('area key letters meet 4.5:1 on their keys', () {
      for (final key in t.areaKeys.values) {
        expect(contrastRatio(key.ink, key.fill), greaterThanOrEqualTo(4.5));
      }
    });

    test('indicators meet 3:1', () {
      for (final (name, color, surface) in [
        ('signal', t.signal, t.paper),
        ('status dot', status.indicator, t.chrome),
        ('focus', t.focus, t.paper),
        ('focus', t.focus, t.chrome),
        ('cell cursor', painters.cellCursor(t), t.selWash),
        ('key outline', MillenniumSkin.keyLine, t.chrome),
        ('progress', MillenniumSkin.progress, t.ink),
      ]) {
        expect(
          contrastRatio(color, surface),
          greaterThanOrEqualTo(3),
          reason: name,
        );
      }
    });
  });

  test('the Office Machine status line meets 4.5:1 and 3:1', () {
    const skin = OfficeMachineSkin();
    for (final tokens in [
      LifeOSTokens.day,
      LifeOSTokens.night,
      LifeOSTokens.highContrast,
    ]) {
      final status = skin.painters.statusLine(tokens);
      expect(contrastRatio(status.ink, tokens.head), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(status.alertInk, tokens.head),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(status.indicator, tokens.head),
        greaterThanOrEqualTo(3),
      );
    }
  });

  test('Millennium keeps its palette whatever the system brightness', () {
    final (skin, brightness, highContrast) = LifeOSSkinScope.resolve(
      LifeOSAppearance.millennium,
      platformBrightness: Brightness.dark,
      platformHighContrast: false,
    );
    expect(skin, isA<MillenniumSkin>());
    expect(
      skin.tokensFor(brightness, highContrast: highContrast),
      same(MillenniumSkin.tokens),
    );
  });

  testWidgets('system high contrast replaces Millennium with Office Machine', (
    tester,
  ) async {
    late LifeOSSkinData data;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: LifeOSSkinScope(
          appearance: LifeOSAppearance.millennium,
          child: Builder(
            builder: (context) {
              data = LifeOSSkinScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(data.skin, isA<OfficeMachineSkin>());
    expect(data.tokens, same(LifeOSTokens.highContrast));
  });

  group('on the production shell', () {
    late AppDatabase database;
    late ProductionWorkProviders work;
    late Employment employment;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      final ids = UuidV7WorkIdFactory();
      work = buildWorkProviders(
        database: database,
        clock: _Clock(),
        timezones: IanaTimezoneService(),
        currentTimezoneId: () => 'Europe/Vilnius',
        workIds: ids,
        shiftIds: ids,
        evidenceIds: ids,
      );
    });

    tearDown(() => database.close());

    Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
      employment = (await work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Warehouse', legalLabel: null),
      ) as Committed<Employment>).value;
      await work.agreement.createAgreement(
        CreateAgreementCommand(
          employmentId: employment.id,
          version: 1,
          terms: const AgreementTerms(
            effectiveStart: LocalDate(2026, 9, 1),
            effectiveEnd: null,
            hourlyRateMicroEur: 18400000,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      );
      await work.manualShifts.createAndFinalize(
        CreateManualShiftCommand(
          employmentId: employment.id,
          localStartDate: const LocalDate(2026, 10, 1),
          localStartTime: const LocalTime(22, 0),
          localEndDate: const LocalDate(2026, 10, 2),
          localEndTime: const LocalTime(6, 0),
          timezoneId: 'Europe/Vilnius',
          startFold: null,
          endFold: null,
          breaks: const [],
          note: null,
        ),
      );
    });

    Future<void> launch(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      final router = createAppRouter(
        initialLocation: '/work?employment=${employment.id.value}',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        work.scope(LifeOsApp(router: router, preferences: work.preferences)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String appearance) async {
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(appearance));
      await tester.pumpAndSettle();
      // Close the menus without touching the shell.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    LifeOSSkin activeSkin(WidgetTester tester) =>
        LifeOSSkinScope.of(tester.element(find.text('Warehouse').first)).skin;

    /// Every semantics node's label, flags and place on screen.
    List<String> semantics(WidgetTester tester) {
      final nodes = <String>[];
      void visit(SemanticsNode node, Matrix4 parent) {
        final transform = parent.clone();
        if (node.transform != null) transform.multiply(node.transform!);
        final rect = MatrixUtils.transformRect(transform, node.rect);
        final data = node.getSemanticsData();
        nodes.add(
          '${data.label}|${data.value}|${data.flagsCollection.toStrings()}|'
          '${rect.left.round()},${rect.top.round()},'
          '${rect.width.round()}x${rect.height.round()}',
        );
        node.visitChildren((child) {
          visit(child, transform);
          return true;
        });
      }

      final root = tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!;
      visit(root, Matrix4.identity());
      return nodes;
    }

    testWidgets('Millennium moves nothing and announces the same', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await seed(tester);
      await launch(tester);
      await choose(tester, 'Office Machine Day');
      expect(activeSkin(tester), isA<OfficeMachineSkin>());
      final office = semantics(tester);

      await choose(tester, 'Millennium');
      expect(activeSkin(tester), isA<MillenniumSkin>());
      final millennium = semantics(tester);

      final differences = [
        for (var i = 0; i < office.length && i < millennium.length; i++)
          if (office[i] != millennium[i]) '${office[i]}  →  ${millennium[i]}',
      ];
      expect(differences, isEmpty);
      expect(millennium.length, office.length);
      expect(office.length, greaterThan(40));
      handle.dispose();
    });

    testWidgets('the chosen appearance is restored on restart', (tester) async {
      await seed(tester);
      await launch(tester);
      expect(activeSkin(tester), isA<OfficeMachineSkin>());
      await choose(tester, 'Millennium');
      late String? stored;
      await tester.runAsync(
        () async =>
            stored = await work.preferences.read(PreferenceKey.appearance),
      );
      expect(stored, 'millennium');

      // A new app over the same database starts in Millennium.
      await tester.pumpWidget(const SizedBox.shrink());
      await launch(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(activeSkin(tester), isA<MillenniumSkin>());
    });
  });
}

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 3, 9);
}
