# LifeOS Work Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first persisted LifeOS domain so the owner can create, review, edit, delete, and reconcile monthly shifts, understand an estimated salary, and see a truthful current-month Work summary.

**Architecture:** Work remains a focused Django domain. Its model owns stored invariants, pure immutable values own salary policy, query functions own month semantics, and server-rendered views orchestrate HTTP workflows; core gains only a generic immutable labelled-value boundary and never imports Work persistence.

**Tech Stack:** Python 3.14, Django 6.1.1, SQLite, `Decimal`, pytest 9.1.1, pytest-django 4.14.0, Django templates, local CSS, and `uv` 0.12+.

**Spec:** `docs/superpowers/specs/2026-09-25-lifeos-work-slice-design.md`

## Global Constraints

- SQLite remains the single source of truth; no salary totals are persisted.
- Personal data remains outside the repository.
- Tests use explicitly owned disposable databases and never resolve or create the personal database location.
- Use server-rendered Django and ordinary HTTP; core workflows work without JavaScript.
- Mutations use POST, CSRF protection, atomic writes, and Post/Redirect/Get after success.
- Logs and responses never disclose notes, dates tied to records, hours, rates, amounts, SQL, paths, or exception text.
- All salary arithmetic uses `Decimal`; named outputs use `ROUND_HALF_UP` to two places.
- The Daily Register reads its clock once and preserves Work, Money, Habits order.
- User text remains escaped plain text and is never marked safe.
- Do not add dependencies, APIs, queues, repositories, generic service frameworks, tax engines, or client-side state.
- Do not add visual browser tests, browser drivers, screenshots, snapshots, golden images, pixel comparison, capture rounds, or visual-regression services.
- Money and Habits persistence remains outside this slice.
- Manual 320px, 200% zoom, text-spacing, keyboard, theme, reduced-motion, and screen-reader checks remain unverified unless actually performed.

## Review Focus

- Empty calculation input returns an immutable zero result without division by zero — Task 2 tests it.
- Non-finite, excessive-scale, and boundary decimal input commits nothing — Tasks 1 and 4 test it.
- Invalid month input falls back visibly to the canonical current month, including leap-year and December boundaries — Task 3 tests it.
- Equal-distance nearest shifts prefer future, while same-date ties remain deterministic — Task 3 tests it.
- Expected database failures expose neither fabricated values nor private diagnostics — Tasks 4, 7, and 8 test responses and logs.

## Stable Interfaces

```python
# lifeos/work/calculations.py
@dataclass(frozen=True, slots=True)
class SalaryInput:
    worked_hours: Decimal
    overtime_hours: Decimal
    hourly_rate: Decimal
    shift_type: str

@dataclass(frozen=True, slots=True)
class SalaryResult:
    shift_count: int
    total_worked_hours: Decimal
    total_normal_hours: Decimal
    total_overtime_hours: Decimal
    mean_hourly_rate: Decimal
    gross: Decimal
    gpm: Decimal
    vsd: Decimal
    psd: Decimal
    total_taxes: Decimal
    net: Decimal

def calculate_salary(records: Iterable[SalaryInput]) -> SalaryResult: ...
```

```python
# lifeos/work/queries.py
@dataclass(frozen=True, slots=True)
class CalendarMonth:
    year: int
    month: int
    @property
    def value(self) -> str: ...
    @property
    def label(self) -> str: ...
    @property
    def first_day(self) -> date: ...
    @property
    def next_first_day(self) -> date: ...
    def previous(self) -> "CalendarMonth": ...
    def next(self) -> "CalendarMonth": ...

@dataclass(frozen=True, slots=True)
class MonthSelection:
    month: CalendarMonth
    error: str | None

def select_month(raw_value: str | None, *, today: date) -> MonthSelection: ...
def shifts_for_month(month: CalendarMonth) -> QuerySet[Shift]: ...
def salary_inputs_for_month(month: CalendarMonth) -> tuple[SalaryInput, ...]: ...
def nearest_shift(*, month: CalendarMonth, target: date) -> Shift | None: ...
```

```python
# lifeos/core/dashboard.py
RegisterState = Literal["empty", "ready", "unavailable"]

@dataclass(frozen=True, slots=True)
class LabelledValue:
    label: str
    value: str

# RegisterSummary retains all existing fields and adds last:
values: tuple[LabelledValue, ...] = ()
```

---

