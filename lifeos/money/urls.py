from django.urls import path

from . import views

app_name = "money"

urlpatterns = [
    path("", views.register, name="register"),
    path("transactions/new/", views.transaction_create, name="transaction-create"),
    path(
        "transactions/<int:pk>/",
        views.transaction_detail,
        name="transaction-detail",
    ),
    path(
        "transactions/<int:pk>/edit/",
        views.transaction_edit,
        name="transaction-edit",
    ),
    path(
        "transactions/<int:pk>/delete/",
        views.transaction_delete,
        name="transaction-delete",
    ),
]
