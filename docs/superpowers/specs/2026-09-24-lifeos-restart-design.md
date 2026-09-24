# LifeOS Restart

**Status:** Approved design awaiting written-spec review  
**Date:** 2026-09-24  
**Workspace:** `/home/aUser/lifeManager`  
**Implementation target:** Focused v1 built as a Django modular monolith

## 1. Purpose

LifeOS is restarting in this workspace rather than undergoing another rewrite of the existing application. The restart is product-first: it preserves the product identity, proven domain semantics, data-safety lessons, accessibility commitments, and Closing Ledger direction while reconsidering implementation from first principles.

The existing application at `/home/aUser/improvedCalendar` is historical evidence, not a template. Its source code and personal data are not copied. The restart must not inherit loaders, registries, protocols, abstractions, or framework choices merely because they already exist.

The immediate objective is a runnable, production-shaped foundation and empty Daily Register in `/home/aUser/lifeManager`. The same repository will contain a concise source-of-truth package under `docs/foundation/`. Later milestones add Work, Money, and Habits as complete vertical slices.

Success means:

- a clean checkout can install, migrate, test, and run with documented `uv` commands;
- the app is safe by default for one private user on one local computer;
- the Daily Register and domain boundaries support incremental vertical slices without speculative infrastructure;
- an AI build agent can understand and continue the project from this repository without consulting or copying the old source tree.

## 2. Settled direction

- This is a **product-first reset**, not a compatibility rewrite.
- The first release is a **focused v1**, not current feature parity.
- Focused v1 covers **Work Shifts, Money, and Habits**. Knowledge is deferred.
- The project starts with a fresh database and provides no legacy-data importer.
- The Closing Ledger concept, dashboard priorities, interaction quality, and accessibility are authoritative; the old implementation mechanics are not.
- The app is a local web application bound to loopback only.
- It uses a Django modular monolith, SQLite, Django templates and forms, handwritten CSS, and small optional vanilla JavaScript enhancements.
- Dependencies are managed with `uv`, one `pyproject.toml`, and a committed `uv.lock`.
- Domains are ordinary first-party Django apps, not runtime addons.
- The dashboard supports review plus a few quick actions.
- Lithuanian salary estimation remains a core Work capability.
- Habit completion occurs at most once per local calendar day.
- Long-term simplicity takes priority over UI novelty, extensibility infrastructure, and maximum delivery speed.
- Backup and restore are deferred beyond focused v1, although the architecture must not obstruct their later addition.
- There are no visual browser tests: no screenshot baselines, image snapshots, pixel comparisons, visual-regression service, or automated approval based on appearance.

## 3. Repository and documentation shape

The implementation lives directly in this repository:

```text
lifeManager/
├── manage.py
├── pyproject.toml
├── uv.lock
├── README.md
├── lifeos/
│   ├── settings.py
│   ├── test_settings.py
│   ├── urls.py
│   ├── wsgi.py
│   ├── core/
│   ├── work/
│   ├── money/
│   └── habits/
├── templates/
├── static/
├── tests/
└── docs/
    ├── foundation/
    │   ├── START-HERE.md
    │   ├── PRODUCT.md
    │   ├── V1-SCOPE.md
    │   ├── DOMAIN.md
    │   ├── DESIGN.md
    │   ├── ARCHITECTURE.md
    │   ├── ENGINEERING.md
    │   ├── LESSONS.md
    │   └── fixtures/
    │       ├── salary-cases.json
    │       └── habit-momentum-cases.json
    └── superpowers/
        ├── specs/
        └── plans/
```

The exact Django package layout may use conventional support files such as `asgi.py`, app configs, migrations, and template subdirectories. It must preserve the ownership boundaries in this design.

The root `README.md` gives setup and operation commands and directs build agents to `docs/foundation/START-HERE.md`.

### 3.1 Foundation document responsibilities

- `START-HERE.md` publishes the reading order, authority hierarchy, settled decisions, and vertical-slice workflow.
- `PRODUCT.md` is the technology-neutral product north star.
- `V1-SCOPE.md` defines required workflows, completion criteria, and explicit deferrals.
- `DOMAIN.md` is the normative, technology-neutral specification for records, validation, calculations, ordering, deletion, and error concepts.
- `DESIGN.md` is the sole visual and interaction authority.
- `ARCHITECTURE.md` records how the application realizes product and domain requirements.
- `ENGINEERING.md` defines implementation, dependency, data-safety, and verification practices.
- `LESSONS.md` records historical evidence and rejected mechanics; it is contextual, not normative.
- Portable JSON fixtures contain implementation-independent salary and Habit momentum examples.

