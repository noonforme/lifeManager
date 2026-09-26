# LifeOS

LifeOS is a private, local-first personal reconciliation system. It brings Work, Money, and Habits into one Daily Register so the user can compare what happened with what they intended and leave a trustworthy record.

The current build includes the safe Django foundation and persisted Work, Money and Habits vertical slices. Habits supports check, quantity, abstinence and scheduled-chore routines with structured recurrence, factual outcomes, archive/restore and derived streak/momentum. Work and Money have **no visual browser tests**; verification is deterministic Python and Django testing plus documented manual checks.

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

Open the Daily Register at `/`. Open the monthly Work register at `/work/`; from there you can create, review, edit, and delete shifts through server-rendered forms. The register derives an **Estimated salary** with its exact version-one formula, rounding, and deduction rates, and states that the result is not tax advice.

Open the monthly Money register at `/money/` or create a record at `/money/transactions/new/`. The no-JavaScript workflow supports create, review, edit, confirmed hard delete, and canonical detail pages. The register derives **Inflow**, **Outflow**, and **Net movement** from one selected-month transaction snapshot. Net movement is not an account balance, budget, tax result, forecast, or bank-import claim.

Open `/habits/` or create at `/habits/new/`. The selected-date register supports daily, weekly, anchored day/week intervals, monthly dates and ordinal weekdays, with inclusive active dates, additions, exclusions and pauses. Quantity targets use exact non-negative two-place Decimal values. Missing past due evidence is Unknown; abstinence never implies success from silence. Excused results neither extend nor break streaks. Needs attention covers only the 90 days before the selected date, excluding today and future dates. Archive periods preserve history and suspend recurrence until restoration. Reminder times are in-app display/ordering only, not notifications. The read-only calendar projection accepts at most 366 inclusive dates; no calendar UI is included.

The readiness endpoint is `/ready/`; it returns only `ready` or `unavailable` and never exposes database details.

## Verify

```bash
uv run pytest -q
uv run python manage.py check
uv run python manage.py makemigrations --check --dry-run
```

Read [docs/foundation/START-HERE.md](docs/foundation/START-HERE.md) before changing product behavior or architecture.
