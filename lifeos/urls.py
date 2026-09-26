from django.urls import include, path

urlpatterns = [
    path("habits/", include("lifeos.habits.urls")),
    path("work/", include("lifeos.work.urls")),
    path("money/", include("lifeos.money.urls")),
    path("", include("lifeos.core.urls")),
]
