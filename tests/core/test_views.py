import logging
from datetime import date
from unittest.mock import patch

import pytest
from django.contrib import messages
from django.urls import reverse

from lifeos.work.models import Shift
from decimal import Decimal
from django.db import DatabaseError
from django.test import Client, RequestFactory

from lifeos.core.clock import override_clock

pytestmark = pytest.mark.django_db


class FixedClock:
    def today(self) -> date:
        return date(2026, 9, 25)


def test_dashboard_renders_semantic_ordered_registers(client: Client) -> None:
    with override_clock(FixedClock()):
        response = client.get("/")
    assert response.status_code == 200
    html = response.content.decode()
    assert html.count("<main") == 1
    assert html.count("<h1") == 1
    assert "Daily register" in html
    assert 'href="#main-content"' in html
    assert '<nav aria-label="Primary"' in html
    assert '<time datetime="2026-09-25">' in html
    positions = [html.index(f'id="register-{key}"') for key in ("work", "money", "habits")]
    assert positions == sorted(positions)
    assert html.count('data-register-state="empty"') == 3
    assert html.count(">Empty<") == 3
    assert 'role="status"' in html
    assert 'role="alert"' in html
    assert 'href="/work/"' in html
    assert 'href="/work/shifts/new/?date=2026-09-25"' in html
    assert 'href="/money/"' in html
    assert 'href="/money/transactions/new/?date=2026-09-25"' in html
    assert "/habits/new/" not in html


def test_dashboard_renders_ready_work_values_generically(client: Client) -> None:
    Shift.objects.create(
        work_date=date(2026, 9, 25),
        shift_type="normal",
        worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"),
        hourly_rate=Decimal("20.00"),
    )
    with override_clock(FixedClock()):
        response = client.get(reverse("core:dashboard"))
    html = response.content.decode()
    assert 'data-register-state="ready"' in html
    assert 'class="register-values"' in html
    assert "Estimated net" in html
    assert "102.85" in html
    assert html.count('data-register-state="empty"') == 2


def test_messages_are_escaped_and_routed_by_level() -> None:
    from lifeos.core.views import dashboard

    request = RequestFactory().get("/")
    setattr(request, "session", {})
    from django.contrib.messages.storage.fallback import FallbackStorage
    setattr(request, "_messages", FallbackStorage(request))
    messages.success(request, "Saved <strong>now</strong>")
    messages.error(request, "Failed <script>alert(1)</script>")
    with override_clock(FixedClock()):
        response = dashboard(request)
    html = response.content.decode()
    assert "Saved &lt;strong&gt;now&lt;/strong&gt;" in html
    assert "Failed &lt;script&gt;alert(1)&lt;/script&gt;" in html
    assert "<script>alert(1)</script>" not in html


def test_readiness_success_is_minimal(client: Client) -> None:
    response = client.get("/ready/")
    assert response.status_code == 200
    assert response.headers["Content-Type"].startswith("text/plain")
    assert response.content == b"ready\n"


def test_readiness_database_failure_is_safe(
    client: Client,
    caplog: pytest.LogCaptureFixture,
) -> None:
    with (
        caplog.at_level(logging.WARNING, logger="lifeos.core.views"),
        patch(
            "lifeos.core.views.connection.cursor",
            side_effect=DatabaseError("SELECT secret FROM /private/path"),
        ),
    ):
        response = client.get("/ready/")
    assert response.status_code == 503
    assert response.headers["Content-Type"].startswith("text/plain")
    assert response.content == b"unavailable\n"
    assert "SELECT secret" not in caplog.text
    assert "/private/path" not in caplog.text
    assert "DatabaseError" in caplog.text


def test_unexpected_host_is_rejected() -> None:
    response = Client().get("/", HTTP_HOST="evil.example")
    assert response.status_code == 400
