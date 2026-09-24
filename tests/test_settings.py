import os
import subprocess
import sys
from pathlib import Path

import pytest

from lifeos.settings import personal_database_path


def test_database_defaults_to_xdg_data_home(tmp_path: Path) -> None:
    result = personal_database_path({"XDG_DATA_HOME": str(tmp_path), "HOME": "/unused"})
    assert result == (tmp_path / "lifeos" / "lifeos.sqlite3").resolve()


def test_database_defaults_to_home_when_xdg_is_absent(tmp_path: Path) -> None:
    result = personal_database_path({"HOME": str(tmp_path)})
    assert result == (tmp_path / ".local/share/lifeos/lifeos.sqlite3").resolve()


def test_database_override_must_be_absolute() -> None:
    with pytest.raises(ValueError, match="absolute"):
        personal_database_path({"LIFEOS_DATABASE_PATH": "var/lifeos.sqlite3", "HOME": "/tmp"})


def test_database_override_expands_user(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HOME", str(tmp_path))
    result = personal_database_path({"LIFEOS_DATABASE_PATH": "~/private/lifeos.sqlite3", "HOME": str(tmp_path)})
    assert result == (tmp_path / "private/lifeos.sqlite3").resolve()


def _import_test_settings(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    clean = os.environ.copy()
    for key in ("LIFEOS_TEST_ROOT", "LIFEOS_TEST_OWNER", "LIFEOS_TEST_DATABASE_PATH"):
        clean.pop(key, None)
    clean.update(env)
    return subprocess.run(
        [sys.executable, "-c", "import lifeos.test_settings"],
        cwd=Path(__file__).parents[1],
        env=clean,
        text=True,
        capture_output=True,
        check=False,
    )


def _owned_root(tmp_path: Path) -> tuple[Path, str]:
    root = tmp_path / "owned"
    root.mkdir()
    owner = "test-owner"
    (root / ".lifeos-test-root").write_text(owner)
    return root, owner


def test_test_settings_require_ownership_variables() -> None:
    assert _import_test_settings({}).returncode != 0


def test_test_database_must_be_inside_owned_root(tmp_path: Path) -> None:
    root, owner = _owned_root(tmp_path)
    outside = tmp_path / "outside.sqlite3"
    result = _import_test_settings({"LIFEOS_TEST_ROOT": str(root), "LIFEOS_TEST_OWNER": owner, "LIFEOS_TEST_DATABASE_PATH": str(outside)})
    assert result.returncode != 0
    assert not outside.exists()


def test_test_database_cannot_resolve_to_personal_database(tmp_path: Path) -> None:
    root, owner = _owned_root(tmp_path)
    personal = root / "personal.sqlite3"
    link = root / "test.sqlite3"
    personal.touch()
    link.symlink_to(personal)
    result = _import_test_settings({"LIFEOS_TEST_ROOT": str(root), "LIFEOS_TEST_OWNER": owner, "LIFEOS_TEST_DATABASE_PATH": str(link), "LIFEOS_DATABASE_PATH": str(personal)})
    assert result.returncode != 0


def test_existing_test_database_must_have_owner_sidecar(tmp_path: Path) -> None:
    root, owner = _owned_root(tmp_path)
    database = root / "test.sqlite3"
    database.touch()
    result = _import_test_settings({"LIFEOS_TEST_ROOT": str(root), "LIFEOS_TEST_OWNER": owner, "LIFEOS_TEST_DATABASE_PATH": str(database)})
    assert result.returncode != 0


def test_owned_test_database_configuration_is_accepted(tmp_path: Path) -> None:
    root, owner = _owned_root(tmp_path)
    database = root / "test.sqlite3"
    result = _import_test_settings({"LIFEOS_TEST_ROOT": str(root), "LIFEOS_TEST_OWNER": owner, "LIFEOS_TEST_DATABASE_PATH": str(database)})
    assert result.returncode == 0, result.stderr
