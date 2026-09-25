# LifeOS Habits Slice Design

**Date:** 2026-09-25  
**Status:** Approved design awaiting implementation plan

## 1. Purpose and authority

This design defines the third persisted LifeOS domain slice: Habits. It adds a flexible personal consistency tracker for exercise, step goals, household tasks, abstinence, and other recurring behavior while preserving truthful records and calm, non-punitive presentation.

The maintained foundation package under `docs/foundation/` remains authoritative. If this design conflicts with that hierarchy, the higher-authority foundation document wins. This design resolves the practical Habits details intentionally left open by the foundation documents and incorporates the approved decisions for this slice.

The Habits slice must preserve these constraints:

- SQLite remains the single source of truth.
- Personal data remains outside the repository.
- Tests use explicitly owned disposable databases and never resolve, create, inspect, migrate, or reuse the personal database location.
- The interface is server-rendered Django over ordinary HTTP.
- Core workflows work without JavaScript.
- User content is escaped and treated as plain text.
- Logs and responses do not disclose names, descriptions, schedules, dates, quantities, units, notes, reasons, database paths, SQL, exception text, or other personal content.
- No historical application source code or personal data is accessed, copied, imported, or treated as authority. `/home/aUser/improvedCalendar` remains historical evidence only and is not consulted during implementation.
- No visual browser tests, screenshots, image snapshots, golden files, pixel comparison, capture rounds, or visual-regression services are introduced.
- Work and Money remain independent domains. Habits never imports their models or persistence internals.

## 2. User outcome and scope

After this slice, the owner can:

1. Create a check, quantity, abstinence, or scheduled-chore habit.
2. Give it a structured recurrence rule, active date range, optional exceptions, and an optional in-app reminder.
3. Review habits due on a selected local date.
4. Record, review, edit, or remove the type-appropriate result for one habit and date.
5. Mark an otherwise due occurrence as excused without claiming completion or breaking the streak.
6. Review current and longest streaks, momentum, recent outcomes, and upcoming due dates.
7. Archive a habit without destroying its history and restore it after explicit review.
8. See a truthful current-day Habits summary in the Daily Register without affecting Work or Money.

This workflow is a private factual record, not a medical system, addiction-treatment system, diagnostic tool, competitive score, productivity punishment mechanism, or health recommendation engine.

A combined Work/Habits calendar is explicitly deferred to a separate later slice. This slice exposes a small immutable Habits event-projection boundary for that future work but does not build calendar routes, month grids, agenda pages, or Work integration.

## 3. Habit domain

### 3.1 Habit record

A `Habit` owns:

- a stable identifier;
- `name`, required trimmed plain text;
- `description`, optional trimmed plain text;
- `habit_type`, exactly `check`, `quantity`, `abstinence`, or `chore`;
- an inclusive local `start_date`;
- an optional inclusive local `end_date`;
- an optional local reminder time;
- optional reminder text;
- active or archived state;
- an optional archive timestamp;
- timezone-aware creation and update timestamps.

The name is 1 through 120 characters after trimming. The description is stored as `""` when blank and is at most 500 characters after trimming. Reminder text is stored as `""` when blank and is at most 160 characters after trimming. An end date cannot precede the start date. Archiving records the archive timestamp; restoring clears it.

The habit type may be changed only while no occurrence record exists. Once evidence exists, changing the type is rejected because it would reinterpret history. Names, descriptions, schedules, reminders, active ranges, and type-specific targets may otherwise be edited while retaining existing occurrence records as factual history.

### 3.2 Habit types

#### Check

A check habit represents a yes/no behavior such as gym or reading. A dated result is one of:

- `completed`;
- `missed`;
- `excused`.

#### Quantity

A quantity habit records a non-negative exact Decimal measurement, a required trimmed unit, and one target rule:

- `at_least` with a lower target;
- `at_most` with an upper target;
- `range` with inclusive lower and upper targets.

