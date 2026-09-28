# LifeOS Native Foundation and Work Design

**Status:** Approved design, pending implementation plan review  
**Date:** 2026-09-29  
**Target:** Native Linux desktop application  
**Supersedes:** `docs/superpowers/specs/2026-09-28-lifeos-minimal-workbench-design.md` for implementation architecture and the Foundation/Work product model

## 1. Purpose

LifeOS will become a private, local-first native desktop application for operating and reconciling personal records. The first delivery slice establishes the durable Flutter foundation and ships a complete reinvented Work domain.

The product is not a dashboard, launcher, motivational tracker, or browser-hosted administrative interface. It is a precise daily workbench where the owner can record facts, inspect derived meaning, identify discrepancies, and make the smallest valid correction without losing context.

The first slice succeeds when the owner can:

1. launch LifeOS as a native Linux application without a web server;
2. maintain multiple employments and effective-dated pay agreements;
3. record shifts from start/end instants and unpaid breaks, including overnight work;
4. review exact expected compensation under the applicable agreement;
5. group work into explicit pay periods;
6. record payslip evidence;
7. reconcile expected compensation against compatible paid evidence;
8. correct finalized records without erasing their history;
9. create a consistent manual backup and a versioned Work export;
10. complete these workflows in one dense rail/register/inspector workspace.

## 2. Product Principles

### 2.1 Truth before motivation

LifeOS records what happened and distinguishes it from expectations, interpretations, and evidence. It does not invent missing schedules, payroll policy, deductions, goals, priorities, or motivational scores.

### 2.2 Facts and derivations remain distinct

Recorded shift instants, breaks, agreements, pay periods, and payslips are facts. Paid duration, expected compensation, summaries, and reconciliation differences are derived views. A derivation never silently mutates a fact.

### 2.3 Reconciliation, not false certainty

The application exposes disagreements and incompatible evidence. It does not force unlike values into one total or present an estimate as a payment.

### 2.4 Local and private by construction

The shipped application has no account, cloud dependency, telemetry, advertising, analytics, remote font, CDN, or runtime API dependency. Personal content must not appear in source control, tests, fixtures, screenshots, logs, diagnostic output, or readiness checks.

### 2.5 Dense, direct operation

The primary interaction is single-click **select → inspect → act**. The register remains visible while the adjacent inspector explains or edits the selected record. Mouse operation is primary, with complete keyboard and semantic accessibility.

### 2.6 Historical integrity

Used agreements and finalized records are historical evidence. Corrections create explicit successor records instead of rewriting or deleting the past.

## 3. Scope

### 3.1 Included in this slice

- Native Flutter Linux application bootstrap and packaging foundation
- Application-owned window, theme, navigation, and workbench shell
- Fresh embedded SQLite database
- Database identity, migrations, validation, and guarded test isolation
- Application clock and timezone services
- Safe diagnostics and privacy boundaries
- Multiple employments
- Versioned hourly pay agreements
- Per-shift overtime threshold and multiplier
- Shift and break lifecycle
- Overnight and daylight-saving-safe duration handling
- Explicit pay periods
- Payslip evidence
- Expected-versus-paid reconciliation
- Revision conflict handling
- Void-and-replace correction
- Manual SQLite backup
- Versioned Work JSON export
- Automated domain, persistence, widget, and Linux integration tests
- Bounded native visual verification and final design documentation
- A Flutter-aware `app.sh` that tests, builds, verifies, and starts the application

### 3.2 Explicitly excluded

- Django, Python, React, Node, Vite, browser delivery, or local HTTP APIs in the shipped architecture
- Importing, inspecting, transforming, or mutating the existing Django database
- Money and Habits implementations
- A complete Today surface beyond a stable navigation destination or unavailable placeholder
- Salaried employment
- Freelance invoices
- Shift differentials, allowances, bonuses, commissions, or tips
- Weekly, monthly, or pay-period overtime rules
- General-purpose payroll or rules engines
- Tax-band, withholding, or statutory deduction calculation
- Automatic payroll calendar inference
- Multi-currency conversion
- Cloud sync, automatic backup, background daemons, notifications, and tray behavior
- Plugins or runtime-loaded feature modules
- Encrypted backups or claims of encryption at rest
- Flatpak and Snap distribution

