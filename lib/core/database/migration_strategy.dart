import 'package:drift/drift.dart';

import 'app_database.dart';

MigrationStrategy lifeOsMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await database
          .into(database.coreMetadata)
          .insert(const CoreMetadataCompanion(id: Value(1)));
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