The target and recorded value use `Decimal`, reject exponent and non-finite syntax, and accept at most two decimal places. Values range from `0.00` through `999,999,999.99`. A range lower bound cannot exceed its upper bound. The unit is plain text from 1 through 40 characters after trimming.

A recorded quantity is factual whether or not it meets the target. Meeting the target derives a successful outcome; a value outside the target derives an unsuccessful outcome. The persisted result stores the measurement, not a competing success flag. An excused quantity occurrence has no measurement.

#### Abstinence

An abstinence habit represents a day without something, such as smoking or alcohol. A dated result is one of:

- `successful`;
- `lapse`;
- `excused`.

Only an explicitly recorded successful day counts as success. Absence of a record never implies abstinence.

#### Scheduled chore

A chore represents a due task such as cleaning or laundry. A dated result is one of:

- `completed`;
- `missed`;
- `excused`.

A chore differs from a check habit through due/overdue language and presentation, not through a separate occurrence table.

### 3.3 Occurrence records

A `HabitOccurrence` owns:

- a stable identifier;
- its owning habit;
- one local occurrence date;
- a type-appropriate explicit result or quantity value;
- an optional trimmed plain-text note;
- an optional trimmed plain-text excuse reason;
- timezone-aware creation and update timestamps.

The pair `(habit, occurrence_date)` is unique. Notes are stored as `""` when blank and are at most 500 characters. Excuse reasons are stored as `""` when blank and are at most 250 characters. An excused result may carry a reason; non-excused results store no excuse reason. Quantity results store either one measurement or an excused status, never both. Other habit types never store a quantity.

Unknown is derived from a past due date without an occurrence. It is never persisted as fabricated evidence. A future due date has a pending state rather than Unknown. Editing replaces the factual result for the unique habit/date pair through an explicit edit workflow. Removing an erroneous occurrence is confirmed hard deletion of that occurrence only and returns a due date to Unknown.

A record on a non-due date is permitted only through an explicit one-off occurrence workflow, which also creates a schedule addition for that date. Ordinary entry rejects accidentally selected non-due dates.

## 4. Recurrence and due-date semantics

### 4.1 Supported recurrence forms

Each habit owns exactly one base recurrence kind:

- `daily` — every calendar day;
- `weekly` — one or more selected weekdays;
- `interval` — every positive `N` days or weeks from an explicit anchor date;
- `monthly_dates` — one or more calendar day numbers from 1 through 31;
- `monthly_ordinal_weekdays` — one or more ordinal weekday rules, where ordinal is first, second, third, fourth, or last.

The structured rule may contain multiple selected weekdays, monthly dates, or ordinal weekday entries as appropriate. Duplicate components are rejected or normalized to one semantic component. Interval `N` is a positive integer with a documented implementation ceiling chosen to prevent accidental unusable schedules; it is never calculated from the last completion.

Version one does not accept free-form RRULE text, natural-language recurrence, nested boolean rules, per-habit time zones, automatic holiday calendars, or silent schedule inference.

### 4.2 Active range and exceptions

The habit's start and optional end dates bound recurrence inclusively. Recurrence also supports:

- explicit excluded dates;
- explicit one-off added dates;
- temporary pause ranges with inclusive start and end dates.

Pause ranges require start on or before end. Additions and exclusions are unique per habit/date. Overlapping pause ranges are semantically equivalent to their union and must not create duplicate occurrences.

Due-date precedence is:

1. Outside the active start/end range: not due.
2. Inside a pause: not due.
3. Explicit exclusion: not due.
4. Explicit addition: due.
5. Otherwise evaluate the base recurrence.

An explicit addition remains bounded by the habit's active range. A date cannot be both an effective addition and exclusion; the form rejects contradictory configuration rather than relying on hidden precedence.

If a requested monthly date does not exist, such as day 31 in February, that month has no such occurrence; the date is not shifted. All recurrence uses local calendar dates without timestamp arithmetic.

### 4.3 Schedule edits and retained history

