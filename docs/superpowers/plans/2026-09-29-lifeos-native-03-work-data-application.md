# LifeOS Native Work Data and Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist Work facts in Drift and expose complete transactional application services without leaking SQL, persistence models, or uncertain commits into presentation.

**Architecture:** Drift tables and DAOs map to the pure Work domain from Phase 02. Repositories expose reactive projections and conditional writes; application services own validation, agreement resolution, revision checks, transaction boundaries, ID/time generation, and typed outcomes.

**Tech Stack:** Dart 3.13.4, Drift 2.35.0, sqlite3 3.6.0, Phase 01 database/time/outcome services, Phase 02 Work domain.

**Spec:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md`

## Global Constraints

- Tables store facts only; expected pay and reconciliation totals remain query/application projections.
- All money, rates, durations, revisions, and multiplier parts are integers.
- UTC instants, IANA timezone, and local start date are stored explicitly.
- Application services own transactions; widgets/controllers never call DAOs.
- Multi-record mutations either commit fully or return a typed non-success outcome.
- Revision updates use `WHERE id = ? AND revision = ?`; zero affected rows means `Stale`, not overwrite.
- One `running` or `onBreak` shift is allowed globally.
- Used agreements, finalized shifts, and effective payslip correction history are never hard-deleted.
- A transaction-exit failure whose commit status cannot be proven maps to `Uncertain`.

## Review Focus

1. Two concurrent start-shift calls produce exactly one active shift.
2. Finalization persists the resolved agreement ID in the same transaction as the state transition.
3. A stale correction cannot void the original or create an orphan replacement.
4. Restart recovers running/on-break truth solely from SQLite.
5. Void records remain queryable but are excluded from active totals and reconciliation.

---

### Task 1: Define Work Tables, Constraints, and Domain Mappers

**Files:**
- Create: `lib/features/work/data/work_tables.dart`
- Create: `lib/features/work/data/work_converters.dart`
- Create: `lib/features/work/data/work_database.dart`
- Modify: `lib/core/database/app_database.dart`
- Create: `test/features/work/data/work_schema_test.dart`
- Create: `test/features/work/data/work_converters_test.dart`
- Create: `drift_schemas/schema_v2.json`

**Interfaces:**
- Consumes: Phase 01 `AppDatabase`; all Phase 02 fact/value types.
- Produces: Drift rows/tables and total row↔domain converters; schema version 2.

- [ ] **Step 1: Write failing schema tests**

```dart
test('work schema stores integer facts and enforces foreign keys', () async {
  final columns = await tableInfo(db, 'work_shifts');
  expect(columns['overtime_minutes']!.type, 'INTEGER');
  expect(columns['local_start_date']!.type, 'TEXT');
  expect(columns.containsKey('expected_pay'), isFalse);
  await expectLater(insertShiftWithMissingEmployment(db), throwsA(isA<SqliteException>()));
});
```

Pin tables: `employments`, `pay_agreements`, `work_shifts`, `shift_breaks`, `pay_periods`, and `payslips`, including timestamps, revision, state, and reciprocal correction links described by the spec.

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/features/work/data/work_schema_test.dart`
Expected: FAIL because Work tables do not exist.

- [ ] **Step 3: Implement tables and database constraints**

Use text UUIDs/ISO local dates/IANA zones, integer UTC microseconds, and integer money/rate fields. Add FK actions that restrict historical parent deletion. Add checks for positive rates/thresholds/multiplier parts, nonnegative overtime, valid date ranges, positive payslip amount, and nonnegative revisions.

Enforce global one-active-shift with a unique partial index:

```sql
CREATE UNIQUE INDEX one_active_shift
ON work_shifts ((1))
WHERE state IN ('running', 'onBreak');
```

Use reciprocal correction FKs without cascade. Keep range-overlap and break-overlap checks in transactions because SQLite row checks cannot safely enforce them across rows.

- [ ] **Step 4: Write and implement total converter round trips**

```dart
test('finalized shift round trips every historical field', () {
  final fact = syntheticFinalizedShift();
  expect(shiftFromRow(shiftToCompanion(fact)), fact);
});
```

Converters reject unknown enum/state/basis/currency text with a safe data-corruption exception; they do not substitute defaults.

