import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'app/desktop_window_service.dart';
import 'app/edit_session/window_close_guard.dart';
import 'app/font_licenses.dart';
import 'app/lifeos_app.dart';
import 'app/production_work_providers.dart';
import 'app/startup_mode.dart';
import 'app/startup_recovery.dart';
import 'app/trailing_frame.dart';
import 'app/work_edit/work_records.dart';
import 'app/work_shell/location_store.dart';
import 'app/work_shell/work_shell.dart';
import 'bootstrap.dart';
import 'core/database/app_database.dart';
import 'core/database/database_config.dart';
import 'core/database/database_location.dart';
import 'core/database/database_service.dart';
import 'core/time/app_clock.dart';
import 'core/time/system_timezone.dart';
import 'core/time/timezone_service.dart';
import 'features/work/application/uuid_v7_work_id_factory.dart';
import 'ui/gallery/gallery_main.dart';

Future<void> main() => startSelectedMode(
  startGallery: _startGallery,
  startProduction: _startProduction,
);

Future<void> _startGallery() async {
  if (Platform.isLinux) TrailingFrameBinding();
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final window = WindowManagerDesktopWindowService();
  await runGallery(
    prepareWindow: () async {
      await window.prepare();
      await window.setTitle('LifeOS widget gallery');
    },
    showWindow: window.show,
  );
}

/// LifeOS on its database: the Work shell behind the one `/work` route
/// (cutover spec 4g), its last place in a file beside the database, and
/// the window's close button guarded.
Future<void> _startProduction() async {
  final window = WindowManagerDesktopWindowService();
  final clock = SystemAppClock();
  final timezones = IanaTimezoneService();
  final systemZone = SystemTimezoneSource.platform();
  final ids = UuidV7WorkIdFactory();
  late final _BootstrapDatabaseAdapter opened;
  late final ProductionWorkProviders work;
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
        opened = database as _BootstrapDatabaseAdapter;
        work = buildWorkProviders(
          database: opened.database,
          clock: clock,
          timezones: timezones,
          currentTimezoneId: systemZone.currentZoneId,
          workIds: ids,
          shiftIds: ids,
          evidenceIds: ids,
        );
        return const BootstrapProviders();
      },
      buildRouter: (_) async {
        final file = await DefaultDatabaseLocation().resolve(
          const DatabaseConfig.production(),
        );
        final zone = systemZone.currentZoneId() ?? 'UTC';
        return LifeOsApp(
          router: createAppRouter(
            work: (link) => WorkShell(
              work: work,
              reads: WorkReads(opened.database),
              today: timezones.localDateAt(clock.nowUtc(), zone),
              timezoneId: zone,
              store: FileLocationStore.beside(file),
              closeApi: WindowManagerCloseApi(),
              release: opened.close,
              link: link,
              // A title the platform refuses is no reason to stop.
              onTitle: (title) =>
                  unawaited(window.setTitle(title).catchError((_) {})),
            ),
          ),
        );
      },
      mountApp: (app) async => runApp(app),
      showWindow: window.show,
      showRecovery: (failure) async {
        runApp(StartupRecoveryApp(failure: failure));
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
