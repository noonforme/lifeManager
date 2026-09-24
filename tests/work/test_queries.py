from dataclasses import FrozenInstanceError
from datetime import date
from decimal import Decimal

import pytest

from lifeos.work.calculations import SalaryInput
from lifeos.work.models import Shift
from lifeos.work.queries import (
    CalendarMonth,
    nearest_shift,
    salary_inputs_for_month,
    select_month,
    shifts_for_month,
)

pytestmark = pytest.mark.django_db


def create_shift(work_date, *, shift_type=Shift.Type.NORMAL):
    return Shift.objects.create(
        work_date=work_date,
        shift_type=shift_type,
        worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"),
        hourly_rate=Decimal("20.00"),
    )


def test_missing_month_defaults_without_error():
    selection = select_month(None, today=date(2026, 9, 25))
    assert selection.month == CalendarMonth(2026, 9)
    assert selection.error is None


@pytest.mark.parametrize(
    "raw_value",
    ["2026-9", "26-09", "2026-00", "2026-13", " 2026-09 ", "", "other"],
)
def test_invalid_month_falls_back_with_visible_error(raw_value):
    selection = select_month(raw_value, today=date(2026, 9, 25))
    assert selection.month == CalendarMonth(2026, 9)
    assert selection.error == "Enter a month in YYYY-MM format."


def test_month_values_labels_and_year_rollover():
    december = CalendarMonth(2026, 12)
    assert december.value == "2026-12"
    assert december.label == "December 2026"
    assert december.first_day == date(2026, 12, 1)
    assert december.next_first_day == date(2027, 1, 1)
    assert december.previous() == CalendarMonth(2026, 11)
    assert december.next() == CalendarMonth(2027, 1)


def test_month_values_are_frozen():
    month = CalendarMonth(2026, 9)
    with pytest.raises(FrozenInstanceError):
        month.month = 10


def test_month_query_uses_half_open_leap_year_boundaries():
    february = CalendarMonth(2024, 2)
    january = create_shift(date(2024, 1, 31))
    first = create_shift(date(2024, 2, 1))
    leap = create_shift(date(2024, 2, 29))
    march = create_shift(date(2024, 3, 1))
    assert list(shifts_for_month(february)) == [leap, first]
    assert january not in shifts_for_month(february)
    assert march not in shifts_for_month(february)


def test_month_query_uses_deterministic_history_order():
    previous = create_shift(date(2026, 9, 24))
    first = create_shift(date(2026, 9, 25))
    second = create_shift(date(2026, 9, 25), shift_type=Shift.Type.NIGHT)
    assert list(shifts_for_month(CalendarMonth(2026, 9))) == [
        second,
        first,
        previous,
    ]


def test_salary_inputs_are_immutable_adapters():
    create_shift(date(2026, 9, 25), shift_type=Shift.Type.HOLIDAY)
    records = salary_inputs_for_month(CalendarMonth(2026, 9))
    assert records == (
        SalaryInput(
            Decimal("8.00"),
            Decimal("1.00"),
            Decimal("20.00"),
            Shift.Type.HOLIDAY,
        ),
    )
    with pytest.raises(FrozenInstanceError):
        records[0].hourly_rate = Decimal("1.00")


def test_nearest_shift_treats_today_as_next():
    today = create_shift(date(2026, 9, 25))
    create_shift(date(2026, 9, 24))
    assert nearest_shift(
        month=CalendarMonth(2026, 9),
        target=date(2026, 9, 25),
    ) == today


def test_nearest_shift_prefers_future_on_equal_distance():
    create_shift(date(2026, 9, 24))
    future = create_shift(date(2026, 9, 26))
    assert nearest_shift(
        month=CalendarMonth(2026, 9),
        target=date(2026, 9, 25),
    ) == future


def test_nearest_shift_uses_newest_record_for_same_date():
    create_shift(date(2026, 9, 25))
    latest = create_shift(date(2026, 9, 25), shift_type=Shift.Type.NIGHT)
    assert nearest_shift(
        month=CalendarMonth(2026, 9),
        target=date(2026, 9, 25),
    ) == latest


def test_nearest_shift_returns_none_for_empty_month():
    assert nearest_shift(
        month=CalendarMonth(2026, 9),
        target=date(2026, 9, 25),
    ) is None