### Task 1: Validated Shift Model and Migration

**Files:**
- Create: `lifeos/work/models.py`
- Create: `lifeos/work/migrations/__init__.py`
- Create: `lifeos/work/migrations/0001_initial.py`
- Create: `tests/work/__init__.py`
- Create: `tests/work/test_models.py`

**Interfaces:**
- Consumes: installed `lifeos.work` app and owned pytest database.
- Produces: `Shift`, `Shift.Type`, and ordering `("-work_date", "-created_at", "-pk")`.

- [ ] **Step 1: Write failing model tests**

Create `make_shift()` with valid `Decimal` defaults. Test type choices, trimmed/blank/500-character notes, rejection of 501 characters, aware timestamps, future dates, multiple shifts on one date, and deterministic ordering. Parameterize these invalid values:

```python
@pytest.mark.parametrize(("field", "value"), [
    ("worked_hours", Decimal("0.00")),
    ("worked_hours", Decimal("24.01")),
    ("overtime_hours", Decimal("-0.01")),
    ("overtime_hours", Decimal("24.01")),
    ("hourly_rate", Decimal("-0.01")),
    ("hourly_rate", Decimal("10000.01")),
])
def test_shift_rejects_values_outside_bounds(field, value):
    with pytest.raises(ValidationError) as error:
        make_shift(**{field: value}).full_clean()
    assert field in error.value.message_dict
```

For each decimal field, reject `Decimal("1.001")`, `Decimal("NaN")`, and `Decimal("Infinity")`. Through `Shift.objects.create()` inside nested `transaction.atomic()`, assert `IntegrityError` for range violations and prove overtime greater than worked hours is accepted.

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/work/test_models.py -q`  
Expected: collection fails because `lifeos.work.models` does not exist.

- [ ] **Step 3: Implement the model**

Use `DateField`, constrained `TextChoices`, `DecimalField(max_digits=4, decimal_places=2)` for hours, `DecimalField(max_digits=7, decimal_places=2)` for rate, `TextField(blank=True, default="", max_length=500)`, and automatic timestamps. Add min/max validators and named database constraints for `(0,24]`, `[0,24]`, and `[0,10000]`. Override `clean_fields(exclude=None)` only to normalize `note = (note or "").strip()` before calling `super().clean_fields(exclude=exclude)`; this ensures whitespace is removed before the model's 500-character validation. Do not override `save()`.

- [ ] **Step 4: Generate and inspect the migration**

Run: `uv run python manage.py makemigrations work`  
Verify the migration contains only the model, ordering, and three constraints; no data operation.

- [ ] **Step 5: Verify GREEN and regression safety**

```bash
uv run pytest tests/work/test_models.py -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
```

Expected: all pass; migration check says `No changes detected`.

- [ ] **Step 6: Commit**

```bash
git add lifeos/work/models.py lifeos/work/migrations tests/work
git commit -m "feat: add validated work shift model

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 2: Fixture-Driven Salary Calculation

**Files:**
- Create: `lifeos/work/calculations.py`
- Create: `tests/work/test_calculations.py`
- Read: `docs/foundation/fixtures/salary-cases.json`

**Interfaces:** Produces the exact `SalaryInput`, `SalaryResult`, and `calculate_salary()` interface above.

- [ ] **Step 1: Write failing fixture tests**

Load every fixture case and map each shift to `SalaryInput`. Assert every `expected_*` field against the matching result field. Add:

```python
def test_empty_salary_input_returns_zero_result():
    zero = Decimal("0.00")
    assert calculate_salary(()) == SalaryResult(
        0, zero, zero, zero, zero, zero, zero, zero, zero, zero, zero,
    )

def test_overtime_above_worked_never_makes_normal_negative():
    result = calculate_salary((
        SalaryInput(Decimal("1.00"), Decimal("2.00"), Decimal("10.00"), "night"),
    ))
    assert result.total_normal_hours == Decimal("0.00")
    assert result.gross == Decimal("30.00")
```

