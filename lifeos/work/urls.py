from django.urls import path

from . import views

app_name = "work"

urlpatterns = [
    path("", views.register, name="register"),
    path("shifts/new/", views.shift_create, name="shift-create"),
    path("shifts/<int:pk>/", views.shift_detail, name="shift-detail"),
    path("shifts/<int:pk>/edit/", views.shift_edit, name="shift-edit"),
    path("shifts/<int:pk>/delete/", views.shift_delete, name="shift-delete"),
]
