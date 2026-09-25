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


def test_register_defaults_to_canonical_month_with_empty_totals(client):
    clock = FixedClock(date(2026, 9, 25))
    with override_clock(clock):
        response = client.get(reverse("money:register"))
    content = response.content.decode()
    assert clock.calls == 1
    assert response.context["month"].value == "2026-09"
    assert response.context["month_error"] is None
    assert response.context["movement"].count == 0
    assert response.context["formatted_inflow"] == "€0.00"
    assert response.context["formatted_outflow"] == "€0.00"
    assert response.context["formatted_net_movement"] == "€0.00"
    assert "No transactions recorded for September 2026." in content


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

    monkeypatch.setattr(
        "lifeos.money.views.transaction_snapshot_for_month", one_snapshot
    )
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("money:register"))
    assert calls == 1
    assert response.context["transactions"] == snapshot
    assert response.context["movement"].count == 2
    assert response.context["movement"].inflow == Decimal("100.00")
    assert response.context["movement"].outflow == Decimal("25.25")
    assert response.context["movement"].net_movement == Decimal("74.75")


@pytest.mark.parametrize("raw_value", ["bad", "0000-01", "0001-01", "9999-12"])
def test_invalid_month_visibly_falls_back_without_echo(client, raw_value):
    create_item(date(2026, 8, 31), "expense", "9.99", "other-month-marker")
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("money:register"), {"month": raw_value})
    content = response.content.decode()
    assert response.status_code == 200
    assert response.context["month"].value == "2026-09"
    assert "Enter a month in YYYY-MM format." in content
    assert raw_value not in content
    assert "other-month-marker" not in content


@pytest.mark.parametrize(
    ("raw_value", "previous", "next_value"),
    [
        ("0002-01", "?month=0001-12", "?month=0002-02"),
        ("9998-12", "?month=9998-11", "?month=9999-01"),
        ("2026-12", "?month=2026-11", "?month=2027-01"),
    ],
)
def test_register_navigation_handles_edges_and_rollover(
    client, raw_value, previous, next_value
):
    with override_clock(FixedClock(date(2026, 9, 25))):
        content = client.get(
            reverse("money:register"), {"month": raw_value}
        ).content.decode()
    assert previous in content
    assert next_value in content


def test_register_table_has_only_approved_columns_and_no_notes(client):
    item = create_item(date(2026, 9, 25), "expense", "12.34", "<b>Food</b>")
    with override_clock(FixedClock(date(2026, 9, 25))):
        html = client.get(reverse("money:register")).content.decode()
    for heading in ("Date", "Direction", "Category", "Amount"):
        assert f">{heading}<" in html
    assert "Expense" in html
    assert "&lt;b&gt;Food&lt;/b&gt;" in html
    assert "private-register-note" not in html
    assert reverse("money:transaction-detail", args=[item.pk]) in html
    for excluded in ("Search", "Filter", "Leading category", "<canvas", "<svg"):
        assert excluded not in html
    assert '<div class="horizontal-scroll" role="region"' in html
    assert 'aria-label="Transactions for September 2026"' in html
    assert 'tabindex="0"' in html
    assert html.count("<main") == 1
    assert html.count("<h1") == 1


def test_register_excludes_leap_month_boundary_and_orders_deterministically(client):
    first = create_item(date(2028, 2, 1), "income", "1.00", "first")
    older = create_item(date(2028, 2, 29), "expense", "2.00", "older")
    newer = create_item(date(2028, 2, 29), "income", "3.00", "newer")
    excluded = create_item(date(2028, 3, 1), "expense", "4.00", "excluded")
    with override_clock(FixedClock(date(2028, 2, 15))):
        response = client.get(reverse("money:register"))
    html = response.content.decode()
    assert html.index(str(newer.category)) < html.index(str(older.category)) < html.index(str(first.category))
    assert excluded.category not in html


def test_register_formats_negative_net_with_explicit_sign(client):
    create_item(date(2026, 9, 25), "expense", "12.34", "Food")
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("money:register"))
    assert response.context["formatted_net_movement"] == "-€12.34"
    assert "-€12.34" in response.content.decode()


def test_register_database_failure_returns_private_503(client, monkeypatch, caplog):
    def fail(month):
        raise DatabaseError("private 66.66 /private/register")

    monkeypatch.setattr("lifeos.money.views.transaction_snapshot_for_month", fail)
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("money:register"))
    content = response.content.decode()
    assert response.status_code == 503
    assert "Money register is temporarily unavailable." in content
    assert "€0.00" not in content
    assert "Money register query failed (DatabaseError)" in caplog.text
    assert "private 66.66" not in caplog.text
    assert "/private/register" not in caplog.text


def test_register_unexpected_error_propagates(client, monkeypatch):
    def fail(month):
        raise RuntimeError("defect")

    monkeypatch.setattr("lifeos.money.views.transaction_snapshot_for_month", fail)
    with override_clock(FixedClock(date(2026, 9, 25))), pytest.raises(
        RuntimeError, match="defect"
    ):
        client.get(reverse("money:register"))


def test_register_is_get_only(client):
    assert client.post(reverse("money:register")).status_code == 405


def test_money_controls_have_minimum_target_size_css():
    css = open("static/css/app.css", encoding="utf-8").read()
    assert ".money-header .button-link" in css
    assert ".month-navigation a" in css and "min-height:44px" in css
    assert ".transaction-table" in css
    assert "overflow-x:auto" in css
    assert "body{overflow" not in css
