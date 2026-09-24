import logging

from django.db import DatabaseError, connection
from django.http import HttpRequest, HttpResponse
from django.shortcuts import render
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_GET

from .dashboard import build_dashboard

logger = logging.getLogger(__name__)


@require_GET
def dashboard(request: HttpRequest) -> HttpResponse:
    return render(request, "core/dashboard.html", {"dashboard": build_dashboard()})


@require_GET
@never_cache
def ready(request: HttpRequest) -> HttpResponse:
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except DatabaseError:
        logger.exception("Readiness database check failed")
        return HttpResponse("unavailable\n", content_type="text/plain", status=503)
    return HttpResponse("ready\n", content_type="text/plain")
