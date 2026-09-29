# Native Release Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a verified native Fedora-compatible LifeOS release with consistent manual backup, versioned Work export, guarded integration/launcher workflows, and a bounded documented visual finish.

**Architecture:** The database service owns a serialized SQLite snapshot mechanism and Work repositories provide export projections; the file layer selects a destination only through `DestinationPicker`, writes staging files owned by LifeOS, validates them, then atomically publishes one artifact. Backup compatibility metadata is embedded inside the SQLite snapshot so database plus metadata cannot be split by a partial two-file publish. Native integration and release checks start only with an explicitly owned disposable data root. Packaging wraps the Flutter Linux bundle without background services or network permissions, while cutover preserves the Django source/database and user-owned untracked planning drafts strictly as uninspected archive material.

**Tech Stack:** Flutter `3.47.5`, Dart `3.13.4`, Drift `2.35.0`, `sqlite3` `3.6.0`, Riverpod `3.4.3`, GoRouter `18.0.2`, `flutter_test`, `integration_test`, SQLite, RPM, Fedora-compatible Linux.

**Spec:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md`; master dependency and interface contract: `docs/superpowers/plans/2026-09-29-lifeos-native-implementation.md`; UI predecessor: `docs/superpowers/plans/2026-09-29-lifeos-native-04-workbench-ui.md`.

## Global Constraints

- Ship a Flutter Linux application only. Do not launch, embed, call, import, wrap, or depend on Django, Python, React, Node, a browser, or an HTTP server at runtime.
- Retain exact pins Flutter `3.47.5`, Dart `3.13.4`, Drift `2.35.0`, `sqlite3` `3.6.0`, Riverpod `3.4.3`, GoRouter `18.0.2`, and commit `pubspec.lock`.
- The native database is the distinct identified `lifeos-native-v1.sqlite` beneath application support. Never search for, infer, inspect, open, copy, import, migrate, test against, capture, or mutate the archived Django database.
- A manual backup is not a live-file copy: serialize it with the database service, make a consistent SQLite snapshot in an application-controlled temporary location, reopen it read-only, verify identity and integrity, and atomically publish only after validation.
- Backup metadata contains application version, schema version, and creation timestamp inside the SQLite snapshot's core metadata table; diagnostics/UI never expose destination paths, SQL, exception text, record values, labels, notes, dates, amounts, or IDs unless essential to the local visible record.
- Work JSON export is separate from backup, uses a versioned top-level schema, contains all reconciliation-relevant facts and void/replacement links, and labels optional derived reconciliation as non-authoritative convenience output.
- Backup/export are plaintext owner-controlled files. Do not imply encryption, off-device safety, automatic backup, interactive restore, arbitrary SQLite restore, Django import, hot swap, or automatic merge.
- Test and integration roots fail closed unless they are fresh, explicitly owned, marked, and outside normal/known real-data locations. Synthetic fixtures/captures/logs are mandatory.
- First distribution target is Fedora-compatible Linux. Required artifacts are a Flutter release bundle, RPM, `.desktop` entry, icon, AppStream metadata, and checksums. Application ID is `io.lifeos.LifeOS`.
- Do not add network permissions, background services, Flatpak, Snap, or Debian packaging in this release.
- `./app.sh` becomes the supported native entry point with `format-check`, `analyze`, `generate-check`, `test`, `verify`, `build`, and `start --data-root <owned-root>`; every command first validates Flutter `3.47.5`, Dart `3.13.4`, and the committed lockfile/dependency resolution, and it must never silently fall back to Django or an HTTP service.
- Preserve committed historical specifications and user-owned untracked drafts, including the `2026-09-28` React plan drafts. Mark those drafts inactive in a native plan index; never delete or commit them as a cutover side effect.
- Impeccable work is bounded: one complete synthetic capture matrix, one independent finish review, one material-fix batch, at most one confirmation capture, then shipped design documentation. Do not claim review approval when capture prerequisites are absent.
- End every implementation commit with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.

## Review Focus

1. **A database with WAL-resident committed changes:** backup must use SQLite’s backup/snapshot path and never publish a byte-for-byte live database copy; test in Task 1.
2. **A wrong/absent application ID, failed integrity check, or invalid snapshot schema:** reject it before destination publication and leave an existing destination unchanged; test in Task 1.
3. **Picker cancellation or a destination write failure:** return a safe non-success outcome, write no final artifact, and disclose neither path nor personal content; test in Tasks 1 and 2.
4. **A disposable-root override resolving to production/archive/symlinked data:** refuse before opening a database or starting the release bundle; test in Task 3.
5. **A clean-machine release bundle missing a shared library, desktop integration file, or native GTK chooser proof:** fail the packaging gate or record the manual check as incomplete, not passed; test/inspect in Tasks 4 and 6.

---

## File responsibilities

- `lib/core/files/atomic_file_publisher.dart`: creates staging output in an owned temporary directory and atomically replaces a validated selected destination.
- `lib/core/files/backup_service.dart`: serializes snapshot creation through the database service, validates read-only snapshots, and produces safe backup results.
- `lib/core/files/work_export_service.dart`: obtains fact projections, constructs a versioned Work export document, validates it, and publishes it atomically.
- `lib/core/files/work_export_schema.dart`: defines export schema version `1`, record DTOs, canonical JSON encoding, and structural validation.
- `lib/core/files/destination_picker_file_selector.dart`: production adapter over `file_selector`; no repository/data access.
- `lib/features/system_files/presentation/system_files_screen.dart`: native backup/export controls and safe outcome announcements at `/system/files`.
- `test/core/files/*.dart`: file-layer unit tests with temporary owned roots and fake database/picker adapters.
- `integration_test/native_workflow_test.dart`: full synthetic native path: setup, active shift restart, Work review/correction, backup/export, and route restoration.
- `tool/verify_native.dart`: creates and validates an owned temporary root, runs the release bundle smoke process, and removes only its own root.
- `tool/check_release_bundle.dart`: checks artifact manifest, expected bundle paths, release executable `ldd`, and forbidden network/background-service declarations.
- `tool/write_checksums.sh`: invokes the system `sha256sum` utility over the exact sorted release artifact set and writes `SHA256SUMS`.
- `tool/package_rpm.sh`: builds the RPM only from the release bundle and packaging manifest.
- `packaging/linux/io.lifeos.LifeOS.desktop`: desktop entry for `io.lifeos.LifeOS`.
- `packaging/linux/io.lifeos.LifeOS.metainfo.xml`: AppStream metadata.
- `packaging/linux/io.lifeos.LifeOS.spec`: Fedora RPM definition and file manifest.
- `packaging/linux/icons/hicolor/*/apps/io.lifeos.LifeOS.png`: LifeOS-owned application icons.
- `app.sh`: non-interactive native launcher command dispatcher; no `uv`, `manage.py`, `runserver`, or numeric menu.
- `test/app_script_test.dart`: native launcher command and guard contract.
- `README.md`: native installation/development/release and archive boundary documentation.
- `docs/release/manual-linux-checklist.md`: the exact manual GTK chooser and clean-Fedora checks, including pass/fail recording rules.
- `docs/verification/2026-09-29-native-release.md`: actual release verification, known limitations, checksums, reviewer disposition, and manual-check outcome.
- `DESIGN.md`, `.impeccable/design.json`, `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md`: only after valid capture/review; describe shipped native code rather than intended direction.

### Task 1: Create WAL-safe, validated manual backup

**Files:**
- Create: `lib/core/files/atomic_file_publisher.dart`
- Create: `lib/core/files/backup_service.dart`
- Create: `test/core/files/backup_service_test.dart`
- Create: `test/core/files/atomic_file_publisher_test.dart`

**Interfaces:**
- Consumes: the plan-01 database service adapter, which exposes serialized `Future<void> createSnapshot(File destination, SnapshotMetadata metadata)` and `Future<DatabaseIdentity> validateReadOnly(File snapshot)`; `DestinationPicker.chooseBackupDestination()` from the master plan. Validation confirms `lifeOsApplicationId`, schema compatibility, integrity, and embedded snapshot metadata.
- Produces:

```dart
sealed class BackupResult { const BackupResult(); }
final class BackupCompleted extends BackupResult {
  const BackupCompleted({required this.createdAt, required this.schemaVersion});
  final DateTime createdAt;
  final int schemaVersion;
}
final class BackupCancelled extends BackupResult { const BackupCancelled(); }
final class BackupFailed extends BackupResult {
  const BackupFailed(this.code);
  final SafeFailureCode code;
}
final class BackupUncertain extends BackupResult {
  const BackupUncertain(this.code);
  final SafeFailureCode code;
}

