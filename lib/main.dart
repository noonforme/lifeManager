import 'dart:io';

import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'app/desktop_window_service.dart';
import 'app/font_licenses.dart';
import 'app/lifeos_app.dart';
import 'app/production_work_providers.dart';
import 'app/startup_recovery.dart';
import 'app/trailing_frame.dart';
import 'bootstrap.dart';
import 'core/database/app_database.dart';
import 'core/database/database_config.dart';
import 'core/database/database_service.dart';
import 'core/time/app_clock.dart';
import 'core/time/system_timezone.dart';
import 'core/time/timezone_service.dart';
import 'features/work/application/uuid_v7_work_id_factory.dart';

Future<void> main() async {
  final window = WindowManagerDesktopWindowService();
  final clock = SystemAppClock();
  final timezones = IanaTimezoneService();
  final systemZone = SystemTimezoneSource.platform();
  final ids = UuidV7WorkIdFactory();
  await bootstrap(
    BootstrapDependencies(
      initializeBindings: () async {
        // The Linux window shows each frame only once the next is drawn
        // (bead lifeManager-7qj); a trailing frame shows the last one.
        if (Platform.isLinux) TrailingFrameBinding();
        WidgetsFlutterBinding.ensureInitialized();
        registerFontLicenses();
        await window.prepare();
      },
      resolveSupportDirectory: () async {},
      initializeDiagnostics: () async {},
      initializeTimezone: () async {},
      initializeClock: () async {},
      openDatabase: () => _BootstrapDatabaseAdapter.open(),
      validateSchema: (_) async {},
      buildProviders: (database) async {
        final adapter = database as _BootstrapDatabaseAdapter;
        final built = buildWorkProviders(
          database: adapter.database,
          clock: clock,
          timezones: timezones,
          currentTimezoneId: systemZone.currentZoneId,
          workIds: ids,
          shiftIds: ids,
          evidenceIds: ids,
        );
        return BootstrapProviders(scope: built.scope);
      },
      buildRouter: (providers) async => providers.scope(
        LifeOsApp(
          router: createAppRouter(),
          onQuit: window.close,
          onTitle: window.setTitle,
        ),
      ),
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

  AppDatabase get database => _database.database;

  static Future<_BootstrapDatabaseAdapter> open() async {
    return _BootstrapDatabaseAdapter(
      await DatabaseService.open(const DatabaseConfig.production()),
    );
  }

  @override
  Future<void> close() => _database.close();
}
