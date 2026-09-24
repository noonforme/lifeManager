from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.test import Client
from django.urls import reverse

from lifeos.work.forms import ShiftForm
from lifeos.work.models import Shift

pytestmark = pytest.mark.django_db


def make_shift():
    return Shift.objects.create(
        work_date=date(2026, 9, 25),
        shift_type="normal",
        worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"),
        hourly_rate=Decimal("20.00"),
        note="before",
    )


def update_data(**overrides):
    values = {
        "work_date": "2026-09-26",
        "shift_type": "night",
        "worked_hours": "7.00",
        "overtime_hours": "2.00",
        "hourly_rate": "21.00",
        "note": "  after  ",
    }
    values.update(overrides)
    return values


def test_edit_get_is_populated_without_mutation(client):
    shift = make_shift()
    response = client.get(reverse("work:shift-edit", args=[shift.pk]))
    shift.refresh_from_db()
    assert response.status_code == 200
    assert response.context["form"].instance == shift
    assert response.context["page_title"] == "Edit shift"
    assert shift.note == "before"


def test_valid_edit_redirects_to_detail_and_updates_once(client, monkeypatch):
    shift = make_shift()
    original = ShiftForm.save
    calls = 0

    def count_save(self):
        nonlocal calls
        calls += 1
        return original(self)

    monkeypatch.setattr(ShiftForm, "save", count_save)
    response = client.post(reverse("work:shift-edit", args=[shift.pk]), update_data())
    shift.refresh_from_db()
    assert calls == 1
    assert response.status_code == 302
    assert response.url == reverse("work:shift-detail", args=[shift.pk])
    assert shift.work_date == date(2026, 9, 26)
    assert shift.note == "after"


def test_invalid_edit_preserves_database_and_has_no_success(client):
    shift = make_shift()
    response = client.post(
        reverse("work:shift-edit", args=[shift.pk]),
        update_data(worked_hours="0.00"),
    )
    shift.refresh_from_db()
    content = response.content.decode()
    assert response.status_code == 200
    assert shift.worked_hours == Decimal("8.00")
    assert "Shift updated." not in content


@pytest.mark.parametrize("method", ["get", "post"])
def test_missing_edit_returns_404(client, method):
    response = getattr(client, method)(
        reverse("work:shift-edit", args=[999]),
        update_data(),
    )
    assert response.status_code == 404
    assert Shift.objects.count() == 0


def test_edit_database_failure_rolls_back_safely(client, monkeypatch, caplog):
    shift = make_shift()

    def fail_save(self):
        raise DatabaseError("private 88.88 /private/edit")

    monkeypatch.setattr(ShiftForm, "save", fail_save)
    response = client.post(reverse("work:shift-edit", args=[shift.pk]), update_data())
    shift.refresh_from_db()
    assert response.status_code == 200
    assert shift.note == "before"
    assert "Please try again." in response.content.decode()
    assert "DatabaseError" in caplog.text
    assert "private 88.88" not in caplog.text
    assert "/private/edit" not in caplog.text


def test_edit_requires_csrf():
    shift = make_shift()
    client = Client(enforce_csrf_checks=True)
    response = client.post(reverse("work:shift-edit", args=[shift.pk]), update_data())
    shift.refresh_from_db()
    assert response.status_code == 403
    assert shift.note == "before"
