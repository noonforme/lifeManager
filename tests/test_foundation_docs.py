import json
import re
from datetime import date
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
FOUNDATION = ROOT / "docs" / "foundation"
REQUIRED_DOCUMENTS = (
    "START-HERE.md",
    "PRODUCT.md",
    "V1-SCOPE.md",
    "DOMAIN.md",
    "DESIGN.md",
    "ARCHITECTURE.md",
    "ENGINEERING.md",
    "LESSONS.md",
)
AUTHORITY_ORDER = (
    "PRODUCT.md",
    "V1-SCOPE.md",
    "DOMAIN.md",
    "DESIGN.md",
    "ARCHITECTURE.md",
    "ENGINEERING.md",
    "LESSONS.md",
)
FIXTURES = (
    "salary-cases.json",
    "habit-momentum-cases.json",
)
PLACEHOLDER_PATTERN = re.compile(
    r"\b(?:TODO|TBD|FIXME|XXX)\b|<[^>]*(?:placeholder|fill)[^>]*>",
    re.IGNORECASE,
)
ISO_DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DECIMAL_PATTERN = re.compile(r"^-?\d+\.\d{2}$")


def read_document(name: str) -> str:
    return (FOUNDATION / name).read_text(encoding="utf-8")


def load_fixture(name: str) -> dict[str, object]:
    return json.loads((FOUNDATION / "fixtures" / name).read_text(encoding="utf-8"))


def walk_values(value: object):
    if isinstance(value, dict):
        for key, child in value.items():
            yield key, child
            yield from walk_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_values(child)


def test_foundation_package_contains_every_required_file() -> None:
    required = [FOUNDATION / name for name in REQUIRED_DOCUMENTS]
    required.extend(FOUNDATION / "fixtures" / name for name in FIXTURES)
    required.append(ROOT / "README.md")

    assert [path.relative_to(ROOT) for path in required if not path.is_file()] == []


def test_start_here_declares_the_authority_hierarchy_in_order() -> None:
    text = read_document("START-HERE.md")
    positions = [text.index(f"{index}. [{name}]") for index, name in enumerate(AUTHORITY_ORDER, 1)]

    assert positions == sorted(positions)
    assert "Historical code is not an implicit specification" in text


def test_foundation_documents_have_no_unresolved_placeholders() -> None:
    for name in REQUIRED_DOCUMENTS:
        assert PLACEHOLDER_PATTERN.search(read_document(name)) is None, name


def test_history_is_confined_to_lessons_and_not_normative() -> None:
    historical_path = "/home/aUser/improvedCalendar"
    for name in REQUIRED_DOCUMENTS:
        text = read_document(name)
        if name == "LESSONS.md":
            assert historical_path in text
        else:
            assert historical_path not in text, name
            assert "consult the historical" not in text.lower(), name
            assert "copy from the historical" not in text.lower(), name


def test_readme_uses_uv_commands_and_documents_runtime_boundaries() -> None:
    text = (ROOT / "README.md").read_text(encoding="utf-8")
    commands = re.findall(r"```bash\n(.*?)```", text, re.DOTALL)
    command_lines = [
        line.strip()
        for block in commands
        for line in block.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]

    assert command_lines
    assert all(line.startswith("uv ") for line in command_lines)
    assert "uv sync --group test" in command_lines
    assert "uv run python manage.py migrate" in command_lines
    assert "uv run python manage.py runserver 127.0.0.1:8000" in command_lines
    assert "uv run pytest -q" in command_lines
    assert "uv run python manage.py check" in command_lines
    assert "uv run python manage.py makemigrations --check --dry-run" in command_lines
    assert "lifeos.settings" in text
    assert "/ready/" in text
    assert "LIFEOS_DATABASE_PATH" in text
    assert "no visual browser tests" in text.lower()


@pytest.mark.parametrize("fixture_name", FIXTURES)
def test_fixtures_are_versioned_and_have_unique_case_ids(fixture_name: str) -> None:
    fixture = load_fixture(fixture_name)
    cases = fixture["cases"]
    ids = [case["id"] for case in cases]

    assert fixture["schema_version"] == 1
    assert cases
    assert len(ids) == len(set(ids))


def test_salary_fixture_uses_decimal_strings_for_numeric_values() -> None:
    fixture = load_fixture("salary-cases.json")

    for key, value in walk_values(fixture["cases"]):
        if key in {"hours", "overtime_hours", "hourly_rate"} or key.startswith("expected_"):
            assert isinstance(value, str) and DECIMAL_PATTERN.fullmatch(value), (key, value)


def test_domain_defines_exact_salary_rates() -> None:
    text = read_document("DOMAIN.md")

    assert "GPM is `gross × 0.20`" in text
    assert "VSD is `gross × 0.1252`" in text
    assert "PSD is `gross × 0.0698`" in text


def test_habit_fixture_uses_strict_iso_dates_and_decimal_outputs() -> None:
    fixture = load_fixture("habit-momentum-cases.json")

    for case in fixture["cases"]:
        for completion_date in case["completion_dates"]:
            assert ISO_DATE_PATTERN.fullmatch(completion_date)
            assert date.fromisoformat(completion_date).isoformat() == completion_date
        assert DECIMAL_PATTERN.fullmatch(case["expected_momentum"])
