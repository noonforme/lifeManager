from collections.abc import Iterable
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

ZERO = Decimal("0.00")
CENT = Decimal("0.01")
OVERTIME_MULTIPLIER = Decimal("1.5")
GPM_RATE = Decimal("0.20")
VSD_RATE = Decimal("0.1252")
PSD_RATE = Decimal("0.0698")


@dataclass(frozen=True, slots=True)
class SalaryInput:
    worked_hours: Decimal
    overtime_hours: Decimal
    hourly_rate: Decimal
    shift_type: str


@dataclass(frozen=True, slots=True)
class SalaryResult:
    shift_count: int
    total_worked_hours: Decimal
    total_normal_hours: Decimal
    total_overtime_hours: Decimal
    mean_hourly_rate: Decimal
    gross: Decimal
    gpm: Decimal
    vsd: Decimal
    psd: Decimal
    total_taxes: Decimal
    net: Decimal


def _display(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def calculate_salary(records: Iterable[SalaryInput]) -> SalaryResult:
    shifts = tuple(records)
    if not shifts:
        return SalaryResult(0, ZERO, ZERO, ZERO, ZERO, ZERO, ZERO, ZERO, ZERO, ZERO, ZERO)

    total_worked = sum((shift.worked_hours for shift in shifts), start=ZERO)
    total_overtime = sum((shift.overtime_hours for shift in shifts), start=ZERO)
    normal_hours = tuple(
        max(shift.worked_hours - shift.overtime_hours, ZERO)
        for shift in shifts
    )
    total_normal = sum(normal_hours, start=ZERO)
    exact_gross = sum(
        (
            normal * shift.hourly_rate
            + shift.overtime_hours * shift.hourly_rate * OVERTIME_MULTIPLIER
            for shift, normal in zip(shifts, normal_hours, strict=True)
        ),
        start=ZERO,
    )
    exact_mean_rate = sum(
        (shift.hourly_rate for shift in shifts),
        start=ZERO,
    ) / len(shifts)

    gross = _display(exact_gross)
    gpm = _display(exact_gross * GPM_RATE)
    vsd = _display(exact_gross * VSD_RATE)
    psd = _display(exact_gross * PSD_RATE)
    total_taxes = gpm + vsd + psd

    return SalaryResult(
        shift_count=len(shifts),
        total_worked_hours=_display(total_worked),
        total_normal_hours=_display(total_normal),
        total_overtime_hours=_display(total_overtime),
        mean_hourly_rate=_display(exact_mean_rate),
        gross=gross,
        gpm=gpm,
        vsd=vsd,
        psd=psd,
        total_taxes=_display(total_taxes),
        net=_display(gross - total_taxes),
    )