## 4. Replacement and Archive Policy

This specification replaces the earlier React plus Django implementation direction. Flutter is not an additional client and will not wrap, embed, or call the Django application.

The existing Django source and its database remain untouched as an archive during the first native implementation. The native application must never:

- search for the Django database;
- infer its location;
- open or inspect it;
- copy it into native storage;
- import or migrate its records;
- write to it;
- reuse it for development, screenshots, tests, or verification.

The uncommitted React implementation plans are obsolete and must not be executed. Their removal or archival is an implementation-planning concern; it must not be mixed into database migration or product code.

## 5. Technology Direction

### 5.1 Core stack

- Flutter stable, pinned to an exact repository-controlled SDK version
- Dart from the pinned Flutter SDK
- Flutter Linux desktop target
- Drift over native SQLite
- `sqlite3` for the native SQLite library
- Riverpod for dependency injection, reactive subscriptions, and feature controllers
- GoRouter for application surface, temporal scope, and selected-record state
- `file_selector` for owner-selected backup and export destinations
- `path_provider` and `path` for application-support and temporary paths
- `window_manager` behind a narrow LifeOS adapter
- `uuid` for stable UUIDv7 identifiers
- `clock` for injected time
- `timezone` for IANA timezone conversion
- Flutter and Dart test tooling, Drift migration tests, and Linux integration tests

Exact package and SDK versions belong in the implementation plan and lockfiles. Dependencies must be pinned and reviewed before implementation.

### 5.2 Deliberately rejected alternatives

Raw `sqlite3`, `sqlite_async`, and `sqflite_common_ffi` are viable but would leave LifeOS responsible for more schema mapping, reactive invalidation, and migration infrastructure without improving the product. NoSQL object stores are unsuitable for the relational and historical Work model.

Redux, BLoC, event buses, a global mutable application store, Freezed, Riverpod code generation, and mocking frameworks are not default dependencies. They may be introduced only if an implementation need cannot be met clearly by Dart types, explicit immutable models, fakes, Drift generation, and ordinary Riverpod providers.

## 6. Architecture

LifeOS is a local modular monolith:

```text
Flutter widget tree
  → feature controllers and Riverpod providers
    → application services
      → pure domain policy
      → repositories
        → Drift DAOs and projections
          → dedicated SQLite database isolate
```

### 6.1 Layer responsibilities

#### App

Owns bootstrap, error recovery, the desktop frame, theme, route parsing, navigation, selection restoration, and window behavior.

#### Core database

Owns database location, identity, opening, PRAGMAs, schema versions, migrations, validation, transaction access, and lifecycle.

#### Core time

Owns the injected clock, strict local-date value type, IANA timezone loading, UTC/local conversion, and deterministic “today.”

#### Core files

Owns destination selection abstractions, consistent backup creation, atomic file publication, export encoding, and compatibility validation.

#### Core privacy

Owns safe diagnostic categories and redaction rules. It must not accept arbitrary personal values for logging.

#### Work domain

Owns immutable value objects, invariants, exact arithmetic, agreement resolution, pay calculation, and reconciliation policy. It has no Flutter or Drift dependency.

#### Work application

Owns use cases and transaction boundaries: employment and agreement creation, shift lifecycle, period management, payslip recording, correction, backup coordination, and reconciliation queries.

#### Work data

Owns Drift tables, constraints, DAOs, repository implementations, query projections, and conversion between persistence and domain representations.

#### Work presentation

Owns the Work route, register, inspector, lifecycle controls, forms, controllers, accessible announcements, and visual states.

Widgets must not calculate compensation, infer business dates, execute SQL, select filesystem paths directly, or copy database files.

### 6.2 Feature organization

Features are registered at compile time. The architecture should permit later Money and Habits modules without implementing a runtime plugin system or generic framework before those domains exist.

## 7. Application Bootstrap and Failure Behavior

Startup proceeds in a controlled order:

