# LifeOS Native Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the pinned Flutter/Linux project, guarded native data boundary, deterministic time/database services, privacy-safe bootstrap, and application-frame skeleton without implementing Work behavior.

**Architecture:** Flutter becomes the active root application while the Django tree remains an untouched archive. Bootstrap resolves a guarded application-data root, initializes privacy/time services, opens one identified Drift database on a background isolate, validates migrations and PRAGMAs, constructs providers/routes, and only then shows the native window.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, Drift 2.35.0, drift_flutter 0.3.1, sqlite3 3.6.0, Riverpod 3.4.3, GoRouter 18.0.2, window_manager 0.5.2, timezone 0.11.1.

**Spec:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md`

## Global Constraints

- Preserve `lifeos/`, Django migrations, templates, Python tests, and any existing personal database as archival material; native code never imports or launches them.
- Pin Flutter `3.47.5`, Dart `3.13.4`, and every direct package exactly; commit `pubspec.lock`.
- Application ID is `io.lifeos.LifeOS`; native database name is `lifeos-native-v1.sqlite`; SQLite `application_id` is `0x4C49464F` (`1279870543`).
- Runtime/test databases never live in the repository. Test roots require an ownership marker and may not resolve to production support storage, including through symlinks.
- Reject a nonempty SQLite file without the LifeOS application ID; never adopt arbitrary SQLite.
- Enable and verify foreign keys, WAL, busy timeout, and the chosen synchronous policy.
- Diagnostics accept bounded safe fields only, not arbitrary strings, paths, SQL, values, notes, dates, times, IDs, or amounts.
- Startup order follows the approved specification and the native window remains hidden until stable state or a safe recovery surface is ready.

## Review Focus

1. A symlinked test root resolving into production storage is rejected before SQLite opens.
2. A valid SQLite file with a missing/wrong application ID is rejected without migrations.
3. A migration failure leaves no writable partial application and exposes no raw exception/path.
4. DST fold/gap conversion is explicit; supplied invalid local dates never become today.
5. Generated code, schema snapshots, and dependency pins cannot drift unnoticed.

---

### Task 1: Establish the Native Repository and Toolchain Contract

**Files:**
- Create: `.fvmrc`
- Create: `pubspec.yaml`
- Create: `pubspec.lock`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`
- Create: `linux/` through the Flutter Linux scaffold
- Create: `test/toolchain/toolchain_contract_test.dart`
- Modify: `.gitignore`

**Interfaces:**
- Produces: a Linux-only Flutter root package named `lifeos`, application ID `io.lifeos.LifeOS`, and commands usable by every later phase.

- [ ] **Step 1: Verify the host prerequisite before scaffolding**

Run:

```bash
flutter --version
dart --version
flutter doctor -v
flutter config --enable-linux-desktop
```

Expected: Flutter `3.47.5`, Dart `3.13.4`, Linux desktop enabled, and no blocking Linux toolchain finding. If unavailable or different, stop; install/select the pinned SDK rather than generating with another version.

- [ ] **Step 2: Write the failing toolchain contract test**

```dart
test('repository pins the approved native toolchain', () {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  expect(File('.fvmrc').readAsStringSync().trim(), '{"flutter":"3.47.5"}');
  expect(pubspec, contains('sdk: ">=3.13.4 <3.14.0"'));
  expect(pubspec, isNot(contains('http:')));
  expect(pubspec, isNot(contains('django')));
  expect(File('linux/CMakeLists.txt').existsSync(), isTrue);
  expect(Directory('web').existsSync(), isFalse);
});
```

- [ ] **Step 3: Confirm RED**

Run: `flutter test test/toolchain/toolchain_contract_test.dart`
Expected: FAIL because the Flutter package and contract file do not exist.

- [ ] **Step 4: Generate Linux only and replace generated dependency declarations**

Run:

```bash
flutter create --platforms=linux --org=io.lifeos --project-name=lifeos .
rm -rf web android ios macos windows
```

Pin these direct versions in `pubspec.yaml`: `drift 2.35.0`, `drift_flutter 0.3.1`, `sqlite3 3.6.0`, `flutter_riverpod 3.4.3`, `go_router 18.0.2`, `file_selector 1.1.0`, `path_provider 2.1.6`, `path 1.9.1`, `window_manager 0.5.2`, `uuid 4.6.0`, `clock 1.1.3`, and `timezone 0.11.1`. Pin dev dependencies `flutter_lints 6.0.0`, `drift_dev 2.35.0`, and `build_runner 2.16.1`; use SDK `flutter_test` and `integration_test` rather than a pub-hosted integration package.

