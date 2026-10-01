# Work Employments and Premium Pay, Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a fresh install explain Work and set up an employment in one press. Let an agreement take only an hourly rate, with legal defaults for everything else. Allow editing and deleting setup that has no history. Derive expected pay with night, public-holiday and overtime premiums, shown with a breakdown.

**Architecture:** The domain stays free of Flutter. Holidays, segmentation and per-segment multipliers are pure functions; time-zone conversion is passed in, so tests use fixed offsets and production uses `TimezoneService`. Expected pay remains a derivation: segments are computed on read, never stored. Manual overtime is removed everywhere; overtime is the paid time after the agreement's per-shift threshold. The schema history is reset because nothing is released.

**Tech Stack:** Flutter `3.47.5`, Dart `3.13.4`, Drift `2.35.0`, `sqlite3` `3.6.0`, Riverpod `3.4.3`, GoRouter `18.0.2`, `timezone` `0.11.1`.

**Spec:** `docs/superpowers/specs/2026-10-01-work-employments-premiums-design.md`. Shell context: `docs/superpowers/specs/2026-10-01-lifeos-office-machine-shell-design.md`.

## Owner decisions recorded for this plan

- **Data (2026-10-01):** the owner confirmed the local database holds test data only, so the schema history is reset as the spec says. No migration from schema 2 is written.
- **Startup message:** a database from an earlier development build gets an explicit startup message naming the file to remove. This replaces the generic "Database unavailable" message (spec section 6, last bullet).

## Global Constraints

- Keep every master-plan constraint: exact pins, integer money, `BigInt` rational arithmetic, typed `MutationOutcome<T>`, optimistic revisions, structural routes, and synthetic data in tests.
- The domain never imports Flutter. Segmentation takes conversion functions, not a `TimezoneService`.
- Every multiplier stays an exact `RationalMultiplier`. The amount is rounded half-up once, at the end, to whole micro-euros, then to the currency's minor unit.
- No stored totals or segments. `ExpectedPay` is computed when read.
- Remove manual overtime completely: the domain field, column, commands, services, forms, the inspector's overtime confirmation and tests. Nothing may still accept an overtime-minutes value.
- The services enforce every rule (history blocks delete, an in-use agreement blocks edit), and the screen also hides actions the services would reject.
- Error copy follows spec section 9 word for word.
- Presentation changes land in the current Work widgets, inside the Office Machine shell. Shell Task 6 later restyles them, so keep these changes behavioural rather than visual.
- End every implementation commit with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.

## Review Focus

1. **Daylight saving:** a night window across the Europe/Vilnius changes (gap and overlap) counts each paid second exactly once. Tested in Task 3.
2. **Stacking:** a night hour on a holiday that is also overtime gives ×2, ×2.5 and ×3 for highest, additive and multiplicative. Tested in Task 3.
3. **Overtime start:** the instant at which cumulative paid seconds reach the threshold, skipping breaks. Tested in Task 3.
4. **Delete with history:** blocked by any shift, pay period or payslip, and the cascade removes only unused agreements, in one transaction. Tested in Task 5.
5. **No leftover manual overtime:** a repository-wide scan finds no `overtimeMinutes` field, column or form. Tested in Task 4.

---

## File responsibilities

- `lib/features/work/domain/lithuanian_holidays.dart`: `HolidayCalendar`, `isLithuanianPublicHoliday`, `westernEaster`.
- `lib/features/work/domain/pay_premiums.dart`: `PaySegment`, `segmentPaidTime`, `segmentMultiplier`.
- `lib/features/work/domain/agreement.dart`: premium fields, defaults and validation; `PremiumStacking`.
- `lib/features/work/domain/pay.dart`: `ExpectedPay` breakdown and amount from segments.
- `lib/features/work/domain/shift.dart`: `FinalizationFacts` without overtime minutes; produces the pay input.
- `lib/features/work/domain/reconciliation.dart`: reads the new breakdown.
- `lib/features/work/data/work_tables.dart`, `work_converters.dart`, DAOs: new agreement columns; `overtime_minutes` removed.
- `lib/core/database/schema_versions.dart`, `migration_strategy.dart`, `drift_schemas/`, `tool/schema_check.dart`: the reset schema history.
- `lib/features/work/application/`: update and delete employment, update agreement, premium fields on create, finalization without overtime.
- `lib/features/work/presentation/`: first-launch copy, employment and agreement forms, employment switcher, employment header, shift forms without overtime, finalized-shift breakdown, error copy, and explanations with the premium breakdown.
- `lib/app/startup_recovery.dart`: the earlier-build database message.

