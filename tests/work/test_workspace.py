from datetime import date
from decimal import Decimal

import pytest
from django.urls import reverse

from lifeos.core.clock import override_clock
from lifeos.work.models import Shift
from tests.work.test_register import FixedClock

pytestmark = pytest.mark.django_db

VALID = {
    "work_date": "2026-09-26", "shift_type": "normal",
    "worked_hours": "8.00", "overtime_hours": "1.00",
    "hourly_rate": "20.00", "note": "synthetic edited note",
}


def desk_url(route, pk=None, month="2026-09"):
    return reverse(route, args=[pk] if pk is not None else None) + f"?workspace=1&month={month}"


@pytest.mark.parametrize("mode,route", [("new", "work:shift-create"), ("edit", "work:shift-edit"), ("delete", "work:shift-delete"), ("review", "work:shift-detail")])
def test_workspace_endpoints_keep_register_visible(client, mode, route):
    shift = make_shift(date(2026, 9, 25))
    response = client.get(desk_url(route, None if mode == "new" else shift.pk))
    assert response.status_code == 200
    assert response.context["inspector_mode"] == mode
    assert 'class="shift-table"' in response.content.decode()


@pytest.mark.parametrize("route", ["work:shift-create", "work:shift-edit"])
@pytest.mark.parametrize("day", ["0001-01-01", "9999-12-01"])
def test_workspace_boundary_dates_remain_reviewable(client, route, day):
    shift = make_shift(date(2026, 9, 25))
    response = client.post(desk_url(route, None if route == "work:shift-create" else shift.pk),
                           {**VALID, "work_date": day})
    saved = Shift.objects.order_by("pk").last() if route == "work:shift-create" else shift
    assert response.url == reverse("work:shift-detail", args=[saved.pk])
    assert client.get(response.url).status_code == 200


def test_workspace_create_returns_to_selected_record(client):
    response = client.post(desk_url("work:shift-create"), VALID)
    shift = Shift.objects.get()
    assert response.url == f"/work/?month=2026-09&shift={shift.pk}"


@pytest.mark.parametrize("day,month", [("2026-09-26", "2026-09"), ("2026-10-01", "2026-10")])
def test_workspace_edit_follows_saved_month(client, day, month):
    shift = make_shift(date(2026, 9, 25))
    response = client.post(desk_url("work:shift-edit", shift.pk), {**VALID, "work_date": day})
    assert response.url == f"/work/?month={month}&shift={shift.pk}"
    shift.refresh_from_db()
    assert shift.work_date.isoformat() == day


@pytest.mark.parametrize("route", ["work:shift-edit", "work:shift-delete"])
def test_stale_workspace_post_does_not_mutate(client, route):
    shift = make_shift(date(2026, 8, 25), note="original")
    response = client.post(desk_url(route, shift.pk), VALID)
    assert response.status_code == 409
    shift.refresh_from_db()
    assert shift.note == "original"
    assert shift.work_date == date(2026, 8, 25)


def test_stale_workspace_get_moves_to_actual_month(client):
    shift = make_shift(date(2026, 8, 25))
    response = client.get(desk_url("work:shift-edit", shift.pk))
    assert response.url == f"/work/shifts/{shift.pk}/edit/?workspace=1&month=2026-08"


def test_invalid_workspace_form_retains_persisted_snapshot(client):
    shift = make_shift(date(2026, 9, 25))
    response = client.post(desk_url("work:shift-edit", shift.pk),
        {**VALID, "worked_hours": "invalid", "hourly_rate": "99.00", "note": "<b>safe</b>"})
    assert response.status_code == 200
    assert response.context["salary"].gross == Decimal("170.00")
    assert response.context["shifts"][0].hourly_rate == Decimal("20.00")
    assert "&lt;b&gt;safe&lt;/b&gt;" in response.content.decode()
    assert response.context["form"].errors


def test_workspace_delete_returns_to_unselected_month(client):
    shift = make_shift(date(2026, 9, 25))
    response = client.post(desk_url("work:shift-delete", shift.pk))
    assert response.url == "/work/?month=2026-09"
    assert not Shift.objects.filter(pk=shift.pk).exists()


def test_detail_rejects_post(client):
    shift = make_shift(date(2026, 9, 25))
    assert client.post(reverse("work:shift-detail", args=[shift.pk])).status_code == 405


@pytest.mark.parametrize("route", ["work:shift-create", "work:shift-edit", "work:shift-delete"])
def test_uncertain_commit_advises_review(client, monkeypatch, route):
    from contextlib import contextmanager
    from django.db import DatabaseError
    shift = make_shift(date(2026, 9, 25))

    from django.db import transaction
    original_atomic = transaction.atomic

    @contextmanager
    def fail_after_body(*args, **kwargs):
        if args or kwargs:
            with original_atomic(*args, **kwargs):
                yield
        else:
            yield
            raise DatabaseError("private commit marker")

    monkeypatch.setattr("lifeos.work.views.transaction.atomic", fail_after_body)
    response = client.post(desk_url(route, None if route == "work:shift-create" else shift.pk), VALID)
    content = response.content.decode()
    assert "inspect the Work register before retrying" in content
    assert "private commit marker" not in content


