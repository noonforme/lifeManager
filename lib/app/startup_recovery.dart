import 'package:flutter/material.dart';

import '../core/outcomes/mutation_outcome.dart';
import '../ui/ui.dart';

final class StartupFailure {
  const StartupFailure(this.code, {this.databasePath});

  final SafeFailureCode code;

  /// The database file's own location, shown only when the owner must
  /// remove it. Never record content.
  final String? databasePath;
}

/// The app shown when the database cannot be opened: the production
/// app's theme, skin and era scrolling around [StartupRecovery], so a
/// failed start looks like LifeOS (bead 9pk.4.39). The window's own close
/// key closes it.
final class StartupRecoveryApp extends StatelessWidget {
  const StartupRecoveryApp({required this.failure, super.key});

  final StartupFailure failure;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'LifeOS',
    theme: buildLifeOSTheme(),
    scrollBehavior: const EraScrollBehavior(),
    builder: (context, child) => LifeOSSkinScope(
      child: Builder(
        builder: (context) => Theme(
          data: lifeOSThemeFor(LifeOSSkinScope.of(context)),
          child: Material(
            type: MaterialType.transparency,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
    home: StartupRecovery(failure: failure),
  );
}

/// Why LifeOS could not start and what the owner can do, as the library's
/// [OperationalState] on the window's face. Needs a [LifeOSSkinScope].
final class StartupRecovery extends StatelessWidget {
  const StartupRecovery({required this.failure, super.key});

  final StartupFailure failure;

  @override
  Widget build(BuildContext context) {
    final title = switch (failure.code) {
      SafeFailureCode.storageUnavailable => 'Storage unavailable',
      SafeFailureCode.databaseIdentityMismatch => 'Database unavailable',
      SafeFailureCode.migrationFailed => 'Update unavailable',
      SafeFailureCode.databaseFromEarlierBuild =>
        'Database from an earlier build',
      SafeFailureCode.invalidTimezone => 'Timezone unavailable',
      SafeFailureCode.commitOutcomeUnknown => 'Result uncertain',
    };
    return ColoredBox(
      color: LifeOSSkinScope.of(context).tokens.chrome,
      // Centred in the window; large text scrolls instead of clipping.
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: OperationalState(
              kind: failure.code == SafeFailureCode.commitOutcomeUnknown
                  ? OperationalStateKind.uncertain
                  : OperationalStateKind.unavailable,
              title: title,
              message: switch (failure.code) {
                SafeFailureCode.databaseFromEarlierBuild =>
                  'This database was made by an earlier development build '
                      "of LifeOS and can't be opened. Close LifeOS, remove "
                      '${failure.databasePath ?? 'the LifeOS database'}, '
                      'then start it again.',
                _ =>
                  'LifeOS could not open a stable local workspace. '
                      'Close the app, check local storage, then try again.',
              },
            ),
          ),
        ),
      ),
    );
  }
}
