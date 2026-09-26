from calendar import monthrange
from dataclasses import dataclass
from datetime import date

MAX_EXPANSION_DAYS = 36600
ATTENTION_DAYS = 90


@dataclass(frozen=True, slots=True)
class ScheduleInput:
    start_date: date
    end_date: date | None = None
    kind: str = "daily"
    interval_n: int = 1
    interval_unit: str = "days"
    anchor_date: date | None = None
    weekdays: tuple[int, ...] = ()
    month_days: tuple[int, ...] = ()
    ordinal_weekdays: tuple[tuple[int, int], ...] = ()
    additions: tuple[date, ...] = ()
    exclusions: tuple[date, ...] = ()
    pauses: tuple[tuple[date, date], ...] = ()
    archive_periods: tuple[tuple[date, date | None], ...] = ()

    def __post_init__(self):
        if self.kind not in {"daily", "weekly", "interval", "monthly_dates", "monthly_ordinal_weekdays"}:
            raise ValueError("Invalid recurrence kind")
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("Invalid active range")
        if not 1 <= self.interval_n <= 3650 or self.interval_unit not in {"days", "weeks"}:
            raise ValueError("Invalid interval")
        if self.kind == "interval" and self.anchor_date is None:
            raise ValueError("An interval requires an anchor")
        if self.kind == "weekly" and not self.weekdays:
            raise ValueError("Select weekdays")
        if self.kind == "monthly_dates" and not self.month_days:
            raise ValueError("Select month dates")
        if self.kind == "monthly_ordinal_weekdays" and not self.ordinal_weekdays:
            raise ValueError("Select ordinal weekdays")
        if any(x not in range(7) for x in self.weekdays) or any(x not in range(1,32) for x in self.month_days):
            raise ValueError("Invalid recurrence component")
        if any(o not in (1,2,3,4,-1) or w not in range(7) for o,w in self.ordinal_weekdays):
            raise ValueError("Invalid ordinal weekday")
        if set(self.additions) & set(self.exclusions):
            raise ValueError("An added date cannot also be excluded")
        if any(a > b for a,b in self.pauses) or any(b is not None and a > b for a,b in self.archive_periods):
            raise ValueError("Invalid suspension range")


def is_due(schedule: ScheduleInput, day: date) -> bool:
    if day < schedule.start_date or (schedule.end_date is not None and day > schedule.end_date):
        return False
    if any(a <= day <= b for a,b in schedule.pauses):
        return False
    if any(a <= day and (b is None or day < b) for a,b in schedule.archive_periods):
        return False
    if day in schedule.exclusions:
        return False
    if day in schedule.additions:
        return True
    if schedule.kind == "daily":
        return True
    if schedule.kind == "weekly":
        return day.weekday() in schedule.weekdays
    if schedule.kind == "interval":
        delta = (day - schedule.anchor_date).days
        return delta >= 0 and delta % (schedule.interval_n * (7 if schedule.interval_unit == "weeks" else 1)) == 0
    if schedule.kind == "monthly_dates":
        return day.day in schedule.month_days
    return any(day.weekday() == w and ((day.day-1)//7+1 == o if o != -1 else day.day+7 > monthrange(day.year,day.month)[1]) for o,w in schedule.ordinal_weekdays)


def due_dates(schedule: ScheduleInput, *, start: date, end: date) -> tuple[date, ...]:
    if end < start or (end-start).days+1 > MAX_EXPANSION_DAYS:
        raise ValueError("Use a finite ordered date range of at most 36600 days")
    return tuple(date.fromordinal(n) for n in range(start.toordinal(),end.toordinal()+1) if is_due(schedule,date.fromordinal(n)))


def _search(schedule, first, last, direction):
    n = first
    while (n <= last if direction == 1 else n >= last):
        day = date.fromordinal(n)
        jump = None
        for a,b in schedule.pauses:
            if a <= day <= b:
                jump = b.toordinal()+1 if direction == 1 else a.toordinal()-1
        for a,b in schedule.archive_periods:
            if a <= day and (b is None or day < b):
                jump = (b.toordinal() if b else date.max.toordinal()+1) if direction == 1 else a.toordinal()-1
        if jump is not None:
            n = jump
            continue
        if is_due(schedule,day):
            return day
        n += direction
    return None


def next_due(schedule: ScheduleInput, *, after: date, end: date) -> date | None:
    first = max(after.toordinal()+1,schedule.start_date.toordinal())
    last = min(end.toordinal(), (schedule.end_date or date.max).toordinal())
    return _search(schedule,first,last,1)


def previous_due(schedule: ScheduleInput, *, before: date, start: date) -> date | None:
    first = min(before.toordinal()-1,(schedule.end_date or date.max).toordinal())
    last = max(start.toordinal(),schedule.start_date.toordinal())
    return _search(schedule,first,last,-1)


def describe_schedule(schedule: ScheduleInput) -> str:
    names = ("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday")
    if schedule.kind == "daily":
        return "Every day"
    if schedule.kind == "weekly":
        return "Weekly: " + ", ".join(names[w] for w in sorted(set(schedule.weekdays)))
    if schedule.kind == "interval":
        return f"Every {schedule.interval_n} {schedule.interval_unit} from {schedule.anchor_date.isoformat()}"
    if schedule.kind == "monthly_dates":
        return "Monthly dates: " + ", ".join(str(x) for x in sorted(set(schedule.month_days)))
    ordinals = {1:"First",2:"Second",3:"Third",4:"Fourth",-1:"Last"}
    return "Monthly: " + ", ".join(f"{ordinals[o]} {names[w]}" for o,w in sorted(set(schedule.ordinal_weekdays)))
