from collections.abc import Iterable
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

ZERO = Decimal("0.00")
CENT = Decimal("0.01")


@dataclass(frozen=True, slots=True)
class TransactionAmountInput:
    direction: str
    amount: Decimal


@dataclass(frozen=True, slots=True)
class MonthlyMovement:
    count: int
    inflow: Decimal
    outflow: Decimal
    net_movement: Decimal


def _display(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def calculate_monthly_movement(
    records: Iterable[TransactionAmountInput],
) -> MonthlyMovement:
    snapshot = tuple(records)
    exact_inflow = sum(
        (record.amount for record in snapshot if record.direction == "income"),
        start=ZERO,
    )
    exact_outflow = sum(
        (record.amount for record in snapshot if record.direction == "expense"),
        start=ZERO,
    )
    return MonthlyMovement(
        count=len(snapshot),
        inflow=_display(exact_inflow),
        outflow=_display(exact_outflow),
        net_movement=_display(exact_inflow - exact_outflow),
    )


def format_euros(value: Decimal) -> str:
    displayed = _display(value)
    if displayed < ZERO:
        return f"-€{abs(displayed):.2f}"
    return f"€{displayed:.2f}"
