#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

resolve_flutter() {
    if [[ -n "${FLUTTER:-}" ]]; then
        printf '%s\n' "$FLUTTER"
    elif command -v flutter >/dev/null 2>&1; then
        command -v flutter
    elif [[ -x "$HOME/.local/opt/flutter-3.47.5/bin/flutter" ]]; then
        printf '%s\n' "$HOME/.local/opt/flutter-3.47.5/bin/flutter"
    else
        return 1
    fi
}

if ! flutter="$(resolve_flutter)"; then
    printf 'Error: Flutter 3.47.5 is required. Install it or set FLUTTER.\n' >&2
    exit 1
fi
readonly flutter

start_app() {
    printf '\nPreparing LifeOS...\n'
    "$flutter" pub get
    printf '\nStarting LifeOS (native Linux)...\n'
    "$flutter" run -d linux
}

run_tests() {
    printf '\nRunning tests...\n'
    "$flutter" test
}

run_checks() {
    printf '\nRunning project checks...\n'
    "$flutter" analyze lib test tool
    dart_bin="$(dirname -- "$flutter")/dart"
    "$dart_bin" format --output=none --set-exit-if-changed lib test tool
    "$dart_bin" run tool/schema_check.dart
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