Configure strict analysis. Ignore generated `*.g.dart` only for lint rules, not compilation. Add `.dart_tool/`, `.fvm/`, `build/`, native runtime databases, WAL/SHM files, backups, and exports to `.gitignore`; do not ignore `pubspec.lock` or schema snapshots.

- [ ] **Step 5: Verify GREEN and the native boundary**

```bash
flutter pub get
flutter test test/toolchain/toolchain_contract_test.dart
flutter analyze
flutter build linux --debug
```

Expected: PASS; a Linux bundle builds and no web platform exists.

- [ ] **Step 6: Commit**

```bash
git add .fvmrc pubspec.yaml pubspec.lock analysis_options.yaml lib/main.dart linux test/toolchain .gitignore
git commit -m "build: establish native Flutter toolchain

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 2: Guard Application and Test Data Locations

**Files:**
- Create: `lib/core/database/database_config.dart`
- Create: `lib/core/database/database_location.dart`
- Create: `lib/core/database/test_root_guard.dart`
- Create: `test/core/database/database_location_test.dart`
- Create: `test/support/owned_test_root.dart`

**Interfaces:**
- Produces: `DatabaseConfig`, `DatabaseLocation.resolve()`, and `OwnedTestRoot.create()`.

```dart
final class DatabaseConfig {
  const DatabaseConfig.production();
  const DatabaseConfig.test({required this.root, required this.markerToken});
  final Uri? root;
  final String? markerToken;
}

abstract interface class DatabaseLocation {
  Future<File> resolve(DatabaseConfig config);
}
```

- [ ] **Step 1: Write failing path and symlink tests**

```dart
test('test database requires an owned marked root outside repository and production support', () async {
  final root = await OwnedTestRoot.create();
  final file = await location.resolve(DatabaseConfig.test(root: root.uri, markerToken: root.token));
  expect(file.path, endsWith('lifeos-native-v1.sqlite'));
  expect(file.path, isNot(contains(Directory.current.path)));
});

test('rejects a symlink resolving to production support', () async {
  final alias = await createSymlinkTo(fakeProductionSupport);
  expect(() => location.resolve(DatabaseConfig.test(root: alias.uri, markerToken: 'owned')), throwsA(isA<UnsafeDataRoot>()));
});
```

Also pin rejection of repository paths, missing/wrong markers, ordinary temporary directories without ownership, and the production support root in test mode.

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/core/database/database_location_test.dart`
Expected: FAIL because location policy is undefined.

- [ ] **Step 3: Implement canonical-path validation**

Resolve filesystem links before comparing roots. Production uses `path_provider.getApplicationSupportDirectory()` plus `io.lifeos.LifeOS`; test mode requires a marker file containing the supplied random token. Create directories with owner-only permissions where supported. Return only the fixed database filename; never scan for SQLite files or legacy names.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/core/database/database_location_test.dart`
Expected: PASS for safe root and every rejection case.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/database_config.dart lib/core/database/database_location.dart lib/core/database/test_root_guard.dart test/core/database test/support
git commit -m "feat: guard native data locations

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 3: Open an Identified Drift Database on a Background Isolate

**Files:**
- Create: `lib/core/database/app_database.dart`
- Create: `lib/core/database/database_identity.dart`
- Create: `lib/core/database/database_pragmas.dart`
- Create: `lib/core/database/database_service.dart`
- Create: `lib/core/database/migration_strategy.dart`
- Create: `lib/core/database/schema_versions.dart`
- Create: `drift_schemas/schema_v1.json`
- Create: `test/core/database/database_open_test.dart`
- Create: `test/core/database/migration_test.dart`

**Interfaces:**
- Produces: `DatabaseService.open(DatabaseConfig)`, `DatabaseService.transaction()`, `SnapshotMetadata`, snapshot creation/validation, `DatabaseIdentityMismatch`, and schema snapshot workflow. Define `const lifeOsApplicationId = 0x4C49464F` in `database_identity.dart`; every phase imports this constant rather than repeating a literal. `SnapshotMetadata` contains application version, schema version, and UTC creation time and is stored inside the snapshot's core metadata table in the same database transaction as snapshot preparation.

```dart
abstract interface class DatabaseService {
  static Future<DatabaseService> open(DatabaseConfig config);
  Future<T> transaction<T>(Future<T> Function() operation);
  Future<void> createSnapshot(File destination, SnapshotMetadata metadata);
  Future<DatabaseIdentity> validateReadOnly(File snapshot);
  Future<void> close();
}
```

- [ ] **Step 1: Write failing identity and PRAGMA tests**

```dart
test('fresh database receives identity and required pragmas', () async {
  final db = await openOwnedDatabase();
  expect(await db.scalarInt('PRAGMA application_id'), lifeOsApplicationId);
  expect(await db.scalarInt('PRAGMA foreign_keys'), 1);
  expect(await db.scalarText('PRAGMA journal_mode'), 'wal');
  expect(await db.scalarInt('PRAGMA busy_timeout'), greaterThanOrEqualTo(5000));
});