abstract interface class AtomicFilePublisher {
  Future<void> publish({required File staged, required Uri destination});
}

abstract interface class BackupService {
  Future<BackupResult> createManualBackup();
}
```

`DatabaseIdentity` must contain only validated application ID and schema version; it never includes a path or record content. The expected native application ID and a nonempty source DB are checked by the database service itself.

- [ ] **Step 1: Write failing snapshot and publication tests**

```dart
test('validates a read-only snapshot before atomically replacing destination', () async {
  final destination = File('${root.path}/chosen/lifeos-backup.sqlite');
  await destination.parent.create(recursive: true);
  await destination.writeAsString('previous-safe-file');
  final database = FakeDatabaseService(
    snapshotBytes: bytesWithWalCommittedRecord,
    identity: const DatabaseIdentity(applicationId: lifeOsApplicationId, schemaVersion: 2),
    integrityOk: true,
  );
  final service = BackupServiceImpl(database: database, picker: FakePicker.backup(destination.uri), publisher: publisher);

  final result = await service.createManualBackup();

  expect(result, isA<BackupCompleted>());
  expect(database.liveFileCopyCalls, 0);
  expect(database.snapshotCalls, 1);
  expect(database.readOnlyValidationCalls, 1);
  expect(await destination.readAsBytes(), bytesWithWalCommittedRecord);
});