1. initialize Flutter bindings;
2. resolve the application-support directory;
3. configure privacy-safe diagnostics;
4. initialize timezone data and the application clock;
5. create the database service on its dedicated isolate;
6. verify database identity and schema compatibility;
7. run allowed migrations;
8. validate required PRAGMAs and schema state;
9. initialize application providers and routes;
10. show the native window only when the first stable application state is ready.

Startup failure must produce a local recovery surface that identifies the failure category without exposing database paths, SQL, record content, or raw exception messages. Recoverable migration or storage failures must not lead to a partially initialized writable application.

The application must never report that a write failed if the transaction outcome is uncertain. Where the persistence layer cannot determine whether a commit completed, it reports an explicit uncertain outcome and instructs the owner to reload and inspect records before retrying.

## 8. Database Foundation

### 8.1 Location and identity

The native database lives beneath the platform application-support directory, outside the source repository, with a distinct name such as:

```text
<application-support>/lifeos-native-v1.sqlite
```

The containing directory should use owner-only permissions where supported by the Linux filesystem.

The database must use a nonzero application-specific SQLite `application_id`. Opening logic must reject a nonempty file with an absent or incorrect identifier. It must never adopt an arbitrary SQLite file by applying LifeOS migrations to it.

### 8.2 Operating policy

The database runs through one shared Drift database service on a dedicated isolate. It must enable and verify:

- `PRAGMA foreign_keys = ON`;
- WAL journal mode;
- a conservative busy timeout;
- an explicitly chosen and tested synchronous policy;
- Drift schema versioning;
- explicit transactions for multi-record mutations.

A successful UI mutation state is published only after transaction commit. There is no optimistic persistence.

### 8.3 Migrations

Migrations exist from schema version one even though the first database starts empty. Every released schema version has a schema snapshot. Automated tests migrate each supported historical snapshot to the current schema and validate the resulting structure and representative data.

A checksum or equivalent reviewable migration identity must detect accidental modification of previously released migration steps. Released migrations are immutable; corrections are new migrations.

### 8.4 Test isolation

Each persistence or integration test receives a fresh temporary application-data root and database. Test bootstrap must fail closed if a resolved path:

- points to the normal production application-support directory;
- lacks an explicit test ownership marker;
- resolves inside a known real-data location;
- attempts to reuse a non-test database.

Tests, fixtures, screenshots, and goldens use obviously synthetic values only.

## 9. Shared Value Types

### 9.1 Identifiers

All persisted records use UUIDv7 identifiers represented by dedicated typed IDs at the domain boundary. UI routes may contain IDs but never personal labels, notes, amounts, or other record content.

### 9.2 Local dates

Business dates are strict ISO calendar dates without implicit timezone conversion. Invalid text never silently becomes today.

### 9.3 Instants and timezones

Persist instants in UTC. A shift captures the IANA timezone and local start date at creation. Duration uses elapsed UTC time; display uses the captured timezone. This makes daylight-saving transitions explicit and reproducible.

### 9.4 Money

Persist monetary amounts as integers, never binary floating point.

- Payslip amounts use integer minor units.
- Hourly agreement rates use integer micro-units per hour, allowing four decimal places for EUR rates.
- Currency is persisted as an ISO code.
- Version one presents and creates EUR records only; the stored code prevents an incompatible future schema.

### 9.5 Rate basis

Every agreement and payslip amount has an explicit basis: `gross` or `net`. The application does not infer tax deductions or convert between bases.

### 9.6 Multipliers and rounding

Overtime multipliers are rational numerator/denominator pairs, such as `3/2`. Expected-pay calculations use integer or `BigInt` intermediate arithmetic. Rounding occurs only at named monetary output boundaries using decimal half-up rounding.

## 10. Work Domain Model

### 10.1 Employment

An employment contains:

- UUID;
- owner-facing name;
- optional factual legal/employer label;
- active or archived state;
- creation and update timestamps;
- revision.

Names are required after trimming. Archiving removes an employment from normal new-record controls but never hides its history. An employment referenced by historical records cannot be deleted.

