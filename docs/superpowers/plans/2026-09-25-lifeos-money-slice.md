# LifeOS Money Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independent, persisted Money transaction ledger with exact monthly reconciliation, safe create/review/edit/delete workflows, Daily Register integration, correct current-page navigation, and privacy-preserving database-failure recovery.

**Architecture:** Implement Money as a conventional Django domain under `lifeos.money`, with its own `Transaction`, immutable calculation result, Money-owned month type and queries, forms, views, URLs, templates, migration, and summary adapter. Materialize each selected month exactly once, derive rows and totals from that immutable snapshot, and expose only the generic immutable `RegisterSummary` boundary to Core; Money must not import Work models, queries, forms, calculations, views, or templates, and proven Work internals are not refactored merely to share code.

**Tech Stack:** Python `>=3.14,<3.15`; Django `6.1.1`; SQLite; pytest `9.1.1`; pytest-django `4.14.0`; server-rendered Django templates; repository-local CSS, JavaScript, and fonts; `uv`.

**Spec:** `/home/aUser/lifeManager/docs/superpowers/specs/2026-09-25-lifeos-money-slice-design.md`

## Global Constraints

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
- Preserve unrelated untracked `.claude/`, root `PRODUCT.md`, and other files beneath `docs/superpowers/plans/`; do not stage, delete, inspect for product authority, or include them in task commits.
- Money owns its month type and domain policy. Do not import `lifeos.work` internals into Money and do not refactor proven Work month/query code unless a separately observed requirement makes that necessary.

## Review Focus

1. Lexically unsafe monetary inputs such as `-0.01`, `1e2`, `NaN`, `Infinity`, `1.001`, `1,00`, and values outside `0.01..999999999.99` must be rejected rather than coerced; Task 1 pins model invariants and Task 4 pins submitted-input behavior.
2. A `DatabaseError` raised during validation, lookup, save/delete, or atomic-block exit must produce the operation-specific controlled response, rollback where applicable, no false success, and class-only private logging; Tasks 4, 5, 6, 7, and 8 pin every boundary independently.
3. Month selection at `0002`, `9998`, leap-year February, and December rollover must never construct year zero or year 10000 and must use half-open boundaries; Task 3 owns these tests.
4. Register rows and all aggregates must derive from the same single materialized snapshot, so edits or concurrent evaluation cannot make the table disagree with its totals; Task 7 owns a one-query snapshot regression and Task 8 owns the equivalent summary regression.
5. Exactly one implemented primary-navigation destination must carry `aria-current="page"` based on resolved route identity, including Money detail/form pages and Work detail/form pages; Task 8 owns semantic response tests across every namespace.

---

## File Responsibility Map

| File | Responsibility |
| --- | --- |
| `/home/aUser/lifeManager/lifeos/money/models.py` | `Transaction` schema, direction choices, normalization, validation, ordering, and named database amount constraints. |
| `/home/aUser/lifeManager/lifeos/money/migrations/0001_initial.py` | Reviewed Money schema and lower/upper amount constraints. |
| `/home/aUser/lifeManager/lifeos/money/calculations.py` | Immutable transaction calculation input/result, exact monthly derivation, independent `ROUND_HALF_UP` boundaries, and euro formatting. |
| `/home/aUser/lifeManager/lifeos/money/queries.py` | Money-owned `CalendarMonth`, strict month selection, half-open date bounds, deterministic query, and immutable monthly snapshot. |
| `/home/aUser/lifeManager/lifeos/money/forms.py` | Lexically strict amount input, model form widgets, normalization presentation, hints, and ARIA error associations. |
| `/home/aUser/lifeManager/lifeos/money/views.py` | Method enforcement, create/detail/edit/delete/register orchestration, atomic mutations, safe database recovery, messages, redirects, and date prefill. |
| `/home/aUser/lifeManager/lifeos/money/urls.py` | Money URL namespace and five approved routes. |
| `/home/aUser/lifeManager/lifeos/money/summary.py` | One-snapshot Money-to-Core `RegisterSummary` adapter and `SummaryUnavailable` translation. |
| `/home/aUser/lifeManager/lifeos/money/migrations/__init__.py` | Migration package marker. |
| `/home/aUser/lifeManager/lifeos/urls.py` | Mount `lifeos.money.urls` below `/money/`. |
| `/home/aUser/lifeManager/templates/money/_transaction_form.html` | Shared accessible field rendering and linked multi-error summary. |
| `/home/aUser/lifeManager/templates/money/transaction_form.html` | Create/edit page shell and one save action. |
| `/home/aUser/lifeManager/templates/money/transaction_detail.html` | Canonical GET-only record review, including note only here. |
| `/home/aUser/lifeManager/templates/money/transaction_confirm_delete.html` | Safe identity, explicit destructive confirmation, and delete recovery guidance. |
| `/home/aUser/lifeManager/templates/money/register.html` | Selected-month totals, four-column transaction table, navigation, feedback, and empty state. |
| `/home/aUser/lifeManager/templates/money/register_unavailable.html` | Money-owned HTTP 503 response without false empty values. |
| `/home/aUser/lifeManager/templates/base.html` | Route-identity-based primary navigation and Money link. |
| `/home/aUser/lifeManager/static/css/app.css` | Money presentation using existing tokens, mono values, responsive table region, and 44px targets. |
| `/home/aUser/lifeManager/tests/money/test_models.py` | Model, normalization, constraints, ordering, duplicates, timestamps, and migration contracts. |
| `/home/aUser/lifeManager/tests/money/test_calculations.py` | Pure exact arithmetic, quantization, immutability, and euro formatting. |
| `/home/aUser/lifeManager/tests/money/test_queries.py` | Strict month parsing, edge navigation, half-open selection, ordering, and snapshot behavior. |
| `/home/aUser/lifeManager/tests/money/test_create_detail.py` | Routes, lexical form validation, create, GET-only detail, escaping, atomic boundaries, and failure privacy. |
| `/home/aUser/lifeManager/tests/money/test_edit.py` | Edit workflow and lookup/validation/save/atomic-exit failures. |
| `/home/aUser/lifeManager/tests/money/test_delete.py` | Confirmed hard delete, selected-month redirect, and lookup/delete/atomic-exit failures. |
| `/home/aUser/lifeManager/tests/money/test_register.py` | Register totals/table/empty/unavailable behavior and one-snapshot contract. |
| `/home/aUser/lifeManager/tests/money/test_summary.py` | Empty/ready summaries, value order, one snapshot, and database-failure translation. |
| `/home/aUser/lifeManager/tests/core/test_dashboard.py` | One clock read, deterministic domain order, Money links/values, and failure isolation. |
| `/home/aUser/lifeManager/tests/core/test_views.py` | Rendered navigation current-page semantics across Core, Work, and Money. |
| `/home/aUser/lifeManager/tests/test_foundation_docs.py` | Maintained documentation contracts for the implemented Money slice and retained safety boundaries. |
| `/home/aUser/lifeManager/README.md` | Operator-facing Money routes, workflow, exact-ledger boundary, and verification commands. |
| `/home/aUser/lifeManager/docs/foundation/START-HERE.md` | Foundation implementation-state reconciliation. |
| `/home/aUser/lifeManager/docs/foundation/PRODUCT.md` | Product status and implemented Money outcome. |
| `/home/aUser/lifeManager/docs/foundation/V1-SCOPE.md` | Implemented Money scope and explicit non-goals. |
| `/home/aUser/lifeManager/docs/foundation/DOMAIN.md` | Transaction invariants and exact monthly semantics. |
| `/home/aUser/lifeManager/docs/foundation/DESIGN.md` | Money pages, accessibility, and navigation behavior. |
| `/home/aUser/lifeManager/docs/foundation/ARCHITECTURE.md` | Independent Money ownership and Core summary boundary. |
| `/home/aUser/lifeManager/docs/foundation/ENGINEERING.md` | Test, privacy, disposable database, and manual-verification boundaries. |
| `/home/aUser/lifeManager/docs/foundation/LESSONS.md` | Only implementation lessons actually learned; no speculative additions. |
| `/home/aUser/lifeManager/docs/verification/2026-09-25-money-slice.md` | Exact command results, warnings, HTTP workflow evidence, review disposition, and seven manual gaps. |

## Task 1: Transaction Persistence and Initial Migration

