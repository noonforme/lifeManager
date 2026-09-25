from contextlib import contextmanager
from datetime import date
from decimal import Decimal

import pytest
from django.db import DatabaseError
from django.test import Client
from django.urls import resolve, reverse

from lifeos.money.forms import TransactionForm
from lifeos.money.models import Transaction

pytestmark = pytest.mark.django_db

VALID = {
    "transaction_date": "2026-09-25",
    "direction": "expense",
    "amount": "12.34",
    "category": "  Groceries  ",
    "note": "  private note  ",
}


def test_money_routes_have_canonical_paths_and_names():
    expected = {
        "money:register": "/money/",
        "money:transaction-create": "/money/transactions/new/",
        "money:transaction-detail": "/money/transactions/7/",
        "money:transaction-edit": "/money/transactions/7/edit/",
        "money:transaction-delete": "/money/transactions/7/delete/",
    }
    for name, path in expected.items():
        args = [7] if "detail" in name or "edit" in name or "delete" in name else []
        assert reverse(name, args=args) == path
        assert resolve(path).url_name == name.removeprefix("money:")


def test_register_route_is_get_only(client):
    response = client.get(reverse("money:register"))
    assert response.status_code == 200
    assert "Money register" in response.content.decode()
    assert client.post(reverse("money:register")).status_code == 405


def test_create_get_prefills_only_exact_or_future_date_and_creates_nothing(client):
    for value in ("2026-09-25", "2027-01-01"):
        response = client.get(reverse("money:transaction-create"), {"date": value})
        assert response.status_code == 200
        assert response.context["form"].initial["transaction_date"] == date.fromisoformat(value)
    assert Transaction.objects.count() == 0


@pytest.mark.parametrize("value", ["25-09-2026", "2026-9-25", "2026-02-30"])
def test_create_ignores_malformed_prefill_without_error(client, value):
    response = client.get(reverse("money:transaction-create"), {"date": value})
    assert response.status_code == 200
    assert response.context["form"].initial.get("transaction_date") is None
    assert not response.context["form"].errors


@pytest.mark.parametrize("method", ["put", "patch", "delete"])
def test_create_rejects_methods_other_than_get_and_post(client, method):
    assert getattr(client, method)(reverse("money:transaction-create")).status_code == 405


@pytest.mark.parametrize("method", ["post", "put", "patch", "delete"])
def test_detail_is_explicitly_get_only(client, method):
    item = Transaction.objects.create(
        transaction_date=date(2026, 9, 25),
        direction="income",
        amount=Decimal("10.00"),
        category="Salary",
    )
    response = getattr(client, method)(
        reverse("money:transaction-detail", args=[item.pk])
    )
    assert response.status_code == 405


@pytest.mark.parametrize(
    "amount",
    ["0", "-0.01", "1e2", "NaN", "Infinity", "1.001", "1,00", "1000000000.00"],
)
def test_create_rejects_unsafe_amount_text(client, amount):
    response = client.post(
        reverse("money:transaction-create"), {**VALID, "amount": amount}
    )
    assert response.status_code == 200
    assert Transaction.objects.count() == 0
    assert "amount" in response.context["form"].errors


def test_create_redirects_to_canonical_detail_and_trims_text(client):
    response = client.post(reverse("money:transaction-create"), VALID)
    item = Transaction.objects.get()
    assert response.status_code == 302
    assert response.url == reverse("money:transaction-detail", args=[item.pk])
    assert item.category == "Groceries"
    assert item.note == "private note"


def test_create_enters_one_atomic_boundary_and_saves_once(client, monkeypatch):
    calls = {"atomic": 0, "save": 0}
    original_save = TransactionForm.save

    original_atomic = __import__("django.db.transaction", fromlist=["atomic"]).atomic

    @contextmanager
    def counted_atomic(*args, **kwargs):
        if args or kwargs:
            with original_atomic(*args, **kwargs):
                yield
            return
        calls["atomic"] += 1
        yield

    def counted_save(self, *args, **kwargs):
        calls["save"] += 1
        return original_save(self, *args, **kwargs)

    monkeypatch.setattr("lifeos.money.views.transaction.atomic", counted_atomic)
    monkeypatch.setattr(TransactionForm, "save", counted_save)
    response = client.post(reverse("money:transaction-create"), VALID)
    assert response.status_code == 302
    assert calls == {"atomic": 1, "save": 1}


def test_invalid_create_preserves_safe_values_and_links_multiple_errors(client, caplog):
    response = client.post(
        reverse("money:transaction-create"),
        {
            **VALID,
            "transaction_date": "not-a-date",
            "direction": "unknown",
            "amount": "1.001",
            "category": "private-category-marker",
        },
    )
    content = response.content.decode()
    assert response.status_code == 200
    assert Transaction.objects.count() == 0
    assert "private-category-marker" in content
    assert "Transaction created." not in content
    assert 'class="error-summary"' in content
    assert 'href="#id_transaction_date"' in content
    assert 'aria-invalid="true"' in content
    assert (
        'aria-describedby="id_transaction_date_hint id_transaction_date_error"'
        in content
    )
    assert content.index("id_transaction_date_hint") < content.index(
        "id_transaction_date_error"
    )
    assert "private-category-marker" not in caplog.text


