from contextlib import contextmanager
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.test import Client
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


def test_valid_edit_saves_once_in_one_atomic_boundary_and_redirects(client, monkeypatch):
    item = make_transaction()
    original_save = TransactionForm.save
    original_atomic = __import__("django.db.transaction", fromlist=["atomic"]).atomic
    calls = {"save": 0, "atomic": 0}

    def counted_save(self, *args, **kwargs):
        calls["save"] += 1
        return original_save(self, *args, **kwargs)

    @contextmanager
    def counted_atomic(*args, **kwargs):
        if args or kwargs:
            with original_atomic(*args, **kwargs):
                yield
            return
        calls["atomic"] += 1
        yield

    monkeypatch.setattr(TransactionForm, "save", counted_save)
    monkeypatch.setattr("lifeos.money.views.transaction.atomic", counted_atomic)
    response = client.post(
        reverse("money:transaction-edit", args=[item.pk]), update_data()
    )
    item.refresh_from_db()
    assert calls == {"save": 1, "atomic": 1}
    assert response.status_code == 302
    assert response.url == reverse("money:transaction-detail", args=[item.pk])
    assert item.category == "After"


def test_invalid_edit_preserves_safe_values_without_changing_record(client):
    item = make_transaction()
    response = client.post(
        reverse("money:transaction-edit", args=[item.pk]),
        update_data(amount="1e2", category="safe-marker"),
    )
    item.refresh_from_db()
    content = response.content.decode()
    assert response.status_code == 200
    assert "safe-marker" in content
    assert "Transaction updated." not in content
    assert item.category == "Before"
    assert item.amount == Decimal("12.34")


@pytest.mark.parametrize("method", ["put", "patch", "delete"])
def test_edit_rejects_methods_other_than_get_and_post(client, method):
    item = make_transaction()
    response = getattr(client, method)(
        reverse("money:transaction-edit", args=[item.pk])
    )
    assert response.status_code == 405


@pytest.mark.parametrize("method", ["get", "post"])
def test_edit_missing_record_is_404(client, method):
    response = getattr(client, method)(
        reverse("money:transaction-edit", args=[999]), update_data()
    )
    assert response.status_code == 404


def test_edit_lookup_database_failure_is_503_and_class_only_log(client, monkeypatch, caplog):
    monkeypatch.setattr(
        "lifeos.money.views.get_object_or_404",
        lambda *args, **kwargs: (_ for _ in ()).throw(
            DatabaseError("private lookup 20.00 /private/database")
        ),
    )
    response = client.get(reverse("money:transaction-edit", args=[1]))
    assert response.status_code == 503
    assert "Money transaction edit lookup failed (DatabaseError)" in caplog.text
    assert "private lookup" not in caplog.text
    assert "/private/database" not in caplog.text


def test_edit_validation_database_failure_is_safe(client, monkeypatch):
    item = make_transaction()

    def fail_validation(self, *, exclude=None):
        raise DatabaseError("private validation")

    monkeypatch.setattr(Transaction, "validate_constraints", fail_validation)
    response = client.post(
        reverse("money:transaction-edit", args=[item.pk]), update_data()
    )
    item.refresh_from_db()
    assert response.status_code == 200
    assert "The transaction could not be saved. Please try again." in response.content.decode()
    assert item.category == "Before"


def test_edit_save_database_failure_is_safe(client, monkeypatch, caplog):
    item = make_transaction()

    def fail_save(self, *args, **kwargs):
        raise DatabaseError("private save /private/database")

    monkeypatch.setattr(TransactionForm, "save", fail_save)
    response = client.post(
        reverse("money:transaction-edit", args=[item.pk]), update_data()
    )
    item.refresh_from_db()
    assert response.status_code == 200
    assert item.category == "Before"
    assert "Transaction updated." not in response.content.decode()
    assert "DatabaseError" in caplog.text
    assert "private save" not in caplog.text


def test_edit_atomic_exit_failure_has_no_success(client, monkeypatch):
    item = make_transaction()
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
    response = client.post(
        reverse("money:transaction-edit", args=[item.pk]), update_data()
    )
    content = response.content.decode()
    assert response.status_code == 200
    assert "Transaction updated." not in content
    assert "inspect the Money register before retrying" in content


def test_edit_requires_csrf():
    item = make_transaction()
    client = Client(enforce_csrf_checks=True)
    response = client.post(
        reverse("money:transaction-edit", args=[item.pk]), update_data()
    )
    assert response.status_code == 403


def test_edit_unexpected_lookup_exception_propagates(client, monkeypatch):
    monkeypatch.setattr(
        "lifeos.money.views.get_object_or_404",
        lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError("defect")),
    )
    with pytest.raises(RuntimeError, match="defect"):
        client.get(reverse("money:transaction-edit", args=[1]))


def test_edit_unexpected_save_exception_propagates(client, monkeypatch):
    item = make_transaction()

    def fail_save(self, *args, **kwargs):
        raise RuntimeError("defect")

    monkeypatch.setattr(TransactionForm, "save", fail_save)
    with pytest.raises(RuntimeError, match="defect"):
        client.post(reverse("money:transaction-edit", args=[item.pk]), update_data())
