from datetime import date
from urllib.parse import urlencode

from django.http import HttpRequest
from django.urls import reverse

from .models import Shift
from .queries import CalendarMonth, select_month


def workspace_month(request: HttpRequest, *, today: date) -> CalendarMonth | None:
    if request.GET.get("workspace") != "1" or "month" not in request.GET:
        return None
    selection = select_month(request.GET["month"], today=today)
    return selection.month if selection.error is None else None


def register_url(month: CalendarMonth, shift_id: int | None = None) -> str:
    params = {"month": month.value}
    if shift_id is not None:
        params["shift"] = str(shift_id)
    return f"{reverse('work:register')}?{urlencode(params)}"


def workspace_url(route: str, month: CalendarMonth, *, pk: int | None = None) -> str:
    path = reverse(route, kwargs={"pk": pk} if pk is not None else None)
    return f"{path}?{urlencode({'workspace': '1', 'month': month.value})}"


def selected_shift(shifts: tuple[Shift, ...], raw_id: str | None) -> Shift | None:
    if raw_id is None or len(raw_id) > 20:
        return None
    return next((shift for shift in shifts if str(shift.pk) == raw_id), None)
