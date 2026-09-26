from datetime import date
from django.db import DatabaseError
from django.urls import reverse
from lifeos.core.dashboard import LabelledValue,RegisterSummary,SummaryUnavailable
from .queries import register_snapshot

NEW_HABIT_PATH = "/habits/new/"


def get_summary(*,today:date) -> RegisterSummary:
    try:
        snapshot=register_snapshot(selected_date=today,today=today)
    except DatabaseError as error:
        raise SummaryUnavailable("Habits summary unavailable") from error
    return RegisterSummary(key="habits",title="Habits",description="No habits yet." if not snapshot.active_count else "Personal routines; attention covers the previous 90 days. Reminder times are in-app only.",href=reverse("habits:register"),action_label="New habit",action_href=reverse("habits:habit-create"),state="ready" if snapshot.active_count else "empty",state_label="Ready" if snapshot.active_count else "Empty",values=(LabelledValue("Due today",str(len(snapshot.due))),LabelledValue("Completed",str(snapshot.completed)),LabelledValue("Needs attention",str(snapshot.attention_count)),LabelledValue("Active habits",str(snapshot.active_count))) if snapshot.active_count else ())
