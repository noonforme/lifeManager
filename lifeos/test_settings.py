import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

from .settings import *  # noqa: F403
from .settings import DATABASES, personal_database_path


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ImproperlyConfigured(f"{name} is required for test settings")
    return value


root = Path(_required("LIFEOS_TEST_ROOT")).resolve(strict=True)
owner = _required("LIFEOS_TEST_OWNER")
database_input = Path(_required("LIFEOS_TEST_DATABASE_PATH"))
if not database_input.is_absolute():
    raise ImproperlyConfigured("LIFEOS_TEST_DATABASE_PATH must be absolute")
if database_input.is_symlink():
    raise ImproperlyConfigured("The test database path cannot be a symlink")
database = database_input.resolve(strict=False)
marker = root / ".lifeos-test-root"
if not marker.is_file() or marker.read_text() != owner:
    raise ImproperlyConfigured("The test root ownership marker is invalid")
try:
    database.relative_to(root)
except ValueError as error:
    raise ImproperlyConfigured("The test database must be inside the test root") from error
if database == root:
    raise ImproperlyConfigured("The test database must be a file below the test root")
if database == personal_database_path():
    raise ImproperlyConfigured("The test database cannot be the personal database")
sidecar = database.with_name(f"{database.name}.owner")
if database.exists() and (not sidecar.is_file() or sidecar.read_text() != owner):
    raise ImproperlyConfigured("The existing test database is not owned by this run")
if not database.exists():
    sidecar.write_text(owner)

DATABASES["default"] = {
    "ENGINE": "django.db.backends.sqlite3",
    "NAME": database,
    "TEST": {"NAME": database},
}
DEBUG = False
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
