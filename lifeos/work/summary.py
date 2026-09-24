from datetime import date

from django.db import DatabaseError
from django.urls import reverse

from lifeos.core.dashboard import LabelledValue, RegisterSummary, SummaryUnavailable

from .calculations import SalaryInput, calculate_salary
from .queries import CalendarMonth, nearest_shift, shifts_for_month

NEW_SHIFT_PATH = "/work/shifts/new/"


def _formatted_date(value: date) -> str:
    return f"{value.day} {value:%B %Y}"


def get_summary(*, today: date) -> RegisterSummary:
    month = CalendarMonth(today.year, today.month)
    try:
        shifts = tuple(shifts_for_month(month))
        nearest = nearest_shift(month=month, target=today) if shifts else None
    except DatabaseError as error:
        raise SummaryUnavailable("Work summary unavailable") from error

    href = reverse("work:register")
    action_href = f"{reverse('work:shift-create')}?date={today.isoformat()}"
    if not shifts:
        return RegisterSummary(
            key="work",
            title="Work",
            description="No shifts recorded this month.",
            href=href,
            action_label="New shift",
            action_href=action_href,
            state="empty",
            state_label="Empty",
            values=(),
        )

    salary = calculate_salary(
        SalaryInput(
            shift.worked_hours,
            shift.overtime_hours,
            shift.hourly_rate,
            shift.shift_type,
        )
        for shift in shifts
    )
    nearest_label = "Next shift" if nearest.work_date >= today else "Last shift"
    return RegisterSummary(
        key="work",
        title="Work",
        description=f"{salary.shift_count} shifts recorded this month.",
        href=href,
        action_label="New shift",
        action_href=action_href,
        state="ready",
        state_label="Ready",
        values=(
            LabelledValue("Shifts", str(salary.shift_count)),
            LabelledValue("Worked", f"{salary.total_worked_hours} h"),
            LabelledValue("Overtime", f"{salary.total_overtime_hours} h"),
            LabelledValue("Estimated net", str(salary.net)),
            LabelledValue(nearest_label, _formatted_date(nearest.work_date)),
        ),
    )
