from datetime import date, timedelta
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

from lifeos.money.models import Transaction

pytestmark = pytest.mark.django_db


def make_transaction(**overrides):
    values = {
        "transaction_date": date(2026, 9, 25),
        "direction": Transaction.Direction.EXPENSE,
        "amount": Decimal("12.34"),
        "category": "Groceries",
        "note": "",
    }
    values.update(overrides)
    return Transaction(**values)


def test_direction_choices_are_fixed():
    assert Transaction.Direction.choices == [
        ("income", "Income"),
        ("expense", "Expense"),
    ]


@pytest.mark.parametrize("amount", [Decimal("0.01"), Decimal("999999999.99")])
def test_amount_boundaries_are_valid(amount):
    item = make_transaction(amount=amount)
    item.full_clean()
    item.save()
    assert Transaction.objects.get(pk=item.pk).amount == amount


@pytest.mark.parametrize(
    "amount",
    [
        Decimal("0"),
        Decimal("-0.01"),
        Decimal("1000000000.00"),
        Decimal("1.001"),
        Decimal("1E+2"),
        Decimal("NaN"),
        Decimal("Infinity"),
    ],
)
def test_model_rejects_invalid_amounts(amount):
    with pytest.raises(ValidationError) as error:
        make_transaction(amount=amount).full_clean()
    assert "amount" in error.value.message_dict


@pytest.mark.parametrize("amount", [Decimal("0.00"), Decimal("1000000000.00")])
def test_database_constraints_reject_out_of_range_amounts(amount):
    with pytest.raises(IntegrityError), transaction.atomic():
        Transaction.objects.create(
            transaction_date=date(2026, 9, 25),
            direction="income",
            amount=amount,
            category="Salary",
        )


@pytest.mark.parametrize(
    ("category", "expected"),
    [
        ("x", "x"),
        ("x" * 80, "x" * 80),
        ("  Groceries  ", "Groceries"),
    ],
)
def test_valid_categories_are_trimmed(category, expected):
    item = make_transaction(category=category)
    item.full_clean()
    assert item.category == expected


@pytest.mark.parametrize("category", ["", "   ", "x" * 81])
def test_invalid_categories_are_rejected_after_trimming(category):
    with pytest.raises(ValidationError) as error:
        make_transaction(category=category).full_clean()
    assert "category" in error.value.message_dict


@pytest.mark.parametrize(
    ("note", "expected"),
    [
        (None, ""),
        ("   ", ""),
        ("  private note  ", "private note"),
        ("x" * 500, "x" * 500),
    ],
)
def test_notes_are_trimmed_and_blank_normalizes_to_empty(note, expected):
    item = make_transaction(note=note)
    item.full_clean()
    assert item.note == expected


def test_note_longer_than_500_is_rejected_after_trimming():
    with pytest.raises(ValidationError) as error:
        make_transaction(note="x" * 501).full_clean()
    assert "note" in error.value.message_dict


def test_transaction_date_is_required():
    with pytest.raises(ValidationError) as error:
        make_transaction(transaction_date=None).full_clean()
    assert "transaction_date" in error.value.message_dict


def test_unknown_direction_is_rejected():
    with pytest.raises(ValidationError) as error:
        make_transaction(direction="unknown").full_clean()
    assert "direction" in error.value.message_dict


def test_future_dates_and_identical_transactions_are_allowed():
    future = date.today() + timedelta(days=30)
    first = make_transaction(transaction_date=future)
    second = make_transaction(transaction_date=future)
    for item in (first, second):
        item.full_clean()
        item.save()
    assert Transaction.objects.filter(transaction_date=future).count() == 2


def test_timestamps_are_timezone_aware():
    item = make_transaction()
    item.full_clean()
    item.save()
    assert timezone.is_aware(item.created_at)
    assert timezone.is_aware(item.updated_at)


def test_default_order_is_date_creation_and_identifier_descending():
    older = make_transaction(transaction_date=date(2026, 9, 24))
    older.save()
    first = make_transaction(note="first")
    first.save()
    second = make_transaction(note="second")
    second.save()
    assert list(Transaction.objects.values_list("pk", flat=True)) == [
        second.pk,
        first.pk,
        older.pk,
    ]
