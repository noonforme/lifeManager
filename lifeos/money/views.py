import logging
from datetime import date

from django.contrib import messages
from django.db import DatabaseError, transaction
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.views.decorators.http import require_GET, require_http_methods

from lifeos.core.clock import get_clock

from .calculations import TransactionAmountInput, calculate_monthly_movement, format_euros
from .forms import TransactionForm
from .models import Transaction
from .queries import select_month, transaction_snapshot_for_month

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
    logger.warning("Money %s failed (%s)", operation, type(error).__name__)


def _unavailable_response(request: HttpRequest) -> HttpResponse:
    return render(request, "money/register_unavailable.html", status=503)


@require_GET
def register(request: HttpRequest) -> HttpResponse:
    today = get_clock().today()
    selection = select_month(request.GET.get("month"), today=today)
    try:
        items = transaction_snapshot_for_month(selection.month)
    except DatabaseError as error:
        _log_database_failure("register query", error)
        return _unavailable_response(request)
    movement = calculate_monthly_movement(
        TransactionAmountInput(item.direction, item.amount) for item in items
    )
    transaction_rows = tuple(
        (item, item.get_direction_display(), format_euros(item.amount))
        for item in items
    )
    return render(
        request,
        "money/register.html",
        {
            "month": selection.month,
            "month_error": selection.error,
            "previous_month": selection.month.previous(),
            "next_month": selection.month.next(),
            "transactions": items,
            "transaction_rows": transaction_rows,
            "movement": movement,
            "formatted_inflow": format_euros(movement.inflow),
            "formatted_outflow": format_euros(movement.outflow),
            "formatted_net_movement": format_euros(movement.net_movement),
        },
    )


@require_http_methods(["GET", "POST"])
def transaction_create(request: HttpRequest) -> HttpResponse:
    initial = {}
    if prefill := _prefill_date(request.GET.get("date")):
        initial["transaction_date"] = prefill
    form = TransactionForm(request.POST or None, initial=initial)
    if request.method == "POST":
        is_valid = False
        atomic_entered = False
        try:
            is_valid = form.is_valid()
            if is_valid:
                with transaction.atomic():
                    atomic_entered = True
                    item = form.save()
        except DatabaseError as error:
            _log_database_failure("transaction create", error)
            form.add_error(None, "The transaction could not be saved. Please try again.")
            if atomic_entered:
                form.add_error(
                    None,
                    "The commit outcome is uncertain; inspect the Money register before retrying.",
                )
        else:
            if is_valid:
                messages.success(request, "Transaction created.")
                return redirect("money:transaction-detail", pk=item.pk)
    return render(request, "money/transaction_form.html", {"form": form})


@require_GET
def transaction_detail(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        item = get_object_or_404(Transaction, pk=pk)
    except DatabaseError as error:
        _log_database_failure("transaction detail lookup", error)
        return _unavailable_response(request)
    return render(
        request,
        "money/transaction_detail.html",
        {"item": item, "formatted_amount": format_euros(item.amount)},
    )


@require_http_methods(["GET", "POST"])
def transaction_edit(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        item = get_object_or_404(Transaction, pk=pk)
    except DatabaseError as error:
        _log_database_failure("transaction edit lookup", error)
        return _unavailable_response(request)
    form = TransactionForm(request.POST or None, instance=item)
    if request.method == "POST":
        is_valid = False
        atomic_entered = False
        try:
            is_valid = form.is_valid()
            if is_valid:
                with transaction.atomic():
                    atomic_entered = True
                    item = form.save()
        except DatabaseError as error:
            _log_database_failure("transaction edit", error)
            form.add_error(None, "The transaction could not be saved. Please try again.")
            if atomic_entered:
                form.add_error(
                    None,
                    "The commit outcome is uncertain; inspect the Money register before retrying.",
                )
        else:
            if is_valid:
                messages.success(request, "Transaction updated.")
                return redirect("money:transaction-detail", pk=item.pk)
    return render(
        request,
        "money/transaction_form.html",
        {
            "form": form,
            "page_title": "Edit transaction",
            "submit_label": "Save changes",
        },
    )


@require_http_methods(["GET", "POST"])
def transaction_delete(request: HttpRequest, pk: int) -> HttpResponse:
    try:
        item = get_object_or_404(Transaction, pk=pk)
    except DatabaseError as error:
        _log_database_failure("transaction delete lookup", error)
        return _unavailable_response(request)
    selected_month = f"{item.transaction_date.year:04d}-{item.transaction_date.month:02d}"
    identity = {
        "item_pk": item.pk,
        "transaction_date": item.transaction_date,
        "direction_label": item.get_direction_display(),
        "category": item.category,
    }
    if request.method == "POST":
        original_pk = item.pk
        delete_called = False
        try:
            with transaction.atomic():
                delete_called = True
                item.delete()
        except DatabaseError as error:
            _log_database_failure("transaction delete", error)
            item.pk = original_pk
            context = {
                **identity,
                "delete_error": "The transaction could not be deleted. Please try again.",
            }
            if delete_called:
                context["recovery_text"] = (
                    "The commit outcome is uncertain; inspect the Money register before retrying."
                )
            return render(request, "money/transaction_confirm_delete.html", context)
        messages.success(request, "Transaction deleted.")
        return redirect(f"{reverse('money:register')}?month={selected_month}")
    return render(request, "money/transaction_confirm_delete.html", identity)
