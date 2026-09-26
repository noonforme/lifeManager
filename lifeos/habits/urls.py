from django.urls import path
from . import views

app_name = "habits"
urlpatterns = [
    path("",views.register,name="register"),
    path("<int:pk>/occurrences/new/",views.occurrence_create,name="occurrence-create"),
    path("<int:pk>/occurrences/<int:occurrence_pk>/",views.occurrence_detail,name="occurrence-detail"),
    path("<int:pk>/occurrences/<int:occurrence_pk>/edit/",views.occurrence_edit,name="occurrence-edit"),
    path("<int:pk>/occurrences/<int:occurrence_pk>/delete/",views.occurrence_delete,name="occurrence-delete"),
    path("archived/",views.archive_list,name="archive-list"),
    path("<int:pk>/archive/",views.habit_archive,name="habit-archive"),
    path("<int:pk>/restore/",views.habit_restore,name="habit-restore"),
    path("new/",views.habit_create,name="habit-create"),
    path("<int:pk>/",views.habit_detail,name="habit-detail"),
    path("<int:pk>/edit/",views.habit_edit,name="habit-edit"),
]
