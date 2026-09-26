from contextlib import contextmanager
from datetime import date

import pytest
from django.db import DatabaseError
from lifeos.habits.models import Habit,HabitOccurrence
from .test_habit_workflows import VALID

pytestmark=pytest.mark.django_db


@pytest.mark.parametrize("path", ["/habits/","/habits/1/","/habits/1/edit/","/habits/archived/","/habits/1/archive/","/habits/1/restore/","/habits/1/occurrences/new/","/habits/1/occurrences/1/","/habits/1/occurrences/1/edit/","/habits/1/occurrences/1/delete/"])
def test_database_lookup_and_materialization_errors_are_private_503(client,monkeypatch,caplog,path):
    def fail(): raise DatabaseError("private-content /private/path")
    monkeypatch.setattr("lifeos.habits.views.loaded_habits",fail)
    monkeypatch.setattr("lifeos.habits.queries.loaded_habits",fail)
    r=client.get(path)
    assert r.status_code==503
    assert "private-content" not in r.content.decode()+caplog.text
    assert "DatabaseError" in caplog.text


def test_atomic_exit_failure_has_uncertain_guidance_no_success(client,monkeypatch):
    original = __import__("django.db.transaction",fromlist=["atomic"]).atomic
    @contextmanager
    def fail_exit(*args,**kwargs):
        if args or kwargs:
            with original(*args,**kwargs):
                yield
            return
        with original():
            yield
            raise DatabaseError("private")
    monkeypatch.setattr("lifeos.habits.views.transaction.atomic",fail_exit)
    r=client.post("/habits/new/",VALID)
    assert "uncertain" in r.content.decode()
    assert "Habit created." not in r.content.decode()


def test_unexpected_query_error_propagates(client,monkeypatch):
    def fail(): raise RuntimeError("programming defect")
    monkeypatch.setattr("lifeos.habits.queries.loaded_habits",fail)
    with pytest.raises(RuntimeError): client.get("/habits/")


@pytest.mark.parametrize("kind,data", [("abstinence",{"result":"lapse"}),("quantity",{"result":"","value":"0.00"})])
def test_type_specific_occurrence_forms(client,kind,data):
    from decimal import Decimal
    h=Habit.objects.create(name="Example",habit_type=kind,start_date=date(2024,1,1),**({"unit":"steps","target_rule":"at_least","lower_target":Decimal("1")} if kind=="quantity" else {}))
    r=client.post(f"/habits/{h.pk}/occurrences/new/",{"occurrence_date":"2024-01-01",**data})
    assert r.status_code==302
    assert HabitOccurrence.objects.count()==1
