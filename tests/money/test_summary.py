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


class FixedClock:
    def __init__(self, value):
        self.value = value
        self.calls = 0

    def today(self):
        self.calls += 1
        return self.value


def create_item(day, direction, amount):
    return Transaction.objects.create(
        transaction_date=day,
        direction=direction,
        amount=Decimal(amount),
        category="Private category",
    )


def test_empty_summary_links_to_register_and_canonical_quick_action():
    summary = get_summary(today=date(2026, 9, 25))
    assert summary.state == "empty"
    assert summary.href == "/money/"
    assert summary.action_label == "New transaction"
    assert summary.action_href == "/money/transactions/new/?date=2026-09-25"
    assert summary.values == ()


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

    monkeypatch.setattr(
        "lifeos.money.summary.transaction_snapshot_for_month", one_snapshot
    )
    assert get_summary(today=date(2026, 9, 25)).state == "ready"
    assert calls == 1


def test_summary_database_error_becomes_safe_wrapper(monkeypatch):
    monkeypatch.setattr(
        "lifeos.money.summary.transaction_snapshot_for_month",
        lambda month: (_ for _ in ()).throw(DatabaseError("private summary")),
    )
    with pytest.raises(SummaryUnavailable) as error:
        get_summary(today=date(2026, 9, 25))
    assert "Money summary unavailable" == str(error.value)
    assert "private summary" not in str(error.value)


def test_summary_unexpected_error_propagates(monkeypatch):
    monkeypatch.setattr(
        "lifeos.money.summary.transaction_snapshot_for_month",
        lambda month: (_ for _ in ()).throw(RuntimeError("defect")),
    )
    with pytest.raises(RuntimeError, match="defect"):
        get_summary(today=date(2026, 9, 25))


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
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse(url_name))
    html = response.content.decode()
    assert html.count('aria-current="page"') == 1
    marker = html.index('aria-current="page"')
    assert expected_text in html[max(0, marker - 120) : marker + 120]


@pytest.mark.parametrize(
    ("url_name", "factory"),
    [
        ("work:shift-detail", "work"),
        ("work:shift-edit", "work"),
        ("work:shift-delete", "work"),
        ("money:transaction-detail", "money"),
        ("money:transaction-edit", "money"),
        ("money:transaction-delete", "money"),
    ],
)
def test_record_pages_mark_only_their_register_current(client, url_name, factory):
    if factory == "work":
        from lifeos.work.models import Shift

        item = Shift.objects.create(
            work_date=date(2026, 9, 25),
            shift_type="normal",
            worked_hours=Decimal("8.00"),
            overtime_hours=Decimal("0.00"),
            hourly_rate=Decimal("20.00"),
        )
        expected = "Work"
    else:
        item = create_item(date(2026, 9, 25), "expense", "12.34")
        expected = "Money"
    html = client.get(reverse(url_name, args=[item.pk])).content.decode()
    assert html.count('aria-current="page"') == 1
    marker = html.index('aria-current="page"')
    assert expected in html[max(0, marker - 120) : marker + 120]


def test_readiness_has_no_false_current_marker(client):
    assert 'aria-current="page"' not in client.get(reverse("core:ready")).content.decode()