Changing recurrence affects future and derived due-state evaluation. Existing occurrence records remain visible even if the edited schedule no longer marks their dates due. They are labeled as retained historical records rather than deleted or silently reinterpreted.

Schedule evaluation is pure and deterministic. Public APIs accept explicit dates or date ranges rather than reading the clock internally. Queries place finite bounds on recurrence expansion.

## 5. Streak and momentum calculations

### 5.1 Success semantics

A due occurrence is successful when:

- a check or chore result is `completed`;
- an abstinence result is `successful`;
- a quantity measurement satisfies its target.

A streak-breaking occurrence is:

- a check or chore result of `missed`;
- an abstinence result of `lapse`;
- a quantity measurement outside its target;
- a past due date with no occurrence, shown as Unknown.

An excused occurrence neither extends nor breaks a streak. Future due dates and non-due dates have no effect.

### 5.2 Streak semantics

Streaks count consecutive due occurrences, not necessarily consecutive calendar days. Calculations produce at least:

- current streak;
- longest streak;
- whether unresolved overdue Unknown occurrences exist;
- most recent effective result.

Historical entry, edit, removal, schedule additions, exclusions, pauses, and recurrence edits recalculate derived results. A non-daily habit is described as `N in a row` or `N completed occurrences`, not inaccurately as an N-day streak.

### 5.3 Momentum

Momentum uses the foundation's canonical calculation over sorted, deduplicated successful dates:

`next = round(previous × exp(-0.1 × elapsed_days) + 1, 2)`

The first successful date uses one elapsed day, which is immaterial when previous momentum is zero. Rounding occurs at every successful occurrence. The implementation satisfies `fixtures/habit-momentum-cases.json` exactly.

Check/chore completions, abstinence successes, and quantity values meeting their target each add one momentum point. Misses, lapses, unsuccessful quantities, Unknown dates, and excused occurrences add no point. Momentum and streak are separate immutable derived results and are never persisted as competing totals.

Momentum is presented as a descriptive personal signal, not a diagnosis, prediction, rank, or moral judgment. The interface explains both streak and momentum semantics.

## 6. Reminders

A habit may have one optional local reminder time and optional short reminder text. These fields:

- order due habits within a selected date;
- identify a reminder as upcoming or passed relative to the canonical local time where a request owns such a time boundary;
- remain visible in the Daily Register and Habits register;
- do not create an external delivery promise.

Version one has no background scheduler, email, push, browser notifications, desktop notifications, service worker, or operating-system integration. Copy must say `Reminder time` or equivalent, not claim that LifeOS will notify the owner while the application is closed.

Because the existing core clock boundary supplies only a canonical date, time-sensitive reminder state must use a separately injected, testable local-time boundary or limit initial presentation to ordering and the configured time. It must not call the system clock repeatedly inside one response.

## 7. Routes and HTTP behavior

Habits routes are namespaced beneath `/habits/`. The stable route set includes:

| Method | Path | Name | Purpose |
| --- | --- | --- | --- |
| GET | `/habits/` | `habits:register` | Selected-date Habits register |
| GET, POST | `/habits/new/` | `habits:habit-create` | Create a habit and schedule |
| GET | `/habits/<int:pk>/` | `habits:habit-detail` | Canonical habit review |
| GET, POST | `/habits/<int:pk>/edit/` | `habits:habit-edit` | Edit configuration and recurrence |
| GET, POST | `/habits/<int:pk>/archive/` | `habits:habit-archive` | Confirm archive |
| GET, POST | `/habits/<int:pk>/restore/` | `habits:habit-restore` | Confirm restoration |
| GET | `/habits/archived/` | `habits:archive-list` | Archived habit history |
| GET, POST | `/habits/<int:pk>/occurrences/new/` | `habits:occurrence-create` | Record one dated result |
| GET | `/habits/<int:pk>/occurrences/<int:occurrence_pk>/` | `habits:occurrence-detail` | Canonical result review |
| GET, POST | `/habits/<int:pk>/occurrences/<int:occurrence_pk>/edit/` | `habits:occurrence-edit` | Correct one result |
| GET, POST | `/habits/<int:pk>/occurrences/<int:occurrence_pk>/delete/` | `habits:occurrence-delete` | Confirm result removal |

