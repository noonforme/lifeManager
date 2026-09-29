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
}
