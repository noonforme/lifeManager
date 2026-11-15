import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/startup_recovery.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  testWidgets('startup error exposes category without raw exception or path', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StartupRecoveryApp(
        failure: StartupFailure(SafeFailureCode.storageUnavailable),
      ),
    );

    expect(find.text('Storage unavailable'), findsOneWidget);
    expect(find.textContaining('/home/'), findsNothing);
    expect(find.textContaining('SqliteException:'), findsNothing);
  });

  testWidgets('an earlier-build database names only its own location', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StartupRecoveryApp(
        failure: StartupFailure(
          SafeFailureCode.databaseFromEarlierBuild,
          databasePath: '/synthetic/support/lifeos-native-v1.sqlite',
        ),
      ),
    );

    expect(find.text('Database from an earlier build'), findsOneWidget);
    expect(
      find.text(
        'This database was made by an earlier development build of LifeOS '
        "and can't be opened. Close LifeOS, remove "
        '/synthetic/support/lifeos-native-v1.sqlite, then start it again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('recovery wears the LifeOS skin and stays readable at 200% '
      'text in a small window', (tester) async {
    // Audit 9pk.4.39: it was a bare Material page with headline type.
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      const StartupRecoveryApp(
        failure: StartupFailure(
          SafeFailureCode.databaseFromEarlierBuild,
          databasePath: '/synthetic/support/lifeos-native-v1.sqlite',
        ),
      ),
    );
    final state = tester.widget<OperationalState>(
      find.byType(OperationalState),
    );
    expect(state.kind, OperationalStateKind.unavailable);
    expect(state.title, 'Database from an earlier build');
    expect(find.byType(LifeOSSkinScope), findsOneWidget);
    final title = tester.widget<Text>(
      find.text('Database from an earlier build'),
    );
    final skin = LifeOSSkinScope.of(
      tester.element(find.byType(OperationalState)),
    );
    expect(title.style!.fontFamily, skin.typography.body.fontFamily);
    expect(title.style!.fontSize, skin.typography.body.fontSize);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.textContaining('lifeos-native-v1.sqlite'),
      40,
    );
    expect(find.textContaining('lifeos-native-v1.sqlite'), findsOneWidget);
  });
}
