# LifeOS Work Slice Design

**Date:** 2026-09-25  
**Status:** Approved design awaiting implementation plan

## 1. Purpose and authority

This design defines the first persisted LifeOS domain slice: Work. It adds a complete local workflow for recording shifts, reviewing a selected month, deriving an estimated salary, correcting records, and exposing a truthful Work summary in the Daily Register.

The maintained foundation package under `docs/foundation/` remains authoritative. If this document conflicts with that hierarchy, the foundation document with the higher authority wins. This design resolves the practical Work details intentionally left open by the foundation documents.

The slice must preserve these milestone-one constraints:

- SQLite remains the single source of truth.
- Personal data remains outside the repository.
- Tests use explicitly owned disposable databases and never resolve or create the personal database location.
- The interface is server-rendered Django over ordinary HTTP.
- Core workflows work without JavaScript.
- Logs and responses do not disclose notes, amounts, rates, database paths, SQL, or exception text.
- No visual browser tests, screenshots, snapshots, golden images, pixel comparison, capture rounds, or visual-regression services are introduced.
- Money and Habits remain legitimate empty summaries; their persisted workflows are outside this slice.

## 2. User outcome

After this slice, the owner can:

1. Open the Work register for the current or another selected month.
2. Create a shift with a date, type, worked hours, overtime hours, hourly rate, and optional note.
3. Review a canonical page for that shift.
4. Edit an incorrect shift.
5. Delete an incorrect shift after an explicit confirmation step.
6. See deterministic monthly hours and an explainable estimated salary.
7. Return to the Daily Register and see a populated current-month Work summary without affecting Money or Habits.

The workflow is a personal reconciliation record, not employer timekeeping, payroll processing, tax filing, or tax advice.

## 3. Domain record

### 3.1 Shift

A `Shift` owns:

- a stable identifier;
- `work_date`, a local calendar date;
- `shift_type`, one of `normal`, `night`, or `holiday`;
- `worked_hours`, an exact decimal;
- `overtime_hours`, an exact decimal;
- `hourly_rate`, an exact decimal monetary rate;
- `note`, optional plain text;
- timezone-aware `created_at` and `updated_at` timestamps.

No salary total, deduction, mean rate, or momentum-like cached value is stored on the record.

### 3.2 Validation

The model and form enforce the same rules:

- Worked hours are greater than `0.00` and at most `24.00`.
- Overtime hours are from `0.00` through `24.00`, inclusive.
- Hourly rate is from `0.00` through `10000.00`, inclusive.
- Hours and hourly rate accept at most two decimal places.
- Shift type must be one of the three defined values.
- The note is trimmed plain text with a maximum length of 500 characters.
- A missing or whitespace-only note is stored as an empty string.
- Future dates are allowed.
- Multiple shifts may share a work date.
- No implicit duplicate-shift rule is introduced.

Database check constraints protect the numeric ranges. Form and model validation provide useful field-level errors before a constraint can fail. Unknown records return HTTP 404 rather than creating replacements.

### 3.3 Ordering and deletion

Histories order shifts by:

1. work date descending;
2. creation timestamp descending;
3. stable identifier descending.

Deletion is a confirmed hard delete. The confirmation page names the shift date and type. This slice does not introduce soft deletion or an audit-log subsystem. Removing a shift immediately removes it from all derived results.

## 4. Salary policy

### 4.1 Per-shift values

For each included shift:

- `normal_hours = max(worked_hours - overtime_hours, 0)`
- `normal_pay = normal_hours × hourly_rate`
- `overtime_pay = overtime_hours × hourly_rate × 1.5`
- `shift_gross = normal_pay + overtime_pay`

Overtime may exceed worked hours. Normal hours never become negative. Shift type is descriptive and has no salary multiplier in version one.

### 4.2 Monthly values

For all shifts in the selected calendar month:

- total worked hours are the sum of `worked_hours`;
- total normal hours are the sum of per-shift `normal_hours`;
- total overtime hours are the sum of `overtime_hours`;
- mean hourly rate is the unweighted arithmetic mean of included shift rates;
- gross is the sum of each exact `shift_gross`;
- GPM is exact gross multiplied by `0.20`;
- VSD is exact gross multiplied by `0.1252`;
- PSD is exact gross multiplied by `0.0698`.

All intermediate arithmetic uses `Decimal`. Each named displayed output is rounded independently with `ROUND_HALF_UP` to two decimal places. Displayed total taxes are the sum of displayed GPM, VSD, and PSD. Displayed net is displayed gross minus displayed total taxes.

An immutable Work-owned calculation result carries the exact semantic fields. Views and templates do not recalculate salary.

### 4.3 Portable evidence and explanation

Every case in `docs/foundation/fixtures/salary-cases.json` is executable acceptance evidence. Tests load the fixture rather than duplicating its expected outputs in application code.

The Work register labels the result **Estimated salary** and explains:

- normal and overtime pay;
- the three characterized deduction rates;
- per-output half-up rounding;
- displayed tax summation and net derivation;
- that the estimate is a fixed version-one characterization and not tax advice.

