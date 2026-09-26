from datetime import date
import pytest
from lifeos.habits.models import Habit,HabitOccurrence

pytestmark=pytest.mark.django_db


def test_habit_review_exposes_lifecycle_entry_and_history_actions(client):
    h=Habit.objects.create(name="Example",start_date=date(2024,1,1))
    o=HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,2),result="completed")
    text=client.get(f"/habits/{h.pk}/").content.decode()
    assert f'href="/habits/{h.pk}/archive/"' in text
    assert f'href="/habits/{h.pk}/occurrences/new/"' in text
    assert f'href="/habits/{h.pk}/occurrences/{o.pk}/"' in text


def test_occurrence_create_prefills_register_selected_date(client):
    h=Habit.objects.create(name="Example",start_date=date(2024,1,1))
    r=client.get(f"/habits/{h.pk}/occurrences/new/",{"date":"2024-01-02"})
    assert r.context['form'].initial['occurrence_date']==date(2024,1,2)
