import re
from dataclasses import dataclass
from datetime import date, time
from decimal import Decimal

from .calculations import OutcomeInput, QuantityTarget, calculate_momentum, calculate_streak, target_met
from .models import Habit
from .recurrence import ScheduleInput, describe_schedule, due_dates, is_due, next_due


@dataclass(frozen=True, slots=True)
class DateSelection:
    day: date
    error: str | None = None


def select_date(raw_value: str | None, *, today: date) -> DateSelection:
    if raw_value is None:
        return DateSelection(today)
    if re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}",raw_value):
        try:
            return DateSelection(date.fromisoformat(raw_value))
        except ValueError:
            pass
    return DateSelection(today,"Enter a date in YYYY-MM-DD format.")


def persisted_schedule(**configuration):
    from django.db import DatabaseError
    try:
        return ScheduleInput(**configuration)
    except ValueError:
        raise DatabaseError("Invalid persisted habit configuration") from None


def schedule_for(habit) -> ScheduleInput:
    components = tuple(habit.components.all())
    exceptions = tuple(habit.exceptions.all())
    return persisted_schedule(start_date=habit.start_date,end_date=habit.end_date,kind=habit.recurrence_kind,
        interval_n=habit.interval_n,interval_unit=habit.interval_unit,anchor_date=habit.anchor_date,
        weekdays=tuple(c.value for c in components if c.kind=="weekday"),
        month_days=tuple(c.value for c in components if c.kind=="month_day"),
        ordinal_weekdays=tuple((c.ordinal,c.value) for c in components if c.kind=="ordinal"),
        additions=tuple(e.day for e in exceptions if e.kind=="addition"),
        exclusions=tuple(e.day for e in exceptions if e.kind=="exclusion"),
        pauses=tuple((p.start_date,p.end_date) for p in habit.pauses.all()),
        archive_periods=tuple((p.start_date,p.end_date) for p in habit.archive_periods.all()))


def loaded_habits(*, occurrence_start=None, occurrence_end=None):
    from django.db.models import Prefetch
    from .models import HabitOccurrence
    records = HabitOccurrence.objects.all()
    if occurrence_start is not None:
        records = records.filter(occurrence_date__gte=occurrence_start, occurrence_date__lte=occurrence_end)
    else:
        records = records.only("pk", "habit_id", "occurrence_date", "result", "value")
    return Habit.objects.prefetch_related("components","exceptions","pauses","archive_periods",Prefetch("occurrences", queryset=records))


def evidence_state(habit, occurrence):
    if occurrence.result == "excused":
        return "excused"
    if habit.habit_type == "quantity":
        return "success" if target_met(occurrence.value,QuantityTarget(habit.target_rule,habit.lower_target,habit.upper_target)) else "failure"
    return "success" if occurrence.result in {"completed","successful"} else "failure"


@dataclass(frozen=True, slots=True)
class OccurrenceRow:
    pk: int
    day: date
    label: str
    note: str
    reason: str
    retained: bool


def occurrence_label(h, o):
    if h.habit_type == "quantity" and o.value is not None:
        label = f"{o.value:.2f} {h.unit} — {'Target met' if evidence_state(h,o)=='success' else 'Target not met'}"
    else:
        label = o.result.title()
    return label


def occurrence_row(h, o, schedule):
    return OccurrenceRow(o.pk,o.occurrence_date,occurrence_label(h,o),o.note,o.excuse_reason,not is_due(schedule,o.occurrence_date))


@dataclass(frozen=True, slots=True)
class HabitRow:
    pk: int
    name: str
    habit_type: str
    schedule: str
    reminder_time: time | None
    reminder_text: str
    state: str
    current: int
    longest: int
    momentum: Decimal
    next_date: date | None
    attention: tuple[date, ...]
    history: tuple[OccurrenceRow, ...]
    unit: str
    target: str


def row_for(h, *, selected_date, today):
    schedule = schedule_for(h)
    records = tuple(h.occurrences.all())
    outcomes = tuple(OutcomeInput(o.occurrence_date,evidence_state(h,o)) for o in records)
    streak = calculate_streak(schedule,outcomes,today=today)
    momentum = calculate_momentum(o.day for o in outcomes if o.state=="success" and o.day<=today and is_due(schedule,o.day))
    item = next((o for o in records if o.occurrence_date==selected_date),None)
    if item:
        state = occurrence_label(h,item)
    elif not is_due(schedule,selected_date):
        state = "Not due"
    elif selected_date > today:
        state = "Pending"
    elif selected_date == today:
        state = "Awaiting entry"
    else:
        state = "Overdue — Unknown" if h.habit_type=="chore" else "Unknown"
    start = date.fromordinal(max(date.min.toordinal(),selected_date.toordinal()-90))
    end_ord = min(selected_date.toordinal(),today.toordinal())-1
    attention = ()
    if end_ord >= start.toordinal():
        recorded = {o.occurrence_date for o in records}
        attention = tuple(d for d in due_dates(schedule,start=start,end=date.fromordinal(end_ord)) if d not in recorded)
    horizon = date.fromordinal(min(date.max.toordinal(),today.toordinal()+36600))
    following = next_due(schedule,after=today,end=horizon)
    target = ""
    if h.habit_type=="quantity":
        target = f"{h.get_target_rule_display()}: " + (f"{h.lower_target:.2f}–{h.upper_target:.2f}" if h.target_rule=="range" else f"{(h.lower_target if h.lower_target is not None else h.upper_target):.2f}") + f" {h.unit}"
    return HabitRow(h.pk,h.name,h.get_habit_type_display(),describe_schedule(schedule),h.reminder_time,h.reminder_text,state,streak.current,streak.longest,momentum.value,following,attention,(),h.unit,target)


@dataclass(frozen=True, slots=True)
class RegisterSnapshot:
    due: tuple[HabitRow, ...]
    not_due: tuple[HabitRow, ...]
    active_count: int
    completed: int
    attention_count: int


def register_snapshot(*, selected_date: date, today: date) -> RegisterSnapshot:
    habits = tuple(loaded_habits().filter(is_archived=False))
    rows = tuple((h,row_for(h,selected_date=selected_date,today=today)) for h in habits)
    key = lambda pair: (pair[0].reminder_time is None,pair[0].reminder_time or time.max,pair[0].name.casefold(),pair[0].pk)
    due = tuple(r for h,r in sorted(rows,key=key) if is_due(schedule_for(h),selected_date))
    not_due = tuple(r for h,r in sorted(rows,key=key) if not is_due(schedule_for(h),selected_date))
    completed = sum(any(o.occurrence_date==selected_date and evidence_state(h,o)=="success" for o in h.occurrences.all()) for h,r in rows if is_due(schedule_for(h),selected_date))
    return RegisterSnapshot(due,not_due,len(habits),completed,sum(len(r.attention) for h,r in rows))