Register, archive list, habit detail, and occurrence detail are explicitly GET-only. Create/edit/archive/restore/remove mutations accept only GET and POST. GET never mutates. POST is the only mutation method, and Django CSRF protection remains active.

Successful mutation follows Post/Redirect/Get. Habit changes redirect to canonical habit review; occurrence changes redirect to canonical occurrence or habit review as appropriate; archive/restore returns to an honest register or archive view. Success messages state only the operation and include no personal value.

## 8. Habits register and presentation

The register defaults to the canonical local date and accepts only exact `date=YYYY-MM-DD`. Missing input uses the canonical date without error. Invalid input falls back to the canonical date with a generic visible error and never echoes the raw value.

For the selected date, the register presents:

- habits due that date, ordered by reminder time with habits lacking a time afterward, then normalized name and stable identifier;
- each habit's type, concise schedule description, recorded or derived state, current streak, and momentum;
- a distinct Needs attention section for overdue Unknown due occurrences;
- active habits not due on the selected date in a secondary section;
- actions to create a habit and review archived habits;
- an honest empty state when no habits exist.

The detail page presents configuration, recurrence, reminder, current and longest streaks, momentum, next due date, recent outcomes, notes where appropriate, and retained historical records. Compact registers and summaries omit occurrence notes and excuse reasons.

State is always textual and never conveyed by color alone. Abstinence copy uses factual terms such as Successful, Lapse, Excused, and Unknown without punitive language. Quantity presentation shows the recorded value, unit, target, and whether the target was met.

## 9. Habit lifecycle and occurrence workflows

### 9.1 Create and edit

Habit creation and editing use type-aware server-rendered forms. Irrelevant configuration fields are rejected or cleared deterministically and are never silently interpreted for another type. Recurrence components and exceptions are validated as one coherent configuration before commit.

Creating or editing a habit plus its owned configuration records uses one explicit outer `transaction.atomic()` boundary. Exactly one coherent save operation occurs, atomic exit completes, then factual success feedback and redirect are produced.

If occurrence history exists, the form disables or rejects type changes with a clear explanation. Editing the schedule never deletes occurrence history.

### 9.2 Archive and restore

Archive and restore require distinct confirmation pages. Archiving sets the archived state and timestamp and prevents future routine entry or new due occurrences after the archive boundary while retaining all existing records. Restoring clears the archive timestamp and resumes recurrence according to the configured active range; it does not backfill fabricated outcomes for the archived period.

Version one does not hard-delete habits or cascade-delete their history.

### 9.3 Record, edit, and remove outcomes

Type-specific occurrence forms expose only valid inputs. A standard entry must be within the habit's active range and due under the effective schedule. An explicit one-off action creates both a schedule addition and occurrence in one atomic mutation.

The unique habit/date constraint prevents duplicate evidence. Attempting to create a result where one exists directs the owner to the explicit edit workflow rather than silently overwriting it. Editing preserves the unique identity. Removing a result requires confirmation and hard-deletes only that result.

## 10. Daily Register integration

For the canonical date, `lifeos.habits.summary.get_summary(today=...)` performs one Habits-owned bounded snapshot. Empty/ready state and all values derive from that same immutable snapshot.

An empty database produces an honest empty Habits summary linked to the Habits register and a New habit action. A ready summary exposes exactly these immutable labelled values in order:

1. **Due today** — effective due-habit count;
2. **Completed** — successful results among today's due habits;
3. **Needs attention** — bounded overdue Unknown count under the approved attention window;
4. **Active habits** — active habit count.

The attention window must be explicit in implementation and user-facing explanation so an unbounded lifetime recurrence scan is neither performed nor implied. Per-habit momentum stays on Habits-owned pages and is not collapsed into a misleading aggregate.