### 10.2 Pay agreement version

A pay agreement version contains:

- UUID;
- employment ID;
- monotonic version number within the employment;
- inclusive effective local start date;
- optional inclusive effective local end date;
- EUR hourly rate in integer micro-euros;
- rate basis (`gross` or `net`);
- per-shift overtime threshold in paid minutes;
- overtime multiplier numerator and denominator;
- optional factual label and note;
- creation timestamp;
- revision.

Invariants:

- effective ranges may not overlap within one employment;
- the end date cannot precede the start date;
- hourly rate must be positive;
- overtime threshold must be positive;
- multiplier numerator and denominator must be positive;
- a used agreement is immutable;
- closing an unused agreement range is permitted only if it creates no overlap and invalidates no finalized shift;
- correction of a used agreement creates a new effective-dated version.

### 10.3 Work shift

A shift contains:

- UUID;
- employment ID;
- optional resolved agreement version ID until finalization;
- lifecycle state;
- UTC start instant;
- optional UTC end instant;
- captured IANA timezone;
- captured local start date;
- owner-entered overtime minutes;
- optional factual note;
- optional void reason;
- optional replacement shift ID;
- optional replaced shift ID;
- creation and update timestamps;
- revision.

Lifecycle states are:

- `draft`: manually entered or replacement record not yet finalized;
- `running`: start recorded, no open break;
- `onBreak`: start recorded with exactly one open break;
- `finalized`: immutable active historical fact;
- `void`: immutable superseded historical fact excluded from current totals.

Only one `running` or `onBreak` shift may exist at a time across the application. Version one does not support concurrent employment timers.

### 10.4 Shift break

A break contains:

- UUID;
- shift ID;
- UTC start instant;
- optional UTC end instant;
- open or closed state;
- creation and update timestamps;
- revision.

Invariants:

- at most one break is open for a shift;
- breaks may not overlap;
- closed breaks must have positive duration;
- all breaks must fit inside the shift bounds at finalization;
- a finalized shift cannot contain an open break.

### 10.5 Shift finalization

Finalization validates the complete shift in one transaction:

1. end exists and follows start;
2. no break remains open;
3. all breaks are bounded, positive, and non-overlapping;
4. paid elapsed duration is positive;
5. overtime minutes are nonnegative and do not exceed paid whole minutes;
6. exactly one agreement is effective on the captured local start date;
7. the agreement belongs to the shift’s employment;
8. the selected agreement ID is persisted on the shift;
9. state becomes `finalized` and revision advances.

A cross-midnight shift is attributed wholly to its captured local start date and effective agreement in version one. It is not split across dates or agreement versions.

### 10.6 Expected compensation

For a finalized shift:

```text
elapsed seconds = end UTC - start UTC
break seconds = sum(closed break durations)
paid seconds = elapsed seconds - break seconds
overtime seconds = overtime minutes × 60
regular seconds = paid seconds - overtime seconds
regular amount = hourly rate × regular seconds / 3600
overtime amount = hourly rate × overtime seconds × multiplier / 3600
expected amount = round-half-up(regular amount + overtime amount)
```

The overtime threshold is a validation and assistance rule: overtime minutes may be suggested from paid duration beyond the agreement threshold, but the stored overtime minutes remain an explicit owner-confirmed fact. LifeOS must show when an entered value differs from the threshold-derived suggestion; it must not silently replace the owner’s value.

Expected values are view projections. The agreement reference and recorded facts are persisted; calculated monetary totals are not a second source of truth.

### 10.7 Correction

A finalized shift cannot be edited or hard-deleted. Correction is one transaction that:

1. verifies the expected revision;
2. marks the original shift `void` with a factual reason;
3. creates a linked replacement `draft` populated from the original facts;
4. preserves the original breaks and agreement reference for historical inspection;
5. excludes the void record from active totals;
6. leaves the replacement selected in edit mode after commit.

Canceling a replacement draft does not reactivate or delete the original automatically. The confirmation flow must explain this before voiding. If the owner needs to abandon a replacement, the application provides an explicit resolution action rather than silently restoring history.

