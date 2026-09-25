from contextlib import contextmanager
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.test import Client
from django.urls import reverse

from lifeos.work.models import Shift

pytestmark = pytest.mark.django_db


def make_shift():
    return Shift.objects.create(
        work_date=date(2026, 9, 25),
        shift_type="holiday",
        worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"),
        hourly_rate=Decimal("20.00"),
        note="private-delete-marker",
    )


def test_delete_get_names_shift_and_never_deletes(client):
    shift = make_shift()
    url = reverse("work:shift-delete", args=[shift.pk])
    first = client.get(url)
    second = client.get(url)
    content = first.content.decode()
    assert first.status_code == second.status_code == 200
    assert "25 September 2026" in content
    assert "Holiday" in content
    assert Shift.objects.filter(pk=shift.pk).exists()


def test_delete_post_hard_deletes_and_redirects_to_month(client):
    shift = make_shift()
    response = client.post(reverse("work:shift-delete", args=[shift.pk]))
    assert response.status_code == 302
    assert response.url == "/work/?month=2026-09"
    assert not Shift.objects.filter(pk=shift.pk).exists()
    follow = client.get(response.url)
    messages = list(follow.context["messages"])
    assert [str(message) for message in messages] == ["Shift deleted."]
    assert "private-delete-marker" not in follow.content.decode()


@pytest.mark.parametrize("method", ["get", "post"])
def test_missing_delete_returns_404(client, method):
    response = getattr(client, method)(reverse("work:shift-delete", args=[999]))
    assert response.status_code == 404


def test_delete_lookup_database_failure_is_safe(client, monkeypatch, caplog):
    shift = make_shift()

    def fail_get(*args, **kwargs):
        raise DatabaseError("private lookup 77.77 /private/delete")

    monkeypatch.setattr("lifeos.work.views.get_object_or_404", fail_get)
    response = client.get(reverse("work:shift-delete", args=[shift.pk]))
    assert response.status_code == 503
    assert "temporarily unavailable" in response.content.decode()
    assert "DatabaseError" in caplog.text
    assert "private lookup 77.77" not in caplog.text
    assert "/private/delete" not in caplog.text


def test_delete_commit_failure_renders_recovery_with_original_identifier(
    client, monkeypatch, caplog
):
    shift = make_shift()
    original_pk = shift.pk

    @contextmanager
    def fail_after_body():
        yield
        raise DatabaseError("private commit 77.77 /private/delete")

    monkeypatch.setattr("lifeos.work.views.transaction.atomic", fail_after_body)
    response = client.post(reverse("work:shift-delete", args=[original_pk]))
    assert response.status_code == 200
    assert reverse("work:shift-detail", args=[original_pk]) in response.content.decode()
    assert "could not be deleted" in response.content.decode()
    assert "DatabaseError" in caplog.text
    assert "private commit 77.77" not in caplog.text
    assert "/private/delete" not in caplog.text


def test_delete_database_failure_rolls_back_safely(client, monkeypatch, caplog):
    shift = make_shift()

    def fail_delete(self):
        raise DatabaseError("private 77.77 /private/delete")

    monkeypatch.setattr(Shift, "delete", fail_delete)
    response = client.post(reverse("work:shift-delete", args=[shift.pk]))
    assert response.status_code == 200
    assert Shift.objects.filter(pk=shift.pk).exists()
    assert "could not be deleted" in response.content.decode()
    assert "DatabaseError" in caplog.text
    assert "private 77.77" not in caplog.text
    assert "/private/delete" not in caplog.text


def test_delete_requires_csrf():
    shift = make_shift()
    client = Client(enforce_csrf_checks=True)
    response = client.post(reverse("work:shift-delete", args=[shift.pk]))
    assert response.status_code == 403
    assert Shift.objects.filter(pk=shift.pk).exists()
