# Work Schedules, Part 2: Screens — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner see, adjust and confirm their rotation in LifeOS: a Calendar sheet of planned and confirmed days, a day's Properties with its actions, a Confirm worked days dialog, Schedules and Leave sheets, the schedule editor with its shift types, and the shell, desk and status integration of spec §5–§6.

**Architecture:** Part 1 shipped every command and query (`ScheduleService`, `DayPlanService`, `planDays`, `plannedPay`, `priceLeave`, the register's `leaveSheet` and `plannedNotConfirmed`). Part 2 adds a pure view model (`work_plan_view.dart`) that turns planned days and register rows into calendar words, pure widgets that render it (tested with plain data), and thin `ConsumerWidget` hosts that read the Part 1 providers and call the services — the pattern `RecordHistoryPanel` already uses — so `WorkScreen` gains only a few routing branches instead of a callback per command. Every screen opens from the route (`sheet=`, `day=`, `confirm=1`, `add=`, `record=schedule:`/`leave:`), so Back and Forward close and reopen it.

**Tech Stack:** Flutter 3.47.5, Dart, Riverpod 3, Drift 2.35 (read through Part 1 repositories only), `flutter_test` with goldens.

**Spec:** `docs/superpowers/specs/2026-10-02-work-schedules-design.md` §5–§6 (and §4.4's "N planned days not yet confirmed"). The look follows `DESIGN.md` and the memory rule that every choice reads as the 2001 desktop era (Millennium is the only style).

## Global Constraints

- Work on a new branch `feat/work-schedules-screens` cut from `feat/era-pickers` (which holds Part 1 and the editable property sheets).
- Flutter binary: `F=~/.local/opt/flutter-3.47.5/bin` (not on PATH). Tests: `$F/flutter test <path>`; analysis: `$F/flutter analyze lib test tool`; format: `$F/dart format lib test tool`; goldens: `$F/flutter test --update-goldens test/goldens/shell_goldens_test.dart`.
- Every task ends with analyze reporting "No issues found!", `$F/dart format --output=none --set-exit-if-changed lib test tool` passing and the full suite green.
- Planned shifts are derived, never stored; the screens never write planned days anywhere (spec §2).
- Every command reports the existing outcomes; field issues are worded on the field they name; nothing is retried silently (spec §7).
- Calendar and cycle text is never smaller than 11 px: use `skin.typography.body` or `figure`, never `small`, inside the calendar grid and cycle list (spec §6).
- Entries are written words with a small colour swatch; colour never carries meaning alone (spec §6.1).
- Weeks start Monday (`monthGridDays`, `eraWeekdayInitials`).
- Money is shown with `formatMoney` ("EUR 2714.40"), durations with `formatDuration` ("138:00"), clock times as `HH:mm`.
- Dialog keys: the affirmative key comes first, then **Cancel** (DESIGN.md). A record's Properties sheet uses the shell's **OK / Cancel / Apply**.
- Synthetic data only in tests and fixtures.
- Commit after every task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Changes From The Spec's Screens

The spec's §6 predates the editable Properties sheets now in DESIGN.md. Where the two differ, this plan follows DESIGN.md:

| Spec | This plan | Why |
|---|---|---|
| §6.2 Change… opens a form with Save / Cancel | Change… turns the day's General page editable in place; the sheet's OK / Apply save it, Cancel discards | "There are no separate Edit dialogs" (DESIGN.md, Properties sheet) |
| §6.2 Confirm is the default key | Confirm is an action key on General; OK stays the sheet's default | One default per sheet; Enter is OK |
| §6.4 one page of three group boxes; Save schedule | A Properties sheet with **Schedule \| Cycle \| Preview \| History** tabs (create: the same tabs without History, keys **Save schedule** / Cancel) | The agreement sheet's tabbed pattern; three group boxes do not fit a 600 px dialog |
| §6.4 Employment dropdown | Employment shown greyed | `ScheduleService.update` finds the schedule through its employment; moving it is a new schedule |
| §5 status bar *first* panel | A panel of its own after the notice panel | The first panel is now the status notice ("Shift saved.") |
| §6.3 footer "EUR 2,714.40" | "EUR 2714.40" | `formatMoney` is used everywhere else |
| Confirmed day opens "the existing shift or leave detail" | The calendar opens that shift's or leave's own Properties | Same sheet, one route per record |

## Review Focus

1. **A day confirmed elsewhere while the Confirm worked days dialog is open** (another window, or the day's own Confirm key) must show "Already confirmed" on that row and still commit every other ticked day. Test in Task 6.
2. **A night shift across the end of daylight saving** (Europe/Vilnius, 25 October 2026) must read "Night 19:00–07:00" on the calendar and count 12:30 paid, not shift an hour in the words. Test in Task 2.
3. **Apply on a schedule a confirmed day uses, then Cancel in "Use the new cycle from:"** must save nothing and keep the sheet open and dirty. Test in Task 9.
4. **A day opened by its URL where no schedule is in use, or a future day,** must say "No schedule is in use on this date." / offer no Confirm, never throw. Test in Task 5.
5. **A cycle block count of 0 or 100** must show "Enter 1 to 99." on that block's row on the Cycle tab and bring that tab forward, not a generic error. Test in Task 9.

## Left For Later

Filed as their own beads, not built here:

- **Working for a day's planned pay** (spec §6.2 "Working group box for the selected pay figure"): the day sheet states its planned pay as a fact; explaining it in Working needs an explanation of planned pay beside `work_explanations.dart`'s shift explanations.
- **"Unavailable" on calendar days** (spec §7): a day with no agreement shows "No pay agreement on this date" on its Properties and adds nothing to the month's planned pay, but its calendar cell does not say "Unavailable".

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/work/data/projections/work_register_projection.dart` | `WorkSheet` gains `calendar`, `leave`, `schedules` (spec order). |
| `lib/features/work/presentation/work_route_state.dart` | `day=`, `confirm=1`, nullable `sheet`, `schedule`/`leave` record kinds, `schedule`/`extraShift`/`leave` add kinds. |
| `lib/features/work/presentation/work_views.dart`, `lib/core/desks/saved_views.dart` | A saved view for the Leave sheet; Calendar and Schedules are not saved as views. |
| `lib/features/work/application/{schedule_service,day_plan_service}.dart` | `watch`, `watchInputs`, `watchDaysToConfirm`. |
| `lib/features/work/presentation/work_controller.dart` | `employmentSchedulesProvider`, `planInputsProvider`, `zoneClocksProvider`; `daysToConfirmProvider` becomes a stream. |
| `lib/features/work/presentation/work_plan_view.dart` (new) | Pure: `DayEntry`, `DayView`, `dayViews`, `MonthTotals`, `monthTotals`, `plannedLeavePay`, `defaultSheetFor`, wording helpers. |
| `lib/features/work/presentation/work_calendar.dart` (new) | Pure `WorkCalendar` month grid. |
| `lib/features/work/presentation/work_calendar_sheet.dart` (new) | `WorkCalendarSheet` host: month header, plan stream, totals line. |
| `lib/features/work/presentation/day_sheet.dart` (new) | Pure `DaySheet`, `DayTimes`, `DayTimesForm`, `askCancelShift`, `askLeave`, outcome wording. |
| `lib/features/work/presentation/day_sheet_host.dart` (new) | `DaySheetHost` and `AddDayHost` (quick add Extra shift… / Leave…). |
| `lib/features/work/presentation/confirm_days_dialog.dart` (new) | Pure `ConfirmDaysDialog`, `ConfirmRow`, `confirmProblem`; `ConfirmDaysHost`. |
| `lib/features/work/data/projections/work_record_projection.dart`, `lib/features/work/data/work_repository.dart` | `LeaveRecordProjection`, loaded by `watchRecord`. |
| `lib/features/work/presentation/leave_sheet.dart` (new) | `LeaveSheet` list and `LeavePropertiesSheet` with Correct…. |
| `lib/features/work/presentation/schedules_sheet.dart` (new) | Pure `SchedulesSheet`; `SchedulesSheetHost`. |
| `lib/features/work/presentation/shift_types_dialog.dart` (new) | `editShiftTypes`, `editShiftType` dialogs. |
| `lib/features/work/presentation/schedule_editor.dart` (new) | Pure `ScheduleEditor` (tabs), `askNewVersionFrom`, error wording. |
| `lib/features/work/presentation/schedule_sheet_host.dart` (new) | `ScheduleSheetHost`: create, update, delete through `ScheduleService`. |
| `lib/features/work/presentation/{work_screen,work_register,work_tasks,work_toolbar_controls,work_record_names,work_desk_tiles}.dart` | Routing branches, task links, labels, desk tiles. |
| `lib/app/{app_router,shell_host,desk_host}.dart`, `lib/shared/shell/{book_tree,status_line}.dart`, `lib/core/desks/desks.dart` | Books sub-sheets and badge, status panel, quick add, desks. |
| `test/support/synthetic_shell.dart`, `test/goldens/shell_goldens_test.dart` | A seeded schedule for the new goldens. |

---
### Task 1: Routes for the new sheets and dialogs

Spec §5 (View dropdown, default sheet), §6. Pure routing; no screen yet.

**Files:**
- Modify: `lib/features/work/data/projections/work_register_projection.dart:47`
- Modify: `lib/features/work/presentation/work_route_state.dart`
- Modify: `lib/features/work/presentation/work_views.dart`
- Modify: `lib/features/work/presentation/work_toolbar_controls.dart:365-392` (`SheetPicker`)
- Modify: `lib/features/work/presentation/work_register.dart:122-160`
- Modify: `lib/app/app_router.dart:102-107,225-235`
- Modify: `lib/app/desk_host.dart:455-484`
- Test: `test/features/work/presentation/work_route_state_test.dart`, `test/features/work/presentation/work_views_test.dart`

**Interfaces:**
- Produces:
  - `enum WorkSheet { calendar, shifts, leave, schedules, periods, payslips, agreements }`
  - `WorkRouteState.sheet` is `WorkSheet?`; null means "the employment's default" (Task 4 resolves it). `copyWith(sheet: WorkSheet?)` still means "keep when null".
  - `WorkRouteState.day` (`LocalDate?`, URL `day=YYYY-MM-DD`) and `WorkRouteState.confirming` (`bool`, URL `confirm=1`); `copyWith(day: LocalDate? Function()?, confirming: bool?)`.
  - `WorkRecordKind.schedule` (`record=schedule:<ScheduleId>`) and `WorkRecordKind.leave` (`record=leave:<LeaveRecordId>`).
  - `WorkAddKind.schedule`, `WorkAddKind.extraShift`, `WorkAddKind.leave`.
  - `ViewShape? workViewShape(WorkRouteState route)` — null for a sheet that cannot be saved as a view (calendar, leave, schedules until Task 7 adds leave).
  - `SheetPicker.labels` lists all seven sheets in spec order; `app_router.dart` uses it instead of its own `_sheetLabels`.

- [ ] **Step 1: Failing tests**

Replace the test "Shifts and hidden void rows are the defaults and stay implicit" in `test/features/work/presentation/work_route_state_test.dart` and append the new tests inside `main()`:

```dart
  test('no sheet is the default and stays implicit', () {
    final parsed = (parseWorkRoute(
      Uri.parse('/work?employment=${employment.value}'),
    ) as ValidWorkRoute).state;
    expect(parsed.sheet, isNull);
    expect(parsed.showVoid, isFalse);
    expect(workRouteUri(parsed).query, isNot(contains('sheet')));
  });

  test('an explicit Shifts sheet is kept in the address', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      sheet: WorkSheet.shifts,
    );
    expect(workRouteUri(state).query, contains('sheet=shifts'));
  });

  test('the calendar, leave and schedules sheets round-trip', () {
    for (final sheet in [
      WorkSheet.calendar,
      WorkSheet.leave,
      WorkSheet.schedules,
    ]) {
      final state = WorkRouteState(
        employmentId: employment,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
        sheet: sheet,
      );
      final parsed = (parseWorkRoute(workRouteUri(state)) as ValidWorkRoute)
          .state;
      expect(parsed.sheet, sheet);
    }
  });

  test('a day opens as properties and round-trips', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.properties,
      sheet: WorkSheet.calendar,
      day: LocalDate(2026, 10, 7),
    );
    final uri = workRouteUri(state);
    expect(uri.query, contains('day=2026-10-07'));
    final parsed = (parseWorkRoute(uri) as ValidWorkRoute).state;
    expect(parsed.day, const LocalDate(2026, 10, 7));
    expect(parsed.mode, WorkInspectorMode.properties);
  });

  test('a malformed day is an invalid scope', () {
    final result = parseWorkRoute(Uri.parse('/work?day=2026-13-40'));
    expect(
      (result as InvalidWorkRoute).reason,
      WorkRouteProblem.malformedScope,
    );
  });

  test('confirm=1 opens the confirm dialog; any other value is invalid', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      confirming: true,
    );
    final uri = workRouteUri(state);
    expect(uri.query, contains('confirm=1'));
    expect((parseWorkRoute(uri) as ValidWorkRoute).state.confirming, isTrue);
    expect(parseWorkRoute(Uri.parse('/work?confirm=yes')), isA<InvalidWorkRoute>());
  });

  test('schedule and leave records parse with their own ids', () {
    final schedule = WorkRecordRef.tryParse(
      'schedule:018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61',
    )!;
    expect(schedule.kind, WorkRecordKind.schedule);
    expect(schedule.id, isA<ScheduleId>());
    final leave = WorkRecordRef.tryParse(
      'leave:018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c71',
    )!;
    expect(leave.kind, WorkRecordKind.leave);
    expect(leave.id, isA<LeaveRecordId>());
  });

  test('the new add kinds round-trip', () {
    for (final adding in [
      WorkAddKind.schedule,
      WorkAddKind.extraShift,
      WorkAddKind.leave,
    ]) {
      final state = WorkRouteState(
        employmentId: employment,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
        adding: adding,
      );
      expect(
        (parseWorkRoute(workRouteUri(state)) as ValidWorkRoute).state.adding,
        adding,
      );
    }
  });
```

Add `import 'package:lifeos/core/time/local_date.dart';` to that file's imports.

In `test/features/work/presentation/work_views_test.dart`, give the second route of "a Work route saves as a valid shape and reopens identically" an explicit `sheet: WorkSheet.shifts` (a saved view names its sheet), and append:

```dart
  test('a default route saves as a Shifts view', () {
    const route = WorkRouteState(
      employmentId: _employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
    );
    expect(workViewShape(route)!.sheetRef, ViewSheets.workShifts);
  });

  test('the calendar and schedules sheets are not saved as views', () {
    for (final sheet in [WorkSheet.calendar, WorkSheet.schedules]) {
      expect(
        workViewShape(
          WorkRouteState(
            employmentId: _employment,
            scope: null,
            record: null,
            mode: WorkInspectorMode.inspect,
            sheet: sheet,
          ),
        ),
        isNull,
      );
    }
  });
```

Every other `workViewShape(...)` call in that file becomes `workViewShape(...)!`.

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/work_route_state_test.dart test/features/work/presentation/work_views_test.dart`
Expected: compile errors (`WorkSheet.calendar`, `day`, `confirming`, `WorkRecordKind.schedule` not defined).

- [ ] **Step 3: Sheets and record kinds**

`lib/features/work/data/projections/work_register_projection.dart:47`:

```dart
/// The sheets an employment's Work desk shows, in the Books tree's order
/// (schedules spec 5).
enum WorkSheet {
  calendar,
  shifts,
  leave,
  schedules,
  periods,
  payslips,
  agreements,
}
```

In `lib/features/work/presentation/work_route_state.dart`:

```dart
/// A create form opened by route, for example from + Add.
enum WorkAddKind { payPeriod, payslip, agreement, schedule, extraShift, leave }

enum WorkRecordKind {
  employment,
  agreement,
  shift,
  shiftBreak,
  payPeriod,
  payslip,
  schedule,
  leave,
}
```

and in `WorkRecordRef.tryParse`, before `_ => null`:

```dart
      'schedule' => _record(
        WorkRecordKind.schedule,
        ScheduleId.tryParse(idText),
      ),
      'leave' => _record(WorkRecordKind.leave, LeaveRecordId.tryParse(idText)),
```

- [ ] **Step 4: Route state fields**

Replace the `WorkRouteState` class with:

```dart
final class WorkRouteState {
  const WorkRouteState({
    required this.employmentId,
    required this.scope,
    required this.record,
    required this.mode,
    this.sheet,
    this.showVoid = false,
    this.adding,
    this.fromLast = false,
    this.day,
    this.confirming = false,
  });

  final EmploymentId? employmentId;
  final WorkTemporalScope? scope;
  final WorkRecordRef? record;
  final WorkInspectorMode mode;

  /// The sheet on the desk; null shows the employment's default, Calendar
  /// when a schedule is in use today, otherwise Shifts (schedules spec 5).
  final WorkSheet? sheet;

  /// Whether voided rows are listed; they are hidden by default.
  final bool showVoid;

  /// The create form the inspector shows, when opened by route.
  final WorkAddKind? adding;

  /// Whether the manual shift form is prefilled from the last shift.
  final bool fromLast;

  /// A planned day whose Properties are open (schedules spec 6.2).
  final LocalDate? day;

  /// Whether the Confirm worked days dialog is open (spec 6.3).
  final bool confirming;

  WorkRouteState copyWith({
    WorkTemporalScope? Function()? scope,
    WorkRecordRef? Function()? record,
    WorkInspectorMode? mode,
    WorkSheet? sheet,
    bool? showVoid,
    WorkAddKind? Function()? adding,
    bool? fromLast,
    LocalDate? Function()? day,
    bool? confirming,
  }) => WorkRouteState(
    employmentId: employmentId,
    scope: scope == null ? this.scope : scope(),
    record: record == null ? this.record : record(),
    mode: mode ?? this.mode,
    sheet: sheet ?? this.sheet,
    showVoid: showVoid ?? this.showVoid,
    adding: adding == null ? this.adding : adding(),
    fromLast: fromLast ?? this.fromLast,
    day: day == null ? this.day : day(),
    confirming: confirming ?? this.confirming,
  );
}
```

In `workRouteUri`, replace the sheet line and add the two parameters before the record:

```dart
  if (state.sheet case final sheet?) parameters.add('sheet=${sheet.name}');
  if (state.showVoid) parameters.add('void=1');
  if (state.adding case final adding?) parameters.add('add=${adding.name}');
  if (state.fromLast) parameters.add('template=last');
  if (state.day case final day?) parameters.add('day=$day');
  if (state.confirming) parameters.add('confirm=1');
```

In `parseWorkRoute`, parse the sheet as nullable and read the two new parameters:

```dart
  final sheetText = uri.queryParameters['sheet'];
  final sheet = sheetText == null
      ? null
      : WorkSheet.values.where((value) => value.name == sheetText).firstOrNull;
  final dayText = uri.queryParameters['day'];
  final day = dayText == null ? null : LocalDate.tryParse(dayText);
  final confirmText = uri.queryParameters['confirm'];
```

extend the refusal condition to

```dart
  if ((sheetText != null && sheet == null) ||
      (dayText != null && day == null) ||
      (confirmText != null && confirmText != '1') ||
      (voidText != null && voidText != '1') ||
      (addText != null && adding == null) ||
      (templateText != null && templateText != 'last')) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedScope);
  }
```

and pass `day: day, confirming: confirmText == '1'` to the returned `WorkRouteState`.

- [ ] **Step 5: Saved views, the View combo and the other sheet switches**

`lib/features/work/presentation/work_views.dart`:

```dart
const _sheets = {
  WorkSheet.shifts: ViewSheets.workShifts,
  WorkSheet.periods: ViewSheets.workPeriods,
  WorkSheet.payslips: ViewSheets.workPayslips,
  WorkSheet.agreements: ViewSheets.workAgreements,
};

/// What Save as view stores for a Work route: the sheet and its structural
/// filters, or null for a sheet that is not saved as a view. The open
/// record, form and mode are not part of a view.
ViewShape? workViewShape(WorkRouteState route) {
  final sheetRef = _sheets[route.sheet ?? WorkSheet.shifts];
  if (sheetRef == null) return null;
  return ViewShape(
    sheetRef: sheetRef,
    filters: {
      if (route.employmentId case final employment?)
        'employment': employment.value,
      ...switch (route.scope) {
        PayPeriodScope(:final periodId) => {'period': periodId.value},
        DateRangeScope(:final start, :final end) => {
          'from': '$start',
          'to': '$end',
        },
        null => const <String, String>{},
      },
      if (route.showVoid) 'void': '1',
    },
  );
}
```

`SheetPicker` (`work_toolbar_controls.dart`): `sheet` becomes the shown sheet (non-null, the caller resolves the default) and the labels list every sheet:

```dart
  static const labels = {
    WorkSheet.calendar: 'Calendar',
    WorkSheet.shifts: 'Shifts',
    WorkSheet.leave: 'Leave',
    WorkSheet.schedules: 'Schedules',
    WorkSheet.periods: 'Pay periods',
    WorkSheet.payslips: 'Payslips',
    WorkSheet.agreements: 'Agreements',
  };
```

`lib/app/app_router.dart`: delete `_sheetLabels`, import `work_toolbar_controls.dart`, and change the Save view handler to

```dart
          final views => (route) async {
            final shape = workViewShape(route);
            if (shape == null) return;
            final name = await askForName(
              context,
              title: 'Save view',
              action: 'Save',
              initial:
                  '${SheetPicker.labels[route.sheet ?? WorkSheet.shifts]} view',
            );
            if (name != null && name.trim().isNotEmpty) {
              await views.createView(name, shape);
            }
          },
```

`lib/app/desk_host.dart:457`: switch on `state.sheet ?? WorkSheet.shifts` and add, after the agreements case,

```dart
      // Never saved as views (work_views.dart).
      WorkSheet.calendar || WorkSheet.leave || WorkSheet.schedules =>
        const TileList(lines: [], empty: 'This view is not available.'),
```

`lib/features/work/presentation/work_register.dart`: until Task 4 resolves the default, compute `final shown = route.sheet ?? WorkSheet.shifts;`, switch on `shown`, pass `sheet: shown` to `SheetPicker`, and add a placeholder case for the three new sheets that Tasks 4, 7 and 8 replace:

```dart
      WorkSheet.calendar || WorkSheet.leave || WorkSheet.schedules =>
        const OperationalState(
          kind: OperationalStateKind.empty,
          title: 'Not built yet',
          message: 'This sheet arrives with the schedule screens.',
        ),
```

Run `grep -rn "WorkSheet\.\|workViewShape(" lib test` and fix any remaining exhaustive switch or non-null use the analyzer reports the same way.

- [ ] **Step 6: Run the tests**

Run: `$F/flutter analyze lib test tool && $F/flutter test test/features/work/presentation/work_route_state_test.dart test/features/work/presentation/work_views_test.dart`
Expected: "No issues found!"; all pass.

- [ ] **Step 7: Full suite, format, commit**

Run: `$F/dart format lib test tool && $F/flutter test`
Expected: all pass.

