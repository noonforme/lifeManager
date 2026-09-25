from datetime import date

from django.db import DatabaseError
from django.urls import reverse

from lifeos.core.dashboard import LabelledValue, RegisterSummary, SummaryUnavailable

from .calculations import TransactionAmountInput, calculate_monthly_movement, format_euros
from .queries import CalendarMonth, transaction_snapshot_for_month


def get_summary(*, today: date) -> RegisterSummary:
    month = CalendarMonth(today.year, today.month)
    try:
        items = transaction_snapshot_for_month(month)
    except DatabaseError as error:
        raise SummaryUnavailable("Money summary unavailable") from error

    href = reverse("money:register")
    action_href = f"{reverse('money:transaction-create')}?date={today.isoformat()}"
    if not items:
        return RegisterSummary(
            key="money",
            title="Money",
            description="No transactions recorded this month.",
            href=href,
            action_label="New transaction",
            action_href=action_href,
            state="empty",
            state_label="Empty",
            values=(),
        )

    movement = calculate_monthly_movement(
        TransactionAmountInput(item.direction, item.amount) for item in items
    )
    return RegisterSummary(
        key="money",
        title="Money",
        description=f"{movement.count} transactions recorded this month.",
        href=href,
        action_label="New transaction",
        action_href=action_href,
        state="ready",
        state_label="Ready",
        values=(
            LabelledValue("Transactions", str(movement.count)),
            LabelledValue("Inflow", format_euros(movement.inflow)),
            LabelledValue("Outflow", format_euros(movement.outflow)),
            LabelledValue("Net movement", format_euros(movement.net_movement)),
        ),
    )
