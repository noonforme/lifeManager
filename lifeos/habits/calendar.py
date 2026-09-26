from dataclasses import dataclass
from datetime import date
from django.urls import reverse
from .queries import loaded_habits, occurrence_row, schedule_for
from .recurrence import due_dates


@dataclass(frozen=True,slots=True)
class HabitEvent:
    domain: str
    reference: str
    day: date
    title: str
    state: str
    href: str


def project_events(*,start:date,end:date,today:date) -> tuple[HabitEvent,...]:
    """Read-only projection, at most 366 inclusive dates; DatabaseError propagates."""
    if end<start or (end-start).days+1>366:
        raise ValueError("Use an ordered date range of at most 366 days")
    habits=tuple(loaded_habits(occurrence_start=start, occurrence_end=end))
    events=[]
    for h in habits:
        schedule=schedule_for(h)
        records={o.occurrence_date:o for o in h.occurrences.all() if start<=o.occurrence_date<=end}
        for day in sorted(set(due_dates(schedule,start=start,end=end)) | set(records)):
            item=records.get(day)
            state=occurrence_row(h,item,schedule).label if item else ("Pending" if day>today else "Awaiting entry" if day==today else "Unknown")
            href=reverse("habits:occurrence-detail",kwargs={"pk":h.pk,"occurrence_pk":item.pk}) if item else reverse("habits:habit-detail",kwargs={"pk":h.pk})
            events.append(HabitEvent("habits",f"habit-{h.pk}-{day.isoformat()}",day,h.name,state,href))
    return tuple(sorted(events,key=lambda e:(e.day,e.title.casefold(),e.reference)))
