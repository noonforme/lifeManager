import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/startup_recovery.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

void main() {
  testWidgets('startup error exposes category without raw exception or path', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartupRecovery(
          failure: StartupFailure(SafeFailureCode.storageUnavailable),
        ),
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
      const MaterialApp(
        home: StartupRecovery(
          failure: StartupFailure(
            SafeFailureCode.databaseFromEarlierBuild,
            databasePath: '/synthetic/support/lifeos-native-v1.sqlite',
          ),
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
}
