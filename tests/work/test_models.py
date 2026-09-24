from datetime import date, timedelta
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

from lifeos.work.models import Shift

pytestmark = pytest.mark.django_db


def make_shift(**overrides):
    values = {
        "work_date": date(2026, 9, 25),
        "shift_type": Shift.Type.NORMAL,
        "worked_hours": Decimal("8.00"),
        "overtime_hours": Decimal("1.00"),
        "hourly_rate": Decimal("20.00"),
        "note": "",
    }
    values.update(overrides)
    return Shift(**values)


def test_shift_type_choices_are_fixed():
    assert Shift.Type.choices == [
        ("normal", "Normal"),
        ("night", "Night"),
        ("holiday", "Holiday"),
    ]


@pytest.mark.parametrize(("note", "expected"), [
    ("  reconciled  ", "reconciled"),
    ("   ", ""),
    ("x" * 500, "x" * 500),
])
def test_shift_normalizes_valid_notes(note, expected):
    shift = make_shift(note=note)
    shift.full_clean()
    assert shift.note == expected


def test_shift_rejects_note_longer_than_500_after_trimming():
    with pytest.raises(ValidationError) as error:
        make_shift(note="x" * 501).full_clean()
    assert "note" in error.value.message_dict


@pytest.mark.parametrize(("field", "value"), [
    ("worked_hours", Decimal("0.00")),
    ("worked_hours", Decimal("24.01")),
    ("overtime_hours", Decimal("-0.01")),
    ("overtime_hours", Decimal("24.01")),
    ("hourly_rate", Decimal("-0.01")),
    ("hourly_rate", Decimal("10000.01")),
])
def test_shift_rejects_values_outside_bounds(field, value):
    with pytest.raises(ValidationError) as error:
        make_shift(**{field: value}).full_clean()
    assert field in error.value.message_dict


@pytest.mark.parametrize("field", ["worked_hours", "overtime_hours", "hourly_rate"])
@pytest.mark.parametrize("value", [Decimal("1.001"), Decimal("NaN"), Decimal("Infinity")])
def test_shift_rejects_invalid_decimal_values(field, value):
    with pytest.raises(ValidationError) as error:
        make_shift(**{field: value}).full_clean()
    assert field in error.value.message_dict


def test_shift_rejects_unknown_type():
    with pytest.raises(ValidationError) as error:
        make_shift(shift_type="unknown").full_clean()
    assert "shift_type" in error.value.message_dict


@pytest.mark.parametrize(("field", "value"), [
    ("worked_hours", Decimal("0.00")),
    ("overtime_hours", Decimal("-0.01")),
    ("hourly_rate", Decimal("-0.01")),
])
def test_database_constraints_reject_invalid_ranges(field, value):
    values = make_shift(**{field: value})
    with pytest.raises(IntegrityError), transaction.atomic():
        Shift.objects.create(
            work_date=values.work_date,
            shift_type=values.shift_type,
            worked_hours=values.worked_hours,
            overtime_hours=values.overtime_hours,
            hourly_rate=values.hourly_rate,
            note=values.note,
        )


def test_overtime_may_exceed_worked_hours():
    shift = make_shift(
        worked_hours=Decimal("1.00"),
        overtime_hours=Decimal("2.00"),
    )
    shift.full_clean()
    shift.save()
    assert shift.pk is not None


def test_future_dates_and_multiple_shifts_per_date_are_allowed():
    future = date.today() + timedelta(days=30)
    first = make_shift(work_date=future)
    second = make_shift(work_date=future, shift_type=Shift.Type.NIGHT)
    first.full_clean()
    second.full_clean()
    first.save()
    second.save()
    assert Shift.objects.filter(work_date=future).count() == 2


def test_timestamps_are_timezone_aware():
    shift = make_shift()
    shift.full_clean()
    shift.save()
    assert timezone.is_aware(shift.created_at)
    assert timezone.is_aware(shift.updated_at)


def test_default_order_is_date_creation_and_identifier_descending():
    older_date = make_shift(work_date=date(2026, 9, 24))
    older_date.save()
    first = make_shift(note="first")
    first.save()
    second = make_shift(note="second")
    second.save()
    assert list(Shift.objects.values_list("pk", flat=True)) == [
        second.pk,
        first.pk,
        older_date.pk,
    ]
