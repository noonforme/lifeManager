from datetime import date, datetime, timezone as datetime_timezone

from django.test import override_settings
from django.utils import timezone

from lifeos.core.clock import SystemClock, get_clock, override_clock


class FixedClock:
    def __init__(self, value: date) -> None:
        self.value = value
        self.calls = 0

    def today(self) -> date:
        self.calls += 1
        return self.value


def test_system_clock_uses_configured_local_timezone(monkeypatch) -> None:
    instant = datetime(2026, 1, 1, 22, 30, tzinfo=datetime_timezone.utc)
    monkeypatch.setattr(timezone, "now", lambda: instant)
    with override_settings(TIME_ZONE="Europe/Vilnius"):
        assert SystemClock().today() == date(2026, 1, 2)


def test_clock_override_is_scoped_and_reset() -> None:
    original = get_clock()
    fixed = FixedClock(date(2026, 9, 25))
    with override_clock(fixed):
        assert get_clock() is fixed
    assert get_clock() is original