Also test frozen results, `Decimal` outputs, and unchanged input sequences.

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/work/test_calculations.py -q`  
Expected: missing calculations module.

- [ ] **Step 3: Implement exact calculations**

Materialize the iterable once. Use constants `ZERO`, `CENT`, overtime `1.5`, and rates `0.20`, `0.1252`, `0.0698`. Calculate normal hours per shift, exact gross and unweighted mean, then quantize displayed gross and each deduction independently. Sum displayed deductions and subtract them from displayed gross. Return all hours/rates/amounts quantized to two places. Never branch on shift type.

- [ ] **Step 4: Verify GREEN**

```bash
uv run pytest tests/work/test_calculations.py -q
uv run pytest tests/work -q
uv run pytest -q
uv run python manage.py check
```

- [ ] **Step 5: Commit**

```bash
git add lifeos/work/calculations.py tests/work/test_calculations.py
git commit -m "feat: calculate estimated work salary

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 3: Month and Nearest-Shift Queries

**Files:**
- Create: `lifeos/work/queries.py`
- Create: `tests/work/test_queries.py`

**Interfaces:** Produces the exact `CalendarMonth`, `MonthSelection`, and query functions above.

- [ ] **Step 1: Write failing month tests**

Reject `2026-9`, `26-09`, `2026-00`, `2026-13`, whitespace, empty string, and arbitrary text with error `Enter a month in YYYY-MM format.` and fallback to `today`'s month. `None` defaults without error. Test December/year rollover, leap-day inclusion, March exclusion, and half-open boundaries.

- [ ] **Step 2: Write failing ordering and nearest tests**

Create valid shifts and assert monthly isolation and ordering by date/creation/id descending. Test immutable salary inputs. Test today as next, future winning equal past/future distance, and same-date creation/id tie breaking.

- [ ] **Step 3: Verify RED**

Run: `uv run pytest tests/work/test_queries.py -q`  
Expected: missing queries module.

- [ ] **Step 4: Implement query semantics**

Use exact regex `^(?P<year>\d{4})-(?P<month>0[1-9]|1[0-2])$`. Implement immutable month navigation and half-open filtering. Adapt rows to `SalaryInput`. Implement nearest selection over the month-bounded tuple with key:

```python
(
    abs((shift.work_date - target).days),
    0 if shift.work_date >= target else 1,
    -shift.created_at.timestamp(),
    -shift.pk,
)
```

- [ ] **Step 5: Verify GREEN and commit**

```bash
uv run pytest tests/work/test_queries.py -q
uv run pytest tests/work -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
git add lifeos/work/queries.py tests/work/test_queries.py
git commit -m "feat: add work month queries

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 4: Create and Canonical Review Workflow

**Files:**
- Create: `lifeos/work/forms.py`
- Create: `lifeos/work/views.py`
- Create: `lifeos/work/urls.py`
- Create: `templates/work/_shift_form.html`
- Create: `templates/work/shift_form.html`
- Create: `templates/work/shift_detail.html`
- Create: `tests/work/test_create_detail.py`
- Modify: `lifeos/urls.py`
- Modify: `static/css/app.css`

**Interfaces:** Produces `ShiftForm`, `shift_create`, `shift_detail`, `work:shift-create`, and `work:shift-detail`.

- [ ] **Step 1: Write failing route and happy-path tests**

Test exact `date=YYYY-MM-DD` prefill, malformed prefill ignored, GET creates nothing, valid POST trims the note and redirects to canonical detail, detail has one main/h1 and escaped note, and missing IDs return 404 without replacement.

- [ ] **Step 2: Write failing invalid/privacy/accessibility tests**

Submit an invalid date/type, excessive scale, `NaN`, excessive rate, and a private note. Assert no row, retained safe input, no success message, linked multi-error summary, hint/error/control association, `aria-invalid`, and private text absent from logs. Enforce CSRF with `Client(enforce_csrf_checks=True)`.

Patch `ShiftForm.save` to raise `DatabaseError("private 99.99 /private/path")`; require safe form-level feedback, rollback, exception class in logs, and no exception text/private fragments.

- [ ] **Step 3: Verify RED**

Run: `uv run pytest tests/work/test_create_detail.py -q`  
Expected: Work routes cannot be resolved.

- [ ] **Step 4: Implement form and routes**

Use `ModelForm` with six fields, native date/number controls, `step="0.01"`, explicit help text, and `error_count()`. Include Work URLs beneath `/work/`.

- [ ] **Step 5: Implement safe view orchestration**

Parse prefill with `date.fromisoformat()` plus round-trip equality. On valid POST, save inside `transaction.atomic()`, then add `Shift created.` and redirect after successful exit. Catch only `DatabaseError`, log `Work shift create failed (DatabaseError)` without traceback/message, and add a non-field retry error. Detail uses `get_object_or_404`.

- [ ] **Step 6: Implement semantic templates and CSS**

The form partial renders a linked summary only for multiple errors, then each field's label, hint, errors, and control with associations. Include CSRF and never `safe`. Detail uses `<time datetime>`, `.mono`, and escaped note. Add flat Closing Ledger form/error/action styles, 44px controls, and narrow reflow.

- [ ] **Step 7: Verify GREEN and commit**

```bash
uv run pytest tests/work/test_create_detail.py -q
uv run pytest tests/work -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
git add lifeos/urls.py lifeos/work/forms.py lifeos/work/views.py lifeos/work/urls.py templates/work static/css/app.css tests/work/test_create_detail.py
git commit -m "feat: add shift creation and review

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 5: Edit Workflow

