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
from .queries import select_month, shifts_for_month

logger = logging.getLogger(__name__)


def _prefill_date(raw_value: str | None) -> date | None:
    if raw_value is None:
        return None
    try:
        value = date.fromisoformat(raw_value)
    except ValueError:
        return None
    if value.isoformat() != raw_value:
        return None
    return value


def _log_database_failure(operation: str, error: DatabaseError) -> None:
    logger.warning("Work %s failed (%s)", operation, type(error).__name__)


def _unavailable_response(request: HttpRequest) -> HttpResponse:
    return render(request, "work/register_unavailable.html", status=503)


@require_http_methods(["GET", "POST"])
def shift_create(request: HttpRequest) -> HttpResponse:
    initial = {}
    if prefill := _prefill_date(request.GET.get("date")):
        initial["work_date"] = prefill
    form = ShiftForm(request.POST or None, initial=initial)
    if request.method == "POST":
        try:
            is_valid = form.is_valid()
            if is_valid:
                with transaction.atomic():
                    shift = form.save()
        except DatabaseError as error:
            _log_database_failure("shift create", error)
            form.add_error(None, "The shift could not be saved. Please try again.")
        else:
            if is_valid:
                messages.success(request, "Shift created.")
                return redirect("work:shift-detail", pk=shift.pk)
    return render(request, "work/shift_form.html", {"form": form})


def shift_detail(request: HttpRequest, pk: int) -> HttpResponse:
    shift = get_object_or_404(Shift, pk=pk)
    return render(request, "work/shift_detail.html", {"shift": shift})


@require_http_methods(["GET", "POST"])
def shift_edit(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        shift = get_object_or_404(Shift, pk=pk)
    except DatabaseError as error:
        _log_database_failure("shift edit lookup", error)
        return _unavailable_response(request)
    form = ShiftForm(request.POST or None, instance=shift)
    if request.method == "POST":
        try:
            is_valid = form.is_valid()
            if is_valid:
                with transaction.atomic():
                    shift = form.save()
        except DatabaseError as error:
            _log_database_failure("shift edit", error)
            form.add_error(None, "The shift could not be saved. Please try again.")
        else:
            if is_valid:
                messages.success(request, "Shift updated.")
                return redirect("work:shift-detail", pk=shift.pk)
    return render(
        request,
        "work/shift_form.html",
        {
            "form": form,
            "page_title": "Edit shift",
            "submit_label": "Save changes",
        },
    )


@require_GET
def register(request: HttpRequest) -> HttpResponse:
    today = get_clock().today()
    selection = select_month(request.GET.get("month"), today=today)
    try:
        shifts = tuple(shifts_for_month(selection.month))
    except DatabaseError as error:
        _log_database_failure("register query", error)
        return _unavailable_response(request)
    salary = calculate_salary(
        SalaryInput(
            shift.worked_hours,
            shift.overtime_hours,
            shift.hourly_rate,
            shift.shift_type,
        )
        for shift in shifts
    )
    return render(
        request,
        "work/register.html",
        {
            "month": selection.month,
            "month_error": selection.error,
            "previous_month": selection.month.previous(),
            "next_month": selection.month.next(),
            "shifts": shifts,
            "salary": salary,
        },
    )


@require_http_methods(["GET", "POST"])
def shift_delete(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        shift = get_object_or_404(Shift, pk=pk)
    except DatabaseError as error:
        _log_database_failure("shift delete lookup", error)
        return _unavailable_response(request)
    if request.method == "POST":
        selected_month = f"{shift.work_date.year:04d}-{shift.work_date.month:02d}"
        original_pk = shift.pk
        try:
            with transaction.atomic():
                shift.delete()
        except DatabaseError as error:
            _log_database_failure("shift delete", error)
            shift.pk = original_pk
            return render(
                request,
                "work/shift_confirm_delete.html",
                {
                    "shift": shift,
                    "delete_error": "The shift could not be deleted. Please try again.",
                },
            )
        messages.success(request, "Shift deleted.")
        return redirect(f"{redirect('work:register').url}?month={selected_month}")
    return render(request, "work/shift_confirm_delete.html", {"shift": shift})