An expected `DatabaseError` becomes `SummaryUnavailable`, allowing Core to render only Habits as unavailable. Unexpected exceptions propagate. Core reads its canonical date once and passes the same date to Work, Money, and Habits in deterministic order. Core never imports Habit models, evaluates recurrence, or calculates streaks or momentum.

The Habits panel and primary navigation link to `habits:register`. Its action links to `habits:habit-create`. Exactly one primary navigation item carries `aria-current="page"` based on resolved route identity.

## 11. Future calendar boundary

Habits exposes a small public immutable projection API that accepts an explicit finite date range and returns calendar event values containing only the fields the future calendar needs, such as domain key, stable opaque reference, date, concise title, state, and canonical URL.

This boundary:

- evaluates Habits recurrence without exposing Habit query internals;
- never imports Work;
- does not persist duplicate calendar events;
- has a documented finite-range limit;
- performs no mutation;
- contains no calendar UI.

The later calendar slice may compose this boundary with a corresponding Work-owned projection. It must not query either domain's models directly or become a second source of truth.

## 12. Accessibility and feedback

Forms use visible labels, explanatory hints before errors, native date/time/select/decimal/text controls, and one clear submission action. Invalid fields are programmatically associated with errors. Multiple errors produce a concise linked summary. Safe submitted values remain visible where feasible.

Requirements include:

- one main region and logical headings;
- correct fieldsets and legends for recurrence and type-specific options;
- at least 44-by-44 CSS-pixel interactive targets;
- keyboard-operable date navigation and actions;
- visible state and outcome text independent of color;
- no page-level horizontal scrolling;
- source order matching visual order;
- no JavaScript dependency for navigation, validation, calculations, or mutation;
- local assets only.

Success messages contain no habit name, date, quantity, unit, note, reason, or identifier. Controlled errors explain a safe next step without exposing internals.

## 13. Error, transaction, and privacy behavior

Expected `DatabaseError` failures are handled at every database boundary introduced by this slice, including:

- register, detail, archive-list, summary, and projection materialization;
- habit and occurrence lookup;
- validation that queries uniqueness or constraints;
- habit/configuration create and edit;
- archive and restore;
- occurrence create, edit, and remove;
- exit from the outer atomic block when commit fails.

A controlled lookup failure returns a Habits-owned HTTP 503 response rather than a false 404. A genuinely missing record returns 404. Validation/save/delete/commit failure retains safe values or identity where feasible, commits nothing when rollback is established, adds no success message, and presents operation-specific recovery guidance.

Uncertain-commit guidance appears only when the mutation body returned and atomic exit failed. A direct validation, save, or delete exception is a definite controlled failure under the outer atomic rollback and must not encourage inspection for a possibly committed result.

Only expected `DatabaseError` and the established summary wrapper become controlled operational outcomes. Unexpected programming exceptions propagate.

Controlled warning logs contain only fixed domain, operation, and exception-class metadata. They exclude exception text and arguments, names, descriptions, schedules, dates, quantities, targets, units, notes, reasons, identifiers tied to a record, request bodies, query strings, SQL, database paths, tokens, and tracebacks at the controlled site.

## 14. Architecture and components

The Habits slice uses focused conventional Django modules:

- `models.py` owns Habit, type configuration, recurrence, exceptions, pauses, HabitOccurrence, normalization, invariants, ordering, and database constraints.
- `recurrence.py` owns pure due-date evaluation, finite expansion, schedule description inputs, and next/previous due calculations.
- `calculations.py` owns immutable streak, target-success, and momentum derivation.
- `queries.py` owns deterministic active/archive/history queries and one-snapshot register inputs.
- `forms.py` owns strict lexical parsing, type-aware configuration, recurrence input, and occurrence forms.
- `views.py` owns method enforcement, orchestration, atomic boundaries, controlled database recovery, messages, and redirects.
- `summary.py` adapts one Habits-owned snapshot to Core's immutable presentation boundary.
- `calendar.py` exposes the future finite-range immutable event projection.
- `urls.py` owns the `habits` namespace.