**Files:**
- Create: `/home/aUser/lifeManager/lifeos/money/models.py`
- Create: `/home/aUser/lifeManager/lifeos/money/migrations/__init__.py`
- Create: `/home/aUser/lifeManager/lifeos/money/migrations/0001_initial.py`
- Create: `/home/aUser/lifeManager/tests/money/test_models.py`

**Interfaces:**
- Consumes: Django `models.Model`, `models.TextChoices`, `Decimal`, `MinValueValidator`, `MaxValueValidator`, and `MaxLengthValidator`.
- Produces:
  - `class Transaction(models.Model)`
  - `Transaction.Direction.INCOME == "income"` and `Transaction.Direction.EXPENSE == "expense"`
  - Fields `transaction_date: date`, `direction: str`, `amount: Decimal`, `category: str`, `note: str`, `created_at: datetime`, `updated_at: datetime`
  - Default ordering `("-transaction_date", "-created_at", "-pk")`
  - Constraints `money_transaction_amount_min` and `money_transaction_amount_max`

- [ ] **Step 1: Write the failing model and migration tests**

Create tests that explicitly cover both valid bounds, direct database rejection at both invalid bounds, unknown direction, future dates, duplicates, scale/non-finite/exponent inputs, trimming, lengths, timezone-aware timestamps, ordering, and migration drift. Representative tests:

```python
from datetime import date, timedelta
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

from lifeos.money.models import Transaction

pytestmark = pytest.mark.django_db


def make_transaction(**overrides):
    values = {
        "transaction_date": date(2026, 9, 25),
        "direction": Transaction.Direction.EXPENSE,
        "amount": Decimal("12.34"),
        "category": "Groceries",
        "note": "",
    }
    values.update(overrides)
    return Transaction(**values)


@pytest.mark.parametrize("amount", [Decimal("0.01"), Decimal("999999999.99")])
def test_amount_boundaries_are_valid(amount):
    item = make_transaction(amount=amount)
    item.full_clean()
    item.save()
    assert Transaction.objects.get(pk=item.pk).amount == amount


@pytest.mark.parametrize(
    "amount",
    [
        Decimal("0"),
        Decimal("-0.01"),
        Decimal("1000000000.00"),
        Decimal("1.001"),
        Decimal("1E+2"),
        Decimal("NaN"),
        Decimal("Infinity"),
    ],
)
def test_model_rejects_invalid_amounts(amount):
    with pytest.raises(ValidationError) as error:
        make_transaction(amount=amount).full_clean()
    assert "amount" in error.value.message_dict


@pytest.mark.parametrize("amount", [Decimal("0.00"), Decimal("1000000000.00")])
def test_database_constraints_reject_out_of_range_amounts(amount):
    with pytest.raises(IntegrityError), transaction.atomic():
        Transaction.objects.create(
            transaction_date=date(2026, 9, 25),
            direction="income",
            amount=amount,
            category="Salary",
        )


def test_text_is_trimmed_and_blank_note_normalizes_to_empty():
    item = make_transaction(category="  Groceries  ", note="   ")
    item.full_clean()
    assert item.category == "Groceries"
    assert item.note == ""


def test_future_dates_and_identical_transactions_are_allowed():
    future = date.today() + timedelta(days=30)
    first = make_transaction(transaction_date=future)
    second = make_transaction(transaction_date=future)
    for item in (first, second):
        item.full_clean()
        item.save()
    assert Transaction.objects.filter(transaction_date=future).count() == 2


def test_timestamps_and_default_ordering():
    old = make_transaction(transaction_date=date(2026, 9, 24))
    old.save()
    first = make_transaction()
    first.save()
    second = make_transaction()
    second.save()
    assert timezone.is_aware(second.created_at)
    assert timezone.is_aware(second.updated_at)
    assert list(Transaction.objects.values_list("pk", flat=True)) == [
        second.pk,
        first.pk,
        old.pk,
    ]
```

Also assert category lengths `1` and `80` pass, `0` after trimming and `81` fail; note length `500` passes and `501` fails; missing date fails; exact direction choices equal `[("income", "Income"), ("expense", "Expense")]`.

- [ ] **Step 2: Run the tests to verify RED**

Run:

```bash
uv run pytest tests/money/test_models.py -q
```

Expected: collection fails because `lifeos.money.models` and `Transaction` do not exist.

- [ ] **Step 3: Implement the minimal model and reviewed migration**

Implement the independent Money model:

```python
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MaxLengthValidator, MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import Q


class Transaction(models.Model):
    class Direction(models.TextChoices):
        INCOME = "income", "Income"
        EXPENSE = "expense", "Expense"

    transaction_date = models.DateField()
    direction = models.CharField(max_length=7, choices=Direction.choices)
    amount = models.DecimalField(
        max_digits=11,
        decimal_places=2,
        validators=[
            MinValueValidator(Decimal("0.01")),
            MaxValueValidator(Decimal("999999999.99")),
        ],
    )
    category = models.CharField(max_length=80)
    note = models.TextField(
        blank=True,
        default="",
        max_length=500,
        validators=[MaxLengthValidator(500)],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-transaction_date", "-created_at", "-pk")
        constraints = [
            models.CheckConstraint(
                condition=Q(amount__gte=Decimal("0.01")),
                name="money_transaction_amount_min",
            ),
            models.CheckConstraint(
                condition=Q(amount__lte=Decimal("999999999.99")),
                name="money_transaction_amount_max",
            ),
        ]

    def clean_fields(self, exclude=None):
        self.category = (self.category or "").strip()
        self.note = (self.note or "").strip()
        super().clean_fields(exclude=exclude)
        if self.amount is not None:
            if not self.amount.is_finite() or self.amount.as_tuple().exponent > 0:
                raise ValidationError({"amount": "Enter a positive euro amount with at most two decimal places."})
```

Generate the migration with:

```bash
uv run python manage.py makemigrations money
```

Review `0001_initial.py` to confirm `max_digits=11`, `decimal_places=2`, both exact named constraints, all fields, timestamps, and ordering. Do not hand-edit unrelated migration state.

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```bash
uv run pytest tests/money/test_models.py -q
uv run python manage.py makemigrations --check --dry-run
```

Expected: all model tests pass and Django reports no migration changes.

- [ ] **Step 5: Run the full relevant suite**

Run:

```bash
uv run pytest tests/money/test_models.py tests/test_settings.py -q
uv run pytest -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/money/models.py lifeos/money/migrations/__init__.py lifeos/money/migrations/0001_initial.py tests/money/test_models.py
git commit -m "feat(money): add transaction persistence" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 2: Exact Monthly Calculations and Euro Formatting

**Files:**
- Create: `/home/aUser/lifeManager/lifeos/money/calculations.py`
- Create: `/home/aUser/lifeManager/tests/money/test_calculations.py`

**Interfaces:**
- Consumes: `Iterable[TransactionAmountInput]`, where each item contains `direction: str` and `amount: Decimal`.
- Produces:
  - `@dataclass(frozen=True, slots=True) class TransactionAmountInput`
  - `@dataclass(frozen=True, slots=True) class MonthlyMovement`
  - `calculate_monthly_movement(records: Iterable[TransactionAmountInput]) -> MonthlyMovement`
  - `format_euros(value: Decimal) -> str`

- [ ] **Step 1: Write the failing pure tests**

```python
from dataclasses import FrozenInstanceError
from decimal import Decimal

import pytest

from lifeos.money.calculations import (
    MonthlyMovement,
    TransactionAmountInput,
    calculate_monthly_movement,
    format_euros,
)


def row(direction, amount):
    return TransactionAmountInput(direction, Decimal(amount))


def test_empty_month_is_exact_zero():
    result = calculate_monthly_movement(())
    assert result == MonthlyMovement(
        count=0,
        inflow=Decimal("0.00"),
        outflow=Decimal("0.00"),
        net_movement=Decimal("0.00"),
    )


@pytest.mark.parametrize(
    ("records", "expected"),
    [
        ((row("income", "10.005"),), (1, "10.01", "0.00", "10.01")),
        ((row("expense", "2.005"),), (1, "0.00", "2.01", "-2.01")),
        (
            (row("income", "10.00"), row("expense", "4.25")),
            (2, "10.00", "4.25", "5.75"),
        ),
        (
            (row("income", "4.25"), row("expense", "4.25")),
            (2, "4.25", "4.25", "0.00"),
        ),
    ],
)
def test_named_outputs_are_independently_quantized(records, expected):
    result = calculate_monthly_movement(records)
    assert (
        result.count,
        str(result.inflow),
        str(result.outflow),
        str(result.net_movement),
    ) == expected