### 3.2 Authority hierarchy

When foundation documents conflict, the following order applies:

1. `PRODUCT.md` — why the product exists.
2. `V1-SCOPE.md` — what must and must not be built now.
3. `DOMAIN.md` and fixtures — what records and calculations mean.
4. `DESIGN.md` — how the product behaves and presents itself.
5. `ARCHITECTURE.md` — how the system realizes those requirements.
6. `ENGINEERING.md` — how it is developed and verified.
7. `LESSONS.md` — context only.
8. Historical documents and code in the old application — evidence only.

`START-HERE.md` publishes this order but does not override it. Each requirement has one normative home; other documents link rather than restate it.

## 4. Product design

### 4.1 Purpose and recurring loop

LifeOS is a private personal reconciliation system for sustaining accurate records and useful daily review across work, money, and habits. It is not a collaboration platform, generic productivity suite, finance-only tool, quantified-self game, or customizable dashboard builder.

Focused v1 supports one recurring loop:

1. capture a Work, Money, or Habit record;
2. review current daily and monthly state;
3. perform the next useful action;
4. reconcile what is recorded, incomplete, or unavailable.

The Daily Register is the starting surface. Domain registers own history, filtering, correction, and configuration.

### 4.2 Daily Register

One request reads the canonical local date once through an injectable clock and uses that date for every summary.

#### Work register

For the current calendar month, show total worked hours, overtime hours, estimated net salary, shift count, and the nearest recorded shift. Label the nearest record `Next shift` when it is today or later and `Last shift` when it is earlier. Minimum absolute date distance wins; a future date wins an exact tie. Provide explicit empty and unavailable states. The quick action opens a new-shift form and may prefill today without creating data.

#### Money register

For the current calendar month, show income, expenses, balance, leading expense category and amount, transaction count, and explicit empty or unavailable states. Order leading-category ties by case-insensitive category name and then raw category name. The quick action opens a new-transaction form. The register contains no decorative chart.

#### Habits register

Show every active Habit, incomplete today before completed today. Within each group, sort by case-insensitive title, raw title, and stable identifier. Show weekly count and target, seven-segment weekly progress, momentum, and a record-specific completion form for incomplete Habits. A completed Habit shows `Completed today`. Completion uses an ordinary form and redirects to the Habit anchor on the dashboard.

#### Failure isolation

One register's expected calculation or data-access failure must not suppress the others. The affected register becomes a safe unavailable state with recovery navigation. It never exposes exception details or personal record content.

## 5. Domain design

### 5.1 Shared rules

- Civil dates and UTC instants are separate concepts.
- A request obtains `today` exactly once through an injectable clock.
- Currency uses an exact representation; binary floating point is prohibited for stored or calculated money.
- User-entered values survive validation failures as entered.
- Multi-write business operations commit entirely or not at all.
- Success feedback appears only after commit.
- Duplicate-sensitive mutations are idempotent through a domain constraint or an explicit per-mutation mechanism.
- Deterministic tie-breakers are explicit rather than inherited from database row order.
- User content is escaped by default.
- Errors never expose SQL, filesystem paths, tracebacks, secrets, or record values.
- The app starts from a new empty database and imports no old IDs or records.

### 5.2 Work Shifts

A Work Shift records:

- local calendar date;
- worked hours;
- overtime hours;
- hourly rate;
- shift type: normal, night, or holiday;
- optional note.

Validation rules:

- worked hours are greater than zero and no more than 24;
- overtime is between zero and 24 inclusive;
- hourly rate is between zero and €10,000 inclusive;
- shift type is descriptive and does not change pay.

The Work register supports create, review, edit, delete, date filtering, shift-type filtering, and deterministic sorting.

#### Salary estimate

The simplified Lithuanian salary estimate uses these versioned rules:

- selected records use their unweighted mean hourly rate;
- normal hours are `max(total worked hours - overtime hours, 0)`;
- overtime uses a 1.5 multiplier;
- GPM is 20%;
- VSD is 12.52%;
- PSD is 6.98%;
- intermediate calculations retain full precision;
- results round only at the documented output boundary.

The UI labels the result as an estimate, explains deductions in English, and exposes the assumptions' version or effective basis. A tax-rule change requires an explicit domain change and new fixtures; historical results must not change silently.

### 5.3 Money

A Money transaction records:

- local calendar date;
- type: income or expense;
- positive amount;
- category;
- optional description.

Rules:

- amount is stored as integer euro cents;
- accepted range is €0.01 through €999,999,999.99;
- signs, exponents, excess precision, non-finite values, ambiguous values, and unsupported separators are rejected;
- category is required and contains 1–80 characters;
- description is optional and contains at most 500 characters;
- whitespace-only optional text becomes absent.

The Money register supports create, review, edit, delete, date/type/category filtering, and deterministic sorting. Accounts, transfers, budgets, multiple currencies, recurring transactions, and bank import are excluded from v1.

### 5.4 Habits

A Habit records a title, weekly target from one through seven days, active state, and creation timestamp. A completion records Habit identity, one local completion date, and one UTC audit timestamp.

The database enforces uniqueness for `(habit, local completion date)`. Repeating a completion request for an already completed date returns the canonical already-complete state without adding an event or increasing momentum.

A week runs Monday through Sunday. Each completed local date counts once. Text always shows exact count and target. The visual track has seven segments; text may exceed the target, but the track never renders more than seven completed days.

Momentum is derived from the ordered set of unique completion dates:

```text
next = round(previous × exp(-0.1 × elapsed_days) + 1, 2)
```

Direct derivation is required in v1. Cached or independently mutable momentum is prohibited until measurement and an explicit invalidation design justify it.

The Habit register supports creating and editing a Habit, completing it once per local day, removing an accidental completion made today, deactivating a Habit without deleting history, and reviewing weekly progress and momentum. Historical completion dates are not editable in focused v1. A Habit with completion history is not ordinarily hard-deleted.

## 6. Experience design

### 6.1 Closing Ledger thesis

LifeOS is where the day's records are reconciled. Each domain occupies a stable register. Values update in place, committed actions read as posted facts, and controls are decisive rather than decorative.

The rejected default is a neutral SaaS sidebar with interchangeable rounded cards, ornamental charts, and generic dashboard metrics.

### 6.2 Visual language

Use hard alignment, one-pixel rules, square or minimally clipped corners, stable registers, ruled sections, strong scale contrast, tabular figures, and fixed numeric positions. Use locally bundled Barlow for interface and user-authored text and JetBrains Mono for dates, amounts, durations, counts, identifiers, and system state.

Vermilion denotes consequential action; acid-lime denotes current or confirmed state; cyan, amber, and lime identify Work, Money, and Habits only as subordinate accents. Every color-coded state also has text or structure.

Prohibited patterns include gradients, glass effects, glow, fake paper, scanlines, ornamental charts, floating shadows, pill badges, excessive rounded containers, and decorative motion.

Final palette values are chosen during implementation and become tokens only after computed contrast validation.

### 6.3 Layout and interaction

Desktop uses a compact register-index rail, context strip, primary workspace, broad Daily Register layout, and focused domain pages. On narrow screens, navigation becomes a disclosed full-width tray, registers linearize in DOM and keyboard order, forms stack before controls become cramped, and tables use labeled horizontal overflow. Essential workflows must remain usable at 320px and at 200% browser zoom.

Complete server-rendered pages and ordinary forms are the baseline. Successful mutations use POST/Redirect/GET. Validation failures render raw entered values, field messages, and a linked error summary. Destructive actions use explicit wording and confirmation.

JavaScript may manage theme preference, navigation disclosure, focus assistance, and duplicate-click feedback. It must not calculate salary or momentum, invent committed state, or maintain authoritative persisted records. The app has no generalized partial-page update protocol.

Motion is short, functional, non-blocking, and never claims success before commit. There is no idle or looping animation. Reduced-motion preferences remove nonessential transitions while preserving labels and focus behavior.

## 7. Architecture

### 7.1 Selected stack and dependency policy