test('wrong identity leaves prior destination unchanged', () async {
  final destination = await writeExistingDestination(root, 'keep-this');
  final service = BackupServiceImpl(
    database: FakeDatabaseService(identity: const DatabaseIdentity(applicationId: 7, schemaVersion: 1)),
    picker: FakePicker.backup(destination.uri),
    publisher: publisher,
  );
  expect(await service.createManualBackup(), isA<BackupFailed>());
  expect(await destination.readAsString(), 'keep-this');
});
```

Add tests for absent picker selection, integrity failure, snapshot exception, destination parent failure, staged-file cleanup, replacement rollback, an indeterminate rename/rollback returning `BackupUncertain`, and embedded metadata exactly equal to application version `0.1.0`, schema version `2`, and UTC creation time `2026-09-29T12:00:00.000Z`. Prove validation reads those values from the staged snapshot before publication and that safe error messages contain neither the destination path nor a synthetic label.

- [ ] **Step 2: Run tests and confirm failure**

Run: `flutter test test/core/files/backup_service_test.dart test/core/files/atomic_file_publisher_test.dart`

Expected: FAIL because no backup service, publisher, or metadata manifest exists.

- [ ] **Step 3: Implement snapshot-first backup and atomic publication**

Request a destination first; return `BackupCancelled` without creating staging state if it is `null`. Create the staged SQLite file in a unique temporary name inside the selected destination's parent so the final rename stays on one filesystem. In order: call database `createSnapshot(stagedSqlite, SnapshotMetadata(...))`, reopen it read-only, validate `lifeOsApplicationId`, supported schema, embedded metadata, and `PRAGMA integrity_check`, fsync/close the staged file, then rename that one file over the selected `.sqlite` destination. Preserve an existing destination until validation succeeds; if the platform cannot replace an existing file atomically, use a same-directory previous-file rename with rollback and report `Uncertain` whenever final state cannot be proven. Delete only LifeOS-created staging/previous files in `finally`. Never invoke `File.copy` on the live database path and never publish metadata separately from the snapshot.

- [ ] **Step 4: Run backup tests, formatter, and analyzer**

Run:

```bash
flutter test test/core/files/backup_service_test.dart test/core/files/atomic_file_publisher_test.dart
dart format --set-exit-if-changed lib/core/files test/core/files
flutter analyze
```

Expected: PASS; all failed validations preserve the prior destination and report a safe code only.

- [ ] **Step 5: Commit the backup boundary**

```bash
git add lib/core/files/atomic_file_publisher.dart lib/core/files/backup_service.dart lib/core/database/database_service.dart test/core/files/backup_service_test.dart test/core/files/atomic_file_publisher_test.dart
git commit -m "feat: add validated WAL-safe backups

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 2: Create versioned Work JSON export and system-file controls

**Files:**
- Create: `lib/core/files/work_export_schema.dart`
- Create: `lib/core/files/work_export_service.dart`
- Create: `lib/core/files/destination_picker_file_selector.dart`
- Create: `lib/features/system_files/presentation/system_files_screen.dart`
- Create: `test/core/files/work_export_service_test.dart`
- Create: `test/features/system_files/presentation/system_files_screen_test.dart`
- Modify: `lib/app/app_router.dart`

**Interfaces:**
- Consumes plan-03 repositories/projections for employment, agreements, shifts/breaks, periods, payslips, and relation IDs; `DestinationPicker.chooseExportDestination`; `AtomicFilePublisher` from Task 1.
- Produces:

```dart
const int workExportSchemaVersion = 1;

final class WorkExportDocument {
  const WorkExportDocument({
    required this.schemaVersion,
    required this.exportedAt,
    required this.employments,
    required this.agreements,
    required this.shifts,
    required this.breaks,
    required this.periods,
    required this.payslips,
  });
  final int schemaVersion;
  final DateTime exportedAt;
  final List<ExportEmployment> employments;
  final List<ExportAgreement> agreements;
  final List<ExportShift> shifts;
  final List<ExportBreak> breaks;
  final List<ExportPayPeriod> periods;
  final List<ExportPayslip> payslips;
  Map<String, Object?> toJson();
}

sealed class ExportResult { const ExportResult(); }
final class ExportCompleted extends ExportResult { const ExportCompleted(this.schemaVersion); final int schemaVersion; }
final class ExportCancelled extends ExportResult { const ExportCancelled(); }
final class ExportFailed extends ExportResult { const ExportFailed(this.code); final SafeFailureCode code; }
```

