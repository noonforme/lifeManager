from datetime import date
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

pytestmark = pytest.mark.django_db


def habit(**overrides):
    from lifeos.habits.models import Habit

    return Habit(name="  Reading  ", start_date=date(2026, 9, 25), **overrides)


@pytest.mark.parametrize("kind", ["check", "quantity", "abstinence", "chore"])
def test_habit_types_persist_trimmed_configuration(kind):
    values = {"habit_type": kind}
    if kind == "quantity":
        values.update(unit=" steps ", target_rule="at_least", lower_target=Decimal("0.00"))
    item = habit(description="  Plain text  ", reminder_text="  In app  ", **values)
    item.full_clean()
    item.save()
    item.refresh_from_db()
    assert item.name == "Reading"
    assert item.description == "Plain text"
    assert item.reminder_text == "In app"
    assert timezone.is_aware(item.created_at)
    assert timezone.is_aware(item.updated_at)
    assert item.archived_at is None
    if kind == "quantity":
        assert item.unit == "steps"


@pytest.mark.parametrize("field,value", [
    ("name", " "), ("name", "x" * 121), ("description", "x" * 501),
    ("reminder_text", "x" * 161), ("habit_type", "unknown"),
    ("end_date", date(2026, 9, 24)),
])
def test_habit_rejects_invalid_configuration(field, value):
    item = habit()
    setattr(item, field, value)
    with pytest.raises(ValidationError):
        item.full_clean()


@pytest.mark.parametrize("rule,lower,upper", [
    ("at_least", "0.00", None), ("at_most", None, "999999999.99"),
    ("range", "1.00", "1.00"),
])
def test_quantity_targets_accept_inclusive_bounds(rule, lower, upper):
    item = habit(habit_type="quantity", unit="kg", target_rule=rule,
                 lower_target=Decimal(lower) if lower else None,
                 upper_target=Decimal(upper) if upper else None)
    item.full_clean()
    item.save()
    item.refresh_from_db()
    assert item.target_rule == rule


@pytest.mark.parametrize("rule,lower,upper,unit", [
    ("at_least", None, None, "steps"), ("at_most", "1", "2", "steps"),
    ("at_least", "1", "2", "steps"), ("range", "2", "1", "steps"),
    ("range", "1", None, "steps"), ("at_least", "1", None, " "),
    ("at_least", "1", None, "x" * 41), ("invalid", "1", None, "steps"),
])
def test_quantity_rejects_incoherent_targets(rule, lower, upper, unit):
    item = habit(habit_type="quantity", unit=unit, target_rule=rule,
                 lower_target=Decimal(lower) if lower else None,
                 upper_target=Decimal(upper) if upper else None)
    with pytest.raises(ValidationError):
        item.full_clean()


@pytest.mark.parametrize("value", ["-0.01", "1000000000", "1.001", "1E2", "NaN", "Infinity"])
def test_quantity_rejects_invalid_decimal_at_model_boundary(value):
    item = habit(habit_type="quantity", unit="steps", target_rule="at_least",
                 lower_target=Decimal(value))
    with pytest.raises(ValidationError):
        item.full_clean()


@pytest.mark.parametrize("kind", ["check", "abstinence", "chore"])
def test_non_quantity_habit_rejects_quantity_configuration(kind):
    item = habit(habit_type=kind, unit="steps", target_rule="at_least", lower_target=Decimal("1"))
    with pytest.raises(ValidationError):
        item.full_clean()


def test_active_range_is_inclusive_and_text_limits_follow_trimming():
    item = habit(end_date=date(2026, 9, 25), description="  " + "x" * 500 + "  ")
    item.name = "  " + "x" * 120 + "  "
    item.full_clean()
    assert len(item.name) == 120
    assert len(item.description) == 500


@pytest.mark.parametrize("archived,timestamp", [(True, None), (False, "present")])
def test_archive_state_and_timestamp_must_agree(archived, timestamp):
    item = habit(is_archived=archived, archived_at=timezone.now() if timestamp else None)
    with pytest.raises(ValidationError):
        item.full_clean()


def test_database_rejects_invalid_active_range():
    item = habit(end_date=date(2026, 9, 24))
    with pytest.raises(IntegrityError), transaction.atomic():
        item.save()


def test_database_rejects_quantity_configuration_for_check():
    item = habit(unit="steps", lower_target=Decimal("1"), target_rule="at_least")
    with pytest.raises(IntegrityError), transaction.atomic():
        item.save()