Focused v1 uses Python, Django, Django templates and forms, Django ORM and migrations, SQLite, handwritten tokenized CSS, small local vanilla JavaScript where justified, pytest-compatible tests, and locally bundled Barlow and JetBrains Mono assets.

`uv` manages one `pyproject.toml` and a committed lockfile. Runtime dependencies remain deliberately small. Development/test tooling and optional functional-browser tooling use separate dependency groups. A dependency is added only when an implemented requirement justifies it.

Django is selected to replace custom form, CSRF, migration, transaction, settings, template, and test-application machinery with mature conventional facilities. The goal is not maximum framework use; it is minimum application-specific infrastructure.

### 7.2 Module boundaries

- `core` owns composition, the Daily Register, shared UI, navigation, messages, and the clock boundary.
- `work`, `money`, and `habits` each own their models, migrations, calculations, forms, queries, views, templates, and tests.
- `core` calls explicit public query or service functions from each domain. It does not duplicate formulas, construct domain-specific SQL, or inspect model internals for convenience.
- Domain summary functions return immutable presentation values representing available data, a legitimate empty state, or a safe unavailable state.
- The first milestone implements stable empty-summary boundaries, not speculative domain tables or workflows.

The project has no runtime discovery, plugin loader, manifest DSL, dependency graph, generic repository layer, service container, event bus, frontend/backend split, separate API, SPA framework, client router, browser state store, message broker, background worker, or cache service.

### 7.3 Process, security, and database location

One Django process serves the app and binds to `127.0.0.1` by default. The OS account and local machine form the accepted user boundary; v1 has no account or login system. Django CSRF remains enabled. Allowed-host and trusted-origin policy rejects unexpected hosts and browser origins despite loopback binding.

The personal SQLite database defaults to:

```text
${XDG_DATA_HOME:-~/.local/share}/lifeos/lifeos.sqlite3
```

`LIFEOS_DATABASE_PATH` may explicitly override it. The application creates the containing user-data directory safely when needed. Personal data is outside the repository and ignored by Git regardless of overrides that point into the workspace.

Tests use `lifeos.test_settings`. The test harness allocates an explicit temporary root and database path before Django initializes. Test settings fail closed if that path is absent, outside the allocated test root, resolves to the personal database, or points at a non-test-owned existing file. No test command may discover or default to the personal database.

Django migrations are the only schema-history mechanism. Read paths do not mutate. Multi-write operations use explicit transaction boundaries. Domain constraints enforce invariants that must survive retries or concurrency. Startup failure never authorizes destructive repair or reset.

Any later LAN, remote, mobile, hosted, or multi-user access requires a new threat model and explicit authentication, authorization, session, transport-security, and deployment design.

### 7.4 Rendering, assets, and readiness

The server renders complete HTML. Forms use ordinary HTTP. Writes commit and redirect to canonical pages. Dashboard quick actions work without JavaScript. Handwritten CSS variables, layers, and component classes implement Closing Ledger; no CSS framework or compiler is required.

Fonts are bundled locally. A deterministic asset-copy or integrity command is allowed only if the chosen font workflow needs it. Generated stylesheets are not committed merely to preserve an unnecessary build step.

Milestone one provides a simple loopback readiness endpoint for startup checks. It performs no mutation, exposes no configuration or record content, and returns an unsuccessful status when required application or database initialization is unavailable.

## 8. Failure semantics and diagnostics

The application distinguishes four outcomes:

1. **Rejected before commit:** domain or form validation rejects the request; no state changes; entered values, actionable field errors, and a linked error summary render together.
2. **Operational failure before commit:** the transaction rolls back; recovery guidance is safe and entered values are retained where feasible.
3. **Committed successfully:** the transaction has committed; the app redirects to canonical state and then presents factual success feedback.
4. **Commit outcome uncertain to the browser:** the app does not claim definite failure and directs the user to inspect canonical state before retrying.

Expected dashboard summary failures become an unavailable state for only the affected register. Diagnostics may record the domain and exception class but never serialize personal field values. Unexpected programming errors remain visible in development and tests rather than being silently converted into ordinary unavailable states.

Habit completion is naturally idempotent through `(habit, local date)` uniqueness. Other duplicate-sensitive creations receive an explicit per-mutation decision. There is no universal idempotency abstraction without a concrete use case.

