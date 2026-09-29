import 'package:flutter/material.dart';

import '../core/outcomes/mutation_outcome.dart';

final class StartupFailure {
  const StartupFailure(this.code);

  final SafeFailureCode code;
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
                const Text(
                  'LifeOS could not open a stable local workspace. '
                  'Close the app, check local storage, then try again.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
