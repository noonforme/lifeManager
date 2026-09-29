import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'app/desktop_window_service.dart';
import 'app/lifeos_app.dart';
import 'app/startup_recovery.dart';
import 'bootstrap.dart';
import 'core/database/database_config.dart';
import 'core/database/database_service.dart';
import 'core/time/timezone_service.dart';

Future<void> main() async {
  final window = WindowManagerDesktopWindowService();
  await bootstrap(
    BootstrapDependencies(
      initializeBindings: () async {
        WidgetsFlutterBinding.ensureInitialized();
        await window.prepare();
      },
      resolveSupportDirectory: () async {},
      initializeDiagnostics: () async {},
      initializeTimezone: () async {
        IanaTimezoneService();
      },
      initializeClock: () async {},
      openDatabase: () => _BootstrapDatabaseAdapter.open(),
      validateSchema: (_) async {},
      buildProviders: (_) async => const BootstrapProviders(),
      buildRouter: (_) async => LifeOsApp(router: createAppRouter()),
      mountApp: (app) async => runApp(app),
      showWindow: window.show,
      showRecovery: (failure) async {
        runApp(MaterialApp(home: StartupRecovery(failure: failure)));
        await window.show();
      },
    ),
  );
}

final class _BootstrapDatabaseAdapter implements BootstrapDatabase {
  _BootstrapDatabaseAdapter(this._database);

  final DatabaseService _database;

  static Future<_BootstrapDatabaseAdapter> open() async {
    return _BootstrapDatabaseAdapter(
      await DatabaseService.open(const DatabaseConfig.production()),
    );
  }

  @override
  Future<void> close() => _database.close();
}
