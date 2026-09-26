from datetime import date

import pytest
from django.db import DatabaseError
from lifeos.core.dashboard import SummaryUnavailable
from lifeos.habits.models import Habit,HabitOccurrence
from lifeos.habits.summary import get_summary

pytestmark=pytest.mark.django_db


def test_summary_empty_and_exact_ready_values():
    summary=get_summary(today=date(2024,1,2))
    assert summary.href=="/habits/" and summary.action_href=="/habits/new/"
    h=Habit.objects.create(name="Example",start_date=date(2024,1,1))
    HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,2),result="completed")
    summary=get_summary(today=date(2024,1,2))
    assert [(v.label,v.value) for v in summary.values]==[("Due today","1"),("Completed","1"),("Needs attention","1"),("Active habits","1")]


def test_summary_expected_database_failure_only(monkeypatch):
    def fail(**kw): raise DatabaseError("private")
    monkeypatch.setattr("lifeos.habits.summary.register_snapshot",fail)
    with pytest.raises(SummaryUnavailable): get_summary(today=date(2024,1,2))
