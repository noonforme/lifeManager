# LifeOS Money Slice Design

**Date:** 2026-09-25  
**Status:** Approved design awaiting implementation plan

## 1. Purpose and authority

This design defines the second persisted LifeOS domain slice: Money. It adds a lean transaction ledger for recording income and expenses, reviewing a selected month, deriving exact monthly movement, correcting records, and exposing a truthful Money summary in the Daily Register.

The maintained foundation package under `docs/foundation/` remains authoritative. If this document conflicts with that hierarchy, the foundation document with the higher authority wins. This design resolves the practical Money details intentionally left open by the foundation documents and incorporates the approved decisions for this slice.

The Money ledger is an independent `lifeos.money` domain. It is not an extension of Work salary, payroll, banking, accounting, or a generic finance framework. Work may display estimated salary, but it never creates Money transactions, and Money never imports Work models or derives transactions from shifts.

The slice must preserve these constraints:

- SQLite remains the single source of truth.
- Personal data remains outside the repository.
- Tests use explicitly owned disposable databases and never resolve, create, inspect, migrate, or reuse the personal database location.
- The interface is server-rendered Django over ordinary HTTP.
- Core workflows work without JavaScript.
- User content is escaped and treated as plain text.
- Logs and responses do not disclose transaction dates, categories, notes, amounts, database paths, SQL, exception text, or other personal record content.
- No historical application source code or personal data is accessed, copied, imported, or treated as authority. In particular, `/home/aUser/improvedCalendar` remains historical evidence only and is not consulted during implementation.
- No visual browser tests, screenshots, snapshots, golden images, pixel comparison, capture rounds, or visual-regression services are introduced.
- Habits remains a legitimate empty summary; its persisted workflow is outside this slice.

## 2. User outcome and scope

After this slice, the owner can:

1. Open the Money register for the current or another selected month.
2. Create an income or expense transaction with a date, positive euro amount, category, and optional note.
3. Review a canonical page for that transaction.
4. Edit an incorrect transaction.
5. Delete an incorrect transaction after an explicit confirmation step.
6. Reconcile the selected month through transaction count, inflow, outflow, and net movement.
7. Return to the Daily Register and see a populated current-month Money summary without affecting Work or Habits.

This workflow is a private, factual transaction ledger. It does not claim to be double-entry accounting, a bank statement, a tax record, a budget, an account balance, a financial forecast, or financial advice.

## 3. Domain record

### 3.1 Transaction

A `Transaction` owns:

- a stable identifier;
- `transaction_date`, a required local calendar date;
- `direction`, exactly `income` or `expense`;
- `amount`, a positive exact decimal euro amount stored to two decimal places;
- `category`, required trimmed plain text;
- `note`, optional trimmed plain text;
- timezone-aware `created_at` and `updated_at` timestamps.

The record stores an unsigned positive amount. Direction supplies its financial meaning; expense amounts are not stored as negative values. No monthly count, inflow, outflow, net movement, category aggregate, account balance, or other summary is stored on the record.

### 3.2 Validation and normalization

The model and form enforce the same rules:

- `transaction_date` is required and accepts a valid local calendar date.
- Future transaction dates are allowed.
- `direction` must be one of `income` or `expense`.
- `amount` uses `Decimal`, has exactly the currency's two-place storage precision, and accepts at most two decimal places.
- `amount` is at least `€0.01` and at most `€999,999,999.99`, inclusive.
- A zero, negative, signed-negative, exponent, non-finite value, excess precision, ambiguous value, unsupported separator, or otherwise invalid decimal input is rejected rather than coerced.
- `category` is required trimmed plain text from 1 through 80 characters after trimming.
- A missing or whitespace-only category is invalid.
- `note` is trimmed plain text with a maximum length of 500 characters after trimming.
- A missing or whitespace-only note is stored as the empty string.
- Identical transactions are allowed. The slice introduces no uniqueness constraint, implicit duplicate suppression, or generalized idempotency mechanism for transaction creation.

