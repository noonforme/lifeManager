from datetime import date

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

pytestmark = pytest.mark.django_db


def test_schedule_components_are_relational_and_unique():
    from lifeos.habits.models import Habit, RecurrenceComponent, ScheduleException, HabitPause
    h = Habit.objects.create(name="Example", start_date=date(2024,1,1), recurrence_kind="weekly")
    RecurrenceComponent.objects.create(habit=h, kind="weekday", value=0)
    with pytest.raises(IntegrityError), transaction.atomic():
        RecurrenceComponent.objects.create(habit=h,kind="weekday",value=0)
    e = ScheduleException(habit=h,day=date(2024,1,2),kind="addition")
    e.full_clean(); e.save()
    with pytest.raises(IntegrityError), transaction.atomic():
        ScheduleException.objects.create(habit=h,day=e.day,kind="exclusion")
    with pytest.raises(ValidationError):
        HabitPause(habit=h,start_date=date(2024,1,3),end_date=date(2024,1,2)).full_clean()