```bash
git add -A lib test
git commit -m "feat: route the calendar, leave and schedule sheets, days and confirming

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Live plan providers and the calendar view model

Spec §6.1 (entry words, month status line), §5 (default sheet). Pure functions and providers; no widget yet.

**Files:**
- Modify: `lib/features/work/application/schedule_service.dart`
- Modify: `lib/features/work/application/day_plan_service.dart`
- Modify: `lib/features/work/presentation/work_controller.dart`
- Create: `lib/features/work/presentation/work_plan_view.dart`
- Test: `test/features/work/application/day_plan_watch_test.dart` (create), `test/support/schedule_views.dart` (create), `test/features/work/presentation/work_plan_view_test.dart` (create)

**Interfaces:**
- Consumes: `planDays`, `PlannedDay` and its kinds, `plannedPay` (`planner.dart`); `priceLeave`, `LeaveRecord`, `LeavePay`, `WorkedPay` (`leave.dart`); `resolveAgreement` (`agreement.dart`); `ShiftSheetRow`, `LeaveSheetRow`, `WorkSheet` (Task 1).
- Produces:
  - `ScheduleService.watch(EmploymentId) → Stream<List<WorkSchedule>>`
  - `DayPlanService.watchInputs(EmploymentId) → Stream<PlanInputs>`; `DayPlanService.watchDaysToConfirm(EmploymentId, {required LocalDate today}) → Stream<List<PlannedDay>>`
  - Providers: `employmentSchedulesProvider` (`StreamProvider.autoDispose.family<List<WorkSchedule>, EmploymentId>`), `planInputsProvider` (`StreamProvider.autoDispose.family<PlanInputs, EmploymentId>`), `zoneClocksProvider` (`Provider<ZoneClocks>`); `daysToConfirmProvider` becomes `StreamProvider.autoDispose.family<List<PlannedDay>, EmploymentId>`.
  - `enum DayEntryKind { planned, confirmed, changed, cancelled, leave, extra, needsReview }`
  - `final class DayEntry { DayEntryKind kind; String text; String? struck; bool confirmed; }`
  - `final class DayView { LocalDate date; List<DayEntry> entries; PlannedDay? planned; List<ShiftSheetRow> shifts; LeaveSheetRow? leave; bool get confirmed; }`
  - `Map<LocalDate, DayView> dayViews({required LocalDate from, required LocalDate to, required List<PlannedDay> plan, required List<ShiftSheetRow> shifts, required List<LeaveSheetRow> leave, required List<WorkSchedule> schedules, required TimezoneService timezones})`
  - `final class MonthTotals { int shifts; int paidSeconds; Money planned; Money confirmed; }`; `MonthTotals monthTotals(Iterable<DayView> days, {required ExpectedPay? Function(PlannedShift) price})`
  - `LeavePay? plannedLeavePay(PlannedLeave day, {required EmploymentId employmentId, required List<PayAgreement> agreements, required List<ShiftSheetRow> shifts, required List<LeaveSheetRow> leave})`
  - `WorkSheet defaultSheetFor(List<WorkSchedule> schedules, LocalDate today)`
  - `String shiftTimes(DateTime startUtc, DateTime endUtc, String zone, TimezoneService timezones)` → `"07:00–19:00"`; `String cancelReasonLabel(CancelReason)`; `String leaveTypeLabel(LeaveType)`; `String plannedShiftName(PlannedShift)` (`"Extra"`, the type's name, or `"Shift"`).

- [ ] **Step 1: Failing service test**

`test/features/work/application/day_plan_watch_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  test('days to confirm update live when a day is confirmed', () async {
    final fixture = await ScheduleFixture.create();
    addTearDown(fixture.dispose);
    await fixture.saveDepot();
    final lengths = <int>[];
    final subscription = fixture.plans
        .watchDaysToConfirm(
          fixtureEmployment,
          today: const LocalDate(2026, 12, 1),
        )
        .listen((days) => lengths.add(days.length));
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 5 October to 30 November: four 12-day cycles and 9 days more.
    expect(lengths.last, 30);
    await fixture.plans.confirm(fixtureEmployment, const LocalDate(2026, 10, 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(lengths.last, 29);
  });

  test('schedules are watched per employment', () async {
    final fixture = await ScheduleFixture.create();
    addTearDown(fixture.dispose);
    final first = fixture.schedules.watch(fixtureEmployment).first;
    expect(await first, isEmpty);
    await fixture.saveDepot();
    expect(
      (await fixture.schedules.watch(fixtureEmployment).first).single.name,
      'Depot rotation',
    );
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `$F/flutter test test/features/work/application/day_plan_watch_test.dart`
Expected: compile errors: `watchDaysToConfirm` and `watch` are not defined.

- [ ] **Step 3: Implement the service streams**

`schedule_service.dart`, in `ScheduleService` after `create`:

```dart
  /// Every version of every schedule of the employment, live.
  Stream<List<WorkSchedule>> watch(EmploymentId id) =>
      repository.watchSchedules(id);
```

`day_plan_service.dart`: replace `daysToConfirm` with

```dart
  /// What the planner reads for one employment, live.
  Stream<PlanInputs> watchInputs(EmploymentId id) =>
      repository.watchPlanInputs(id);

  /// Past planned shifts and leave not yet confirmed, oldest first: from the
  /// first date any schedule is in use up to the day before [today].
  Future<List<PlannedDay>> daysToConfirm(
    EmploymentId id, {
    required LocalDate today,
  }) async => _toConfirm(await repository.planInputs(id), today);

  /// [daysToConfirm], live: a day leaves the list once it is confirmed.
  Stream<List<PlannedDay>> watchDaysToConfirm(
    EmploymentId id, {
    required LocalDate today,
  }) => repository
      .watchPlanInputs(id)
      .map((inputs) => _toConfirm(inputs, today));

  List<PlannedDay> _toConfirm(PlanInputs inputs, LocalDate today) {
    if (inputs.schedules.isEmpty) return const [];
    final from = inputs.schedules
        .map((value) => value.inUseFrom)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final to = today.addDays(-1);
    if (from.compareTo(to) > 0) return const [];
    return [
      for (final day in _plan(inputs, from, to))
        if (day is PlannedShift || day is PlannedLeave) day,
    ];
  }
```

- [ ] **Step 4: Run it to see it pass**

Run: `$F/flutter test test/features/work/application/day_plan_watch_test.dart test/features/work/application/day_plan_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Providers**

In `work_controller.dart` (add imports `../../../core/time/wall_clock.dart`, `../domain/pay_premiums.dart`, `../domain/schedule.dart`), replace `daysToConfirmProvider` and add the three providers after `dayPlanServiceProvider`:

```dart
/// Every schedule version of one employment, live.
final employmentSchedulesProvider = StreamProvider.autoDispose
    .family<List<WorkSchedule>, EmploymentId>(
      (ref, id) => ref.watch(scheduleServiceProvider).watch(id),
    );

/// Schedules, exceptions, confirmed dates and agreements of one employment,
/// live; a day's Properties read their date from it.
final planInputsProvider = StreamProvider.autoDispose
    .family<PlanInputs, EmploymentId>(
      (ref, id) => ref.watch(dayPlanServiceProvider).watchInputs(id),
    );

/// Wall clocks for planned times and planned pay.
final zoneClocksProvider = Provider<ZoneClocks>(
  (ref) => zoneClocksOf(ref.watch(timezoneServiceProvider)),
);

/// Past planned days of one employment not yet confirmed, live.
final daysToConfirmProvider = StreamProvider.autoDispose
    .family<List<PlannedDay>, EmploymentId>(
      (ref, id) => ref
          .watch(dayPlanServiceProvider)
          .watchDaysToConfirm(id, today: ref.watch(todayProvider)()),
    );
```

- [ ] **Step 6: Failing view-model tests**

`test/support/schedule_views.dart` (shared with Tasks 3–5):

```dart
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_plan_view.dart';

import 'schedule_fixture.dart';
import 'zone_clocks.dart';

const depotScheduleId = ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
final testTimezones = IanaTimezoneService();

/// The 3 Day / 3 Off / 3 Night / 3 Off rotation from 5 October 2026, as a
/// stored version 1.
WorkSchedule depotSchedule() {
  final draft = depotDraft();
  return WorkSchedule(
    id: depotScheduleId,
    employmentId: fixtureEmployment,
    name: draft.name,
    timezoneId: draft.timezoneId,
    version: 1,
    cycleStart: draft.cycleStart,
    inUseFrom: draft.inUseFrom,
    inUseUntil: null,
    shiftTypes: draft.shiftTypes,
    blocks: draft.blocks,
    createdAtUtc: DateTime.utc(2026, 10, 1),
    revision: const Revision(0),
  );
}

/// October 2026 planned from [depotSchedule].
List<PlannedDay> octoberPlan({
  List<DayException> exceptions = const [],
  Set<LocalDate> confirmed = const {},
}) => planDays(
  from: const LocalDate(2026, 10, 1),
  to: const LocalDate(2026, 10, 31),
  schedules: [depotSchedule()],
  exceptions: exceptions,
  confirmedDates: confirmed,
  zoneClocks: testZoneClocks,
);

/// October 2026's calendar days.
Map<LocalDate, DayView> octoberViews(
  List<PlannedDay> plan, {
  List<ShiftSheetRow> shifts = const [],
}) => dayViews(
  from: const LocalDate(2026, 10, 1),
  to: const LocalDate(2026, 10, 31),
  plan: plan,
  shifts: shifts,
  leave: const [],
  schedules: [depotSchedule()],
  timezones: testTimezones,
);

/// A finalized Day shift on [date], confirmed from [depotSchedule].
ShiftSheetRow confirmedDayRow(LocalDate date) {
  // 07:00–19:00 Europe/Vilnius in summer time (UTC+3).
  final start = DateTime.utc(date.year, date.month, date.day, 4);
  final end = DateTime.utc(date.year, date.month, date.day, 16);
  return ShiftSheetRow(
    shift: WorkShift(
      id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c81'),
      employmentId: fixtureEmployment,
      agreementId: fixtureAgreement,
      state: ShiftState.finalized,
      startUtc: start,
      endUtc: end,
      timezoneId: 'Europe/Vilnius',
      localStartDate: date,
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: DateTime.utc(2026, 10, 1),
      updatedAtUtc: DateTime.utc(2026, 10, 1),
      revision: const Revision(1),
      schedule: ScheduleLink(
        scheduleId: depotScheduleId,
        scheduleVersion: 1,
        plannedDate: date,
        plannedStartUtc: start,
        plannedEndUtc: end,
      ),
    ),
    breakSeconds: 1800,
    paidSeconds: 41400,
    period: null,
  );
}
```

`test/features/work/presentation/work_plan_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/presentation/work_plan_view.dart';

import '../../../support/schedule_fixture.dart';
import '../../../support/schedule_views.dart';

void main() {
  test('a planned day reads its type and wall-clock times', () {
    final views = octoberViews(octoberPlan());
    final entry = views[const LocalDate(2026, 10, 5)]!.entries.single;
    expect(entry.kind, DayEntryKind.planned);
    expect(entry.text, 'Day 07:00–19:00');
    expect(entry.confirmed, isFalse);
  });

  test('an Off day has no entry', () {
    expect(octoberViews(octoberPlan())[const LocalDate(2026, 10, 8)]!.entries, isEmpty);
  });

  test('the night daylight saving ends reads 19:00–07:00, 12:30 paid', () {
    final views = octoberViews(octoberPlan());
    final night = views[const LocalDate(2026, 10, 24)]!;
    expect(night.entries.single.text, 'Night 19:00–07:00');
    expect((night.planned! as PlannedShift).paidSeconds, 12 * 3600 + 1800);
  });

  test('a cancelled day strikes its type and writes the reason', () {
    final views = octoberViews(
      octoberPlan(
        exceptions: [
          CancelledDay(
            id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c91'),
            employmentId: fixtureEmployment,
            date: const LocalDate(2026, 10, 6),
            reason: CancelReason.swapped,
            note: null,
            createdAtUtc: DateTime.utc(2026, 10, 1),
            updatedAtUtc: DateTime.utc(2026, 10, 1),
            revision: const Revision(0),
          ),
        ],
      ),
    );
    final entry = views[const LocalDate(2026, 10, 6)]!.entries.single;
    expect(entry.kind, DayEntryKind.cancelled);
    expect(entry.struck, 'Day');
    expect(entry.text, 'Cancelled · Swapped');
  });

  test('a confirmed day reads like its plan, filled', () {
    const date = LocalDate(2026, 10, 7);
    final views = octoberViews(
      octoberPlan(confirmed: {date}),
      shifts: [confirmedDayRow(date)],
    );
    final day = views[date]!;
    expect(day.confirmed, isTrue);
    expect(day.planned, isNull);
    final entry = day.entries.single;
    expect(entry.kind, DayEntryKind.confirmed);
    expect(entry.text, 'Day 07:00–19:00');
    expect(entry.confirmed, isTrue);
  });

  test('month totals count planned and confirmed shifts apart', () {
    const date = LocalDate(2026, 10, 7);
    final views = octoberViews(
      octoberPlan(confirmed: {date}),
      shifts: [confirmedDayRow(date)],
    );
    final totals = monthTotals(
      views.values,
      price: (_) => null,
    );
    // October from the 5th: 15 shifts, one of them confirmed.
    expect(totals.shifts, 15);
    expect(totals.planned, const Money(minorUnits: 0));
  });

  test('Calendar is the default sheet while a schedule is in use today', () {
    expect(
      defaultSheetFor([depotSchedule()], const LocalDate(2026, 10, 7)),
      WorkSheet.calendar,
    );
    expect(
      defaultSheetFor([depotSchedule()], const LocalDate(2026, 10, 1)),
      WorkSheet.shifts,
    );
    expect(defaultSheetFor(const [], const LocalDate(2026, 10, 7)), WorkSheet.shifts);
  });
}
```

(15: Day 5–7, Night 11–13, Day 17–19, Night 23–25, Day 29–31 in October.)

- [ ] **Step 7: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/work_plan_view_test.dart`
Expected: compile error: `work_plan_view.dart` does not exist.

- [ ] **Step 8: Implement the view model**

`lib/features/work/presentation/work_plan_view.dart`:

```dart
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/day_exception.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import '../domain/shift.dart';

/// What a calendar entry stands for (schedules spec 6.1).
enum DayEntryKind {
  planned,
  confirmed,
  changed,
  cancelled,
  leave,
  extra,
  needsReview,
}

/// One written entry in a calendar cell, such as "Day 07:00–19:00".
final class DayEntry {
  const DayEntry(this.kind, this.text, {this.struck, this.confirmed = false});

  final DayEntryKind kind;
  final String text;

  /// A cancelled shift's type name, drawn struck through before [text].
  final String? struck;

  /// Confirmed entries have a filled swatch; planned ones an outline.
  final bool confirmed;

  /// The entry as one phrase, for screen readers and tests.
  String get spoken => struck == null ? text : '$struck $text';
}

/// One date of the calendar: what the plan and the records hold on it.
final class DayView {
  const DayView({
    required this.date,
    required this.entries,
    this.planned,
    this.shifts = const [],
    this.leave,
  });

  final LocalDate date;
  final List<DayEntry> entries;

  /// What the plan holds; null once the date is confirmed or when no
  /// schedule is in use on it.
  final PlannedDay? planned;

  /// Shifts recorded on this date, voided ones left out.
  final List<ShiftSheetRow> shifts;

  /// Effective leave on this date.
  final LeaveSheetRow? leave;

  bool get confirmed => shifts.isNotEmpty || leave != null;
}

/// "07:00–19:00" on the shift's own wall clock.
String shiftTimes(
  DateTime startUtc,
  DateTime endUtc,
  String zone,
  TimezoneService timezones,
) =>
    '${_clock(startUtc, zone, timezones)}–${_clock(endUtc, zone, timezones)}';

String _clock(DateTime utc, String zone, TimezoneService timezones) =>
    timezones.localTimeAt(utc, zone).toString().substring(0, 5);

String cancelReasonLabel(CancelReason reason) => switch (reason) {
  CancelReason.swapped => 'Swapped',
  CancelReason.dayOff => 'Day off',
  CancelReason.other => 'Other',
};

String leaveTypeLabel(LeaveType type) => switch (type) {
  LeaveType.vacation => 'Vacation',
  LeaveType.sick => 'Sick',
};

/// "Extra", the shift type's name, or "Shift" for custom times.
String plannedShiftName(PlannedShift shift) =>
    shift.isExtra ? 'Extra' : shift.type?.name ?? 'Shift';

/// Calendar when a schedule is in use on [today], otherwise Shifts.
WorkSheet defaultSheetFor(List<WorkSchedule> schedules, LocalDate today) =>
    schedules.any((value) => value.isInUseOn(today))
    ? WorkSheet.calendar
    : WorkSheet.shifts;

/// Every date [from]..[to] with its entries: the plan's days, then the
/// shifts and leave recorded on dates the plan no longer holds.
Map<LocalDate, DayView> dayViews({
  required LocalDate from,
  required LocalDate to,
  required List<PlannedDay> plan,
  required List<ShiftSheetRow> shifts,
  required List<LeaveSheetRow> leave,
  required List<WorkSchedule> schedules,
  required TimezoneService timezones,
}) {
  bool inRange(LocalDate date) =>
      date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
  final planned = {
    for (final day in plan)
      if (inRange(day.date)) day.date: day,
  };
  final shiftsOn = <LocalDate, List<ShiftSheetRow>>{};
  for (final row in shifts) {
    if (row.shift.state == ShiftState.voided) continue;
    final date = row.shift.schedule?.plannedDate ?? row.shift.localStartDate;
    if (inRange(date)) shiftsOn.putIfAbsent(date, () => []).add(row);
  }
  final leaveOn = {
    for (final row in leave)
      if (row.record.isEffective && inRange(row.record.date))
        row.record.date: row,
  };

  String shiftName(WorkShift shift) {
    final link = shift.schedule;
    if (link == null) return 'Shift';
    if (link.isExtra) return 'Extra';
    return schedules
            .where(
              (value) =>
                  value.id == link.scheduleId &&
                  value.version == link.scheduleVersion,
            )
            .firstOrNull
            ?.shiftTypeOn(link.plannedDate)
            ?.name ??
        'Shift';
  }

  DayEntry plannedEntry(PlannedShift shift) {
    final times = shiftTimes(
      shift.startUtc,
      shift.endUtc,
      shift.timezoneId,
      timezones,
    );
    if (shift.isExtra) return DayEntry(DayEntryKind.extra, 'Extra $times');
    final name = plannedShiftName(shift);
    return shift.changed
        ? DayEntry(DayEntryKind.changed, '$name $times changed')
        : DayEntry(DayEntryKind.planned, '$name $times');
  }

  final views = <LocalDate, DayView>{};
  for (var date = from; date.compareTo(to) <= 0; date = date.addDays(1)) {
    final day = planned[date];
    final recorded = shiftsOn[date] ?? const <ShiftSheetRow>[];
    final leaveRow = leaveOn[date];
    final entries = <DayEntry>[
      ...switch (day) {
        PlannedShift() => [plannedEntry(day)],
        CancelledPlan(:final reason, :final replaced) => [
          DayEntry(
            DayEntryKind.cancelled,
            'Cancelled · ${cancelReasonLabel(reason)}',
            struck: plannedShiftName(replaced),
          ),
        ],
        PlannedLeave(:final leaveType) => [
          DayEntry(DayEntryKind.leave, leaveTypeLabel(leaveType)),
        ],
        NeedsReview() => [
          const DayEntry(DayEntryKind.needsReview, 'Needs review'),
        ],
        OffDay() || null => const <DayEntry>[],
      },
      for (final row in recorded)
        DayEntry(
          row.shift.schedule?.isExtra ?? false
              ? DayEntryKind.extra
              : DayEntryKind.confirmed,
          [
            shiftName(row.shift),
            if (row.shift.endUtc case final end?)
              shiftTimes(
                row.shift.startUtc,
                end,
                row.shift.timezoneId,
                timezones,
              ),
            if (row.shift.state == ShiftState.draft) '· Draft',
          ].join(' '),
          confirmed: true,
        ),
      if (leaveRow != null)
        DayEntry(
          DayEntryKind.leave,
          leaveTypeLabel(leaveRow.record.leaveType),
          confirmed: true,
        ),
    ];
    views[date] = DayView(
      date: date,
      entries: entries,
      planned: day,
      shifts: recorded,
      leave: leaveRow,
    );
  }
  return views;
}

/// A month's figures for the line under the calendar (spec 6.1).
final class MonthTotals {
  const MonthTotals({
    required this.shifts,
    required this.paidSeconds,
    required this.planned,
    required this.confirmed,
  });

  /// Planned and confirmed shifts together.
  final int shifts;
  final int paidSeconds;

  /// Expected pay of the shifts still planned.
  final Money planned;

  /// Expected pay of finalized shifts and confirmed leave.
  final Money confirmed;
}

MonthTotals monthTotals(
  Iterable<DayView> days, {
  required ExpectedPay? Function(PlannedShift shift) price,
}) {
  var shifts = 0;
  var paid = 0;
  var planned = 0;
  var confirmed = 0;
  for (final day in days) {
    if (day.planned case final PlannedShift shift) {
      shifts++;
      paid += shift.paidSeconds;
      planned += price(shift)?.amount.minorUnits ?? 0;
    }
    for (final row in day.shifts) {
      if (row.shift.state != ShiftState.finalized) continue;
      shifts++;
      paid += row.paidSeconds ?? 0;
      confirmed += row.pay?.amount.minorUnits ?? 0;
    }
    confirmed += day.leave?.pay?.amount.minorUnits ?? 0;
  }
  return MonthTotals(
    shifts: shifts,
    paidSeconds: paid,
    planned: Money(minorUnits: planned),
    confirmed: Money(minorUnits: confirmed),
  );
}

/// What [day] would pay once confirmed, from the employment's confirmed
/// work and leave; null when no agreement covers its date. A sick day
/// without an illness start is priced as the illness's first day.
LeavePay? plannedLeavePay(
  PlannedLeave day, {
  required EmploymentId employmentId,
  required List<PayAgreement> agreements,
  required List<ShiftSheetRow> shifts,
  required List<LeaveSheetRow> leave,
}) {
  if (day.paidMinutes <= 0) return null;
  final resolution = resolveAgreement(
    employmentId: employmentId,
    localStartDate: day.date,
    agreements: agreements,
  );
  if (resolution is! ResolvedAgreement) return null;
  final stamp = DateTime.utc(2000);
  final record = LeaveRecord(
    id: const LeaveRecordId('planned'),
    employmentId: employmentId,
    date: day.date,
    leaveType: day.leaveType,
    illnessStartedOn: day.leaveType == LeaveType.sick
        ? day.illnessStartedOn ?? day.date
        : null,
    paidMinutes: day.paidMinutes,
    agreementId: resolution.agreement.id,
    scheduleId: day.scheduleId,
    scheduleVersion: day.scheduleVersion,
    state: LeaveState.confirmed,
    voidReason: null,
    replacementId: null,
    replacedId: null,
    createdAtUtc: stamp,
    updatedAtUtc: stamp,
    revision: const Revision(0),
  );
  final worked = [
    for (final row in shifts)
      if (row.shift.state == ShiftState.finalized &&
          row.paidSeconds != null &&
          row.pay != null)
        WorkedPay(
          date: row.shift.localStartDate,
          paidSeconds: row.paidSeconds!,
          pay: row.pay!.amount,
        ),
  ];
  final earlier = [
    for (final row in leave)
      if (row.record.isEffective && row.record.date.compareTo(day.date) < 0)
        row.record,
  ];
  return priceLeave(
    leave: [...earlier, record],
    worked: worked,
    agreements: agreements,
  )[record.id];
}
```

- [ ] **Step 9: Run them to see them pass**

Run: `$F/flutter test test/features/work/presentation/work_plan_view_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 10: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`
Expected: "No issues found!"; all pass.

```bash
git add -A lib test
git commit -m "feat: watch plans live and word planned days for the calendar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The month grid

Spec §6.1: bevelled weekday headers, white cells, out-of-month days on the face colour, at most two entries and "+N more", today's amber outline, the selected day's dotted focus rectangle and selection fill, arrow keys, Enter, Page Up/Down. Pure widget.

**Files:**
- Create: `lib/features/work/presentation/work_calendar.dart`
- Test: `test/features/work/presentation/work_calendar_test.dart` (create)

**Interfaces:**
- Consumes: `DayView`, `DayEntry`, `DayEntryKind` (Task 2); `monthGridDays`, `spokenDate`, `eraMonthTitle` (`era_dates.dart`).
- Produces:
  - `WorkCalendar({required LocalDate month, required LocalDate today, required Map<LocalDate, DayView> days, ValueChanged<LocalDate>? onOpen, ValueChanged<LocalDate>? onMonth, ValueChanged<LocalDate>? onCursor, bool readOnly = false, bool autofocus = false})`
  - Keys: `ValueKey('work-calendar-day-$date')` on each cell, `ValueKey('work-calendar-today')` on today's outline.
  - `Color entrySwatch(DayEntryKind kind)`.

- [ ] **Step 1: Failing widget tests**

`test/features/work/presentation/work_calendar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/presentation/work_calendar.dart';
import 'package:lifeos/features/work/presentation/work_plan_view.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

import '../../../support/schedule_views.dart';

Future<void> _pump(
  WidgetTester tester, {
  Map<LocalDate, DayView>? days,
  LocalDate month = const LocalDate(2026, 10, 1),
  ValueChanged<LocalDate>? onOpen,
  ValueChanged<LocalDate>? onMonth,
  bool readOnly = false,
}) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: WorkCalendar(
              month: month,
              today: const LocalDate(2026, 10, 7),
              days: days ?? octoberViews(octoberPlan()),
              onOpen: onOpen,
              onMonth: onMonth,
              readOnly: readOnly,
              autofocus: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every entry is written in words', (tester) async {
    await _pump(tester);
    expect(find.text('Day 07:00–19:00'), findsNWidgets(9));
    expect(find.text('Night 19:00–07:00'), findsNWidgets(6));
  });

  testWidgets('weeks start on Monday', (tester) async {
    await _pump(tester);
    final monday = tester.getTopLeft(find.text('Mon'));
    final sunday = tester.getTopLeft(find.text('Sun'));
    expect(monday.dx, lessThan(sunday.dx));
    // 1 October 2026 is a Thursday: the first row starts on 28 September.
    expect(
      find.byKey(const ValueKey('work-calendar-day-2026-09-28')),
      findsOneWidget,
    );
  });

  testWidgets('today has the amber outline', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-calendar-day-2026-10-07')),
        matching: find.byKey(const ValueKey('work-calendar-today')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a third entry folds into "+1 more"', (tester) async {
    const date = LocalDate(2026, 10, 5);
    final days = octoberViews(octoberPlan());
    final day = days[date]!;
    days[date] = DayView(
      date: date,
      planned: day.planned,
      entries: [
        ...day.entries,
        const DayEntry(DayEntryKind.extra, 'Extra 20:00–22:00'),
        const DayEntry(DayEntryKind.leave, 'Vacation'),
      ],
    );
    await _pump(tester, days: days);
    expect(find.text('Extra 20:00–22:00'), findsOneWidget);
    expect(find.text('Vacation'), findsNothing);
    expect(find.text('+1 more'), findsOneWidget);
  });

  testWidgets('arrow keys move the day and Enter opens it', (tester) async {
    LocalDate? opened;
    await _pump(tester, onOpen: (day) => opened = day);
    // The cursor starts on today.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, const LocalDate(2026, 10, 15));
  });

  testWidgets('Page Down asks for the next month', (tester) async {
    LocalDate? month;
    await _pump(tester, onMonth: (value) => month = value);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    expect(month, const LocalDate(2026, 11, 1));
  });

  testWidgets('a double-click opens a day', (tester) async {
    LocalDate? opened;
    await _pump(tester, onOpen: (day) => opened = day);
    final cell = find.byKey(const ValueKey('work-calendar-day-2026-10-12'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(opened, const LocalDate(2026, 10, 12));
  });

  testWidgets('a cell is announced with its date and entries', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      find.bySemanticsLabel('Monday 5 October 2026: Day 07:00–19:00'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a preview takes no keys and opens nothing', (tester) async {
    LocalDate? opened;
    await _pump(tester, readOnly: true, onOpen: (day) => opened = day);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final cell = find.byKey(const ValueKey('work-calendar-day-2026-10-12'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(opened, isNull);
  });
}
```

(9 Day entries: 5–7, 17–19, 29–31. 6 Night entries: 11–13, 23–25.)

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/work_calendar_test.dart`
Expected: compile error: `work_calendar.dart` does not exist.

- [ ] **Step 3: Implement the grid**

`lib/features/work/presentation/work_calendar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_icons.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import 'work_plan_view.dart';

const _weekdayHeads = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The swatch beside an entry's words; the words carry the meaning.
Color entrySwatch(DayEntryKind kind) => switch (kind) {
  DayEntryKind.planned ||
  DayEntryKind.confirmed ||
  DayEntryKind.changed => MillenniumColors.link,
  DayEntryKind.extra => MillenniumColors.orbOrange,
  DayEntryKind.leave => MillenniumColors.orbGreen,
  DayEntryKind.cancelled => MillenniumColors.tabLine,
  DayEntryKind.needsReview => MillenniumColors.sortAccent,
};

/// The Work calendar (schedules spec 6.1): a Monday-first month in the
/// details-list style, each day with up to two written entries.
final class WorkCalendar extends StatefulWidget {
  const WorkCalendar({
    required this.month,
    required this.today,
    required this.days,
    this.onOpen,
    this.onMonth,
    this.onCursor,
    this.readOnly = false,
    this.autofocus = false,
    super.key,
  });

  /// Any date in the month shown.
  final LocalDate month;
  final LocalDate today;

  /// The month's days; dates outside it show no entries.
  final Map<LocalDate, DayView> days;

  /// Enter, or a double-click on a day.
  final ValueChanged<LocalDate>? onOpen;

  /// The month to show next: Page Up/Down, or the cursor leaving the month.
  final ValueChanged<LocalDate>? onMonth;

  /// The day under the cursor changed.
  final ValueChanged<LocalDate>? onCursor;

  /// A preview: no cursor, no keys, nothing opens.
  final bool readOnly;
  final bool autofocus;

  @override
  State<WorkCalendar> createState() => _WorkCalendarState();
}

final class _WorkCalendarState extends State<WorkCalendar> {
  final _node = FocusNode(debugLabel: 'WorkCalendar');
  late LocalDate _cursor = _start();
  bool _focused = false;

  LocalDate _start() {
    final first = widget.month.firstOfMonth;
    return widget.today.firstOfMonth == first ? widget.today : first;
  }

  @override
  void didUpdateWidget(covariant WorkCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The header's ‹ › or Today moved the month; the cursor follows.
    if (_cursor.firstOfMonth != widget.month.firstOfMonth) _cursor = _start();
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  void _move(LocalDate to) {
    setState(() => _cursor = to);
    widget.onCursor?.call(to);
    if (to.firstOfMonth != widget.month.firstOfMonth) {
      widget.onMonth?.call(to.firstOfMonth);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final LocalDate? target = switch (key) {
      LogicalKeyboardKey.arrowLeft => _cursor.addDays(-1),
      LogicalKeyboardKey.arrowRight => _cursor.addDays(1),
      LogicalKeyboardKey.arrowUp => _cursor.addDays(-7),
      LogicalKeyboardKey.arrowDown => _cursor.addDays(7),
      LogicalKeyboardKey.pageUp => _cursor.addMonthsClamped(-1),
      LogicalKeyboardKey.pageDown => _cursor.addMonthsClamped(1),
      LogicalKeyboardKey.home => _cursor.firstOfMonth,
      LogicalKeyboardKey.end => _cursor.lastOfMonth,
      _ => null,
    };
    if (target != null) {
      _move(target);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      widget.onOpen?.call(_cursor);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final grid = monthGridDays(widget.month);
    final body = Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Calendar, ${eraMonthTitle(widget.month)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          border: Border.all(color: MillenniumColors.fieldLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final head in _weekdayHeads)
                  Expanded(
                    child: ExcludeSemantics(
                      child: Container(
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.chrome,
                          border: Border(
                            right: BorderSide(color: tokens.chromeLine),
                            bottom: BorderSide(color: tokens.chromeLine),
                          ),
                        ),
                        child: Text(
                          head,
                          style: skin.typography.label.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (var week = 0; week < 6; week++)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in grid.sublist(week * 7, week * 7 + 7))
                      Expanded(child: _cell(skin, day)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.readOnly) return body;
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: body,
    );
  }

  Widget _cell(LifeOSSkinData skin, LocalDate day) {
    final tokens = skin.tokens;
    final inMonth =
        day.year == widget.month.year && day.month == widget.month.month;
    final entries = inMonth
        ? widget.days[day]?.entries ?? const <DayEntry>[]
        : const <DayEntry>[];
    final selected = !widget.readOnly && day == _cursor;
    // Blue while the calendar has focus, face grey while not, as in a list.
    final fill = selected
        ? (_focused ? tokens.selWash : MillenniumColors.groupLine)
        : inMonth
        ? tokens.paper
        : tokens.chrome;
    final ink = selected && _focused ? tokens.selInk : tokens.ink;
    final shown = entries.length > 2 ? entries.take(2) : entries;
    Widget cell = Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          right: BorderSide(color: tokens.chromeLine),
          bottom: BorderSide(color: tokens.chromeLine),
        ),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: skin.typography.figure.copyWith(
                color: inMonth ? ink : tokens.muted,
                fontWeight: day == widget.today ? FontWeight.w700 : null,
              ),
            ),
            for (final entry in shown) _EntryLine(entry: entry, ink: ink),
            if (entries.length > 2)
              Text(
                '+${entries.length - 2} more',
                style: skin.typography.body.copyWith(color: ink),
              ),
          ],
        ),
      ),
    );
    if (day == widget.today) {
      cell = DecoratedBox(
        key: const ValueKey('work-calendar-today'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: MillenniumColors.sortAccent, width: 2),
        ),
        child: cell,
      );
    }
    if (selected && _focused) {
      cell = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: DottedFocusRectangle(color: tokens.selInk, inset: 3),
        child: cell,
      );
    }
    final spoken = entries.isEmpty
        ? spokenDate(day)
        : '${spokenDate(day)}: ${entries.map((e) => e.spoken).join(', ')}';
    return Semantics(
      key: ValueKey('work-calendar-day-$day'),
      button: !widget.readOnly,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      onTap: widget.readOnly ? null : () => _move(day),
      child: widget.readOnly
          ? cell
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _node.requestFocus();
                _move(day);
              },
              onDoubleTap: () {
                _node.requestFocus();
                _move(day);
                widget.onOpen?.call(day);
              },
              child: cell,
            ),
    );
  }
}

/// A swatch and the entry's words on one line; a cancelled type is struck.
final class _EntryLine extends StatelessWidget {
  const _EntryLine({required this.entry, required this.ink});

  final DayEntry entry;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final colour = entrySwatch(entry.kind);
    final style = skin.typography.body.copyWith(color: ink);
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          if (entry.kind == DayEntryKind.needsReview)
            const EraIcon(EraIconKind.warning)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: entry.confirmed ? colour : null,
                border: Border.all(color: colour),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (entry.struck case final struck?)
                    TextSpan(
                      text: '$struck ',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  TextSpan(text: entry.text),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run them to see them pass**

Run: `$F/flutter test test/features/work/presentation/work_calendar_test.dart`
Expected: PASS (9 tests). If "a double-click opens a day" fails because the second tap lands after the double-tap timeout, keep the 50 ms pump; do not lengthen it.

- [ ] **Step 5: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: paint the Work calendar's month grid with written entries

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The Calendar sheet on the desk

Spec §6.1 header (‹ › push buttons, Month and Year dropdowns, Today) and status line; §5 default sheet. A day opens its Properties (Task 5), or the shift or leave recorded on it.

**Files:**
- Create: `lib/features/work/presentation/work_calendar_sheet.dart`
- Modify: `lib/features/work/presentation/work_register.dart`
- Modify: `lib/features/work/presentation/work_screen.dart`
- Modify: `lib/app/app_router.dart` (`_WorkRouteHost`)
- Test: `test/support/scheduled_app.dart` (create), `test/features/work/presentation/work_calendar_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `workPlanProvider`, `employmentSchedulesProvider`, `zoneClocksProvider`, `timezoneServiceProvider` (Task 2), `WorkCalendar` (Task 3), `dayViews`, `monthTotals`, `defaultSheetFor`.
- Produces:
  - `WorkCalendarSheet({required EmploymentId employmentId, required LocalDate month, required LocalDate today, required WorkRegisterProjection register, required ValueChanged<LocalDate> onMonth, required ValueChanged<DayView> onOpenDay})` — a `ConsumerWidget`.
  - `String monthTotalsLine(MonthTotals totals)` → `"15 shifts · 177:00 paid · planned EUR 3256.80 · confirmed EUR 0.00"` (the exact figures come from the premium engine).
  - `WorkScreen.schedules` (`List<WorkSchedule>`, default `const []`); `WorkRegister.defaultSheet` (`WorkSheet`, default `WorkSheet.shifts`).
  - The calendar's month is the route's `DateRangeScope` start; with no range, today's month.

- [ ] **Step 1: Failing tests**

The sheet reads real providers, so its tests drive the real app on an in-memory database. `test/support/scheduled_app.dart` (reused by Tasks 5–12):

```dart
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import 'schedule_fixture.dart';

/// The pumped app, its router and services, and the seeded ids.
typedef ScheduledApp = ({
  String employment,
  String? schedule,
  GoRouter router,
  ProductionWorkProviders work,
  FixedClock clock,
});

/// The app on an in-memory database with one employment paid EUR 18.40
/// gross from 1 September and, unless [withSchedule] is false, the depot
/// rotation from 5 October. "Now" is [now] (default 7 October 2026, 12:00
/// in Vilnius). `{employment}` and `{schedule}` in [location] become the
/// seeded ids.
Future<ScheduledApp> pumpScheduledApp(
  WidgetTester tester, {
  String location = '/work?employment={employment}',
  DateTime? now,
  bool withSchedule = true,
  Size size = const Size(1280, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final clock = FixedClock(now ?? DateTime.utc(2026, 10, 7, 9));
  final ids = UuidV7WorkIdFactory();
  final work = buildWorkProviders(
    database: database,
    clock: clock,
    timezones: IanaTimezoneService(),
    currentTimezoneId: () => 'Europe/Vilnius',
    workIds: ids,
    shiftIds: ids,
    evidenceIds: ids,
    scheduleIds: ids,
  );
  late String employment;
  String? schedule;
  await tester.runAsync(() async {
    final created = (await work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic depot', legalLabel: null),
    ) as Committed<Employment>).value;
    employment = created.id.value;
    await work.agreement.createAgreement(
      CreateAgreementCommand(
        employmentId: created.id,
        version: 1,
        terms: const AgreementTerms(
          effectiveStart: LocalDate(2026, 9, 1),
          effectiveEnd: null,
          hourlyRateMicroEur: 18400000,
          basis: GrossBasis(),
          label: null,
          note: null,
        ),
      ),
    );
    if (withSchedule) {
      final draft = depotDraft();
      final saved = await work.schedules.create(
        ScheduleDraft(
          employmentId: created.id,
          name: draft.name,
          timezoneId: draft.timezoneId,
          cycleStart: draft.cycleStart,
          inUseFrom: draft.inUseFrom,
          inUseUntil: null,
          shiftTypes: draft.shiftTypes,
          blocks: draft.blocks,
        ),
      );
      schedule = (saved as Committed<WorkSchedule>).value.id.value;
    }
  });
  final router = createAppRouter(
    initialLocation: location
        .replaceAll('{employment}', employment)
        .replaceAll('{schedule}', schedule ?? ''),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
  await tester.pumpAndSettle();
  return (
    employment: employment,
    schedule: schedule,
    router: router,
    work: work,
    clock: clock,
  );
}

/// Where the app is now.
String locationOf(ScheduledApp app) =>
    app.router.routeInformationProvider.value.uri.toString();
```

`test/features/work/presentation/work_calendar_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/scheduled_app.dart';

void main() {
  testWidgets('an employment with a schedule in use opens on its Calendar', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    expect(find.text('October 2026'), findsWidgets);
    expect(find.text('Day 07:00–19:00'), findsNWidgets(9));
  });

  testWidgets('the month status line sums the month', (tester) async {
    await pumpScheduledApp(tester);
    // October's 15 planned shifts, none confirmed yet.
    expect(find.textContaining('15 shifts · '), findsOneWidget);
    expect(find.textContaining('planned EUR '), findsOneWidget);
    expect(find.textContaining('confirmed EUR 0.00'), findsOneWidget);
  });

  testWidgets('› moves to November in the address', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    final location = locationOf(app);
    expect(location, contains('from=2026-11-01'));
    expect(location, contains('to=2026-11-30'));
    expect(location, contains('sheet=calendar'));
    expect(find.text('November 2026'), findsWidgets);
  });

  testWidgets('Enter on a planned day opens its Properties', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('work-calendar-day-2026-10-05')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final location = locationOf(app);
    expect(location, contains('day=2026-10-05'));
    expect(location, contains('mode=properties'));
  });

  testWidgets('Shifts is the default without a schedule', (tester) async {
    await pumpScheduledApp(tester, withSchedule: false);
    expect(find.text('Day 07:00–19:00'), findsNothing);
    expect(find.byKey(const ValueKey('work-calendar-totals')), findsNothing);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/work_calendar_sheet_test.dart`
Expected: FAIL: the Calendar sheet still shows "Not built yet".

- [ ] **Step 3: The sheet**

`lib/features/work/presentation/work_calendar_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/era_combo.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/ids.dart';
import '../domain/planner.dart';
import 'work_calendar.dart';
import 'work_controller.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';

/// "15 shifts · 172:30 paid · planned EUR 3174.00 · confirmed EUR 0.00".
String monthTotalsLine(MonthTotals totals) =>
    '${totals.shifts == 1 ? '1 shift' : '${totals.shifts} shifts'} · '
    '${formatDuration(totals.paidSeconds)} paid · '
    'planned ${formatMoney(totals.planned)} · '
    'confirmed ${formatMoney(totals.confirmed)}';

/// The Calendar sheet (schedules spec 6.1): a month header, the month grid
/// and the month's figures, read live from the plan.
final class WorkCalendarSheet extends ConsumerWidget {
  const WorkCalendarSheet({
    required this.employmentId,
    required this.month,
    required this.today,
    required this.register,
    required this.onMonth,
    required this.onOpenDay,
    super.key,
  });

  final EmploymentId employmentId;

  /// The first of the month shown.
  final LocalDate month;
  final LocalDate today;

  /// The month's recorded shifts and leave.
  final WorkRegisterProjection register;
  final ValueChanged<LocalDate> onMonth;
  final ValueChanged<DayView> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = LifeOSSkinScope.of(context);
    final grid = monthGridDays(month);
    final plan = ref.watch(
      workPlanProvider((
        employment: employmentId,
        from: grid.first,
        to: grid.last,
      )),
    );
    final schedules = switch (ref.watch(
      employmentSchedulesProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => const [],
    };
    final timezones = ref.watch(timezoneServiceProvider);
    final zones = ref.watch(zoneClocksProvider);
    final agreements = [
      for (final row in register.agreementSheet) row.agreement,
    ];
    return switch (plan) {
      AsyncData(:final value) => () {
        final days = dayViews(
          from: month.firstOfMonth,
          to: month.lastOfMonth,
          plan: value,
          shifts: register.shiftSheet,
          leave: register.leaveSheet,
          schedules: [...schedules],
          timezones: timezones,
        );
        final totals = monthTotals(
          days.values,
          price: (shift) => plannedPay(
            shift,
            agreements: agreements,
            employmentId: employmentId,
            zoneClocks: zones,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MonthHeader(month: month, today: today, onMonth: onMonth),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: WorkCalendar(
                  key: ValueKey(('work-calendar', month)),
                  month: month,
                  today: today,
                  days: days,
                  autofocus: true,
                  onMonth: onMonth,
                  onOpen: (date) => onOpenDay(days[date]!),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Text(
                monthTotalsLine(totals),
                key: const ValueKey('work-calendar-totals'),
                style: skin.typography.body.copyWith(color: skin.tokens.ink),
              ),
            ),
          ],
        );
      }(),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Calendar unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the schedule',
        message: 'Planning the month from its schedule.',
      ),
    };
  }
}

/// ‹ [Month ▾] [Year ▾] › [Today] above the grid.
final class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.today,
    required this.onMonth,
  });

  final LocalDate month;
  final LocalDate today;
  final ValueChanged<LocalDate> onMonth;

  @override
  Widget build(BuildContext context) {
    final first = month.firstOfMonth;
    final years = {
      for (var year = today.year - 5; year <= today.year + 5; year++) year,
      first.year,
    }.toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StepKey(
            forward: false,
            semanticLabel: 'Previous month',
            onPressed: () => onMonth(first.addMonthsClamped(-1)),
          ),
          EraCombo<int>(
            key: const ValueKey('work-calendar-month'),
            semanticLabel: 'Month',
            value: first.month,
            minWidth: 96,
            items: [
              for (var index = 0; index < 12; index++)
                EraComboItem(index + 1, eraMonthNames[index]),
            ],
            onSelected: (value) => onMonth(LocalDate(first.year, value, 1)),
          ),
          EraCombo<int>(
            key: const ValueKey('work-calendar-year'),
            semanticLabel: 'Year',
            value: first.year,
            items: [for (final year in years) EraComboItem(year, '$year')],
            onSelected: (value) => onMonth(LocalDate(value, first.month, 1)),
          ),
          StepKey(
            forward: true,
            semanticLabel: 'Next month',
            onPressed: () => onMonth(first.addMonthsClamped(1)),
          ),
          KeyButton(
            label: 'Today',
            onPressed: () => onMonth(today.firstOfMonth),
          ),
          // The month in words, for the window title and screen readers.
          Text(eraMonthTitle(first)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the sheet into the register and the screen**

`work_register.dart`: add `this.defaultSheet = WorkSheet.shifts` to the constructor with

```dart
  /// The sheet shown when the route names none (schedules spec 5).
  final WorkSheet defaultSheet;
```

compute `final shown = route.sheet ?? defaultSheet;`, and replace the placeholder's calendar arm with

```dart
      WorkSheet.calendar => WorkCalendarSheet(
        employmentId: value.scope.employmentId!,
        month: switch (route.scope) {
          DateRangeScope(:final start) => start.firstOfMonth,
          _ => (today ?? _deviceToday()).firstOfMonth,
        },
        today: today ?? _deviceToday(),
        register: value,
        onMonth: (month) => change(
          route.copyWith(
            sheet: WorkSheet.calendar,
            scope: () => DateRangeScope(
              start: month.firstOfMonth,
              end: month.lastOfMonth,
            ),
            record: () => null,
          ),
        ),
        onOpenDay: (day) => _openDay(day, route, change),
      ),
```

keeping `WorkSheet.leave || WorkSheet.schedules` on the placeholder. Add to the file:

```dart
LocalDate _deviceToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}

/// A confirmed day opens what was recorded on it; any other day opens its
/// own Properties.
void _openDay(
  DayView day,
  WorkRouteState route,
  ValueChanged<WorkRouteState> change,
) {
  final shift = day.shifts.firstOrNull;
  final leave = day.leave;
  final WorkRecordRef? record = shift != null
      ? WorkRecordRef(kind: WorkRecordKind.shift, id: shift.shift.id)
      : leave != null
      ? WorkRecordRef(kind: WorkRecordKind.leave, id: leave.record.id)
      : null;
  change(
    route.copyWith(
      sheet: WorkSheet.calendar,
      record: () => record,
      day: () => record == null ? day.date : null,
      mode: WorkInspectorMode.properties,
    ),
  );
}
```

On the calendar and schedules sheets the toolbar keeps the View combo and the employment switcher only: wrap the `PeriodPicker` and `StateFilter` in `if (shown != WorkSheet.calendar && shown != WorkSheet.schedules) ...[ ... ]`.

`work_screen.dart`: add `this.schedules = const []` with

```dart
  /// The selected employment's schedule versions; they choose the default
  /// sheet and name a schedule's dialog.
  final List<WorkSchedule> schedules;
```

pass `defaultSheet: defaultSheetFor(widget.schedules, _today)` to `WorkRegister`, and when saving a view pass the shown sheet: in `_taskGroups`, `onSaveView: ... () => widget.onSaveView!(route.copyWith(sheet: route.sheet ?? defaultSheetFor(widget.schedules, _today)))`.

`app_router.dart` `_WorkRouteHost.build`: pass

```dart
        schedules: switch (ref.watch(workRouteProvider)) {
          ValidWorkRoute(state: WorkRouteState(:final employmentId?)) =>
            switch (ref.watch(employmentSchedulesProvider(employmentId))) {
              AsyncData(:final value) => value,
              _ => const [],
            },
          _ => const [],
        },
```

- [ ] **Step 5: Run the tests**

Run: `$F/flutter test test/features/work/presentation/work_calendar_sheet_test.dart test/features/work/presentation/work_register_test.dart test/features/work/presentation/work_screen_test.dart`
Expected: PASS. The day route opens a dialog titled "Work record" until Task 5; the test only checks the address.

- [ ] **Step 6: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: show the Calendar sheet, by default while a schedule is in use

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: A day's Properties

Spec §6.2, §3.5. The route `day=…&mode=properties` opens "{weekday} {d} {Month} {yyyy}" as a Properties sheet. A planned shift offers **Confirm**, **Change…**, **Cancel shift…** and **Mark as leave…**; an Off day **Add extra shift…**; a change, cancellation or leave can be undone until the day is confirmed. Change… and Add extra shift… edit the times in place; the sheet's OK and Apply save them.

**Files:**
- Create: `lib/features/work/presentation/day_sheet.dart`
- Create: `lib/features/work/presentation/day_sheet_host.dart`
- Modify: `lib/features/work/presentation/work_screen.dart` (`_inspector`, `_dialogTitle`)
- Modify: `lib/app/app_router.dart` (`onCloseDialog`)
- Test: `test/features/work/presentation/day_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `planInputsProvider`, `employmentRegisterProvider`, `zoneClocksProvider`, `timezoneServiceProvider`, `dayPlanServiceProvider`; `DayPlanService.confirm/changeDay/cancelDay/markLeave/addExtra/removeException`; `plannedShiftName`, `shiftTimes`, `cancelReasonLabel`, `leaveTypeLabel`, `plannedLeavePay` (Task 2).
- Produces:
  - `final class DayTimes { LocalTime start; LocalTime end; int endDayOffset; List<FixedBreak> breaks; ShiftTypeId? shiftTypeId; bool countsAsOvertime; }`
  - `DayTimesForm({required List<ShiftType> types, required DayTimes initial, required bool extra, required Future<MutationOutcome<DayException>> Function(DayTimes) onSubmit, String? submitLabel, List<Widget> leading = const [], String? Function(MutationOutcome<DayException>) describe = dayProblem})` — on a Properties sheet (no `submitLabel`) it attaches to the sheet's OK / Apply; with a `submitLabel` it is its own dialog form, keys at the foot, closing once saved (Task 11's quick add).
  - `Future<({CancelReason reason, String? note})?> askCancelShift(BuildContext context)`
  - `Future<({LeaveType type, LocalDate? illnessStartedOn})?> askLeave(BuildContext context, {required LocalDate date, required LocalDate today, LeaveType initial = LeaveType.vacation, LocalDate? illnessStartedOn})`
  - `String? dayProblem(MutationOutcome<Object?> outcome)` and `String? confirmProblem(MutationOutcome<ConfirmedDay> outcome)` — the words for each outcome (Task 6 reuses `confirmProblem`).
  - `DayTimes dayTimesOf(PlannedShift shift, TimezoneService timezones)`; `DayTimes dayTimesOfType(ShiftType? type)`.
  - `DaySheet` (pure) and `DaySheetHost({required EmploymentId employmentId, required LocalDate date, required LocalDate today})`.
  - Field keys: `day-start`, `day-end`, `day-next-day`, `day-type`, `day-break-$i-start`, `day-break-$i-minutes`, `day-overtime`, `cancel-note`, `leave-illness-start`.

- [ ] **Step 1: Failing tests**

`test/features/work/presentation/day_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';

import '../../../support/era_pickers.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';

String _day(String date) =>
    '/work?employment={employment}&sheet=calendar&day=$date&mode=properties';

Finder _inSubDialog(String text) => find.descendant(
  of: find.byType(EraDialog),
  matching: find.text(text),
);

void main() {
  testWidgets('a planned day shows its shift and its actions', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    expect(dialogTitled('Monday 5 October 2026'), findsOneWidget);
    expect(find.text('Planned shift'), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);
    for (final key in ['Confirm', 'Change…', 'Cancel shift…', 'Mark as leave…']) {
      expect(find.text(key), findsOneWidget);
    }
  });

  testWidgets('a future day cannot be confirmed yet', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-10-17'));
    expect(find.text('Change…'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('an Off day offers an extra shift', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-10-08'));
    expect(find.text('No shift planned.'), findsOneWidget);
    expect(find.text('Add extra shift…'), findsOneWidget);
  });

  testWidgets('a day with no schedule in use says so', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-09-20'));
    expect(find.text('No schedule is in use on this date.'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('Confirm records the day and closes the sheet', (tester) async {
    final app = await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Confirm'));
    expect(locationOf(app), endsWith('mode=inspect'));
    expect(find.text('Day confirmed.'), findsOneWidget);
  });

  testWidgets('Change… edits the times in place and OK saves them', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Change…'));
    await setTime(tester, 'day-end', const LocalTime(20, 0));
    await tapInDialog(tester, find.text('OK'));
    expect(find.text('Day changed.'), findsOneWidget);
    expect(find.text('Day 07:00–20:00 changed'), findsOneWidget);
  });

  testWidgets('a break outside the shift is refused on the sheet', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Change…'));
    await setTime(tester, 'day-break-0-start', const LocalTime(21, 0));
    await tapInDialog(tester, find.text('Apply'));
    expect(
      find.text(
        'Breaks must lie inside the shift, not overlap, and last 1 to 240 '
        'minutes.',
      ),
      findsOneWidget,
    );
    expect(dialogTitled('Monday 5 October 2026'), findsOneWidget);
  });

  testWidgets('Cancel shift… records a reason and can be undone', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-06'));
    await tapInDialog(tester, find.text('Cancel shift…'));
    await tester.tap(_inSubDialog('Day off'));
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Shift cancelled.'), findsOneWidget);
    expect(find.text('Day off'), findsOneWidget);
    await tapInDialog(tester, find.text('Restore shift'));
    expect(find.text('Cancel shift…'), findsOneWidget);
  });

  testWidgets('Mark as leave… makes the day sick leave from its date', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-06'));
    await tapInDialog(tester, find.text('Mark as leave…'));
    await tester.tap(_inSubDialog('Sick'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leave-illness-start')), findsOneWidget);
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Marked as leave.'), findsOneWidget);
    expect(find.text('Sick'), findsWidgets);
    expect(find.text('Restore shift'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/day_sheet_test.dart`
Expected: FAIL: the dialog is titled "Work record".

- [ ] **Step 3: The sheet, its form and its small dialogs**

`lib/features/work/presentation/day_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/workbench/era_combo.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/era_icons.dart';
import '../../../shared/workbench/era_time_field.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/property_sheet.dart';
import '../application/day_plan_service.dart';
import '../domain/day_exception.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import 'employment_agreement_forms.dart' show staleMessage;
import 'work_formats.dart';
import 'work_plan_view.dart';

/// The times of a changed or extra day (schedules spec 3.5).
final class DayTimes {
  const DayTimes({
    required this.start,
    required this.end,
    required this.endDayOffset,
    required this.breaks,
    required this.shiftTypeId,
    this.countsAsOvertime = false,
  });

  final LocalTime start;
  final LocalTime end;
  final int endDayOffset;
  final List<FixedBreak> breaks;
  final ShiftTypeId? shiftTypeId;
  final bool countsAsOvertime;
}

int _minute(LocalTime time) => time.hour * 60 + time.minute;

String _hhmm(LocalTime time) => time.toString().substring(0, 5);

/// A planned shift's times on its own wall clock, to change.
DayTimes dayTimesOf(PlannedShift shift, TimezoneService timezones) {
  final zone = shift.timezoneId;
  int offset(DateTime utc) =>
      timezones.localDateAt(utc, zone).daysSince(shift.date);
  return DayTimes(
    start: timezones.localTimeAt(shift.startUtc, zone),
    end: timezones.localTimeAt(shift.endUtc, zone),
    endDayOffset: offset(shift.endUtc),
    breaks: [
      for (final item in shift.breaks)
        FixedBreak(
          start: timezones.localTimeAt(item.start, zone),
          dayOffset: offset(item.start),
          minutes: item.end.difference(item.start).inMinutes,
        ),
    ],
    shiftTypeId: shift.type?.id,
    countsAsOvertime: shift.countsAsOvertime,
  );
}

/// A type's times, or 08:00–20:00 without breaks when there is no type.
DayTimes dayTimesOfType(ShiftType? type) => type == null
    ? const DayTimes(
        start: LocalTime(8, 0),
        end: LocalTime(20, 0),
        endDayOffset: 0,
        breaks: [],
        shiftTypeId: null,
      )
    : DayTimes(
        start: type.start,
        end: type.end,
        endDayOffset: type.endDayOffset,
        breaks: type.breaks,
        shiftTypeId: type.id,
      );

/// What went wrong with a change to a day, in words; null once saved.
String? dayProblem(MutationOutcome<Object?> outcome) => switch (outcome) {
  Committed() => null,
  Invalid(:final fields) when fields.containsKey('end') =>
    'End must be after start and at most 24 hours later.',
  Invalid(:final fields) when fields.containsKey('breaks') =>
    'Breaks must lie inside the shift, not overlap, and last 1 to 240 '
        'minutes.',
  Invalid(:final fields) when fields.containsKey('illnessStartedOn') =>
    'The illness must start on or before this day.',
  Invalid(:final fields) when fields.containsKey('shiftTypeId') =>
    'Choose a shift type of the schedule in use on this date.',
  Invalid(:final fields) when fields.containsKey('date') =>
    'This date no longer holds what it did. Close it and open it again.',
  Invalid() => 'Check the times and try again.',
  Stale() => staleMessage,
  Missing() => 'This day no longer has that change.',
  Unavailable() || Uncertain() => 'Local storage is unavailable. Try again.',
};

/// What went wrong confirming a day, in words; null once confirmed.
String? confirmProblem(MutationOutcome<ConfirmedDay> outcome) =>
    switch (outcome) {
      Committed() => null,
      Stale() => 'Already confirmed',
      Invalid(:final fields) when fields.containsKey('agreement') =>
        'No pay agreement on this date',
      Invalid() || Missing() => 'Nothing to confirm on this date',
      Unavailable() || Uncertain() => 'Not saved: local storage is unavailable',
    };

/// A day's General page (schedules spec 6.2).
final class DaySheet extends StatefulWidget {
  const DaySheet({
    required this.date,
    required this.today,
    required this.day,
    required this.confirmed,
    required this.schedule,
    required this.pay,
    required this.leavePay,
    required this.timezones,
    required this.onConfirm,
    required this.onChange,
    required this.onCancelShift,
    required this.onMarkLeave,
    required this.onAddExtra,
    required this.onRemoveException,
    super.key,
  });

  final LocalDate date;
  final LocalDate today;

  /// What the plan holds; null when no schedule is in use on [date] or the
  /// date is confirmed.
  final PlannedDay? day;
  final bool confirmed;

  /// The schedule version in use on [date].
  final WorkSchedule? schedule;
  final ExpectedPay? pay;
  final LeavePay? leavePay;
  final TimezoneService timezones;
  final Future<MutationOutcome<ConfirmedDay>> Function() onConfirm;
  final Future<MutationOutcome<DayException>> Function(DayTimes times)
  onChange;
  final Future<MutationOutcome<DayException>> Function(
    CancelReason reason,
    String? note,
  )
  onCancelShift;
  final Future<MutationOutcome<DayException>> Function(
    LeaveType type,
    LocalDate? illnessStartedOn,
  )
  onMarkLeave;
  final Future<MutationOutcome<DayException>> Function(DayTimes times)
  onAddExtra;
  final Future<MutationOutcome<DayException>> Function() onRemoveException;

  @override
  State<DaySheet> createState() => _DaySheetState();
}

final class _DaySheetState extends State<DaySheet> {
  bool _editing = false;
  bool _busy = false;
  String? _error;

  bool get _past => widget.date.compareTo(widget.today) <= 0;

  Future<void> _run<T>(
    Future<MutationOutcome<T>> Function() action,
    String? Function(MutationOutcome<T>) problem, {
    bool closeOnCommit = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await action();
    if (!mounted) return;
    if (outcome is Committed<T> && closeOnCommit) {
      ShellDialogScope.closeOf(context)?.call();
      return;
    }
    setState(() {
      _busy = false;
      _error = problem(outcome);
    });
  }

  Future<void> _cancelShift() async {
    final answer = await askCancelShift(context);
    if (answer == null) return;
    await _run(
      () => widget.onCancelShift(answer.reason, answer.note),
      dayProblem,
    );
  }

  Future<void> _markLeave({LeaveType initial = LeaveType.vacation}) async {
    final current = widget.day;
    final answer = await askLeave(
      context,
      date: widget.date,
      today: widget.today,
      initial: current is PlannedLeave ? current.leaveType : initial,
      illnessStartedOn: current is PlannedLeave
          ? current.illnessStartedOn
          : null,
    );
    if (answer == null) return;
    await _run(
      () => widget.onMarkLeave(answer.type, answer.illnessStartedOn),
      dayProblem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final types = widget.schedule?.shiftTypes ?? const <ShiftType>[];
    final schedule = widget.schedule;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Day',
      child: InspectorPane(
        children: [
          InspectorTitle(
            spokenDate(widget.date),
            icon: EraIconKind.payPeriod,
            meta: schedule == null
                ? null
                : '${schedule.name} · cycle day '
                      '${schedule.cycleDayOf(widget.date)}',
          ),
          if (widget.confirmed)
            const InspectorText(
              'This day is confirmed. Open it from the calendar to see what '
              'was recorded.',
            )
          else
            ...switch (day) {
              null => [
                const InspectorText('No schedule is in use on this date.'),
              ],
              PlannedShift() => _shift(day, types),
              OffDay() => _off(types),
              CancelledPlan() => _cancelled(day),
              PlannedLeave() => _leave(day),
              NeedsReview() => _review(day),
            },
          if (_error case final error?) InspectorNote(error, tone: FactTone.negative),
        ],
      ),
    );
  }

  List<Widget> _shift(PlannedShift shift, List<ShiftType> types) {
    final times = shiftTimes(
      shift.startUtc,
      shift.endUtc,
      shift.timezoneId,
      widget.timezones,
    ).split('–');
    String clock(DateTime utc) => _hhmm(
      widget.timezones.localTimeAt(utc, shift.timezoneId),
    );
    final pay = widget.pay;
    return [
      InspectorFacts(legend: shift.isExtra ? 'Extra shift' : 'Planned shift', [
        Fact.words('Type', plannedShiftName(shift)),
        Fact('Start', times.first),
        Fact('End', times.last),
        Fact.words(
          'Breaks',
          shift.breaks.isEmpty
              ? 'None'
              : [
                  for (final item in shift.breaks)
                    '${clock(item.start)}, '
                        '${item.end.difference(item.start).inMinutes} min',
                ].join('; '),
        ),
        Fact('Paid time', formatDuration(shift.paidSeconds)),
        pay == null
            ? const Fact.words('Planned pay', 'No pay agreement on this date')
            : Fact('Planned pay', formatMoney(pay.amount)),
      ]),
      if (shift.changed)
        const InspectorNote('Changed from the schedule for this day.'),
      if (_editing)
        GroupBox(
          legend: shift.isExtra ? 'Extra shift' : 'Change this day',
          child: shift.isExtra
              ? DayTimesForm(
                  types: types,
                  initial: dayTimesOf(shift, widget.timezones),
                  extra: true,
                  onSubmit: widget.onAddExtra,
                )
              : DayTimesForm(
                  types: types,
                  initial: dayTimesOf(shift, widget.timezones),
                  extra: false,
                  onSubmit: widget.onChange,
                ),
        ),
      InspectorActions(
        children: [
          if (_past)
            KeyButton(
              label: 'Confirm',
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.onConfirm,
                      confirmProblem,
                      closeOnCommit: true,
                    ),
            ),
          if (!_editing)
            KeyButton(
              label: 'Change…',
              onPressed: _busy ? null : () => setState(() => _editing = true),
            ),
          if (!shift.isExtra) ...[
            KeyButton(
              label: 'Cancel shift…',
              onPressed: _busy ? null : _cancelShift,
            ),
            KeyButton(
              label: 'Mark as leave…',
              onPressed: _busy ? null : _markLeave,
            ),
          ],
          if (shift.changed || shift.isExtra)
            KeyButton(
              label: shift.isExtra ? 'Remove extra shift' : 'Undo change',
              onPressed: _busy
                  ? null
                  : () => _run(widget.onRemoveException, dayProblem),
            ),
        ],
      ),
    ];
  }

  List<Widget> _off(List<ShiftType> types) => [
    const InspectorText('No shift planned.'),
    if (_editing)
      GroupBox(
        legend: 'Extra shift',
        child: DayTimesForm(
          types: types,
          initial: dayTimesOfType(types.firstOrNull),
          extra: true,
          onSubmit: widget.onAddExtra,
        ),
      )
    else
      InspectorActions(
        children: [
          KeyButton(
            label: 'Add extra shift…',
            onPressed: () => setState(() => _editing = true),
          ),
        ],
      ),
  ];

  List<Widget> _cancelled(CancelledPlan day) => [
    InspectorFacts(legend: 'Cancelled shift', [
      Fact.words('Shift', plannedShiftName(day.replaced)),
      Fact.words('Reason', cancelReasonLabel(day.reason)),
      if (day.note case final note?) Fact.words('Note', note),
    ]),
    InspectorActions(
      children: [
        KeyButton(
          label: 'Restore shift',
          onPressed: _busy
              ? null
              : () => _run(widget.onRemoveException, dayProblem),
        ),
      ],
    ),
  ];

  List<Widget> _leave(PlannedLeave day) {
    final pay = widget.leavePay;
    return [
      InspectorFacts(legend: 'Leave', [
        Fact.words('Leave', leaveTypeLabel(day.leaveType)),
        if (day.leaveType == LeaveType.sick)
          Fact(
            'Illness started on',
            day.illnessStartedOn?.toString() ?? 'Worked out on confirm',
          ),
        Fact('Hours', formatDuration(day.paidMinutes * 60)),
        pay == null
            ? const Fact.words('Planned pay', 'No pay agreement on this date')
            : Fact('Planned pay', formatMoney(pay.amount)),
      ]),
      if (pay != null && !pay.employerPaid)
        const InspectorNote(
          'Paid by the social insurer, not on your payslip.',
        ),
      if (pay != null && pay.usedFallback)
        const InspectorNote(
          'No confirmed work in the 3 months before; using the agreement '
          'rate.',
        ),
      InspectorActions(
        children: [
          if (_past)
            KeyButton(
              label: 'Confirm',
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.onConfirm,
                      confirmProblem,
                      closeOnCommit: true,
                    ),
            ),
          KeyButton(
            label: 'Change leave…',
            onPressed: _busy ? null : _markLeave,
          ),
          KeyButton(
            label: 'Restore shift',
            onPressed: _busy
                ? null
                : () => _run(widget.onRemoveException, dayProblem),
          ),
        ],
      ),
    ];
  }

  List<Widget> _review(NeedsReview day) => [
    const InspectorNote(
      'This change no longer fits the schedule on this date. It is ignored '
      'until you remove it.',
      tone: FactTone.negative,
    ),
    InspectorActions(
      children: [
        KeyButton(
          label: 'Remove change',
          onPressed: _busy
              ? null
              : () => _run(widget.onRemoveException, dayProblem),
        ),
      ],
    ),
  ];
}

/// Start, end and breaks of one day, with the type they came from.
final class DayTimesForm extends StatefulWidget {
  const DayTimesForm({
    required this.types,
    required this.initial,
    required this.extra,
    required this.onSubmit,
    this.submitLabel,
    this.leading = const [],
    this.describe = dayProblem,
    super.key,
  });

  final List<ShiftType> types;
  final DayTimes initial;

  /// An extra shift: offers "Counts as overtime".
  final bool extra;
  final Future<MutationOutcome<DayException>> Function(DayTimes times)
  onSubmit;

  /// Outside a Properties sheet, the key that saves; with none, the form
  /// saves through the sheet's OK and Apply.
  final String? submitLabel;

  /// Fields above the times when the form is its own dialog, such as the
  /// date quick add asks for.
  final List<Widget> leading;

  /// The words for a refused save.
  final String? Function(MutationOutcome<DayException> outcome) describe;

  @override
  State<DayTimesForm> createState() => _DayTimesFormState();
}

final class _Break {
  /// [onEdit] runs whenever the minutes are typed, so Apply lights.
  _Break(this.start, int minutes, VoidCallback onEdit)
    : minutes = TextEditingController(text: '$minutes') {
    this.minutes.addListener(onEdit);
  }

  LocalTime start;
  final TextEditingController minutes;
}

final class _DayTimesFormState extends State<DayTimesForm> {
  late ShiftTypeId? _type = widget.initial.shiftTypeId;
  late LocalTime _start = widget.initial.start;
  late LocalTime _end = widget.initial.end;
  late bool _nextDay = widget.initial.endDayOffset == 1;
  late bool _overtime = widget.initial.countsAsOvertime;
  late final List<_Break> _breaks = [
    for (final item in widget.initial.breaks)
      _Break(item.start, item.minutes, _markDirty),
  ];
  String? _error;
  bool _submitting = false;
  PropertySheetController? _sheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sheet = widget.submitLabel == null
        ? PropertySheetScope.maybeOf(context)
        : null;
    if (sheet != _sheet) {
      _sheet?.detach(_apply);
      _sheet = sheet?..attach(apply: _apply);
    }
  }

  @override
  void dispose() {
    _sheet?.detach(_apply);
    for (final item in _breaks) {
      item.minutes.dispose();
    }
    super.dispose();
  }

  void _markDirty() => _sheet?.markDirty(true);

  void _changed(VoidCallback change) {
    setState(change);
    _markDirty();
  }

  void _useType(ShiftTypeId? id) => _changed(() {
    _type = id;
    final type = widget.types.where((value) => value.id == id).firstOrNull;
    if (type == null) return;
    _start = type.start;
    _end = type.end;
    _nextDay = type.endDayOffset == 1;
    for (final item in _breaks) {
      item.minutes.dispose();
    }
    _breaks
      ..clear()
      ..addAll([
        for (final item in type.breaks)
          _Break(item.start, item.minutes, _markDirty),
      ]);
  });

  DayTimes _value() => DayTimes(
    start: _start,
    end: _end,
    endDayOffset: _nextDay ? 1 : 0,
    breaks: [
      for (final item in _breaks)
        FixedBreak(
          start: item.start,
          // A break earlier on the clock than the start is after midnight.
          dayOffset: _minute(item.start) < _minute(_start) ? 1 : 0,
          minutes: int.tryParse(item.minutes.text.trim()) ?? 0,
        ),
    ],
    shiftTypeId: _type,
    countsAsOvertime: _overtime,
  );

  Future<bool> _apply() async => await _submit() is Committed<DayException>;

  Future<MutationOutcome<DayException>> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final outcome = await widget.onSubmit(_value());
    if (!mounted) return outcome;
    // With its own keys the form is its dialog, which closes once saved.
    if (outcome is Committed<DayException> && widget.submitLabel != null) {
      ShellDialogScope.closeOf(context)?.call();
      return outcome;
    }
    setState(() {
      _submitting = false;
      _error = widget.describe(outcome);
    });
    return outcome;
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      EraLabelled(
        label: 'Shift type',
        field: EraCombo<ShiftTypeId?>(
          key: const ValueKey('day-type'),
          semanticLabel: 'Shift type',
          value: _type,
          minWidth: 120,
          items: [
            for (final type in widget.types)
              EraComboItem<ShiftTypeId?>(type.id, type.name),
            const EraComboItem<ShiftTypeId?>(null, '(custom times)'),
          ],
          onSelected: _useType,
        ),
      ),
      EraTimeField(
        fieldKey: const ValueKey('day-start'),
        label: 'Start',
        value: _start,
        onChanged: (value) => _changed(() => _start = value),
      ),
      EraTimeField(
        fieldKey: const ValueKey('day-end'),
        label: 'End',
        value: _end,
        onChanged: (value) => _changed(() => _end = value),
      ),
      EraCheckBox(
        key: const ValueKey('day-next-day'),
        label: 'Ends the next day',
        value: _nextDay,
        onChanged: (value) => _changed(() => _nextDay = value),
      ),
      for (final (index, item) in _breaks.indexed)
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Break ${index + 1}:'),
            EraTimeField(
              fieldKey: ValueKey('day-break-$index-start'),
              semanticLabel: 'Break ${index + 1} start',
              value: item.start,
              onChanged: (value) => _changed(() => item.start = value),
            ),
            IntrinsicWidth(
              child: EraField(
                fieldKey: ValueKey('day-break-$index-minutes'),
                controller: item.minutes,
                label: 'Minutes',
                width: EraFieldWidth.short,
                keyboardType: TextInputType.number,
              ),
            ),
            KeyButton(
              label: 'Remove',
              onPressed: () => _changed(() {
                _breaks.remove(item);
                item.minutes.dispose();
              }),
            ),
          ],
        ),
      KeyButton(
        label: 'Add break',
        onPressed: () => _changed(
          () => _breaks.add(
            _Break(
              LocalTime((_start.hour + 4) % 24, _start.minute),
              30,
              _markDirty,
            ),
          ),
        ),
      ),
      if (widget.extra)
        EraCheckBox(
          key: const ValueKey('day-overtime'),
          label: 'Counts as overtime',
          value: _overtime,
          onChanged: (value) => _changed(() => _overtime = value),
        ),
      if (_error case final error?) InspectorNote(error, tone: FactTone.negative),
    ];
    final label = widget.submitLabel;
    final column = EraFormScope(
      labelWidth: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in fields)
            Padding(padding: const EdgeInsets.only(bottom: 7), child: field),
        ],
      ),
    );
    if (label == null) return column;
    // Its own dialog: the keys stay at the dialog's foot (DESIGN.md).
    return DialogForm(
      fields: [...widget.leading, column],
      keys: [
        KeyButton(
          label: label,
          kind: KeyKind.primary,
          onPressed: _submitting ? null : _submit,
        ),
        const DialogCancelKey(),
      ],
    );
  }
}

/// "Cancel shift": why a planned shift is not worked (spec 6.2).
Future<({CancelReason reason, String? note})?> askCancelShift(
  BuildContext context,
) => showDialog(context: context, builder: (_) => const _CancelShiftDialog());

final class _CancelShiftDialog extends StatefulWidget {
  const _CancelShiftDialog();

  @override
  State<_CancelShiftDialog> createState() => _CancelShiftDialogState();
}

final class _CancelShiftDialogState extends State<_CancelShiftDialog> {
  var _reason = CancelReason.swapped;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Cancel shift',
    body: EraFormScope(
      labelWidth: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why is this shift not worked?'),
          const SizedBox(height: 7),
          EraRadioGroup<CancelReason>(
            options: const [
              EraRadioOption(CancelReason.swapped, 'Swapped'),
              EraRadioOption(CancelReason.dayOff, 'Day off'),
              EraRadioOption(CancelReason.other, 'Other'),
            ],
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value),
          ),
          const SizedBox(height: 7),
          EraField(
            fieldKey: const ValueKey('cancel-note'),
            controller: _note,
            label: 'Note',
          ),
          const SizedBox(height: 7),
          const Text('Illness is marked as sick leave, not cancelled.'),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: () => Navigator.of(context).pop((
          reason: _reason,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        )),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}

/// "Mark as leave": vacation or sick, and for sick the illness's start
/// (blank works it out from the run of sick days, spec 4.3).
Future<({LeaveType type, LocalDate? illnessStartedOn})?> askLeave(
  BuildContext context, {
  required LocalDate date,
  required LocalDate today,
  LeaveType initial = LeaveType.vacation,
  LocalDate? illnessStartedOn,
}) => showDialog(
  context: context,
  builder: (_) => _LeaveDialog(
    date: date,
    today: today,
    initial: initial,
    illnessStartedOn: illnessStartedOn,
  ),
);

final class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({
    required this.date,
    required this.today,
    required this.initial,
    required this.illnessStartedOn,
  });

  final LocalDate date;
  final LocalDate today;
  final LeaveType initial;
  final LocalDate? illnessStartedOn;

  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

final class _LeaveDialogState extends State<_LeaveDialog> {
  late var _type = widget.initial;
  late LocalDate? _illness = widget.illnessStartedOn;

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Mark as leave',
    body: EraFormScope(
      labelWidth: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraRadioGroup<LeaveType>(
            options: const [
              EraRadioOption(LeaveType.vacation, 'Vacation'),
              EraRadioOption(LeaveType.sick, 'Sick'),
            ],
            groupValue: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          if (_type == LeaveType.sick) ...[
            const SizedBox(height: 7),
            EraDateField(
              fieldKey: const ValueKey('leave-illness-start'),
              label: 'Illness started on',
              value: _illness,
              optional: true,
              today: widget.today,
              onChanged: (value) => setState(() => _illness = value),
            ),
            const SizedBox(height: 4),
            const Text('Leave blank to count from the first sick day.'),
          ],
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: () => Navigator.of(context).pop((
          type: _type,
          illnessStartedOn: _type == LeaveType.sick ? _illness : null,
        )),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}
```

- [ ] **Step 4: The host**

`lib/features/work/presentation/day_sheet_host.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/workbench/operational_state.dart';
import '../domain/day_exception.dart';
import '../domain/ids.dart';
import '../domain/planner.dart';
import 'day_sheet.dart';
import 'work_controller.dart';
import 'work_plan_view.dart';

/// Reads one date's plan and binds its Properties to [DayPlanService].
final class DaySheetHost extends ConsumerWidget {
  const DaySheetHost({
    required this.employmentId,
    required this.date,
    required this.today,
    super.key,
  });

  final EmploymentId employmentId;
  final LocalDate date;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zoneClocksProvider);
    final timezones = ref.watch(timezoneServiceProvider);
    final register = switch (ref.watch(
      employmentRegisterProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final service = ref.read(dayPlanServiceProvider);
    Future<MutationOutcome<T>> noted<T>(
      Future<MutationOutcome<T>> pending,
      String notice,
    ) async {
      final outcome = await pending;
      if (outcome is Committed<T> && context.mounted) {
        StatusNoticeScope.read(context)?.value = notice;
      }
      return outcome;
    }

    return switch (ref.watch(planInputsProvider(employmentId))) {
      AsyncData(value: final inputs) => () {
        final day = planDays(
          from: date,
          to: date,
          schedules: inputs.schedules,
          exceptions: inputs.exceptions,
          confirmedDates: inputs.confirmedDates,
          zoneClocks: zones,
        ).firstOrNull;
        final exception = inputs.exceptions
            .where((value) => value.date == date)
            .firstOrNull;
        final expected = exception?.revision;
        return DaySheet(
          key: ValueKey(('day', date, exception?.updatedAtUtc)),
          date: date,
          today: today,
          day: day,
          confirmed: inputs.confirmedDates.contains(date),
          schedule: inputs.schedules
              .where((value) => value.isInUseOn(date))
              .firstOrNull,
          pay: day is PlannedShift
              ? plannedPay(
                  day,
                  agreements: inputs.agreements,
                  employmentId: employmentId,
                  zoneClocks: zones,
                )
              : null,
          leavePay: day is PlannedLeave && register != null
              ? plannedLeavePay(
                  day,
                  employmentId: employmentId,
                  agreements: inputs.agreements,
                  shifts: register.shiftSheet,
                  leave: register.leaveSheet,
                )
              : null,
          timezones: timezones,
          onConfirm: () =>
              noted(service.confirm(employmentId, date), 'Day confirmed.'),
          onChange: (times) => noted(
            service.changeDay(
              employmentId,
              date,
              start: times.start,
              end: times.end,
              endDayOffset: times.endDayOffset,
              breaks: times.breaks,
              shiftTypeId: times.shiftTypeId,
              expected: expected,
            ),
            'Day changed.',
          ),
          onCancelShift: (reason, note) => noted(
            service.cancelDay(
              employmentId,
              date,
              reason: reason,
              note: note,
              expected: expected,
            ),
            'Shift cancelled.',
          ),
          onMarkLeave: (type, illness) => noted(
            service.markLeave(
              employmentId,
              date,
              leaveType: type,
              illnessStartedOn: illness,
              expected: expected,
            ),
            'Marked as leave.',
          ),
          onAddExtra: (times) => noted(
            service.addExtra(
              employmentId,
              date,
              start: times.start,
              end: times.end,
              endDayOffset: times.endDayOffset,
              breaks: times.breaks,
              shiftTypeId: times.shiftTypeId,
              countsAsOvertime: times.countsAsOvertime,
              expected: expected,
            ),
            'Extra shift added.',
          ),
          onRemoveException: () => exception == null
              ? Future.value(const Missing<DayException>())
              : noted(
                  service.removeException(
                    exception.id,
                    expected: exception.revision,
                  ),
                  'Day restored to its schedule.',
                ),
        );
      }(),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Day unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the day',
        message: 'Planning this date from its schedule.',
      ),
    };
  }
}
```

- [ ] **Step 5: Open it from the route**

`work_screen.dart` (import `day_sheet_host.dart` and `../../../shared/workbench/era_dates.dart`):
- In `_inspector`, right after `final employmentId = route.employmentId;`:

```dart
    if (route.day case final day?
        when employmentId != null && route.record == null) {
      return DaySheetHost(
        key: ValueKey(('day-sheet', day)),
        employmentId: employmentId,
        date: day,
        today: _today,
      );
    }
```

- In `_dialogTitle`, after `if (_failed()) return 'Work';`:

```dart
    if (route.day case final day? when route.record == null) {
      return spokenDate(day);
    }
```

`app_router.dart` `onCloseDialog`: the `copyWith` also clears `day: () => null` and `confirming: false`.

- [ ] **Step 6: Run the tests**

Run: `$F/flutter test test/features/work/presentation/day_sheet_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 7: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: open a day's Properties to confirm, change, cancel or take leave

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Confirm worked days

Spec §6.3: an era dialog listing every past unconfirmed day up to yesterday, each ticked; a footer "12 days · 138:00 paid · EUR 2714.40"; **Confirm** (default) and **Cancel**. One transaction per day; failures stay in the list with their words; committed days leave it.

**Files:**
- Create: `lib/features/work/presentation/confirm_days_dialog.dart`
- Modify: `lib/features/work/presentation/work_screen.dart` (`_inspector`, `_dialogOpen`, `_dialogTitle`, `_dialogSize`, `_taskGroups`)
- Modify: `lib/features/work/presentation/work_tasks.dart` (`WorkTaskContext.onConfirmDays`, `onNewSchedule`; Work tasks group)
- Test: `test/features/work/presentation/confirm_days_dialog_test.dart` (create)

**Interfaces:**
- Consumes: `daysToConfirmProvider`, `employmentRegisterProvider`, `zoneClocksProvider`, `timezoneServiceProvider`, `dayPlanServiceProvider` (Task 2); `confirmProblem` (Task 5); `plannedShiftName`, `shiftTimes`, `leaveTypeLabel`, `plannedLeavePay`.
- Produces:
  - `final class ConfirmRow { LocalDate date; String what; String times; int paidSeconds; Money? pay; }`
  - `List<ConfirmRow> confirmRows(List<PlannedDay> days, {required ExpectedPay? Function(PlannedShift) shiftPay, required LeavePay? Function(PlannedLeave) leavePay, required TimezoneService timezones})`
  - `String confirmSummary(Iterable<ConfirmRow> rows)` → `"2 days · 23:00 paid · EUR 423.20"`
  - `ConfirmDaysDialog({required List<ConfirmRow> rows, required Future<Map<LocalDate, MutationOutcome<ConfirmedDay>>> Function(List<LocalDate>) onConfirm})`; `ConfirmDaysHost({required EmploymentId employmentId})`.
  - `WorkTaskContext.onConfirmDays` ("Confirm worked days…") and `WorkTaskContext.onNewSchedule` ("New schedule…", used by Task 9), both `VoidCallback?`.
  - Row keys: `ValueKey('confirm-row-$date')`.

- [ ] **Step 1: Failing tests**

`test/features/work/presentation/confirm_days_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/presentation/confirm_days_dialog.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

import '../../../support/schedule_views.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';

const _confirm = '/work?employment={employment}&confirm=1&mode=inspect';

void main() {
  testWidgets('every past unconfirmed day is listed and ticked', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _confirm);
    expect(dialogTitled('Confirm worked days'), findsOneWidget);
    // Today is 7 October: the 5th and 6th are past Day shifts.
    expect(find.byKey(const ValueKey('confirm-row-2026-10-05')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-row-2026-10-06')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-row-2026-10-07')), findsNothing);
    expect(find.textContaining('2 days · 23:00 paid · EUR '), findsOneWidget);
  });

  testWidgets('unticked days stay; Confirm records the rest and closes', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester, location: _confirm);
    // The check box's label is the date as a date box shows it.
    await tester.tap(find.text('Tue 2026-10-06'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 day · 11:30 paid'), findsOneWidget);
    await tapInDialog(tester, find.text('Confirm'));
    expect(locationOf(app), endsWith('mode=inspect'));
    expect(locationOf(app), isNot(contains('confirm=1')));
    expect(find.text('1 day confirmed.'), findsOneWidget);
    app.router.go(_confirm.replaceAll('{employment}', app.employment));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-row-2026-10-05')), findsNothing);
    expect(find.byKey(const ValueKey('confirm-row-2026-10-06')), findsOneWidget);
  });

  testWidgets('the Work tasks open it', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(find.widgetWithText(TaskLink, 'Confirm worked days…'));
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('confirm=1'));
  });

  testWidgets('a day confirmed elsewhere says so; the others commit', (
    tester,
  ) async {
    final rows = [
      for (final day in [5, 6])
        ConfirmRow(
          date: LocalDate(2026, 10, day),
          what: 'Day',
          times: '07:00–19:00',
          paidSeconds: 41400,
          pay: const Money(minorUnits: 21160),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SizedBox(
              width: 600,
              height: 480,
              child: ConfirmDaysDialog(
                rows: rows,
                onConfirm: (dates) async => {
                  const LocalDate(2026, 10, 5): const Stale<ConfirmedDay>(),
                  const LocalDate(2026, 10, 6): Committed<ConfirmedDay>(
                    ConfirmedShift(
                      confirmedDayRow(const LocalDate(2026, 10, 6)).shift,
                    ),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Already confirmed'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/confirm_days_dialog_test.dart`
Expected: compile error: `confirm_days_dialog.dart` does not exist.

- [ ] **Step 3: The dialog and its host**

`lib/features/work/presentation/confirm_days_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../application/day_plan_service.dart';
import '../domain/ids.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import '../domain/planner.dart';
import 'day_sheet.dart' show confirmProblem;
import 'work_controller.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';

/// One day the dialog offers to confirm.
final class ConfirmRow {
  const ConfirmRow({
    required this.date,
    required this.what,
    required this.times,
    required this.paidSeconds,
    required this.pay,
  });

  final LocalDate date;

  /// "Day", "Night", "Extra", "Vacation" or "Sick".
  final String what;

  /// "07:00–19:00"; empty for leave.
  final String times;
  final int paidSeconds;

  /// Null when no agreement covers the date.
  final Money? pay;
}

List<ConfirmRow> confirmRows(
  List<PlannedDay> days, {
  required ExpectedPay? Function(PlannedShift shift) shiftPay,
  required LeavePay? Function(PlannedLeave leave) leavePay,
  required TimezoneService timezones,
}) => [
  for (final day in days)
    switch (day) {
      PlannedShift() => ConfirmRow(
        date: day.date,
        what: plannedShiftName(day),
        times: shiftTimes(day.startUtc, day.endUtc, day.timezoneId, timezones),
        paidSeconds: day.paidSeconds,
        pay: shiftPay(day)?.amount,
      ),
      PlannedLeave() => ConfirmRow(
        date: day.date,
        what: leaveTypeLabel(day.leaveType),
        times: '',
        paidSeconds: day.paidMinutes * 60,
        pay: leavePay(day)?.amount,
      ),
      _ => null,
    },
].nonNulls.toList();

/// "12 days · 138:00 paid · EUR 2714.40".
String confirmSummary(Iterable<ConfirmRow> rows) {
  final count = rows.length;
  final paid = rows.fold(0, (sum, row) => sum + row.paidSeconds);
  final pay = rows.fold(0, (sum, row) => sum + (row.pay?.minorUnits ?? 0));
  return '${count == 1 ? '1 day' : '$count days'} · '
      '${formatDuration(paid)} paid · ${formatMoney(Money(minorUnits: pay))}';
}

/// The Confirm worked days dialog (schedules spec 6.3).
final class ConfirmDaysDialog extends StatefulWidget {
  const ConfirmDaysDialog({
    required this.rows,
    required this.onConfirm,
    super.key,
  });

  final List<ConfirmRow> rows;

  /// Confirms each date in turn and says how each went.
  final Future<Map<LocalDate, MutationOutcome<ConfirmedDay>>> Function(
    List<LocalDate> dates,
  )
  onConfirm;

  @override
  State<ConfirmDaysDialog> createState() => _ConfirmDaysDialogState();
}

final class _ConfirmDaysDialogState extends State<ConfirmDaysDialog> {
  /// Days the owner unticked; every other listed day is ticked, including
  /// days that appear while the dialog is open.
  final _unticked = <LocalDate>{};
  final _problems = <LocalDate, String>{};
  bool _busy = false;

  List<ConfirmRow> get _ticked => [
    for (final row in widget.rows)
      if (!_unticked.contains(row.date)) row,
  ];

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _problems.clear();
    });
    final results = await widget.onConfirm([
      for (final row in _ticked) row.date,
    ]);
    if (!mounted) return;
    final problems = {
      for (final MapEntry(key: date, value: outcome) in results.entries)
        if (confirmProblem(outcome) case final problem?) date: problem,
    };
    if (problems.isEmpty) {
      ShellDialogScope.closeOf(context)?.call();
      return;
    }
    setState(() {
      _busy = false;
      _problems.addAll(problems);
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final close = ShellDialogScope.closeOf(context);
    if (widget.rows.isEmpty) {
      return DialogForm(
        fields: const [InspectorText('Every past planned day is confirmed.')],
        keys: [KeyButton(label: 'Close', kind: KeyKind.primary, onPressed: close)],
      );
    }
    final style = skin.typography.body.copyWith(color: tokens.ink);
    Widget head(String text, double width, {bool end = false}) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(right: BorderSide(color: tokens.chromeLine)),
      ),
      child: Text(text, style: skin.typography.label.copyWith(color: tokens.ink)),
    );
    Widget cell(String text, double width, {bool end = false, Color? ink}) =>
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ink == null ? style : style.copyWith(color: ink),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Tick the days you worked as planned, then Confirm.'),
        const SizedBox(height: 7),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    head('Date', 150),
                    head('What', 70),
                    head('Times', 90),
                    head('Paid', 52, end: true),
                    head('Pay', 82, end: true),
                    Expanded(child: head('', 0)),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final row in widget.rows)
                        SizedBox(
                          key: ValueKey('confirm-row-${row.date}'),
                          height: 20,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 150,
                                child: EraCheckBox(
                                  label: eraBoxDate(row.date),
                                  value: !_unticked.contains(row.date),
                                  onChanged: _busy
                                      ? null
                                      : (ticked) => setState(
                                          () => ticked
                                              ? _unticked.remove(row.date)
                                              : _unticked.add(row.date),
                                        ),
                                ),
                              ),
                              cell(row.what, 70),
                              cell(row.times, 90),
                              cell(formatDuration(row.paidSeconds), 52, end: true),
                              cell(
                                row.pay == null ? '—' : formatMoney(row.pay!),
                                82,
                                end: true,
                              ),
                              Expanded(
                                child: cell(
                                  _problems[row.date] ?? '',
                                  0,
                                  ink: tokens.negative,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(confirmSummary(_ticked), style: style),
        FormFooter(
          children: [
            KeyButton(
              label: 'Confirm',
              kind: KeyKind.primary,
              onPressed: _busy || _ticked.isEmpty ? null : _confirm,
            ),
            const DialogCancelKey(),
          ],
        ),
      ],
    );
  }
}

/// Lists the employment's days to confirm, live, and confirms them one
/// transaction at a time.
final class ConfirmDaysHost extends ConsumerWidget {
  const ConfirmDaysHost({required this.employmentId, super.key});

  final EmploymentId employmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final register = switch (ref.watch(
      employmentRegisterProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final zones = ref.watch(zoneClocksProvider);
    final timezones = ref.watch(timezoneServiceProvider);
    final agreements = [
      for (final row in register?.agreementSheet ?? const []) row.agreement,
    ];
    return switch (ref.watch(daysToConfirmProvider(employmentId))) {
      AsyncData(:final value) => ConfirmDaysDialog(
        rows: confirmRows(
          value,
          timezones: timezones,
          shiftPay: (shift) => plannedPay(
            shift,
            agreements: agreements,
            employmentId: employmentId,
            zoneClocks: zones,
          ),
          leavePay: (leave) => register == null
              ? null
              : plannedLeavePay(
                  leave,
                  employmentId: employmentId,
                  agreements: agreements,
                  shifts: register.shiftSheet,
                  leave: register.leaveSheet,
                ),
        ),
        onConfirm: (dates) async {
          final service = ref.read(dayPlanServiceProvider);
          final notice = StatusNoticeScope.read(context);
          final results = <LocalDate, MutationOutcome<ConfirmedDay>>{};
          for (final date in dates) {
            results[date] = await service.confirm(employmentId, date);
          }
          final done = results.values.whereType<Committed<ConfirmedDay>>().length;
          String days(int n) => n == 1 ? '1 day' : '$n days';
          notice?.value = done == dates.length
              ? '${days(done)} confirmed.'
              : '$done of ${days(dates.length)} confirmed.';
          return results;
        },
      ),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Days unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the days',
        message: 'Finding past planned days not yet confirmed.',
      ),
    };
  }
}
```

- [ ] **Step 4: Open it from the route and the task pane**

`work_tasks.dart`: add to `WorkTaskContext`

```dart
    this.onConfirmDays,
    this.onNewSchedule,
```

```dart
  /// Opens Confirm worked days; null without a schedule.
  final VoidCallback? onConfirmDays;

  /// Opens a new schedule; null without an agreement.
  final VoidCallback? onNewSchedule;
```

and make the Work tasks group (spec §5) read:

```dart
      group('Work tasks', [
        (
          'Confirm worked days…',
          EraIconKind.reviewed,
          c.onConfirmDays,
        ),
        ('New schedule…', EraIconKind.add, c.onNewSchedule),
        ('Add a shift', EraIconKind.add, c.onAddShift),
        ('New pay period', EraIconKind.add, c.onNewPeriod),
        ('Record payslip', EraIconKind.recordPayslip, c.onRecordPayslip),
        ('Set up pay agreement…', EraIconKind.agreement, c.onSetUpAgreement),
        (
          'Employment properties',
          EraIconKind.properties,
          c.onEmploymentProperties,
        ),
        ('Save this view…', EraIconKind.saveView, c.onSaveView),
      ]),
```

`work_screen.dart`:
- `_taskGroups`: pass `onConfirmDays: widget.schedules.isEmpty ? null : () => _go(route.copyWith(confirming: true))`. (`onNewSchedule` is wired in Task 9.)
- `_dialogOpen`: add `route.confirming ||`.
- `_inspector`, after the day branch from Task 5:

```dart
    if (route.confirming && employmentId != null) {
      return ConfirmDaysHost(employmentId: employmentId);
    }
```

- `_dialogTitle`, after the day title: `if (route.confirming) return 'Confirm worked days';`
- `_dialogSize`, first line after the failure size: `if (state.route.confirming) return const Size(600, 480);`

- [ ] **Step 5: Run the tests**

Run: `$F/flutter test test/features/work/presentation/confirm_days_dialog_test.dart test/features/work/presentation/work_tasks_test.dart`
Expected: PASS. If `work_tasks_test.dart` pins the Work tasks group's exact links, add the two new links to its expectation.

- [ ] **Step 6: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: confirm worked days in bulk, one day per transaction

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The Leave sheet and a leave record's Properties

Spec §6.5: a list of leave records (date, type, hours, average used, percent, pay, state) with Properties and History; §4.3's notes in Working words. A leave record is corrected by voiding it and recording a replacement on the same date.

**Files:**
- Modify: `lib/features/work/data/projections/work_record_projection.dart`
- Modify: `lib/features/work/data/work_repository.dart` (`_loadRecord`)
- Create: `lib/features/work/presentation/leave_sheet.dart`
- Modify: `lib/features/work/presentation/work_register.dart`, `work_screen.dart`, `work_record_names.dart`, `work_tasks.dart`, `work_views.dart`
- Modify: `lib/core/desks/saved_views.dart` (`ViewSheets.workLeave`), `lib/app/desk_host.dart`
- Test: `test/features/work/presentation/leave_sheet_test.dart` (create), `test/features/work/data/leave_register_test.dart` (append)

**Interfaces:**
- Consumes: `LeaveSheetRow` (`register.leaveSheet`), `DayPlanService.correctLeave`, `leaveTypeLabel`, `formatMultiplier`.
- Produces:
  - `final class LeaveRecordProjection extends WorkRecordProjection { final LeaveRecord leave; }`
  - `LeaveSheet({required List<LeaveSheetRow> rows, required String? selectedId, required ValueChanged<WorkRecordRef> onOpen, ValueChanged<WorkRecordRef>? onProperties, required bool showVoid})`
  - `LeavePropertiesHost({required LeaveRecord leave, required LeavePay? pay, required LocalDate today})`
  - `String leavePercent(LeavePay? pay)` → `"100 %"`, `"62.06 %"` or `"Not paid by the employer"`; `String leaveAverage(LeavePay? pay)` → `"EUR 18.40/h"` or `"Agreement rate"`.
  - `ViewSheets.workLeave = 'work.leave'`, columns `date, type, hours, average, percent, pay, state`.

- [ ] **Step 1: Failing data test**

Append to `test/features/work/data/leave_register_test.dart`, inside its `main()`:

```dart
  test('a leave record loads as its own record', () async {
    final fixture = await ScheduleFixture.create();
    addTearDown(fixture.dispose);
    await fixture.saveDepot();
    await fixture.plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    final confirmed = await fixture.plans.confirm(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
    );
    final leave =
        ((confirmed as Committed<ConfirmedDay>).value as ConfirmedLeave).leave;
    final work = DriftWorkRepository(fixture.database, clock: fixture.clock);
    final record = await work.watchRecord(leave.id).first;
    expect(record, isA<LeaveRecordProjection>());
    expect((record! as LeaveRecordProjection).leave.date, leave.date);
  });
```

The test needs these imports; add those the file lacks:

```dart
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';

import '../../../support/schedule_fixture.dart';
```

- [ ] **Step 2: Run it to see it fail**

Run: `$F/flutter test test/features/work/data/leave_register_test.dart`
Expected: compile error: `LeaveRecordProjection` is not defined.

- [ ] **Step 3: Load leave as a record**

`work_record_projection.dart` (import `../../domain/leave.dart`):

```dart
final class LeaveRecordProjection extends WorkRecordProjection {
  LeaveRecordProjection(this.leave) : super(leave.id);

  final LeaveRecord leave;
}
```

`work_repository.dart` `_loadRecord`, before `return null;`:

```dart
    if (id is LeaveRecordId) {
      final value = await _leave.byId(id);
      return value == null ? null : LeaveRecordProjection(value);
    }
```

Run the data test again: PASS. Then run `$F/flutter analyze lib` — every exhaustive `switch` over `WorkRecordProjection` now needs a leave arm. Add these:

`work_record_names.dart`:

```dart
    LeaveRecordProjection(:final leave) =>
      '${leaveTypeLabel(leave.leaveType)} on ${leave.date}',
```

in `recordName`, and `LeaveRecordProjection() => EraIconKind.payPeriod,` in `recordIcon` (import `work_plan_view.dart` for `leaveTypeLabel`).

`work_tasks.dart` `workTaskGroups`:

```dart
    LeaveRecordProjection(:final leave) => [
      group('Leave tasks', [
        if (leave.isEffective)
          ('Correct this leave…', EraIconKind.correct, c.onProperties),
        ('Properties', EraIconKind.properties, c.onProperties),
      ]),
    ],
```

and in `RecordSummary`:

```dart
      LeaveRecordProjection(:final leave) => (
        'Leave',
        [
          ('Date', '${leave.date}'),
          ('Hours', formatDuration(leave.paidMinutes * 60)),
          ('State', leave.isEffective ? 'Confirmed' : 'Void'),
        ],
      ),
```

Any other switch the analyzer names (for example in `work_inspector.dart`) gets `LeaveRecordProjection() => const SizedBox.shrink()` — leave is drawn by `LeavePropertiesHost`, never by `WorkInspector`.

- [ ] **Step 4: Failing widget tests**

`test/features/work/presentation/leave_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';

import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';
import '../../../support/work_sheets.dart';

/// Marks 6 October as vacation and confirms it through the services.
Future<void> _vacation(WidgetTester tester, ScheduledApp app) async {
  await tester.runAsync(() async {
    final employment = EmploymentId(app.employment);
    await app.work.plans.markLeave(
      employment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await app.work.plans.confirm(employment, const LocalDate(2026, 10, 6));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Leave sheet lists confirmed leave with its pay', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester);
    await _vacation(tester, app);
    await chooseSheet(tester, 'Leave');
    expect(find.text('2026-10-06'), findsOneWidget);
    expect(find.text('Vacation'), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);
    // No confirmed work in July–September: the agreement rate, at 100 %.
    expect(find.text('Agreement rate'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('EUR 211.60'), findsOneWidget);
  });

  testWidgets('a confirmed leave day opens its Properties from the calendar', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester);
    await _vacation(tester, app);
    final cell = find.byKey(const ValueKey('work-calendar-day-2026-10-06'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('record=leave:'));
    expect(dialogTitled('Vacation on 2026-10-06 Properties'), findsOneWidget);
    expect(
      find.text(
        'No confirmed work in the 3 months before; using the agreement rate.',
      ),
      findsOneWidget,
    );
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('Correct… voids the leave and records the replacement', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester);
    await _vacation(tester, app);
    await chooseSheet(tester, 'Leave');
    await openRowProperties(tester, '2026-10-06');
    await tapInDialog(tester, find.text('Correct…'));
    await tester.tap(
      find.descendant(of: find.byType(EraDialog), matching: find.text('Sick')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('leave-correct-reason')),
      'Was ill, not on holiday',
    );
    await tester.tap(
      find.descendant(of: find.byType(EraDialog), matching: find.text('OK')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leave corrected.'), findsOneWidget);
    expect(find.text('Sick'), findsOneWidget);
  });
}
```

(EUR 211.60 = 11:30 h × EUR 18.40.)

- [ ] **Step 5: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/leave_sheet_test.dart`
Expected: FAIL: "Leave" shows "Not built yet".

- [ ] **Step 6: The sheet and the Properties**

`lib/features/work/presentation/leave_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/workbench/data_register.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/era_icons.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/office_controls.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart' show RationalMultiplier;
import '../domain/day_exception.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import 'day_sheet.dart' show dayProblem;
import 'record_history_panel.dart';
import 'work_controller.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';
import 'work_route_state.dart';
import 'work_sheets.dart' show workRowId;

WorkRecordRef _ref(LeaveRecord leave) =>
    WorkRecordRef(kind: WorkRecordKind.leave, id: leave.id);

/// "100 %", "62.06 %", or "Not paid by the employer".
String leavePercent(LeavePay? pay) {
  final factor = pay?.factor;
  if (pay == null) return '';
  if (factor == null) return 'Not paid by the employer';
  return '${formatMultiplier(RationalMultiplier(numerator: factor.numerator * 100, denominator: factor.denominator))} %';
}

/// The average hourly earnings a leave day used, or "Agreement rate".
String leaveAverage(LeavePay? pay) {
  if (pay == null) return '';
  final average = pay.average;
  if (average == null || average.paidSeconds == 0) return 'Agreement rate';
  final perHour = (average.minorUnits * 3600 / average.paidSeconds).round();
  return '${formatMoney(Money(minorUnits: perHour))}/h';
}

/// The Leave sheet (schedules spec 6.5).
final class LeaveSheet extends StatelessWidget {
  const LeaveSheet({
    required this.rows,
    required this.selectedId,
    required this.onOpen,
    this.onProperties,
    required this.showVoid,
    super.key,
  });

  final List<LeaveSheetRow> rows;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final ValueChanged<WorkRecordRef>? onProperties;
  final bool showVoid;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final row in rows)
        if (showVoid || row.record.isEffective) row,
    ]..sort((a, b) => a.record.date.compareTo(b.record.date));
    return DataRegister<LeaveSheetRow>(
      label: 'Leave',
      lines: [
        for (final row in visible)
          RowLine(
            row,
            state: row.record.isEffective ? RowState.normal : RowState.voided,
          ),
      ],
      sortedColumn: 'date',
      rowId: (row) => workRowId(_ref(row.record)),
      rowLabel: (row) =>
          '${leaveTypeLabel(row.record.leaveType)} on ${row.record.date}',
      selectedId: selectedId,
      onOpen: (row) => onOpen(_ref(row.record)),
      onActivate: onProperties == null
          ? null
          : (row) => onProperties!(_ref(row.record)),
      actions: onProperties == null
          ? null
          : (row) => [
              RowAction(
                label: 'Properties',
                isDefault: true,
                onInvoke: () => onProperties!(_ref(row.record)),
              ),
            ],
      columns: [
        RegisterColumn(
          key: 'date',
          label: 'Date',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.record.date.toString(),
        ),
        RegisterColumn(
          key: 'type',
          label: 'Type',
          kind: ColumnKind.text,
          width: 80,
          value: (row) => leaveTypeLabel(row.record.leaveType),
        ),
        RegisterColumn(
          key: 'hours',
          label: 'Hours',
          kind: ColumnKind.duration,
          width: 64,
          value: (row) => formatDuration(row.record.paidMinutes * 60),
        ),
        RegisterColumn(
          key: 'average',
          label: 'Average',
          description: 'Average hourly earnings used',
          kind: ColumnKind.derived,
          width: 104,
          value: (row) => leaveAverage(row.pay),
        ),
        RegisterColumn(
          key: 'percent',
          label: 'Percent',
          kind: ColumnKind.derived,
          width: 72,
          value: (row) => leavePercent(row.pay),
        ),
        RegisterColumn(
          key: 'pay',
          label: 'Pay',
          kind: ColumnKind.money,
          width: 88,
          value: (row) => row.pay == null ? '' : formatMoney(row.pay!.amount),
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 72,
          value: (row) => row.record.isEffective ? 'Confirmed' : 'Void',
        ),
      ],
    );
  }
}

/// A leave record's Properties: General and History (spec 3.6, 6.5).
final class LeavePropertiesHost extends ConsumerStatefulWidget {
  const LeavePropertiesHost({
    required this.leave,
    required this.pay,
    required this.today,
    super.key,
  });

  final LeaveRecord leave;
  final LeavePay? pay;
  final LocalDate today;

  @override
  ConsumerState<LeavePropertiesHost> createState() =>
      _LeavePropertiesHostState();
}

final class _LeavePropertiesHostState
    extends ConsumerState<LeavePropertiesHost> {
  String? _error;

  Future<void> _correct() async {
    final leave = widget.leave;
    final answer = await showDialog<
      ({LeaveType type, LocalDate? illness, String reason})
    >(
      context: context,
      builder: (_) => _CorrectLeaveDialog(leave: leave, today: widget.today),
    );
    if (answer == null || !mounted) return;
    final outcome = await ref
        .read(dayPlanServiceProvider)
        .correctLeave(
          leave.id,
          expected: leave.revision,
          leaveType: answer.type,
          illnessStartedOn: answer.illness,
          reason: answer.reason,
        );
    if (!mounted) return;
    if (outcome is Committed<LeaveRecord>) {
      StatusNoticeScope.read(context)?.value = 'Leave corrected.';
      ShellDialogScope.closeOf(context)?.call();
      return;
    }
    setState(
      () => _error = switch (outcome) {
        Invalid(:final fields) when fields.containsKey('reason') =>
          'Enter why the leave is corrected.',
        _ => dayProblem(outcome),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final pay = widget.pay;
    return RecordTabs(
      key: ValueKey(('tabs', leave.id)),
      record: _ref(leave),
      details: InspectorPane(
        children: [
          InspectorTitle(
            '${leaveTypeLabel(leave.leaveType)} on ${leave.date}',
            icon: EraIconKind.payPeriod,
          ),
          InspectorFacts(legend: 'Leave', [
            Fact('Date', leave.date.toString()),
            Fact.words('Type', leaveTypeLabel(leave.leaveType)),
            if (leave.illnessStartedOn case final start?)
              Fact('Illness started on', start.toString()),
            Fact('Hours', formatDuration(leave.paidMinutes * 60)),
            Fact('Average used', leaveAverage(pay)),
            Fact.words('Percent', leavePercent(pay)),
            Fact('Pay', pay == null ? '' : formatMoney(pay.amount)),
            Fact.words('State', leave.isEffective ? 'Confirmed' : 'Void'),
            if (leave.voidReason case final reason?)
              Fact.words('Void reason', reason),
          ]),
          if (pay != null && pay.usedFallback)
            const InspectorNote(
              'No confirmed work in the 3 months before; using the agreement '
              'rate.',
            ),
          if (pay != null && !pay.employerPaid)
            const InspectorNote(
              'Paid by the social insurer, not on your payslip.',
            ),
          const InspectorNote('Leave pay defaults, not legal advice.'),
          if (leave.isEffective)
            InspectorActions(
              children: [KeyButton(label: 'Correct…', onPressed: _correct)],
            ),
          if (_error case final error?)
            InspectorNote(error, tone: FactTone.negative),
        ],
      ),
    );
  }
}

final class _CorrectLeaveDialog extends StatefulWidget {
  const _CorrectLeaveDialog({required this.leave, required this.today});

  final LeaveRecord leave;
  final LocalDate today;

  @override
  State<_CorrectLeaveDialog> createState() => _CorrectLeaveDialogState();
}

final class _CorrectLeaveDialogState extends State<_CorrectLeaveDialog> {
  late var _type = widget.leave.leaveType;
  late LocalDate? _illness = widget.leave.illnessStartedOn;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Correct leave',
    body: EraFormScope(
      labelWidth: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The ${widget.leave.date} record is voided and replaced.'),
          const SizedBox(height: 7),
          EraRadioGroup<LeaveType>(
            options: const [
              EraRadioOption(LeaveType.vacation, 'Vacation'),
              EraRadioOption(LeaveType.sick, 'Sick'),
            ],
            groupValue: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          if (_type == LeaveType.sick) ...[
            const SizedBox(height: 7),
            EraDateField(
              fieldKey: const ValueKey('leave-correct-illness'),
              label: 'Illness started on',
              value: _illness,
              optional: true,
              today: widget.today,
              onChanged: (value) => setState(() => _illness = value),
            ),
          ],
          const SizedBox(height: 7),
          EraField(
            fieldKey: const ValueKey('leave-correct-reason'),
            controller: _reason,
            label: 'Reason',
          ),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: () => Navigator.of(context).pop((
          type: _type,
          illness: _type == LeaveType.sick ? _illness : null,
          reason: _reason.text,
        )),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}
```

- [ ] **Step 7: Show it**

`work_register.dart`: the leave arm

```dart
      WorkSheet.leave => LeaveSheet(
        rows: value.leaveSheet,
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
        showVoid: route.showVoid,
      ),
```

`work_screen.dart` `_inspector`, in the final switch before the generic record arm:

```dart
      WorkInspectorRecord(record: LeaveRecordProjection(:final leave)) =>
        LeavePropertiesHost(
          key: ValueKey(('leave', leave.id, leave.revision)),
          leave: leave,
          pay: state.register.leaveSheet
              .where((row) => row.record.id == leave.id)
              .firstOrNull
              ?.pay,
          today: _today,
        ),
```

(The calendar's register is scoped to its month and the leave's date is in it; with no scope the register holds every date.)

Saved views: `saved_views.dart` gains `static const workLeave = 'work.leave';` and a shape `workLeave: (filters: _workFilters, columns: ['date', 'type', 'hours', 'average', 'percent', 'pay', 'state'])`; `work_views.dart`'s `_sheets` gains `WorkSheet.leave: ViewSheets.workLeave`; in `desk_host.dart` replace `WorkSheet.leave` in the not-available arm with

```dart
      WorkSheet.leave => LeaveSheet(
        rows: register.leaveSheet,
        selectedId: null,
        onOpen: open,
        showVoid: state.showVoid,
      ),
```

Update Task 1's view test "the calendar and schedules sheets are not saved as views" only if it listed leave (it did not).

- [ ] **Step 8: Run the tests**

Run: `$F/flutter test test/features/work/presentation/leave_sheet_test.dart test/features/work/data/leave_register_test.dart test/features/work/presentation/work_views_test.dart`
Expected: PASS.

- [ ] **Step 9: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: list leave and open a leave day's Properties to correct it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The Schedules sheet

Spec §6.4: a list of schedules and versions (name, employment, in use from, until, cycle length, state In use / Ended / Future). The employment is the sheet's own, so its column is left out.

**Files:**
- Create: `lib/features/work/presentation/schedules_sheet.dart`
- Modify: `lib/features/work/presentation/work_register.dart`
- Test: `test/features/work/presentation/schedules_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `employmentSchedulesProvider` (Task 2).
- Produces:
  - `String scheduleState(WorkSchedule version, LocalDate today)` → `"In use"`, `"Ended"` or `"Future"`.
  - `SchedulesSheet({required List<WorkSchedule> versions, required LocalDate today, required String? selectedId, required ValueChanged<WorkRecordRef> onOpen, ValueChanged<WorkRecordRef>? onProperties})` — pure.
  - `SchedulesSheetHost({required EmploymentId employmentId, required LocalDate today, required String? selectedId, required ValueChanged<WorkRecordRef> onOpen, ValueChanged<WorkRecordRef>? onProperties, required VoidCallback? onNew})`.
  - Every version row opens its schedule (`record=schedule:<id>`), which edits the latest version.

- [ ] **Step 1: Failing tests**

`test/features/work/presentation/schedules_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/presentation/schedules_sheet.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

import '../../../support/schedule_views.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_sheets.dart';

WorkSchedule _version(int version, LocalDate from, LocalDate? until) {
  final base = depotSchedule();
  return WorkSchedule(
    id: base.id,
    employmentId: base.employmentId,
    name: base.name,
    timezoneId: base.timezoneId,
    version: version,
    cycleStart: base.cycleStart,
    inUseFrom: from,
    inUseUntil: until,
    shiftTypes: base.shiftTypes,
    blocks: base.blocks,
    createdAtUtc: base.createdAtUtc,
    revision: const Revision(0),
  );
}

void main() {
  test('a version is in use, ended or future on a date', () {
    final version = _version(
      1,
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 31),
    );
    expect(scheduleState(version, const LocalDate(2026, 10, 7)), 'In use');
    expect(scheduleState(version, const LocalDate(2026, 11, 1)), 'Ended');
    expect(scheduleState(version, const LocalDate(2026, 10, 1)), 'Future');
  });

  testWidgets('each version is a row; opening one opens its schedule', (
    tester,
  ) async {
    WorkRecordRef? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SchedulesSheet(
              versions: [
                _version(
                  1,
                  const LocalDate(2026, 10, 5),
                  const LocalDate(2026, 10, 31),
                ),
                _version(2, const LocalDate(2026, 11, 1), null),
              ],
              today: const LocalDate(2026, 10, 7),
              selectedId: null,
              onOpen: (_) {},
              onProperties: (record) => opened = record,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Depot rotation'), findsNWidgets(2));
    expect(find.text('In use'), findsOneWidget);
    expect(find.text('Future'), findsOneWidget);
    expect(find.text('12 days'), findsNWidgets(2));
    await tester.tap(find.text('2026-11-01'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened?.kind, WorkRecordKind.schedule);
    expect(opened?.id, depotScheduleId);
  });

  testWidgets('the sheet lists the employment\'s schedule', (tester) async {
    await pumpScheduledApp(tester);
    await chooseSheet(tester, 'Schedules');
    expect(find.text('Depot rotation'), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);
  });

  testWidgets('with no schedule it offers a new one', (tester) async {
    await pumpScheduledApp(
      tester,
      withSchedule: false,
      location: '/work?employment={employment}&sheet=schedules',
    );
    expect(find.text('No schedules yet'), findsOneWidget);
    expect(find.text('New schedule…'), findsWidgets);
  });
}
```

(add `import 'package:flutter/services.dart';`.)

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/schedules_sheet_test.dart`
Expected: compile error: `schedules_sheet.dart` does not exist.

- [ ] **Step 3: Implement**

`lib/features/work/presentation/schedules_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/data_register.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import 'work_controller.dart';
import 'work_route_state.dart';
import 'work_sheets.dart' show workRowId;

/// "In use", "Ended" or "Future" on [today].
String scheduleState(WorkSchedule version, LocalDate today) =>
    version.isInUseOn(today)
    ? 'In use'
    : version.inUseFrom.compareTo(today) > 0
    ? 'Future'
    : 'Ended';

WorkRecordRef _ref(WorkSchedule version) =>
    WorkRecordRef(kind: WorkRecordKind.schedule, id: version.id);

/// The Schedules sheet (schedules spec 6.4): every version of every
/// schedule, newest first within a schedule.
final class SchedulesSheet extends StatelessWidget {
  const SchedulesSheet({
    required this.versions,
    required this.today,
    required this.selectedId,
    required this.onOpen,
    this.onProperties,
    super.key,
  });

  final List<WorkSchedule> versions;
  final LocalDate today;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final ValueChanged<WorkRecordRef>? onProperties;

  @override
  Widget build(BuildContext context) {
    final latest = <ScheduleId, int>{};
    for (final value in versions) {
      final known = latest[value.id];
      if (known == null || value.version > known) {
        latest[value.id] = value.version;
      }
    }
    final rows = [...versions]
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        return byName != 0 ? byName : b.version.compareTo(a.version);
      });
    // The latest version's row is the schedule's own, so selecting the
    // schedule selects it; older versions are told apart by their number.
    String rowId(WorkSchedule value) => latest[value.id] == value.version
        ? workRowId(_ref(value))
        : '${workRowId(_ref(value))}@${value.version}';
    return DataRegister<WorkSchedule>(
      label: 'Schedules',
      lines: [for (final row in rows) RowLine(row)],
      sortedColumn: 'name',
      rowId: rowId,
      rowLabel: (row) => '${row.name}, version ${row.version}',
      selectedId: selectedId,
      onOpen: (row) => onOpen(_ref(row)),
      onActivate: onProperties == null
          ? null
          : (row) => onProperties!(_ref(row)),
      actions: onProperties == null
          ? null
          : (row) => [
              RowAction(
                label: 'Properties',
                isDefault: true,
                onInvoke: () => onProperties!(_ref(row)),
              ),
            ],
      columns: [
        RegisterColumn(
          key: 'name',
          label: 'Name',
          kind: ColumnKind.text,
          width: 160,
          value: (row) => row.name,
        ),
        RegisterColumn(
          key: 'version',
          label: 'Version',
          kind: ColumnKind.quantity,
          width: 64,
          value: (row) => '${row.version}',
        ),
        RegisterColumn(
          key: 'from',
          label: 'In use from',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => '${row.inUseFrom}',
        ),
        RegisterColumn(
          key: 'until',
          label: 'Until',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.inUseUntil?.toString() ?? '',
        ),
        RegisterColumn(
          key: 'cycle',
          label: 'Cycle',
          kind: ColumnKind.quantity,
          width: 72,
          value: (row) =>
              row.cycleLength == 1 ? '1 day' : '${row.cycleLength} days',
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 72,
          value: (row) => scheduleState(row, today),
        ),
      ],
    );
  }
}

/// The employment's schedules, live.
final class SchedulesSheetHost extends ConsumerWidget {
  const SchedulesSheetHost({
    required this.employmentId,
    required this.today,
    required this.selectedId,
    required this.onOpen,
    this.onProperties,
    required this.onNew,
    super.key,
  });

  final EmploymentId employmentId;
  final LocalDate today;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final ValueChanged<WorkRecordRef>? onProperties;

  /// Opens a new schedule; null until the employment has an agreement.
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(employmentSchedulesProvider(employmentId))) {
        AsyncData(:final value) when value.isEmpty => OperationalState(
          kind: OperationalStateKind.empty,
          title: 'No schedules yet',
          message:
              'Describe your rotation once to see every planned shift and '
              'its pay ahead of time.',
          action: onNew == null
              ? null
              : KeyButton(
                  label: 'New schedule…',
                  kind: KeyKind.primary,
                  onPressed: onNew,
                ),
        ),
        AsyncData(:final value) => SchedulesSheet(
          versions: value,
          today: today,
          selectedId: selectedId,
          onOpen: onOpen,
          onProperties: onProperties,
        ),
        AsyncError() => const OperationalState(
          kind: OperationalStateKind.unavailable,
          title: 'Schedules unavailable',
          message: 'Reload Work to read the schedules again.',
        ),
        _ => const OperationalState(
          kind: OperationalStateKind.loading,
          title: 'Reading schedules',
          message: 'Reading the local schedules.',
        ),
      };
}
```

`work_register.dart`: replace the placeholder (now only `WorkSheet.schedules`) with

```dart
      WorkSheet.schedules => SchedulesSheetHost(
        employmentId: value.scope.employmentId!,
        today: today ?? _deviceToday(),
        selectedId: selectedId,
        onOpen: onSelect,
        onProperties: onProperties,
        onNew: value.hasAgreement
            ? () => change(route.copyWith(adding: () => WorkAddKind.schedule))
            : null,
      ),
```

- [ ] **Step 4: Run them to see them pass**

Run: `$F/flutter test test/features/work/presentation/schedules_sheet_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: list schedules and their versions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Shift types dialogs

Spec §6.4: a Shift types dialog listing Name, Start, End, Breaks, Paid with **Add…**, **Edit…** and **Remove** (Remove disabled for a type the cycle uses); an Edit type dialog with Name, Start, End and "+1 day", and a Breaks list (start, length) with Add / Remove. The dialogs edit the schedule's draft; nothing is saved until the schedule is.

**Files:**
- Create: `lib/features/work/presentation/shift_types_dialog.dart`
- Test: `test/features/work/presentation/shift_types_dialog_test.dart` (create)

**Interfaces:**
- Consumes: `ShiftType`, `FixedBreak`, `checkShiftTimes` (`schedule.dart`).
- Produces:
  - `Future<List<ShiftType>?> editShiftTypes(BuildContext context, {required List<ShiftType> types, required Set<ShiftTypeId> used})` — null when cancelled.
  - `Future<ShiftType?> editShiftType(BuildContext context, {required ShiftTypeId id, ShiftType? initial, required Set<String> takenNames})`.
  - `ShiftTypeId nextShiftTypeId(Iterable<ShiftType> types)` → `type-1`, `type-2`, … unique within the list.
  - `String breakSummary(ShiftType type)` → `"30 min"`, `"2 breaks, 45 min"` or `"None"`; `String typeTimes(ShiftType type)` → `"19:00–07:00 +1"`.
  - Keys: `shift-type-row-$index`, `type-name`, `type-start`, `type-end`, `type-next-day`, `type-break-$i-start`, `type-break-$i-minutes`.

- [ ] **Step 1: Failing tests**

`test/features/work/presentation/shift_types_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/presentation/shift_types_dialog.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../../../support/era_pickers.dart';
import '../../../support/schedule_fixture.dart';

List<ShiftType>? _result;

Future<void> _open(
  WidgetTester tester, {
  List<ShiftType>? types,
  Set<ShiftTypeId> used = const {},
}) async {
  _result = null;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Scaffold(
          body: Builder(
            builder: (context) => KeyButton(
              label: 'Open',
              onPressed: () async => _result = await editShiftTypes(
                context,
                types: types ?? depotDraft().shiftTypes,
                used: used,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder _key(String label) => find.descendant(
  of: find.byType(EraDialog).last,
  matching: find.widgetWithText(KeyButton, label),
);

void main() {
  test('names and summaries read as the era list did', () {
    final night = depotDraft().shiftTypes.last;
    expect(typeTimes(night), '19:00–07:00 +1');
    expect(breakSummary(night), '30 min');
    expect(nextShiftTypeId(depotDraft().shiftTypes), const ShiftTypeId('type-1'));
  });

  testWidgets('lists the types with their times and paid time', (tester) async {
    await _open(tester);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('07:00–19:00'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
    expect(find.text('19:00–07:00 +1'), findsOneWidget);
    // Both are 12 hours with a 30-minute break.
    expect(find.text('11:30'), findsNWidgets(2));
  });

  testWidgets('a type the cycle uses cannot be removed', (tester) async {
    await _open(tester, used: {const ShiftTypeId('day')});
    await tester.tap(find.byKey(const ValueKey('shift-type-row-0')));
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(_key('Remove')).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('shift-type-row-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(_key('Remove')).onPressed, isNotNull);
  });

  testWidgets('Add… makes a new type; OK returns the list', (tester) async {
    await _open(tester);
    await tester.tap(_key('Add…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('type-name')), 'Late');
    await setTime(tester, 'type-start', const LocalTime(14, 0));
    await setTime(tester, 'type-end', const LocalTime(22, 0));
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsOneWidget);
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(_result!.map((type) => type.name), ['Day', 'Night', 'Late']);
    expect(_result!.last.id, const ShiftTypeId('type-1'));
  });

  testWidgets('a break outside the shift keeps the type dialog open', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('shift-type-row-0')));
    await tester.tap(_key('Edit…'));
    await tester.pumpAndSettle();
    await setTime(tester, 'type-break-0-start', const LocalTime(20, 0));
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Breaks must lie inside the shift, not overlap, and last 1 to 240 '
        'minutes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a name another type has is refused', (tester) async {
    await _open(tester);
    await tester.tap(_key('Add…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('type-name')), 'Day');
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Another shift type has this name.'), findsOneWidget);
  });

  testWidgets('Cancel returns nothing', (tester) async {
    await _open(tester);
    await tester.tap(_key('Cancel'));
    await tester.pumpAndSettle();
    expect(_result, isNull);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/shift_types_dialog_test.dart`
Expected: compile error: `shift_types_dialog.dart` does not exist.

- [ ] **Step 3: Implement**

`lib/features/work/presentation/shift_types_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/time/local_time.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/era_time_field.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import '../../../shared/workbench/office_controls.dart';
import '../domain/schedule.dart';
import 'employment_agreement_forms.dart' show formatClock;
import 'work_formats.dart';

/// "07:00–19:00", or "19:00–07:00 +1" for a shift that ends the next day.
String typeTimes(ShiftType type) =>
    '${formatClock(type.startMinute)}–${formatClock(type.endMinute % 1440)}'
    '${type.endDayOffset == 1 ? ' +1' : ''}';

/// "None", "30 min", or "2 breaks, 45 min".
String breakSummary(ShiftType type) => switch (type.breaks.length) {
  0 => 'None',
  1 => '${type.breakMinutes} min',
  final count => '$count breaks, ${type.breakMinutes} min',
};

/// The next "type-N" id not used in [types].
ShiftTypeId nextShiftTypeId(Iterable<ShiftType> types) {
  final taken = {for (final type in types) type.id.value};
  var n = 1;
  while (taken.contains('type-$n')) {
    n++;
  }
  return ShiftTypeId('type-$n');
}

/// The Shift types dialog (schedules spec 6.4); null when cancelled.
Future<List<ShiftType>?> editShiftTypes(
  BuildContext context, {
  required List<ShiftType> types,
  required Set<ShiftTypeId> used,
}) => showDialog<List<ShiftType>>(
  context: context,
  builder: (_) => _ShiftTypesDialog(types: types, used: used),
);

final class _ShiftTypesDialog extends StatefulWidget {
  const _ShiftTypesDialog({required this.types, required this.used});

  final List<ShiftType> types;
  final Set<ShiftTypeId> used;

  @override
  State<_ShiftTypesDialog> createState() => _ShiftTypesDialogState();
}

final class _ShiftTypesDialogState extends State<_ShiftTypesDialog> {
  late final _types = [...widget.types];
  int? _selected;

  Future<void> _edit(int? index) async {
    final initial = index == null ? null : _types[index];
    final edited = await editShiftType(
      context,
      id: initial?.id ?? nextShiftTypeId(_types),
      initial: initial,
      takenNames: {
        for (final type in _types)
          if (type.id != initial?.id) type.name.trim(),
      },
    );
    if (edited == null) return;
    setState(() {
      if (index == null) {
        _types.add(edited);
        _selected = _types.length - 1;
      } else {
        _types[index] = edited;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final selected = _selected;
    final style = skin.typography.body.copyWith(color: tokens.ink);
    Widget cell(String text, double width, {Color? ink, bool head = false}) =>
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: head
              ? BoxDecoration(
                  color: tokens.chrome,
                  border: Border(right: BorderSide(color: tokens.chromeLine)),
                )
              : null,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: head
                ? skin.typography.label.copyWith(color: tokens.ink)
                : style.copyWith(color: ink),
          ),
        );
    return EraDialog(
      title: 'Shift types',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    cell('Name', 90, head: true),
                    cell('Times', 104, head: true),
                    cell('Breaks', 90, head: true),
                    cell('Paid', 50, head: true),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final (index, type) in _types.indexed)
                        GestureDetector(
                          key: ValueKey('shift-type-row-$index'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selected = index),
                          onDoubleTap: () => _edit(index),
                          child: Container(
                            height: 20,
                            color: selected == index ? tokens.selWash : null,
                            child: Row(
                              children: [
                                for (final (text, width) in [
                                  (type.name, 90.0),
                                  (typeTimes(type), 104.0),
                                  (breakSummary(type), 90.0),
                                  (formatDuration(type.paidMinutes * 60), 50.0),
                                ])
                                  cell(
                                    text,
                                    width,
                                    ink: selected == index
                                        ? tokens.selInk
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            children: [
              KeyButton(label: 'Add…', onPressed: () => _edit(null)),
              KeyButton(
                label: 'Edit…',
                onPressed: selected == null ? null : () => _edit(selected),
              ),
              KeyButton(
                label: 'Remove',
                onPressed:
                    selected == null ||
                        widget.used.contains(_types[selected].id)
                    ? null
                    : () => setState(() {
                        _types.removeAt(selected);
                        _selected = null;
                      }),
              ),
            ],
          ),
          if (selected != null && widget.used.contains(_types[selected].id))
            const InspectorNote('The cycle uses this type, so it stays.'),
        ],
      ),
      actions: [
        KeyButton(
          label: 'OK',
          kind: KeyKind.primary,
          onPressed: () => Navigator.of(context).pop(_types),
        ),
        KeyButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The Edit type dialog (spec 6.4); null when cancelled.
Future<ShiftType?> editShiftType(
  BuildContext context, {
  required ShiftTypeId id,
  ShiftType? initial,
  required Set<String> takenNames,
}) => showDialog<ShiftType>(
  context: context,
  builder: (_) =>
      _EditTypeDialog(id: id, initial: initial, takenNames: takenNames),
);

final class _TypeBreak {
  _TypeBreak(this.start, int minutes)
    : minutes = TextEditingController(text: '$minutes');

  LocalTime start;
  final TextEditingController minutes;
}

final class _EditTypeDialog extends StatefulWidget {
  const _EditTypeDialog({
    required this.id,
    required this.initial,
    required this.takenNames,
  });

  final ShiftTypeId id;
  final ShiftType? initial;
  final Set<String> takenNames;

  @override
  State<_EditTypeDialog> createState() => _EditTypeDialogState();
}

final class _EditTypeDialogState extends State<_EditTypeDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late LocalTime _start = widget.initial?.start ?? const LocalTime(7, 0);
  late LocalTime _end = widget.initial?.end ?? const LocalTime(19, 0);
  late bool _nextDay = widget.initial?.endDayOffset == 1;
  late final _breaks = [
    for (final item in widget.initial?.breaks ?? const <FixedBreak>[])
      _TypeBreak(item.start, item.minutes),
  ];
  String? _nameError;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final item in _breaks) {
      item.minutes.dispose();
    }
    super.dispose();
  }

  void _ok() {
    final name = _name.text.trim();
    final startMinute = _start.hour * 60 + _start.minute;
    final type = ShiftType(
      id: widget.id,
      name: name,
      start: _start,
      end: _end,
      endDayOffset: _nextDay ? 1 : 0,
      breaks: [
        for (final item in _breaks)
          FixedBreak(
            start: item.start,
            // Earlier on the clock than the start: after midnight.
            dayOffset: item.start.hour * 60 + item.start.minute < startMinute
                ? 1
                : 0,
            minutes: int.tryParse(item.minutes.text.trim()) ?? 0,
          ),
      ],
    );
    final check = checkShiftTimes(type);
    setState(() {
      _nameError = name.isEmpty || name.length > 24
          ? 'Enter a name of up to 24 characters.'
          : widget.takenNames.contains(name)
          ? 'Another shift type has this name.'
          : null;
      _error = !check.times
          ? 'End must be after start and at most 24 hours later.'
          : !check.breaks
          ? 'Breaks must lie inside the shift, not overlap, and last 1 to '
                '240 minutes.'
          : null;
    });
    if (_nameError == null && _error == null) Navigator.of(context).pop(type);
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: widget.initial == null ? 'New shift type' : 'Edit shift type',
    body: EraFormScope(
      labelWidth: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraField(
            fieldKey: const ValueKey('type-name'),
            controller: _name,
            label: 'Name',
            error: _nameError,
            autofocus: true,
          ),
          const SizedBox(height: 7),
          EraTimeField(
            fieldKey: const ValueKey('type-start'),
            label: 'Start',
            value: _start,
            onChanged: (value) => setState(() => _start = value),
          ),
          const SizedBox(height: 7),
          EraTimeField(
            fieldKey: const ValueKey('type-end'),
            label: 'End',
            value: _end,
            onChanged: (value) => setState(() => _end = value),
          ),
          EraCheckBox(
            key: const ValueKey('type-next-day'),
            label: '+1 day',
            value: _nextDay,
            onChanged: (value) => setState(() => _nextDay = value),
          ),
          const SizedBox(height: 7),
          const Text('Breaks:'),
          for (final (index, item) in _breaks.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EraTimeField(
                    fieldKey: ValueKey('type-break-$index-start'),
                    semanticLabel: 'Break ${index + 1} start',
                    value: item.start,
                    onChanged: (value) => setState(() => item.start = value),
                  ),
                  IntrinsicWidth(
                    child: EraField(
                      fieldKey: ValueKey('type-break-$index-minutes'),
                      controller: item.minutes,
                      label: 'Minutes',
                      width: EraFieldWidth.short,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  KeyButton(
                    label: 'Remove',
                    onPressed: () => setState(() {
                      _breaks.remove(item);
                      item.minutes.dispose();
                    }),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          KeyButton(
            label: 'Add',
            onPressed: () => setState(
              () => _breaks.add(
                _TypeBreak(LocalTime((_start.hour + 4) % 24, _start.minute), 30),
              ),
            ),
          ),
          if (_error case final error?)
            InspectorNote(error, tone: FactTone.negative),
        ],
      ),
    ),
    actions: [
      KeyButton(label: 'OK', kind: KeyKind.primary, onPressed: _ok),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}
```

- [ ] **Step 4: Run them to see them pass**

Run: `$F/flutter test test/features/work/presentation/shift_types_dialog_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: edit a schedule's shift types in era dialogs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: The schedule editor

Spec §6.4: Schedule (Name, Employment, Timezone, Cycle starts on, In use from, In use until), Cycle — N days (blocks of count × type, reordered by the grip or Alt+↑/↓; Add block; Shift types…), Preview — Month YYYY (the read-only grid with the month's shift count, paid hours and expected pay). A new schedule opens from + Add, the task pane or the Schedules sheet with **Save schedule** / **Cancel**; an existing one is a Properties sheet with **OK / Cancel / Apply** and a History tab. Saving a version a confirmed day uses asks "Use the new cycle from:" (default tomorrow) and starts the next version.

**Files:**
- Create: `lib/features/work/presentation/schedule_editor.dart`
- Create: `lib/features/work/presentation/schedule_sheet_host.dart`
- Modify: `lib/features/work/presentation/work_screen.dart` (`_added`, `_inspector`, `_dialogTitle`, `_dialogSize`, `_taskGroups`)
- Test: `test/features/work/presentation/schedule_editor_test.dart` (create)

**Interfaces:**
- Consumes: `ScheduleService.create/update/delete`, `ScheduleDraft` (Part 1); `employmentSchedulesProvider`, `employmentRegisterProvider`, `zoneClocksProvider`, `timezoneServiceProvider`; `editShiftTypes`, `typeTimes`, `breakSummary` (Task 9); `WorkCalendar` (Task 3); `dayViews`, `monthTotals` (Task 2); `RecordHistoryPanel`.
- Produces:
  - `typedef SaveSchedule = Future<MutationOutcome<WorkSchedule>> Function(ScheduleDraft draft, {LocalDate? newVersionFrom});`
  - `ScheduleEditor({required EmploymentId employmentId, required String employmentName, required LocalDate today, required String defaultTimezoneId, required List<PayAgreement> agreements, required ZoneClocks zoneClocks, required TimezoneService timezones, required SaveSchedule onSave, WorkSchedule? initial, Future<MutationOutcome<WorkSchedule>> Function()? onDelete, WorkRecordRef? historyRecord})`
  - `Map<String, String> scheduleErrors(Map<String, List<FieldIssue>> fields)`; `int scheduleErrorTab(Iterable<String> fields)` (0 Schedule, 1 Cycle).
  - `Future<LocalDate?> askNewVersionFrom(BuildContext context, {required LocalDate today})`.
  - `ScheduleSheetHost({required EmploymentId employmentId, required String employmentName, required ScheduleId? scheduleId, required LocalDate today, required String defaultTimezoneId, required VoidCallback onCreated, required VoidCallback onDeleted})`.
  - Keys: `schedule-name`, `schedule-timezone`, `schedule-cycle-start`, `schedule-from`, `schedule-until`, `block-$i-count`, `block-$i-type`, `new-version-from`.

- [ ] **Step 1: Failing tests**

`test/features/work/presentation/schedule_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/schedule_editor.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';

import '../../../support/era_pickers.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';

const _properties =
    '/work?employment={employment}&sheet=schedules'
    '&record=schedule:{schedule}&mode=properties';

Finder _inSubDialog(String text) => find.descendant(
  of: find.byType(EraDialog).last,
  matching: find.text(text),
);

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  test('field issues are worded on their fields', () {
    final errors = scheduleErrors({
      'blocks[2].count': const [FieldIssue(FieldIssueCode.invalid)],
      'inUseFrom': const [FieldIssue(FieldIssueCode.conflict)],
    });
    expect(errors['blocks[2].count'], 'Enter 1 to 99.');
    expect(
      errors['inUseFrom'],
      'Another schedule of this employment is in use on these dates.',
    );
    expect(scheduleErrorTab(['blocks[2].count']), 1);
    expect(scheduleErrorTab(['blocks[2].count', 'name']), 0);
  });

  testWidgets('a schedule opens on its Properties with its tabs', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _properties);
    expect(dialogTitled('Depot rotation Properties'), findsOneWidget);
    for (final tab in ['Schedule', 'Cycle', 'Preview', 'History']) {
      expect(find.text(tab), findsWidgets);
    }
    await _tab(tester, 'Cycle');
    expect(find.text('Cycle — 12 days'), findsOneWidget);
    await _tab(tester, 'Preview');
    expect(find.text('Preview — October 2026'), findsOneWidget);
    expect(find.text('Day 07:00–19:00'), findsWidgets);
  });

  testWidgets('a count of 0 is refused on its row and brings Cycle forward', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _properties);
    await _tab(tester, 'Cycle');
    await tester.enterText(find.byKey(const ValueKey('block-1-count')), '0');
    await _tab(tester, 'Schedule');
    await tapInDialog(tester, find.text('Apply'));
    expect(find.text('Enter 1 to 99.'), findsOneWidget);
    expect(find.text('Cycle — 9 days'), findsOneWidget);
  });

  testWidgets('Alt+Down moves a block down the cycle', (tester) async {
    await pumpScheduledApp(tester, location: _properties);
    await _tab(tester, 'Cycle');
    await tester.tap(find.byKey(const ValueKey('block-0-count')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    // Day's row moved below the first row, which is now an Off block.
    expect(
      tester.getTopLeft(find.text('07:00–19:00, break 30 min')).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('block-0-count'))).dy + 10,
      ),
    );
  });

  testWidgets('a version a confirmed day uses asks where the new one starts; '
      'Cancel saves nothing', (tester) async {
    final app = await pumpScheduledApp(tester, location: _properties);
    await tester.runAsync(
      () => app.work.plans.confirm(
        EmploymentId(app.employment),
        const LocalDate(2026, 10, 5),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-name')),
      'Depot rotation 2',
    );
    await tapInDialog(tester, find.text('Apply'));
    expect(find.text('Schedule in use'), findsOneWidget);
    await tester.tap(_inSubDialog('Cancel'));
    await tester.pumpAndSettle();
    // Nothing saved; the sheet is still open and its edit still waiting.
    expect(dialogTitled('Depot rotation Properties'), findsOneWidget);
    expect(find.text('Schedule saved.'), findsNothing);
    await tapInDialog(tester, find.text('Apply'));
    await pickDate(tester, 'new-version-from', const LocalDate(2026, 10, 20));
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule saved.'), findsOneWidget);
  });

  testWidgets('New schedule… creates one and shows its Calendar', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester, withSchedule: false);
    await tester.tap(find.widgetWithText(TaskLink, 'New schedule…'));
    await tester.pumpAndSettle();
    expect(dialogTitled('New schedule'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('schedule-name')),
      'Depot rotation',
    );
    await pickDate(tester, 'schedule-cycle-start', const LocalDate(2026, 10, 5));
    await pickDate(tester, 'schedule-from', const LocalDate(2026, 10, 5));
    await _tab(tester, 'Cycle');
    await tester.tap(find.text('Shift types…'));
    await tester.pumpAndSettle();
    await tester.tap(_inSubDialog('Add…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('type-name')), 'Day');
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block-0-count')), '3');
    await tester.tap(find.byKey(const ValueKey('block-0-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add block'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block-1-count')), '3');
    await tapInDialog(tester, find.text('Save schedule'));
    expect(find.text('Schedule saved.'), findsOneWidget);
    expect(locationOf(app), contains('sheet=calendar'));
    expect(find.text('Day 07:00–19:00'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/schedule_editor_test.dart`
Expected: compile error: `schedule_editor.dart` does not exist.

- [ ] **Step 3: The editor**

`lib/features/work/presentation/schedule_editor.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/workbench/era_combo.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/property_sheet.dart';
import '../application/schedule_service.dart';
import '../domain/agreement.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay_premiums.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import 'employment_agreement_forms.dart' show staleMessage;
import 'record_history_panel.dart';
import 'shift_types_dialog.dart';
import 'work_calendar.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';
import 'work_route_state.dart';

typedef SaveSchedule =
    Future<MutationOutcome<WorkSchedule>> Function(
      ScheduleDraft draft, {
      LocalDate? newVersionFrom,
    });

const _scheduleTabFields = {
  'name',
  'timezoneId',
  'inUseFrom',
  'inUseUntil',
  'newVersionFrom',
  'schedule',
};

/// The words for each field a refused save names (schedules spec 7).
Map<String, String> scheduleErrors(Map<String, List<FieldIssue>> fields) => {
  for (final MapEntry(key: field, value: issues) in fields.entries)
    field: switch (field) {
      'name' => 'Enter a name of up to 60 characters.',
      'timezoneId' => 'Enter a timezone, for example Europe/Vilnius.',
      'inUseUntil' => 'In use until must be on or after In use from.',
      'inUseFrom' =>
        'Another schedule of this employment is in use on these dates.',
      'blocks' => 'The cycle needs 1 to 366 days.',
      'newVersionFrom'
          when issues.any((issue) => issue.code == FieldIssueCode.conflict) =>
        'Days up to that date are already confirmed. Choose a later date.',
      'newVersionFrom' => 'Choose a date after this version starts.',
      _ when field.endsWith('.count') => 'Enter 1 to 99.',
      _ when field.endsWith('.shiftTypeId') => 'Choose a shift type.',
      _ when field.startsWith('shiftTypes') =>
        'Check the shift types: names must differ and breaks lie inside '
            'their shift.',
      _ => 'Check the schedule.',
    },
};

/// The tab that shows the first problem: Schedule, else Cycle.
int scheduleErrorTab(Iterable<String> fields) =>
    fields.any(_scheduleTabFields.contains) ? 0 : 1;

/// "Use the new cycle from:" for a version confirmed days use (spec 6.4).
Future<LocalDate?> askNewVersionFrom(
  BuildContext context, {
  required LocalDate today,
}) => showDialog<LocalDate>(
  context: context,
  builder: (_) => _NewVersionDialog(today: today),
);

final class _NewVersionDialog extends StatefulWidget {
  const _NewVersionDialog({required this.today});

  final LocalDate today;

  @override
  State<_NewVersionDialog> createState() => _NewVersionDialogState();
}

final class _NewVersionDialogState extends State<_NewVersionDialog> {
  late LocalDate? _from = widget.today.addDays(1);

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Schedule in use',
    body: EraFormScope(
      labelWidth: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Confirmed days keep the cycle they were planned from.'),
          const SizedBox(height: 7),
          EraDateField(
            fieldKey: const ValueKey('new-version-from'),
            label: 'Use the new cycle from',
            value: _from,
            today: widget.today,
            onChanged: (value) => setState(() => _from = value),
          ),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: _from == null
            ? null
            : () => Navigator.of(context).pop(_from),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}

final class _Block {
  _Block(int count, this.type, VoidCallback onEdit)
    : count = TextEditingController(text: '$count') {
    this.count.addListener(onEdit);
  }

  final key = UniqueKey();
  final TextEditingController count;
  ShiftTypeId? type;
}

/// Six grip dots, the era's drag handle.
final class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    final ink = LifeOSSkinScope.of(context).tokens.muted;
    return SizedBox(
      width: 10,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var column = 0; column < 2; column++)
                  Container(width: 2, height: 2, color: ink),
              ],
            ),
        ],
      ),
    );
  }
}

/// A schedule's Schedule, Cycle and Preview pages, and its History.
final class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({
    required this.employmentId,
    required this.employmentName,
    required this.today,
    required this.defaultTimezoneId,
    required this.agreements,
    required this.zoneClocks,
    required this.timezones,
    required this.onSave,
    this.initial,
    this.onDelete,
    this.historyRecord,
    super.key,
  });

  final EmploymentId employmentId;
  final String employmentName;
  final LocalDate today;

  /// The system's zone, or '' when unknown: a schedule is never placed in a
  /// guessed zone.
  final String defaultTimezoneId;
  final List<PayAgreement> agreements;
  final ZoneClocks zoneClocks;
  final TimezoneService timezones;
  final SaveSchedule onSave;

  /// The latest version; null creates a schedule.
  final WorkSchedule? initial;

  /// Null while a confirmed day uses the schedule.
  final Future<MutationOutcome<WorkSchedule>> Function()? onDelete;
  final WorkRecordRef? historyRecord;

  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

final class _ScheduleEditorState extends State<ScheduleEditor> {
  late final _name = TextEditingController(text: widget.initial?.name)
    ..addListener(_edited);
  late final _timezone = TextEditingController(
    text: widget.initial?.timezoneId ?? widget.defaultTimezoneId,
  )..addListener(_edited);
  late final _employment = TextEditingController(text: widget.employmentName);
  late LocalDate _cycleStart = widget.initial?.cycleStart ?? widget.today;
  late LocalDate _from = widget.initial?.inUseFrom ?? widget.today;
  late LocalDate? _until = widget.initial?.inUseUntil;
  late List<ShiftType> _types = [...?widget.initial?.shiftTypes];
  late final List<_Block> _blocks = [
    for (final block in widget.initial?.blocks ?? const [CycleBlock(count: 1, shiftTypeId: null)])
      _Block(block.count, block.shiftTypeId, _edited),
  ];
  late LocalDate _previewMonth = widget.today.firstOfMonth;
  int _tab = 0;
  Map<String, String> _errors = const {};
  bool _saving = false;
  PropertySheetController? _sheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sheet = widget.initial == null
        ? null
        : PropertySheetScope.maybeOf(context);
    if (sheet != _sheet) {
      _sheet?.detach(_apply);
      _sheet = sheet?..attach(apply: _apply);
    }
  }

  @override
  void dispose() {
    _sheet?.detach(_apply);
    _name.dispose();
    _timezone.dispose();
    _employment.dispose();
    for (final block in _blocks) {
      block.count.dispose();
    }
    super.dispose();
  }

  void _edited() {
    _sheet?.markDirty(true);
    if (mounted) setState(() {});
  }

  void _set(VoidCallback change) {
    setState(change);
    _sheet?.markDirty(true);
  }

  ScheduleDraft _draft() => ScheduleDraft(
    employmentId: widget.employmentId,
    name: _name.text,
    timezoneId: _timezone.text,
    cycleStart: _cycleStart,
    inUseFrom: _from,
    inUseUntil: _until,
    shiftTypes: List.unmodifiable(_types),
    blocks: [
      for (final block in _blocks)
        CycleBlock(
          count: int.tryParse(block.count.text.trim()) ?? 0,
          shiftTypeId: block.type,
        ),
    ],
  );

  Future<bool> _apply() async => await _save() is Committed<WorkSchedule>;

  /// Saves; null when the owner cancelled the new-version prompt, which
  /// saves nothing and keeps every edit.
  Future<MutationOutcome<WorkSchedule>?> _save() async {
    LocalDate? from;
    if (widget.initial?.usedByConfirmedDay ?? false) {
      from = await askNewVersionFrom(context, today: widget.today);
      if (from == null) return null;
    }
    setState(() {
      _saving = true;
      _errors = const {};
    });
    final outcome = await widget.onSave(_draft(), newVersionFrom: from);
    if (!mounted) return outcome;
    setState(() {
      _saving = false;
      _errors = switch (outcome) {
        Committed() => const {},
        Invalid(:final fields) => scheduleErrors(fields),
        Stale() => const {'schedule': staleMessage},
        Missing() => const {'schedule': 'This schedule no longer exists.'},
        Unavailable() || Uncertain() => const {
          'schedule': 'Local storage is unavailable. Try again.',
        },
      };
      if (_errors.isNotEmpty) _tab = scheduleErrorTab(_errors.keys);
    });
    return outcome;
  }

  Future<void> _delete() async {
    final name = widget.initial!.name;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => EraDialog(
        title: 'Delete schedule',
        body: Text("Delete $name? No confirmed day uses it. This can't be undone."),
        actions: [
          KeyButton(
            label: 'Delete',
            kind: KeyKind.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          KeyButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final outcome = await widget.onDelete!();
    if (!mounted || outcome is Committed<WorkSchedule>) return;
    setState(
      () => _errors = {
        'schedule': outcome is Stale<WorkSchedule>
            ? staleMessage
            : 'The schedule could not be deleted. A confirmed day may use it.',
      },
    );
  }

  Future<void> _shiftTypes() async {
    final edited = await editShiftTypes(
      context,
      types: _types,
      used: {for (final block in _blocks) ?block.type},
    );
    if (edited != null) _set(() => _types = edited);
  }

  void _reorder(int from, int to) => _set(() {
    final target = to > from ? to - 1 : to;
    _blocks.insert(target, _blocks.removeAt(from));
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Schedule',
      'Cycle',
      'Preview',
      if (widget.historyRecord != null) 'History',
    ];
    final page = switch (_tab) {
      0 => _scheduleTab(),
      1 => _cycleTab(),
      2 => _previewTab(),
      _ => RecordHistoryPanel(record: widget.historyRecord!),
    };
    final tabs = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PropertySheetTabs(
          labels: labels,
          selectedIndex: _tab,
          onSelected: (index) => setState(() => _tab = index),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: MillenniumColors.page,
              border: Border(
                left: BorderSide(color: MillenniumColors.tabLine),
                right: BorderSide(color: MillenniumColors.tabLine),
                bottom: BorderSide(color: MillenniumColors.tabLine),
              ),
            ),
            child: page,
          ),
        ),
      ],
    );
    if (widget.initial != null) return tabs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tabs),
        const SizedBox(height: 7),
        FormFooter(
          children: [
            KeyButton(
              label: 'Save schedule',
              kind: KeyKind.primary,
              onPressed: _saving ? null : _save,
            ),
            const DialogCancelKey(),
          ],
        ),
      ],
    );
  }

  Widget _note(String? text) => text == null
      ? const SizedBox.shrink()
      : InspectorNote(text, tone: FactTone.negative);

  Widget _scheduleTab() {
    final initial = widget.initial;
    const gap = SizedBox(height: 7);
    return ListView(
      padding: inspectorInset,
      children: [
        _note(_errors['schedule']),
        _note(_errors['newVersionFrom']),
        GroupBox(
          legend: 'Schedule',
          child: EraFormScope(
            labelWidth: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EraField(
                  fieldKey: const ValueKey('schedule-name'),
                  controller: _name,
                  label: 'Name',
                  error: _errors['name'],
                  autofocus: initial == null,
                ),
                gap,
                // A schedule stays with its employment (see the plan's
                // changes from the spec).
                EraFormScope(
                  labelWidth: 100,
                  enabled: false,
                  child: EraField(controller: _employment, label: 'Employment'),
                ),
                gap,
                EraField(
                  fieldKey: const ValueKey('schedule-timezone'),
                  controller: _timezone,
                  label: 'Timezone',
                  error: _errors['timezoneId'],
                  hint: 'For example Europe/Vilnius',
                ),
                gap,
                EraDateField(
                  fieldKey: const ValueKey('schedule-cycle-start'),
                  label: 'Cycle starts on',
                  value: _cycleStart,
                  today: widget.today,
                  onChanged: (value) =>
                      _set(() => _cycleStart = value ?? _cycleStart),
                ),
                gap,
                EraDateField(
                  fieldKey: const ValueKey('schedule-from'),
                  label: 'In use from',
                  value: _from,
                  today: widget.today,
                  error: _errors['inUseFrom'],
                  onChanged: (value) => _set(() => _from = value ?? _from),
                ),
                gap,
                EraDateField(
                  fieldKey: const ValueKey('schedule-until'),
                  label: 'In use until',
                  value: _until,
                  optional: true,
                  today: widget.today,
                  error: _errors['inUseUntil'],
                  onChanged: (value) => _set(() => _until = value),
                ),
              ],
            ),
          ),
        ),
        if (initial != null) ...[
          InspectorFacts(legend: 'Version', [
            Fact('Version', '${initial.version}'),
            Fact.words(
              'Confirmed days',
              initial.usedByConfirmedDay ? 'Use this version' : 'None yet',
            ),
          ]),
          if (initial.usedByConfirmedDay)
            const InspectorNote(
              'Confirmed days keep this version. Saving a change starts a '
              'new version from a date you choose.',
            ),
        ],
        if (widget.onDelete != null && initial != null)
          InspectorActions(
            children: [
              KeyButton(label: 'Delete schedule…', onPressed: _delete),
            ],
          ),
      ],
    );
  }

  Widget _cycleTab() {
    final days = _blocks.fold(
      0,
      (sum, block) => sum + (int.tryParse(block.count.text.trim()) ?? 0),
    );
    final typeProblem = _errors.entries
        .where((entry) => entry.key.startsWith('shiftTypes'))
        .map((entry) => entry.value)
        .firstOrNull;
    return ListView(
      padding: inspectorInset,
      children: [
        _note(_errors['blocks']),
        _note(typeProblem),
        GroupBox(
          legend: 'Cycle — ${days == 1 ? '1 day' : '$days days'}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _reorder,
                children: [
                  for (final (index, block) in _blocks.indexed)
                    _blockRow(index, block),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                children: [
                  KeyButton(
                    label: 'Add block',
                    onPressed: () =>
                        _set(() => _blocks.add(_Block(1, null, _edited))),
                  ),
                  KeyButton(label: 'Shift types…', onPressed: _shiftTypes),
                ],
              ),
              if (_types.isEmpty)
                const InspectorNote(
                  'Add shift types first, then choose them for the blocks.',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _blockRow(int index, _Block block) {
    final skin = LifeOSSkinScope.of(context);
    final type = block.type == null
        ? null
        : _types.where((value) => value.id == block.type).firstOrNull;
    final error =
        _errors['blocks[$index].count'] ??
        _errors['blocks[$index].shiftTypeId'];
    final summary = type == null
        ? 'Off'
        : '${typeTimes(type)}, '
              '${type.breaks.isEmpty ? 'no break' : 'break ${breakSummary(type)}'}';
    return Focus(
      key: block.key,
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || !HardwareKeyboard.instance.isAltPressed) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && index > 0) {
          _reorder(index, index - 1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            index < _blocks.length - 1) {
          _reorder(index, index + 2);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Semantics(
                    label: 'Move block ${index + 1}: drag, or Alt+Up and '
                        'Alt+Down',
                    child: const _Grip(),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: EraFieldWidth.short,
                  child: Semantics(
                    label: 'Block ${index + 1} days',
                    textField: true,
                    child: TextField(
                      key: ValueKey('block-$index-count'),
                      controller: block.count,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                const Text(' × '),
                EraCombo<ShiftTypeId?>(
                  key: ValueKey('block-$index-type'),
                  semanticLabel: 'Block ${index + 1} shift type',
                  value: block.type,
                  minWidth: 100,
                  items: [
                    const EraComboItem<ShiftTypeId?>(null, 'Off'),
                    for (final value in _types)
                      EraComboItem<ShiftTypeId?>(value.id, value.name),
                  ],
                  onSelected: (value) => _set(() => block.type = value),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: skin.typography.body.copyWith(
                      color: skin.tokens.ink,
                    ),
                  ),
                ),
                KeyButton(
                  label: 'Remove',
                  onPressed: _blocks.length == 1
                      ? null
                      : () => _set(() {
                          _blocks.removeAt(index);
                          block.count.dispose();
                        }),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                  error,
                  style: skin.typography.body.copyWith(
                    color: skin.tokens.negative,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewTab() {
    final month = _previewMonth;
    final draft = _draft();
    final schedule = WorkSchedule(
      id: const ScheduleId('preview'),
      employmentId: widget.employmentId,
      name: draft.name.trim().isEmpty ? 'Preview' : draft.name,
      timezoneId: draft.timezoneId.trim(),
      version: 1,
      cycleStart: draft.cycleStart,
      inUseFrom: draft.inUseFrom,
      inUseUntil: draft.inUseUntil,
      shiftTypes: draft.shiftTypes,
      blocks: draft.blocks,
      createdAtUtc: DateTime.utc(2000),
      revision: const Revision(0),
    );
    Widget body;
    if (validateSchedule(schedule).isNotEmpty) {
      body = const Text('Complete the schedule to see its preview.');
    } else {
      final grid = monthGridDays(month);
      List<PlannedDay>? plan;
      try {
        plan = planDays(
          from: grid.first,
          to: grid.last,
          schedules: [schedule],
          exceptions: const [],
          confirmedDates: const {},
          zoneClocks: widget.zoneClocks,
        );
      } on Object {
        plan = null;
      }
      if (plan == null) {
        body = const Text(
          'Enter a timezone LifeOS knows, for example Europe/Vilnius.',
        );
      } else {
        final days = dayViews(
          from: month.firstOfMonth,
          to: month.lastOfMonth,
          plan: plan,
          shifts: const [],
          leave: const [],
          schedules: [schedule],
          timezones: widget.timezones,
        );
        final totals = monthTotals(
          days.values,
          price: (shift) => plannedPay(
            shift,
            agreements: widget.agreements,
            employmentId: widget.employmentId,
            zoneClocks: widget.zoneClocks,
          ),
        );
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 300,
              child: WorkCalendar(
                month: month,
                today: widget.today,
                days: days,
                readOnly: true,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${totals.shifts == 1 ? '1 shift' : '${totals.shifts} shifts'}'
              ' · ${formatDuration(totals.paidSeconds)} paid · '
              '${formatMoney(totals.planned)} expected',
            ),
          ],
        );
      }
    }
    return ListView(
      padding: inspectorInset,
      children: [
        GroupBox(
          legend: 'Preview — ${eraMonthTitle(month)}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StepKey(
                    forward: false,
                    semanticLabel: 'Previous month',
                    onPressed: () => setState(
                      () => _previewMonth = month.addMonthsClamped(-1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  StepKey(
                    forward: true,
                    semanticLabel: 'Next month',
                    onPressed: () => setState(
                      () => _previewMonth = month.addMonthsClamped(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              body,
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: The host**

`lib/features/work/presentation/schedule_sheet_host.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/workbench/operational_state.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import 'schedule_editor.dart';
import 'work_controller.dart';
import 'work_route_state.dart';

/// Binds the schedule editor to [ScheduleService]: a new schedule when
/// [scheduleId] is null, otherwise that schedule's latest version.
final class ScheduleSheetHost extends ConsumerWidget {
  const ScheduleSheetHost({
    required this.employmentId,
    required this.employmentName,
    required this.scheduleId,
    required this.today,
    required this.defaultTimezoneId,
    required this.onCreated,
    required this.onDeleted,
    super.key,
  });

  final EmploymentId employmentId;
  final String employmentName;
  final ScheduleId? scheduleId;
  final LocalDate today;
  final String defaultTimezoneId;
  final VoidCallback onCreated;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final register = switch (ref.watch(
      employmentRegisterProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final agreements = [
      for (final row in register?.agreementSheet ?? const []) row.agreement,
    ];
    final zones = ref.watch(zoneClocksProvider);
    final timezones = ref.watch(timezoneServiceProvider);
    final service = ref.read(scheduleServiceProvider);
    void notice(String text) => StatusNoticeScope.read(context)?.value = text;

    final id = scheduleId;
    if (id == null) {
      return ScheduleEditor(
        key: const ValueKey('new-schedule'),
        employmentId: employmentId,
        employmentName: employmentName,
        today: today,
        defaultTimezoneId: defaultTimezoneId,
        agreements: agreements,
        zoneClocks: zones,
        timezones: timezones,
        onSave: (draft, {newVersionFrom}) async {
          final outcome = await service.create(draft);
          if (outcome is Committed<WorkSchedule>) {
            notice('Schedule saved.');
            onCreated();
          }
          return outcome;
        },
      );
    }
    return switch (ref.watch(employmentSchedulesProvider(employmentId))) {
      AsyncData(:final value) => () {
        final versions = [
          for (final version in value)
            if (version.id == id) version,
        ];
        if (versions.isEmpty) {
          return const OperationalState(
            kind: OperationalStateKind.unavailable,
            title: 'Schedule unavailable',
            message: 'This schedule no longer exists.',
          );
        }
        final latest = versions.reduce(
          (a, b) => a.version >= b.version ? a : b,
        );
        final used = versions.any((version) => version.usedByConfirmedDay);
        return ScheduleEditor(
          key: ValueKey(('schedule', id, latest.version, latest.revision)),
          employmentId: employmentId,
          employmentName: employmentName,
          today: today,
          defaultTimezoneId: defaultTimezoneId,
          agreements: agreements,
          zoneClocks: zones,
          timezones: timezones,
          initial: latest,
          // History is kept per version (work_history.dart).
          historyRecord: WorkRecordRef(
            kind: WorkRecordKind.schedule,
            id: ScheduleId('${id.value}@${latest.version}'),
          ),
          onSave: (draft, {newVersionFrom}) async {
            final outcome = await service.update(
              id,
              expected: latest.revision,
              draft: draft,
              newVersionFrom: newVersionFrom,
            );
            if (outcome is Committed<WorkSchedule>) notice('Schedule saved.');
            return outcome;
          },
          onDelete: used
              ? null
              : () async {
                  final outcome = await service.delete(
                    id,
                    expected: latest.revision,
                  );
                  if (outcome is Committed<WorkSchedule>) {
                    notice('Schedule deleted.');
                    onDeleted();
                  }
                  return outcome;
                },
        );
      }(),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Schedule unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the schedule',
        message: 'Reading the local schedule.',
      ),
    };
  }
}
```

- [ ] **Step 5: Open it from the route, the task pane and + Add**

`work_screen.dart` (import `schedule_sheet_host.dart`):

- `_added`: add an arm before the final `null` arm

```dart
      case WorkAddKind.schedule:
        return ScheduleSheetHost(
          key: ValueKey(('add-schedule', employmentId)),
          employmentId: employmentId,
          employmentName: register.employment?.name ?? 'Employment',
          scheduleId: null,
          today: _today,
          defaultTimezoneId: widget.systemTimezoneId ?? '',
          onCreated: () => _go(
            WorkRouteState(
              employmentId: employmentId,
              scope: null,
              record: null,
              mode: WorkInspectorMode.inspect,
              sheet: WorkSheet.calendar,
            ),
          ),
          onDeleted: () {},
        );
```

  and leave `WorkAddKind.extraShift || WorkAddKind.leave` returning null until Task 11 (add them to the `null` arm's pattern).
- `_inspector`, after the confirm branch:

```dart
    if (route.record case WorkRecordRef(
      kind: WorkRecordKind.schedule,
      id: final ScheduleId id,
    ) when employmentId != null && route.mode == WorkInspectorMode.properties) {
      return ScheduleSheetHost(
        key: ValueKey(('schedule-sheet', id)),
        employmentId: employmentId,
        employmentName: state.register.employment?.name ?? 'Employment',
        scheduleId: id,
        today: _today,
        defaultTimezoneId: widget.systemTimezoneId ?? '',
        onCreated: () {},
        onDeleted: _closeDialog,
      );
    }
```

- `_dialogTitle`: before the final `switch (route.mode)`:

```dart
    if (route.adding == WorkAddKind.schedule) return 'New schedule';
    if (route.record case WorkRecordRef(
      kind: WorkRecordKind.schedule,
      :final id,
    )) {
      final name = widget.schedules
          .where((value) => value.id == id)
          .map((value) => value.name)
          .firstOrNull;
      return '${name ?? 'Schedule'} Properties';
    }
```

- `_dialogSize`: `if (state.route.adding == WorkAddKind.schedule || state.route.record?.kind == WorkRecordKind.schedule) return const Size(560, 620);` before the properties size.
- `_taskGroups`: `onNewSchedule: register.hasAgreement ? () => _go(route.copyWith(adding: () => WorkAddKind.schedule)) : null,`

- [ ] **Step 6: Run the tests**

Run: `$F/flutter test test/features/work/presentation/schedule_editor_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 7: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: create and edit schedules: cycle, shift types, preview, versions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Books sub-sheets, the status panel and + Add

Spec §5: Books lists Calendar, Shifts, Leave, Schedules, Pay periods, Payslips, Agreements under the open employment, whose badge counts its days to confirm; the status bar says "N days to confirm"; + Add offers Manual shift, Extra shift…, Leave…, Pay period, Payslip, Employment, Agreement, Schedule.

**Files:**
- Modify: `lib/shared/shell/book_tree.dart` (`TreeSheet.children`, `_SheetRow.depth`)
- Modify: `lib/shared/shell/status_line.dart` (`StatusSnapshot.daysToConfirm`)
- Modify: `lib/app/shell_host.dart` (`ShellChromeHost`)
- Modify: `lib/features/work/presentation/day_sheet_host.dart` (`AddDayHost`), `work_screen.dart` (`_added`, `_dialogTitle`)
- Test: `test/shared/shell/book_tree_test.dart`, `test/shared/shell/status_line_test.dart` (append), `test/integration/schedule_shell_test.dart` (create)

**Interfaces:**
- Consumes: `daysToConfirmProvider`, `planInputsProvider`, `dayPlanServiceProvider`; `DayTimesForm`, `dayTimesOfType`, `dayProblem` (Task 5); `SheetPicker.labels` (Task 1).
- Produces:
  - `TreeSheet({..., List<TreeSheet> children = const []})`, drawn one indent deeper under their sheet.
  - `StatusSnapshot({..., int daysToConfirm = 0})`; panel text "1 day to confirm" / "N days to confirm".
  - `enum AddDayKind { extraShift, leave }`; `AddDayHost({required EmploymentId employmentId, required AddDayKind kind, required LocalDate today})`; date field key `add-day-date`.

- [ ] **Step 1: Failing tests**

Append to `test/shared/shell/book_tree_test.dart` (inside `main()`; reuse its imports):

```dart
  testWidgets('an open sheet lists its own sheets one level deeper', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SizedBox(
              width: 228,
              child: BookTree(
                nodes: const [
                  TreeArea(
                    area: LifeOSArea.work,
                    route: '/work',
                    built: true,
                    children: [
                      TreeSheet(
                        label: 'Synthetic depot',
                        route: '/work?employment=e',
                        needsYou: 2,
                        children: [
                          TreeSheet(
                            label: 'Calendar',
                            route: '/work?employment=e&sheet=calendar',
                          ),
                          TreeSheet(
                            label: 'Leave',
                            route: '/work?employment=e&sheet=leave',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                selectedRoute: null,
                onOpen: (route) => opened = route,
              ),
            ),
          ),
        ),
      ),
    );
    final depot = tester.getTopLeft(find.text('Synthetic depot'));
    final calendar = tester.getTopLeft(find.text('Calendar'));
    expect(calendar.dx, greaterThan(depot.dx));
    expect(calendar.dy, greaterThan(depot.dy));
    await tester.tap(find.text('Leave'));
    expect(opened, '/work?employment=e&sheet=leave');
  });
```

Append to `test/shared/shell/status_line_test.dart` (inside `main()`; copy that file's existing pump wrapper):

```dart
  testWidgets('days to confirm have a panel of their own', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(
            body: StatusLine(snapshot: StatusSnapshot(daysToConfirm: 3)),
          ),
        ),
      ),
    );
    expect(find.text('3 days to confirm'), findsOneWidget);
  });
```

`test/integration/schedule_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../support/era_pickers.dart';
import '../support/scheduled_app.dart';

void main() {
  testWidgets('the status bar and Books count the days to confirm', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    // Today is 7 October: the 5th and 6th are past and unconfirmed.
    expect(find.text('2 days to confirm'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is CountBadge && widget.count == 2),
      findsOneWidget,
    );
  });

  testWidgets('Books lists the open employment\'s sheets', (tester) async {
    final app = await pumpScheduledApp(tester);
    for (final sheet in ['Shifts', 'Leave', 'Schedules', 'Pay periods']) {
      expect(find.text(sheet), findsWidgets);
    }
    await tester.tap(find.text('Schedules').first);
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('sheet=schedules'));
  });

  testWidgets('+ Add › Extra shift… adds one on an Off day', (tester) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra shift…').last);
    await tester.pumpAndSettle();
    await pickDate(tester, 'add-day-date', const LocalDate(2026, 10, 8));
    await tester.tap(find.text('Add extra shift'));
    await tester.pumpAndSettle();
    expect(find.text('Extra shift added.'), findsOneWidget);
    expect(find.text('Extra 07:00–19:00'), findsOneWidget);
  });

  testWidgets('+ Add › Extra shift… on a planned day says to change it', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra shift…').last);
    await tester.pumpAndSettle();
    await pickDate(tester, 'add-day-date', const LocalDate(2026, 10, 6));
    await tester.tap(find.text('Add extra shift'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The schedule plans a shift on this date. Open the day to change it '
        'instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('+ Add › Leave… marks a planned day as leave', (tester) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave…').last);
    await tester.pumpAndSettle();
    await pickDate(tester, 'add-day-date', const LocalDate(2026, 10, 11));
    await tester.tap(find.text('Mark as leave'));
    await tester.pumpAndSettle();
    expect(find.text('Marked as leave.'), findsOneWidget);
    expect(find.text('Vacation'), findsOneWidget);
  });

  testWidgets('+ Add lists the schedule entries in the spec\'s order', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    final labels = [
      'Manual shift',
      'Extra shift…',
      'Leave…',
      'Pay period',
      'Payslip',
      'Employment',
      'Agreement',
      'Schedule',
    ];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label).last).dy,
    ];
    expect(tops, [...tops]..sort());
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/shared/shell/book_tree_test.dart test/shared/shell/status_line_test.dart test/integration/schedule_shell_test.dart`
Expected: compile errors (`children`, `daysToConfirm`) and then failures.

- [ ] **Step 3: Nested sheets in Books**

`book_tree.dart`: `TreeSheet` gains `this.children = const []` and

```dart
  /// The sheet's own sheets, such as an employment's Calendar and Shifts,
  /// drawn one level deeper.
  final List<TreeSheet> children;
```

`_SheetRow`'s `indent` becomes `final int depth;` (0 at the top, 1 under an area or group, 2 under a sheet), and its row starts with `if (depth > 0) SizedBox(width: 20.0 * depth),` in place of `if (indent) const SizedBox(width: 20),`. In `BookTree.build`, every `indent: true` becomes `depth: 1`, `indent: false` becomes `depth: 0`, and under an area each child is followed by its own children:

```dart
          TreeArea() => [
            _AreaRow(
              node: node,
              selected: node.route == selectedRoute,
              onOpen: onOpen,
            ),
            for (final child in node.children) ...[
              _SheetRow(
                node: child,
                depth: 1,
                selected: child.route == selectedRoute,
                onOpen: onOpen,
              ),
              for (final sheet in child.children)
                _SheetRow(
                  node: sheet,
                  depth: 2,
                  selected: sheet.route == selectedRoute,
                  onOpen: onOpen,
                ),
            ],
          ],
```

- [ ] **Step 4: The status panel**

`status_line.dart`: `StatusSnapshot` gains `this.daysToConfirm = 0` and `final int daysToConfirm;` ("Past planned days not yet confirmed (schedules spec 5)."); in `StatusLine.build`, before the `needsYou` panel:

```dart
            if (snapshot.daysToConfirm > 0)
              _Panel(
                child: Text(
                  snapshot.daysToConfirm == 1
                      ? '1 day to confirm'
                      : '${snapshot.daysToConfirm} days to confirm',
                  style: style,
                ),
              ),
```

- [ ] **Step 5: The shell host**

`shell_host.dart` (import `work_toolbar_controls.dart` and `work_register_projection.dart` if not already):

```dart
    int toConfirm(Employment value) =>
        switch (ref.watch(daysToConfirmProvider(value.id))) {
          AsyncData(:final value) => value.length,
          _ => 0,
        };
    String sheetRoute(Employment value, WorkSheet sheet) => workRouteUri(
      WorkRouteState(
        employmentId: value.id,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
        sheet: sheet,
      ),
    ).toString();
```

Each employment's `TreeSheet` becomes

```dart
            TreeSheet(
              label: employment.name,
              route: employmentRoute(employment),
              needsYou: toConfirm(employment),
              children: employment.id.value == employmentId
                  ? [
                      for (final MapEntry(key: sheet, value: label)
                          in SheetPicker.labels.entries)
                        TreeSheet(
                          label: label,
                          route: sheetRoute(employment, sheet),
                        ),
                    ]
                  : const [],
            ),
```

the `selected` route prefers the open sheet:

```dart
    final sheetText = location.path == '/work'
        ? location.queryParameters['sheet']
        : null;
    final openSheet = WorkSheet.values
        .where((value) => value.name == sheetText)
        .firstOrNull;
```

and in the `'/work' when employmentId != null` arm map with `(value) => openSheet == null ? employmentRoute(value) : sheetRoute(value, openSheet)`.

The status line: `status: StatusLine(snapshot: StatusSnapshot(daysToConfirm: employments.fold(0, (sum, value) => sum + toConfirm(value)))),`

`_quickAdd` returns, in order:

```dart
    return [
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Manual shift',
        icon: EraIconKind.shift,
        open: go(WorkInspectorMode.edit),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Extra shift…',
        icon: EraIconKind.shift,
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.extraShift),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Leave…',
        icon: EraIconKind.payPeriod,
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.leave),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Pay period',
        icon: EraIconKind.payPeriod,
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.payPeriod),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Payslip',
        icon: EraIconKind.payslip,
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.payslip),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Employment',
        icon: EraIconKind.employment,
        open: go(WorkInspectorMode.create, needsEmployment: false),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Agreement',
        icon: EraIconKind.agreement,
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.agreement),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Schedule',
        icon: EraIconKind.payPeriod,
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.schedule),
      ),
    ];
```

- [ ] **Step 6: The Extra shift… and Leave… dialogs**

Append to `day_sheet_host.dart` (new imports: `../../../shared/shell/shell_dialog.dart`, `../../../shared/workbench/era_date_field.dart`, `../../../shared/workbench/era_form.dart`, `../../../shared/workbench/inspector_parts.dart`, `../../../shared/workbench/office_controls.dart`):

```dart
enum AddDayKind { extraShift, leave }

/// + Add › Extra shift… and Leave…: a date, then the day's times or leave
/// type (schedules spec 5).
final class AddDayHost extends ConsumerStatefulWidget {
  const AddDayHost({
    required this.employmentId,
    required this.kind,
    required this.today,
    super.key,
  });

  final EmploymentId employmentId;
  final AddDayKind kind;
  final LocalDate today;

  @override
  ConsumerState<AddDayHost> createState() => _AddDayHostState();
}

final class _AddDayHostState extends ConsumerState<AddDayHost> {
  late LocalDate _date = widget.today;
  var _type = LeaveType.vacation;
  LocalDate? _illness;
  String? _error;
  bool _busy = false;

  String? _words(MutationOutcome<DayException> outcome) => switch (outcome) {
    Invalid(:final fields) when fields.containsKey('date') =>
      widget.kind == AddDayKind.extraShift
          ? 'The schedule plans a shift on this date. Open the day to '
                'change it instead.'
          : 'The schedule plans no shift on this date.',
    _ => dayProblem(outcome),
  };

  @override
  Widget build(BuildContext context) {
    final inputs = switch (ref.watch(planInputsProvider(widget.employmentId))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final schedule = inputs?.schedules
        .where((value) => value.isInUseOn(_date))
        .firstOrNull;
    final exception = inputs?.exceptions
        .where((value) => value.date == _date)
        .firstOrNull;
    final service = ref.read(dayPlanServiceProvider);
    final date = EraFormScope(
      labelWidth: 110,
      child: EraDateField(
        fieldKey: const ValueKey('add-day-date'),
        label: 'Date',
        value: _date,
        today: widget.today,
        onChanged: (value) => setState(() {
          _date = value ?? _date;
          _error = null;
        }),
      ),
    );
    final noSchedule = inputs != null && schedule == null
        ? const InspectorNote('No schedule is in use on this date.')
        : null;
    if (widget.kind == AddDayKind.extraShift) {
      return DayTimesForm(
        key: ValueKey(('add-extra', _date, schedule?.version)),
        types: schedule?.shiftTypes ?? const [],
        initial: dayTimesOfType(schedule?.shiftTypes.firstOrNull),
        extra: true,
        submitLabel: 'Add extra shift',
        leading: [date, const SizedBox(height: 7), ?noSchedule],
        describe: _words,
        onSubmit: (times) async {
          final outcome = await service.addExtra(
            widget.employmentId,
            _date,
            start: times.start,
            end: times.end,
            endDayOffset: times.endDayOffset,
            breaks: times.breaks,
            shiftTypeId: times.shiftTypeId,
            countsAsOvertime: times.countsAsOvertime,
            expected: exception?.revision,
          );
          if (outcome is Committed<DayException> && context.mounted) {
            StatusNoticeScope.read(context)?.value = 'Extra shift added.';
          }
          return outcome;
        },
      );
    }
    Future<void> mark() async {
      setState(() {
        _busy = true;
        _error = null;
      });
      final outcome = await service.markLeave(
        widget.employmentId,
        _date,
        leaveType: _type,
        illnessStartedOn: _type == LeaveType.sick ? _illness : null,
        expected: exception?.revision,
      );
      if (!mounted) return;
      if (outcome is Committed<DayException>) {
        StatusNoticeScope.read(context)?.value = 'Marked as leave.';
        ShellDialogScope.closeOf(context)?.call();
        return;
      }
      setState(() {
        _busy = false;
        _error = _words(outcome);
      });
    }

    return DialogForm(
      fields: [
        date,
        const SizedBox(height: 7),
        ?noSchedule,
        EraRadioGroup<LeaveType>(
          options: const [
            EraRadioOption(LeaveType.vacation, 'Vacation'),
            EraRadioOption(LeaveType.sick, 'Sick'),
          ],
          groupValue: _type,
          onChanged: (value) => setState(() => _type = value),
        ),
        if (_type == LeaveType.sick)
          EraFormScope(
            labelWidth: 110,
            child: EraDateField(
              fieldKey: const ValueKey('add-day-illness'),
              label: 'Illness started on',
              value: _illness,
              optional: true,
              today: widget.today,
              onChanged: (value) => setState(() => _illness = value),
            ),
          ),
        if (_error case final error?)
          InspectorNote(error, tone: FactTone.negative),
      ],
      keys: [
        KeyButton(
          label: 'Mark as leave',
          kind: KeyKind.primary,
          onPressed: _busy ? null : mark,
        ),
        const DialogCancelKey(),
      ],
    );
  }
}
```

`work_screen.dart` `_added`: replace the `WorkAddKind.extraShift || WorkAddKind.leave` part of the null arm with

```dart
      case WorkAddKind.extraShift || WorkAddKind.leave:
        return AddDayHost(
          key: ValueKey(('add-day', adding, employmentId)),
          employmentId: employmentId,
          kind: adding == WorkAddKind.extraShift
              ? AddDayKind.extraShift
              : AddDayKind.leave,
          today: _today,
        );
```

and in `_dialogTitle`, beside the schedule title: `if (route.adding == WorkAddKind.extraShift) return 'Extra shift';` and `if (route.adding == WorkAddKind.leave) return 'Leave';`.

- [ ] **Step 7: Run the tests**

Run: `$F/flutter test test/shared/shell/book_tree_test.dart test/shared/shell/status_line_test.dart test/integration/schedule_shell_test.dart test/integration/quick_add_flow_test.dart`
Expected: PASS. If `quick_add_flow_test.dart` counts the + Add entries, raise its count by three.

- [ ] **Step 8: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: Books sub-sheets, days-to-confirm counts and schedule entries in + Add

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Desks and the period's unconfirmed days

Spec §5 Desks and §4.4: a **Next shifts** tile (the next 5 planned shifts with date, type, times and planned pay); **Needs you** says "N days to confirm" and opens the confirm dialog; the Today starter desk becomes Journal recent, Needs you, Next shifts (existing desks unchanged; Reset desk applies it); the Month close checklist's first check becomes "Every past planned day is confirmed"; a pay period's Details say "N planned days not yet confirmed".

**Files:**
- Modify: `lib/core/desks/desks.dart`
- Modify: `lib/features/work/presentation/work_desk_tiles.dart`
- Modify: `lib/app/desk_host.dart`
- Modify: `lib/features/work/presentation/work_register.dart` (`WorkDetails`)
- Test: `test/features/work/presentation/work_desk_tiles_test.dart` (append), `test/integration/today_desk_flow_test.dart` (update), `test/integration/schedule_shell_test.dart` (append)

**Interfaces:**
- Consumes: `workPlanProvider`, `daysToConfirmProvider`, `zoneClocksProvider`; `plannedPay`, `plannedShiftName`, `shiftTimes`, `eraBoxDate`.
- Produces:
  - `DeskSheets.nextShifts = 'work.nextShifts'`, in `DeskSheets.all`; the Today starter's sheets are `[journalRecent, needsYou, nextShifts]`.
  - `final class NextShift { LocalDate date; String text; String? pay; String route; }`; `List<NextShift> nextShifts(List<({EmploymentId employment, List<PlannedDay> plan, List<PayAgreement> agreements})> employments, {required ZoneClocks zoneClocks, required TimezoneService timezones, int count = 5})`.
  - `needsYou({required List<WorkRegisterProjection> registers, Map<EmploymentId, int> daysToConfirm = const {}})`.
  - `monthChecklist(List<WorkRegisterProjection> registers, ({LocalDate start, LocalDate end}) month, {List<LocalDate> unconfirmed = const []})`.

- [ ] **Step 1: Failing tests**

Append to `test/features/work/presentation/work_desk_tiles_test.dart` (add imports `package:lifeos/features/work/domain/planner.dart`, `../../../support/schedule_fixture.dart`, `../../../support/schedule_views.dart`, `../../../support/zone_clocks.dart`):

```dart
  test('Next shifts are the next five planned shifts in date order', () {
    final plan = octoberPlan().where(
      (day) => day.date.compareTo(const LocalDate(2026, 10, 7)) >= 0,
    );
    final rows = nextShifts(
      [
        (
          employment: fixtureEmployment,
          plan: plan.toList(),
          agreements: const [],
        ),
      ],
      zoneClocks: testZoneClocks,
      timezones: testTimezones,
    );
    expect(rows.map((row) => row.date), const [
      LocalDate(2026, 10, 7),
      LocalDate(2026, 10, 11),
      LocalDate(2026, 10, 12),
      LocalDate(2026, 10, 13),
      LocalDate(2026, 10, 17),
    ]);
    expect(rows.first.text, 'Wed 2026-10-07 Day 07:00–19:00');
    expect(rows.first.route, contains('day=2026-10-07'));
  });

  test('Needs you says how many days wait to be confirmed', () {
    final register = WorkRegisterProjection.empty(
      const WorkScope(employmentId: fixtureEmployment, temporal: null),
    );
    final items = needsYou(
      registers: [register],
      daysToConfirm: {fixtureEmployment: 2},
    );
    expect(items.single.text, '2 days to confirm');
    expect(items.single.route, contains('confirm=1'));
  });

  test('the month checklist counts past planned days not confirmed', () {
    final checks = monthChecklist(
      const [],
      (start: const LocalDate(2026, 10, 1), end: const LocalDate(2026, 10, 31)),
      unconfirmed: const [LocalDate(2026, 10, 5), LocalDate(2026, 10, 6)],
    );
    expect(checks.first.label, 'Every past planned day is confirmed');
    expect(checks.first.done, isFalse);
    expect(checks.first.detail, '2 days to confirm');
  });
```

Append to `test/integration/schedule_shell_test.dart`:

```dart
  testWidgets('Details count the planned days not yet confirmed', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    expect(find.text('2 planned days not yet confirmed'), findsOneWidget);
  });
```

In `test/integration/today_desk_flow_test.dart:146`, the label becomes `'Every past planned day is confirmed'`.

- [ ] **Step 2: Run them to see them fail**

Run: `$F/flutter test test/features/work/presentation/work_desk_tiles_test.dart test/integration/schedule_shell_test.dart`
Expected: compile errors (`nextShifts`, `daysToConfirm`, `unconfirmed`).

- [ ] **Step 3: The tiles**

`desks.dart`: add `static const nextShifts = 'work.nextShifts';` to `DeskSheets`, append it to `all`, and make the Today starter's sheets `const [DeskSheets.journalRecent, DeskSheets.needsYou, DeskSheets.nextShifts]`.

`work_desk_tiles.dart` (imports: `../../../core/time/timezone_service.dart`, `../../../shared/workbench/era_dates.dart`, `../domain/agreement.dart`, `../domain/ids.dart`, `../domain/pay_premiums.dart`, `../domain/planner.dart`, `../data/projections/work_register_projection.dart` for `WorkSheet`, `work_plan_view.dart`):

```dart
/// One upcoming planned shift for the Next shifts tile.
final class NextShift {
  const NextShift({
    required this.date,
    required this.text,
    required this.pay,
    required this.route,
  });

  final LocalDate date;

  /// "Wed 2026-10-07 Day 07:00–19:00".
  final String text;

  /// Planned pay, or null without an agreement on the date.
  final String? pay;

  /// The day's Properties.
  final String route;
}

/// The next [count] planned shifts across employments, soonest first.
List<NextShift> nextShifts(
  List<
    ({
      EmploymentId employment,
      List<PlannedDay> plan,
      List<PayAgreement> agreements,
    })
  >
  employments, {
  required ZoneClocks zoneClocks,
  required TimezoneService timezones,
  int count = 5,
}) {
  final rows = [
    for (final (:employment, :plan, :agreements) in employments)
      for (final day in plan.whereType<PlannedShift>())
        (
          start: day.startUtc,
          row: NextShift(
            date: day.date,
            text:
                '${eraBoxDate(day.date)} ${plannedShiftName(day)} '
                '${shiftTimes(day.startUtc, day.endUtc, day.timezoneId, timezones)}',
            pay: switch (plannedPay(
              day,
              agreements: agreements,
              employmentId: employment,
              zoneClocks: zoneClocks,
            )) {
              final pay? => formatMoney(pay.amount),
              null => null,
            },
            route: workRouteUri(
              WorkRouteState(
                employmentId: employment,
                scope: null,
                record: null,
                mode: WorkInspectorMode.properties,
                sheet: WorkSheet.calendar,
                day: day.date,
              ),
            ).toString(),
          ),
        ),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return [for (final item in rows.take(count)) item.row];
}
```

`needsYou` gains `Map<EmploymentId, int> daysToConfirm = const {}` and, first inside the `for (final register in registers) ...[` list:

```dart
      if (daysToConfirm[register.scope.employmentId] case final n? when n > 0)
        NeedsYouItem(
          text: n == 1 ? '1 day to confirm' : '$n days to confirm',
          route: workRouteUri(
            WorkRouteState(
              employmentId: register.scope.employmentId,
              scope: null,
              record: null,
              mode: WorkInspectorMode.inspect,
              confirming: true,
            ),
          ).toString(),
        ),
```

`monthChecklist` gains `{List<LocalDate> unconfirmed = const []}` and its first item becomes

```dart
    ChecklistItem(
      label: 'Every past planned day is confirmed',
      done: open.isEmpty && waiting == 0,
      detail: waiting > 0
          ? '${count(waiting, 'day', 'days')} to confirm'
          : open.isNotEmpty
          ? '${count(open.length, 'shift', 'shifts')} still drafts'
          : 'All confirmed',
    ),
```

with `final waiting = unconfirmed.where(inMonth).length;` declared beside `open`.

- [ ] **Step 4: The desk host**

`desk_host.dart`: `_sheetNames` gains `DeskSheets.nextShifts: 'Next shifts'`. Beside `registers`, read

```dart
    final waiting = {
      for (final employment in employments)
        employment.id: switch (ref.watch(daysToConfirmProvider(employment.id))) {
          AsyncData(:final value) => [for (final day in value) day.date],
          _ => const <LocalDate>[],
        },
    };
```

pass `daysToConfirm: {for (final MapEntry(:key, :value) in waiting.entries) key: value.length}` to `needsYou`, `unconfirmed: [for (final dates in waiting.values) ...dates]` to `monthChecklist`, and add the tile:

```dart
      case DeskSheets.nextShifts:
        final rows = nextShifts(
          [
            for (final employment in employments)
              (
                employment: employment.id,
                plan: switch (ref.watch(
                  workPlanProvider((
                    employment: employment.id,
                    from: today,
                    to: today.addDays(62),
                  )),
                )) {
                  AsyncData(:final value) => value,
                  _ => const <PlannedDay>[],
                },
                agreements: [
                  for (final register in registers)
                    if (register.scope.employmentId == employment.id)
                      for (final row in register.agreementSheet) row.agreement,
                ],
              ),
          ],
          zoneClocks: ref.watch(zoneClocksProvider),
          timezones: ref.read(timezoneServiceProvider),
        );
        return (
          title: title,
          area: LifeOSArea.work,
          fullSizeRoute: workRoute(sheet: WorkSheet.calendar),
          body: TileList(
            lines: [
              for (final row in rows)
                (text: row.text, detail: row.pay, route: row.route, done: null),
            ],
            empty: 'No shifts planned.',
            onOpen: go,
          ),
        );
```

(Where `desk_host.dart` builds its `firstEmployment` routes, keep them; `workRoute(sheet: …)` already exists.)

- [ ] **Step 5: The period's unconfirmed days**

`work_register.dart` `WorkDetails`, after the shift count line:

```dart
        if (projection.plannedNotConfirmed case final n when n > 0)
          Text(
            n == 1
                ? '1 planned day not yet confirmed'
                : '$n planned days not yet confirmed',
          ),
```

- [ ] **Step 6: Run the tests**

Run: `$F/flutter test test/features/work/presentation/work_desk_tiles_test.dart test/integration/schedule_shell_test.dart test/integration/today_desk_flow_test.dart test/app`
Expected: PASS. A test that pins the Today starter's three tiles changes its third tile from "Work this period" to "Next shifts".

- [ ] **Step 7: Full suite, format, commit**

Run: `$F/flutter analyze lib test tool && $F/dart format lib test tool && $F/flutter test`

```bash
git add -A lib test
git commit -m "feat: Next shifts tile, days to confirm on desks, unconfirmed days in Details

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: End to end, goldens and docs

Spec §8: Integration (create a 3-on/3-off/3-night/3-off rotation → confirm the days → a vacation day and a sick day → payslip → reconcile) and Goldens (Calendar and Schedule properties at 1280 × 800 and 960 × 760).

**Files:**
- Create: `test/integration/schedule_screens_flow_test.dart`
- Modify: `test/goldens/shell_goldens_test.dart`; create `test/goldens/work_calendar_{1280x800,960x760}.png`, `test/goldens/schedule_{1280x800,960x760}.png`
- Modify: `DESIGN.md`, `README.md`
- Check: `app.sh`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: The end-to-end flow**

`test/integration/schedule_screens_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';

import '../support/era_pickers.dart';
import '../support/scheduled_app.dart';
import '../support/work_dialogs.dart';
import '../support/work_sheets.dart';

Finder _inSubDialog(String text) => find.descendant(
  of: find.byType(EraDialog).last,
  matching: find.text(text),
);

Future<void> _addType(
  WidgetTester tester, {
  required String name,
  required LocalTime start,
  required LocalTime end,
  required LocalTime breakAt,
  bool nextDay = false,
}) async {
  await tester.tap(_inSubDialog('Add…'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('type-name')), name);
  await setTime(tester, 'type-start', start);
  await setTime(tester, 'type-end', end);
  if (nextDay) {
    await tester.tap(find.byKey(const ValueKey('type-next-day')));
    await tester.pumpAndSettle();
  }
  await tester.tap(_inSubDialog('Add'));
  await tester.pumpAndSettle();
  await setTime(tester, 'type-break-0-start', breakAt);
  await tester.tap(_inSubDialog('OK'));
  await tester.pumpAndSettle();
}

Future<void> _block(
  WidgetTester tester,
  int index, {
  required String count,
  String? type,
}) async {
  if (index > 0) {
    await tester.tap(find.text('Add block'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(ValueKey('block-$index-count')), count);
  if (type != null) {
    await tester.tap(find.byKey(ValueKey('block-$index-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(type).last);
    await tester.pumpAndSettle();
  }
}

Future<void> _markLeave(
  WidgetTester tester,
  ScheduledApp app,
  String date,
  String type,
) async {
  app.router.go(
    '/work?employment=${app.employment}&sheet=calendar&day=$date'
    '&mode=properties',
  );
  await tester.pumpAndSettle();
  await tapInDialog(tester, find.text('Mark as leave…'));
  await tester.tap(_inSubDialog(type));
  await tester.tap(_inSubDialog('OK'));
  await tester.pumpAndSettle();
  expect(find.text('Marked as leave.'), findsOneWidget);
}

void main() {
  testWidgets('a rotation is set up, confirmed, takes leave and reconciles', (
    tester,
  ) async {
    final app = await pumpScheduledApp(
      tester,
      withSchedule: false,
      now: DateTime.utc(2026, 9, 15, 9),
      size: const Size(1280, 900),
    );

    // 1. The rotation: 3 Day, 3 Off, 3 Night, 3 Off from 1 September.
    await tester.tap(find.widgetWithText(TaskLink, 'New schedule…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-name')),
      'Depot rotation',
    );
    await pickDate(tester, 'schedule-cycle-start', const LocalDate(2026, 9, 1));
    await pickDate(tester, 'schedule-from', const LocalDate(2026, 9, 1));
    await tester.tap(find.text('Cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift types…'));
    await tester.pumpAndSettle();
    await _addType(
      tester,
      name: 'Day',
      start: const LocalTime(7, 0),
      end: const LocalTime(19, 0),
      breakAt: const LocalTime(12, 0),
    );
    await _addType(
      tester,
      name: 'Night',
      start: const LocalTime(19, 0),
      end: const LocalTime(7, 0),
      breakAt: const LocalTime(0, 0),
      nextDay: true,
    );
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    await _block(tester, 0, count: '3', type: 'Day');
    await _block(tester, 1, count: '3');
    await _block(tester, 2, count: '3', type: 'Night');
    await _block(tester, 3, count: '3');
    expect(find.text('Cycle — 12 days'), findsOneWidget);
    await tapInDialog(tester, find.text('Save schedule'));
    expect(find.text('Schedule saved.'), findsOneWidget);
    expect(find.text('Day 07:00–19:00'), findsWidgets);
    expect(find.text('Night 19:00–07:00'), findsWidgets);

    // 2. A vacation day and a sick day before confirming.
    await _markLeave(tester, app, '2026-09-02', 'Vacation');
    await _markLeave(tester, app, '2026-09-03', 'Sick');

    // 3. Confirm every past day: Day 1, Vacation 2, Sick 3, Night 7–9,
    //    Day 13–14.
    app.router.go('/work?employment=${app.employment}&confirm=1&mode=inspect');
    await tester.pumpAndSettle();
    expect(find.textContaining('8 days · '), findsOneWidget);
    await tapInDialog(tester, find.text('Confirm'));
    expect(find.text('8 days confirmed.'), findsOneWidget);
    expect(find.textContaining('days to confirm'), findsNothing);

    // 4. The leave is priced: no confirmed work in June–August, so the
    //    agreement rate; vacation at 100 %, the illness's first day at
    //    62.06 %.
    await chooseSheet(tester, 'Leave');
    expect(find.text('Vacation'), findsOneWidget);
    expect(find.text('Sick'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('62.06 %'), findsOneWidget);

    // 5. A payslip for September reconciles against the confirmed days.
    final employment = EmploymentId(app.employment);
    late PayPeriod period;
    await tester.runAsync(() async {
      period = (await app.work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: employment,
          start: const LocalDate(2026, 9, 1),
          end: const LocalDate(2026, 9, 30),
          label: null,
        ),
      ) as Committed<PayPeriod>).value;
      await app.work.payslips.recordPayslip(
        RecordPayslipCommand(
          periodId: period.id,
          issuedDate: const LocalDate(2026, 9, 30),
          paidDate: null,
          amountMinorUnits: 150000,
          basis: const GrossBasis(),
          grossMinorUnits: null,
          netMinorUnits: null,
          deductionMinorUnits: null,
          reference: null,
          note: null,
        ),
      );
    });
    app.router.go(
      '/work?employment=${app.employment}&period=${period.id.value}'
      '&record=payPeriod:${period.id.value}&mode=inspect',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Expected under recorded agreement'), findsWidgets);
    expect(find.textContaining('Difference'), findsWidgets);
    expect(find.textContaining('not yet confirmed'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it**

Run: `$F/flutter test test/integration/schedule_screens_flow_test.dart`
Expected: PASS. A failure here is a defect in an earlier task: fix it there, with a test in that task's file, before going on.

- [ ] **Step 3: Goldens**

Append to `test/goldens/shell_goldens_test.dart`'s `main()` (import `../support/scheduled_app.dart`):

```dart
  for (final (name, location) in [
    ('work_calendar', '/work?employment={employment}'),
    (
      'schedule',
      '/work?employment={employment}&sheet=schedules'
          '&record=schedule:{schedule}&mode=properties',
    ),
  ]) {
    for (final size in sizes) {
      final file = '${name}_${size.width.round()}x${size.height.round()}';
      testWidgets(file, (tester) async {
        await pumpScheduledApp(tester, size: size, location: location);
        await expectLater(
          find.byType(LifeOsApp),
          matchesGoldenFile('$file.png'),
        );
      });
    }
  }
```

Run: `$F/flutter test --update-goldens test/goldens/shell_goldens_test.dart`
Then open each new PNG (`test/goldens/work_calendar_1280x800.png`, `work_calendar_960x760.png`, `schedule_1280x800.png`, `schedule_960x760.png`) and check it against DESIGN.md: era bevels, the amber today outline, words on every entry, nothing clipped at 960 × 760, no text under 11 px. Fix what is off and regenerate. Confirm the existing goldens did not change: `git status test/goldens` lists only the four new files.

- [ ] **Step 4: Docs**

`DESIGN.md`, in the components list after **Date and time boxes**:

```markdown
- **Work calendar** (`WorkCalendar`, `WorkCalendarSheet`): a Monday-first month in the details-list style; bevelled weekday heads, white cells, out-of-month days on the face colour. Each day shows its date and up to two written entries ("Day 07:00–19:00", "Cancelled · Swapped", "Vacation", "Needs review"), then "+N more"; a swatch beside the words is outlined while planned and filled once confirmed. Today has the amber outline; the selected day the selection fill and dotted focus rectangle. Arrow keys move, Enter or a double-click opens the day, Page Up/Down change month. Above it ‹ [Month ▾] [Year ▾] › [Today]; below it the month's shifts, paid time, planned and confirmed pay.
- **Day Properties** (`DaySheet`): "{weekday} {d} {Month} {yyyy}"; the planned shift's facts with **Confirm** (today or earlier), **Change…**, **Cancel shift…**, **Mark as leave…**, or an Off day's **Add extra shift…**. Change… and Add extra shift… edit the times in place; OK and Apply save them. Cancel shift… and Mark as leave… are small era dialogs of radios. A confirmed day opens its shift's or leave's own Properties instead.
- **Confirm worked days**: every past unconfirmed day, ticked, with date, what, times, paid time and pay; the footer totals the ticked days. Each day is its own transaction; a day that fails keeps its row and says why.
- **Schedule Properties** (`ScheduleEditor`): **Schedule | Cycle | Preview | History**. The cycle is a list of blocks — grip, count, ×, type or Off, the type's times — reordered by dragging the grip or Alt+↑/↓. Shift types… opens the Shift types dialog (Add… / Edit… / Remove; a type the cycle uses stays). Saving a version a confirmed day uses asks "Use the new cycle from:" and starts a new version.
```

`README.md` line 47: "Shifts, Pay periods, Payslips and Agreements are chosen with the **View:** dropdown" becomes "Calendar, Shifts, Leave, Schedules, Pay periods, Payslips and Agreements are chosen with the **View:** dropdown or under the employment in Books"; line 52's Today tiles become "(Needs you, Next shifts, Work this period, the Journal, the Month close checklist)".

- [ ] **Step 5: app.sh**

`app.sh`'s commands are unchanged by this plan. Verify it still runs the tests and builds:

Run: `printf '2\n5\n' | ./app.sh`
Expected: "All tests passed!" then the menu exits.

Run: `$F/flutter build linux --release`
Expected: "✓ Built build/linux/x64/release/bundle/lifeos".

- [ ] **Step 6: Final checks and commit**

Run: `$F/flutter analyze lib test tool && $F/dart format --output=none --set-exit-if-changed lib test tool && $F/dart run tool/schema_check.dart && $F/flutter test`
Expected: "No issues found!", no format changes, schema check passes, all tests pass.

```bash
git add -A lib test DESIGN.md README.md
git commit -m "test: drive the schedule screens end to end; calendar and schedule goldens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
