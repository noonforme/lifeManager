# Engineering

## Toolchain

Python dependencies and commands are managed with `uv`; `pyproject.toml` declares direct dependencies and `uv.lock` freezes resolution. Use Python 3.14 and install the test group before development.

```bash
uv sync --group test
```

## Development commands

```bash
uv run python manage.py migrate
uv run python manage.py runserver 127.0.0.1:8000
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
```

Runtime commands use `lifeos.settings`. Tests use `lifeos.test_settings` through pytest configuration.

## Change discipline

Implement complete vertical slices with RED–GREEN–REFACTOR: write the smallest behavioral test, observe the expected failure, implement the behavior, run the focused test, then run the entire suite. Match existing idiom and keep domain policy out of views and templates.

## Migrations

Model changes require reviewed migrations. Before committing, apply migrations to an explicitly disposable database, run `makemigrations --check --dry-run`, and test both the new behavior and important constraints. Never run migration experiments against the personal database.

## Clock

Code that depends on today obtains a `Clock` or calls the core clock boundary. Request composition reads the date once. Tests use a fixed clock through the context-local override; they do not patch the system clock globally.

## Test database ownership

Test settings fail closed. A test database is valid only when all three variables identify an absolute database within an explicitly owned temporary root:

- `LIFEOS_TEST_ROOT`
- `LIFEOS_TEST_OWNER`
- `LIFEOS_TEST_DATABASE_PATH`

The root contains `.lifeos-test-root` with the matching owner value. An existing database also requires its matching `.owner` sidecar. Symlinks, paths outside the root, and any path resolving to the personal database are rejected. The pytest bootstrap creates session-specific ownership automatically; other runners must provide equivalent isolated ownership deliberately.

## Verification order

1. Run the narrowest new test and observe RED.
2. Run the same test to GREEN.
3. Run the affected module or contract tests.
4. Run the complete pytest suite.
5. Run Django system checks.
6. Run the migration drift check.
7. For a milestone, start against a throwaway absolute database, query `/ready/` and `/`, and record the exact manual observations.

Do not claim success from expected output, a partial run, or a hidden warning. Record command, result, warnings, and skipped/manual gaps.

## Assets and fonts

Fonts are fetched only through the repository script, which pins source URLs and SHA-256 values, writes through a temporary file, and rejects mismatches. Tests verify committed hashes, local references, theme behavior boundaries, contrast, and the absence of remote runtime assets.

## Browser testing boundary

Milestone one has no visual browser tests. Do not add browser drivers, screenshots, snapshots, golden images, pixel comparison, capture rounds, or visual-regression services. Semantic response tests, static asset contracts, contrast calculations, and documented manual responsive checks provide the current evidence. Report unperformed visual or assistive-technology checks as manual gaps rather than implying automation.
