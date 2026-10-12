# LifeOS

LifeOS is a private, local-first personal reconciliation system. The active application is a native Flutter desktop app shaped like a 2001 office program: a menu bar, toolbar and Address bar over a blue task pane and a details list, with records opening in Properties dialogs. Work is the first area. Finance, Tracking and Knowledge are honest unavailable destinations until their domains are implemented.

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

Its **Start app** runs a release build. Debug builds draw several times slower, so pickers and menus feel laggy in them; option 4 starts one only for hot reload.

For development through Paseo, see [the Paseo setup guide](docs/paseo.md). The repository's `paseo.json` adds launcher, test, and check actions to the workspace.

LifeOS looks like a 2001 office PC, shaped like that era's file browser: an orb toolbar, an Address bar, a blue task pane that follows the selection, details lists, Properties dialogs and forms as dialog boxes, set in EraSans (Wine's Tahoma-metric font).

What the shell holds:

- **Work:** employments and agreements with night, holiday and overtime premiums and leave pay; rotating schedules with planned days you confirm, day changes and paid leave; manual shifts; pay periods, payslips and reconciliation; and correction. Calendar, Shifts, Leave, Schedules, Pay periods, Payslips and Agreements are chosen with the **View:** dropdown or under the employment in Books; Work tasks sit in the task pane.
- **Working:** select any derived figure; Details in the task pane shows how it was worked out.
- **Properties:** select a row and press Enter, double-click it, or use its Properties task to open its Properties sheet.
- **History:** every record's Properties sheet keeps a History tab beside General.
- **Add and "from last time":** create records from anywhere.
- **Today:** desks of tiles (Needs you, Next shifts, Work this period, the Journal, the Month close checklist). Create your own desks, and save filtered sheets as views.
- **Journal:** every event, by day.

Finance, Tracking, Knowledge and Backup and export show honest unavailable states rather than fake data.

## Verify

```bash
dart format --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/schema_check.dart
```

`./app.sh` runs the same: option 2 runs the tests, and option 3 runs analysis, the format check and the schema check. Goldens in `test/goldens/` cover the Work list, a selected row, a figure's Working, a pay period's Properties, the manual shift and pay agreement forms, the open calendar and Today at 1280 × 800 and 960 × 760; refresh them with `flutter test --update-goldens test/goldens` after an intended visual change. `flutter test --run-skipped -t real-font --update-goldens test/goldens/real_font_check_test.dart` renders the same screens in the bundled EraSans for a look by eye.

Release packaging and backup/export file selection are established by the release plan rather than documented speculatively here.

Read [the native specification](docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md) and [the shell specification](docs/superpowers/specs/2026-10-01-lifeos-office-machine-shell-design.md) before changing product behavior or architecture. [PRODUCT.md](PRODUCT.md) and [DESIGN.md](DESIGN.md) record product and design context.