## 11. Pay Periods and Payslips

### 11.1 Pay period

A pay period contains:

- UUID;
- employment ID;
- inclusive local start and end dates;
- optional owner label;
- `open` or `reviewed` state;
- creation and update timestamps;
- revision.

Invariants:

- end cannot precede start;
- periods for one employment may not overlap;
- a period contains finalized, non-void shifts whose captured local start dates fall in its range;
- changing a period boundary requires a revision match and must not create overlap;
- `reviewed` records remain reopenable because review is an owner workflow state, not immutable evidence.

The first release does not infer cadence or automatically create future periods.

### 11.2 Payslip

A payslip contains:

- UUID;
- pay-period ID;
- issued local date;
- optional paid local date;
- EUR amount in integer cents;
- rate basis (`gross` or `net`);
- optional supplementary gross, net, and deduction amounts in integer cents;
- optional factual reference and note;
- effective or void state;
- optional void reason;
- optional replacement and replaced payslip IDs;
- creation and update timestamps;
- revision.

The primary amount is the evidence used in reconciliation. Supplementary fields are descriptive evidence and must not become an implicit tax calculation.

Multiple effective payslips may belong to one period. A payslip correction uses void-and-replace. Void payslips remain inspectable and are excluded from active paid totals.

## 12. Reconciliation

Reconciliation is a non-persisted projection grouped by:

- employment;
- pay period;
- currency;
- rate basis.

For each compatible group it exposes:

- regular paid duration;
- overtime paid duration;
- expected amount;
- effective payslip amount;
- signed difference (`paid - expected`);
- count and identity of contributing shifts and payslips;
- status and explanation.

Statuses include:

- `balanced`: expected and paid match after named rounding;
- `difference`: compatible totals differ;
- `missingPayslip`: expected amount exists without paid evidence;
- `unmatchedPayslip`: paid evidence exists without compatible expected work;
- `mixedBasis`: gross and net evidence exist but cannot be combined;
- `unavailable`: required facts or valid agreement resolution are absent;
- `empty`: neither expected work nor effective payslip evidence exists.

Gross and net values are never combined. Distinct currencies are never combined. A mixed period displays separate subtotals and the reason no single difference exists.

The UI must label expected compensation as an estimate under recorded agreements, not as payroll certainty or a tax report.

## 13. Concurrency and Mutation Outcomes

Every mutable root record carries an integer revision. Mutations accept the expected revision and use a conditional update. A zero-row update is a stale conflict and must not overwrite the newer record.

Application services return typed outcomes:

- committed success;
- validation failure with field-safe errors;
- stale conflict;
- not found;
- unavailable;
- uncertain commit outcome.

The UI preserves the register, selection, and owner draft when validation or stale-conflict outcomes occur. It offers reload/review rather than automatic retry for non-idempotent mutations.

Database exception text, SQL, values, notes, labels, amounts, and paths must not enter logs or user-visible diagnostics.

## 14. Navigation and Safe State Restoration

GoRouter owns only safe structural state:

- active surface;
- selected employment ID;
- selected pay-period ID or date scope;
- selected record ID;
- inspector mode when it contains no draft content.

Routes must not contain personal names, notes, amounts, timestamps beyond explicit non-sensitive temporal scope, or serialized records.

Invalid IDs and malformed dates produce explicit unavailable or invalid-scope states. They never silently choose another record or replace the requested date with today.

Draft values remain in memory. Application preferences may store only:

- theme;
- density;
- rail state;
- inspector/splitter width;
- safe last-surface information.

Preferences must not contain Work records, notes, amounts, timer state, export paths, or database content. Active shift truth always comes from SQLite.

## 15. Native Workbench Design

### 15.1 Visual direction

The approved composition is a continuous orchestrated workspace informed by a restrained metrology bench: precise, humane, quiet, and materially flat. It is not a themed instrument panel.

The design uses:

- a compact fixed system rail;
- one central dense register;
- one stable adjacent inspector;
- neutral working surfaces;
- restrained blue selection and orange warning accents;
- tabular numerals for time and money;
- clear named states rather than decorative color;
- thin separators and measured spacing;
- no generic SaaS card field, KPI tile row, dashboard grid, gradients, glow, or decorative chart.

