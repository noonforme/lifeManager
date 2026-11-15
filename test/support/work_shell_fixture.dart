import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';

import 'schedule_fixture.dart' show FixedClock;
import 'shifts_sheet_fixture.dart';

/// The production Work services over an in-memory database with no
/// employment at all: the Work shell's first run (spec 4.9).
final class EmptyWorkFixture {
  EmptyWorkFixture._(this.database, this.work, this.reads);

  final AppDatabase database;
  final ProductionWorkProviders work;
  final WorkReads reads;

  /// Over [executor] when given, else a new in-memory database.
  static Future<EmptyWorkFixture> create({QueryExecutor? executor}) async {
    final database = AppDatabase(executor ?? NativeDatabase.memory());
    final ids = UuidV7WorkIdFactory();
    final work = buildWorkProviders(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 10, 20, 9)),
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => ShiftsSheetFixture.zone,
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
      scheduleIds: ids,
    );
    return EmptyWorkFixture._(database, work, WorkReads(database));
  }

  Future<void> dispose() => database.close();
}