def test_workspace_mutation_requires_csrf():
    from django.test import Client
    response = Client(enforce_csrf_checks=True).post(desk_url("work:shift-create"), VALID)
    assert response.status_code == 403
    assert Shift.objects.count() == 0


def test_workspace_table_is_keyboard_reachable_and_policy_disclosed(client):
    shift = make_shift(date(2026, 9, 25))
    response = client.get("/work/", {"month": "2026-09", "shift": shift.pk})
    content = response.content.decode()
    assert 'role="region" aria-labelledby="shift-list-heading" tabindex="0"' in content
    assert '<details class="salary-explanation">' in content
    assert '<summary>How this estimate works</summary>' in content
    assert 'href="#shift-list-heading"' in content
    assert 'href="/work/shifts/new/?workspace=1&amp;month=2026-09"' in content


def test_workspace_edit_table_links_return_to_register(client):
    shift = make_shift(date(2026, 9, 25))
    other = make_shift(date(2026, 9, 26))
    content = client.get(desk_url("work:shift-edit", shift.pk)).content.decode()
    assert f'href="/work/?month=2026-09&amp;shift={other.pk}#shift-inspector"' in content
    assert 'href="/work/?month=2026-08"' in content
    assert 'href="/work/?month=2026-10"' in content


def test_long_month_and_note_are_complete_and_escaped(client):
    shifts = [make_shift(date(2026, 9, (index % 30) + 1)) for index in range(90)]
    last = shifts[-1]
    last.note = "<script>synthetic</script>" + "long-note " * 300
    last.save()
    response = client.get("/work/", {"month": "2026-09", "shift": last.pk})
    content = response.content.decode()
    assert len(response.context["shifts"]) == 90
    assert all(f'id="shift-{shift.pk}"' in content for shift in shifts)
    assert "&lt;script&gt;synthetic&lt;/script&gt;" in content
    assert content.count("long-note ") == 300


def make_shift(day, note="synthetic workspace note"):
    return Shift.objects.create(
        work_date=day, shift_type="normal", worked_hours=Decimal("8.00"),
        overtime_hours=Decimal("1.00"), hourly_rate=Decimal("20.00"), note=note,
    )


def test_workspace_has_neutral_inspector(client):
    response = client.get(reverse("work:register"), {"month": "2026-09"})
    assert response.context["selected_shift"] is None
    assert "Select a shift" in response.content.decode()


def test_workspace_selected_record_is_month_scoped(client):
    shift = make_shift(date(2026, 8, 31), note="foreign-month-marker")
    response = client.get(reverse("work:register"),
                          {"month": "2026-09", "shift": str(shift.pk)})
    assert response.status_code == 200
    assert "foreign-month-marker" not in response.content.decode()
    assert response.context["selected_shift"] is None


@pytest.mark.parametrize("selection", ["bad", "-1", "9" * 5000, "", "01"], ids=["text", "negative", "huge", "empty", "leading-zero"])
def test_invalid_selection_is_safe(client, selection):
    response = client.get(reverse("work:register"),
                          {"month": "2026-09", "shift": selection})
    assert response.status_code == 200
    assert response.context["selected_shift"] is None


def test_selection_reviews_only_selected_note_and_reads_clock_once(client):
    make_shift(date(2026, 9, 24), note="unselected-private-note")
    selected = make_shift(date(2026, 9, 25), note="selected-synthetic-note")
    clock = FixedClock(date(2026, 9, 26))
    with override_clock(clock):
        response = client.get(reverse("work:register"),
                              {"month": "2026-09", "shift": str(selected.pk)})
    assert clock.calls == 1
    assert response.context["selected_shift"].pk == selected.pk
    content = response.content.decode()
    assert "selected-synthetic-note" in content
    assert "unselected-private-note" not in content
    assert f'id="shift-{selected.pk}"' in content


@pytest.mark.parametrize("raw_month", [None, "bad", "2026-9", "0001-01"])
def test_invalid_workspace_context_is_not_accepted(rf, raw_month):
    from lifeos.work.workspace import workspace_month
    params = {"workspace": "1"}
    if raw_month is not None:
        params["month"] = raw_month
    assert workspace_month(rf.get("/", params), today=date(2026, 9, 26)) is None


def test_workspace_internal_urls_and_valid_month(rf):
    from lifeos.work.workspace import register_url, workspace_month, workspace_url
    month = workspace_month(rf.get("/", {"workspace": "1", "month": "2026-09"}),
                            today=date(2026, 9, 26))
    assert month.value == "2026-09"
    assert register_url(month, 42) == "/work/?month=2026-09&shift=42"
    assert workspace_url("work:shift-edit", month, pk=42) == "/work/shifts/42/edit/?workspace=1&month=2026-09"