The visual system must be implemented as LifeOS-owned Flutter components. Material widgets may provide behavior and accessibility but must not leave the product looking like a stock Material application.

### 15.2 System rail

The rail contains visible icon-and-text destinations for:

- Today;
- Work;
- Money;
- Habits;
- Backup and Export or Settings.

Only Work is fully operational in this slice. Unimplemented destinations must be honest, stable unavailable states—not fake data, dead controls, or legacy web launches.

### 15.3 Work register

The central register contains:

- employment control;
- pay-period or date-range control;
- status filters;
- compact expected/paid/difference summary;
- dense tabular shift or period rows;
- clear primary action appropriate to context;
- contained horizontal scrolling when necessary.

Rows use intentional column widths and tabular figures. Single click selects. Keyboard navigation moves focus independently from selection; Enter selects. Double click may enter edit mode only for mutable drafts.

The register remains mounted and visually stable while the inspector changes state.

### 15.4 Inspector

Inspector modes are:

- no selection;
- inspect;
- create;
- edit draft;
- running shift;
- on-break shift;
- validation failure;
- stale conflict;
- void-and-replace confirmation;
- unavailable;
- uncertain outcome.

Actions remain adjacent to the record they affect. Destructive confirmations identify the exact synthetic or owner-facing record and explain historical consequences without using generic “Are you sure?” copy.

### 15.5 Window and constrained width

Initial target minimum is `1280 × 760` logical pixels. The workbench compresses spacing and nonessential columns before changing topology.

At constrained widths, the inspector becomes a sequential pane with:

- an explicit “Back to register” action;
- preserved scope and selection;
- stable draft state;
- no modal maze or card-grid fallback.

No page body may overflow horizontally. Only an intentionally contained table region may scroll horizontally.

### 15.6 Accessibility

- Every icon action has a persistent visible text label unless the platform convention makes the meaning unambiguous and an accessible label is still supplied.
- Keyboard focus is visible and distinct from selection.
- State and validation changes are announced semantically.
- Color is never the only state signal.
- Controls meet desktop target-size requirements without becoming oversized tablet controls.
- Text scaling and high-contrast themes must preserve operation.
- Reduced-motion settings disable nonessential transitions.

## 16. Work Flows

### 16.1 First-run Work setup

1. The empty Work register explains that an employment and agreement are required before recording paid work.
2. The owner creates an employment in the inspector.
3. The owner creates its first effective pay agreement.
4. After commit, the register remains in the employment scope and exposes start-shift and manual-entry actions.

No sample personal-looking data is inserted.

### 16.2 Live shift

1. The owner selects an active employment and starts a shift.
2. LifeOS records UTC start, captured timezone, local start date, and `running` state transactionally.
3. The owner may start and end one break at a time.
4. The owner ends the shift.
5. LifeOS presents paid duration and the threshold-derived overtime suggestion.
6. The owner confirms or changes overtime minutes.
7. Finalization resolves and persists the agreement version.
8. After commit, the finalized shift remains selected and expected compensation appears as a derivation.

Closing and reopening the app must recover the active shift from SQLite without relying on preferences or an in-memory timer.

### 16.3 Manual shift

The owner creates a draft with start, end, timezone, breaks, employment, overtime minutes, and optional note. Validation remains adjacent. Saving a valid draft finalizes it through the same domain service used by the live workflow.

### 16.4 Pay-period review

1. The owner creates or selects an explicit period.
2. The register shows contributing finalized shifts and expected subtotals by basis.
3. The owner records one or more payslips.
4. Reconciliation refreshes after commit.
5. The inspector explains a difference, mismatch, or missing evidence using the contributing facts.
6. The owner may mark the period reviewed without freezing the underlying evidence.

### 16.5 Historical correction

1. The owner selects a finalized shift or effective payslip.
2. The inspector enters correction confirmation and explains void-and-replace.
3. After confirmation, the transaction voids the original and creates a linked replacement draft.
4. The replacement remains selected for editing.
5. Totals exclude the void original and include the replacement only after finalization.

