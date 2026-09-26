from dataclasses import replace
from datetime import date

import pytest


def schedule(**kw):
    from lifeos.habits.recurrence import ScheduleInput
    return ScheduleInput(start_date=date(2024, 1, 1), **kw)


@pytest.mark.parametrize("kind,kw,start,end,want", [
    ("daily", {}, "2024-02-28", "2024-03-01", ["2024-02-28", "2024-02-29", "2024-03-01"]),
    ("weekly", {"weekdays": (0, 4)}, "2024-01-01", "2024-01-07", ["2024-01-01", "2024-01-05"]),
    ("interval", {"interval_n": 2, "interval_unit": "days", "anchor_date": date(2024,1,1)}, "2024-01-01", "2024-01-06", ["2024-01-01", "2024-01-03", "2024-01-05"]),
    ("interval", {"interval_n": 1, "interval_unit": "weeks", "anchor_date": date(2024,1,1)}, "2024-01-01", "2024-01-10", ["2024-01-01", "2024-01-08"]),
    ("monthly_dates", {"month_days": (31,)}, "2024-02-01", "2024-03-31", ["2024-03-31"]),
    ("monthly_ordinal_weekdays", {"ordinal_weekdays": ((1,0),(2,0),(3,0),(4,0),(-1,0))}, "2024-01-01", "2024-01-31", ["2024-01-01","2024-01-08","2024-01-15","2024-01-22","2024-01-29"]),
])
def test_due_dates_are_explicit_calendar_dates(kind, kw, start, end, want):
    from lifeos.habits.recurrence import due_dates
    got = due_dates(schedule(kind=kind, **kw), start=date.fromisoformat(start), end=date.fromisoformat(end))
    assert [x.isoformat() for x in got] == want


def test_due_precedence_and_inclusive_active_range():
    from lifeos.habits.recurrence import due_dates
    s = schedule(end_date=date(2024,1,7), additions=(date(2024,1,2),), exclusions=(date(2024,1,3),), pauses=((date(2024,1,2), date(2024,1,4)), (date(2024,1,4),date(2024,1,5))))
    assert due_dates(s,start=date(2023,12,31),end=date(2024,1,8)) == (date(2024,1,1),date(2024,1,6),date(2024,1,7))


def test_archive_period_has_exclusive_restore_boundary():
    from lifeos.habits.recurrence import is_due
    s = schedule(archive_periods=((date(2024,1,2),date(2024,1,5)),))
    assert not is_due(s,date(2024,1,4))
    assert is_due(s,date(2024,1,5))


def test_next_previous_and_extreme_dates():
    from lifeos.habits.recurrence import next_due, previous_due, due_dates
    s = schedule(kind="weekly",weekdays=(0,))
    assert next_due(s,after=date(2024,1,1),end=date(2024,1,9)) == date(2024,1,8)
    assert previous_due(s,before=date(2024,1,9),start=date(2024,1,1)) == date(2024,1,8)
    assert due_dates(replace(s,start_date=date.min,kind="daily",weekdays=()),start=date.max,end=date.max) == (date.max,)
    assert next_due(s,after=date.max,end=date.max) is None
    assert previous_due(s,before=date.min,start=date.min) is None


@pytest.mark.parametrize("kw", [{"interval_n": 0,"kind":"interval"}, {"kind":"weekly"}, {"kind":"monthly_dates","month_days":(32,)}, {"additions":(date(2024,1,2),),"exclusions":(date(2024,1,2),)}])
def test_invalid_schedule_rejected(kw):
    with pytest.raises(ValueError):
        schedule(**kw)


def test_expansion_is_bounded_and_snapshot_frozen():
    from lifeos.habits.recurrence import due_dates
    s = schedule()
    with pytest.raises(ValueError):
        due_dates(s,start=date.min,end=date.max)
    with pytest.raises(AttributeError):
        s.kind = "weekly"