- [ ] **Step 1: Write failing export schema, picker, and UI tests**

```dart
test('version one export retains facts and correction relationships', () async {
  final document = await WorkExportServiceImpl(repository: repository, clock: fixedClock, picker: picker, publisher: publisher).buildDocument();
  final json = document.toJson();
  expect(json['schemaVersion'], 1);
  expect(json.keys, containsAll(['employments', 'agreements', 'shifts', 'breaks', 'periods', 'payslips']));
  expect((json['shifts'] as List).single['replacementShiftId'], replacement.id.value);
  expect((json['payslips'] as List).single['voidReason'], 'Synthetic correction reason');
  expect(json.containsKey('authoritativeReconciliation'), isFalse);
});

testWidgets('cancelled export picker writes no file and announces cancellation', (tester) async {
  await tester.pumpWidget(TestSystemFilesScreen(exportService: FakeExportService.cancelled()));
  await tester.tap(find.text('Export Work data'));
  await tester.pump();
  expect(find.text('Export cancelled.'), findsOneWidget);
  expect(find.textContaining('/tmp/'), findsNothing);
});
```

Add a schema validator test that rejects version `0`, missing `rateBasis`, binary floating monetary fields, dangling relation IDs, and a document with derived `expectedAmount` presented as authoritative. Test destination write failure and picker cancellation with no final output. Test `/system/files` route and labels **Create backup** and **Export Work data**, each explaining plaintext owner-controlled files and not calling them a payslip/tax/payroll report.

- [ ] **Step 2: Run tests and confirm failure**

Run: `flutter test test/core/files/work_export_service_test.dart test/features/system_files/presentation/system_files_screen_test.dart`

Expected: FAIL because export schema/service, picker adapter, System Files screen, and route do not exist.

- [ ] **Step 3: Implement canonical export and safe System Files surface**

Encode strict canonical JSON with `format: "lifeos-work-export"`, `schemaVersion: 1`, UTC `exportedAt`, typed IDs as strings, dates as ISO dates, instants as UTC ISO-8601 strings, money as integer minor/micro-unit fields, and explicit basis/currency/lifecycle/replacement facts. Call `validateWorkExportDocument()` before atomic publication. The production picker sets suggested filenames `lifeos-backup.sqlite` and `lifeos-work-export-v1.json`, but never persists paths. The screen reports only outcome/status and schema version; it does not reveal a selected path.

- [ ] **Step 4: Run export and route regressions**

Run:

```bash
flutter test test/core/files/work_export_service_test.dart test/features/system_files/presentation/system_files_screen_test.dart test/app/router_test.dart
flutter analyze
```

Expected: PASS; export JSON validates before output and cancelled operations write nothing.

- [ ] **Step 5: Commit export and file surface**

```bash
git add lib/core/files/work_export_schema.dart lib/core/files/work_export_service.dart lib/core/files/destination_picker_file_selector.dart lib/features/system_files/presentation/system_files_screen.dart lib/app/app_router.dart test/core/files/work_export_service_test.dart test/features/system_files/presentation/system_files_screen_test.dart
git commit -m "feat: add versioned Work export

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 3: Guard native integration and release-bundle smoke tests

**Files:**
- Create: `integration_test/native_workflow_test.dart`
- Create: `tool/owned_data_root.dart`
- Create: `tool/verify_native.dart`
- Create: `test/tool/owned_data_root_test.dart`
- Create: `test/tool/verify_native_test.dart`

**Interfaces:**
- Consumes the complete Work application/UI from plans 01–04 and Task 1/2 fake picker adapters.
- Produces:

```dart
const ownedRootMarkerName = '.lifeos-test-owned';

Future<Directory> createOwnedDataRoot(Directory parent);
Future<void> requireOwnedDataRoot(Directory root);
Future<void> deleteOwnedDataRoot(Directory root);

Future<int> verifyNative({
  required Directory ownedRoot,
  required String bundleExecutable,
  required ProcessRunner runner,
});
```

- [ ] **Step 1: Write failing root guard and end-to-end integration tests**

```dart
test('guard rejects symlinked root before any database open', () async {
  final unsafe = Link('${temp.path}/unsafe')..createSync(productionLikeRoot.path);
  await expectLater(requireOwnedDataRoot(Directory(unsafe.path)), throwsA(isA<UnsafeDataRoot>()));
  expect(fakeDatabase.openCalls, 0);
});