## 9. Accessibility requirements

WCAG 2.2 AA is a focused-v1 release requirement. The implementation must provide:

- complete keyboard operation;
- logical heading, reading, DOM, and focus order;
- visible and unobscured focus in both themes;
- no color-only meaning;
- normal-text contrast of at least 4.5:1;
- large-text, control-boundary, focus-indicator, and meaningful non-text contrast of at least 3:1;
- WCAG minimum target sizes with a 44px touch-layout aim;
- reduced-motion behavior;
- accessible error-summary navigation;
- accessible status and error announcements;
- tables usable without hover;
- correct focus containment and restoration if a dialog is later introduced;
- 320px reflow;
- actual 200% browser zoom support;
- support for the complete WCAG text-spacing override set.

Automated accessibility checks supplement rather than replace manual keyboard and screen-reader smoke checks. Verification reports must not present automated passes as manual evidence.

## 10. Delivery sequence

Implementation proceeds through complete vertical slices:

1. **Foundation and application shell** — repository, `uv`, Django configuration, data-safety boundary, injectable clock, empty Daily Register, shared Closing Ledger presentation, readiness endpoint, and foundation documents.
2. **Work** — shift persistence and CRUD, filtering, salary fixtures and calculation, summaries, dashboard integration, and tests.
3. **Money** — exact-cent input and persistence, CRUD, filtering, summaries, dashboard integration, and tests.
4. **Habits** — definitions, once-per-day completion, correction, deactivation, weekly progress, momentum fixtures and calculation, dashboard action, and tests.
5. **Integrated release hardening** — responsive CSS review, keyboard and accessibility verification, error-path checks, documentation reconciliation, and complete test gates without visual browser tests.

Each slice finishes domain behavior, UI, tests, and documentation before the next starts. Later slices receive separate implementation plans based on the application and documentation that then exist.

## 11. Milestone one: foundation and empty Daily Register

### 11.1 Deliverables

- Initialize Git and add focused ignore rules before generated or personal files appear.
- Create `pyproject.toml` and `uv.lock` with pinned Python/Django requirements and separated dependency groups.
- Create the Django project and the four first-party apps.
- Add explicit development and test settings.
- Configure XDG personal-data resolution, loopback hosts, CSRF origin policy, static files, templates, logging, and local time behavior.
- Add the injectable clock boundary.
- Build the shared shell: skip navigation, register-index navigation, compact context strip, Light and Dark themes, responsive navigation tray, visible focus, and status/message regions.
- Build the empty Daily Register with stable Work, Money, and Habits regions.
- Add stable domain summary interfaces returning legitimate empty states.
- Isolate expected register failures independently.
- Add the readiness endpoint.
- Create all initial source-of-truth documents and fixture schemas under `docs/foundation/`.
- Add automated tests for configuration, protected-data isolation, clock use, composition, routes, semantic rendering, and essential accessibility behavior.

### 11.2 Dashboard data flow

1. A request enters the `core` dashboard view.
2. The view asks the injected clock for the local date exactly once.
3. It invokes one public summary query from each domain.
4. Each query returns an immutable presentation value representing available data, a legitimate empty state, or a safe unavailable state.
5. An expected failure in one query is logged safely and converted into only that register's unavailable state.
6. The view creates one immutable dashboard presentation value.
7. The server renders the complete page.

Milestone one uses real empty-summary implementations, not template placeholders that later require a different composition path.

### 11.3 Explicit deferrals

Milestone one does not add domain database tables, Work/Money/Habit forms or mutations, salary or momentum calculations, final unvalidated palette tokens, deployment machinery, authentication, import, backup, remote access, background processes, or speculative interfaces for later slices.

Functional browser automation is optional in milestone one and is introduced only where it provides evidence not available from Django rendering and integration tests. If introduced, it may cover startup, keyboard behavior, navigation disclosure, theme switching, reduced-motion behavior, and automated accessibility smoke checks. It must not capture screenshots or perform visual comparison.

### 11.4 Acceptance criteria

Milestone one is complete when:

- a clean checkout can install, migrate, test, and launch using documented `uv` commands;
- the server defaults to `127.0.0.1`;
- the personal database defaults outside the source tree;
- tests demonstrably fail closed rather than touch personal data;
- the empty Daily Register uses the final composition boundaries and renders safe empty and unavailable states;
- the Closing Ledger shell works without JavaScript, while optional enhancements remain non-authoritative;
- foundation documents contain no unresolved placeholders, contradictory authority, or undocumented implementation decisions;
- automated verification passes and visual/manual gaps are reported rather than represented as tested;
- no old application code, generated assets, database, or personal records have been copied or altered.

## 12. Verification strategy

Each slice includes the smallest applicable set of:

- pure domain tests;
- fixture-driven calculation tests;
- form and validation tests;
- transaction and constraint tests;
- view, route, and rendering tests;
- functional browser tests only where they provide unique behavioral evidence;
- automated accessibility checks;
- explicit manual verification notes.

Milestone-one automated coverage includes:

- personal database path resolution and environment overrides;
- fail-closed test database setup and rejection of the personal path;
- loopback host, origin, and security settings;
- injectable clock behavior and one date read per dashboard request;
- ordered Work, Money, and Habits composition;
- legitimate empty and independently unavailable register states;
- semantic landmarks, heading order, skip link, labels, and status regions;
- readiness behavior;
- Django system checks, migration consistency, and static-file discovery.

Verification runs in this order:

1. focused unit tests;
2. affected Django integration and rendering tests;
3. the complete Python suite;
4. Django system and migration checks;
5. limited functional and accessibility browser checks, only if present;
6. honest reporting of failures, skips, warnings, approximations, unverified visual behavior, and manual gaps.

Fixed clocks cover month boundaries, week boundaries, leap years, year rollover, and local-date behavior when those domains are implemented.

Visual browser tests are prohibited. There are no screenshots as automated evidence, image snapshots, golden files, pixel-difference tests, browser capture rounds, or visual-regression services. CSS layout quality is protected through semantic rendering tests, deterministic token/contrast checks, responsive CSS review, and explicitly reported manual review.

## 13. Rejected complexity and deferred product scope

Focused v1 has no frontend/backend split, separate API, SPA framework, client router, generic repository layer, runtime plugin system, manifest DSL, dashboard factory contract, custom migration ledger, generalized fragment protocol, event bus, customizable dashboard, or premature backup subsystem.

Deferred product capabilities include Knowledge, remote access, authentication, cloud synchronization, legacy import, backup/restore product flows, financial accounts and budgets, bank import, reminders, notifications, analytics, customization, and gamification.

These exclusions do not weaken transactionality, exact money, clock control, CSRF protection, test isolation, accessibility, deterministic results, or server-authoritative calculations.

## 14. Foundation-document acceptance criteria

The initial foundation set is complete when:

- every requirement has one normative home;
- references replace duplicated rules;
- no unresolved `TBD`, `TODO`, placeholder, or open design question remains;
- deferred features are explicit;
- historical implementation mechanics appear only in `LESSONS.md`;
- domain rules have concrete examples;
- fixture schemas and expected values are documented;
- authority hierarchy is consistent everywhere;
- a new AI build agent can understand and continue the project from this repository alone;
- no document directs the agent to copy old source code;
- the documentation preserves Closing Ledger identity without preserving obsolete architecture.

## 15. Provenance and supersession

This design synthesizes enduring knowledge from the prior product documentation, the approved Closing Ledger direction, characterized domain code and tests for salary, exact money, Habits, dates, ordering, and validation, and verification evidence for accessibility, focus, responsive behavior, test isolation, and failure handling.

Those materials remain historical evidence only. This design and the resulting `docs/foundation/` package supersede them for the restart. Historical implementation plans and verification receipts are not current architecture and are not proof that checks have been completed in this repository.

## 16. Delivery boundary

After written-spec review and approval, this design authorizes a detailed implementation plan for milestone one and implementation of that plan directly in `/home/aUser/lifeManager`.

It authorizes Git initialization, foundation documentation, Django scaffolding, dependency locking, settings, test-safety infrastructure, shared presentation, the empty Daily Register, readiness behavior, and milestone-one tests.

It does not authorize implementation of the Work, Money, or Habits vertical slices without their later plans. It does not authorize copying old application code or assets, importing or altering current personal data, deleting or archiving the old application, enabling remote access, or selecting final palette tokens without contrast verification.
