from datetime import date

import pytest
from lifeos.core.clock import override_clock
from lifeos.habits.models import Habit,HabitOccurrence
from lifeos.habits.queries import schedule_for
from lifeos.habits.recurrence import is_due

pytestmark = pytest.mark.django_db

class FixedClock:
    def __init__(self,day): self.day=day
    def today(self): return self.day


def test_archive_restore_preserves_evidence_and_suspends_archived_dates(client):
    h = Habit.objects.create(name="Example",start_date=date(2024,1,1))
    o = HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,1),result="completed")
    with override_clock(FixedClock(date(2024,1,2))):
        assert client.get(f"/habits/{h.pk}/archive/").status_code == 200
        h.refresh_from_db(); assert not h.is_archived
        assert client.post(f"/habits/{h.pk}/archive/").status_code == 302
    h.refresh_from_db(); assert h.is_archived and h.archived_at
    assert client.get("/habits/archived/").status_code == 200
    with override_clock(FixedClock(date(2024,1,5))):
        assert client.post(f"/habits/{h.pk}/restore/").status_code == 302
    h.refresh_from_db(); assert not h.is_archived and h.archived_at is None
    assert HabitOccurrence.objects.filter(pk=o.pk).exists()
    assert not is_due(schedule_for(h),date(2024,1,4))
    assert is_due(schedule_for(h),date(2024,1,5))
