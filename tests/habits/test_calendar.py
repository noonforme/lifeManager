from datetime import date
import pytest
from lifeos.habits.models import Habit

pytestmark=pytest.mark.django_db


def test_projection_is_finite_immutable_and_read_only():
    from lifeos.habits.calendar import project_events
    Habit.objects.create(name="Example",start_date=date(2024,1,1))
    events=project_events(start=date(2024,1,1),end=date(2024,1,2),today=date(2024,1,1))
    assert len(events)==2
    assert events[0].domain=="habits" and events[1].state=="Pending"
    with pytest.raises(AttributeError): events[0].title="Changed"
    with pytest.raises(ValueError): project_events(start=date(2024,1,1),end=date(2025,1,1),today=date(2024,1,1))
    assert Habit.objects.count()==1
