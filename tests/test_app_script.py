from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_SCRIPT = PROJECT_ROOT / "app.sh"


@pytest.fixture
def launcher_environment(tmp_path: Path) -> tuple[dict[str, str], Path]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    command_log = tmp_path / "uv-commands.log"
    fake_uv = bin_dir / "uv"
    fake_uv.write_text(
        '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$UV_COMMAND_LOG"\n',
        encoding="utf-8",
    )
    fake_uv.chmod(fake_uv.stat().st_mode | stat.S_IXUSR)

    environment = os.environ.copy()
    environment["PATH"] = f"{bin_dir}:{environment['PATH']}"
    environment["UV_COMMAND_LOG"] = str(command_log)
    return environment, command_log


def run_launcher(choice: str, environment: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(APP_SCRIPT)],
        input=f"{choice}\n4\n",
        text=True,
        capture_output=True,
        cwd="/tmp",
        env=environment,
        check=False,
    )


@pytest.mark.parametrize(
    ("choice", "expected_commands"),
    [
        (
            "1",
            [
                "sync --group test",
                "run python manage.py migrate",
                "run python manage.py runserver 127.0.0.1:8000",
            ],
        ),
        ("2", ["run pytest -q"]),
        (
            "3",
            [
                "run python manage.py check",
                "run python manage.py makemigrations --check --dry-run",
            ],
        ),
    ],
)
def test_menu_runs_selected_workflow_from_any_directory(
    choice: str,
    expected_commands: list[str],
    launcher_environment: tuple[dict[str, str], Path],
) -> None:
    environment, command_log = launcher_environment

    result = run_launcher(choice, environment)

    assert result.returncode == 0, result.stderr
    assert command_log.read_text(encoding="utf-8").splitlines() == expected_commands


def test_menu_reprompts_after_an_invalid_choice(
    launcher_environment: tuple[dict[str, str], Path],
) -> None:
    environment, command_log = launcher_environment

    result = subprocess.run(
        [str(APP_SCRIPT)],
        input="invalid\n2\n4\n",
        text=True,
        capture_output=True,
        cwd="/tmp",
        env=environment,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert "Invalid choice" in result.stdout
    assert command_log.read_text(encoding="utf-8").splitlines() == ["run pytest -q"]
