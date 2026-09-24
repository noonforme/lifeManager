# LifeOS

LifeOS is a private, local-first personal reconciliation system. It brings Work, Money, and Habits into one Daily Register so the user can compare what happened with what they intended and leave a trustworthy record.

Milestone one establishes the safe Django foundation and renders honest empty register states. It does not yet implement data-entry workflows. Milestone one has **no visual browser tests**; verification is deterministic Python and Django testing plus documented manual checks.

## Requirements

- Python 3.14
- `uv` 0.12 or newer

## Set up

```bash
uv sync --group test
```

## Database safety

Runtime uses `lifeos.settings`. By default, the SQLite database is stored at `${XDG_DATA_HOME}/lifeos/lifeos.sqlite3`, falling back to `~/.local/share/lifeos/lifeos.sqlite3` when `XDG_DATA_HOME` is unset or empty. Set `LIFEOS_DATABASE_PATH` to an absolute path outside the source repository to override that location.

Do not inspect, print, probe, copy, or reset the personal database while setting up or testing. The test settings require an explicitly owned temporary database and fail closed if ownership cannot be proven.

## Run locally

Apply migrations:

```bash
uv run python manage.py migrate
```

Start the loopback-only development server:

```bash
uv run python manage.py runserver 127.0.0.1:8000
```

Open the Daily Register at `/`. The readiness endpoint is `/ready/`; it returns only `ready` or `unavailable` and never exposes database details.

## Verify

```bash
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
```

Read [docs/foundation/START-HERE.md](docs/foundation/START-HERE.md) before changing product behavior or architecture.
