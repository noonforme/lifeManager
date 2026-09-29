# LifeOS Native Foundation and Work Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the shipped Django application with a private native Linux Flutter workbench and deliver the complete reinvented Work domain.

**Architecture:** A pinned Flutter desktop modular monolith uses Riverpod controllers over application services, pure Work policy, Drift repositories, and one SQLite database isolate. The native application creates a fresh identified database, never discovers the archived Django database, and exposes one rail/register/inspector workspace with manual backup and export.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, Drift 2.35.0, sqlite3 3.6.0, Riverpod 3.4.3, GoRouter 18.0.2, Flutter test/integration_test, Linux, RPM.

**Spec:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md`

## Global Constraints

- Target native Fedora-compatible Linux first; no web target or local HTTP server ships.
- Pin Flutter `3.47.5` and Dart `3.13.4`; commit `pubspec.lock`.
- Use a fresh database named `lifeos-native-v1.sqlite` below application support with SQLite `application_id = 0x4C49464F` (`1279870543`).
- Never search for, inspect, import, copy, migrate, or mutate the archived Django database.
- Runtime databases, exports, backups, screenshots, fixtures, and logs never contain real personal data in source control.
- SQLite is authoritative; expected pay and reconciliation are derived, not persisted.
- Store money and durations as integers; use rational multipliers and `BigInt` intermediates; never use floating point for pay.
- Persist UTC instants, captured IANA timezone, and strict local start date.
- Used agreements and finalized shifts/payslips are immutable; correction is void-and-replace.
- Publish mutation success only after commit; expose stale and uncertain outcomes explicitly.
- The defining interaction is mouse-first single-click select → inspect → act, with full keyboard and semantic accessibility.
- No cloud, telemetry, analytics, remote assets, automatic backup, or runtime plugin system.
- Visual verification is one batched capture/review pass, one batched fix, and at most one confirmation pass.
- At completion, `./app.sh` must test, build, verify, and start the native app using guarded disposable storage for verification.

## Review Focus

1. A symlink, environment override, or arbitrary existing SQLite file must never lead startup or tests to open/migrate the archived or production database.
2. DST folds/gaps, overnight work, and agreement boundaries must use elapsed UTC duration and the persisted local start date consistently.
3. A commit-boundary failure must never be reported as definite success/failure when the outcome is uncertain, preventing blind duplicate retries.
4. Concurrent active-shift, revision, and correction operations must be atomic; stale operations cannot partially void or overwrite history.
5. Backup must use a consistent SQLite snapshot rather than copying a live WAL database, and diagnostics/routes/captures must not leak personal content.

---

## Plan Series and Dependency Order

Execute these plans in order. Each phase ends with an independently reviewable commit and must pass its own checks.

1. [Toolchain, privacy, and core foundation](2026-09-29-lifeos-native-01-foundation.md)
2. [Pure Work domain](2026-09-29-lifeos-native-02-work-domain.md)
3. [Work persistence and application services](2026-09-29-lifeos-native-03-work-data-application.md)
4. [Native workbench and Work presentation](2026-09-29-lifeos-native-04-workbench-ui.md)
5. [Backup, integration, packaging, cutover, and finish](2026-09-29-lifeos-native-05-release-cutover.md)

## Stable Cross-Phase Interfaces

Later plans depend on these names. Change them only by updating all dependent plans before execution.

```dart
abstract interface class AppClock {
  DateTime nowUtc();
}

abstract interface class TimezoneService {
  ZonedInstant resolveLocal(LocalDate date, LocalTime time, String zoneId, {required FoldChoice fold});
  LocalDate localDateAt(DateTime utc, String zoneId);
}

sealed class MutationOutcome<T> {}
final class Committed<T> extends MutationOutcome<T> { final T value; }
final class Invalid<T> extends MutationOutcome<T> { final Map<String, List<FieldIssue>> fields; }
final class Stale<T> extends MutationOutcome<T> {}
final class Missing<T> extends MutationOutcome<T> {}
final class Unavailable<T> extends MutationOutcome<T> { final SafeFailureCode code; }
final class Uncertain<T> extends MutationOutcome<T> { final SafeFailureCode code; }

abstract interface class WorkRepository {
  Future<MutationOutcome<T>> transaction<T>(Future<T> Function(WorkWriteStore store) body);
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope);
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id);
}

abstract interface class DestinationPicker {
  Future<Uri?> chooseBackupDestination();
  Future<Uri?> chooseExportDestination();
}
```

Projection and route scope use these stable shapes:

```dart
sealed class WorkTemporalScope { const WorkTemporalScope(); }
final class PayPeriodScope extends WorkTemporalScope {
  const PayPeriodScope(this.periodId);
  final PayPeriodId periodId;
}
final class DateRangeScope extends WorkTemporalScope {
  const DateRangeScope({required this.start, required this.end});
  final LocalDate start;
  final LocalDate end;
}

final class WorkScope {
  const WorkScope({required this.employmentId, required this.temporal});
  final EmploymentId? employmentId;
  final WorkTemporalScope? temporal;
}
```

Routes contain only safe structural state:

```text
/work?employment=<uuid>&period=<uuid>&record=<kind:uuid>&mode=inspect|create|edit|correct
/work?employment=<uuid>&from=YYYY-MM-DD&to=YYYY-MM-DD&record=<kind:uuid>&mode=inspect|create|edit|correct
/system/files
/today
/money
/habits
```

Personal labels, notes, amounts, shift instants, and drafts never enter routes or preferences.

## Whole-Series Completion Check

- [ ] `./app.sh format-check` passes.
- [ ] `./app.sh analyze` passes with no warnings.
- [ ] `./app.sh generate-check` proves generated Drift output is current.
- [ ] `./app.sh test` passes pure, database, and widget suites.
- [ ] `./app.sh verify` runs Linux integration tests and a release-bundle smoke test against an owned disposable data root.
- [ ] `./app.sh build` produces the native release bundle and RPM metadata/artifact.
- [ ] `./app.sh start --data-root <owned disposable root>` starts a native process with no HTTP listener, then terminates cleanly.
- [ ] Database path/application-ID guards prove the archived database cannot be opened.
- [ ] Backup integrity and JSON export schema tests pass.
- [ ] One manual GTK chooser check passes for backup and export.
- [ ] The bounded Impeccable capture, independent review, fix, and confirmation sequence is complete.
- [ ] `DESIGN.md`, `.impeccable/design.json`, and the native Work surface brief describe shipped code.
- [ ] The native plan index marks obsolete React drafts inactive; user-owned untracked drafts and committed historical specifications remain untouched.