- [ ] **Step 5: Export and test schema migration**

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/schema_v2.json
flutter test test/features/work/data/work_schema_test.dart test/features/work/data/work_converters_test.dart test/core/database/migration_test.dart
```

Expected: version 1 migrates to version 2 and all constraints/converters pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work/data lib/core/database/app_database.dart drift_schemas/schema_v2.json test/features/work/data test/core/database/migration_test.dart
git commit -m "feat: add native Work persistence schema

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 2: Implement Employment and Agreement Repository Operations

**Files:**
- Create: `lib/features/work/data/daos/employment_dao.dart`
- Create: `lib/features/work/data/daos/agreement_dao.dart`
- Create: `lib/features/work/data/work_write_store.dart`
- Create: `lib/features/work/data/work_repository.dart`
- Create: `test/features/work/data/employment_agreement_repository_test.dart`

**Interfaces:**
- Produces: `DriftWorkRepository`, transactional `WorkWriteStore`, employment/agreement watchers and conditional writes.

```dart
abstract interface class WorkWriteStore {
  Future<int> insertEmployment(Employment value);
  Future<int> updateEmployment(Employment value, Revision expected);
  Future<List<PayAgreement>> agreementsFor(EmploymentId id);
  Future<int> insertAgreement(PayAgreement value);
  Future<int> updateUnusedAgreement(PayAgreement value, Revision expected);
}
```

- [ ] **Step 1: Write failing revision/range tests**

```dart
test('stale employment update affects zero rows and preserves newer data', () async {
  await repository.updateEmployment(newer, expected: const Revision(0));
  expect(await repository.updateEmployment(stale, expected: const Revision(0)), 0);
  expect((await repository.employmentById(id))!.name, newer.name);
});

