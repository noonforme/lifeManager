import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:lifeos/core/history/record_event_dao.dart';
import 'package:lifeos/core/history/record_events.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';

import '../support/owned_test_root.dart';

void main() {
  test('WAL snapshot restores application values and append-only history', () async {
    final source = await OwnedTestRoot.create();
    addTearDown(source.dispose);
    await File('${source.directory.path}/.lifeos-synthetic-root')
        .writeAsString('lifeos-synthetic-only-v1\n');
    final support = await Directory('${source.directory.path}/unused-support')
        .create();
    Future<DriftDatabaseService> open(Directory root, String token) =>
        DriftDatabaseService.open(
          DatabaseConfig.test(root: root.uri, markerToken: token),
          location: DefaultDatabaseLocation(
            repositoryRoot: Directory.current,
            productionSupportDirectory: () async => support,
          ),
        );
    final live = await open(source.directory, source.token);
    addTearDown(live.close);
    await live.database.customStatement('PRAGMA wal_autocheckpoint=0');
    final repository = DriftWorkRepository(live.database);
    final initial = Employment.create(
      id: const EmploymentId('0190f5d2-6a00-7000-8000-000000000005'),
      name: 'Synthetic backup lab',
      legalLabel: 'Synthetic Ltd',
      nowUtc: DateTime.utc(2026, 11, 14, 8),
    );
    await repository.insertEmployment(initial);
    final changed = initial.renamed(
      name: 'Synthetic restored lab',
      legalLabel: 'Synthetic Ltd',
      nowUtc: DateTime.utc(2026, 11, 14, 9),
    );
    await repository.updateEmployment(changed, expected: initial.revision);
    final agreement = PayAgreement(
      id: const AgreementId('0190f5d2-6a00-7000-8000-000000000006'),
      employmentId: initial.id,
      version: 1,
      effectiveStart: const LocalDate(2026, 11, 1),
      effectiveEnd: null,
      hourlyRateMicroEur: 18400000,
      basis: const GrossBasis(),
      overtimeThresholdMinutes: 480,
      overtimeMultiplier: AgreementDefaults.overtimeMultiplier,
      label: 'Synthetic rate',
      note: null,
      createdAtUtc: initial.createdAtUtc,
      revision: const Revision(0),
      usedByFinalizedShift: false,
    );
    await repository.insertAgreement(agreement);
    await live.database.customStatement(
      "INSERT INTO preferences (key, value) VALUES ('appearance', 'night')",
    );
    final before = await RecordEventDao(live.database)
        .forRecord('employment', initial.id.value);
    expect(before.map((event) => event.kind), [
      RecordEventKind.created,
      RecordEventKind.changed,
    ]);
    final filename = DefaultDatabaseLocation.databaseFilename;
    final wal = File('${source.directory.path}/$filename-wal');
    expect(await wal.length(), greaterThan(32));
    final mainBefore = await File('${source.directory.path}/$filename')
        .readAsBytes();
    final walBefore = await wal.readAsBytes();

    Future<Directory> transfer(
      String operation,
      Directory from,
      String token,
      String suffix,
    ) async {
      final destination = Directory(
        '/tmp/lifeos-recovery-${source.token}-$suffix',
      );
      final result = await Process.run('tool/operations/db-recovery.sh', [
        operation,
        '--root',
        from.path,
        '--marker-token',
        token,
        '--destination',
        destination.path,
        '--destination-token',
        source.token,
      ]).timeout(const Duration(seconds: 15));
      // Only successful, newly created roots are acquired for harness cleanup.
      if (result.exitCode == 0) {
        addTearDown(() async {
          expect(
            await File('${destination.path}/.lifeos-test-root').readAsString(),
            source.token,
          );
          await destination.delete(recursive: true);
        });
      }
      expect(result.stderr, isEmpty);
      expect(result.exitCode, 0, reason: '${result.stdout}');
      expect(
        (jsonDecode(result.stdout as String) as Map)['records_match'],
        true,
      );
      return destination;
    }

    final snapshot = await transfer(
      'backup',
      source.directory,
      source.token,
      'backup',
    );
    expect(
      await File('${source.directory.path}/$filename').readAsBytes(),
      mainBefore,
    );
    expect(await wal.readAsBytes(), walBefore);
    // Change the live database after backup; recovery must retain the snapshot.
    await repository.updateEmployment(
      changed.renamed(
        name: 'Later live edit',
        legalLabel: null,
        nowUtc: DateTime.utc(2026, 11, 14, 10),
      ),
      expected: changed.revision,
    );
    final restored = await transfer(
      'restore',
      snapshot,
      source.token,
      'restore',
    );
    final service = await open(restored, source.token);
    addTearDown(service.close);
    final recoveredAgreement = (await DriftWorkRepository(
      service.database,
    ).agreementsFor(initial.id)).single;
    expect(recoveredAgreement.hourlyRateMicroEur, 18400000);
    expect(recoveredAgreement.effectiveStart, agreement.effectiveStart);
    expect(recoveredAgreement.overtimeMultiplier, agreement.overtimeMultiplier);
    final agreementHistory = await RecordEventDao(service.database)
        .forRecord('agreement', agreement.id.value);
    expect(agreementHistory.single.kind, RecordEventKind.created);
    expect(
      agreementHistory.single.changes,
      contains(const FieldChange('Hourly rate', null, '18.40 EUR/h')),
    );
    final reads = WorkReads(service.database);
    final record = (await reads.employment(initial.id))!.value;
    expect(record.name, changed.name);
    expect(record.legalLabel, 'Synthetic Ltd');
    expect(record.revision, changed.revision);
    expect(record.createdAtUtc, initial.createdAtUtc);
    expect(record.updatedAtUtc, changed.updatedAtUtc);
    final history = await RecordEventDao(service.database)
        .forRecord('employment', initial.id.value);
    expect(history.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(history[i].id, before[i].id);
      expect(history[i].kind, before[i].kind);
      expect(history[i].atUtc, before[i].atUtc);
      expect(history[i].revisionAfter, before[i].revisionAfter);
      expect(history[i].changes, before[i].changes);
    }
    expect(
      history.last.changes,
      contains(
        const FieldChange(
          'Name',
          'Synthetic backup lab',
          'Synthetic restored lab',
        ),
      ),
    );
    final preference = await service.database
        .customSelect("SELECT value FROM preferences WHERE key = 'appearance'")
        .getSingle();
    expect(preference.data['value'], 'night');
    expect((await service.readPragmas()).foreignKeys, true);
    // Opening recovery did not redirect the live service.
    expect(
      (await repository.employmentById(initial.id))!.name,
      'Later live edit',
    );
  });
}
