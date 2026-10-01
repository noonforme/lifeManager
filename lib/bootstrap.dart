import 'package:flutter/widgets.dart';

import 'app/startup_recovery.dart';
import 'core/database/database_identity.dart';
import 'core/outcomes/mutation_outcome.dart';

abstract interface class BootstrapDatabase {
  Future<void> close();
}

final class BootstrapProviders {
  const BootstrapProviders({this.scope = _identityScope});

  final Widget Function(Widget child) scope;
}

Widget _identityScope(Widget child) => child;

final class BootstrapDependencies {
  const BootstrapDependencies({
    required this.initializeBindings,
    required this.resolveSupportDirectory,
    required this.initializeDiagnostics,
    required this.initializeTimezone,
    required this.initializeClock,
    required this.openDatabase,
    required this.validateSchema,
    required this.buildProviders,
    required this.buildRouter,
    required this.mountApp,
    required this.showWindow,
    required this.showRecovery,
  });

  final Future<void> Function() initializeBindings;
  final Future<void> Function() resolveSupportDirectory;
  final Future<void> Function() initializeDiagnostics;
  final Future<void> Function() initializeTimezone;
  final Future<void> Function() initializeClock;
  final Future<BootstrapDatabase> Function() openDatabase;
  final Future<void> Function(BootstrapDatabase database) validateSchema;
  final Future<BootstrapProviders> Function(BootstrapDatabase database)
  buildProviders;
  final Future<Widget> Function(BootstrapProviders providers) buildRouter;
  final Future<void> Function(Widget app) mountApp;
  final Future<void> Function() showWindow;
  final Future<void> Function(StartupFailure failure) showRecovery;
}

Future<void> bootstrap(BootstrapDependencies dependencies) async {
  BootstrapDatabase? database;
  try {
    await dependencies.initializeBindings();
    await dependencies.resolveSupportDirectory();
    await dependencies.initializeDiagnostics();
    await dependencies.initializeTimezone();
    await dependencies.initializeClock();
    database = await dependencies.openDatabase();
    await dependencies.validateSchema(database);
    final providers = await dependencies.buildProviders(database);
    final app = await dependencies.buildRouter(providers);
    await dependencies.mountApp(app);
    await dependencies.showWindow();
  } on DatabaseFromEarlierBuild catch (failure) {
    await database?.close();
    await dependencies.showRecovery(
      StartupFailure(
        SafeFailureCode.databaseFromEarlierBuild,
        databasePath: failure.path,
      ),
    );
  } on Object {
    await database?.close();
    await dependencies.showRecovery(
      const StartupFailure(SafeFailureCode.storageUnavailable),
    );
  }
}
