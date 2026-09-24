import os
from collections.abc import Mapping
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

from .common_settings import *  # noqa: F403
from .common_settings import BASE_DIR


def personal_database_path(env: Mapping[str, str] | None = None) -> Path:
    values = os.environ if env is None else env
    override = values.get("LIFEOS_DATABASE_PATH", "").strip()
    if override:
        expanded = Path(override).expanduser()
        if not expanded.is_absolute():
            raise ValueError("LIFEOS_DATABASE_PATH must be absolute")
        resolved = expanded.resolve(strict=False)
        try:
            resolved.relative_to(BASE_DIR)
        except ValueError:
            return resolved
        raise ValueError("LIFEOS_DATABASE_PATH must be outside the repository")

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
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": DATABASE_PATH}}
