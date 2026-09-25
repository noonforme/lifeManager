from dataclasses import FrozenInstanceError
from decimal import Decimal

import pytest

from lifeos.money.calculations import (
    MonthlyMovement,
    TransactionAmountInput,
    calculate_monthly_movement,
    format_euros,
)


def row(direction, amount):
    return TransactionAmountInput(direction, Decimal(amount))


def test_empty_month_is_exact_zero():
    result = calculate_monthly_movement(())
    assert result == MonthlyMovement(
        count=0,
        inflow=Decimal("0.00"),
        outflow=Decimal("0.00"),
        net_movement=Decimal("0.00"),
    )


@pytest.mark.parametrize(
    ("records", "expected"),
    [
        ((row("income", "10.005"),), (1, "10.01", "0.00", "10.01")),
        ((row("expense", "2.005"),), (1, "0.00", "2.01", "-2.01")),
        (
            (row("income", "10.00"), row("expense", "4.25")),
            (2, "10.00", "4.25", "5.75"),
        ),
        (
            (row("income", "4.25"), row("expense", "4.25")),
            (2, "4.25", "4.25", "0.00"),
        ),
    ],
)
def test_named_outputs_are_independently_quantized(records, expected):
    result = calculate_monthly_movement(records)
    assert (
        result.count,
        str(result.inflow),
        str(result.outflow),
        str(result.net_movement),
    ) == expected


def test_inputs_are_materialized_without_mutation_and_result_is_frozen():
    records = [row("income", "0.10"), row("income", "0.20")]
    result = calculate_monthly_movement(records)
    assert records == [row("income", "0.10"), row("income", "0.20")]
    assert result.inflow == Decimal("0.30")
    with pytest.raises(FrozenInstanceError):
        result.count = 3


@pytest.mark.parametrize(
    ("value", "formatted"),
    [
        (Decimal("12"), "€12.00"),
        (Decimal("0"), "€0.00"),
        (Decimal("-12.345"), "-€12.35"),
    ],
)
def test_format_euros_has_symbol_two_places_and_negative_sign(value, formatted):
    assert format_euros(value) == formatted