### Task 1: Lithuanian public holidays

**Files:**
- Create: `lib/features/work/domain/lithuanian_holidays.dart`
- Create: `test/features/work/domain/lithuanian_holidays_test.dart`

**Interfaces:**

```dart
enum HolidayCalendar { none, lithuania }

/// Western (Gregorian) Easter Sunday, by the anonymous Gregorian algorithm.
LocalDate westernEaster(int year);

bool isLithuanianPublicHoliday(LocalDate date);

bool isPublicHoliday(HolidayCalendar calendar, LocalDate date);
```

- [x] **Step 1: Write failing tests.**
  - All 16 dates in spec section 3 for 2026 are holidays, including Easter Sunday and Monday, and the first Sundays of May and June.
  - Easter for 2024–2030 matches the published dates: 31 Mar 2024, 20 Apr 2025, 5 Apr 2026, 28 Mar 2027, 16 Apr 2028, 1 Apr 2029, 21 Apr 2030.
  - Non-holidays such as 3 November and 2 January are not holidays.
  - `HolidayCalendar.none` has no holidays.
- [x] **Step 2: Run, implement, run.** Expected: FAIL, then PASS.
- [x] **Step 3: Commit** `feat: add the Lithuanian public holiday calendar`.

### Task 2: Agreement premium fields

**Files:**
- Modify: `lib/features/work/domain/agreement.dart`
- Modify: `test/features/work/domain/agreement_test.dart`

**Interfaces:**

```dart
enum PremiumStacking { highest, additive, multiplicative }

// PayAgreement gains, with these defaults for new agreements (spec section 4):
//   bool nightEnabled = true
//   int nightStartMinute = 1320   // 22:00
//   int nightEndMinute = 360      // 06:00
//   RationalMultiplier nightMultiplier = 3/2
//   HolidayCalendar holidayCalendar = lithuania
//   RationalMultiplier holidayMultiplier = 2/1
//   PremiumStacking premiumStacking = highest
abstract final class AgreementDefaults { /* the values above, plus overtime 480 min and 3/2 */ }
```

- [ ] **Step 1: Write failing tests.**
  - Night minutes must be 0–1439 and the start and end must differ.
  - Every multiplier, including overtime, must be at least 1.
  - The threshold stays above 0.
  - Window fields are kept when night pay is off.
- [ ] **Step 2: Run, implement, run.** Expected: FAIL, then PASS. Update every `PayAgreement` construction in `lib` and `test` to pass the new fields. Tests use a shared synthetic builder.
- [ ] **Step 3: Commit** `feat: add night, holiday and stacking fields to agreements`.

### Task 3: Segmentation and expected pay

**Files:**
- Create: `lib/features/work/domain/pay_premiums.dart`
- Modify: `lib/features/work/domain/pay.dart`
- Create: `test/features/work/domain/pay_premiums_test.dart`
- Modify: `test/features/work/domain/pay_test.dart`

**Interfaces:**

```dart
/// Local wall-clock view of an instant in the shift's zone.
typedef ToLocal = ({LocalDate date, int minuteOfDay}) Function(DateTime utc);

/// The first valid instant at or after a local wall-clock time in the shift's
/// zone (a time inside a daylight-saving gap resolves forward).
typedef ToInstant = DateTime Function(LocalDate date, int minuteOfDay);

final class PaySegment {
  const PaySegment({required this.startUtc, required this.seconds,
    required this.night, required this.holiday, required this.overtime});
}

List<PaySegment> segmentPaidTime({
  required List<({DateTime start, DateTime end})> paidIntervals, // shift minus breaks, UTC, ordered
  required PayAgreement agreement,
  required ToLocal toLocal,
  required ToInstant toInstant,
});

RationalMultiplier segmentMultiplier(PaySegment segment, PayAgreement agreement);

final class ExpectedPay {
  const ExpectedPay({required this.totalPaidSeconds, required this.nightPaidSeconds,
    required this.holidayPaidSeconds, required this.overtimePaidSeconds,
    required this.regularPaidSeconds, required this.amount});
  // regularPaidSeconds = paid seconds with no premium flag; categories overlap.
}

ExpectedPay calculateExpectedPay({
  required List<PaySegment> segments,
  required int hourlyRateMicroEur,
  required PayAgreement agreement,
  required CurrencyCode currency,
});
```

