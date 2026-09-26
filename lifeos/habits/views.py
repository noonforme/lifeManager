import logging

from django.contrib import messages
from django.db import DatabaseError, transaction
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_GET, require_http_methods

from lifeos.core.clock import get_clock
from .forms import HabitConfigurationForm
from .queries import loaded_habits, row_for
from .models import HabitArchivePeriod
from django.utils import timezone

logger = logging.getLogger(__name__)


def database_failure(operation,error):
    logger.warning("Habits %s failed (%s)",operation,type(error).__name__)


def unavailable(request):
    return render(request,"habits/unavailable.html",status=503)


@require_http_methods(["GET","POST"])
def habit_create(request):
    return configuration(request)


@require_http_methods(["GET","POST"])
def habit_edit(request,pk):
    try:
        item = get_object_or_404(loaded_habits(),pk=pk)
    except DatabaseError as error:
        database_failure("habit edit lookup",error)
        return unavailable(request)
    return configuration(request,item)


def configuration(request,item=None):
    completed = False
    try:
        form = HabitConfigurationForm(request.POST if request.method=="POST" else None,instance=item,initial={"start_date":get_clock().today()})
        if request.method=="POST" and form.is_valid():
            with transaction.atomic():
                saved = form.save()
                completed = True
            messages.success(request,"Habit updated." if item else "Habit created.")
            return redirect("habits:habit-detail",pk=saved.pk)
    except DatabaseError as error:
        database_failure("habit configuration",error)
        if "form" not in locals():
            return unavailable(request)
        form.add_error(None,"The habit could not be saved. Please try again.")
        if completed:
            form.add_error(None,"The commit outcome is uncertain; inspect the Habits register before retrying.")
    return render(request,"habits/habit_form.html",{"form":form,"title":"Edit habit" if item else "New habit"})


@require_GET
def habit_detail(request,pk):
    today = get_clock().today()
    try:
        item = get_object_or_404(loaded_habits(),pk=pk)
        from dataclasses import replace
        from django.core.paginator import Paginator
        from .models import HabitOccurrence
        from .queries import occurrence_row, schedule_for
        history_page = Paginator(HabitOccurrence.objects.filter(habit=item), 20).get_page(request.GET.get("page"))
        row = replace(row_for(item,selected_date=today,today=today), history=tuple(occurrence_row(item,o,schedule_for(item)) for o in history_page))
    except DatabaseError as error:
        database_failure("habit detail lookup",error)
        return unavailable(request)
    return render(request,"habits/habit_detail.html",{"item":item,"row":row,"history_page":history_page})


@require_http_methods(["GET","POST"])
def habit_archive(request,pk):
    return lifecycle(request,pk,True)


@require_http_methods(["GET","POST"])
def habit_restore(request,pk):
    return lifecycle(request,pk,False)


def lifecycle(request,pk,archiving):
    today = get_clock().today()
    try:
        item = get_object_or_404(loaded_habits(),pk=pk)
    except DatabaseError as error:
        database_failure("lifecycle lookup",error)
        return unavailable(request)
    error_text = None
    completed = False
    if request.method == "POST":
        try:
            with transaction.atomic():
                if item.is_archived != archiving:
                    if archiving:
                        HabitArchivePeriod.objects.create(habit=item,start_date=today)
                        item.archived_at = timezone.now()
                    else:
                        period = item.archive_periods.get(end_date__isnull=True)
                        period.end_date = today
                        period.save()
                        item.archived_at = None
                    item.is_archived = archiving
                    item.save()
                completed = True
        except DatabaseError as error:
            database_failure("archive" if archiving else "restore",error)
            error_text = "The habit state could not be saved. Please try again."
            if completed:
                error_text += " The commit outcome is uncertain; inspect the Habits register before retrying."
        else:
            messages.success(request,"Habit archived." if archiving else "Habit restored.")
            return redirect("habits:archive-list" if archiving else "habits:habit-detail", **({} if archiving else {"pk":pk}))
    return render(request,"habits/lifecycle_confirm.html",{"item":item,"title":"Archive habit" if archiving else "Restore habit","error":error_text})


@require_GET
def archive_list(request):
    try:
        items = tuple(loaded_habits().filter(is_archived=True))
    except DatabaseError as error:
        database_failure("archive list",error)
        return unavailable(request)
    return render(request,"habits/archive_list.html",{"items":items})


