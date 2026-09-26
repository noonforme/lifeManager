from datetime import date,time

import pytest
from lifeos.core.clock import override_clock
from lifeos.habits.models import Habit,HabitOccurrence
from .test_lifecycle import FixedClock

pytestmark = pytest.mark.django_db


def test_register_selected_date_order_attention_and_compact_privacy(client):
    h = Habit.objects.create(name="Example",start_date=date(2024,1,1),reminder_time=time(9))
    HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,3),result="completed",note="private-note",excuse_reason="")
    with override_clock(FixedClock(date(2024,1,3))):
        r=client.get("/habits/",{"date":"2024-01-03"})
        assert r.status_code==200
        text=r.content.decode()
        assert "Needs attention" in text and "Completed" in text
        assert "private-note" not in text
        assert client.post("/habits/").status_code==405
        r=client.get("/habits/",{"date":"unsafe-marker"})
        assert "unsafe-marker" not in r.content.decode()
        assert "YYYY-MM-DD" in r.content.decode()


def test_attention_has_exact_90_day_bound_and_snapshot_is_frozen():
    from lifeos.habits.queries import register_snapshot
    h=Habit.objects.create(name="Example",start_date=date(2023,1,1))
    snap=register_snapshot(selected_date=date(2024,1,3),today=date(2024,1,3))
    assert snap.attention_count==90
    assert snap.due[0].attention[0]==date(2023,10,5)
    with pytest.raises(AttributeError): snap.active_count=2