Explicit relational fields and constraints are used instead of JSON configuration. The exact table decomposition may use one Habit table plus one-to-one type configuration and related recurrence component tables, provided type-incompatible states are rejected at the model/form boundary and protected by feasible database constraints.

No generic rules engine, arbitrary expression evaluator, repository framework, background queue, event bus, cache, REST API, client-side state store, or notification service is introduced.

## 15. Testing strategy

Implementation follows strict RED–GREEN–REFACTOR in complete increments. Tests use real behavior and explicitly owned disposable databases.

### 15.1 Models and migrations

Tests cover:

- all four fixed habit types;
- name, description, reminder text, active date range, archive timestamp, and trimming boundaries;
- type-specific required and prohibited configuration;
- exact quantity syntax, scale, bounds, units, and target relationships;
- recurrence-kind invariants and component uniqueness;
- additions, exclusions, pauses, and contradictory configuration;
- unique `(habit, occurrence_date)` evidence;
- type-appropriate occurrence result/value/reason combinations;
- type immutability once history exists;
- archive/restore history retention;
- migration application and migration-state consistency.

### 15.2 Recurrence

Pure tests cover:

- daily and selected-weekday schedules;
- day/week intervals from a fixed anchor;
- monthly dates across 28/29/30/31-day months and leap years;
- first through fourth and last weekday rules;
- inclusive start/end ranges;
- pause, exclusion, addition, and precedence behavior;
- contradictory exception rejection;
- next/previous due dates and finite-range ceilings;
- deterministic schedule descriptions;
- no dependence on completion timing or ambient clock.

### 15.3 Calculations

Pure tests cover:

- at-least, at-most, and inclusive-range target evaluation;
- current and longest streaks over due occurrences;
- success, miss/lapse, unsuccessful quantity, Unknown, excused, future, and non-due behavior;
- historical corrections and schedule changes;
- sorted/deduplicated successful dates;
- every `habit-momentum-cases.json` fixture;
- per-step two-place rounding;
- immutable inputs and outputs.

### 15.4 HTTP workflows

Tests cover:

- canonical paths, names, and methods;
- exact selected-date fallback without unsafe echo;
- create/edit Post/Redirect/Get;
- type-change rejection after history;
- archive and restore confirmation;
- one atomic boundary per coherent mutation;
- type-specific occurrence entry and editing;
- explicit one-off date creation;
- duplicate-date handling without overwrite;
- confirmed occurrence removal;
- CSRF enforcement;
- escaped text and omission of notes/reasons from compact views;
- success messages only after commit.

### 15.5 Failure contracts

Regression tests independently inject `DatabaseError` at:

- every list/snapshot/materialization boundary;
- habit and occurrence lookup;
- validation;
- direct save and delete;
- outer atomic exit;
- Daily Register summary;
- future calendar projection.

They prove 503 versus real 404, rollback, direct-failure versus uncertain-commit wording, safe retained forms/identity, no false success, class-only logs, failure isolation, and unexpected-exception propagation.

### 15.6 Register and integration

Tests cover:

- empty and ready selected-date registers;
- reminder ordering;
- due, completed, missed/lapse, unsuccessful quantity, excused, pending, Unknown, overdue, and not-due states;
- one snapshot for rows and derived counts;
- bounded Needs attention semantics;
- archived history separation;
- exact Daily Register value order;
- one canonical date read and Work/Money/Habits composition;
- expected Habits failure isolation;
- Habits route-identity navigation;
- finite immutable future-calendar projections without Work imports.

### 15.7 Automated and manual verification

The completion gate includes focused Habits tests, affected Core/Work/Money tests, documentation contracts, the complete suite, Django checks, migration drift, owned disposable migration/startup, and a CSRF-enforced create/review/edit/archive/restore/occurrence/remove workflow.

Source and tracked-state scans cover personal data, database artifacts, remote runtime dependencies, prohibited visual tooling, and executable historical-source references. Verification output records only statuses and non-personal markers.