**Files:**
- Modify: `lifeos/work/views.py`
- Modify: `lifeos/work/urls.py`
- Modify: `templates/work/shift_form.html`
- Modify: `templates/work/shift_detail.html`
- Create: `tests/work/test_edit.py`

**Interfaces:** Produces `shift_edit(request, pk)` and `work:shift-edit`.

- [ ] **Step 1: Write failing edit tests**

Test populated GET without mutation, valid POST saves once and redirects to detail, invalid POST preserves the database and has no success message, missing GET/POST return 404, CSRF is enforced, and a patched `DatabaseError` rolls back with controlled logging only.

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/work/test_edit.py -q`  
Expected: edit route cannot be resolved.

- [ ] **Step 3: Implement edit**

Use `get_object_or_404`, `ShiftForm(request.POST or None, instance=shift)`, atomic save, safe database failure handling, `Shift updated.`, and detail redirect. Reuse the form template with `Edit shift` and `Save changes`. Add a visible edit link to detail.

- [ ] **Step 4: Verify GREEN and commit**

```bash
uv run pytest tests/work/test_edit.py -q
uv run pytest tests/work/test_create_detail.py tests/work/test_edit.py -q
uv run pytest -q
uv run python manage.py check
git add lifeos/work/views.py lifeos/work/urls.py templates/work tests/work/test_edit.py
git commit -m "feat: add shift editing

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 6: Confirmed Deletion

**Files:**
- Modify: `lifeos/work/views.py`
- Modify: `lifeos/work/urls.py`
- Modify: `templates/work/shift_detail.html`
- Create: `templates/work/shift_confirm_delete.html`
- Create: `templates/work/register.html`
- Create: `tests/work/test_delete.py`

**Interfaces:** Produces `shift_delete`, `work:shift-delete`, and provisional `work:register` needed as a real redirect target.

- [ ] **Step 1: Write failing deletion tests**

GET must name date/type and retain the row. POST hard-deletes and redirects to `/work/?month=YYYY-MM`. Test repeated GET safety, missing 404, CSRF, factual `Shift deleted.` without private details, and patched `DatabaseError` rollback plus safe logging.

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/work/test_delete.py -q`  
Expected: delete/register routes cannot be resolved.

- [ ] **Step 3: Add routes and confirmed delete**

Add `/work/`, delete route, and a minimal GET-only register placeholder with an honest selected-month heading. Delete uses atomic POST, captures month before deletion, logs controlled metadata on `DatabaseError`, and redirects after success. Confirmation has CSRF, clear destructive button, and cancel link. Detail links to confirmation; GET never deletes.

- [ ] **Step 4: Verify GREEN and commit**

```bash
uv run pytest tests/work/test_delete.py -q
uv run pytest tests/work -q
uv run pytest -q
uv run python manage.py check
git add lifeos/work/views.py lifeos/work/urls.py templates/work tests/work/test_delete.py
git commit -m "feat: add confirmed shift deletion

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 7: Monthly Work Register

**Files:**
- Modify: `lifeos/work/views.py`
- Replace: `templates/work/register.html`
- Create: `templates/work/register_unavailable.html`
- Modify: `static/css/app.css`
- Create: `tests/work/test_register.py`

**Interfaces:** Register consumes core clock, month/query functions, and salary calculation; context exposes `month`, `month_error`, navigation months, `shifts`, and `salary`.

- [ ] **Step 1: Write failing selection/empty tests**

Test canonical current-month default with fixed clock, invalid month visible fallback without leaking another month's row, exact previous/next navigation including December, and honest empty state with zero result.

