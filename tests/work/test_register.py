from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.urls import reverse

from lifeos.core.clock import override_clock
from lifeos.work.models import Shift

pytestmark = pytest.mark.django_db


class FixedClock:
    def __init__(self, value):
        self.value = value
        self.calls = 0

    def today(self):
        self.calls += 1
        return self.value


def create_shift(work_date, *, note="private-register-marker", rate="20.00"):
    return Shift.objects.create(
        work_date=work_date,
        shift_type="normal",
        worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"),
        hourly_rate=Decimal(rate),
        note=note,
    )


def test_register_defaults_to_canonical_month_and_empty_result(client):
    clock = FixedClock(date(2026, 9, 25))
    with override_clock(clock):
        response = client.get(reverse("work:register"))
    assert clock.calls == 1
    assert response.context["month"].value == "2026-09"
    assert response.context["month_error"] is None
    assert response.context["salary"].shift_count == 0
    assert response.context["salary"].net == Decimal("0.00")
    assert "No shifts recorded for September 2026." in response.content.decode()


@pytest.mark.parametrize("raw_value", ["bad", "0000-01", "0001-01", "9999-12"])
def test_invalid_month_visibly_falls_back_without_other_month_data(client, raw_value):
    create_shift(date(2026, 8, 31), note="other-month-private")
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("work:register"), {"month": raw_value})
    content = response.content.decode()
    assert response.status_code == 200
    assert response.context["month"].value == "2026-09"
    assert "Enter a month in YYYY-MM format." in content
    assert raw_value not in content
    assert "other-month-private" not in content


def test_register_navigation_rolls_over_year(client):
    with override_clock(FixedClock(date(2026, 12, 1))):
        response = client.get(reverse("work:register"))
    content = response.content.decode()
    assert "?month=2026-11" in content
    assert "?month=2027-01" in content


def test_register_displays_exact_salary_and_deterministic_shift_links(client):
    older = create_shift(date(2026, 9, 24), rate="10.00")
    newer = create_shift(date(2026, 9, 25), rate="20.00")
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("work:register"))
    content = response.content.decode()
    salary = response.context["salary"]
    assert salary.shift_count == 2
    assert salary.total_worked_hours == Decimal("16.00")
    assert salary.total_normal_hours == Decimal("14.00")
    assert salary.total_overtime_hours == Decimal("2.00")
    assert salary.mean_hourly_rate == Decimal("15.00")
    assert salary.gross == Decimal("255.00")
    assert salary.gpm == Decimal("51.00")
    assert salary.vsd == Decimal("31.93")
    assert salary.psd == Decimal("17.80")
    assert salary.total_taxes == Decimal("100.73")
    assert salary.net == Decimal("154.27")
    assert content.index(reverse("work:shift-detail", args=[newer.pk])) < content.index(
        reverse("work:shift-detail", args=[older.pk])
    )
    assert content.count("<main") == 1
    assert content.count("<h1") == 1
    assert "Estimated salary" in content
    assert 'class="mono"' in content
    assert 'class="horizontal-scroll"' in content
    assert "private-register-marker" not in content
    for phrase in [
        "normal hours × hourly rate",
        "overtime hours × hourly rate × 1.5",
        "GPM 20%",
        "VSD 12.52%",
        "PSD 6.98%",
        "ROUND_HALF_UP",
        "displayed deductions",
        "fixed version-one characterization",
        "not tax advice",
    ]:
        assert phrase in content


def test_register_database_failure_returns_private_503(client, monkeypatch, caplog):
    def fail_query(month):
        raise DatabaseError("private 66.66 /private/register")

    monkeypatch.setattr("lifeos.work.views.shifts_for_month", fail_query)
    with override_clock(FixedClock(date(2026, 9, 25))):
        response = client.get(reverse("work:register"))
    content = response.content.decode()
    assert response.status_code == 503
    assert "Work register is temporarily unavailable." in content
    assert "Estimated salary" not in content
    assert "0.00" not in content
    assert "DatabaseError" in caplog.text
    assert "private 66.66" not in caplog.text
    assert "/private/register" not in caplog.text


def test_register_unexpected_errors_propagate(client, monkeypatch):
    def fail_query(month):
        raise AssertionError("programming defect")

    monkeypatch.setattr("lifeos.work.views.shifts_for_month", fail_query)
    with override_clock(FixedClock(date(2026, 9, 25))), pytest.raises(AssertionError):
        client.get(reverse("work:register"))
