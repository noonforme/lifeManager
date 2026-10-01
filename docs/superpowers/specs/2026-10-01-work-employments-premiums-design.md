# Work Employments, First Launch, and Premium Pay Design

**Status:** Approved design sections, pending written-spec review
**Date:** 2026-10-01
**Builds on:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md`
**Phase:** A of A–D (B: agreement versions and archive; C: schedules; D: full reset with backup)

## 1. Purpose

A newly installed LifeOS must let the owner understand Work, set up an employment with sensible pay defaults, correct a mistaken setup, and move between employments. The expected-pay derivation must also reflect the owner's real pay rules: Lithuanian night work and public-holiday work premiums.

Phase A succeeds when the owner can:

1. Open a fresh install, read what Work does, and create an employment in one press.
2. Create an agreement by typing only an hourly rate, because every other field is pre-filled with legal defaults.
3. Rename an employment, edit an agreement no finalized shift uses, and delete an employment that has no history.
4. Switch between employments and return to the employment list from the register toolbar.
5. See expected pay for a finalized shift that accounts for night hours, public-holiday hours, and overtime, with a breakdown of each.

Expected pay remains a derivation. Payslips remain the evidence of what was paid.

## 2. Decisions

| Topic | Decision |
|---|---|
| Premium model | Fixed fields on the agreement (night, holiday, stacking), not a rule list |
| Night premium | Applies to paid time inside a local-time window; default 22:00–06:00, ×1.5 |
| Holiday premium | Applies to paid time on a public holiday's local date; default Lithuania, ×2 |
| Overtime | Derived: paid time after the agreement's per-shift threshold, i.e. the last hours of the shift |
| Manual overtime entry | Removed; derived overtime is the single source of truth |
| Stacking | Configurable per agreement: highest wins (default), additive, multiplicative |
| Database | Schema history reset; no migration from schema 2 |
| Out of scope | Agreement versions, archive/unarchive, schedules, full reset, salaried pay |

The defaults match the minimums in the Lithuanian Labour Code (Article 144: night work and holiday work pay). The app labels them as defaults, not legal advice.

## 3. Lithuanian Public Holidays

Source: Labour Code of the Republic of Lithuania, Article 123 (as amended in 2019, in force from 2020-01-01).

| Date | Holiday |
|---|---|
| 1 January | New Year's Day |
| 16 February | Restoration of the State |
| 11 March | Restoration of Independence |
| Easter Sunday (Western) | Easter |
| Easter Monday | Easter (second day) |
| 1 May | International Workers' Day |
| First Sunday of May | Mother's Day |
| First Sunday of June | Father's Day |
| 24 June | Rasos and Joninės |
| 6 July | Statehood Day |
| 15 August | Assumption (Žolinė) |
| 1 November | All Saints' Day |
| 2 November | All Souls' Day |
| 24 December | Christmas Eve |
| 25 December | Christmas Day |
| 26 December | Christmas (second day) |

The calendar lives in code as `bool isLithuanianPublicHoliday(LocalDate date)`. It computes Western Easter with the anonymous Gregorian algorithm and needs no network. A holiday covers the whole local date from 00:00 to 24:00 in the shift's timezone.

`HolidayCalendar` is an enum with values `none` and `lithuania`. Adding a country later means adding a value and a function.

## 4. Agreement Data

`PayAgreement` keeps its existing fields (identity, employment, version, effective range, hourly rate, rate basis, overtime threshold minutes, overtime multiplier, label, note, revision) and gains:

| Field | Type | Default for new agreements | Validation |
|---|---|---|---|
| `nightEnabled` | bool | true | — |
| `nightStartMinute` | int, minutes after local midnight | 1320 (22:00) | 0–1439 |
| `nightEndMinute` | int, minutes after local midnight | 360 (06:00) | 0–1439, not equal to start |
| `nightMultiplier` | `RationalMultiplier` | 3/2 | ≥ 1 |
| `holidayCalendar` | `HolidayCalendar` | `lithuania` | — |
| `holidayMultiplier` | `RationalMultiplier` | 2/1 | ≥ 1 |
| `premiumStacking` | `PremiumStacking` | `highest` | — |

When the start minute is greater than the end minute, the window crosses midnight. Night window fields are stored even when `nightEnabled` is false, so switching it back on restores them.

The overtime multiplier also gains the "≥ 1" rule. The overtime threshold keeps its existing "> 0" rule.

`WorkShift` loses `overtimeMinutes`. `suggestedOvertimeMinutes` and every UI and command field for manual overtime are removed.

## 5. Expected Pay Calculation

### 5.1 Segmentation

Given a finalized shift, its breaks, and the resolved agreement:

1. Build the paid intervals: the shift's start to end, minus each break, in UTC.
2. Collect boundary instants inside each interval:
   - every local midnight (a holiday can start or end there)
   - every night window start and end, when night pay is enabled
   - the overtime start instant, which is the instant when cumulative paid seconds reach `overtimeThresholdMinutes × 60`
3. Convert local times to instants with the shift's `timezoneId` through the existing timezone service. On a daylight-saving gap, a local boundary that does not exist resolves to the first valid instant after it. On an overlap, each boundary instant is used once.
4. Split the paid intervals at the boundaries into segments. Each segment carries its seconds and three flags: `night`, `holiday` and `overtime`.

Each flag is set by checking the segment's start instant in local time:
- `night`: the local time is inside the window (start inclusive, end exclusive) and night pay is enabled.
- `holiday`: the local date is a holiday in the agreement's calendar.
- `overtime`: the segment starts at or after the overtime start instant.

### 5.2 Multiplier per segment

Let the active premiums be the multipliers of the flags that are set (night, holiday, overtime).

| Stacking | Segment multiplier |
|---|---|
| none active | 1 |
| `highest` | the largest active multiplier |
| `additive` | 1 + Σ(each active multiplier − 1) |
| `multiplicative` | Π(each active multiplier) |

Example for a night hour on a holiday with night ×1.5 and holiday ×2:
- `highest` gives ×2
- `additive` gives ×2.5
- `multiplicative` gives ×3

All multipliers stay exact rationals.

### 5.3 Amount and breakdown

`amount = Σ(segment seconds × hourlyRateMicroEur × segment multiplier) / 3600`

The sum is computed with BigInt rationals and rounded half-up once, at the end, to whole micro-euros, then to the currency's minor unit, as today.

`ExpectedPay` returns the amount plus a breakdown in paid seconds. The categories overlap, so they do not have to add up to the total:
- `totalPaidSeconds`
- `nightPaidSeconds`
- `holidayPaidSeconds`
- `overtimePaidSeconds`
- `regularPaidSeconds`, meaning paid seconds with no premium flag

Reconciliation keeps its current shape and reads `regularPaidSeconds` and `overtimePaidSeconds` from the new result.

### 5.4 Units

| File | Responsibility |
|---|---|
| `domain/lithuanian_holidays.dart` | Holiday calendar and Easter calculation |
| `domain/pay_premiums.dart` | Segmentation and per-segment multiplier, given a time-zone lookup |
| `domain/pay.dart` | Rounding, amount and breakdown, built on the segments |
| `domain/shift.dart` | `FinalizationFacts` produces the pay input from the shift, breaks, agreement and timezone; no overtime minutes |
| `domain/reconciliation.dart` | Uses the new pay result |

The domain stays free of Flutter. The time-zone conversion is passed in as a function so pure tests can use fixed offsets, while production uses the existing timezone service.

## 6. Database

- `PayAgreements` gains these columns:
  - `night_enabled`, `night_start_minute`, `night_end_minute`
  - `night_multiplier_numerator`, `night_multiplier_denominator`
  - `holiday_calendar`
  - `holiday_multiplier_numerator`, `holiday_multiplier_denominator`
  - `premium_stacking`
- Each new column has a CHECK constraint matching the validation in section 4.
- `WorkShifts` drops `overtime_minutes`.
- The schema history is reset because nothing is released:
  - `onCreate` builds the new schema.
  - `onUpgrade` is simplified to the single current version.
  - `releasedMigrationFingerprints` is regenerated.
  - A developer database from schema 2 is not migrated; the app's existing database-failure path tells the owner to remove it.
- Converters map the new columns and enums by their stable string names.

## 7. Application Services

New commands, each returning `MutationOutcome` and using optimistic revisions:

| Command | Rule |
|---|---|
| `UpdateEmploymentCommand(employmentId, expectedRevision, name, legalLabel)` | Always allowed for active employments |
| `DeleteEmploymentCommand(employmentId, expectedRevision)` | Allowed only when the employment has no shifts, pay periods or payslips. Deletes its agreements and the employment in one transaction. Otherwise returns `Invalid` with issue `employment.hasHistory` |
| `UpdateAgreementCommand(agreementId, expectedRevision, …all editable fields)` | Allowed only when no finalized shift references the agreement, otherwise returns `Invalid` with issue `agreement.inUse`. Revalidates overlaps with the employment's other agreements |

`CreateAgreementCommand` gains the premium fields. A stale revision returns `Stale`, and a missing record returns `Missing`, as existing services do.

`WorkRegisterProjection` gains:
- `canDeleteEmployment`
- the current agreement
- `agreementInUse`

The screen hides actions the services would reject, and the services still enforce the rules.

## 8. Presentation

### 8.1 First launch

The register's empty state with no employments shows:
- Title: "Work"
- Body: "Track shifts, see what you should be paid, and compare it with your payslips. Start by adding where you work."
- A **Create employment** button that opens the employment form in the inspector directly.

### 8.2 Employment form

- **Name**, with the hint "What you call this job, e.g. Warehouse".
- **Legal name** (optional), with the hint "Employer name as it appears on payslips".
- The same form edits an existing employment.

### 8.3 Agreement form

| Field | Behaviour |
|---|---|
| Starts on | Defaults to today |
| Hourly rate (€), Gross/Net | Required |
| Overtime | "after [8] hours per shift, ×[1.5]" |
| Night pay | Toggle; "[22:00] to [06:00], ×[1.5]" |
| Public holidays | Toggle (Lithuania); "×[2]" |
| When several apply | Highest wins / Add the extras / Multiply, each with a one-line example |
| Label, note | Optional, in a collapsed "More" section |

- Multipliers are typed as decimals (up to three decimal places) and stored as exact fractions; for example 1.5 is stored as 3/2.
- Hours accept decimals and are stored as minutes.
- The same form edits an unused agreement. For an agreement in use, the inspector shows the values read-only with "Used by N finished shifts. New versions arrive in a later update."

### 8.4 Employment switcher

The register toolbar's Employment control opens a menu:
- each active employment, with a check mark on the current one
- a divider
- **All employments**, which clears the employment from the route
- **Create employment**

### 8.5 Employment header, edit and delete

When an employment is selected and no record is open, the inspector shows an employment header with:
- the name and legal name
- **Edit**, which opens the employment form
- **Edit agreement**, only when the agreement is unused
- **Delete**, only when `canDeleteEmployment`

Delete swaps the header for an inline confirmation: "Delete Warehouse? Its unused agreement is removed too. This can't be undone." with **Cancel** and **Delete**. After a committed delete, the route clears the employment and the register shows the list, or the first-launch state if no employments remain. When deletion is not possible, the header shows "Has work history — archiving arrives in a later update."

### 8.6 Shift pay breakdown

A finalized shift's inspector shows the expected amount and the breakdown (regular, night, holiday and overtime hours), with the note that expected pay is an estimate until a payslip confirms it.

Shift forms drop the overtime minutes field.

## 9. Error Handling

| Situation | Message |
|---|---|
| `Stale` | "This changed since you opened it. Reload to see the latest." |
| `employment.hasHistory` | "This employment has work history and can't be deleted." |
| `agreement.inUse` | "This agreement is used by finished shifts and can't be edited." |
| Multiplier below 1 or unparseable | "Enter a multiplier of 1 or more, e.g. 1.5" |
| Night start equals end | "Night pay start and end must differ" |
| Overlapping agreement range | Existing overlap message |

## 10. Testing

**Domain:**
- Holidays: all 16 dates in 2026; Easter for 2024–2030 against published dates; non-holidays such as 3 November.
- Pay:
  - an 8h day shift with no premiums
  - a 12h night shift from 18:00 to 06:00 with an 8h threshold, where the overtime is the last 4h and some of it is also night
  - a shift crossing midnight into 24 December
  - a night shift across the Europe/Vilnius daylight-saving change (both directions)
  - breaks removed from night time
  - each stacking mode with night+holiday+overtime overlap
  - night pay disabled
  - holiday calendar `none`
  - half-up rounding at the end only

**Data:**
- converters round-trip every new field
- CHECK constraints reject invalid rows
- a fresh database creates the new schema
- the fingerprint test is updated

**Application:**
- update employment
- delete blocked by a shift, a period or a payslip
- delete cascades to unused agreements
- update agreement blocked when in use
- overlap revalidation
- stale revisions

**Presentation:**
- first-launch copy and one-press create
- agreement form defaults, and a decimal multiplier stored as 3/2
- the switcher lists employments and returns to the list
- edit employment
- delete with inline confirmation and return to the list
- the delete action is hidden with history
- the breakdown is shown on a finalized shift

**Integration:** fresh install → employment → agreement with defaults (rate only) → record a night shift → finalize → expected pay includes the night premium.

**Final:** analyze, format and the full test suite pass, and `./app.sh` starts and tests the app.
