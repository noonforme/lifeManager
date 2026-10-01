import 'package:drift/drift.dart';

import 'app_database.dart';
import 'database_identity.dart';

MigrationStrategy lifeOsMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await database.customStatement('''
        CREATE UNIQUE INDEX one_active_shift
        ON work_shifts ((1))
        WHERE state IN ('running', 'onBreak')
      ''');
      await database
          .into(database.coreMetadata)
          .insert(const CoreMetadataCompanion(id: Value(1)));
    },
    // Version 1 is the only schema; databases from earlier development
    // builds are refused before Drift opens them.
    onUpgrade: (migrator, from, to) async {
      throw DatabaseFromEarlierBuild(from: from, to: to);
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
