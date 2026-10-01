# LifeOS

LifeOS is a private, local-first personal reconciliation system. The active application is a native Flutter desktop app. Work is the operational surface in this implementation slice; Today, Money, and Habits remain honest unavailable destinations until their native domains are implemented.

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

Work provides the native rail, register, and adjacent inspector for employment setup, agreements, live and manual shifts, pay periods, payslip evidence, reconciliation, and historical correction. Today, Money, Habits, and Backup and Export show honest unavailable states rather than fake data.

## Verify

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Release packaging and backup/export file selection are established by the release plan rather than documented speculatively here.

Read [the native specification](docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md) before changing product behavior or architecture. [PRODUCT.md](PRODUCT.md) and [DESIGN.md](DESIGN.md) record product and design context.