test('nonempty SQLite with wrong identity is rejected before migration', () async {
  final file = await arbitraryNonemptySqlite(applicationId: 0);
  await expectLater(DatabaseService.open(configFor(file)), throwsA(isA<DatabaseIdentityMismatch>()));
  expect(await userVersionOf(file), 0);
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/core/database/database_open_test.dart`
Expected: FAIL because database classes do not exist.

- [ ] **Step 3: Implement open/identity/PRAGMA order**

Use Drift’s background native connection. For a zero-length/new file, set the fixed nonzero `application_id` before creating schema. For a nonempty file, read identity before migrations and reject absent/wrong identity. Configure `foreign_keys=ON`, WAL, `busy_timeout=5000`, and `synchronous=FULL`; read each back and fail closed when validation differs.

- [ ] **Step 4: Add migration snapshot and immutability tests**

```dart
test('every released schema snapshot migrates and validates', () async {
  for (final snapshot in releasedSchemaSnapshots) {
    final migrated = await migrateSnapshot(snapshot);
    await expectCurrentSchema(migrated);
  }
});

test('released migration fingerprints match the ledger', () {
  expect(computeMigrationFingerprints(), releasedMigrationFingerprints);
});
```

Create version-one core metadata only. Export `drift_schemas/schema_v1.json`; store immutable migration step fingerprints in `schema_versions.dart`. Add `tool/schema_check.dart` that regenerates to a temporary directory and compares committed snapshots without rewriting them.

- [ ] **Step 5: Verify GREEN and generation drift**

```bash
dart run build_runner build --delete-conflicting-outputs
dart run tool/schema_check.dart
flutter test test/core/database
```

Expected: PASS; generated output and schema snapshots are current.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database drift_schemas tool/schema_check.dart test/core/database
git commit -m "feat: add identified native database foundation

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 4: Implement Deterministic Date, Clock, and Timezone Services

**Files:**
- Create: `lib/core/time/app_clock.dart`
- Create: `lib/core/time/local_date.dart`
- Create: `lib/core/time/local_time.dart`
- Create: `lib/core/time/timezone_service.dart`
- Create: `test/core/time/local_date_test.dart`
- Create: `test/core/time/timezone_service_test.dart`

**Interfaces:**
- Produces: the `AppClock`, `LocalDate`, `LocalTime`, `FoldChoice`, `ZonedInstant`, and `TimezoneService` contracts used by every domain.

- [ ] **Step 1: Write failing strict-date and DST tests**

```dart
test('strict date rejects malformed and impossible input', () {
  expect(LocalDate.tryParse('2026-09-29'), const LocalDate(2026, 9, 29));
  expect(LocalDate.tryParse('29/09/2026'), isNull);
  expect(LocalDate.tryParse('2026-09-31'), isNull);
});

test('fold requires an explicit occurrence and gap is invalid', () {
  expect(() => zones.resolveLocal(foldDate, foldTime, 'Europe/Berlin'), throwsA(isA<AmbiguousLocalTime>()));
  expect(() => zones.resolveLocal(gapDate, gapTime, 'Europe/Berlin', fold: FoldChoice.earlier), throwsA(isA<NonexistentLocalTime>()));
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/core/time`
Expected: FAIL because time services do not exist.

- [ ] **Step 3: Implement immutable temporal values**

`SystemAppClock.nowUtc()` returns a UTC instant. `LocalDate.parse()` accepts exactly `YYYY-MM-DD`; `tryParse()` returns null and never substitutes today. Load bundled IANA data once. Resolve folds only with explicit earlier/later choice, reject gaps, convert UTC to local deterministically, and expose the captured local date.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/core/time`
Expected: PASS, including overnight UTC duration and both DST transition classes.

- [ ] **Step 5: Commit**

```bash
git add lib/core/time test/core/time
git commit -m "feat: add deterministic temporal foundation

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 5: Add Typed Outcomes and Privacy-Safe Diagnostics

**Files:**
- Create: `lib/core/outcomes/mutation_outcome.dart`
- Create: `lib/core/privacy/safe_diagnostic.dart`
- Create: `lib/core/privacy/diagnostic_sink.dart`
- Create: `test/core/outcomes/mutation_outcome_test.dart`
- Create: `test/core/privacy/diagnostic_sink_test.dart`
- Create: `tool/privacy_scan.dart`

**Interfaces:**
- Produces: the master-plan `MutationOutcome<T>` hierarchy, `FieldIssue`, `SafeFailureCode`, `SafeDiagnostic`, and `DiagnosticSink`.

- [ ] **Step 1: Write failing closed-vocabulary tests**

```dart
test('diagnostics serialize only closed safe fields', () {
  final event = SafeDiagnostic(operation: SafeOperation.databaseOpen, outcome: SafeOutcome.unavailable, exceptionClass: 'SqliteException');
  expect(event.toJson().keys, unorderedEquals(['operation', 'outcome', 'exceptionClass', 'appVersion', 'schemaVersion']));
});

test('outcomes distinguish stale and uncertain', () {
  expect(const Stale<void>(), isNot(isA<Uncertain<void>>()));
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/core/privacy test/core/outcomes`
Expected: FAIL because types do not exist.

- [ ] **Step 3: Implement safe diagnostics and sealed outcomes**

Use enums/validated exception class names; do not expose an arbitrary message or metadata map. `DiagnosticSink` accepts only `SafeDiagnostic`. In release mode write bounded local operational lines only when explicitly enabled; never upload. Implement all six master-plan outcome variants.

Create `tool/privacy_scan.dart` to reject known personal-data fixture paths, runtime database/export extensions under tracked roots, and prohibited logger calls with interpolation in native code.

- [ ] **Step 4: Verify GREEN**

```bash
flutter test test/core/privacy test/core/outcomes
dart run tool/privacy_scan.dart
```

Expected: PASS with no private-value channel.

- [ ] **Step 5: Commit**

```bash
git add lib/core/outcomes lib/core/privacy test/core tool/privacy_scan.dart
git commit -m "feat: define safe native outcomes and diagnostics

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 6: Build Ordered Bootstrap, Safe Routes, and the Native Frame Skeleton

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/bootstrap.dart`
- Create: `lib/app/lifeos_app.dart`
- Create: `lib/app/app_router.dart`
- Create: `lib/app/app_theme.dart`
- Create: `lib/app/desktop_window_service.dart`
- Create: `lib/app/startup_recovery.dart`
- Create: `test/app/bootstrap_test.dart`
- Create: `test/app/router_test.dart`
- Create: `test/app/startup_recovery_test.dart`

**Interfaces:**
- Produces: `bootstrap(BootstrapDependencies)`, safe top-level routes, `DesktopWindowService`, and provider overrides consumed by later phases.

- [ ] **Step 1: Write failing startup-order and recovery tests**

```dart
test('window is shown only after stable services and router exist', () async {
  final trace = <String>[];
  await bootstrap(fakeDependencies(trace));
  expect(trace, ['supportDir', 'diagnostics', 'timezone', 'clock', 'database', 'schema', 'providers', 'router', 'showWindow']);
});

testWidgets('startup error exposes category without raw exception or path', (tester) async {
  await tester.pumpWidget(StartupRecovery(failure: safeStorageFailure));
  expect(find.text('Storage unavailable'), findsOneWidget);
  expect(find.textContaining('/home/'), findsNothing);
  expect(find.textContaining('SqliteException:'), findsNothing);
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/app`
Expected: FAIL because bootstrap/app modules do not exist.

- [ ] **Step 3: Implement startup and honest route skeleton**

Keep `main.dart` to bindings plus `bootstrap()`. Wrap `window_manager` only in `DesktopWindowService`; configure minimum `1280×760`, title, and delayed show. Build routes for `/today`, `/work`, `/money`, `/habits`, and `/system/files`; unimplemented surfaces render honest local unavailable states. Route parsing accepts structural IDs and strict date scopes only, never content. Startup failures close or retain read-only resources and render categorized recovery.

- [ ] **Step 4: Verify the complete foundation gate**

```bash
dart format --set-exit-if-changed lib test tool
flutter analyze
dart run build_runner build --delete-conflicting-outputs
dart run tool/schema_check.dart
dart run tool/privacy_scan.dart
flutter test test/toolchain test/core test/app
flutter build linux --debug
```

Expected: PASS; no Work behavior exists yet and no Django process or database is touched.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/bootstrap.dart lib/app test/app
git commit -m "feat: bootstrap the native LifeOS frame

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Foundation Completion Gate

- [ ] Verify `git diff -- lifeos tests` shows no accidental Django/archive edits except later explicitly approved launcher-test replacement.
- [ ] Search native runtime code for `manage.py`, `runserver`, `127.0.0.1`, `localhost`, and legacy database names; expected: no matches.
- [ ] Run all Task 6 gate commands from a clean checkout with the pinned SDK.
