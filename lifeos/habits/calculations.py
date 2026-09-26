from collections.abc import Iterable
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from math import exp

from .recurrence import ScheduleInput, is_due, next_due


@dataclass(frozen=True, slots=True)
class QuantityTarget:
    rule: str
    lower: Decimal | None = None
    upper: Decimal | None = None


def target_met(value: Decimal, target: QuantityTarget) -> bool:
    if target.rule == "at_least":
        return value >= target.lower
    if target.rule == "at_most":
        return value <= target.upper
    return target.lower <= value <= target.upper


@dataclass(frozen=True, slots=True)
class MomentumResult:
    value: Decimal
    successful_dates: tuple[date, ...]


def calculate_momentum(successful_dates: Iterable[date]) -> MomentumResult:
    dates = tuple(sorted(set(successful_dates)))
    value = Decimal("0.00")
    previous = None
    for day in dates:
        elapsed = (day-previous).days if previous else 1
        value = (value * Decimal(str(exp(-0.1 * elapsed))) + 1).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        previous = day
    return MomentumResult(value,dates)


@dataclass(frozen=True, slots=True)
class OutcomeInput:
    day: date
    state: str


@dataclass(frozen=True, slots=True)
class StreakResult:
    current: int
    longest: int
    has_overdue_unknown: bool
    most_recent_result: str | None


def calculate_streak(schedule: ScheduleInput, occurrences: tuple[OutcomeInput, ...], *, today: date) -> StreakResult:
    records = sorted((o for o in occurrences if o.day <= today and is_due(schedule,o.day)),key=lambda o:o.day)
    current = longest = 0
    unknown = False
    recent = None
    cursor = date.fromordinal(schedule.start_date.toordinal()-1) if schedule.start_date > date.min else None
    for item in records:
        first = next_due(schedule,after=cursor,end=item.day) if cursor else (date.min if is_due(schedule,date.min) else next_due(schedule,after=date.min,end=item.day))
        if first is not None and first < item.day:
            unknown = True
            current = 0
        if item.state == "success":
            current += 1
            longest = max(longest,current)
        elif item.state != "excused":
            current = 0
        recent = item.state
        cursor = item.day
    past_end = date.fromordinal(today.toordinal()-1) if today > date.min else None
    if past_end and past_end >= schedule.start_date:
        first = next_due(schedule,after=cursor,end=past_end) if cursor else (date.min if is_due(schedule,date.min) else next_due(schedule,after=date.min,end=past_end))
        if first is not None:
            unknown = True
            current = 0
            recent = "Unknown"
    return StreakResult(current,longest,unknown,recent)
