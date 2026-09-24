from django.urls import include, path

urlpatterns = [
    path("work/", include("lifeos.work.urls")),
    path("", include("lifeos.core.urls")),
]