@require_http_methods(["GET","POST"])
def occurrence_create(request,pk):
    return occurrence_mutation(request,pk)


@require_http_methods(["GET","POST"])
def occurrence_edit(request,pk,occurrence_pk):
    return occurrence_mutation(request,pk,occurrence_pk)


def occurrence_mutation(request,pk,occurrence_pk=None):
    from .forms import OccurrenceForm
    from .models import HabitOccurrence, ScheduleException
    today = get_clock().today()
    try:
        habit = get_object_or_404(loaded_habits(),pk=pk)
        item = get_object_or_404(HabitOccurrence,habit=habit,pk=occurrence_pk) if occurrence_pk else None
        from .queries import select_date
        initial_day = select_date(request.GET.get("date"),today=today).day
        form = OccurrenceForm(request.POST if request.method=="POST" else None,habit=habit,instance=item,initial={} if item else {"occurrence_date":initial_day})
    except DatabaseError as error:
        database_failure("occurrence lookup",error)
        return unavailable(request)
    completed = False
    try:
        if request.method=="POST" and form.is_valid():
            with transaction.atomic():
                if item is None and form.cleaned_data.get("one_off"):
                    ScheduleException.objects.get_or_create(habit=habit,day=form.cleaned_data["occurrence_date"],defaults={"kind":"addition"})
                saved = form.save()
                completed = True
            messages.success(request,"Occurrence updated." if item else "Occurrence recorded.")
            return redirect("habits:occurrence-detail",pk=pk,occurrence_pk=saved.pk)
    except DatabaseError as error:
        database_failure("occurrence save",error)
        form.add_error(None,"The occurrence could not be saved. Please try again.")
        if completed:
            form.add_error(None,"The commit outcome is uncertain; inspect habit history before retrying.")
    return render(request,"habits/occurrence_form.html",{"form":form,"habit":habit})


@require_GET
def occurrence_detail(request,pk,occurrence_pk):
    from .models import HabitOccurrence
    from .queries import occurrence_row,schedule_for
    try:
        habit = get_object_or_404(loaded_habits(),pk=pk)
        item = get_object_or_404(HabitOccurrence,habit=habit,pk=occurrence_pk)
        row = occurrence_row(habit,item,schedule_for(habit))
    except DatabaseError as error:
        database_failure("occurrence detail",error)
        return unavailable(request)
    return render(request,"habits/occurrence_detail.html",{"habit":habit,"row":row})


@require_http_methods(["GET","POST"])
def occurrence_delete(request,pk,occurrence_pk):
    from .models import HabitOccurrence
    try:
        habit = get_object_or_404(loaded_habits(),pk=pk)
        item = get_object_or_404(HabitOccurrence,habit=habit,pk=occurrence_pk)
    except DatabaseError as error:
        database_failure("occurrence delete lookup",error)
        return unavailable(request)
    completed = False
    error_text = None
    if request.method=="POST":
        try:
            with transaction.atomic():
                item.delete()
                completed = True
        except DatabaseError as error:
            database_failure("occurrence delete",error)
            error_text = "The occurrence could not be removed. Please try again."
            if completed:
                error_text += " The commit outcome is uncertain; inspect habit history before retrying."
        else:
            messages.success(request,"Occurrence removed.")
            return redirect("habits:habit-detail",pk=pk)
    return render(request,"habits/occurrence_confirm_delete.html",{"habit":habit,"day":item.occurrence_date,"error":error_text})


@require_GET
def register(request):
    from datetime import date
    from .queries import register_snapshot,select_date
    today = get_clock().today()
    selection = select_date(request.GET.get("date"),today=today)
    try:
        snapshot = register_snapshot(selected_date=selection.day,today=today)
    except DatabaseError as error:
        database_failure("register snapshot",error)
        return unavailable(request)
    previous = date.fromordinal(selection.day.toordinal()-1) if selection.day > date.min else None
    following = date.fromordinal(selection.day.toordinal()+1) if selection.day < date.max else None
    return render(request,"habits/register.html",{"snapshot":snapshot,"day":selection.day,"date_error":selection.error,"previous":previous,"following":following})