- [ ] **Step 1: Write failing segmentation tests**, using fixed-offset `ToLocal`/`ToInstant` for the plain cases and the real Europe/Vilnius zone for the daylight-saving cases:
  - an 8-hour day shift with no premiums
  - a 12-hour night shift from 18:00 to 06:00 with an 8-hour threshold, where the last 4 hours are overtime and partly night
  - a shift crossing midnight into 24 December (holiday from 00:00)
  - a night shift across the Europe/Vilnius spring-forward and fall-back changes; every paid second is counted once
  - breaks removed from night time
  - night pay disabled, and holiday calendar `none`
- [ ] **Step 2: Write failing multiplier and amount tests.**
  - Each stacking mode with night, holiday and overtime overlapping gives ×2, ×2.5 and ×3 (night 1.5, holiday 2, overtime 1.5).
  - Rounding is half-up once, at the end only. An amount that rounds differently per segment must round correctly in total.
- [ ] **Step 3: Run, implement, run.** Expected: FAIL, then PASS. Boundaries are local midnights, night window start and end, and the overtime start instant. Each flag is read at the segment's start instant (start inclusive, end exclusive).
- [ ] **Step 4: Commit** `feat: derive expected pay with night, holiday and overtime premiums`.

### Task 4: Remove manual overtime and reset the schema

Removing the overtime field touches the domain, the schema, the services and the forms at once. This task does all of it in one commit, so every commit compiles and passes.

**Files:**
- Modify: `lib/features/work/domain/shift.dart`, `reconciliation.dart`, `correction.dart` (if it copies overtime)
- Modify: `lib/features/work/data/work_tables.dart`, `work_converters.dart`, `daos/agreement_dao.dart`, `daos/shift_dao.dart`, `shift_repository.dart`, `work_repository.dart`, projections
- Modify: `lib/features/work/application/work_commands.dart`, `shift_lifecycle_service.dart`, `manual_shift_service.dart`, `agreement_service.dart` (premium fields on create)
- Modify: `lib/features/work/presentation/shift_forms.dart`, `work_inspector.dart`, `work_screen.dart`, `work_controller.dart`, `lib/app/app_router.dart`
- Modify: `lib/core/database/schema_versions.dart`, `migration_strategy.dart`, `database_service.dart`, `app_database.g.dart` (regenerated); `lib/core/outcomes/mutation_outcome.dart` (failure code); `lib/app/startup_recovery.dart`
- Replace: `drift_schemas/schema_v1.json`; delete `drift_schemas/schema_v2.json`
- Modify: `tool/schema_check.dart` and the affected tests
- Create: `test/repository/no_manual_overtime_test.dart`

- [ ] **Step 1: Write failing tests.**
  - **Scan:** no file under `lib/` mentions `overtimeMinutes`, `overtime_minutes`, `suggestedOvertimeMinutes` or `OvertimeConfirmation`.
  - **Finalization:** derived overtime gives the expected pay from Task 3. A finished shift finalizes directly, with no overtime value.
  - **Converters:** round-trip every new agreement field and the enums by their stable names.
  - **CHECK constraints:** reject a night minute outside 0–1439, a start equal to the end, a multiplier below 1 and an unknown enum.
  - **Fresh database:** created at schema version 1 with no `overtime_minutes` column. The fingerprint test lists only version 1.
  - **Earlier-build database:** a database with `user_version` 2 fails with `SafeFailureCode.databaseFromEarlierBuild`. The recovery screen shows "This database was made by an earlier development build of LifeOS and can't be opened. Close LifeOS, remove <path>, then start it again." The path is the database's own location; no record content is shown.
- [ ] **Step 2: Implement.**
  - Remove `WorkShift.overtimeMinutes`, its validation, `suggestedOvertimeMinutes` and the overtime confirmation inspector.
  - `FinalizationFacts` exposes the paid intervals plus `expectedPay(ToLocal, ToInstant)`, and reconciliation reads the new breakdown.
  - Add the agreement columns and CHECKs from spec section 6, and drop `overtime_minutes`.
  - Set `currentSchemaVersion = 1`. `onCreate` builds everything, and `onUpgrade` only accepts the current version.
  - Regenerate Drift output and the snapshot: `dart run build_runner build --delete-conflicting-outputs`, then `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/schema_v1.json`. Update the fingerprints with `sha256sum`.
- [ ] **Step 3: Run** `flutter analyze`, `flutter test` and `dart run tool/schema_check.dart`. Expected: PASS.
- [ ] **Step 4: Commit** `feat!: derive overtime and reset the unreleased schema`.

### Task 5: Application services

