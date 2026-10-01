# LifeOS

LifeOS is a private, local-first personal reconciliation system. The active application is a native Flutter desktop app. Work is the operational surface in this implementation slice; Today, Money, and Habits remain honest unavailable destinations until their native domains are implemented.

The repository retains an archived Django implementation only as product-history reference. Native workflows do not search for, inspect, import, migrate, mutate, or start the archived Django application or its database.

## Requirements

- Flutter 3.47.5
- Dart 3.13.4
- Linux desktop build dependencies supported by Flutter

Use the repository-pinned Flutter toolchain. The application does not require Django, Node, a browser, or a local HTTP server.

## Storage safety

Native runtime data uses the application-support location selected by the platform storage service. Development and verification must use explicitly guarded disposable roots containing synthetic data only.

Never inspect, print, probe, copy, migrate, or reset an archived or personal database while setting up or testing. Native workflows fail closed when safe storage ownership or database identity cannot be established.

## Run locally

Fetch pinned dependencies:

```bash
flutter pub get
```

Start the native Linux application:

```bash
flutter run -d linux
```

Work provides the native rail, register, and adjacent inspector for employment setup, agreements, live and manual shifts, pay periods, payslip evidence, reconciliation, and historical correction. Today, Money, Habits, and Backup and Export do not substitute fake data or launch archived web workflows when unavailable.

## Verify

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Release packaging, backup/export file selection, and the supported `app.sh` cutover are established by the release plan rather than documented speculatively here.

Read [docs/foundation/START-HERE.md](docs/foundation/START-HERE.md) before changing product behavior or architecture.
