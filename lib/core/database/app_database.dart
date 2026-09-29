import 'package:drift/drift.dart';

import 'migration_strategy.dart';

part 'app_database.g.dart';

class CoreMetadata extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get applicationVersion => text().nullable()();
  IntColumn get snapshotSchemaVersion => integer().nullable()();
  TextColumn get snapshotCreatedAtUtc => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [CoreMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => lifeOsMigrationStrategy(this);
}
