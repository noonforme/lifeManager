from datetime import date

import pytest
from django.db import DatabaseError
from lifeos.habits.models import Habit,HabitOccurrence

pytestmark = pytest.mark.django_db


def test_occurrence_entry_duplicate_edit_and_confirmed_remove(client):
    h = Habit.objects.create(name="Example",start_date=date(2024,1,1))
    path = f"/habits/{h.pk}/occurrences/new/"
    assert client.get(path).status_code == 200
    data = {"occurrence_date":"2024-01-02","result":"completed","note":"  example  "}
    r = client.post(path,data)
    assert r.status_code == 302
    o = HabitOccurrence.objects.get()
    assert o.note == "example"
    assert client.get(r.url).status_code == 200
    assert client.post(path,data).status_code == 200
    assert HabitOccurrence.objects.count()==1
    assert client.post(r.url+"edit/",{**data,"result":"missed"}).status_code==302
    assert client.get(r.url+"delete/").status_code==200
    assert HabitOccurrence.objects.exists()
    assert client.post(r.url+"delete/").status_code==302
    assert not HabitOccurrence.objects.exists()


def test_explicit_one_off_is_atomic_and_cannot_override_pause(client,monkeypatch):
    from lifeos.habits.models import RecurrenceComponent,HabitPause
    h = Habit.objects.create(name="Example",start_date=date(2024,1,1),recurrence_kind="weekly")
    RecurrenceComponent.objects.create(habit=h,kind="weekday",value=0)
    path=f"/habits/{h.pk}/occurrences/new/"
    data={"occurrence_date":"2024-01-02","result":"completed"}
    assert client.post(path,data).status_code==200
    assert not HabitOccurrence.objects.exists()
    assert client.post(path,{**data,"one_off":"on"}).status_code==302
    assert h.exceptions.count()==1
    HabitPause.objects.create(habit=h,start_date=date(2024,1,3),end_date=date(2024,1,3))
    assert client.post(path,{**data,"occurrence_date":"2024-01-03","one_off":"on"}).status_code==200
    assert h.exceptions.count()==1
    original=HabitOccurrence.save
    def fail(self,*args,**kwargs):
        original(self,*args,**kwargs)
        raise DatabaseError("private marker")
    monkeypatch.setattr(HabitOccurrence,"save",fail)
    assert client.post(path,{**data,"occurrence_date":"2024-01-04","one_off":"on"}).status_code==200
    assert h.exceptions.count()==1
    assert HabitOccurrence.objects.count()==1
