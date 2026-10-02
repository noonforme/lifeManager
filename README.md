# LifeOS

LifeOS is a private, local-first personal reconciliation system. The active application is a native Flutter desktop app built as an office machine: a menu bar, toolbar and formula bar over a book tree, a desk and a record inspector. Work is the first area. Finance, Tracking and Knowledge are honest unavailable destinations until their domains are implemented.

The repository contains only the native Flutter application. Earlier prototypes live in Git history; their data is never read, imported, or migrated.

## Requirements

- Flutter 3.47.5
- Dart 3.13.4
- Linux desktop build dependencies supported by Flutter

Use the repository-pinned Flutter toolchain. The application does not require Node, a browser, or a local HTTP server.

## Storage safety

Native runtime data uses the application-support location selected by the platform storage service. Development and verification must use explicitly guarded disposable roots containing synthetic data only.

Never inspect, print, probe, copy, migrate, or reset a personal database while setting up or testing. Native workflows fail closed when safe storage ownership or database identity cannot be established.

## Run locally

Fetch pinned dependencies:

```bash
flutter pub get
```

Start the native Linux application:

```bash
flutter run -d linux
```

Or use the interactive launcher, which finds Flutter through `FLUTTER`, `PATH`, or `~/.local/opt/flutter-3.47.5`:

```bash
./app.sh
```

What the shell holds:

- **Work:** employments and agreements with night, holiday and overtime premiums; live and manual shifts; pay periods, payslips and reconciliation; and correction. Shifts, Pay periods, Payslips and Agreements are separate sheets.
- **Formula bar:** select any derived figure to read how it was worked out.
- **History:** every record keeps its own History tab.
- **+ Add and "from last time":** create records from anywhere.
- **Today:** desks of tiles (Needs you, Work this period, the Journal, the Month close checklist). Create your own desks, and save filtered sheets as views.
- **Journal:** every event, by day.
- **Appearances:** under View › Appearance, Office Machine Day, Night, High contrast and Millennium. The choice is kept in the database.

Finance, Tracking, Knowledge and Backup and export show honest unavailable states rather than fake data.

## Verify

```bash
dart format --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/schema_check.dart
```

`./app.sh` runs the same: option 2 runs the tests, and option 3 runs analysis, the format check and the schema check. Goldens in `test/goldens/` cover the shell in every appearance; refresh them with `flutter test --update-goldens test/goldens` after an intended visual change.

Release packaging and backup/export file selection are established by the release plan rather than documented speculatively here.

Read [the native specification](docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md) and [the shell specification](docs/superpowers/specs/2026-10-01-lifeos-office-machine-shell-design.md) before changing product behavior or architecture. [PRODUCT.md](PRODUCT.md) and [DESIGN.md](DESIGN.md) record product and design context.
