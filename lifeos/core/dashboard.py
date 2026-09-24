import logging
from dataclasses import dataclass
from datetime import date
from typing import Literal

from lifeos.core.clock import Clock, get_clock

logger = logging.getLogger(__name__)

RegisterKey = Literal["work", "money", "habits"]
RegisterState = Literal["empty", "ready", "unavailable"]


class SummaryUnavailable(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class LabelledValue:
    label: str
    value: str


@dataclass(frozen=True, slots=True)
class RegisterSummary:
    key: RegisterKey
    title: str
    description: str
    href: str | None
    action_label: str | None
    action_href: str | None
    state: RegisterState
    state_label: str
    recovery_text: str | None = None
    values: tuple[LabelledValue, ...] = ()


@dataclass(frozen=True, slots=True)
class DashboardView:
    today: date
    registers: tuple[RegisterSummary, ...]


from lifeos.habits import summary as habits_summary
from lifeos.money import summary as money_summary
from lifeos.work import summary as work_summary


def _unavailable(key: RegisterKey) -> RegisterSummary:
    titles = {"work": "Work", "money": "Money", "habits": "Habits"}
    title = titles[key]
    return RegisterSummary(
        key=key,
        title=title,
        description=f"{title} summary is temporarily unavailable.",
        href=None,
        action_label=None,
        action_href=None,
        state="unavailable",
        state_label="Unavailable",
        recovery_text="Try again after checking the register.",
    )


def build_dashboard(*, clock: Clock | None = None) -> DashboardView:
    today = (clock or get_clock()).today()
    modules = (work_summary, money_summary, habits_summary)
    registers: list[RegisterSummary] = []
    for module in modules:
        try:
            registers.append(module.get_summary(today=today))
        except SummaryUnavailable as error:
            key = module.__name__.split(".")[-2]
            logger.warning("Dashboard summary unavailable for %s (%s)", key, type(error).__name__)
            registers.append(_unavailable(key))
    return DashboardView(today=today, registers=tuple(registers))
