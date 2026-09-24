from datetime import date

from lifeos.core.dashboard import RegisterSummary

NEW_HABIT_PATH = "/habits/new/"


def get_summary(*, today: date) -> RegisterSummary:
    return RegisterSummary(
        key="habits",
        title="Habits",
        description="No habits yet.",
        href=None,
        action_label=None,
        action_href=None,
        state="empty",
        state_label="Empty",
    )