def test_create_validation_database_failure_is_safe(client, monkeypatch, caplog):
    def fail_validation(self, *, exclude=None):
        raise DatabaseError("private validation 99.99 /private/database")

    monkeypatch.setattr(Transaction, "validate_constraints", fail_validation)
    response = client.post(reverse("money:transaction-create"), VALID)
    assert response.status_code == 200
    assert list(response.context["form"].non_field_errors()) == [
        "The transaction could not be saved. Please try again."
    ]
    assert Transaction.objects.count() == 0
    assert "Money transaction create failed (DatabaseError)" in caplog.text
    assert "private validation" not in caplog.text
    assert "/private/database" not in caplog.text


def test_create_save_database_failure_is_safe(client, monkeypatch, caplog):
    def fail_save(self, *args, **kwargs):
        raise DatabaseError("private amount 99.99 /private/database")

    monkeypatch.setattr(TransactionForm, "save", fail_save)
    response = client.post(reverse("money:transaction-create"), VALID)
    assert response.status_code == 200
    assert Transaction.objects.count() == 0
    assert "The transaction could not be saved. Please try again." in response.content.decode()
    assert "DatabaseError" in caplog.text
    assert "private amount" not in caplog.text
    assert "/private/database" not in caplog.text


def test_create_atomic_exit_failure_has_no_false_success(client, monkeypatch):
    original_atomic = __import__("django.db.transaction", fromlist=["atomic"]).atomic

    @contextmanager
    def fail_on_exit(*args, **kwargs):
        if args or kwargs:
            with original_atomic(*args, **kwargs):
                yield
            return
        yield
        raise DatabaseError("private commit outcome")

    monkeypatch.setattr("lifeos.money.views.transaction.atomic", fail_on_exit)
    response = client.post(reverse("money:transaction-create"), VALID)
    content = response.content.decode()
    assert response.status_code == 200
    assert "Transaction created." not in content
    assert "inspect the Money register before retrying" in content


def test_create_unexpected_exception_propagates(client, monkeypatch):
    def fail_save(self, *args, **kwargs):
        raise RuntimeError("programming defect")

    monkeypatch.setattr(TransactionForm, "save", fail_save)
    with pytest.raises(RuntimeError, match="programming defect"):
        client.post(reverse("money:transaction-create"), VALID)


def test_create_requires_csrf():
    client = Client(enforce_csrf_checks=True)
    response = client.post(reverse("money:transaction-create"), VALID)
    assert response.status_code == 403
    assert Transaction.objects.count() == 0


def test_detail_renders_exact_values_escaped_and_single_landmarks(client):
    item = Transaction.objects.create(
        transaction_date=date(2026, 9, 25),
        direction="expense",
        amount=Decimal("12.30"),
        category="<b>Groceries</b>",
        note="<script>private</script>",
    )
    response = client.get(reverse("money:transaction-detail", args=[item.pk]))
    content = response.content.decode()
    assert response.status_code == 200
    assert content.count("<main") == 1
    assert content.count("<h1") == 1
    assert "Transaction review" in content
    assert '<time datetime="2026-09-25">' in content
    assert "Expense" in content
    assert "€12.30" in content
    assert "&lt;b&gt;Groceries&lt;/b&gt;" in content
    assert "&lt;script&gt;private&lt;/script&gt;" in content
    assert "<script>private</script>" not in content


def test_detail_states_when_note_is_empty(client):
    item = Transaction.objects.create(
        transaction_date=date(2026, 9, 25),
        direction="income",
        amount=Decimal("10.00"),
        category="Salary",
        note="",
    )
    response = client.get(reverse("money:transaction-detail", args=[item.pk]))
    assert "No note recorded." in response.content.decode()


def test_missing_detail_returns_404_without_creating_record(client):
    response = client.get(reverse("money:transaction-detail", args=[999]))
    assert response.status_code == 404
    assert Transaction.objects.count() == 0


def test_detail_lookup_database_failure_is_503_not_false_404(client, monkeypatch, caplog):
    monkeypatch.setattr(
        "lifeos.money.views.get_object_or_404",
        lambda *args, **kwargs: (_ for _ in ()).throw(
            DatabaseError("private date amount /private/database")
        ),
    )
    response = client.get(reverse("money:transaction-detail", args=[1]))
    assert response.status_code == 503
    assert "Money transaction detail lookup failed (DatabaseError)" in caplog.text
    assert "private date amount" not in caplog.text
    assert "/private/database" not in caplog.text


def test_detail_unexpected_lookup_exception_propagates(client, monkeypatch):
    monkeypatch.setattr(
        "lifeos.money.views.get_object_or_404",
        lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError("defect")),
    )
    with pytest.raises(RuntimeError, match="defect"):
        client.get(reverse("money:transaction-detail", args=[1]))
