import 'package:flutter/material.dart';

import '../core/outcomes/mutation_outcome.dart';

final class StartupFailure {
  const StartupFailure(this.code, {this.databasePath});

  final SafeFailureCode code;

  /// The database file's own location, shown only when the owner must
  /// remove it. Never record content.
  final String? databasePath;
}

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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(switch (failure.code) {
                  SafeFailureCode.databaseFromEarlierBuild =>
                    'This database was made by an earlier development build '
                        "of LifeOS and can't be opened. Close LifeOS, remove "
                        '${failure.databasePath ?? 'the LifeOS database'}, '
                        'then start it again.',
                  _ =>
                    'LifeOS could not open a stable local workspace. '
                        'Close the app, check local storage, then try again.',
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
