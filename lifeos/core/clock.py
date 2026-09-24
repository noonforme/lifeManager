from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar
from typing import Protocol
from datetime import date

from django.utils import timezone


class Clock(Protocol):
    def today(self) -> date: ...


class SystemClock:
    def today(self) -> date:
        return timezone.localdate(timezone.now())


_override: ContextVar[Clock | None] = ContextVar("lifeos_clock", default=None)
_system_clock = SystemClock()


def get_clock() -> Clock:
    return _override.get() or _system_clock


@contextmanager
def override_clock(clock: Clock) -> Iterator[None]:
    token = _override.set(clock)
    try:
        yield
    finally:
        _override.reset(token)
