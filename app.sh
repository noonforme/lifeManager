#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

if ! command -v uv >/dev/null 2>&1; then
    printf 'Error: uv is required. Install uv 0.12 or newer and try again.\n' >&2
    exit 1
fi

start_app() {
    printf '\nPreparing LifeOS...\n'
    uv sync --group test
    uv run python manage.py migrate
    printf '\nStarting LifeOS at http://127.0.0.1:8000\n'
    uv run python manage.py runserver 127.0.0.1:8000
}

run_tests() {
    printf '\nRunning tests...\n'
    uv run pytest -q
}

run_checks() {
    printf '\nRunning project checks...\n'
    uv run python manage.py check
    uv run python manage.py makemigrations --check --dry-run
}

while true; do
    printf '\nLifeOS\n'
    printf '  1) Start app\n'
    printf '  2) Run tests\n'
    printf '  3) Run project checks\n'
    printf '  4) Exit\n'
    printf 'Choose an option: '

    if ! IFS= read -r choice; then
        printf '\n'
        exit 0
    fi

    case "$choice" in
        1) start_app ;;
        2) run_tests ;;
        3) run_checks ;;
        4) exit 0 ;;
        *) printf 'Invalid choice. Enter 1, 2, 3, or 4.\n' ;;
    esac
done