Form and model validation provide useful field-level errors before a database constraint can fail. Database check constraints independently enforce `amount >= 0.01` and `amount <= 999999999.99`. The schema's `DecimalField` precision enforces two-place storage and the approved maximum. Unknown records return HTTP 404 rather than creating replacements.

### 3.3 Ordering and deletion

Transaction histories order records by:

1. transaction date descending;
2. creation timestamp descending;
3. stable identifier descending.

Deletion is a confirmed hard delete. The confirmation page identifies the transaction safely by date, direction, and category and does not put its note in confirmation prose. This slice does not introduce soft deletion or an audit-log subsystem. Removing a transaction immediately removes it from every derived result.

## 4. Monthly calculations and display

### 4.1 Calculation semantics

For the selected calendar month:

- `count` is the number of included transactions;
- `inflow` is the sum of amounts whose direction is `income`;
- `outflow` is the sum of amounts whose direction is `expense`;
- `net_movement = inflow - outflow`.

Income and expense amounts remain positive within their separate sums. An empty month has count `0` and monetary outputs `0.00`. Net movement may be positive, zero, or negative.

All monetary arithmetic uses `Decimal`; binary floating point is prohibited. Intermediate sums remain exact. Each named monetary output—`inflow`, `outflow`, and `net_movement`—is independently quantized to two decimal places with `ROUND_HALF_UP`. The calculation API returns an immutable Money-owned result with the exact semantic fields. Views, templates, and Core do not recalculate totals.

Aggregates are always derived from the selected transaction snapshot and are never persisted. Editing or deleting a transaction changes the next derivation immediately.

### 4.2 Presentation

Every displayed monetary value uses the euro symbol and exactly two decimal places. Negative net movement uses an explicit minus sign, for example `−€12.34` or `-€12.34` according to the established formatter; it must never be represented by colour alone or by parentheses without a textual sign. Zero and positive values remain unambiguous. Direction is always written as text (`Income` or `Expense`); colour may reinforce it but cannot be the sole indicator.

No calculation in this slice ranks categories or derives a leading category. Category is a transaction attribute shown for reconciliation, not a separate model or aggregate.

## 5. Month and query semantics

The Money register defaults to the month containing the canonical local date from the core clock boundary. A `month=YYYY-MM` query parameter selects another calendar month.

The parser accepts only the exact four-digit-year, two-digit-month representation with a valid month from `01` through `12`. It accepts only years for which the selected month, its first day, the next-month exclusive boundary, and visible previous/next navigation can all be constructed. The navigable range is therefore years `0002` through `9998`, matching the existing safe month boundary convention.

An absent month parameter selects the canonical current month without error. An invalid, malformed, or unnavigable value does not raise and does not silently query an unintended range: the page displays the canonical current month and a visible generic form-level error, **Enter a month in YYYY-MM format.** The error does not echo the supplied value.

Month boundaries are half-open: `transaction_date >= first day of selected month` and `transaction_date < first day of next month`. This handles month lengths, leap-year February, and December rollover without timestamp assumptions.

The selected-month page includes previous- and next-month links. At the approved navigable bounds, links must remain valid and must not construct year zero or year 10000; because accepted selected years are `0002` through `9998`, both adjacent links are always constructible.

Money-owned query functions provide exact month parsing, boundaries, and deterministically ordered transactions for a selected month. The register materializes that query once and derives both the table and all totals from the same immutable request snapshot.

## 6. Routes and HTTP behavior

The Money app owns these routes and names:

| Method | Path | Name | Purpose |
| --- | --- | --- | --- |
| GET | `/money/` | `money:register` | Current or selected monthly register |
| GET, POST | `/money/transactions/new/` | `money:transaction-create` | Create a transaction |
| GET | `/money/transactions/<int:pk>/` | `money:transaction-detail` | Canonical transaction review |
| GET, POST | `/money/transactions/<int:pk>/edit/` | `money:transaction-edit` | Edit a transaction |
| GET, POST | `/money/transactions/<int:pk>/delete/` | `money:transaction-delete` | Confirm and delete a transaction |