def test_inputs_are_materialized_without_mutation_and_result_is_frozen():
    records = [row("income", "0.10"), row("income", "0.20")]
    result = calculate_monthly_movement(records)
    assert records == [row("income", "0.10"), row("income", "0.20")]
    assert result.inflow == Decimal("0.30")
    with pytest.raises(FrozenInstanceError):
        result.count = 3


@pytest.mark.parametrize(
    ("value", "formatted"),
    [
        (Decimal("12"), "€12.00"),
        (Decimal("0"), "€0.00"),
        (Decimal("-12.345"), "-€12.35"),
    ],
)
def test_format_euros_has_symbol_two_places_and_negative_sign(value, formatted):
    assert format_euros(value) == formatted
```

- [ ] **Step 2: Run the tests to verify RED**

```bash
uv run pytest tests/money/test_calculations.py -q
```

Expected: import failure because the calculation module does not exist.

- [ ] **Step 3: Implement the exact pure calculation boundary**

```python
from collections.abc import Iterable
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

ZERO = Decimal("0.00")
CENT = Decimal("0.01")


@dataclass(frozen=True, slots=True)
class TransactionAmountInput:
    direction: str
    amount: Decimal


@dataclass(frozen=True, slots=True)
class MonthlyMovement:
    count: int
    inflow: Decimal
    outflow: Decimal
    net_movement: Decimal


