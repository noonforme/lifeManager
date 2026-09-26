from datetime import date
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

pytestmark = pytest.mark.django_db


@pytest.mark.parametrize("kind,result,value", [("check","completed",None),("chore","missed",None),("abstinence","successful",None),("abstinence","lapse",None),("quantity","",Decimal("0")),("quantity","excused",None)])
def test_type_appropriate_evidence_and_unique_date(kind,result,value):
    from lifeos.habits.models import Habit,HabitOccurrence
    h = Habit.objects.create(name="Example",habit_type=kind,start_date=date(2024,1,1), **({"unit":"steps","target_rule":"at_least","lower_target":Decimal("1")} if kind=="quantity" else {}))
    o = HabitOccurrence(habit=h,occurrence_date=date(2024,1,1),result=result,value=value,note="  note  ")
    o.full_clean(); o.save()
    assert o.note == "note"
    with pytest.raises(IntegrityError), transaction.atomic():
        HabitOccurrence.objects.create(habit=h,occurrence_date=o.occurrence_date,result=result,value=value)
    h.habit_type = "chore" if kind != "chore" else "check"
    with pytest.raises(ValidationError):
        h.full_clean()


@pytest.mark.parametrize("result,value,reason", [("unknown",None,""),("successful",None,""),("completed",Decimal("1"),""),("completed",None,"reason"),("excused",Decimal("1"),"")])
def test_invalid_evidence_is_rejected(result,value,reason):
    from lifeos.habits.models import Habit,HabitOccurrence
    h = Habit.objects.create(name="Example",start_date=date(2024,1,1))
    with pytest.raises(ValidationError):
        HabitOccurrence(habit=h,occurrence_date=date(2024,1,1),result=result,value=value,excuse_reason=reason).full_clean()