- [ ] **Step 2: Write failing totals/presentation tests**

Create multiple shifts and assert count, worked/normal/overtime totals, mean, gross, deductions, taxes, net, deterministic links, one main/h1, `Estimated salary`, `.mono` values, isolated table scrolling, no list notes, and literal explanation of formula, rates, rounding, fixed characterization, and “not tax advice.”

- [ ] **Step 3: Write failing operational-error tests**

Patch query to raise a sensitive `DatabaseError`; require HTTP 503 with `Work register is temporarily unavailable.`, controlled class-only logs, and no fabricated zero salary. Assert unexpected `AssertionError` propagates.

- [ ] **Step 4: Verify RED**

Run: `uv run pytest tests/work/test_register.py -q`  
Expected: provisional register lacks required context and behavior.

- [ ] **Step 5: Implement register**

Read clock once, select month, materialize deterministic shifts, calculate from salary inputs, and render. Catch only `DatabaseError` and return private 503 unavailable template. Render month navigation, new shift, error, values, explanation, and linked rows without recalculation.

- [ ] **Step 6: Add responsive styles**

Add month navigation, salary grid/explanation, shift table, empty/unavailable styles. Preserve 44px targets and page-level no-overflow; only the table wrapper may scroll.

- [ ] **Step 7: Verify GREEN and commit**

