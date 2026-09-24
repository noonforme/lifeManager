import os
from collections.abc import Mapping
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def personal_database_path(env: Mapping[str, str] | None = None) -> Path:
    values = os.environ if env is None else env
    override = values.get("LIFEOS_DATABASE_PATH", "").strip()
    if override:
        expanded = Path(override).expanduser()
        if not expanded.is_absolute():
            raise ValueError("LIFEOS_DATABASE_PATH must be absolute")
        return expanded.resolve(strict=False)

    xdg_data_home = values.get("XDG_DATA_HOME", "").strip()
    if xdg_data_home:
        base = Path(xdg_data_home).expanduser()
    else:
        home = values.get("HOME", "").strip()
        if not home:
            raise ImproperlyConfigured("HOME or XDG_DATA_HOME is required")
        base = Path(home).expanduser() / ".local" / "share"
    if not base.is_absolute():
        raise ImproperlyConfigured("The user data directory must be absolute")
    return (base / "lifeos" / "lifeos.sqlite3").resolve(strict=False)


DATABASE_PATH = personal_database_path()
DATABASE_PATH.parent.mkdir(mode=0o700, parents=True, exist_ok=True)

SECRET_KEY = os.environ.get("LIFEOS_SECRET_KEY", "lifeos-local-development-only")
DEBUG = os.environ.get("LIFEOS_DEBUG", "1") == "1"
ALLOWED_HOSTS = ["127.0.0.1", "localhost", "[::1]"]
CSRF_TRUSTED_ORIGINS = ["http://127.0.0.1:8000", "http://localhost:8000"]

INSTALLED_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "lifeos.core",
    "lifeos.work",
    "lifeos.money",
    "lifeos.habits",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
ROOT_URLCONF = "lifeos.urls"
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    }
]
WSGI_APPLICATION = "lifeos.wsgi.application"
ASGI_APPLICATION = "lifeos.asgi.application"
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": DATABASE_PATH}}
AUTH_PASSWORD_VALIDATORS: list[dict[str, str]] = []
LANGUAGE_CODE = "en-gb"
TIME_ZONE = "Europe/Vilnius"
USE_I18N = True
USE_TZ = True
STATIC_URL = "static/"
STATICFILES_DIRS = [BASE_DIR / "static"]
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