The canonical detail view is explicitly GET-only and returns HTTP 405 for unsupported methods. The register is GET-only. Create, edit, and delete accept only GET and POST. GET renders a form, record, or confirmation and never mutates state. POST is the only method that mutates state. Django CSRF protection remains active.

### 6.1 Create and edit

Successful create and edit operations:

1. validate through the form and model;
2. perform exactly one model save inside one explicit `transaction.atomic()` boundary;
3. allow the atomic block to commit;
4. add a factual success message only after successful commit;
5. redirect to `money:transaction-detail` for the saved record.

Invalid forms commit nothing, preserve safe submitted values for correction, and add no success message. Identical valid submissions create distinct records by design.

The create route accepts an optional exact `date=YYYY-MM-DD` query parameter solely to prefill `transaction_date`. The parser requires an exact zero-padded ISO local date and a real calendar date. Invalid, malformed, or absent values leave the date field unprefilled without showing an error. Future exact dates may prefill because future transactions are valid. Opening the route never creates a record.

### 6.2 Delete

GET renders a distinct confirmation page. A valid POST performs one hard delete inside one explicit `transaction.atomic()` boundary. Only after commit does it add `Transaction deleted.` and redirect to `money:register` with `?month=YYYY-MM` for the deleted transaction's month. The selected month is captured before deletion. A failed delete does not claim success and re-renders safe recovery guidance where possible.

## 7. Money register and record presentation

The Money register extends the existing Closing Ledger shell and contains:

- one page heading and selected-month label;
- previous- and next-month navigation;
- a clear **New transaction** action;
- visible generic invalid-month feedback when applicable;
- transaction count;
- inflow;
- outflow;
- net movement;
- a deterministic transaction table with exactly the reconciliation columns date, direction, category, and amount;
- links from each row to its canonical review page;
- an honest empty state when the selected month has no transactions.

The register does not display notes. Notes appear only on the canonical detail page and edit form. The detail page presents date, direction, category, amount, and note, with the note omitted or explicitly described as absent when empty. User text renders as escaped plain text and preserves no trusted markup.

The list does not include charts, category rankings, leading-category callouts, search, filters, arbitrary date ranges, or pagination. A selected calendar month is the complete version-one reconciliation boundary for this slice.

Dates, amounts, counts, and calculated values use the established tabular mono treatment. Direction and category remain readable text. Expense presentation must not imply that the stored amount is negative; the direction label supplies meaning.

## 8. Forms, accessibility, and feedback

Forms use visible labels, native date/select/decimal/text controls, and one clear save action. Amount guidance states that the value is a positive euro amount with at most two decimal places and gives the accepted range. Hints precede field errors. Invalid fields are programmatically associated with their messages. When more than one error is present, a concise linked error summary appears before the fields. Safe submitted values remain visible for correction.

Create and edit have one clear save action. Delete has a distinct confirmation page and explicit destructive wording. No destructive action is performed through a link or GET request.

All Money pages reuse the existing semantic shell, skip link, permanent status and alert regions, theme behavior, focus treatment, and responsive foundation. Requirements include:

- logical headings and exactly one main region;
- programmatic labels and descriptions;
- linked error-summary navigation when multiple fields fail;
- visible state and direction text independent of colour;
- at least 44-by-44 CSS-pixel interactive targets;
- keyboard-operable month navigation and actions;
- an explicitly labelled horizontal scroll region only if the transaction table cannot reflow;
- no page-level horizontal scrolling;
- source order matching visual order;
- no JavaScript dependency for navigation, authoritative validation, calculations, or mutation;
- locally bundled assets only, with no remote runtime dependency.

Success messages state only what happened: `Transaction created.`, `Transaction updated.`, or `Transaction deleted.` They do not include a date, category, amount, direction, note, identifier, or other personal value.

## 9. Error, transaction, and privacy behavior

### 9.1 Controlled database failures

Expected `DatabaseError` failures are handled at every database boundary introduced by this slice, including:

- register and summary lookup/materialization;
- detail, edit, and delete lookup;
- model/form constraint validation when validation performs database access;
- create and edit save;
- delete;
- exit from the atomic block when commit itself fails.