test('concurrent agreement creation cannot commit an overlap', () async {
  final outcomes = await Future.wait([createAgreement(rangeA), createAgreement(overlappingRange)]);
  expect(outcomes.whereType<Committed<PayAgreement>>(), hasLength(1));
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/features/work/data/employment_agreement_repository_test.dart`
Expected: FAIL because repositories/DAOs do not exist.

- [ ] **Step 3: Implement repository queries and transactional range validation**

Read the complete employment agreement set inside the write transaction, apply Phase 02 policy, then insert/update. Determine used status by finalized/void shift references, not a mutable agreement flag column. Conditional updates increment revision atomically.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/features/work/data/employment_agreement_repository_test.dart`
Expected: PASS for stale writes, adjacent ranges, overlaps, archives, and used-agreement immutability.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work/data test/features/work/data/employment_agreement_repository_test.dart
git commit -m "feat: persist employments and agreements

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 3: Implement Atomic Shift and Break Persistence

**Files:**
- Create: `lib/features/work/data/daos/shift_dao.dart`
- Create: `lib/features/work/data/shift_repository.dart`
- Create: `test/features/work/data/shift_repository_test.dart`

**Interfaces:**
- Produces: active-shift stream; draft/finalized shift queries; atomic shift/break writes; finalization and correction primitives available only inside `WorkWriteStore` transactions.

- [ ] **Step 1: Write failing concurrency, rollback, and recovery tests**

```dart
test('two concurrent starts commit exactly one active shift', () async {
  final results = await Future.wait([repository.start(syntheticStartA), repository.start(syntheticStartB)]);
  expect(results.where((value) => value == 1), hasLength(1));
  expect(await repository.activeShift(), isNotNull);
});

test('failed finalization rolls back agreement and state writes', () async {
  await expectLater(repository.injectFailureAfterAgreementLink(), throwsA(anything));
  expect((await repository.shiftById(id))!.state, ShiftState.running);
  expect((await repository.shiftById(id))!.agreementId, isNull);
});

test('active shift and open break recover after reopening database', () async {
  await repository.start(start);
  await repository.startBreak(breakStart);
  await reopenDatabase();
  expect((await repository.activeShift())!.state, ShiftState.onBreak);
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/features/work/data/shift_repository_test.dart`
Expected: FAIL because shift DAO/repository does not exist.

- [ ] **Step 3: Implement factual operations**

Use the unique active-shift index as the final concurrency authority. Start/end break and shift state updates use expected revisions. Finalization reads shift, breaks, and agreements in one transaction, calls `validateFinalization()`, persists the resolved agreement ID and `finalized` state conditionally, and returns the factual row. Do not persist expected pay.

- [ ] **Step 4: Add atomic correction tests**

```dart
test('stale correction creates no replacement and leaves original active', () async {
  final result = await repository.correctShift(originalId, expected: staleRevision, replacement: replacement);
  expect(result, isA<Stale<WorkShift>>());
  expect(await repository.shiftById(replacement.id), isNull);
  expect((await repository.shiftById(originalId))!.state, ShiftState.finalized);
});
```

Persist the voided original, copied replacement draft, and copied replacement break facts atomically. Historical original breaks remain attached to the original.

- [ ] **Step 5: Verify GREEN**

Run: `flutter test test/features/work/data/shift_repository_test.dart`
Expected: PASS for concurrency, lifecycle, rollback, recovery, revision, and correction.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work/data test/features/work/data/shift_repository_test.dart
git commit -m "feat: persist atomic shift lifecycle

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 4: Implement Pay-Period, Payslip, and Register Projections

**Files:**
- Create: `lib/features/work/data/daos/pay_period_dao.dart`
- Create: `lib/features/work/data/daos/payslip_dao.dart`
- Create: `lib/features/work/data/projections/work_register_projection.dart`
- Create: `lib/features/work/data/projections/work_record_projection.dart`
- Create: `lib/features/work/data/projections/reconciliation_projection.dart`
- Create: `test/features/work/data/pay_period_repository_test.dart`
- Create: `test/features/work/data/work_projection_test.dart`

**Interfaces:**
- Produces: master-plan `WorkScope`, `WorkTemporalScope`, `PayPeriodScope`, `DateRangeScope`, `watchRegister(WorkScope)`, `watchRecord(WorkRecordId)`, period/payslip persistence, and pure-domain-backed reconciliation projections. Define these scope values in `work_register_projection.dart` exactly as the master plan; presentation imports them rather than redeclaring them.

- [ ] **Step 1: Write failing period/payslip persistence tests**

```dart
test('period overlap is rejected transactionally and adjacent periods are accepted', () async {
  expect(await createPeriod(september), isA<Committed<PayPeriod>>());
  expect(await createPeriod(overlapping), isA<Invalid<PayPeriod>>());
  expect(await createPeriod(october), isA<Committed<PayPeriod>>());
});

test('void payslip remains inspectable but leaves active paid total', () async {
  await correctPayslip(original, replacement);
  expect((await repository.payslipById(original.id))!.state, PayslipState.voided);
  expect((await repository.watchRegister(scope).first).paid.minorUnits, replacement.amount.minorUnits);
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/features/work/data/pay_period_repository_test.dart test/features/work/data/work_projection_test.dart`
Expected: FAIL because period/payslip DAOs and projections do not exist.

- [ ] **Step 3: Implement period/payslip transactions**

Validate non-overlap from a complete same-employment period snapshot in the transaction. Use conditional revisions. Payslip correction atomically voids and links original/replacement. `reviewed` is reversible and never freezes evidence.

- [ ] **Step 4: Implement bounded reactive projections**

Fetch only rows in selected employment/scope plus selected detail. Materialize factual rows, call Phase 02 `calculateExpectedPay()` and `reconcilePeriod()`, and expose facts/derived/evidence separately. Exclude void facts from active totals while retaining IDs for historical inspection. Never load notes for unselected register rows.

- [ ] **Step 5: Verify GREEN and query bounds**

```bash
flutter test test/features/work/data/pay_period_repository_test.dart test/features/work/data/work_projection_test.dart
flutter test test/features/work/data
```

Expected: PASS; query instrumentation confirms period-bounded reads and selected-only notes.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work/data test/features/work/data
git commit -m "feat: project Work periods and reconciliation

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 5: Build Employment and Agreement Application Services

**Files:**
- Create: `lib/features/work/application/work_commands.dart`
- Create: `lib/features/work/application/employment_service.dart`
- Create: `lib/features/work/application/agreement_service.dart`
- Create: `test/features/work/application/employment_service_test.dart`
- Create: `test/features/work/application/agreement_service_test.dart`

**Interfaces:**
- Produces: immutable create/archive employment and create/close agreement commands returning `Future<MutationOutcome<T>>`.

- [ ] **Step 1: Write failing application outcome tests**

```dart
test('invalid agreement returns field issues without opening a write', () async {
  final result = await service.createAgreement(invalidCommand);
  expect(result, isA<Invalid<PayAgreement>>());
  expect(fakeRepository.transactionCount, 0);
});

test('zero-row archive maps to stale', () async {
  fakeStore.nextUpdateCount = 0;
  expect(await service.archiveEmployment(command(expectedRevision: 2)), isA<Stale<Employment>>());
});
```

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/features/work/application/employment_service_test.dart test/features/work/application/agreement_service_test.dart`
Expected: FAIL because services do not exist.

- [ ] **Step 3: Implement services with injected IDs/clock**

Commands contain owner facts and expected revision only. Services trim/validate via domain constructors, obtain UUIDv7 from injected `IdFactory`, timestamps from `AppClock`, and map known constraint/revision outcomes to typed variants. Unexpected programming errors propagate in tests; expected database unavailability maps safely.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/features/work/application/employment_service_test.dart test/features/work/application/agreement_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work/application test/features/work/application
git commit -m "feat: add employment and agreement services

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 6: Build Complete Shift Lifecycle Services

**Files:**
- Modify: `lib/features/work/application/work_commands.dart`
- Create: `lib/features/work/application/shift_lifecycle_service.dart`
- Create: `lib/features/work/application/manual_shift_service.dart`
- Create: `test/features/work/application/shift_lifecycle_service_test.dart`
- Create: `test/features/work/application/manual_shift_service_test.dart`

**Interfaces:**
- Produces: `startShift`, `startBreak`, `endBreak`, `endShift`, `finalizeShift`, manual-draft finalization, and shift correction.

- [ ] **Step 1: Write failing lifecycle tests**

```dart
test('finalization resolves agreement by captured local start date and commits it', () async {
  final result = await service.finalizeShift(FinalizeShiftCommand(id: id, overtimeMinutes: 15, expectedRevision: const Revision(4)));
  expect(result, isA<Committed<WorkShift>>());
  expect((result as Committed<WorkShift>).value.agreementId, septemberAgreement.id);
});

test('commit-exit ambiguity returns uncertain and does not invite retry', () async {
  fakeRepository.failAtCommitBoundary = true;
  expect(await service.correctShift(correctionCommand), isA<Uncertain<WorkShift>>());
});
```

Also test no active employment/agreement, global active-shift conflict, break state errors, DST/overnight elapsed facts, overtime suggestion mismatch preservation, stale revisions, rollback, and restart recovery.

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/features/work/application/shift_lifecycle_service_test.dart test/features/work/application/manual_shift_service_test.dart`
Expected: FAIL because services are undefined.

- [ ] **Step 3: Implement transactional lifecycle orchestration**

Start captures one clock instant, timezone ID, and local date. End/break operations use authoritative persisted state and expected revision. Finalize calls Phase 02 validation; return field-safe issues for factual invalidity. Expected pay is calculated only for the returned/view projection. Correction delegates to the atomic repository operation and never retries uncertain outcomes.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/features/work/application/shift_lifecycle_service_test.dart test/features/work/application/manual_shift_service_test.dart`
Expected: PASS for all lifecycle and failure outcomes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work/application test/features/work/application
git commit -m "feat: add transactional shift services

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 7: Build Period, Payslip, Reconciliation, and Query Services

**Files:**
- Modify: `lib/features/work/application/work_commands.dart`
- Create: `lib/features/work/application/pay_period_service.dart`
- Create: `lib/features/work/application/payslip_service.dart`
- Create: `lib/features/work/application/reconciliation_service.dart`
- Create: `lib/features/work/application/work_query_service.dart`
- Create: `test/features/work/application/pay_period_payslip_service_test.dart`
- Create: `test/features/work/application/reconciliation_service_test.dart`

**Interfaces:**
- Produces: period/payslip mutations, correction services, `watchRegister`, `watchRecord`, and reconciliation queries consumed by presentation.

- [ ] **Step 1: Write failing service tests**

```dart
test('multiple compatible payslips sum while mixed basis remains separate', () async {
  await service.recordPayslip(firstGross);
  await service.recordPayslip(secondGross);
  await service.recordPayslip(netAdjustment);
  final summary = await reconciliation.watch(periodScope).first;
  expect(summary.groups.where((g) => g.basis == const GrossBasis()).single.paid!.minorUnits, 250000);
  expect(summary.overallStatus, isA<MixedBasis>());
});
```

Pin invalid overlap, stale period edit, reviewed/reopen, payslip correction rollback, unmatched evidence, missing agreement, and unavailable database.

- [ ] **Step 2: Confirm RED**

Run: `flutter test test/features/work/application/pay_period_payslip_service_test.dart test/features/work/application/reconciliation_service_test.dart`
Expected: FAIL because services do not exist.

- [ ] **Step 3: Implement thin services over domain/repository contracts**

Do not duplicate calculations or SQL in services. Queries expose immutable presentation-ready factual and derived projections, but no Flutter types. Mutation errors expose safe field codes and typed outcomes only.

- [ ] **Step 4: Run the complete Work backend gate**

```bash
dart format --set-exit-if-changed lib/features/work test/features/work
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/features/work test/features/work
flutter test test/features/work/domain test/features/work/data test/features/work/application
dart run tool/schema_check.dart
dart run tool/privacy_scan.dart
```

Expected: PASS; generated/schema output is clean and derived totals are absent from tables.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work/application test/features/work/application
git commit -m "feat: complete Work application services

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Data and Application Completion Gate

- [ ] Inspect generated schema: no expected-pay or reconciliation-total columns.
- [ ] Inject a commit-boundary failure into each non-idempotent correction/payslip path and confirm `Uncertain`.
- [ ] Reopen the disposable database after running/on-break fixtures and confirm exact lifecycle recovery.
- [ ] Run all phase gate commands from a clean generated state.