```bash
uv run pytest tests/work/test_register.py -q
uv run pytest tests/work -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
git add lifeos/work/views.py templates/work/register.html templates/work/register_unavailable.html static/css/app.css tests/work/test_register.py
git commit -m "feat: add monthly work register

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 8: Daily Register Integration

**Files:**
- Modify: `lifeos/core/dashboard.py`
- Modify: `lifeos/work/summary.py`
- Modify: `lifeos/money/summary.py`
- Modify: `lifeos/habits/summary.py`
- Modify: `templates/core/register.html`
- Modify: `templates/base.html`
- Modify: `static/css/app.css`
- Create: `tests/work/test_summary.py`
- Modify: `tests/core/test_dashboard.py`
- Modify: `tests/core/test_views.py`

**Interfaces:** Produces `ready`, immutable `LabelledValue`, optional `RegisterSummary.values`, and populated Work adaptation.

- [ ] **Step 1: Write failing summary tests**

For a current-month shift with worked `8.00`, overtime `1.00`, and rate `20.00`, assert ready state, `/work/`, dated create prefill, and exact values: one shift, worked `8.00`, overtime `1.00`, estimated net `102.85`, and nearest label/date. This pins gross `170.00`, deductions `34.00` + `21.28` + `11.87`, taxes `67.15`, and net `102.85` under the approved policy. Test frozen values. Empty Work retains implemented links but no values. Exclude another month. Test same-day/future `Next shift`, past `Last shift`, query `DatabaseError` translated to `SummaryUnavailable` without private text, and unexpected errors propagated.

- [ ] **Step 2: Extend failing core tests**

Assert one clock read, ready/empty/empty states, unchanged domain order, generic rendered values, Work nav and dated action, no Money/Habits action links, expected failure isolation and safe logs, and unexpected propagation.

- [ ] **Step 3: Verify RED**

Run: `uv run pytest tests/work/test_summary.py tests/core/test_dashboard.py tests/core/test_views.py -q`  
Expected: ready/value behavior absent.

- [ ] **Step 4: Extend immutable core boundary**

Add `ready`, frozen `LabelledValue`, and trailing default `values=()`. Set explicit empty values in existing constructors and unavailable fallback.

- [ ] **Step 5: Implement Work adapter**

Use current `CalendarMonth`, salary query/calculation, and nearest query. Translate only `DatabaseError` to `SummaryUnavailable`. Format dates portably with `f"{value.day} {value:%B %Y}"`. Empty and ready states both use reversed Work routes; create includes exact `today.isoformat()` prefill.

- [ ] **Step 6: Render and style values**

Render escaped `<dl class="register-values">` generically. Change only Work navigation from inert text to route link. Add compact generic value layout; do not expose domain ORM to core.

- [ ] **Step 7: Verify GREEN and commit**

```bash
uv run pytest tests/work/test_summary.py tests/core/test_dashboard.py tests/core/test_views.py -q
uv run pytest tests/work tests/core -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
git add lifeos/core/dashboard.py lifeos/work/summary.py lifeos/money/summary.py lifeos/habits/summary.py templates/core/register.html templates/base.html static/css/app.css tests/work/test_summary.py tests/core
git commit -m "feat: integrate work into daily register

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 9: Documentation and End-to-End Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/foundation/START-HERE.md`
- Modify: `docs/foundation/V1-SCOPE.md`
- Modify: `docs/foundation/DOMAIN.md`
- Modify: `docs/foundation/ARCHITECTURE.md`
- Modify: `docs/foundation/ENGINEERING.md`
- Modify: `tests/test_foundation_docs.py`
- Create: `docs/verification/2026-09-25-work-slice.md`

**Interfaces:** Produces maintained authority reflecting implemented Work and an honest receipt.

- [ ] **Step 1: Write failing documentation contracts**

Assert README documents `/work/`, create/review/edit/delete, Estimated salary, and not-tax-advice. Assert START-HERE names persisted Work while Money/Habits remain empty. Assert DOMAIN contains exact bounds/scale/note rules. Assert ENGINEERING retains all named manual checks and no-visual-browser boundary.

- [ ] **Step 2: Verify RED**

Run: `uv run pytest tests/test_foundation_docs.py -q`  
Expected: docs still describe foundation-only behavior.

- [ ] **Step 3: Reconcile docs**

Update only implemented facts: Work routes/workflow, exact validation, module boundaries, focused commands, and milestone status. Do not imply Money/Habits completion or manual checks.

- [ ] **Step 4: Run automated gates**

```bash
uv run pytest tests/test_foundation_docs.py -q
uv run pytest tests/work -q
uv run pytest tests/core -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py check --deploy
uv run python manage.py makemigrations --check --dry-run
```

Record exact counts and all deploy warning IDs/text.

- [ ] **Step 5: Verify migration and startup safely**

Create a system temporary directory, trap cleanup, set an absolute `LIFEOS_DATABASE_PATH` beneath it without printing it, migrate, and start loopback port 8765. Require `/ready/`, `/`, `/work/`, create form, and non-private page markers.

- [ ] **Step 6: Exercise complete HTTP flow**

Using Django's CSRF-aware client in a process configured for the same disposable database, perform create, canonical review, edit, delete confirmation, delete POST, and final empty selected month. Record only statuses/route markers—never CSRF values, notes, dates tied to records, hours, rates, amounts, SQL, or paths.

- [ ] **Step 7: Run source safety scans**

Check runtime templates/CSS/JS for remote assets; executable/config source for prohibited browser tooling; historical absolute paths outside non-normative provenance/test assertions; SQLite/staticfiles/private markers in tracked state. Leave unrelated untracked `.claude/`, root `PRODUCT.md`, and other plan files untouched.

- [ ] **Step 8: Write the receipt**

Create sections for scope/revision, environment, focused tests, complete gates, deploy warnings, isolated migration/startup, HTTP workflow, source/privacy scans, review/fix pass, and visual/accessibility boundary. List all seven manual gaps as unverified and state no visual browser testing occurred.

- [ ] **Step 9: Re-run and commit**

```bash
uv run pytest tests/test_foundation_docs.py -q
uv run pytest tests/work -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
git add README.md docs/foundation docs/verification/2026-09-25-work-slice.md tests/test_foundation_docs.py
git commit -m "docs: reconcile and verify work slice

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Final Whole-Slice Review

- [ ] Build the review package for the complete Work commit range and dispatch one fresh most-capable reviewer. Prioritize arithmetic/rounding, month/tie boundaries, transactions/404s, privacy, accessibility/no-JS, core coupling, database safety, and prohibited tooling.
- [ ] Re-grade findings by user effect. Critical/Important findings enter one fix pass; Minor findings are ledgered and deferred.
- [ ] For every fix, write and observe one focused failing regression test, implement the smallest correction, and prove focused plus complete suites green.
- [ ] Update the receipt with actual review and post-fix evidence; commit only if changes exist.
- [ ] Run the final gate:

```bash
uv run pytest tests/work -q
uv run pytest tests/core -q
uv run pytest tests/test_settings.py tests/test_foundation_docs.py -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py check --deploy
uv run python manage.py makemigrations --check --dry-run
git status --short
```

Expected: tests, ordinary check, and drift check pass; only recorded loopback deploy warnings remain; status contains only explicitly identified pre-existing untracked files.
