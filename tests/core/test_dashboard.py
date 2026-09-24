import logging
from datetime import date

import pytest

from lifeos.core.dashboard import SummaryUnavailable, build_dashboard


class FixedClock:
    def __init__(self, value: date) -> None:
        self.value = value
        self.calls = 0

    def today(self) -> date:
        self.calls += 1
        return self.value


def test_dashboard_reads_date_once_and_orders_registers() -> None:
    clock = FixedClock(date(2026, 9, 25))
    dashboard = build_dashboard(clock=clock)
    assert clock.calls == 1
    assert dashboard.today == date(2026, 9, 25)
    assert [register.key for register in dashboard.registers] == ["work", "money", "habits"]
    assert [register.state_label for register in dashboard.registers] == ["Empty", "Empty", "Empty"]
    assert dashboard.registers[0].description == "No shifts recorded this month."
    assert dashboard.registers[1].description == "No transactions recorded this month."
    assert dashboard.registers[2].description == "No habits yet."


def test_expected_domain_failure_is_isolated(monkeypatch, caplog: pytest.LogCaptureFixture) -> None:
    def unavailable(*, today: date):
        raise SummaryUnavailable("private record text")

    monkeypatch.setattr("lifeos.core.dashboard.money_summary.get_summary", unavailable)
    with caplog.at_level(logging.WARNING, logger="lifeos.core.dashboard"):
        dashboard = build_dashboard(clock=FixedClock(date(2026, 9, 25)))
    assert [register.state for register in dashboard.registers] == ["empty", "unavailable", "empty"]
    assert dashboard.registers[1].description == "Money summary is temporarily unavailable."
    assert "private record text" not in repr(dashboard.registers[1])
    assert "private record text" not in caplog.text
    assert "SummaryUnavailable" in caplog.text


def test_unexpected_programming_error_propagates(monkeypatch) -> None:
    def broken(*, today: date):
        raise AssertionError("programming error")

    monkeypatch.setattr("lifeos.core.dashboard.work_summary.get_summary", broken)
    with pytest.raises(AssertionError, match="programming error"):
        build_dashboard(clock=FixedClock(date(2026, 9, 25)))