**Files:**
- Modify: `lib/features/work/application/work_commands.dart`, `employment_service.dart`, `agreement_service.dart`, `shift_lifecycle_service.dart`, `manual_shift_service.dart`, `work_query_service.dart`
- Modify: `lib/features/work/data/projections/work_register_projection.dart`, `work_repository.dart`
- Modify: application tests

**Interfaces:**

```dart
final class UpdateEmploymentCommand { /* employmentId, expectedRevision, name, legalLabel */ }
final class DeleteEmploymentCommand { /* employmentId, expectedRevision */ }
final class UpdateAgreementCommand  { /* agreementId, expectedRevision, every editable field */ }
// CreateAgreementCommand gains the premium fields.
// WorkRegisterProjection gains: canDeleteEmployment, currentAgreement, agreementInUse.
```

- [ ] **Step 1: Write failing tests.**
  - Updating an employment works.
  - Delete is blocked by a shift, a pay period or a payslip (`Invalid` with `employment.hasHistory`), and otherwise deletes the employment and its unused agreements in one transaction.
  - Updating an agreement is blocked when it is in use (`agreement.inUse`) and revalidates overlaps.
  - Stale revisions return `Stale`, and missing records return `Missing`.
  - The projection reports `canDeleteEmployment`, `currentAgreement` and `agreementInUse`.
- [ ] **Step 2: Run, implement, run.** Expected: FAIL, then PASS.
- [ ] **Step 3: Commit** `feat: edit and delete Work setup that has no history`.

### Task 6: Presentation

**Files:**
- Modify: `lib/features/work/presentation/work_register.dart`, `employment_agreement_forms.dart`, `shift_forms.dart`, `work_inspector.dart`, `work_screen.dart`, `work_controller.dart`, `work_explanations.dart`, `lib/app/app_router.dart`
- Modify: presentation tests

- [ ] **Step 1: Write failing widget tests**, each matching spec section 8:
  - **First launch:** the first-launch copy, and a one-press **Create employment** that opens the form in the inspector.
  - **Employment form:** hints, and the same form edits an employment.
  - **Agreement form:**
    - Defaults are filled in, so typing a rate alone is enough.
    - 1.5 is stored as 3/2, and decimal hours are stored as minutes.
    - Multipliers below 1 or unparseable show "Enter a multiplier of 1 or more, e.g. 1.5", and an equal night start and end shows "Night pay start and end must differ".
    - An in-use agreement shows read-only with "Used by N finished shifts. New versions arrive in a later update."
  - **Employment switcher:** replaces the inert Employment control, with a check mark on the current employment, then **All employments** and **Create employment**.
  - **Employment header:** **Edit**, **Edit agreement** only when the agreement is unused, and **Delete** only when `canDeleteEmployment`, with the inline confirmation copy. With history it reads "Has work history — archiving arrives in a later update."
  - **Finalized shift:** shows the expected amount and the regular, night, holiday and overtime hours, with the estimate note.
  - **Errors:** stale and in-use messages from section 9.
- [ ] **Step 2: Extend the formula-bar explanations** for expected pay to list each premium group, for example `regular 6:00 × 18.40/h + night 2:00 × 18.40/h × 1.5 = …`, built from the same `ExpectedPay`, with the stacking mode named in the source label.
- [ ] **Step 3: Run, implement, run.** Expected: FAIL, then PASS.
- [ ] **Step 4: Commit** `feat: set up employments and agreements with premium defaults`.

### Task 7: Integration and verification

**Files:**
- Modify: `test/integration/work_core_flow_test.dart`

- [ ] **Step 1: Add the spec's integration flow.** Fresh install → employment → agreement with defaults (rate only) → record a night shift → finalize → the expected pay includes the night premium, and the breakdown shows the night hours.
- [ ] **Step 2: Run** `dart format --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test` and `./app.sh` options 2 and 3. Expected: PASS.
- [ ] **Step 3: Commit** `test: cover first launch to night premium end to end`.

## Plan self-review

**Spec coverage:**
- Section 3 → Task 1.
- Section 4 → Task 2.
- Section 5 → Task 3.
- Removing manual overtime and section 6 → Task 4.
- Section 7 → Task 5.
- Sections 8–9 → Task 6.
- Section 10 → Tasks 1–7.

Each Review Focus item names its task.

**Ordering:** every task ends green. Tasks 1–3 add pure domain code beside the old code. Task 4 switches the whole app to derived overtime and the reset schema in one step.

**Shell plan link:** this plan resets the schema to version 1. Shell Task 5 adds `record_events` by re-baselining version 1 the same way while the schema is unreleased, and shell Task 6 builds on Task 6 here.

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-10-01-work-employments-premiums-phase-a.md`.
