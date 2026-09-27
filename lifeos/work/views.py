import logging
from datetime import date

from django.contrib import messages
from django.db import DatabaseError, transaction
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_GET, require_http_methods

from lifeos.core.clock import get_clock

from .calculations import SalaryInput, calculate_salary
from .forms import ShiftForm
from .models import Shift
from .queries import CalendarMonth, select_month, shifts_for_month
from .workspace import register_url, selected_shift, workspace_month, workspace_url

logger = logging.getLogger(__name__)


def _prefill_date(raw_value: str | None) -> date | None:
    if raw_value is None:
        return None
    try:
        value = date.fromisoformat(raw_value)
    except ValueError:
        return None
    return value if value.isoformat() == raw_value else None


def _log_database_failure(operation: str, error: DatabaseError) -> None:
    logger.warning("Work %s failed (%s)", operation, type(error).__name__)


def _unavailable_response(request: HttpRequest) -> HttpResponse:
    return render(request, "work/register_unavailable.html", status=503)


def _record_month(shift: Shift) -> CalendarMonth:
    return CalendarMonth(shift.work_date.year, shift.work_date.month)


def _saved_redirect(shift: Shift, *, workspace: bool) -> HttpResponse:
    # Boundary years remain valid records but have no navigable monthly workspace.
    if workspace and 2 <= shift.work_date.year <= 9998:
        return redirect(register_url(_record_month(shift), shift.pk))
    return redirect("work:shift-detail", pk=shift.pk)


def _render_workspace(request, month, *, mode="neutral", shift_id=None, extra=None, month_error=None):
    try:
        shifts = tuple(shifts_for_month(month))
    except DatabaseError as error:
        _log_database_failure("register query", error)
        return _unavailable_response(request)
    selected = selected_shift(shifts, str(shift_id) if shift_id is not None else request.GET.get("shift"))
    salary = calculate_salary(
        SalaryInput(item.worked_hours, item.overtime_hours, item.hourly_rate, item.shift_type)
        for item in shifts
    )
    context = {
        "month": month, "month_error": month_error,
        "previous_month": month.previous(), "next_month": month.next(),
        "shifts": shifts, "salary": salary, "selected_shift": selected,
        "selection_unavailable": "shift" in request.GET and selected is None,
        "inspector_mode": "review" if mode == "neutral" and selected else mode,
        "new_shift_url": workspace_url("work:shift-create", month),
        "register_url": register_url(month),
        "cancel_url": register_url(month, selected.pk if selected else None),
        "edit_shift_url": workspace_url("work:shift-edit", month, pk=selected.pk) if selected else None,
        "delete_shift_url": workspace_url("work:shift-delete", month, pk=selected.pk) if selected else None,
    }
    context.update(extra or {})
    return render(request, "work/register.html", context)


def _context_conflict(request, month, shift, route):
    actual = _record_month(shift)
    if month is None or month == actual:
        return None
    if request.method == "GET":
        return redirect(workspace_url(route, actual, pk=shift.pk))
    return render(request, "work/workspace_conflict.html", {
        "review_url": register_url(actual, shift.pk),
    }, status=409)


def _save_form(request, form, operation):
    completed = False
    try:
        if not form.is_valid():
            return None
        with transaction.atomic():
            shift = form.save()
            completed = True
        return shift
    except DatabaseError as error:
        _log_database_failure(operation, error)
        form.add_error(None, "The shift could not be saved. Please try again.")
        if completed:
            form.add_error(None, "The commit outcome is uncertain; inspect the Work register before retrying.")
        return None


@require_http_methods(["GET", "POST"])
def shift_create(request: HttpRequest) -> HttpResponse:
    month = workspace_month(request, today=get_clock().today())
    initial = {}
    if prefill := _prefill_date(request.GET.get("date")):
        initial["work_date"] = prefill
    form = ShiftForm(request.POST if request.method == "POST" else None, initial=initial)
    if request.method == "POST":
        shift = _save_form(request, form, "shift create")
        if shift is not None:
            messages.success(request, "Shift created.")
            return _saved_redirect(shift, workspace=month is not None)
    if month:
        return _render_workspace(request, month, mode="new", extra={
            "form": form, "form_action": workspace_url("work:shift-create", month),
            "page_title": "New shift", "submit_label": "Create shift",
        })
    return render(request, "work/shift_form.html", {"form": form})


@require_GET
def shift_detail(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        shift = get_object_or_404(Shift, pk=pk)
    except DatabaseError as error:
        _log_database_failure("shift detail lookup", error)
        return _unavailable_response(request)
    month = workspace_month(request, today=get_clock().today())
    if conflict := _context_conflict(request, month, shift, "work:shift-detail"):
        return conflict
    if month:
        return _render_workspace(request, month, mode="review", shift_id=pk)
    return render(request, "work/shift_detail.html", {"shift": shift})


@require_http_methods(["GET", "POST"])
def shift_edit(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        shift = get_object_or_404(Shift, pk=pk)
    except DatabaseError as error:
        _log_database_failure("shift edit lookup", error)
        return _unavailable_response(request)
    month = workspace_month(request, today=get_clock().today())
    if conflict := _context_conflict(request, month, shift, "work:shift-edit"):
        return conflict
    original_month = _record_month(shift)
    form = ShiftForm(request.POST if request.method == "POST" else None, instance=shift)
    if request.method == "POST":
        saved = _save_form(request, form, "shift edit")
        if saved is not None:
            moved = month and _record_month(saved) != original_month
            messages.success(request, f"Shift updated. Moved to {_record_month(saved).label}." if moved else "Shift updated.")
            return _saved_redirect(saved, workspace=month is not None)
    context = {"form": form, "page_title": "Edit shift", "submit_label": "Save changes"}
    if month:
        context["form_action"] = workspace_url("work:shift-edit", month, pk=pk)
        return _render_workspace(request, month, mode="edit", shift_id=pk, extra=context)
    return render(request, "work/shift_form.html", context)


@require_GET
def register(request: HttpRequest) -> HttpResponse:
    selection = select_month(request.GET.get("month"), today=get_clock().today())
    return _render_workspace(request, selection.month, month_error=selection.error)


@require_http_methods(["GET", "POST"])
def shift_delete(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        shift = get_object_or_404(Shift, pk=pk)
    except DatabaseError as error:
        _log_database_failure("shift delete lookup", error)
        return _unavailable_response(request)
    month = workspace_month(request, today=get_clock().today())
    if conflict := _context_conflict(request, month, shift, "work:shift-delete"):
        return conflict
    actual = _record_month(shift)
    context = {"shift": shift}
    if request.method == "POST":
        completed = False
        try:
            with transaction.atomic():
                shift.delete()
                completed = True
        except DatabaseError as error:
            _log_database_failure("shift delete", error)
            shift.pk = pk
            context["delete_error"] = "The shift could not be deleted. Please try again."
            if completed:
                context["recovery_text"] = "The commit outcome is uncertain; inspect the Work register before retrying."
        else:
            messages.success(request, "Shift deleted.")
            return redirect(register_url(actual))
    if month:
        context["form_action"] = workspace_url("work:shift-delete", month, pk=pk)
        return _render_workspace(request, month, mode="delete", shift_id=pk, extra=context)
    return render(request, "work/shift_confirm_delete.html", context)
