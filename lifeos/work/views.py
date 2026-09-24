import logging
from datetime import date

from django.contrib import messages
from django.db import DatabaseError, transaction
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_http_methods

from .forms import ShiftForm
from .models import Shift

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


@require_http_methods(["GET", "POST"])
def shift_create(request: HttpRequest) -> HttpResponse:
    initial = {}
    if prefill := _prefill_date(request.GET.get("date")):
        initial["work_date"] = prefill
    form = ShiftForm(request.POST or None, initial=initial)
    if request.method == "POST" and form.is_valid():
        try:
            with transaction.atomic():
                shift = form.save()
        except DatabaseError as error:
            logger.warning(
                "Work shift create failed (%s)",
                type(error).__name__,
            )
            form.add_error(None, "The shift could not be saved. Please try again.")
        else:
            messages.success(request, "Shift created.")
            return redirect("work:shift-detail", pk=shift.pk)
    return render(request, "work/shift_form.html", {"form": form})


def shift_detail(request: HttpRequest, pk: int) -> HttpResponse:
    shift = get_object_or_404(Shift, pk=pk)
    return render(request, "work/shift_detail.html", {"shift": shift})


@require_http_methods(["GET", "POST"])
def shift_edit(request: HttpRequest, pk: int) -> HttpResponse:
    shift = get_object_or_404(Shift, pk=pk)
    form = ShiftForm(request.POST or None, instance=shift)
    if request.method == "POST" and form.is_valid():
        try:
            with transaction.atomic():
                shift = form.save()
        except DatabaseError as error:
            logger.warning(
                "Work shift edit failed (%s)",
                type(error).__name__,
            )
            form.add_error(None, "The shift could not be saved. Please try again.")
        else:
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
