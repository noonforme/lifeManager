from datetime import date

import pytest
from django.db import DatabaseError
from django.test import Client

from lifeos.habits.models import Habit

pytestmark = pytest.mark.django_db
VALID = {"name":"  Reading  ","habit_type":"check","start_date":"2024-01-01","recurrence_kind":"daily","interval_n":"1","interval_unit":"days"}


def test_create_review_edit_and_safe_form_errors(client):
    assert client.get("/habits/new/").status_code == 200
    response = client.post("/habits/new/",VALID)
    h = Habit.objects.get()
    assert response.status_code == 302
    assert response.url == f"/habits/{h.pk}/"
    assert h.name == "Reading"
    assert client.get(response.url).status_code == 200
    response = client.post(f"/habits/{h.pk}/edit/",{**VALID,"name":"<script>test</script>"})
    assert response.status_code == 302
    assert "&lt;script&gt;test&lt;/script&gt;" in client.get(response.url).content.decode()
    response = client.post("/habits/new/",{**VALID,"name":"","start_date":"bad"})
    assert response.status_code == 200
    assert 'aria-invalid="true"' in response.content.decode()
    assert 'error-summary' in response.content.decode()


def test_routes_methods_and_csrf(client):
    assert Client(enforce_csrf_checks=True).post("/habits/new/",VALID).status_code == 403
    assert client.put("/habits/new/").status_code == 405
    assert client.get("/habits/999/").status_code == 404


def test_configuration_save_failure_rolls_back_and_is_private(client, monkeypatch, caplog):
    from lifeos.habits.forms import HabitConfigurationForm
    def fail(self):
        self.instance.save()
        raise DatabaseError("private marker")
    monkeypatch.setattr(HabitConfigurationForm,"save",fail)
    response = client.post("/habits/new/",VALID)
    assert response.status_code == 200
    assert not Habit.objects.exists()
    assert "could not be saved" in response.content.decode()
    assert "uncertain" not in response.content.decode()
    assert "private marker" not in caplog.text


def test_weekly_configuration_and_schedule_edit_retains_history(client):
    from lifeos.habits.models import HabitOccurrence
    response = client.post("/habits/new/",{**VALID,"recurrence_kind":"weekly","weekdays":["0","4"]})
    assert response.status_code == 302
    h = Habit.objects.get()
    assert h.components.count() == 2
    o = HabitOccurrence.objects.create(habit=h,occurrence_date=date(2024,1,1),result="completed")
    response = client.post(f"/habits/{h.pk}/edit/",{**VALID,"recurrence_kind":"weekly","weekdays":["4"]})
    assert response.status_code == 302
    assert HabitOccurrence.objects.filter(pk=o.pk).exists()
    assert "Retained historical record" in client.get(response.url).content.decode()
