from dataclasses import FrozenInstanceError
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError

from lifeos.core.dashboard import SummaryUnavailable
from lifeos.work.models import Shift
from lifeos.work.summary import get_summary

pytestmark = pytest.mark.django_db


def create_shift(work_date, *, created_note=""):
    return Shift.objects.create(
        work_date=work_date,
        shift_type="normal",
        worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"),
        hourly_rate=Decimal("20.00"),
        note=created_note,
    )


def values(summary):
    return {item.label: item.value for item in summary.values}


def test_ready_summary_has_exact_values_and_links():
    create_shift(date(2026, 9, 25))
    summary = get_summary(today=date(2026, 9, 25))
    assert summary.state == "ready"
    assert summary.state_label == "Ready"
    assert summary.href == "/work/"
    assert summary.action_href == "/work/shifts/new/?date=2026-09-25"
    assert values(summary) == {
        "Shifts": "1",
        "Worked": "8.00 h",
        "Overtime": "1.00 h",
        "Estimated net": "102.85",
        "Next shift": "25 September 2026",
    }
    with pytest.raises(FrozenInstanceError):
        summary.values[0].value = "changed"


def test_empty_summary_keeps_implemented_links_without_values():
    summary = get_summary(today=date(2026, 9, 25))
    assert summary.state == "empty"
    assert summary.href == "/work/"
    assert summary.action_href == "/work/shifts/new/?date=2026-09-25"
    assert summary.values == ()


def test_summary_excludes_another_month():
    create_shift(date(2026, 8, 31))
    assert get_summary(today=date(2026, 9, 25)).state == "empty"


@pytest.mark.parametrize(("shift_date", "label"), [
    (date(2026, 9, 25), "Next shift"),
    (date(2026, 9, 26), "Next shift"),
    (date(2026, 9, 24), "Last shift"),
])
def test_summary_labels_nearest_shift(shift_date, label):
    create_shift(shift_date)
    summary = get_summary(today=date(2026, 9, 25))
    assert label in values(summary)


def test_summary_translates_database_failure_without_private_text(monkeypatch):
    def fail_query(month):
        raise DatabaseError("private summary text")

    monkeypatch.setattr("lifeos.work.summary.shifts_for_month", fail_query)
    with pytest.raises(SummaryUnavailable) as error:
        get_summary(today=date(2026, 9, 25))
    assert "private summary text" not in str(error.value)


def test_summary_propagates_unexpected_errors(monkeypatch):
    def fail_query(month):
        raise AssertionError("programming defect")

    monkeypatch.setattr("lifeos.work.summary.shifts_for_month", fail_query)
    with pytest.raises(AssertionError, match="programming defect"):
        get_summary(today=date(2026, 9, 25))
