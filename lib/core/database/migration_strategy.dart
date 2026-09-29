import 'package:drift/drift.dart';

import 'app_database.dart';

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
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(database.employments);
        await migrator.createTable(database.payAgreements);
        await migrator.createTable(database.workShifts);
        await migrator.createTable(database.shiftBreaks);
        await migrator.createTable(database.payPeriods);
        await migrator.createTable(database.payslips);
        await database.customStatement('''
          CREATE UNIQUE INDEX one_active_shift
          ON work_shifts ((1))
          WHERE state IN ('running', 'onBreak')
        ''');
      }
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
