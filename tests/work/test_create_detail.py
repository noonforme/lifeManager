from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.test import Client
from django.urls import reverse

from lifeos.work.forms import ShiftForm
from lifeos.work.models import Shift

pytestmark = pytest.mark.django_db

VALID = {
    "work_date": "2026-09-25",
    "shift_type": "normal",
    "worked_hours": "8.00",
    "overtime_hours": "1.00",
    "hourly_rate": "20.00",
    "note": "  private reconciliation  ",
}


def test_create_get_prefills_only_exact_date(client):
    response = client.get(reverse("work:shift-create"), {"date": "2026-09-25"})
    assert response.status_code == 200
    assert response.context["form"].initial["work_date"] == date(2026, 9, 25)
    assert Shift.objects.count() == 0


@pytest.mark.parametrize("value", ["25-09-2026", "2026-9-25", "2026-02-30"])
def test_create_ignores_malformed_prefill(client, value):
    response = client.get(reverse("work:shift-create"), {"date": value})
    assert response.context["form"].initial.get("work_date") is None


def test_create_redirects_to_canonical_detail_and_trims_note(client):
    response = client.post(reverse("work:shift-create"), VALID)
    shift = Shift.objects.get()
    assert response.status_code == 302
    assert response.url == reverse("work:shift-detail", args=[shift.pk])
    assert shift.note == "private reconciliation"

    detail = client.get(response.url)
    content = detail.content.decode()
    assert detail.status_code == 200
    assert content.count("<main") == 1
    assert content.count("<h1") == 1
    assert "Shift review" in content
    assert "private reconciliation" in content
    assert '<time datetime="2026-09-25">' in content


def test_detail_escapes_note(client):
    shift = Shift.objects.create(
        work_date=date(2026, 9, 25),
        shift_type="night",
        worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"),
        hourly_rate=Decimal("20.00"),
        note="<script>private</script>",
    )
    content = client.get(reverse("work:shift-detail", args=[shift.pk])).content.decode()
    assert "&lt;script&gt;private&lt;/script&gt;" in content
    assert "<script>private</script>" not in content


def test_missing_detail_returns_404_without_creating_record(client):
    response = client.get(reverse("work:shift-detail", args=[999]))
    assert response.status_code == 404
    assert Shift.objects.count() == 0


def test_invalid_create_preserves_safe_values_and_commits_nothing(client, caplog):
    invalid = {
        **VALID,
        "work_date": "not-a-date",
        "shift_type": "unknown",
        "worked_hours": "1.001",
        "overtime_hours": "NaN",
        "hourly_rate": "10000.01",
        "note": "private-note-marker",
    }
    response = client.post(reverse("work:shift-create"), invalid)
    content = response.content.decode()
    assert response.status_code == 200
    assert Shift.objects.count() == 0
    assert "private-note-marker" in content
    assert "Shift created." not in content
    assert 'class="error-summary"' in content
    assert 'href="#id_work_date"' in content
    assert 'aria-invalid="true"' in content
    assert 'aria-describedby="id_work_date_hint id_work_date_error"' in content
    assert "private-note-marker" not in caplog.text


def test_create_validation_database_failure_is_safe(client, monkeypatch, caplog):
    def fail_validation(self, *, exclude=None):
        raise DatabaseError("private validation 99.99 /private/path")

    monkeypatch.setattr(Shift, "validate_constraints", fail_validation)
    response = client.post(reverse("work:shift-create"), VALID)
    content = response.content.decode()
    assert response.status_code == 200
    assert Shift.objects.count() == 0
    assert "Please try again." in content
    assert "DatabaseError" in caplog.text
    assert "private validation 99.99" not in caplog.text
    assert "/private/path" not in caplog.text


def test_create_database_failure_is_safe(client, monkeypatch, caplog):
    def fail_save(self):
        raise DatabaseError("private 99.99 /private/path")

    monkeypatch.setattr(ShiftForm, "save", fail_save)
    response = client.post(reverse("work:shift-create"), VALID)
    content = response.content.decode()
    assert response.status_code == 200
    assert Shift.objects.count() == 0
    assert "Please try again." in content
    assert "DatabaseError" in caplog.text
    assert "private 99.99" not in caplog.text
    assert "/private/path" not in caplog.text


def test_create_requires_csrf():
    client = Client(enforce_csrf_checks=True)
    response = client.post(reverse("work:shift-create"), VALID)
    assert response.status_code == 403
    assert Shift.objects.count() == 0
