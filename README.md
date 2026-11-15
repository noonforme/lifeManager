# LifeOS

A local-first Linux desktop application built with Flutter, Dart, Drift and SQLite.
Work includes employments, pay agreements, shifts, schedules, leave and reconciliation.

## Build and check

Requires Linux x64, Flutter 3.47.5 (Dart 3.13.4), Python 3.11+, and the Flutter Linux desktop toolchain.
Use the pinned SDK in `.fvmrc` and locked dependencies. CI lists Ubuntu build dependencies.

```sh
flutter pub get --enforce-lockfile
python3 tool/ci/run.py checks --evidence build/ci-evidence
python3 tool/ci/run.py tests --evidence build/ci-evidence
python3 tool/ci/run.py operations --evidence build/ci-evidence
python3 tool/ci/run.py build --evidence build/ci-evidence
```

Run `build/linux/x64/release/bundle/lifeos`; distribute the whole bundle directory.
Normal startup uses your application storage and can migrate existing data.
Tests use synthetic data; back up personal data before using the application.

## License

First-party code is MIT licensed; see LICENSE. Third-party font notices are retained under assets/fonts.