This slice does not implement effective-dated tax policies or persisted salary snapshots. A future rate change requires an explicit design for policy versioning and historical interpretation; rates must not be changed silently.

## 5. Month and query semantics

The Work register defaults to the month containing the canonical local date from the core clock boundary. A `month=YYYY-MM` query parameter selects another calendar month.

The parser accepts only the exact four-digit-year, two-digit-month representation with a valid month from `01` through `12`. An invalid value does not silently query an unintended range: the page shows a form-level error and displays the canonical current month.

Month boundaries are half-open: the first day of the selected month through, but not including, the first day of the next month. This supports December rollover and leap years without timestamp assumptions.

The selected-month page includes previous- and next-month links. Pagination, arbitrary date ranges, and shift-type filters are deferred because a month already bounds the first workflow.

Work-owned query functions provide:

- deterministic shifts for a selected month;
- monthly salary input records;
- the nearest shift to a supplied local date.

The nearest shift minimizes absolute date distance. A shift today is a next shift. When a past and future shift are equally distant, the future shift wins. If multiple shifts tie on the chosen date, creation timestamp descending and identifier descending decide consistently.

## 6. Routes and HTTP behavior

The Work app owns these routes and names:

| Method | Path | Name | Purpose |
| --- | --- | --- | --- |
| GET | `/work/` | `work:register` | Current or selected monthly register |
| GET, POST | `/work/shifts/new/` | `work:shift-create` | Create a shift |
| GET | `/work/shifts/<int:pk>/` | `work:shift-detail` | Canonical shift review |
| GET, POST | `/work/shifts/<int:pk>/edit/` | `work:shift-edit` | Edit a shift |
| GET, POST | `/work/shifts/<int:pk>/delete/` | `work:shift-delete` | Confirm and delete a shift |

GET renders forms or records. POST is the only method that mutates state. Django CSRF protection remains active.

Successful create and edit operations save once, add a factual success message after commit, and redirect to `work:shift-detail`. A successful delete redirects to `work:register` with the deleted shift's month selected. Invalid forms commit nothing, retain safe submitted values, and do not add a success message.

The create route accepts an optional exact `date=YYYY-MM-DD` query parameter solely to prefill the form. Invalid or absent values leave the date field unprefilled. Opening the route never creates a record.

## 7. Work register presentation

The Work register extends the existing Closing Ledger shell and contains:

- one page heading and selected-month label;
- previous- and next-month navigation;
- a clear New shift action;
- visible invalid-month feedback when applicable;
- shift count;
- total worked, normal, and overtime hours;
- unweighted mean hourly rate;
- gross, GPM, VSD, PSD, total taxes, and estimated net;
- the formula and rounding explanation;
- a deterministic list of shifts with links to canonical review pages;
- an honest empty state when the selected month has no shifts.

Total worked hours do not add overtime a second time. Overtime is shown as a subset/classification used by the salary formula; normal hours are the non-negative calculated salary component.

Dates, durations, rates, and monetary outputs use the established tabular mono treatment. User notes render as escaped plain text.

## 8. Forms, errors, and feedback

Forms use visible labels and native controls. Hints precede field errors. Invalid fields are associated with their messages. When more than one error is present, a concise linked error summary appears before the fields. Safe submitted values remain visible for correction.

Create and edit have one clear save action. Delete has a distinct confirmation page and names the affected shift. No destructive action is performed through a link or GET request.

Success messages state what happened without including private amounts or notes. Expected operational failures log only controlled operation, domain, and exception-class metadata. Unexpected programming errors continue to propagate.

## 9. Daily Register integration

### 9.1 Shared presentation extension

`RegisterSummary` remains immutable and gains:

- the `ready` state;
- an optional tuple of immutable labelled values suitable for a compact domain summary.

Core renders these values generically but does not import Work models or calculate Work data. Existing Money and Habits summaries continue to provide no values and remain empty.

### 9.2 Work states

For the canonical date's calendar month:

- no shifts produces the existing honest empty Work summary;
- one or more shifts produces a ready summary;
- an expected operational failure produces the existing unavailable summary while Money and Habits still render;
- unexpected exceptions propagate.

A ready summary provides:

- shift count;
- total worked hours;
- overtime hours;
- estimated net salary;
- nearest shift label and date.

The nearest shift is labelled **Next shift** when its date is today or later and **Last shift** when earlier.

The Work panel and primary navigation link to `work:register`. The panel's New shift action links to `work:shift-create` with the canonical date as an optional prefill. Links appear only after their routes exist.

The Daily Register still reads its clock once and passes the same date to all domains.

## 10. Architecture and components

The Work slice uses focused conventional Django modules:

- `models.py` owns the Shift schema and invariant validation.
- `calculations.py` owns pure Decimal salary derivation and immutable results.
- `queries.py` owns month boundaries, deterministic selection, and nearest-shift behavior.
- `forms.py` owns input presentation and user-facing validation.
- `views.py` owns HTTP orchestration, transactions, messages, and redirects.
- `urls.py` owns the Work URL namespace.
- `summary.py` adapts Work-owned queries/calculations to the immutable core presentation boundary.
- Work templates own monthly, detail, form, and delete-confirmation pages.