Handling must wrap the whole database-bearing operation, including `form.is_valid()` where model validation can query constraints and the full `with transaction.atomic():` statement so an exception raised on atomic exit is caught. One broad application-wide exception handler is not introduced.

A controlled lookup failure returns a Money-owned unavailable response with HTTP 503 rather than a false 404. A real missing primary key returns HTTP 404. A register query failure returns the safe Money unavailable page with HTTP 503. A create or edit validation/save/commit failure adds a non-field error—**The transaction could not be saved. Please try again.**—retains safe submitted form values where feasible, commits nothing, and sends no success message. A delete/commit failure re-renders the confirmation page with **The transaction could not be deleted. Please try again.**, preserves enough in-memory identity for safe action rendering, and sends no success message.

A failure after a commit whose outcome cannot be established must not claim definite failure or encourage blind duplicate submission. It directs the owner to inspect the canonical Money register before retrying. Under normal Django atomic semantics, successful return from the outer atomic block is the boundary after which success feedback and redirect are produced.

Only `DatabaseError` and the established expected summary wrapper are converted to controlled operational outcomes. Unexpected programming exceptions propagate in development and tests; they are not converted into plausible empty data, validation errors, 404s, or unavailable summaries.

### 9.2 Logging and response privacy

Controlled operational failures log only fixed operation, domain, and exception-class metadata, for example the equivalent of `Money transaction create failed (OperationalError)`. Logs must not serialize exception text or arguments. They also exclude transaction dates, directions, categories, notes, amounts, identifiers tied to a record, request bodies, query-string values, SQL, database paths, CSRF tokens, and tracebacks at the controlled warning site.

Templates escape category and note content by default and never mark it safe. Error responses expose no SQL, filesystem path, traceback, settings value, exception text, or personal record content beyond safe form values intentionally returned to the owner for correction.

## 10. Daily Register integration

For the canonical date's calendar month, `lifeos.money.summary.get_summary(today=...)` performs one Money-owned monthly query and materializes one transaction snapshot. Both the empty/ready decision and every displayed aggregate derive from that one snapshot.

The Money summary has these states:

- no transactions produces the existing honest empty Money summary;
- one or more transactions produces a ready summary;
- an expected `DatabaseError` becomes `SummaryUnavailable`, allowing Core to render only Money as unavailable while Work and Habits still render;
- unexpected exceptions propagate.

A ready summary provides exactly these immutable labelled values, in this order:

1. **Transactions** — transaction count;
2. **Inflow** — euro-formatted inflow;
3. **Outflow** — euro-formatted outflow;
4. **Net movement** — euro-formatted net movement with an explicit minus sign when negative.

The panel description remains factual and does not invent a balance or category ranking. The Money panel and primary navigation link to `money:register`. Its **New transaction** action links to `money:transaction-create?date=<canonical YYYY-MM-DD>`, using the exact canonical date already read by the Daily Register. Links appear only after their routes exist.

Core continues to read its clock exactly once and passes the same date to Work, Money, and Habits in deterministic order. Core may call Money's public summary function and generically render its immutable `RegisterSummary`, but Core never imports `Transaction`, constructs Money queries, or calculates Money totals.

Money failure remains isolated. It cannot suppress Work or Habits, and a Work or Habits failure cannot suppress Money.

## 11. Primary navigation semantics

This slice fixes the current-page semantics for all implemented top-level destinations rather than leaving `aria-current="page"` permanently on Daily Register.

- **Daily register** is a link and has `aria-current="page"` only on the root Daily Register route.
- **Work** is a link and has `aria-current="page"` on every route in the `work` URL namespace.
- **Money** becomes a link and has `aria-current="page"` on every route in the `money` URL namespace.
- A non-current link has no `aria-current` attribute.
- Habits remains non-interactive text until an implemented Habits route exists and never receives `aria-current` during this slice.
- Exactly one primary-navigation item is current on the Daily Register, Work, and Money pages.

The implementation derives this state from resolved route identity or namespace, not brittle path-prefix comparisons, and covers it with semantic response tests.

