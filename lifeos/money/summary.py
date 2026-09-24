from datetime import date

from lifeos.core.dashboard import RegisterSummary

NEW_TRANSACTION_PATH = "/money/transactions/new/"


def get_summary(*, today: date) -> RegisterSummary:
    return RegisterSummary(
        key="money",
        title="Money",
        description="No transactions recorded this month.",
        href=None,
        action_label=None,
        action_href=None,
        state="empty",
        state_label="Empty",
    )