No repository layer, generic service framework, client-side application state, REST API, background queue, event bus, tax-policy engine, or addon registry is introduced.

## 11. Security and privacy

- All mutations use POST and Django CSRF protection.
- User text is escaped by templates and never marked safe.
- Forms reject unknown choices and invalid decimal/date syntax.
- Database constraints protect key numeric invariants outside forms.
- Logs exclude shift notes, dates tied to a record, hours, rates, amounts, SQL, paths, and exception text.
- Readiness remains independent and minimal.
- Tests continue to use explicitly owned disposable databases.
- Runtime database overrides inside the source repository remain rejected.
- No remote runtime assets or analytics are added.

## 12. Accessibility and responsive behavior

All Work pages reuse the existing semantic shell, skip link, message regions, theme behavior, focus treatment, and responsive foundation.

Requirements include:

- logical headings and one main region;
- programmatic labels and descriptions;
- linked error summary for multiple form errors;
- visible state text independent of colour;
- at least 44-by-44 CSS-pixel interactive targets;
- keyboard-operable month navigation and actions;
- isolated horizontal scrolling only if a data table cannot reflow;
- source order matching visual order;
- no JavaScript dependency for navigation, validation, or mutation.

No automated visual browser testing is added. Actual 320-pixel layout, 200% zoom, text-spacing override, keyboard traversal, theme behavior, reduced motion, and screen-reader smoke testing remain manual checks and must be reported honestly.

## 13. Testing strategy

Implementation follows RED–GREEN–REFACTOR in complete increments.

### 13.1 Model and migration

Tests cover:

- field choices and normalization;
- numeric lower and upper bounds;
- decimal scale;
- 500-character note limit and trimming;
- timezone-aware timestamps;
- database constraints;
- deterministic ordering;
- multiple shifts on one date;
- future dates.

### 13.2 Calculations

Fixture-driven tests cover every salary case, including:

- ordinary month;
- overtime greater than worked hours;
- unweighted mean rate;
- equal treatment of all shift types;
- half-cent half-up rounding;
- displayed-tax summation and displayed-net derivation.

Tests additionally prove the calculation uses `Decimal` and does not mutate input records.

### 13.3 Queries

Tests cover:

- exact month parsing;
- current-month default;
- invalid-month fallback with visible error;
- December rollover;
- leap-year February;
- deterministic history ordering;
- nearest-shift past/future tie behavior;
- same-date tie behavior.

### 13.4 HTTP workflow

Tests cover:

- register, detail, create, edit, and delete routes;
- valid create/edit Post/Redirect/Get;
- invalid forms preserving input and committing nothing;
- field errors and linked multi-error summary;
- escaped notes;
- GET never mutating;
- delete confirmation and POST deletion;
- missing-record 404 behavior;
- success messages only after successful commits;
- optional create-date prefill without record creation.

### 13.5 Dashboard integration

Tests cover:

- ready and empty Work states;
- immutable labelled values;
- current-month filtering;
- nearest-shift labels;
- one canonical clock read;
- Work, Money, Habits order;
- implemented navigation and action links;
- expected failure isolation and safe logging;
- unexpected exception propagation.

### 13.6 Verification

The completion gate includes:

- all focused Work tests;
- the complete pytest suite;
- `manage.py check`;
- `manage.py check --deploy`, with expected loopback-development warnings recorded rather than hidden;
- `makemigrations --check --dry-run`;
- migrations and startup against an explicitly disposable absolute database;
- requests to `/ready/`, `/`, `/work/`, and the complete create/review/edit/delete flow;
- source scans for personal data, remote runtime assets, prohibited browser tooling, and historical-source paths;
- an honest verification receipt listing all unperformed manual checks.

## 14. Delivery sequence

The implementation plan should divide the slice into these independently testable tasks:

1. Shift model, validation, constraints, and initial migration.
2. Pure fixture-driven salary calculations.
3. Month parsing, monthly queries, and nearest-shift selection.
4. Create and canonical review workflow.
5. Edit workflow.
6. Confirmed deletion workflow.
7. Monthly Work register and salary explanation.
8. Daily Register and navigation integration.
9. Documentation reconciliation and end-to-end verification.

Each task ends with its focused tests, the full suite, and a commit. A fresh whole-slice review follows the final task; confirmed critical or important findings receive one TDD fix pass.

## 15. Explicit deferrals

This slice does not implement:

- Money or Habits persistence;
- payroll-provider integration or tax filing;
- tax-policy versions or salary snapshots;
- shift-type pay multipliers;
- soft deletion or audit history;
- arbitrary date ranges, shift-type filters, or pagination;
- import/export;
- public APIs;
- background processing;
- browser automation or visual browser tests;
- the remaining manual browser and assistive-technology checks.
