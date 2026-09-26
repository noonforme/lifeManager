import json
from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest


@pytest.mark.parametrize("case", json.loads((Path(__file__).resolve().parents[2]/"docs/foundation/fixtures/habit-momentum-cases.json").read_text())["cases"])
def test_canonical_momentum(case):
    from lifeos.habits.calculations import calculate_momentum
    result = calculate_momentum(date.fromisoformat(x) for x in case["completion_dates"])
    assert result.value == Decimal(case["expected_momentum"])
    assert result.successful_dates == tuple(date.fromisoformat(x) for x in case["expected_unique_dates"])


@pytest.mark.parametrize("rule,lower,upper,value,want", [("at_least","2",None,"2",True),("at_most",None,"2","3",False),("range","1","2","1",True),("range","1","2","2",True)])
def test_quantity_target(rule,lower,upper,value,want):
    from lifeos.habits.calculations import QuantityTarget,target_met
    assert target_met(Decimal(value),QuantityTarget(rule,Decimal(lower) if lower else None,Decimal(upper) if upper else None)) is want


def test_streak_excused_neutral_unknown_breaks_future_and_non_due_ignored():
    from lifeos.habits.calculations import OutcomeInput,calculate_streak
    from lifeos.habits.recurrence import ScheduleInput
    s = ScheduleInput(start_date=date(2024,1,1))
    evidence = tuple(OutcomeInput(date(2024,1,d),state) for d,state in [(1,"success"),(2,"excused"),(3,"success"),(5,"success"),(7,"success")])
    result = calculate_streak(s,evidence,today=date(2024,1,6))
    assert result.current == 1
    assert result.longest == 2
    assert result.has_overdue_unknown
    with pytest.raises(AttributeError):
        result.current = 4


def test_streak_today_missing_does_not_break_and_history_not_truncated():
    from lifeos.habits.calculations import OutcomeInput,calculate_streak
    from lifeos.habits.recurrence import ScheduleInput
    s = ScheduleInput(start_date=date(1900,1,1),kind="monthly_dates",month_days=(1,))
    evidence = (OutcomeInput(date(2024,1,1),"success"),OutcomeInput(date(2024,2,1),"success"))
    result = calculate_streak(s,evidence,today=date(2024,3,1))
    assert result.current == 2
    assert result.longest == 2
    assert result.has_overdue_unknown
