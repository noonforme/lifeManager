import re
from dataclasses import dataclass
from datetime import date

from django.db.models import QuerySet

from .calculations import SalaryInput
from .models import Shift

MONTH_PATTERN = re.compile(r"^(?P<year>\d{4})-(?P<month>0[1-9]|1[0-2])$")
MONTH_ERROR = "Enter a month in YYYY-MM format."


@dataclass(frozen=True, slots=True)
class CalendarMonth:
    year: int
    month: int

    @property
    def value(self) -> str:
        return f"{self.year:04d}-{self.month:02d}"

    @property
    def label(self) -> str:
        return self.first_day.strftime("%B %Y")

    @property
    def first_day(self) -> date:
        return date(self.year, self.month, 1)

    @property
    def next_first_day(self) -> date:
        return self.next().first_day

    def previous(self) -> "CalendarMonth":
        if self.month == 1:
            return CalendarMonth(self.year - 1, 12)
        return CalendarMonth(self.year, self.month - 1)

    def next(self) -> "CalendarMonth":
        if self.month == 12:
            return CalendarMonth(self.year + 1, 1)
        return CalendarMonth(self.year, self.month + 1)


@dataclass(frozen=True, slots=True)
class MonthSelection:
    month: CalendarMonth
    error: str | None


def select_month(raw_value: str | None, *, today: date) -> MonthSelection:
    fallback = CalendarMonth(today.year, today.month)
    if raw_value is None:
        return MonthSelection(fallback, None)
    match = MONTH_PATTERN.fullmatch(raw_value)
    if match is None:
        return MonthSelection(fallback, MONTH_ERROR)
    return MonthSelection(
        CalendarMonth(int(match["year"]), int(match["month"])),
        None,
    )


def shifts_for_month(month: CalendarMonth) -> QuerySet[Shift]:
    return Shift.objects.filter(
        work_date__gte=month.first_day,
        work_date__lt=month.next_first_day,
    )


def salary_inputs_for_month(month: CalendarMonth) -> tuple[SalaryInput, ...]:
    return tuple(
        SalaryInput(
            worked_hours=shift.worked_hours,
            overtime_hours=shift.overtime_hours,
            hourly_rate=shift.hourly_rate,
            shift_type=shift.shift_type,
        )
        for shift in shifts_for_month(month)
    )


def nearest_shift(*, month: CalendarMonth, target: date) -> Shift | None:
    shifts = tuple(shifts_for_month(month))
    if not shifts:
        return None
    return min(
        shifts,
        key=lambda shift: (
            abs((shift.work_date - target).days),
            0 if shift.work_date >= target else 1,
            -shift.created_at.timestamp(),
            -shift.pk,
        ),
    )