No visual browser automation is added. These checks remain explicitly manual unless a person performs them:

1. layout at 320 CSS pixels;
2. layout and operation at 200% browser zoom;
3. complete text-spacing override;
4. keyboard traversal and visible focus;
5. system, light, and dark theme behavior including blocked storage;
6. reduced-motion behavior;
7. screen-reader smoke testing of landmarks, forms, recurrence controls, errors, state labels, history, navigation, and message regions.

## 16. Delivery sequence and review gate

The implementation plan should divide the slice into independently testable tasks covering:

1. Habit persistence and type-specific configuration.
2. Structured recurrence persistence and pure due-date evaluation.
3. HabitOccurrence persistence and target-success derivation.
4. Streak and canonical momentum calculations.
5. Habit create/review/edit workflows.
6. Archive/restore and archived-history workflows.
7. Occurrence create/review/edit/remove and explicit one-off entry.
8. Selected-date Habits register, reminder ordering, and Needs attention.
9. Daily Register summary, Habits navigation, and future calendar projection boundary.
10. Documentation reconciliation and complete disposable verification.

Each task uses strict RED–GREEN–REFACTOR, focused and complete test gates, and a task-boundary commit. After the final task, one fresh whole-slice reviewer checks the specification, plan, migrations, implementation, tests, maintained documents, privacy boundaries, and verification receipt. Confirmed Critical or Important findings receive exactly one TDD fix pass. Minor findings are reported and deferred rather than silently fixed.

## 17. Acceptance criteria

The Habits slice is complete when:

- all four habit types and their type-specific invariants are persisted and migrated;
- recurrence supports the approved daily, weekly, interval, monthly-date, ordinal-weekday, active-range, pause, exclusion, and addition semantics;
- one unique occurrence per habit/date records only type-appropriate factual evidence;
- abstinence never infers success from missing data;
- Unknown is derived, excused is explicit, and their streak effects are correct;
- quantity targets support at least, at most, and inclusive range with exact Decimal behavior;
- current/longest streak and canonical momentum are pure, immutable, tested derivations;
- habit CRUD, archive/restore, and occurrence workflows work without JavaScript through the specified methods and redirects;
- reminders are honest in-app ordering/presentation only;
- the register and Daily Register use one bounded Habits-owned snapshot each;
- Core does not import Habits models or reproduce Habits policy;
- Habits imports neither Work nor Money;
- a finite immutable event projection is ready for a future calendar without implementing that calendar;
- expected database failures have private controlled outcomes, real missing records remain 404, and unexpected exceptions propagate;
- focused/full automated gates and disposable HTTP verification pass;
- no personal data, personal database, historical application source/data, remote runtime asset, prohibited browser tooling, or repository database artifact is accessed or introduced;
- all seven manual gaps remain honestly reported unless personally verified;
- the fresh whole-slice review and one permitted TDD fix pass are complete.

## 18. Explicit non-goals

This slice does not implement:

- the combined Work/Habits calendar, month grid, week planner, or agenda UI;
- direct Work or Money integration;
- browser, desktop, operating-system, email, SMS, or push notifications;
- background scheduling or workers;
- free-form RRULE or natural-language recurrence parsing;
- holiday calendars or per-habit time zones;
- medical advice, diagnosis, treatment guidance, addiction intervention, or emergency support;
- social sharing, competition, leaderboards, badges, points, punitive streak messaging, or artificial urgency;
- automatic abstinence success from silence;
- hard deletion of habits or cascading history deletion;
- arbitrary user-authored formulas or scripts;
- charts, predictive analytics, recommendations, or cross-person comparison;
- a REST, GraphQL, or public API;
- client-side authoritative validation, recurrence, streak, momentum, or mutation;
- visual browser tests, screenshots, image snapshots, golden files, pixel comparison, capture rounds, or visual-regression services;
- access to, reuse of, or migration from `/home/aUser/improvedCalendar` or any historical personal database.
