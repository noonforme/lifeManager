from datetime import date

from lifeos.core.dashboard import RegisterSummary

NEW_SHIFT_PATH = "/work/shifts/new/"


def get_summary(*, today: date) -> RegisterSummary:
    return RegisterSummary(
        key="work",
        title="Work",
        description="No shifts recorded this month.",
        href=None,
        action_label=None,
        action_href=None,
        state="empty",
        state_label="Empty",
    )