## 17. Backup, Export, and Restore Boundary

### 17.1 Manual SQLite backup

Backup is owner-initiated from the system surface:

1. request an explicit destination through the native file selector;
2. serialize backup work through the database service;
3. create a consistent SQLite snapshot in an application-controlled temporary location;
4. reopen the snapshot read-only;
5. validate database identity and run an integrity check;
6. write or atomically replace the selected destination only after validation;
7. include application version, schema version, and creation timestamp in backup metadata or a sidecar manifest;
8. report completion without exposing content.

Copying the live `.sqlite` file while WAL may contain committed data is forbidden.

### 17.2 Work JSON export

Export is separate from backup. It uses a versioned top-level schema and includes:

- employments;
- agreement versions;
- shifts and breaks;
- pay periods;
- payslips;
- void/replacement relationships;
- the factual fields needed to independently reproduce reconciliation.

Derived reconciliation results may be included as clearly labeled convenience output but are not authoritative. Export is labeled as a data export, not a payslip, tax report, or payroll statement.

### 17.3 Restore

Interactive restore is outside the first implementation slice. The backup format must still preserve identity and compatibility metadata needed for a later launch-time maintenance flow. No arbitrary SQLite restore, Django import, automatic merge, or in-app hot swap is permitted.

Backups and exports are plaintext owner-controlled files. The UI must not imply encryption or safe off-device retention.

## 18. Privacy and Diagnostics

Permitted diagnostics contain only bounded operational categories such as:

- subsystem name;
- operation name;
- safe outcome code;
- exception class;
- application and schema versions.

Diagnostics must exclude:

- record content;
- notes and labels;
- employer names;
- dates, times, and durations tied to records;
- money and rate values;
- IDs when not essential;
- SQL and bound parameters;
- database, backup, and export paths;
- raw exceptions that may contain any of the above.

There is no automatic crash-report upload. Debug builds must follow the same personal-content restrictions.

## 19. Testing Strategy

### 19.1 Pure domain tests

Cover:

- integer and rational expected-pay arithmetic;
- half-up rounding boundaries;
- agreement effective-date selection;
- agreement range overlap;
- gross/net mismatch;
- overtime limits and threshold suggestion;
- break overlap and boundary validation;
- overnight shifts;
- daylight-saving gaps and folds;
- cross-midnight start-date attribution;
- void-and-replace history;
- reconciliation grouping and statuses.

### 19.2 Database and repository tests

Cover:

- application-ID creation and rejection;
- required PRAGMAs;
- constraints and foreign-key behavior;
- one-active-shift rule;
- atomic shift, break, finalization, and correction transactions;
- stale revision rejection;
- uncertain outcome mapping where it can be simulated;
- migration from every released schema snapshot;
- schema checksum/identity behavior;
- guarded temporary database resolution;
- backup integrity;
- export schema validation.

### 19.3 Widget tests

Cover:

- rail/register/inspector geometry;
- pointer selection;
- keyboard focus and selection;
- preserved register while inspector changes;
- inspector modes and validation;
- active shift recovery state;
- conflict and uncertain-outcome guidance;
- constrained-width return flow;
- table overflow containment;
- semantic labels and announcements;
- light, dark, high-contrast, text-scale, and reduced-motion behavior where practical.

### 19.4 Linux integration tests

Use an explicitly owned disposable application-data directory and synthetic records to cover:

1. launch and fresh schema creation;
2. employment and agreement setup;
3. start shift, start/end break, end, and finalize;
4. application restart with an active shift;
5. pay-period creation;
6. payslip recording;
7. balanced and differing reconciliation;
8. correction through void-and-replace;
9. route and selection restoration;
10. backup and export through fake destination-picker adapters;
11. release-bundle startup.

Flutter integration tests cannot reliably automate the native GTK chooser. A documented manual Linux release check must verify the real backup/export dialogs.

### 19.5 Visual verification

Impeccable verification is bounded:

1. build the complete target surface;
2. capture the supported Linux viewport/theme/state matrix in one batch;
3. run one independent finish review;
4. apply all material findings in one batch;
5. perform at most one confirmation capture round;
6. stop polishing and document the shipped design.

Captures use synthetic data only. The finished implementation updates `DESIGN.md`, `.impeccable/design.json`, and the native Work surface brief from shipped code rather than intentions.

## 20. Packaging and Distribution

The first supported platform is Fedora-compatible Linux.

Required outputs:

- `flutter build linux --release` bundle;
- RPM package;
- `.desktop` entry;
- application icon assets;
- AppStream metadata;
- checksums for distributed artifacts.

Application ID: `io.lifeos.LifeOS`.

Packaging must not request a network permission or install a background service. The release process includes:

- a smoke test in a clean Fedora-compatible environment;
- `ldd` review of the executable and bundled libraries;
- startup against a disposable database;
- manual GTK file-dialog verification.

A Debian package may be generated from the same packaging configuration after the Fedora path is proven. Flatpak and Snap are deferred until their sandbox and portal effects on backup and export have a separate design and test pass.

## 21. Repository and Tooling Direction

The Flutter project becomes the repository’s active application. A representative structure is:

```text
lib/
  main.dart
  bootstrap.dart
  app/
  core/
    database/
    files/
    privacy/
    time/
  features/
    work/
      domain/
      application/
      data/
      presentation/
  shared/
    workbench/
test/
integration_test/
tool/
packaging/
```

The implementation plan must assign one clear responsibility to each file and avoid oversized generic service files.

The repository pins the Flutter SDK and package lockfile. Code generation is deterministic and verified in automation.

`app.sh` becomes the supported entry point for repository operation. By completion it must provide, at minimum:

- dependency/bootstrap validation;
- formatting and static analysis;
- code-generation drift checks;
- unit and widget tests;
- Linux integration verification on disposable storage;
- release build;
- native start.

After implementation, `./app.sh` must be exercised to confirm it still starts and tests the application. The old launcher behavior may not silently start Django once the native cutover is complete.

## 22. Acceptance Criteria

The Foundation + Work slice is complete only when:

1. LifeOS launches as a native Linux Flutter application with no Django, Node, browser, or local HTTP process.
2. Runtime data is created only in the native application-support location with verified database identity.
3. The existing Django database remains untouched and undiscovered.
4. An owner can create multiple employments and non-overlapping versioned pay agreements.
5. Live and manual shifts support start/end instants, unpaid breaks, overtime confirmation, overnight duration, and DST-safe elapsed time.
6. Finalized shifts retain their resolved agreement and cannot be destructively edited.
7. Explicit pay periods accept multiple payslips and produce compatible-basis reconciliation.
8. Facts, estimates, and payment evidence are visibly distinct.
9. Stale revisions cannot overwrite newer records.
10. Corrections preserve voided originals and linked replacements.
11. Manual backup creates and validates a consistent SQLite snapshot.
12. Work JSON export is versioned and reconstructs reconciliation-relevant facts.
13. No automated test or visual capture can resolve or use the production data location.
14. The rail/register/inspector workbench remains dense, mouse-first, keyboard-accessible, and usable at the supported constrained width.
15. Domain, database, widget, integration, packaging, and privacy tests pass.
16. The bounded Impeccable finish pass is complete and the shipped design is documented.
17. `./app.sh` successfully tests, builds, verifies, and starts the native application using safe storage controls.

## 23. Deferred Decisions

The following require later domain-specific design rather than speculative foundation work:

- Today composition across Work, Money, and Habits;
- Money’s account and transaction model;
- Habits recurrence and evidence model;
- non-EUR creation and currency conversion;
- salaried and freelance work;
- weekly or pay-period overtime;
- allowances and differentials;
- automatic backup scheduling;
- encryption and key management;
- cloud or device sync;
- cross-platform desktop/mobile targets;
- native restore UX;
- Flatpak and Snap packaging.

These omissions are intentional. The first slice establishes a durable native foundation and proves it through one complete, truthful domain rather than building generic infrastructure for hypothetical features.