## 12. Architecture and components

The Money slice uses focused conventional Django modules:

- `models.py` owns the `Transaction` schema, direction choices, normalization, invariant validation, ordering, and database constraints.
- `calculations.py` owns pure Decimal monthly derivation, formatting-independent semantics, named `ROUND_HALF_UP` output boundaries, and immutable calculation results.
- `queries.py` owns safe month parsing, half-open month boundaries, deterministic monthly selection, and snapshot inputs.
- `forms.py` owns input widgets, normalization presentation, and user-facing validation.
- `views.py` owns HTTP method enforcement, orchestration, atomic mutation boundaries, controlled database-error recovery, messages, and redirects.
- `summary.py` adapts one Money-owned monthly snapshot and calculation result to Core's immutable presentation boundary.
- `urls.py` owns the `money` URL namespace.
- Money templates own monthly register, unavailable, detail, form, shared form fields, and delete-confirmation pages.
- A reviewed initial Money migration owns the new schema and named amount constraints.

The application settings install the Money migration-bearing app and the project URL configuration includes its namespace beneath `/money/`.

No repository layer, generic service framework, shared finance base model, cross-domain transaction type, category model, account abstraction, client-side application state, REST API, background queue, event bus, cache, addon registry, or aggregate table is introduced. Shared Core presentation remains generic; Money domain policy remains in Money.

## 13. Testing strategy

Implementation follows strict RED–GREEN–REFACTOR in complete increments. For every behavior, write the smallest test, run it and observe the intended failure for the intended reason, implement the smallest coherent production change, run the focused test to green, refactor only while green, run the affected Money/Core tests, and then run the complete suite. A test added after its implementation does not satisfy the RED requirement.

### 13.1 Model and migration

Tests cover:

- required valid local transaction dates and allowed future dates;
- exact `income` and `expense` choices and rejection of unknown directions;
- positive Decimal amounts at `0.01` and `999999999.99` boundaries;
- rejection below, above, zero, negative, excess-scale, exponent, non-finite, ambiguous, and unsupported-separator inputs as applicable to the form/model boundary;
- database lower and upper amount constraints through direct persistence attempts;
- two-place storage precision;
- category trimming, required-after-trim behavior, and 1/80-character boundaries;
- note trimming, blank-to-empty normalization, and 500-character boundary;
- timezone-aware creation and update timestamps;
- deterministic ordering by date, creation time, and primary key;
- identical transactions and multiple transactions on one date;
- reviewed migration application and migration-state consistency.

### 13.2 Calculations

Pure tests cover:

- empty inputs;
- income-only, expense-only, and mixed months;
- count, inflow, outflow, and positive/zero/negative net movement;
- exact `Decimal` arithmetic with no binary float;
- independent `ROUND_HALF_UP` quantization of each named monetary output;
- immutable results and no mutation of input records;
- euro formatting to two decimal places, including an explicit minus sign for negative net movement.

### 13.3 Queries and month selection

Tests cover:

- exact `YYYY-MM` parsing;
- current-month default from a fixed clock;
- malformed, invalid-month, year `0000`, year `0001`, year `9999`, and otherwise unnavigable input falling back to the canonical current month with the generic visible error;
- valid navigable edge years `0002` and `9998`;
- half-open exclusion of the next month's first day;
- December rollover and leap-year February;
- previous and next links at accepted year bounds;
- deterministic history ordering;
- one materialized register snapshot supplying both rows and totals.

### 13.4 Forms and HTTP workflow

Tests cover:

- route names, paths, and allowed methods for register, detail, create, edit, and delete;
- explicit GET-only detail and register behavior, including HTTP 405 for mutation methods;
- valid create/edit Post/Redirect/Get to canonical review;
- exactly one save and one atomic mutation boundary per successful create/edit;
- invalid forms preserving safe input and committing nothing;
- amount, category, note, direction, and date field errors;
- hints before errors and a linked summary when multiple fields fail;
- escaped category and note output;
- GET never mutating;
- confirmed hard-delete by POST only;
- selected-month redirect after deletion;
- missing-record HTTP 404 behavior;
- success messages only after successful commit;
- exact optional create-date prefill, invalid prefill rejection, future-date prefill, and no creation on GET;
- notes absent from register rows.

