import re
from dataclasses import dataclass
from datetime import date

from django.db.models import QuerySet

from .models import Transaction

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
    year = int(match["year"])
    if not 2 <= year <= 9998:
        return MonthSelection(fallback, MONTH_ERROR)
    return MonthSelection(CalendarMonth(year, int(match["month"])), None)


def transactions_for_month(month: CalendarMonth) -> QuerySet[Transaction]:
    return Transaction.objects.filter(
        transaction_date__gte=month.first_day,
        transaction_date__lt=month.next_first_day,
    )


def transaction_snapshot_for_month(month: CalendarMonth) -> tuple[Transaction, ...]:
    return tuple(transactions_for_month(month))
