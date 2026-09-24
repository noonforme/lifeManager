import json
from dataclasses import FrozenInstanceError
from decimal import Decimal
from pathlib import Path

import pytest

from lifeos.work.calculations import SalaryInput, SalaryResult, calculate_salary

FIXTURES = (
    Path(__file__).parents[2]
    / "docs"
    / "foundation"
    / "fixtures"
    / "salary-cases.json"
)


def salary_cases():
    return json.loads(FIXTURES.read_text())["cases"]


@pytest.mark.parametrize("case", salary_cases(), ids=lambda case: case["id"])
def test_salary_cases_match_portable_characterization(case):
    records = tuple(
        SalaryInput(
            worked_hours=Decimal(shift["hours"]),
            overtime_hours=Decimal(shift["overtime_hours"]),
            hourly_rate=Decimal(shift["hourly_rate"]),
            shift_type=shift["type"],
        )
        for shift in case["shifts"]
    )

    result = calculate_salary(records)

    expected_fields = {
        "expected_normal_hours": "total_normal_hours",
        "expected_mean_rate": "mean_hourly_rate",
        "expected_gross": "gross",
        "expected_gpm": "gpm",
        "expected_vsd": "vsd",
        "expected_psd": "psd",
        "expected_total_taxes": "total_taxes",
        "expected_net": "net",
    }
    for expected_name, result_name in expected_fields.items():
        assert getattr(result, result_name) == Decimal(case[expected_name])
    assert result.shift_count == len(records)
    assert result.total_worked_hours == sum(
        (record.worked_hours for record in records),
        start=Decimal("0.00"),
    )
    assert result.total_overtime_hours == sum(
        (record.overtime_hours for record in records),
        start=Decimal("0.00"),
    )


def test_empty_salary_input_returns_zero_result():
    zero = Decimal("0.00")
    assert calculate_salary(()) == SalaryResult(
        0, zero, zero, zero, zero, zero, zero, zero, zero, zero, zero,
    )


def test_overtime_above_worked_never_makes_normal_negative():
    result = calculate_salary((
        SalaryInput(
            Decimal("1.00"),
            Decimal("2.00"),
            Decimal("10.00"),
            "night",
        ),
    ))
    assert result.total_normal_hours == Decimal("0.00")
    assert result.gross == Decimal("30.00")


def test_calculation_does_not_mutate_input_sequence():
    records = [
        SalaryInput(
            Decimal("8.00"),
            Decimal("1.00"),
            Decimal("20.00"),
            "normal",
        )
    ]
    before = records.copy()
    calculate_salary(records)
    assert records == before


def test_salary_values_are_decimal_and_result_is_frozen():
    result = calculate_salary((
        SalaryInput(
            Decimal("8.00"),
            Decimal("1.00"),
            Decimal("20.00"),
            "holiday",
        ),
    ))
    for field in result.__dataclass_fields__:
        if field != "shift_count":
            assert isinstance(getattr(result, field), Decimal)
    with pytest.raises(FrozenInstanceError):
        result.net = Decimal("0.00")