### 13.5 Database failure contracts

Regression tests inject `DatabaseError` independently at:

- register query/materialization;
- detail lookup;
- edit lookup;
- delete lookup;
- create and edit validation that performs database constraint checks;
- create and edit save;
- create and edit atomic exit/commit;
- delete execution;
- delete atomic exit/commit;
- Daily Register Money snapshot query.

They prove the specified 503, form, confirmation, rollback, no-success-message, and failure-isolation outcomes. Separate tests prove real absence returns 404, class-only logs contain fixed domain/operation metadata, logs and responses exclude sentinel private values and exception text, and unexpected non-database exceptions propagate.

### 13.6 Register, summary, and navigation integration

Tests cover:

- empty and ready selected-month registers;
- exact count/inflow/outflow/net values from the displayed transaction snapshot;
- table columns and deterministic linked rows;
- absence of notes, charts, rankings, filters, search, and pagination from the register;
- ready and empty Daily Register Money states;
- immutable labelled values in the exact Transactions/Inflow/Outflow/Net movement order;
- current-month filtering from the one canonical date;
- one Money transaction snapshot for all Daily Register values;
- one canonical clock read for all domains;
- Work, Money, Habits composition order;
- Money register and dated quick-action links;
- expected Money failure isolation and safe logging;
- unexpected exception propagation;
- exactly one correct `aria-current="page"` across Daily Register, Work detail/form/register pages, and Money detail/form/register pages.

### 13.7 Automated verification

The completion gate includes:

- all focused Money tests;
- affected Core and Work integration tests;
- foundation documentation contract tests;
- the complete pytest suite;
- `uv run python manage.py check`;
- `uv run python manage.py check --deploy`, with expected loopback-development warnings recorded rather than hidden or represented as a deployment pass;
- `uv run python manage.py makemigrations --check --dry-run`;
- migration and startup against an explicitly owned disposable absolute database;
- live requests to `/ready/`, `/`, `/work/`, `/money/`, and `/money/transactions/new/`;
- a complete CSRF-enforced create, canonical review, edit, delete-confirmation, delete, and selected-month redirect workflow over ordinary HTTP;
- source and tracked-state scans for personal data, database files, remote runtime assets, prohibited browser tooling, and executable references to historical-source paths;
- an honest verification receipt recording exact commands, results, warnings, skips, approximations, and all unperformed manual checks.

The disposable runtime database is created beneath a system temporary directory, selected with an absolute `LIFEOS_DATABASE_PATH`, and removed by an exit trap. Test runners continue to use `lifeos.test_settings` with explicit `LIFEOS_TEST_ROOT`, `LIFEOS_TEST_OWNER`, `LIFEOS_TEST_DATABASE_PATH`, matching ownership marker, and existing-database sidecar rules. Verification output records only HTTP statuses, route markers, and non-personal assertions; it does not print tokens, submitted fields, database paths, or record values.

No visual browser automation is added. Django response tests and a real local HTTP client provide the required behavioral evidence.

### 13.8 Manual verification boundary

These seven checks remain explicitly manual and must be reported as unverified unless a person actually performs them:

1. actual layout at 320 CSS pixels;
2. layout and operation at 200% browser zoom;
3. a complete text-spacing override;
4. keyboard traversal and visible focus;
5. system, light, and dark theme behavior, including blocked storage;
6. reduced-motion behavior;
7. screen-reader smoke testing of landmarks, forms, error feedback, state labels, transaction tables, navigation current-page semantics, and message regions.

Automated semantic, contrast, static-asset, and response checks are useful evidence but do not close these seven gaps.

## 14. Delivery sequence and review gate

The implementation plan divides the slice into independently testable tasks:

