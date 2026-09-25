from contextlib import contextmanager
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.test import Client
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


def test_delete_calls_delete_and_atomic_once(client, monkeypatch):
    item = make_transaction()
    original_delete = Transaction.delete
    original_atomic = __import__("django.db.transaction", fromlist=["atomic"]).atomic
    calls = {"delete": 0, "atomic": 0}

    def counted_delete(self, *args, **kwargs):
        calls["delete"] += 1
        return original_delete(self, *args, **kwargs)

    @contextmanager
    def counted_atomic(*args, **kwargs):
        if args or kwargs:
            with original_atomic(*args, **kwargs):
                yield
            return
        calls["atomic"] += 1
        yield

    monkeypatch.setattr(Transaction, "delete", counted_delete)
    monkeypatch.setattr("lifeos.money.views.transaction.atomic", counted_atomic)
    response = client.post(reverse("money:transaction-delete", args=[item.pk]))
    assert response.status_code == 302
    assert calls == {"delete": 1, "atomic": 1}


def test_delete_execution_database_failure_rolls_back(client, monkeypatch, caplog):
    item = make_transaction()

    def fail_delete(self, *args, **kwargs):
        raise DatabaseError("private delete /private/path")

    monkeypatch.setattr(Transaction, "delete", fail_delete)
    response = client.post(reverse("money:transaction-delete", args=[item.pk]))
    assert response.status_code == 200
    assert Transaction.objects.filter(pk=item.pk).exists()
    content = response.content.decode()
    assert "The transaction could not be deleted. Please try again." in content
    assert "Transaction deleted." not in content
    assert "inspect the Money register before retrying" not in content
    assert "Money transaction delete failed (DatabaseError)" in caplog.text
    assert "private delete" not in caplog.text
    assert "/private/path" not in caplog.text


def test_delete_atomic_exit_failure_preserves_safe_identity(client, monkeypatch):
    item = make_transaction()
    original_pk = item.pk
    original_atomic = __import__("django.db.transaction", fromlist=["atomic"]).atomic

    @contextmanager
    def fail_on_exit(*args, **kwargs):
        if args or kwargs:
            with original_atomic(*args, **kwargs):
                yield
            return
        yield
        raise DatabaseError("private commit")

    monkeypatch.setattr("lifeos.money.views.transaction.atomic", fail_on_exit)
    response = client.post(reverse("money:transaction-delete", args=[original_pk]))
    html = response.content.decode()
    assert response.status_code == 200
    assert reverse("money:transaction-detail", args=[original_pk]) in html
    assert "inspect the Money register before retrying" in html
    assert "Transaction deleted." not in html


@pytest.mark.parametrize("method", ["get", "post"])
def test_delete_missing_record_is_404(client, method):
    response = getattr(client, method)(
        reverse("money:transaction-delete", args=[999])
    )
    assert response.status_code == 404


@pytest.mark.parametrize("method", ["put", "patch", "delete"])
def test_delete_rejects_unsupported_methods(client, method):
    item = make_transaction()
    response = getattr(client, method)(
        reverse("money:transaction-delete", args=[item.pk])
    )
    assert response.status_code == 405
    assert Transaction.objects.filter(pk=item.pk).exists()


def test_delete_lookup_database_failure_is_503(client, monkeypatch, caplog):
    monkeypatch.setattr(
        "lifeos.money.views.get_object_or_404",
        lambda *args, **kwargs: (_ for _ in ()).throw(
            DatabaseError("private lookup /private/path")
        ),
    )
    response = client.get(reverse("money:transaction-delete", args=[1]))
    assert response.status_code == 503
    assert "Money transaction delete lookup failed (DatabaseError)" in caplog.text
    assert "private lookup" not in caplog.text


def test_delete_requires_csrf():
    item = make_transaction()
    client = Client(enforce_csrf_checks=True)
    response = client.post(reverse("money:transaction-delete", args=[item.pk]))
    assert response.status_code == 403
    assert Transaction.objects.filter(pk=item.pk).exists()


def test_delete_unexpected_lookup_exception_propagates(client, monkeypatch):
    monkeypatch.setattr(
        "lifeos.money.views.get_object_or_404",
        lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError("defect")),
    )
    with pytest.raises(RuntimeError, match="defect"):
        client.get(reverse("money:transaction-delete", args=[1]))


def test_delete_unexpected_execution_exception_propagates(client, monkeypatch):
    item = make_transaction()

    def fail_delete(self, *args, **kwargs):
        raise RuntimeError("defect")

    monkeypatch.setattr(Transaction, "delete", fail_delete)
    with pytest.raises(RuntimeError, match="defect"):
        client.post(reverse("money:transaction-delete", args=[item.pk]))
