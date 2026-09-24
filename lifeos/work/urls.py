from django.urls import path

from . import views

app_name = "work"

urlpatterns = [
    path("shifts/new/", views.shift_create, name="shift-create"),
    path("shifts/<int:pk>/", views.shift_detail, name="shift-detail"),
]
