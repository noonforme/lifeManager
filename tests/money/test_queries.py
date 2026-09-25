from datetime import date
from decimal import Decimal

import pytest

from lifeos.money.models import Transaction
from lifeos.money.queries import (
    MONTH_ERROR,
    CalendarMonth,
    select_month,
    transaction_snapshot_for_month,
    transactions_for_month,
)

pytestmark = pytest.mark.django_db


def create_transaction(day, category):
    return Transaction.objects.create(
        transaction_date=day,
        direction="expense",
        amount=Decimal("1.00"),
        category=category,
    )


def test_absent_month_selects_current_month_without_error():
    selection = select_month(None, today=date(2026, 9, 25))
    assert selection.month == CalendarMonth(2026, 9)
    assert selection.error is None


@pytest.mark.parametrize(
    "raw",
    ["bad", "2026-9", "2026-13", "0000-01", "0001-12", "9999-01"],
)
def test_invalid_or_unnavigable_month_falls_back_generically(raw):
    selection = select_month(raw, today=date(2026, 9, 25))
    assert selection.month == CalendarMonth(2026, 9)
    assert selection.error == MONTH_ERROR
    assert raw not in selection.error


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("0002-01", CalendarMonth(2, 1)),
        ("9998-12", CalendarMonth(9998, 12)),
    ],
)
def test_navigable_edge_years_are_accepted(raw, expected):
    selection = select_month(raw, today=date(2026, 9, 25))
    assert selection.month == expected
    assert selection.error is None


@pytest.mark.parametrize(
    ("month", "previous", "next_value"),
    [
        (CalendarMonth(2, 1), "0001-12", "0002-02"),
        (CalendarMonth(9998, 12), "9998-11", "9999-01"),
        (CalendarMonth(2026, 12), "2026-11", "2027-01"),
    ],
)
def test_navigation_is_constructible_at_every_accepted_bound(
    month, previous, next_value
):
    assert month.previous().value == previous
    assert month.next().value == next_value


def test_half_open_snapshot_handles_leap_february_and_orders_rows():
    create_transaction(date(2028, 1, 31), "before")
    first = create_transaction(date(2028, 2, 1), "first")
    older = create_transaction(date(2028, 2, 29), "older")
    newer = create_transaction(date(2028, 2, 29), "newer")
    create_transaction(date(2028, 3, 1), "excluded")

    snapshot = transaction_snapshot_for_month(CalendarMonth(2028, 2))
    assert [item.pk for item in snapshot] == [newer.pk, older.pk, first.pk]
    assert all(date(2028, 2, 1) <= item.transaction_date < date(2028, 3, 1) for item in snapshot)


def test_month_query_uses_inclusive_start_and_exclusive_end():
    queryset = transactions_for_month(CalendarMonth(2026, 12))
    sql = str(queryset.query)
    assert '"money_transaction"."transaction_date" >= 2026-12-01' in sql
    assert '"money_transaction"."transaction_date" < 2027-01-01' in sql