testWidgets('synthetic workflow backs up and exports through fake picker adapters', (tester) async {
  await tester.pumpWidget(IntegrationLifeOSApp.withOwnedRoot(root));
  await createEmploymentAgreementShiftBreakFinalizePeriodPayslipAndCorrection(tester);
  await tester.tap(find.text('Create backup'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Export Work data'));
  await tester.pumpAndSettle();
  expect(await File('${root.path}/chosen/lifeos-backup.sqlite').exists(), isTrue);
  expect(await File('${root.path}/chosen/lifeos-work-export-v1.json').exists(), isTrue);
});
```

Add integration coverage for fresh schema creation, active running shift restart, balanced and differing reconciliation, safe route/selection restoration, and release bundle startup. Assert synthetic records begin `Synthetic ` and tests do not use a user home application-support path. Add process tests for a bundle start supplied with an unmarked root, unexpected HTTP listener text, nonzero early exit, and clean termination.

- [ ] **Step 2: Run guard and integration tests and confirm failure**

Run:

```bash
flutter test test/tool/owned_data_root_test.dart test/tool/verify_native_test.dart
flutter test integration_test/native_workflow_test.dart
```

Expected: FAIL because owned-root utilities, verifier, and native integration workflow do not exist.

- [ ] **Step 3: Implement fail-closed root and verifier behavior**

`createOwnedDataRoot` must create a unique child, write a marker containing a fixed non-personal ownership token, canonicalize it, and reject symlinks. `requireOwnedDataRoot` rejects missing marker, normal application-support directories, roots outside the verifier’s temporary parent, symlink resolutions, and a preexisting unmarked database. `verifyNative` starts the release executable with `LIFEOS_DATA_ROOT=<owned root>`, waits for native readiness using a process-safe marker rather than HTTP, confirms no listener/server child is requested, sends SIGTERM, and returns zero only on clean exit. Delete only a root whose marker/token was created by this process.

- [ ] **Step 4: Run native integration verification**

Run:

```bash
flutter test test/tool/owned_data_root_test.dart test/tool/verify_native_test.dart
flutter test integration_test/native_workflow_test.dart
flutter analyze
```

Expected: PASS; all filesystem activity remains below a marked temporary root.

- [ ] **Step 5: Commit integration safeguards**

```bash
git add integration_test/native_workflow_test.dart tool/owned_data_root.dart tool/verify_native.dart test/tool/owned_data_root_test.dart test/tool/verify_native_test.dart
git commit -m "test: verify guarded native release workflows

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 4: Build Fedora bundle, RPM, desktop integration, checksums, and library checks

**Files:**
- Create: `tool/check_release_bundle.dart`
- Create: `tool/write_checksums.sh`
- Create: `tool/package_rpm.sh`
- Create: `packaging/linux/io.lifeos.LifeOS.desktop`
- Create: `packaging/linux/io.lifeos.LifeOS.metainfo.xml`
- Create: `packaging/linux/io.lifeos.LifeOS.spec`
- Create: `packaging/linux/icons/hicolor/48x48/apps/io.lifeos.LifeOS.png`
- Create: `packaging/linux/icons/hicolor/128x128/apps/io.lifeos.LifeOS.png`
- Create: `packaging/linux/icons/hicolor/256x256/apps/io.lifeos.LifeOS.png`
- Create: `test/tool/check_release_bundle_test.dart`
- Create: `test/packaging/linux_metadata_test.dart`

**Interfaces:**
- Consumes `flutter build linux --release` output at `build/linux/x64/release/bundle/` and version from `pubspec.yaml`.
- Produces release directory `dist/` containing `lifeos-<version>-linux-x64.tar.gz`, `lifeos-<version>-1.x86_64.rpm`, and `SHA256SUMS`; all package identity sources use `io.lifeos.LifeOS`.

- [ ] **Step 1: Write failing package metadata/artifact tests**

```dart
test('desktop entry and AppStream metadata use native application ID', () {
  expect(desktopEntry, contains('Name=LifeOS'));
  expect(desktopEntry, contains('Exec=lifeos'));
  expect(desktopEntry, contains('Icon=io.lifeos.LifeOS'));
  expect(appStream, contains('<id>io.lifeos.LifeOS</id>'));
  expect(appStream, contains('<launchable type="desktop-id">io.lifeos.LifeOS.desktop</launchable>'));
});

test('bundle check reports each missing ldd dependency and fails', () async {
  final result = await checkReleaseBundle(fakeBundle.withLdd('libsqlite3.so.0 => not found'));
  expect(result.ok, isFalse);
  expect(result.problems, contains('missing shared library: libsqlite3.so.0'));
});
```

Add tests that the RPM spec contains no `%post` system service, no network download command, installs desktop/AppStream/icons, and package scripts reject a missing bundle. Test the checksum script in `test/tool/check_release_bundle_test.dart` with a fake `sha256sum` on `PATH`: it must sort exactly the tarball and RPM by filename and emit standard `sha256sum` lines (`<64 hex><two spaces><filename>`). Test `ldd` runs against the executable and every executable/bundled `.so` file and rejects `not found`.

- [ ] **Step 2: Run package tests and confirm failure**

Run: `flutter test test/tool/check_release_bundle_test.dart test/packaging/linux_metadata_test.dart`

Expected: FAIL because packaging files and release check tools do not exist.

- [ ] **Step 3: Implement Fedora packaging configuration**

Set `.desktop` `Type=Application`, `Categories=Utility;`, `Terminal=false`, `StartupWMClass=io.lifeos.LifeOS`, and visible `Name=LifeOS`. Set AppStream component ID and launchable desktop ID to `io.lifeos.LifeOS`; use local icon assets and a privacy/local-first description with no encryption claim. `package_rpm.sh` must invoke `rpmbuild` only after `check_release_bundle.dart` passes, copy only bundle/package files to a staging tree, and produce the named RPM. `write_checksums.sh` requires the system `sha256sum`, sorts the exact tarball/RPM basenames under a locale-stable `LC_ALL=C`, and writes standard output to `dist/SHA256SUMS`; no Dart crypto dependency is added. Do not generate Debian, Flatpak, or Snap outputs.

- [ ] **Step 4: Build and check artifacts on Fedora-compatible Linux**

Run:

```bash
flutter build linux --release
flutter test test/tool/check_release_bundle_test.dart test/packaging/linux_metadata_test.dart
dart run tool/check_release_bundle.dart --bundle build/linux/x64/release/bundle
bash tool/package_rpm.sh --bundle build/linux/x64/release/bundle --dist dist
bash tool/write_checksums.sh --dist dist
```

Expected: Flutter bundle, RPM, tarball, and `dist/SHA256SUMS` exist; every `ldd` target resolves; metadata tests PASS.

- [ ] **Step 5: Commit packaging assets and release checks**

```bash
git add tool/check_release_bundle.dart tool/write_checksums.sh tool/package_rpm.sh packaging/linux test/tool/check_release_bundle_test.dart test/packaging/linux_metadata_test.dart
git commit -m "build: package native LifeOS for Fedora

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 5: Replace launcher and documentation without touching the archive

**Files:**
- Modify: `app.sh`
- Create: `test/app_script_test.dart`
- Modify: `README.md`
- Create: `docs/release/manual-linux-checklist.md`
- Delete: `tests/test_app_script.py`

**Interfaces:**
- Consumes Flutter executable and tools from Tasks 3–4.
- Produces exact commands:

```text
./app.sh format-check
./app.sh analyze
./app.sh generate-check
./app.sh test
./app.sh verify
./app.sh build
./app.sh start --data-root <owned disposable root>
```

- [ ] **Step 1: Write failing launcher contract tests**

```dart
test('start requires a marked disposable root and does not start HTTP services', () async {
  final result = await runAppScript(['start', '--data-root', unmarked.path], environment: fakeFlutterEnvironment);
  expect(result.exitCode, isNot(0));
  expect(result.stderr, contains('owned LifeOS data root'));
  expect(result.stdout, isNot(contains('runserver')));
  expect(result.stdout, isNot(contains('http://')));
});

test('build runs Flutter release build, bundle check, RPM packaging, and checksums', () async {
  final result = await runAppScript(['build'], environment: recordingEnvironment);
  expect(result.exitCode, 0);
  expect(recordingEnvironment.commands, [
    ['flutter', 'build', 'linux', '--release'],
    ['dart', 'run', 'tool/check_release_bundle.dart', '--bundle', 'build/linux/x64/release/bundle'],
    ['bash', 'tool/package_rpm.sh', '--bundle', 'build/linux/x64/release/bundle', '--dist', 'dist'],
    ['bash', 'tool/write_checksums.sh', '--dist', 'dist'],
  ]);
});
```

Add tests for no argument/unknown command usage, Flutter version `3.47.5` and Dart version `3.13.4` checks, dependency resolution using the committed `pubspec.lock` before dispatch, `format-check` using `dart format --set-exit-if-changed lib test integration_test tool`, `analyze` using `flutter analyze`, `generate-check` using `dart run build_runner build --delete-conflicting-outputs` followed by `git diff --exit-code -- lib`, `test` using `flutter test`, `verify` running native integration and bundle smoke with owned storage, and no command text containing `uv`, `manage.py`, `pytest`, or `runserver`.

- [ ] **Step 2: Run launcher tests and confirm failure**

Run: `flutter test test/app_script_test.dart`

Expected: FAIL because current `app.sh` is an interactive Django/uv launcher and the native contract test does not exist.

- [ ] **Step 3: Implement the non-interactive native launcher and docs**

Replace the numeric menu entirely. Make `app.sh` `set -Eeuo pipefail`, resolve its own root, require the pinned Flutter/Dart toolchain, run `flutter pub get` against the committed lockfile as dependency/bootstrap validation before command dispatch, reject lockfile drift, reject unknown commands, and dispatch only the interface commands above. `start` must call `tool/owned_data_root.dart` validation before `flutter run -d linux --release` with `LIFEOS_DATA_ROOT`; it must not derive a data directory itself. `verify` creates a fresh owned root, runs integration tests with fake destination pickers, builds if missing, runs `verify_native.dart`, and cleans only its marker-owned root. README must identify Flutter Linux as active, state the exact launcher commands, explain synthetic/disposable verification, and state plainly that Django source/database are archive material never read by the native app. The manual checklist must require recording PASS/FAIL for real GTK backup and export chooser selection, clean-Fedora launch, `ldd` review, and no unexpected service/network behavior.

- [ ] **Step 4: Run launcher and documentation verification**

Run:

```bash
flutter test test/app_script_test.dart
./app.sh format-check
./app.sh analyze
./app.sh generate-check
./app.sh test
./app.sh verify
./app.sh build
```

Expected: PASS. Then create a fresh marker-owned root with `dart run tool/owned_data_root.dart --create`, run `./app.sh start --data-root <printed-root>`, verify native window launch with no HTTP listener, terminate it cleanly, and run `./app.sh test` once more. Record the actual root only in terminal session state, never in repository documentation.

- [ ] **Step 5: Commit launcher/documentation cutover**

```bash
git add app.sh test/app_script_test.dart README.md docs/release/manual-linux-checklist.md
git rm tests/test_app_script.py
git commit -m "build: cut over to native LifeOS launcher

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 6: Mark obsolete React drafts inactive without deleting user files

**Files:**
- Create: `docs/superpowers/plans/README.md`
- Create: `test/docs/archive_boundary_test.dart`
- Preserve without reading, editing, deleting, or committing:
  - `docs/superpowers/plans/2026-09-28-lifeos-workbench-implementation.md`
  - `docs/superpowers/plans/2026-09-28-lifeos-workbench-01-foundation.md`
  - `docs/superpowers/plans/2026-09-28-lifeos-workbench-02-today-work.md`

**Interfaces:**
- Consumes the native specification’s existing `**Supersedes:**` statement.
- Produces an archive-safe plan index naming `2026-09-29-lifeos-native-implementation.md` as the only active implementation entry point. It never inspects or mutates Django source/data, committed historical specifications, or user-owned untracked drafts.

- [ ] **Step 1: Write the failing archive-boundary test**

Create `test/docs/archive_boundary_test.dart` with checks that the native spec still contains `**Supersedes:**`; `README.md` says the native application does not inspect the Django database; `docs/superpowers/plans/README.md` names the native master plan as active and the three `2026-09-28` React paths as inactive/not executable; and no native `lib/`, `tool/`, `packaging/`, `app.sh`, or root README file contains `manage.py`, `runserver`, Django database path probing, or React execution commands.

- [ ] **Step 2: Run the test and confirm failure**

Run: `flutter test test/docs/archive_boundary_test.dart`

Expected: FAIL until Task 5’s launcher/README cutover and the active-plan index exist.

- [ ] **Step 3: Write the non-destructive active-plan index**

Create `docs/superpowers/plans/README.md` with these explicit rules: the native `2026-09-29` master and its five linked phase plans are active; the three named `2026-09-28` React plan drafts are superseded and must not be executed; their presence is archival/user-owned and does not authorize reading, deletion, migration, or commit; the committed `2026-09-28` specification remains historical context only.

- [ ] **Step 4: Re-run archive-boundary test and inspect status**

Run:

```bash
flutter test test/docs/archive_boundary_test.dart
git status --short -- docs/superpowers/plans
```

Expected: PASS; the new index/test are the only Task-6 changes, and all named old drafts remain byte-for-byte untouched and untracked if they started untracked.

- [ ] **Step 5: Commit only the index and boundary test**

```bash
git add docs/superpowers/plans/README.md test/docs/archive_boundary_test.dart
git commit -m "docs: mark native implementation plan active

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 7: Complete bounded Impeccable review and release documentation

**Files:**
- Create: `docs/verification/2026-09-29-native-release.md`
- Create: `test/docs/release_record_test.dart`
- Modify after valid review only: `DESIGN.md`
- Modify after valid review only: `.impeccable/design.json`
- Modify after valid review only: `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md`

**Interfaces:**
- Consumes release artifacts/verification output, valid synthetic viewport captures, the Task-6 archive-boundary result, and the actual independent Impeccable reviewer disposition.
- Produces a factual release record and shipped-design documentation. The only accepted finish-review dispositions are `recapture`, `rebuild`, `fix`, and `ship`.

- [ ] **Step 1: Write the failing release-record test**

Create `test/docs/release_record_test.dart` requiring headings **Automated checks**, **Manual GTK chooser**, **Fedora smoke**, **Impeccable disposition**, **Known limitations**, and **Artifact checksums**. Require one explicit line stating GTK chooser verification is manual and another stating each non-`ship` disposition blocks release documentation from claiming visual approval.

- [ ] **Step 2: Run the release-record test and confirm failure**

Run: `flutter test test/docs/release_record_test.dart`

Expected: FAIL because the release record has not yet been produced from an actual release run.

- [ ] **Step 3: Run the bounded Impeccable finish pass only after complete native surface exists**

Invoke the project `impeccable` skill through the host Skill tool and follow its native finish workflow; do not emulate skill invocation with a shell command. Run its one-time context command only if it has not already run in the implementation session, then use the Phase-04 surface brief as the direction contract.

Capture in one batch using only synthetic data: `1280×760` light and dark for empty setup, dense selected inspect, manual-edit validation, running, on-break, stale conflict, void-and-replace confirmation, unavailable, uncertain outcome, and `/system/files`; plus constrained `960×760` sequential return flow at text scale `2.0` and high contrast/reduced motion where supported. If any required capture is missing/malformed, record disposition `recapture`, repair the capture setup, and do not ask the finish reviewer for approval.

With a valid capture set, request the Impeccable finish reviewer against the native spec, `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md`, changed paths, and capture manifest. For `fix`, apply every material finding in one batch, recapture affected states once, and request one confirmation review. For `rebuild`, return to the implementation plan; do not publish documentation as shipped. Do not begin another polish round.

- [ ] **Step 4: Document shipped code after actual reviewer outcome**

Only with valid captures and final `ship` disposition, inspect the existing `DESIGN.md`; if it exists, follow the Impeccable document workflow's required user choice before refresh/merge/overwrite. Then run the Impeccable documenter using that choice—never silently overwrite—`DESIGN.md` and regenerate `.impeccable/design.json` from shipped Flutter components/tokens. Update `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md` only with actual capture/reviewer provenance. Write `docs/verification/2026-09-29-native-release.md` with exact command outcomes, artifact filenames and SHA-256 values, clean-Fedora environment/result, `ldd` result, GTK backup/export chooser result, reviewer disposition, capture limitations, Task-6 preservation/deletion decision, and explicit deferred items (restore, Debian, Flatpak, Snap, encryption, cloud sync). Never write personal paths, data, labels, notes, amounts, screenshots containing personal data, SQL, or raw exceptions.

- [ ] **Step 5: Run final release gate and document test**

Run:

```bash
flutter test test/docs/archive_boundary_test.dart test/docs/release_record_test.dart
./app.sh format-check
./app.sh analyze
./app.sh generate-check
./app.sh test
./app.sh verify
./app.sh build
dart run tool/check_release_bundle.dart --bundle build/linux/x64/release/bundle
sha256sum --check dist/SHA256SUMS
git diff --check
git status --short
```

Expected: all checks PASS; checksum verification reports every distributed artifact `OK`; manual GTK chooser has an explicit PASS/FAIL result; the historical spec remains; no tracked/unrelated user work is deleted.

- [ ] **Step 6: Commit release evidence and design record**

```bash
git add docs/verification/2026-09-29-native-release.md DESIGN.md .impeccable/design.json .impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md test/docs/release_record_test.dart
git commit -m "docs: record native release verification

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

Do not commit this task if the actual reviewer disposition remains `recapture`, `rebuild`, or `fix`; complete its required corrective path first.

## Plan self-review

Spec coverage: Tasks 1–2 implement the mandated owner-selected, serialized, WAL-safe backup and distinct versioned export, including identity/integrity validation and safe outcomes. Task 3 supplies guarded native integration, active-shift restart, route restoration, fake chooser tests, and release-bundle startup. Task 4 covers the required Fedora bundle/RPM/desktop/icon/AppStream/checksum outputs and `ldd` checks. Task 5 replaces the Django launcher and proves `app.sh` tests and starts the native process on owned storage. Task 6 isolates obsolete-untracked-plan cleanup from archive preservation. Task 7 completes bounded Impeccable review/documentation only after valid captures and a `ship` disposition. Each Review Focus risk has an owning test or manual release gate.

Placeholder scan: every task has concrete paths, types, commands, expected failures, verification commands, and commit commands. RPM build-tool versions are deliberately not invented because the approved master does not pin them; the package script checks the system `rpmbuild` capability and fails with a concrete missing-tool error rather than selecting a hidden dependency.

Type consistency: all file outcomes use `SafeFailureCode`, `DestinationPicker`, `MutationOutcome`-compatible application boundaries, and safe `/system/files` routing from the master plan. Backup/export publication shares the Task-1 `AtomicFilePublisher`; integration roots share the Task-3 marker contract; launcher commands exactly match the master completion check.

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-29-lifeos-native-05-release-cutover.md`. Please review the two plans. Does their scope and task order capture what you want?