def _display(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def calculate_monthly_movement(
    records: Iterable[TransactionAmountInput],
) -> MonthlyMovement:
    snapshot = tuple(records)
    exact_inflow = sum(
        (record.amount for record in snapshot if record.direction == "income"),
        start=ZERO,
    )
    exact_outflow = sum(
        (record.amount for record in snapshot if record.direction == "expense"),
        start=ZERO,
    )
    return MonthlyMovement(
        count=len(snapshot),
        inflow=_display(exact_inflow),
        outflow=_display(exact_outflow),
        net_movement=_display(exact_inflow - exact_outflow),
    )


def format_euros(value: Decimal) -> str:
    displayed = _display(value)
    if displayed < ZERO:
        return f"-€{abs(displayed):.2f}"
    return f"€{displayed:.2f}"
```

Do not accept floats and do not import models or Work code.

- [ ] **Step 4: Run focused tests to verify GREEN**

```bash
uv run pytest tests/money/test_calculations.py -q
```

Expected: all calculation tests pass.

- [ ] **Step 5: Run the full relevant suite**

```bash
uv run pytest tests/money/test_models.py tests/money/test_calculations.py -q
uv run pytest -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/money/calculations.py tests/money/test_calculations.py
git commit -m "feat(money): derive exact monthly movement" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 3: Money-Owned Month Selection, Navigation, and Snapshot Queries

**Files:**
- Create: `/home/aUser/lifeManager/lifeos/money/queries.py`
- Create: `/home/aUser/lifeManager/tests/money/test_queries.py`

**Interfaces:**
- Consumes: `Transaction`, canonical `today: date`, and raw `month: str | None`.
- Produces:
  - `MONTH_ERROR = "Enter a month in YYYY-MM format."`
  - `@dataclass(frozen=True, slots=True) class CalendarMonth`
  - `@dataclass(frozen=True, slots=True) class MonthSelection`
  - `select_month(raw_value: str | None, *, today: date) -> MonthSelection`
  - `transactions_for_month(month: CalendarMonth) -> QuerySet[Transaction]`
  - `transaction_snapshot_for_month(month: CalendarMonth) -> tuple[Transaction, ...]`

- [ ] **Step 1: Write failing month and query tests**

```python
from datetime import date
from decimal import Decimal

import pytest

from lifeos.money.models import Transaction
from lifeos.money.queries import CalendarMonth, MONTH_ERROR, select_month, transaction_snapshot_for_month

pytestmark = pytest.mark.django_db


@pytest.mark.parametrize("raw", ["bad", "2026-9", "0000-01", "0001-12", "9999-01"])
def test_invalid_or_unnavigable_month_falls_back_generically(raw):
    selection = select_month(raw, today=date(2026, 9, 25))
    assert selection.month == CalendarMonth(2026, 9)
    assert selection.error == MONTH_ERROR


@pytest.mark.parametrize(
    ("month", "previous", "next_value"),
    [
        (CalendarMonth(2, 1), "0001-12", "0002-02"),
        (CalendarMonth(9998, 12), "9998-11", "9999-01"),
        (CalendarMonth(2026, 12), "2026-11", "2027-01"),
    ],
)
def test_navigation_is_constructible_at_every_accepted_bound(month, previous, next_value):
    assert month.previous().value == previous
    assert month.next().value == next_value


def test_half_open_snapshot_handles_leap_february_and_orders_rows():
    def create(day, category):
        return Transaction.objects.create(
            transaction_date=day,
            direction="expense",
            amount=Decimal("1.00"),
            category=category,
        )

    create(date(2028, 2, 1), "first")
    older = create(date(2028, 2, 29), "older")
    newer = create(date(2028, 2, 29), "newer")
    create(date(2028, 3, 1), "excluded")

    snapshot = transaction_snapshot_for_month(CalendarMonth(2028, 2))
    assert [item.pk for item in snapshot] == [newer.pk, older.pk, 1]
    assert all(item.transaction_date < date(2028, 3, 1) for item in snapshot)
```

Also test absent input returns current month with `error is None`, exact `0002-01` and `9998-12` are accepted, malformed values are never echoed, and the query bounds are `>= first_day` and `< next_first_day`.

- [ ] **Step 2: Run the tests to verify RED**

```bash
uv run pytest tests/money/test_queries.py -q
```

Expected: import failure because `lifeos.money.queries` does not exist.

- [ ] **Step 3: Implement the Money-owned month type and query functions**

Implement `CalendarMonth` locally rather than importing or moving Work’s type:

```python
import re
from dataclasses import dataclass
from datetime import date

from django.db.models import QuerySet

from .models import Transaction

MONTH_PATTERN = re.compile(r"^(?P<year>\d{4})-(?P<month>0[1-9]|1[0-2])$")
MONTH_ERROR = "Enter a month in YYYY-MM format."


@dataclass(frozen=True, slots=True)
class CalendarMonth:
    year: int
    month: int

    @property
    def value(self) -> str:
        return f"{self.year:04d}-{self.month:02d}"

    @property
    def label(self) -> str:
        return self.first_day.strftime("%B %Y")

    @property
    def first_day(self) -> date:
        return date(self.year, self.month, 1)

    @property
    def next_first_day(self) -> date:
        return self.next().first_day

    def previous(self) -> "CalendarMonth":
        if self.month == 1:
            return CalendarMonth(self.year - 1, 12)
        return CalendarMonth(self.year, self.month - 1)

    def next(self) -> "CalendarMonth":
        if self.month == 12:
            return CalendarMonth(self.year + 1, 1)
        return CalendarMonth(self.year, self.month + 1)


@dataclass(frozen=True, slots=True)
class MonthSelection:
    month: CalendarMonth
    error: str | None


def select_month(raw_value: str | None, *, today: date) -> MonthSelection:
    fallback = CalendarMonth(today.year, today.month)
    if raw_value is None:
        return MonthSelection(fallback, None)
    match = MONTH_PATTERN.fullmatch(raw_value)
    if match is None:
        return MonthSelection(fallback, MONTH_ERROR)
    year = int(match["year"])
    if not 2 <= year <= 9998:
        return MonthSelection(fallback, MONTH_ERROR)
    return MonthSelection(CalendarMonth(year, int(match["month"])), None)


def transactions_for_month(month: CalendarMonth) -> QuerySet[Transaction]:
    return Transaction.objects.filter(
        transaction_date__gte=month.first_day,
        transaction_date__lt=month.next_first_day,
    )


def transaction_snapshot_for_month(month: CalendarMonth) -> tuple[Transaction, ...]:
    return tuple(transactions_for_month(month))
```

- [ ] **Step 4: Run focused tests to verify GREEN**

```bash
uv run pytest tests/money/test_queries.py -q
```

Expected: all query tests pass.

- [ ] **Step 5: Run the full relevant suite**

```bash
uv run pytest tests/money/test_models.py tests/money/test_calculations.py tests/money/test_queries.py -q
uv run pytest -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/money/queries.py tests/money/test_queries.py
git commit -m "feat(money): add safe monthly queries" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 4: Create and GET-Only Canonical Review

**Files:**
- Create: `/home/aUser/lifeManager/lifeos/money/forms.py`
- Create: `/home/aUser/lifeManager/lifeos/money/views.py`
- Create: `/home/aUser/lifeManager/lifeos/money/urls.py`
- Create: `/home/aUser/lifeManager/templates/money/_transaction_form.html`
- Create: `/home/aUser/lifeManager/templates/money/transaction_form.html`
- Create: `/home/aUser/lifeManager/templates/money/transaction_detail.html`
- Create: `/home/aUser/lifeManager/templates/money/register.html`
- Create: `/home/aUser/lifeManager/templates/money/register_unavailable.html`
- Create: `/home/aUser/lifeManager/tests/money/test_create_detail.py`
- Modify: `/home/aUser/lifeManager/lifeos/urls.py`

**Interfaces:**
- Consumes: `Transaction`, `transaction.atomic`, Django forms/messages/render/redirect/reverse, and exact optional `date=YYYY-MM-DD`.
- Produces:
  - `class StrictMoneyDecimalField(forms.DecimalField)`
  - `class TransactionForm(forms.ModelForm)`
  - `_prefill_date(raw_value: str | None) -> date | None`
  - `_log_database_failure(operation: str, error: DatabaseError) -> None`
  - `_unavailable_response(request: HttpRequest) -> HttpResponse`
  - `transaction_create(request: HttpRequest) -> HttpResponse`
  - `transaction_detail(request: HttpRequest, pk: int) -> HttpResponse`
  - Namespace `money` and all approved route names, with `money:register` initially rendering the honest empty/current-month shell for later expansion.

- [ ] **Step 1: Write failing route, form, create, detail, and failure tests**

Include exact route/path assertions and allowed-method assertions. Representative tests:

```python
from contextlib import contextmanager
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.urls import reverse

from lifeos.money.forms import TransactionForm
from lifeos.money.models import Transaction

pytestmark = pytest.mark.django_db

VALID = {
    "transaction_date": "2026-09-25",
    "direction": "expense",
    "amount": "12.34",
    "category": "  Groceries  ",
    "note": "  private note  ",
}


@pytest.mark.parametrize("method", ["post", "put", "patch", "delete"])
def test_detail_is_explicitly_get_only(client, method):
    item = Transaction.objects.create(
        transaction_date=date(2026, 9, 25),
        direction="income",
        amount=Decimal("10.00"),
        category="Salary",
    )
    assert getattr(client, method)(reverse("money:transaction-detail", args=[item.pk])).status_code == 405


@pytest.mark.parametrize(
    "amount",
    ["0", "-0.01", "1e2", "NaN", "Infinity", "1.001", "1,00", "1000000000.00"],
)
def test_create_rejects_unsafe_amount_text(client, amount):
    response = client.post(reverse("money:transaction-create"), {**VALID, "amount": amount})
    assert response.status_code == 200
    assert Transaction.objects.count() == 0
    assert "amount" in response.context["form"].errors


def test_create_redirects_to_canonical_detail_and_trims_text(client):
    response = client.post(reverse("money:transaction-create"), VALID)
    item = Transaction.objects.get()
    assert response.status_code == 302
    assert response.url == reverse("money:transaction-detail", args=[item.pk])
    assert item.category == "Groceries"
    assert item.note == "private note"


def test_detail_lookup_database_failure_is_503_not_false_404(client, monkeypatch, caplog):
    monkeypatch.setattr(
        "lifeos.money.views.get_object_or_404",
        lambda *args, **kwargs: (_ for _ in ()).throw(
            DatabaseError("private date amount /private/database")
        ),
    )
    response = client.get(reverse("money:transaction-detail", args=[1]))
    assert response.status_code == 503
    assert "DatabaseError" in caplog.text
    assert "private date amount" not in caplog.text
    assert "/private/database" not in caplog.text


def test_create_validation_database_failure_is_safe(client, monkeypatch):
    def fail_validation(self, *, exclude=None):
        raise DatabaseError("private validation")

    monkeypatch.setattr(Transaction, "validate_constraints", fail_validation)
    response = client.post(reverse("money:transaction-create"), VALID)
    assert response.status_code == 200
    assert response.context["form"].non_field_errors() == [
        "The transaction could not be saved. Please try again."
    ]
    assert Transaction.objects.count() == 0


def test_create_atomic_exit_failure_has_no_false_success(client, monkeypatch):
    @contextmanager
    def fail_on_exit():
        yield
        raise DatabaseError("private commit outcome")

    monkeypatch.setattr("lifeos.money.views.transaction.atomic", fail_on_exit)
    response = client.post(reverse("money:transaction-create"), VALID)
    assert response.status_code == 200
    assert "Transaction created." not in response.content.decode()
    assert "inspect the Money register before retrying" in response.content.decode()
```

Also test one `TransactionForm.save()` call, one `transaction.atomic()` entry, save failure, real absence as 404, unexpected exception propagation, exact/future prefill, malformed prefill ignored without error, GET creates nothing, CSRF enforcement, escaped category/note, empty note presentation, one `<main>` and one `<h1>`, hints preceding errors, linked summary for multiple errors, and generic logs containing operation/domain/class only.

- [ ] **Step 2: Run the tests to verify RED**

```bash
uv run pytest tests/money/test_create_detail.py -q
```

Expected: imports/routes fail because forms, views, URLs, and templates do not exist.

- [ ] **Step 3: Implement strict form parsing and create/detail orchestration**

Use a raw lexical check before `DecimalField` conversion:

```python
import re
from django import forms
from .models import Transaction

MONEY_PATTERN = re.compile(r"^(?:0|[1-9]\d*)(?:\.\d{1,2})?$")


class StrictMoneyDecimalField(forms.DecimalField):
    def to_python(self, value):
        if isinstance(value, str) and not MONEY_PATTERN.fullmatch(value):
            raise forms.ValidationError(
                "Enter a positive euro amount with at most two decimal places."
            )
        return super().to_python(value)


class TransactionForm(forms.ModelForm):
    amount = StrictMoneyDecimalField(
        min_value=Decimal("0.01"),
        max_value=Decimal("999999999.99"),
        max_digits=11,
        decimal_places=2,
    )

    def full_clean(self):
        super().full_clean()
        for name, field in self.fields.items():
            described_by = [f"id_{name}_hint"]
            if name in self.errors:
                field.widget.attrs["aria-invalid"] = "true"
                described_by.append(f"id_{name}_error")
            field.widget.attrs["aria-describedby"] = " ".join(described_by)

    class Meta:
        model = Transaction
        fields = ("transaction_date", "direction", "amount", "category", "note")
```

In `views.py`, decorate create with `@require_http_methods(["GET", "POST"])` and detail with `@require_GET`. Wrap detail lookup in `try/except DatabaseError`. For create POST, wrap both `form.is_valid()` and the entire `with transaction.atomic(): form.save()` in one `try`; catch `DatabaseError` outside the `with` so atomic-exit failures are caught. Add `Transaction created.` and redirect only in the `else` branch after the context has returned successfully. For an atomic-exit error use recovery text that tells the owner to inspect the Money register before retrying; do not claim a definite save failure if commit outcome cannot be established.

Use this logging shape only:

```python
def _log_database_failure(operation: str, error: DatabaseError) -> None:
    logger.warning("Money %s failed (%s)", operation, type(error).__name__)
```

Never pass `error`, request data, query strings, model identifiers, or `exc_info=True` as log content.

Add all five URL patterns now so route names stabilize. Create `money/register.html` as an honest shell with the page heading and a statement that no monthly totals are available yet. The minimal GET-only register view may render that shell until Task 7 replaces its orchestration; it must not present invented totals or mutate state.

Templates must rely on Django autoescaping and must not use `safe`. The detail page displays date, direction text, category, amount via `format_euros` prepared by the view, and either the note or factual “No note recorded.”

- [ ] **Step 4: Run focused tests to verify GREEN**

```bash
uv run pytest tests/money/test_create_detail.py -q
```

Expected: all create/detail tests pass, including 405, lookup, validation, save, and atomic-exit cases.

- [ ] **Step 5: Run the full relevant suite**

```bash
uv run pytest tests/money/test_models.py tests/money/test_calculations.py tests/money/test_queries.py tests/money/test_create_detail.py -q
uv run pytest -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/urls.py lifeos/money/forms.py lifeos/money/views.py lifeos/money/urls.py templates/money/_transaction_form.html templates/money/transaction_form.html templates/money/transaction_detail.html templates/money/register.html templates/money/register_unavailable.html tests/money/test_create_detail.py
git commit -m "feat(money): add create and review workflow" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 5: Edit Workflow and Database Failure Boundaries

**Files:**
- Modify: `/home/aUser/lifeManager/lifeos/money/views.py`
- Modify: `/home/aUser/lifeManager/templates/money/transaction_form.html`
- Create: `/home/aUser/lifeManager/tests/money/test_edit.py`

**Interfaces:**
- Consumes: `TransactionForm(instance=transaction)`, `_unavailable_response`, `_log_database_failure`, and route `money:transaction-detail`.
- Produces: `transaction_edit(request: HttpRequest, pk: int) -> HttpResponse`.

- [ ] **Step 1: Write failing edit and independent failure-boundary tests**

```python
from contextlib import contextmanager
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.urls import reverse

from lifeos.money.forms import TransactionForm
from lifeos.money.models import Transaction

pytestmark = pytest.mark.django_db


def make_transaction():
    return Transaction.objects.create(
        transaction_date=date(2026, 9, 25),
        direction="expense",
        amount=Decimal("12.34"),
        category="Before",
        note="before",
    )


def update_data(**overrides):
    values = {
        "transaction_date": "2026-09-26",
        "direction": "income",
        "amount": "20.00",
        "category": "After",
        "note": "after",
    }
    values.update(overrides)
    return values


def test_edit_get_is_populated_without_mutation(client):
    item = make_transaction()
    response = client.get(reverse("money:transaction-edit", args=[item.pk]))
    item.refresh_from_db()
    assert response.status_code == 200
    assert response.context["form"].instance == item
    assert item.category == "Before"


def test_valid_edit_saves_once_and_redirects_to_detail(client, monkeypatch):
    item = make_transaction()
    original = TransactionForm.save
    calls = 0

    def counted_save(self):
        nonlocal calls
        calls += 1
        return original(self)

    monkeypatch.setattr(TransactionForm, "save", counted_save)
    response = client.post(reverse("money:transaction-edit", args=[item.pk]), update_data())
    item.refresh_from_db()
    assert calls == 1
    assert response.url == reverse("money:transaction-detail", args=[item.pk])
    assert item.category == "After"


def test_edit_atomic_exit_failure_has_no_success(client, monkeypatch):
    item = make_transaction()

    @contextmanager
    def fail_on_exit():
        yield
        raise DatabaseError("private commit")

    monkeypatch.setattr("lifeos.money.views.transaction.atomic", fail_on_exit)
    response = client.post(reverse("money:transaction-edit", args=[item.pk]), update_data())
    assert response.status_code == 200
    assert "Transaction updated." not in response.content.decode()
    assert "inspect the Money register before retrying" in response.content.decode()
```

Add separate tests for GET/POST missing record 404, lookup `DatabaseError` 503, constraint-validation `DatabaseError`, form save `DatabaseError`, invalid form preserving safe values and persisted record, exactly one atomic boundary, no success before commit, CSRF, method 405, class-only logging, and unexpected exception propagation.

- [ ] **Step 2: Run the tests to verify RED**

```bash
uv run pytest tests/money/test_edit.py -q
```

Expected: edit behavior fails because the route still lacks complete orchestration.

- [ ] **Step 3: Implement the edit workflow**

Lookup inside its own `try/except DatabaseError`; return Money’s 503 response for database failure and preserve ordinary `Http404` for absence. Bind `TransactionForm(request.POST or None, instance=item)`. On POST, wrap `form.is_valid()` and the entire atomic block, save exactly once, and add `Transaction updated.` only after the context returns. Reuse the form template with `page_title="Edit transaction"` and `submit_label="Save changes"`.

- [ ] **Step 4: Run focused tests to verify GREEN**

```bash
uv run pytest tests/money/test_edit.py -q
```

Expected: all edit tests pass.

- [ ] **Step 5: Run the full relevant suite**

```bash
uv run pytest tests/money/test_create_detail.py tests/money/test_edit.py -q
uv run pytest -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/money/views.py templates/money/transaction_form.html tests/money/test_edit.py
git commit -m "feat(money): add transaction editing" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 6: Confirmed Hard Delete and Selected-Month Redirect

**Files:**
- Modify: `/home/aUser/lifeManager/lifeos/money/views.py`
- Create: `/home/aUser/lifeManager/templates/money/transaction_confirm_delete.html`
- Create: `/home/aUser/lifeManager/tests/money/test_delete.py`

**Interfaces:**
- Consumes: `Transaction`, `transaction.atomic`, `_unavailable_response`, `_log_database_failure`, and `money:register`.
- Produces: `transaction_delete(request: HttpRequest, pk: int) -> HttpResponse`, POST redirect `/money/?month=YYYY-MM`.

- [ ] **Step 1: Write failing confirmation, deletion, and failure tests**

```python
from contextlib import contextmanager
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.urls import reverse

from lifeos.money.models import Transaction

pytestmark = pytest.mark.django_db


def make_transaction():
    return Transaction.objects.create(
        transaction_date=date(2026, 9, 25),
        direction="expense",
        amount=Decimal("12.34"),
        category="Groceries",
        note="private-delete-note",
    )


def test_delete_get_identifies_without_note_and_never_mutates(client):
    item = make_transaction()
    response = client.get(reverse("money:transaction-delete", args=[item.pk]))
    html = response.content.decode()
    assert response.status_code == 200
    assert "25 September 2026" in html
    assert "Expense" in html
    assert "Groceries" in html
    assert "private-delete-note" not in html
    assert Transaction.objects.filter(pk=item.pk).exists()


def test_delete_post_hard_deletes_and_redirects_to_original_month(client):
    item = make_transaction()
    response = client.post(reverse("money:transaction-delete", args=[item.pk]))
    assert response.status_code == 302
    assert response.url == "/money/?month=2026-09"
    assert not Transaction.objects.filter(pk=item.pk).exists()


def test_delete_execution_database_failure_rolls_back(client, monkeypatch):
    item = make_transaction()

    def fail_delete(self):
        raise DatabaseError("private delete /private/path")

    monkeypatch.setattr(Transaction, "delete", fail_delete)
    response = client.post(reverse("money:transaction-delete", args=[item.pk]))
    assert response.status_code == 200
    assert Transaction.objects.filter(pk=item.pk).exists()
    assert "The transaction could not be deleted. Please try again." in response.content.decode()
    assert "Transaction deleted." not in response.content.decode()


def test_delete_atomic_exit_failure_preserves_safe_identity(client, monkeypatch):
    item = make_transaction()
    original_pk = item.pk

    @contextmanager
    def fail_on_exit():
        yield
        raise DatabaseError("private commit")

    monkeypatch.setattr("lifeos.money.views.transaction.atomic", fail_on_exit)
    response = client.post(reverse("money:transaction-delete", args=[original_pk]))
    html = response.content.decode()
    assert response.status_code == 200
    assert reverse("money:transaction-detail", args=[original_pk]) in html
    assert "inspect the Money register before retrying" in html
    assert "Transaction deleted." not in html
```

Add GET/POST missing 404, lookup `DatabaseError` 503, one delete call, one atomic entry, POST-only mutation, CSRF, unsupported methods 405, success message only after commit, safe class-only log assertions, and unexpected exception propagation.

- [ ] **Step 2: Run the tests to verify RED**

```bash
uv run pytest tests/money/test_delete.py -q
```

Expected: delete tests fail because confirmation and deletion are not implemented.

- [ ] **Step 3: Implement confirmed hard delete**

Capture `selected_month`, original primary key, date, direction label, and category before deletion. On valid POST run exactly one `item.delete()` inside one explicit outer atomic block. Catch `DatabaseError` around the full `with`; restore the in-memory primary key if Django cleared it, render the confirmation with safe identity, and show the exact delete failure plus atomic-outcome recovery wording where appropriate. Add `Transaction deleted.` and redirect only after successful atomic exit:

```python
return redirect(f"{reverse('money:register')}?month={selected_month}")
```

The confirmation template must not display the note, must use a POST form with CSRF token, and must label the destructive button “Delete transaction.”

- [ ] **Step 4: Run focused tests to verify GREEN**

```bash
uv run pytest tests/money/test_delete.py -q
```

Expected: all delete tests pass.

- [ ] **Step 5: Run the full relevant suite**

```bash
uv run pytest tests/money/test_create_detail.py tests/money/test_edit.py tests/money/test_delete.py -q
uv run pytest -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/money/views.py templates/money/transaction_confirm_delete.html tests/money/test_delete.py
git commit -m "feat(money): add confirmed transaction deletion" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 7: Monthly Register, One-Snapshot Totals, and Unavailable State

**Files:**
- Modify: `/home/aUser/lifeManager/lifeos/money/views.py`
- Create or replace: `/home/aUser/lifeManager/templates/money/register.html`
- Modify: `/home/aUser/lifeManager/templates/money/register_unavailable.html`
- Modify: `/home/aUser/lifeManager/static/css/app.css`
- Create: `/home/aUser/lifeManager/tests/money/test_register.py`

**Interfaces:**
- Consumes:
  - `select_month(raw_value: str | None, *, today: date) -> MonthSelection`
  - `transaction_snapshot_for_month(month: CalendarMonth) -> tuple[Transaction, ...]`
  - `calculate_monthly_movement(records: Iterable[TransactionAmountInput]) -> MonthlyMovement`
  - `format_euros(value: Decimal) -> str`
  - `get_clock().today() -> date`
- Produces: GET-only `register(request: HttpRequest) -> HttpResponse` with context `month`, `month_error`, `previous_month`, `next_month`, `transactions`, `movement`, and preformatted monetary values.

- [ ] **Step 1: Write failing register and one-snapshot tests**

```python
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.urls import reverse

from lifeos.core.clock import override_clock
from lifeos.money.models import Transaction

pytestmark = pytest.mark.django_db


class FixedClock:
    def __init__(self, value):
        self.value = value
        self.calls = 0

    def today(self):
        self.calls += 1
        return self.value


def create_item(day, direction, amount, category, note="private-register-note"):
    return Transaction.objects.create(
        transaction_date=day,
        direction=direction,
        amount=Decimal(amount),
        category=category,
        note=note,
    )


def test_register_uses_one_snapshot_for_rows_and_totals(client, monkeypatch):
    snapshot = (
        create_item(date(2026, 9, 25), "income", "100.00", "Salary"),
        create_item(date(2026, 9, 24), "expense", "25.25", "Food"),
    )
    calls = 0

    def one_snapshot(month):
        nonlocal calls
        calls += 1
        if calls > 1:
            raise AssertionError("month queried twice")
        return snapshot

    monkeypatch.setattr("lifeos.money.views.transaction_snapshot_for_month", one_snapshot)
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("money:register"))
    assert calls == 1
    assert response.context["movement"].count == 2
    assert response.context["movement"].inflow == Decimal("100.00")
    assert response.context["movement"].outflow == Decimal("25.25")
    assert response.context["movement"].net_movement == Decimal("74.75")


def test_register_table_has_only_approved_columns_and_no_notes(client):
    item = create_item(date(2026, 9, 25), "expense", "12.34", "<b>Food</b>")
    with override_clock(FixedClock(date(2026, 9, 25))):
        html = client.get(reverse("money:register")).content.decode()
    for heading in ("Date", "Direction", "Category", "Amount"):
        assert f">{heading}<" in html
    assert "&lt;b&gt;Food&lt;/b&gt;" in html
    assert "private-register-note" not in html
    assert reverse("money:transaction-detail", args=[item.pk]) in html
    for excluded in ("Search", "Filter", "Leading category", "<canvas", "<svg"):
        assert excluded not in html


def test_register_database_failure_returns_private_503(client, monkeypatch, caplog):
    def fail(month):
        raise DatabaseError("private 66.66 /private/register")

    monkeypatch.setattr("lifeos.money.views.transaction_snapshot_for_month", fail)
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("money:register"))
    assert response.status_code == 503
    assert "Money register is temporarily unavailable." in response.content.decode()
    assert "€0.00" not in response.content.decode()
    assert "DatabaseError" in caplog.text
    assert "private 66.66" not in caplog.text
```

Also test GET-only 405, one canonical clock read, empty month, exact invalid-month feedback without echo, `0002`/`9998` links, December rollover, leap month exclusion, deterministic row order, explicit Income/Expense text, `-€` negative movement, one `<main>`, one `<h1>`, labelled horizontal scroll region, no page-level scroll contract, 44px controls, and unexpected exception propagation.

- [ ] **Step 2: Run the tests to verify RED**

```bash
uv run pytest tests/money/test_register.py -q
```

Expected: the minimal register lacks snapshot totals and approved presentation.

- [ ] **Step 3: Implement register orchestration and presentation**

Call the clock once, select the month, materialize one tuple inside a `try/except DatabaseError`, then derive the `TransactionAmountInput` sequence and `MonthlyMovement` solely from that tuple. Do not issue an existence/count query and do not recalculate in the template.

Render:
- one selected-month heading;
- previous/next links;
- **New transaction**;
- generic invalid-month feedback;
- count, inflow, outflow, and net movement;
- exactly Date, Direction, Category, Amount columns;
- canonical detail links;
- no notes;
- an honest empty state.

Preformat all money through `format_euros`. Direction comes from `get_direction_display()`. Use `<div class="horizontal-scroll" role="region" aria-label="Transactions for …" tabindex="0">` only around the table. Extend existing CSS tokens and responsive conventions; do not add remote assets, charts, or client-side calculations.

- [ ] **Step 4: Run focused tests to verify GREEN**

```bash
uv run pytest tests/money/test_register.py -q
```

Expected: all register tests pass.

- [ ] **Step 5: Run the full relevant suite**

```bash
uv run pytest tests/money -q
uv run pytest tests/core tests/work -q
uv run pytest -q
```

Expected: all tests pass.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/money/views.py templates/money/register.html templates/money/register_unavailable.html static/css/app.css tests/money/test_register.py
git commit -m "feat(money): add monthly transaction register" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 8: Daily Register Summary and Resolved-Route Navigation Semantics

**Files:**
- Replace: `/home/aUser/lifeManager/lifeos/money/summary.py`
- Modify: `/home/aUser/lifeManager/templates/base.html`
- Modify: `/home/aUser/lifeManager/tests/money/test_summary.py`
- Modify: `/home/aUser/lifeManager/tests/core/test_dashboard.py`
- Modify: `/home/aUser/lifeManager/tests/core/test_views.py`

**Interfaces:**
- Consumes:
  - `transaction_snapshot_for_month(CalendarMonth(today.year, today.month))`
  - `calculate_monthly_movement(...)`
  - `format_euros(...)`
  - `RegisterSummary`, `LabelledValue`, and `SummaryUnavailable` from `lifeos.core.dashboard`
  - `request.resolver_match.url_name` and `request.resolver_match.namespace`
- Produces:
  - `get_summary(*, today: date) -> RegisterSummary`
  - Money register link and `?date=<canonical date>` quick action
  - Exactly one `aria-current="page"` on implemented top-level destinations.

- [ ] **Step 1: Write failing summary, isolation, clock, and navigation tests**

```python
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.urls import reverse

from lifeos.core.clock import override_clock
from lifeos.core.dashboard import SummaryUnavailable
from lifeos.money.models import Transaction
from lifeos.money.summary import get_summary

pytestmark = pytest.mark.django_db


def create_item(day, direction, amount):
    return Transaction.objects.create(
        transaction_date=day,
        direction=direction,
        amount=Decimal(amount),
        category="Private category",
    )


def test_ready_summary_has_exact_ordered_values_and_links():
    create_item(date(2026, 9, 25), "income", "100.00")
    create_item(date(2026, 9, 24), "expense", "25.25")
    summary = get_summary(today=date(2026, 9, 25))
    assert summary.href == "/money/"
    assert summary.action_href == "/money/transactions/new/?date=2026-09-25"
    assert [(item.label, item.value) for item in summary.values] == [
        ("Transactions", "2"),
        ("Inflow", "€100.00"),
        ("Outflow", "€25.25"),
        ("Net movement", "€74.75"),
    ]


def test_summary_materializes_one_snapshot(monkeypatch):
    rows = (create_item(date(2026, 9, 25), "expense", "12.34"),)
    calls = 0

    def one_snapshot(month):
        nonlocal calls
        calls += 1
        if calls > 1:
            raise AssertionError("summary queried twice")
        return rows

    monkeypatch.setattr("lifeos.money.summary.transaction_snapshot_for_month", one_snapshot)
    assert get_summary(today=date(2026, 9, 25)).state == "ready"
    assert calls == 1


def test_summary_database_error_becomes_safe_wrapper(monkeypatch):
    monkeypatch.setattr(
        "lifeos.money.summary.transaction_snapshot_for_month",
        lambda month: (_ for _ in ()).throw(DatabaseError("private summary")),
    )
    with pytest.raises(SummaryUnavailable) as error:
        get_summary(today=date(2026, 9, 25))
    assert "private summary" not in str(error.value)


@pytest.mark.parametrize(
    ("url_name", "expected_text"),
    [
        ("core:dashboard", "Daily register"),
        ("work:register", "Work"),
        ("work:shift-create", "Work"),
        ("money:register", "Money"),
        ("money:transaction-create", "Money"),
    ],
)
def test_exactly_one_primary_item_is_current(client, url_name, expected_text):
    response = client.get(reverse(url_name))
    html = response.content.decode()
    assert html.count('aria-current="page"') == 1
    current_start = html.index('aria-current="page"')
    assert expected_text in html[max(0, current_start - 100):current_start + 100]
```

Add detail/edit/delete page cases with existing records, non-current links having no `aria-current`, Habits remaining non-interactive, Core reading the clock once, Work/Money/Habits order, Money failure affecting only Money, expected class-only logging, and unexpected exception propagation.

- [ ] **Step 2: Run the tests to verify RED**

```bash
uv run pytest tests/money/test_summary.py tests/core/test_dashboard.py tests/core/test_views.py -q
```

Expected: Money remains an unlinked empty summary and the base template always marks Daily Register current.

- [ ] **Step 3: Implement the summary and route-identity navigation**

In `money/summary.py`, construct a Money `CalendarMonth`, materialize once, translate only `DatabaseError` to `SummaryUnavailable("Money summary unavailable")`, and let unexpected exceptions propagate. Empty and ready states both link to `/money/` and provide `New transaction` with the canonical date. Ready values must be the exact immutable order required by the spec.

Do not import `Transaction` or Money calculations into Core.

In `base.html`, use resolved route identity rather than path prefixes:

```django
{% with namespace=request.resolver_match.namespace url_name=request.resolver_match.url_name %}
  <a href="{% url 'core:dashboard' %}"{% if namespace == "core" and url_name == "dashboard" %} aria-current="page"{% endif %}>Daily register</a>
  <a href="{% url 'work:register' %}"{% if namespace == "work" %} aria-current="page"{% endif %}>Work</a>
  <a href="{% url 'money:register' %}"{% if namespace == "money" %} aria-current="page"{% endif %}>Money</a>
  <span>Habits</span>
{% endwith %}
```

Ensure `/ready/` does not acquire a false current marker; the exclusivity requirement applies to Daily Register, Work, and Money pages.

- [ ] **Step 4: Run focused tests to verify GREEN**

```bash
uv run pytest tests/money/test_summary.py tests/core/test_dashboard.py tests/core/test_views.py -q
```

Expected: all summary, failure-isolation, one-clock, and navigation tests pass.

- [ ] **Step 5: Run the full relevant suite**

```bash
uv run pytest tests/money tests/core tests/work -q
uv run pytest -q
```

Expected: all tests pass and existing Work behavior remains unchanged except corrected navigation semantics.

- [ ] **Step 6: Commit the task boundary**

```bash
git add lifeos/money/summary.py templates/base.html tests/money/test_summary.py tests/core/test_dashboard.py tests/core/test_views.py
git commit -m "feat(money): integrate daily summary and navigation" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Task 9: Documentation Reconciliation and Verification Receipt

**Files:**
- Modify: `/home/aUser/lifeManager/README.md`
- Modify: `/home/aUser/lifeManager/docs/foundation/START-HERE.md`
- Modify: `/home/aUser/lifeManager/docs/foundation/PRODUCT.md`
- Modify: `/home/aUser/lifeManager/docs/foundation/V1-SCOPE.md`
- Modify: `/home/aUser/lifeManager/docs/foundation/DOMAIN.md`
- Modify: `/home/aUser/lifeManager/docs/foundation/DESIGN.md`
- Modify: `/home/aUser/lifeManager/docs/foundation/ARCHITECTURE.md`
- Modify: `/home/aUser/lifeManager/docs/foundation/ENGINEERING.md`
- Modify only if a concrete lesson was learned: `/home/aUser/lifeManager/docs/foundation/LESSONS.md`
- Modify: `/home/aUser/lifeManager/tests/test_foundation_docs.py`
- Create: `/home/aUser/lifeManager/docs/verification/2026-09-25-money-slice.md`

**Interfaces:**
- Consumes: the implemented routes, model/calculation/query contracts, complete automated results, disposable-runtime results, HTTP workflow evidence, source scans, and review disposition.
- Produces: maintained documentation consistent with the implemented slice and an honest dated verification receipt.

- [ ] **Step 1: Write failing documentation contract tests**

Update the current Work-only contract rather than adding a contradictory second assertion:

```python
def test_docs_describe_implemented_work_and_money_slices() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    start_here = read_document("START-HERE.md")
    domain = read_document("DOMAIN.md")
    architecture = read_document("ARCHITECTURE.md")

    for path in ["/work/", "/money/", "/money/transactions/new/"]:
        assert path in readme
    for phrase in [
        "create",
        "review",
        "edit",
        "delete",
        "Inflow",
        "Outflow",
        "Net movement",
        "not an account balance",
    ]:
        assert phrase in readme
    assert "persisted Work and Money" in start_here
    assert "Habits remains an honest empty summary" in start_here
    for phrase in [
        "€0.01",
        "€999,999,999.99",
        "ROUND_HALF_UP",
        "income",
        "expense",
    ]:
        assert phrase in domain
    assert "Money never imports Work" in architecture


def test_engineering_retains_money_privacy_and_manual_boundaries() -> None:
    text = read_document("ENGINEERING.md")
    for phrase in [
        "owned disposable database",
        "no visual browser tests",
        "320 CSS pixels",
        "200% browser zoom",
        "text-spacing override",
        "keyboard traversal",
        "system/light/dark theme",
        "reduced-motion",
        "screen-reader smoke testing",
    ]:
        assert phrase in text
```

- [ ] **Step 2: Run documentation tests to verify RED**

```bash
uv run pytest tests/test_foundation_docs.py -q
```

Expected: the maintained documents still describe Money as empty/unimplemented.

- [ ] **Step 3: Reconcile documentation with the implemented behavior**

Update only maintained repository documentation. State:
- Money is an independent factual transaction ledger;
- exact validation bounds and positive unsigned storage;
- direction supplies financial meaning;
- monthly totals are derived from one snapshot;
- no account balance, budgeting, tax, forecasting, or bank-import claim;
- Money and Work remain independent;
- Habits remains empty;
- routes and no-JavaScript workflow;
- private data and owned database boundaries;
- no visual browser tests;
- seven manual gaps.

Do not consult `/home/aUser/improvedCalendar`. Do not modify the unrelated root `/home/aUser/lifeManager/PRODUCT.md`; the maintained file is `/home/aUser/lifeManager/docs/foundation/PRODUCT.md`.

- [ ] **Step 4: Run documentation tests to verify GREEN**

```bash
uv run pytest tests/test_foundation_docs.py -q
```

Expected: all documentation contracts pass.

- [ ] **Step 5: Run complete automated gates**

Run and record exact exit status, pass count, skips, and warnings:

```bash
uv run pytest tests/money -q
uv run pytest tests/core tests/work -q
uv run pytest tests/test_foundation_docs.py -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py check --deploy
uv run python manage.py makemigrations --check --dry-run
```

Expected:
- every pytest command passes;
- ordinary check reports no issues;
- deployment check may report the existing loopback-development warnings, which must be copied accurately and not represented as a production deployment pass;
- migration drift check reports no changes.

- [ ] **Step 6: Verify migration and startup with an owned disposable database**

Use a system-created temporary directory, an absolute database path beneath it, and an exit trap. Do not print the path:

```bash
tmp_dir="$(mktemp -d)"
cleanup() {
  if [ -n "${server_pid:-}" ]; then kill "$server_pid" 2>/dev/null || true; fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT
export LIFEOS_DATABASE_PATH="$tmp_dir/lifeos.sqlite3"
uv run python manage.py migrate --noinput
uv run python manage.py runserver 127.0.0.1:8765 --noreload &
server_pid=$!
until curl --fail --silent http://127.0.0.1:8765/ready/ >/dev/null; do
  kill -0 "$server_pid"
  sleep 0.25
done
curl --fail --silent http://127.0.0.1:8765/ready/ >/dev/null
curl --fail --silent http://127.0.0.1:8765/ | grep -F "Daily register" >/dev/null
curl --fail --silent http://127.0.0.1:8765/work/ | grep -F "Work register" >/dev/null
curl --fail --silent http://127.0.0.1:8765/money/ | grep -F "Money register" >/dev/null
curl --fail --silent http://127.0.0.1:8765/money/transactions/new/ | grep -F "New transaction" >/dev/null
```

Record only statuses and non-personal route markers. Do not record the temporary path.

- [ ] **Step 7: Verify the complete CSRF-enforced HTTP workflow**

Run a short `uv run python` process using `django.test.Client(enforce_csrf_checks=True)`, host `127.0.0.1`, and a separate owned disposable absolute database. It must:
1. GET create and capture the CSRF cookie without printing it.
2. POST a valid transaction and assert HTTP 302 to canonical detail.
3. GET detail and assert HTTP 200.
4. GET edit, capture a fresh token, POST an update, and assert HTTP 302 to the same detail.
5. GET delete confirmation and assert HTTP 200.
6. POST delete with a fresh token and assert HTTP 302 to `/money/?month=YYYY-MM`.
7. GET that selected month and assert HTTP 200 with the empty state and no remaining transaction.

Output only step labels, HTTP statuses, and route markers. Do not print tokens, submitted values, model values, identifiers, or database paths.

- [ ] **Step 8: Run privacy, dependency, history, and tracked-state scans**

Use scoped read-only scans and record counts or pass/fail conclusions rather than personal content:

```bash
grep -RInE 'https?://|//[^ ]+\.(com|net|org)' templates static lifeos || true
grep -RInE 'playwright|selenium|puppeteer|cypress|screenshot|snapshot|golden|pixel.?comparison|visual.?regression' lifeos templates static tests pyproject.toml || true
grep -RIn '/home/aUser/improvedCalendar' lifeos templates static tests README.md docs/foundation || true
find . -type f \( -name '*.sqlite3' -o -name '*.db' -o -name '*.sqlite' \)
git status --short
git ls-files
```

Confirm:
- no remote runtime assets;
- no prohibited visual-browser tooling;
- no executable historical-source reference;
- no database artifact;
- no personal home path in executable/configured source;
- unrelated untracked `.claude/`, root `PRODUCT.md`, and other plan files remain untouched and unstaged.

Do not scan the historical application directory itself.

- [ ] **Step 9: Write the verification receipt**

Create `/home/aUser/lifeManager/docs/verification/2026-09-25-money-slice.md` with:
- scope and revision;
- exact environment versions;
- focused and complete commands and outcomes;
- deployment warnings;
- disposable migration/startup evidence;
- CSRF-enforced workflow evidence;
- source/privacy scan results;
- fresh review disposition and any one-pass fixes;
- skipped or approximated checks;
- these seven checks marked **unverified** unless a person actually performed them:
  1. actual layout at 320 CSS pixels;
  2. layout and operation at 200% browser zoom;
  3. a complete text-spacing override;
  4. keyboard traversal and visible focus;
  5. system, light, and dark theme behavior, including blocked storage;
  6. reduced-motion behavior;
  7. screen-reader smoke testing of landmarks, forms, error feedback, state labels, transaction tables, navigation current-page semantics, and message regions.

State explicitly that no visual browser test, screenshot, snapshot, golden image, pixel comparison, capture round, or visual-regression service was used.

- [ ] **Step 10: Re-run the final pre-review suite**

```bash
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
```

Expected: all tests and checks pass with no migration drift.

- [ ] **Step 11: Commit the task boundary**

Stage only the named maintained docs, documentation tests, and receipt:

```bash
git add README.md docs/foundation/START-HERE.md docs/foundation/PRODUCT.md docs/foundation/V1-SCOPE.md docs/foundation/DOMAIN.md docs/foundation/DESIGN.md docs/foundation/ARCHITECTURE.md docs/foundation/ENGINEERING.md docs/foundation/LESSONS.md tests/test_foundation_docs.py docs/verification/2026-09-25-money-slice.md
git diff --cached --name-only
git commit -m "docs: verify the Money slice" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

Before committing, remove `docs/foundation/LESSONS.md` from the index if no concrete implementation lesson required changing it. Confirm the staged list excludes `.claude/`, root `PRODUCT.md`, other plan files, database artifacts, and personal data.

## Final Whole-Slice Review and Gate

This section is executed after Task 9 and is not a second feature task.

- [ ] **Fresh review: request one whole-slice review**

Use `superpowers:requesting-code-review` or the review facility available to `superpowers:executing-plans`. Give the fresh reviewer:
- the full implementation commit range;
- `/home/aUser/lifeManager/docs/superpowers/specs/2026-09-25-lifeos-money-slice-design.md`;
- this implementation plan;
- maintained foundation documents;
- Money migration, source, templates, tests, and verification receipt.

Ask for findings classified as **Critical**, **Important**, or **Minor**, with concrete file/line evidence. Ask specifically about:
- model/schema correctness;
- Money-owned month and no Work-internal imports;
- one-snapshot calculations;
- GET-only detail/register behavior;
- lookup versus true-404 handling;
- validation/save/delete/atomic-exit `DatabaseError` coverage;
- privacy-safe logging and responses;
- summary isolation;
- resolved-route navigation semantics;
- disposable database and verification honesty.

- [ ] **Severity regrade: validate every finding before changing code**

Apply `superpowers:receiving-code-review`. Reproduce or inspect every claim, reject findings contradicted by the approved spec or repository evidence, and record the final accepted severity. Do not silently promote Minor polish or speculative abstractions into required scope.

- [ ] **One TDD fix pass: address accepted Critical and Important findings only**

For every accepted Critical or Important finding:
1. add the smallest failing regression test;
2. run it and observe RED for the claimed reason;
3. make the smallest coherent correction;
4. run the focused test to GREEN;
5. run `uv run pytest tests/money tests/core tests/work tests/test_foundation_docs.py -q`;
6. run `uv run pytest -q`;
7. run Django and migration checks;
8. update the verification receipt with the finding and exact outcome.

Combine all accepted Critical/Important corrections into exactly one fix-pass commit:

```bash
git add <only files changed by accepted Critical or Important fixes>
git commit -m "fix(money): address whole-slice review findings" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

If there are no accepted Critical or Important findings, make no empty commit and record that no fix pass was required.

- [ ] **Minor disposition: defer rather than expanding scope**

Record each confirmed Minor finding in the verification receipt with its reason for deferral. Do not implement Minors in this one permitted fix pass. Record unavailable reviewer capabilities honestly. Do not dispatch a second review.

- [ ] **Final gate: verify the reviewed slice**

Run:

```bash
uv run pytest tests/money -q
uv run pytest tests/core tests/work -q
uv run pytest tests/test_foundation_docs.py -q
uv run pytest -q
uv run python manage.py check
uv run python manage.py check --deploy
uv run python manage.py makemigrations --check --dry-run
git status --short
```

Repeat the disposable migration/startup and complete CSRF-enforced HTTP workflow if any accepted review fix touched models, migrations, URLs, views, forms, templates, summary integration, database handling, or settings. Amend the verification receipt with exact final results in a documentation-only commit if the receipt changed after the fix pass:

```bash
git add docs/verification/2026-09-25-money-slice.md
git commit -m "docs: record final Money verification" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

The final gate passes only if:
- no Critical or Important finding remains accepted and unresolved;
- the complete suite and ordinary Django check pass;
- migration drift is absent;
- deployment warnings are recorded honestly;
- disposable startup and HTTP evidence are current;
- all seven manual checks remain explicitly unverified unless personally performed;
- no personal data, database artifact, prohibited browser tooling, historical source access, or unrelated file enters a commit.