1. Transaction model, normalization, amount constraints, and initial migration.
2. Pure Decimal monthly calculations and money formatting contracts.
3. Exact month parsing, safe navigation bounds, and monthly queries.
4. Create and GET-only canonical review workflow.
5. Edit workflow.
6. Confirmed hard-delete workflow with selected-month redirect.
7. Monthly Money register, totals, table, empty state, and unavailable state.
8. Daily Register summary, dated quick action, Money navigation, and corrected Daily Register/Work/Money `aria-current` semantics.
9. Documentation reconciliation, source/privacy scans, disposable-database startup, and full HTTP verification.

Each task is implemented with strict RED–GREEN–REFACTOR, ends with focused tests and the complete suite, and receives its own task commit. Commits contain no personal data, database artifacts, verification secrets, or unrelated untracked files.

After the final task, a fresh reviewer evaluates the complete Money slice against this specification, the implementation plan, maintained foundation authority, migrations, tests, and verification evidence. Confirmed Critical or Important findings receive exactly one dedicated TDD fix pass: reproduce each accepted finding with a failing regression test, implement the smallest correction, run focused and complete gates, and commit the pass. The regression tests and final complete gate record the fix outcome; this slice does not dispatch a second review. Minor deferrals and unavailable review capabilities are recorded honestly rather than silently treated as resolved.

## 15. Acceptance criteria

The Money slice is complete when:

- `Transaction` persistence and its migration implement every approved field, normalization rule, amount bound, database constraint, timestamp, ordering rule, and duplicate policy;
- all monetary storage and calculation use exact `Decimal`, and every named output uses `ROUND_HALF_UP` to two places;
- count, inflow, outflow, and net movement derive from one selected-month snapshot and are never persisted;
- all displayed monetary values use `€`, two decimal places, and an explicit sign for negative net movement;
- `/money/` and the complete create/review/edit/confirmed-delete workflows work without JavaScript through the specified methods and redirects;
- exact date prefill and exact month selection behave safely, including generic fallback and navigable edge years;
- the register presents only the approved summary and date/direction/category/amount table, with no notes or deferred discovery/visualization features;
- validation, lookup, save, delete, and commit `DatabaseError` paths have controlled rollback/recovery, class-only privacy-safe logs, and no false success;
- real missing records return 404 and unexpected exceptions propagate;
- the Daily Register presents Money's Transactions, Inflow, Outflow, and Net movement from one snapshot, links to the register, and offers the canonical-date quick action;
- expected Money failure affects only Money;
- Core does not import `Transaction` or calculate Money totals;
- Daily Register, Work, and Money expose correct exclusive current-page semantics;
- focused and complete automated gates, disposable migration/startup, and the full CSRF-enforced HTTP workflow pass;
- no personal database, historical application code/data, remote runtime asset, prohibited browser tooling, or repository database artifact is accessed or introduced;
- the verification receipt reports all seven manual gaps honestly;
- each planned task has a commit, and the fresh whole-slice review plus its one permitted TDD fix pass are complete.

## 16. Explicit non-goals

This slice does not implement:

- a `Category` model, category management, category normalization, aliases, or category rankings;
- accounts, account balances, reconciliation against accounts, or transfers;
- bank, file, spreadsheet, or historical-data imports;
- recurring transactions or scheduled generation;
- budgets, limits, forecasts, or savings goals;
- multiple currencies, currency conversion, or exchange rates;
- transaction filters, search, arbitrary date ranges, or pagination;
- charts, graphs, trend visualizations, decorative analytics, or leading-category summaries;
- soft deletion, restoration, or an audit log;
- a REST, GraphQL, or other public API;
- SPA behavior, client-side routing, client-side authoritative calculations, or browser state as a source of truth;
- automatic Work-to-Money transaction creation or any shared Work/Money persistence model;
- authentication, remote access, cloud synchronization, sharing, notifications, or background processing;
- backup product flows beyond the foundation's future-path guidance;
- Habits persistence;
- browser drivers, screenshots, snapshots, golden images, pixel comparison, capture rounds, or visual-regression services;
- access to, reuse of, or migration from `/home/aUser/improvedCalendar` or any other historical application source or personal database.
