import 'package:drift/drift.dart';

import '../../features/work/data/work_tables.dart';
import 'migration_strategy.dart';
import 'schema_versions.dart';

part 'app_database.g.dart';

class CoreMetadata extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get applicationVersion => text().nullable()();
  IntColumn get snapshotSchemaVersion => integer().nullable()();
  TextColumn get snapshotCreatedAtUtc => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    CoreMetadata,
    Employments,
    PayAgreements,
    WorkShifts,
    ShiftBreaks,
    PayPeriods,
    Payslips,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => lifeOsMigrationStrategy(this);
}
