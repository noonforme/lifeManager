from datetime import date,timedelta

import pytest
from django.core.exceptions import ValidationError
from lifeos.habits.models import Habit,HabitOccurrence
from .test_habit_workflows import VALID

pytestmark=pytest.mark.django_db


def test_duplicate_entry_links_to_explicit_edit(client):
    h=Habit.objects.create(name="Example",start_date=date(2024,1,1))
    o=HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,2),result="completed")
    r=client.post(f"/habits/{h.pk}/occurrences/new/",{"occurrence_date":"2024-01-02","result":"missed"})
    assert r.status_code==200
    assert f'href="/habits/{h.pk}/occurrences/{o.pk}/edit/"' in r.content.decode()
    o.refresh_from_db(); assert o.result=="completed"


def test_detail_history_is_paginated_and_register_has_no_history_payload(client):
    from lifeos.habits.queries import register_snapshot
    h=Habit.objects.create(name="Example",start_date=date(2024,1,1))
    for n in range(35):
        HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,1)+timedelta(days=n),result="completed",note=f"history-marker-{n}")
    r=client.get(f"/habits/{h.pk}/")
    assert len(r.context['row'].history)==20
    assert 'Next history page' in r.content.decode()
    r=client.get(f"/habits/{h.pk}/",{'page':2})
    assert len(r.context['row'].history)==15
    snap=register_snapshot(selected_date=date(2024,2,4),today=date(2024,2,4))
    assert snap.due[0].history==()
    assert snap.due[0].longest==35


def test_interval_missing_anchor_and_invalid_result_fail_model_validation():
    h=Habit(name="Example",start_date=date(2024,1,1),recurrence_kind="interval")
    with pytest.raises(ValidationError): h.full_clean()


def test_direct_save_rejects_type_incompatible_evidence():
    h=Habit.objects.create(name="Example",start_date=date(2024,1,1))
    with pytest.raises(ValidationError):
        HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,1),result="successful")


def test_direct_component_save_rejects_irrelevant_kind():
    from lifeos.habits.models import RecurrenceComponent
    h=Habit.objects.create(name="Example",start_date=date(2024,1,1))
    with pytest.raises(ValidationError):
        RecurrenceComponent.objects.create(habit=h,kind="weekday",value=1)


def test_incomplete_persisted_schedule_has_private_recovery(client):
    h=Habit.objects.create(name="private-marker",start_date=date(2024,1,1),recurrence_kind="weekly")
    response=client.get(f'/habits/{h.pk}/')
    assert response.status_code==503
    assert 'private-marker' not in response.content.decode()


def test_http_lengths_are_validated_after_trimming(client):
    r=client.post('/habits/new/',{**VALID,'name':'  '+'x'*120+'  ','description':'  '+'x'*500+'  ','reminder_text':'  '+'x'*160+'  '})
    assert r.status_code==302
