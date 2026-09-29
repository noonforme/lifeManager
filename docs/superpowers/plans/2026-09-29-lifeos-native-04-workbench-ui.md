# Native Workbench UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the native, accessible rail/register/inspector Work workspace so an owner can complete every Work flow without a web server or loss of register context.

**Architecture:** Flutter presentation remains a thin layer over Riverpod feature controllers and the typed Work application outcomes delivered by plans 01–03. GoRouter restores only safe structural scope and selection; controllers retain drafts in memory and subscribe to repository projections. LifeOS-owned widgets compose a dense three-region desktop frame and turn each application outcome into an explicit inspector state without calculating pay, running SQL, or selecting files.

**Tech Stack:** Flutter `3.47.5`, Dart `3.13.4`, Drift `2.35.0`, `sqlite3` `3.6.0`, Riverpod `3.4.3`, GoRouter `18.0.2`, `flutter_test`, `integration_test`, Linux desktop.

**Spec:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md`; master dependency and interface contract: `docs/superpowers/plans/2026-09-29-lifeos-native-implementation.md`.

## Global Constraints

- Build only the native Flutter Linux app; do not start, embed, call, or depend on Django, Python, React, Node, a browser, HTTP, or the archived database.
- Retain the exact repository pins: Flutter `3.47.5`, Dart `3.13.4`, Drift `2.35.0`, `sqlite3` `3.6.0`, Riverpod `3.4.3`, and GoRouter `18.0.2`; do not add Freezed, Riverpod code generation, Redux, BLoC, mocking frameworks, or a global mutable store.
- Consume `AppClock`, `TimezoneService`, `MutationOutcome<T>`, `WorkRepository`, and `DestinationPicker` exactly as defined by the master plan; controllers do not execute SQL or derive compensation.
- Routes contain only active surface, UUID IDs, explicit date/period scope, and inspector mode; never put labels, notes, money, instants, drafts, export paths, or serialized records in a route or preference.
- The register stays mounted while selection, inspector mode, validation, conflict, and outcome state changes; a successful mutation is rendered only after `Committed`.
- Implement every Work flow: first-run employment/agreement setup; live running/on-break/finalization; manual shift; pay-period/payslip reconciliation; revision conflict; and finalized-record void-and-replace correction.
- Use exact integer/rational derived values returned by the application projection. Label expected compensation as an estimate under recorded agreements; never call it payroll, tax, or payment certainty.
- Preserve explicit unavailable, invalid-scope, stale-conflict, and uncertain-outcome states. An uncertain outcome tells the owner to reload and inspect, never to retry blindly.
- Implement the LifeOS metrology-bench direction: contiguous neutral surfaces, compact rail/register/inspector topology, thin separators, tabular figures, restrained blue selection and orange warnings; no card grid, gradient, glow, stock Material appearance, decorative chart, or unlabeled icon-only critical action.
- Wide minimum target is `1280 × 760` logical pixels. At constrained width, preserve scope/selection/draft and show an explicit **Back to register** sequential pane; only the labeled table viewport may scroll horizontally.
- Support pointer and complete keyboard operation, semantic landmarks/announcements, visible focus distinct from selection, high contrast, text scaling, and reduced motion. Color is never the sole status cue.
- Personal data must not occur in source control, tests, fixtures, screenshots, logs, diagnostics, route text, or readiness output. Use clearly synthetic values only.
- Before the first widget or UI-style edit, load the Impeccable craft floor and persist the approved native Work surface contract. Do not run finish review or design documentation until plan 05.
- Do not implement backup/export file selection in this phase; plan 05 wires the already-safe System Files route to the native file services.
- End every implementation commit with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.

## Review Focus

1. **A malformed route ID, unknown UUID, or malformed local-date scope:** show the requested invalid-scope/unavailable inspector state without selecting another record or replacing the scope with today; test in Task 1.
2. **A draft shift changes its captured local date or scope while it is saved:** use the committed application projection’s scope and keep that record selected; test in Task 5.
3. **Another operation changes the selected root revision:** keep the register and in-memory owner draft, announce a stale conflict, and offer reload/review rather than overwriting; test in Task 6.
4. **A reopened app has an active running/on-break shift:** rebuild the state solely from the Work projection, not preferences or a timer cached in the widget tree; test in Task 5.
5. **A 200% text scale, high-contrast theme, or 960 logical-pixel-wide window:** preserve reachable controls and the return flow with no page-level horizontal overflow; test in Tasks 2 and 3.

---

## File responsibilities

- `lib/app/app_router.dart`: extends the Phase 01 router with strict Work route parsing/building and explicit route-state errors.
- `lib/app/lifeos_app.dart`: extends the Phase 01 `MaterialApp.router` host with LifeOS workbench theme/density providers and the semantic announcement host.
- `lib/shared/workbench/lifeos_frame.dart`: durable rail/register/inspector frame and constrained sequential topology.
- `lib/shared/workbench/system_rail.dart`: visible, semantic navigation destinations and honest unavailable destinations.
- `lib/shared/workbench/data_register.dart`: focusable dense register, contained horizontal viewport, and pointer/keyboard selection primitives.
- `lib/shared/workbench/inspector_pane.dart`: inspector landmark, stable wide pane, narrow return action, and live-region host.
- `lib/shared/workbench/operational_state.dart`: non-decorative loading, empty, unavailable, invalid-scope, conflict, and uncertain states.
- `lib/shared/workbench/lifeos_theme.dart`: owned light/dark/high-contrast-aware tokens, typography, focus, reduced-motion policy, and density.
- `lib/features/work/presentation/work_route_state.dart`: safe structural Work route value and parser.
- `lib/features/work/presentation/work_controller.dart`: Riverpod controller that combines route state, projection subscriptions, in-memory draft, and typed outcomes.
- `lib/features/work/presentation/work_screen.dart`: route composition; no business calculation or persistence.
- `lib/features/work/presentation/work_register.dart`: Work scopes, status filters, compact reconciliation summary, and shift/period register rows.
- `lib/features/work/presentation/work_inspector.dart`: maps controller state to all named Work inspector modes.
- `lib/features/work/presentation/employment_agreement_forms.dart`: first-run employment and effective-dated agreement forms.
- `lib/features/work/presentation/shift_forms.dart`: live/manual shift, break, overtime-confirmation, and draft-edit controls.
- `lib/features/work/presentation/period_payslip_forms.dart`: period/review and payslip evidence controls.
- `lib/features/work/presentation/correction_confirmation.dart`: exact-history void-and-replace explanation and confirmation.
- `test/app/router_test.dart`, `test/shared/workbench/*.dart`, and `test/features/work/presentation/*.dart`: deterministic widget/controller test coverage with fakes, never the production database.

### Task 1: Safe Work routes and controller contract

**Files:**
- Modify: `lib/app/app_router.dart`
- Create: `lib/features/work/presentation/work_route_state.dart`
- Create: `lib/features/work/presentation/work_controller.dart`
- Create: `test/app/router_test.dart`
- Create: `test/features/work/presentation/work_controller_test.dart`

**Interfaces:**
- Consumes: master-plan `WorkRepository.watchRegister(WorkScope)`, `WorkRepository.watchRecord(WorkRecordId)`, `MutationOutcome<T>`, `AppClock`, and plan-03 `WorkScope`/`WorkTemporalScope` projection values and use cases. `WorkRecordRef` is route-only structural state pairing a `WorkRecordKind` discriminator with a parsed Phase-02 `WorkRecordId`.
- Produces:

```dart
enum WorkInspectorMode { inspect, create, edit, correct }

sealed class WorkRouteParseResult { const WorkRouteParseResult(); }
final class ValidWorkRoute extends WorkRouteParseResult {
  const ValidWorkRoute(this.state);
  final WorkRouteState state;
}
final class InvalidWorkRoute extends WorkRouteParseResult {
  const InvalidWorkRoute(this.reason);
  final WorkRouteProblem reason;
}

enum WorkRouteProblem { malformedId, malformedScope, invalidMode }

enum WorkRecordKind { employment, agreement, shift, shiftBreak, payPeriod, payslip }

final class WorkRecordRef {
  const WorkRecordRef({required this.kind, required this.id});
  final WorkRecordKind kind;
  final WorkRecordId id;
  static WorkRecordRef? tryParse(String? value);
}

final class WorkRouteState {
  const WorkRouteState({
    required this.employmentId,
    required this.scope,
    required this.record,
    required this.mode,
  });
  final EmploymentId? employmentId;
  final WorkTemporalScope? scope; // imported from plan 03
  final WorkRecordRef? record;
  final WorkInspectorMode mode;
}

final workControllerProvider =
    NotifierProvider.autoDispose<WorkController, WorkViewState>(WorkController.new);

sealed class WorkViewState { const WorkViewState(); }
final class WorkReady extends WorkViewState {
  const WorkReady({required this.register, required this.route, required this.inspector});
  final WorkRegisterProjection register;
  final WorkRouteState route;
  final WorkInspectorState inspector;
}
final class WorkInvalidScope extends WorkViewState {
  const WorkInvalidScope(this.problem);
  final WorkRouteProblem problem;
}
```

- [ ] **Step 1: Write failing route and controller tests**

```dart
test('invalid record UUID remains unavailable instead of selecting a row', () {
  final result = parseWorkRoute(Uri.parse('/work?record=shift:not-a-uuid'));
  expect(result, isA<InvalidWorkRoute>());
  expect((result as InvalidWorkRoute).reason, WorkRouteProblem.malformedId);
});

test('controller preserves an explicit invalid period rather than substituting today', () async {
  final container = ProviderContainer(overrides: [
    workRepositoryProvider.overrideWithValue(FakeWorkRepository.empty()),
    workRouteProvider.overrideWith((_) => const InvalidWorkRoute(WorkRouteProblem.malformedScope)),
  ]);
  addTearDown(container.dispose);
  expect(container.read(workControllerProvider), isA<WorkInvalidScope>());
});
```

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run: `flutter test test/app/router_test.dart test/features/work/presentation/work_controller_test.dart`

Expected: FAIL because the route parser, provider, and controller do not exist.

- [ ] **Step 3: Implement strict parsing and controller subscription wiring**

```dart
WorkRouteParseResult parseWorkRoute(Uri uri) {
  if (uri.path != '/work') return const InvalidWorkRoute(WorkRouteProblem.malformedScope);
  final mode = switch (uri.queryParameters['mode'] ?? 'inspect') {
    'inspect' => WorkInspectorMode.inspect,
    'create' => WorkInspectorMode.create,
    'edit' => WorkInspectorMode.edit,
    'correct' => WorkInspectorMode.correct,
    _ => null,
  };
  if (mode == null) return const InvalidWorkRoute(WorkRouteProblem.invalidMode);
  final employment = EmploymentId.tryParse(uri.queryParameters['employment']);
  if (uri.queryParameters.containsKey('employment') && employment == null) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedId);
  }
  final record = WorkRecordRef.tryParse(uri.queryParameters['record']);
  if (uri.queryParameters.containsKey('record') && record == null) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedId);
  }
  final period = PayPeriodId.tryParse(uri.queryParameters['period']);
  final from = LocalDate.tryParse(uri.queryParameters['from']);
  final to = LocalDate.tryParse(uri.queryParameters['to']);
  final hasRange = uri.queryParameters.containsKey('from') || uri.queryParameters.containsKey('to');
  if ((uri.queryParameters.containsKey('period') && period == null) ||
      (period != null && hasRange) ||
      (hasRange && (from == null || to == null || to.compareTo(from) < 0))) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedScope);
  }
  final scope = period != null
      ? PayPeriodScope(period)
      : (from != null && to != null ? DateRangeScope(start: from, end: to) : null);
  return ValidWorkRoute(WorkRouteState(
    employmentId: employment,
    scope: scope,
    record: record,
    mode: mode,
  ));
}
```

`WorkRecordRef.tryParse` accepts exactly `<kind>:<canonical-uuidv7>`, maps each discriminator to its matching Phase-02 typed ID parser, and rejects unknown kinds or ID-kind mismatches. Subscribe to the register projection from `WorkScope(employmentId: employment, temporal: scope)` and to a selected record only when its typed ID is valid. Keep draft fields inside `WorkController`; do not write them to GoRouter, shared preferences, or `WorkRepository`. A missing valid ID becomes inspector unavailable, not a replacement selection.

- [ ] **Step 4: Run focused tests and static analysis**

Run:

```bash
flutter test test/app/router_test.dart test/features/work/presentation/work_controller_test.dart
flutter analyze
```

Expected: PASS with no analyzer warnings.

- [ ] **Step 5: Commit the route/controller boundary**

```bash
git add lib/app/app_router.dart lib/features/work/presentation/work_route_state.dart lib/features/work/presentation/work_controller.dart test/app/router_test.dart test/features/work/presentation/work_controller_test.dart
git commit -m "feat: add safe native Work route state

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 2: LifeOS frame, owned visual system, and rail

**Files:**
- Modify: `lib/app/lifeos_app.dart`
- Create: `lib/shared/workbench/lifeos_theme.dart`
- Create: `lib/shared/workbench/lifeos_frame.dart`
- Create: `lib/shared/workbench/system_rail.dart`
- Create: `lib/shared/workbench/inspector_pane.dart`
- Create: `test/shared/workbench/lifeos_frame_test.dart`
- Create: `test/shared/workbench/system_rail_test.dart`
- Create: `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md`

**Interfaces:**
- Consumes: `GoRouter`, safe surface destinations `/today`, `/work`, `/money`, `/habits`, `/system/files`, and `WorkViewState` from Task 1.
- Produces `LifeOSApp`, `LifeOSFrame`, `SystemRail`, and `InspectorPane`; `LifeOSFrame` receives `Widget rail`, `Widget register`, `Widget inspector`, `bool inspectorIsActive`, and `VoidCallback onBackToRegister`.

- [ ] **Step 1: Load the Impeccable craft floor and persist the approved surface contract before editing UI**

Invoke the project `impeccable` skill through the host Skill tool, then follow its one-time context setup and read `reference/craft-floor.md` immediately before creating any file in `lib/app/` or `lib/shared/workbench/`. Do not emulate skill invocation with a shell command. Use the surface-brief command described by the skill to write `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md` for primary target `lib/features/work/presentation/work_screen.dart`, related targets `lib/app/lifeos_app.dart`, `lib/shared/workbench/lifeos_frame.dart`, and `lib/features/work/presentation/work_inspector.dart`, with this contract:

```markdown
## Direction contract

THESIS: LifeOS is a minimal precision workbench where truthful records and the smallest valid correction share one continuous field; it refuses a dashboard of detached KPI cards.

OWN-WORLD: Quiet neutral contiguous surfaces, exact thin divisions, compact practical system type, tabular values, pointer-efficient controls, restrained blue selection, and orange warning states.

STORY: The owner establishes an employment, records time, reviews expected-versus-paid evidence, and corrects history without losing register context.

FIRST VIEWPORT: At 1280×760, a compact 216-pixel labeled rail frames a dense register and a stable 360–520-pixel adjacent inspector. Selection opens inspection in place; constrained widths preserve state and switch to one pane with Back to register. State changes are immediate with no ornamental motion.

FORM: Approved metrology-bench workbench; seed 66c5219c; code-led path. The approved native specification settles composition; no new concept round.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
```

- [ ] **Step 2: Write failing frame and accessibility tests**

```dart
testWidgets('wide frame exposes rail, register and inspector landmarks', (tester) async {
  await tester.pumpWidget(const TestLifeOSFrame(width: 1280, height: 760));
  expect(find.bySemanticsLabel('System navigation'), findsOneWidget);
  expect(find.bySemanticsLabel('Work register'), findsOneWidget);
  expect(find.bySemanticsLabel('Record inspector'), findsOneWidget);
});

testWidgets('constrained frame keeps selection and provides Back to register', (tester) async {
  await tester.pumpWidget(const TestLifeOSFrame(width: 960, height: 760, inspectorIsActive: true));
  expect(find.text('Back to register'), findsOneWidget);
  await tester.tap(find.text('Back to register'));
  await tester.pump();
  expect(find.bySemanticsLabel('Work register'), findsOneWidget);
});
```

Also assert each rail destination has visible text, Work has `selected: true`, Today/Money/Habits are disabled but explain “Not available in this release”, and reduced motion sets transition duration to zero.

- [ ] **Step 3: Run frame tests and confirm failure**

Run: `flutter test test/shared/workbench/lifeos_frame_test.dart test/shared/workbench/system_rail_test.dart`

Expected: FAIL because LifeOS frame widgets and the surface contract do not exist.

- [ ] **Step 4: Implement owned frame, theme, and rail**

Implement responsive compression first: from `1280` down, hide only explicitly nonessential register columns and tighten spacing while keeping rail/register/inspector visible whenever the register remains usable. Use a tested topology threshold derived from `216` rail + `360` inspector + `560` minimum register + separators (`1138` logical pixels); below `1138`, show exactly one sequential register or inspector pane while retaining controller state. Do not use an arbitrary device-class breakpoint. Use `Semantics(container: true, label: ...)`, `FocusTraversalGroup`, visible `Focus` border tokens, `MediaQuery.disableAnimations`, `MediaQuery.highContrast`, and `ThemeData` only as behavior substrate. The visible rail text must be **Today**, **Work**, **Money**, **Habits**, and **Backup and Export**.

- [ ] **Step 5: Run frame tests, text-scale test, and analysis**

Run:

```bash
flutter test test/shared/workbench/lifeos_frame_test.dart test/shared/workbench/system_rail_test.dart
flutter test test/shared/workbench/lifeos_frame_test.dart --plain-name "constrained frame keeps selection"
flutter analyze
```

Expected: PASS; no uncontrolled animation and no semantic-label failure.

- [ ] **Step 6: Commit the shared workbench shell**

```bash
git add lib/app/lifeos_app.dart lib/shared/workbench .impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md test/shared/workbench
git commit -m "feat: build the native LifeOS frame

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 3: Dense accessible Work register and selection semantics

**Files:**
- Create: `lib/shared/workbench/data_register.dart`
- Create: `lib/shared/workbench/operational_state.dart`
- Create: `lib/features/work/presentation/work_screen.dart`
- Create: `lib/features/work/presentation/work_register.dart`
- Create: `test/shared/workbench/data_register_test.dart`
- Create: `test/features/work/presentation/work_register_test.dart`

**Interfaces:**
- Consumes: `WorkReady.register`, `WorkRouteState.record`, `LifeOSFrame`, and projections from plan 03.
- Produces `WorkScreen`, `WorkRegister`, and generic `DataRegister<Row>`:

```dart
class DataRegister<Row> extends StatefulWidget {
  const DataRegister({
    required this.label,
    required this.rows,
    required this.columns,
    required this.rowId,
    required this.selectedId,
    required this.onSelect,
    super.key,
  });
  final String label;
  final List<Row> rows;
  final List<RegisterColumn<Row>> columns;
  final String Function(Row) rowId;
  final String? selectedId;
  final ValueChanged<Row> onSelect;
}
```

- [ ] **Step 1: Write failing interaction, overflow, and state tests**

```dart
testWidgets('arrow moves keyboard focus but Enter alone changes selection', (tester) async {
  final selected = <String>[];
  await tester.pumpWidget(TestRegister(onSelect: selected.add));
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  expect(selected, isEmpty);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  expect(selected, ['shift:00000000-0000-7000-8000-000000000001']);
});

testWidgets('wide columns scroll inside the labeled table viewport only', (tester) async {
  await tester.pumpWidget(const TestRegister(width: 960));
  expect(find.bySemanticsLabel('Work rows, horizontally scrollable'), findsOneWidget);
  expect(tester.getSize(find.byType(Scrollable).first).width, lessThanOrEqualTo(960));
});
```

Add tests for single-click selection, selected vs focused semantic distinction, empty first-run message, unavailable projection, tabular `FontFeature.tabularFigures()`, and a 2.0 text scale with all toolbar controls reachable.

- [ ] **Step 2: Run register tests and confirm failure**

Run: `flutter test test/shared/workbench/data_register_test.dart test/features/work/presentation/work_register_test.dart`

Expected: FAIL because the register widgets do not exist.

- [ ] **Step 3: Implement contained table and Work scope controls**

Render employment control, explicit period/date-range control, status filters, a compact expected/paid/difference row, and an appropriate primary action. Use a `SingleChildScrollView(scrollDirection: Axis.horizontal)` only around the rows, labeled **Work rows, horizontally scrollable**; the outer screen uses no horizontal scroll view. Single click invokes `onSelect`; Arrow keys move a `FocusNode` index only; Enter/Space invokes it. Row fields use `SelectableText` only where it will not intercept row actions; whole-row selection remains pointer-operable.

- [ ] **Step 4: Run tests and verify routing context**

Run:

```bash
flutter test test/shared/workbench/data_register_test.dart test/features/work/presentation/work_register_test.dart
flutter test test/app/router_test.dart test/features/work/presentation/work_controller_test.dart
flutter analyze
```

Expected: PASS; a selection changes only `/work` safe query state and does not unmount the register.

- [ ] **Step 5: Commit the register primitive and Work composition**

```bash
git add lib/shared/workbench/data_register.dart lib/shared/workbench/operational_state.dart lib/features/work/presentation/work_screen.dart lib/features/work/presentation/work_register.dart test/shared/workbench/data_register_test.dart test/features/work/presentation/work_register_test.dart
git commit -m "feat: add dense accessible Work register

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 4: First-run employment and effective-dated agreement workflow

**Files:**
- Create: `lib/features/work/presentation/employment_agreement_forms.dart`
- Create: `test/features/work/presentation/employment_agreement_forms_test.dart`
- Modify: `lib/features/work/presentation/work_inspector.dart`
- Modify: `lib/features/work/presentation/work_controller.dart`

**Interfaces:**
- Consumes plan-03 use cases `createEmployment(CreateEmploymentCommand)` and `createAgreement(CreateAgreementCommand)`, each returning `Future<MutationOutcome<WorkRecordProjection>>`.
- Produces controller actions `submitEmployment`, `submitAgreement`, and form values `EmploymentDraft`, `AgreementDraft`; application commands contain trimmed names, ISO local dates, integer micro-euros, `RateBasis`, paid-minute threshold, and positive rational multiplier.

- [ ] **Step 1: Write failing first-run and validation tests**

```dart
testWidgets('empty Work explains setup and opens employment creation in inspector', (tester) async {
  await tester.pumpWidget(TestWorkScreen.empty());
  expect(find.text('Create an employment and an agreement before recording paid work.'), findsOneWidget);
  await tester.tap(find.text('Create employment'));
  expect(find.bySemanticsLabel('Create employment'), findsOneWidget);
});

testWidgets('invalid agreement keeps field values and associates errors', (tester) async {
  await tester.pumpWidget(TestAgreementForm(outcome: Invalid({
    'hourlyRate': [const FieldIssue(code: 'positive', message: 'Enter a rate above zero.')],
  })));
  await tester.tap(find.text('Save agreement'));
  await tester.pump();
  expect(find.text('Enter a rate above zero.'), findsOneWidget);
  expect(find.bySemanticsLabel('Hourly rate, Enter a rate above zero.'), findsOneWidget);
});
```

Also test successful employment followed by first agreement stays in that employment scope and exposes **Start shift** and **Add manual shift** only after the agreement commits.

- [ ] **Step 2: Run tests and confirm failure**

Run: `flutter test test/features/work/presentation/employment_agreement_forms_test.dart`

Expected: FAIL because forms and controller actions do not exist.

- [ ] **Step 3: Implement facts-first setup forms**

Use `Form`/`TextFormField` with visible labels and `Focus` handling; controller maps `Invalid` field keys to form errors without logging entered values. Present effective start/end dates, EUR micro-rate input formatted as a display-only decimal conversion at the form boundary, gross/net basis, threshold, multiplier numerator and denominator. Do not implement agreement edits for a used agreement; render the application-provided correction action instead.

- [ ] **Step 4: Run setup tests and Work regressions**

Run:

```bash
flutter test test/features/work/presentation/employment_agreement_forms_test.dart test/features/work/presentation/work_register_test.dart
flutter analyze
```

Expected: PASS; no setup action appears before a committed agreement.

- [ ] **Step 5: Commit the Work setup flow**

```bash
git add lib/features/work/presentation/employment_agreement_forms.dart lib/features/work/presentation/work_inspector.dart lib/features/work/presentation/work_controller.dart test/features/work/presentation/employment_agreement_forms_test.dart
git commit -m "feat: add Work employment and agreement setup

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 5: Live and manual shift lifecycle

**Files:**
- Create: `lib/features/work/presentation/shift_forms.dart`
- Modify: `lib/features/work/presentation/work_inspector.dart`
- Modify: `lib/features/work/presentation/work_controller.dart`
- Create: `test/features/work/presentation/shift_forms_test.dart`
- Create: `test/features/work/presentation/live_shift_workflow_test.dart`

**Interfaces:**
- Consumes plan-03 commands `startShift`, `startBreak`, `endBreak`, `endShift`, `finalizeShift`, and `saveManualShift`, all returning `MutationOutcome<WorkRecordProjection>`.
- Produces inspector states `ShiftCreateInspector`, `RunningShiftInspector`, `OnBreakShiftInspector`, `OvertimeConfirmationInspector`, `ShiftEditInspector`, and `ValidationFailureInspector`.

- [ ] **Step 1: Write failing lifecycle tests**

```dart
testWidgets('end shift presents suggestion and requires owner overtime confirmation', (tester) async {
  await tester.pumpWidget(TestLiveShiftInspector.ended(
    suggestedOvertimeMinutes: 42,
    enteredOvertimeMinutes: 0,
  ));
  expect(find.text('Suggested from the agreement threshold: 42 minutes.'), findsOneWidget);
  expect(find.text('Confirm finalization'), findsOneWidget);
});

testWidgets('restart restores on-break state from projection without preferences', (tester) async {
  final repository = FakeWorkRepository.withActiveOnBreakShift();
  await tester.pumpWidget(TestWorkScreen(repository: repository));
  expect(find.bySemanticsLabel('Shift on break'), findsOneWidget);
  expect(find.text('End break'), findsOneWidget);
});
```

Add tests for start → break start → break end → end → finalize, manual overnight entry, validation preserving timezone/note/draft fields, actual committed local-date scope after save, and an entered overtime value that differs from the suggestion being shown but not replaced.

- [ ] **Step 2: Run lifecycle tests and confirm failure**

Run: `flutter test test/features/work/presentation/shift_forms_test.dart test/features/work/presentation/live_shift_workflow_test.dart`

Expected: FAIL because lifecycle inspector widgets and action wiring do not exist.

- [ ] **Step 3: Implement lifecycle controls without local truth**

Expose **Start shift**, **Start break**, **End break**, **End shift**, **Confirm finalization**, and **Add manual shift** as visible text actions. The current duration is a projection from the application clock/service; it is not persisted in preferences or recalculated by the widget. Manual entry sends explicit local date/time, IANA timezone, break list, and owner overtime minutes to the application command. After `Committed`, replace route scope/record with the returned projection’s safe IDs and local-date scope, retaining the finalized shift selection.

- [ ] **Step 4: Run lifecycle tests and all presentation tests**

Run:

```bash
flutter test test/features/work/presentation/shift_forms_test.dart test/features/work/presentation/live_shift_workflow_test.dart
flutter test test/features/work/presentation
flutter analyze
```

Expected: PASS; restart state is database projection-backed and date changes follow committed scope.

- [ ] **Step 5: Commit live and manual shift UI**

```bash
git add lib/features/work/presentation/shift_forms.dart lib/features/work/presentation/work_inspector.dart lib/features/work/presentation/work_controller.dart test/features/work/presentation/shift_forms_test.dart test/features/work/presentation/live_shift_workflow_test.dart
git commit -m "feat: add native Work shift lifecycle

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 6: Pay periods, payslips, reconciliation, corrections, and mutation outcomes

**Files:**
- Create: `lib/features/work/presentation/period_payslip_forms.dart`
- Create: `lib/features/work/presentation/correction_confirmation.dart`
- Modify: `lib/features/work/presentation/work_inspector.dart`
- Modify: `lib/features/work/presentation/work_controller.dart`
- Create: `test/features/work/presentation/period_payslip_forms_test.dart`
- Create: `test/features/work/presentation/correction_and_outcome_test.dart`

**Interfaces:**
- Consumes plan-03 period, payslip, reconciliation, correction, and revision use cases returning `MutationOutcome<T>`.
- Produces `PeriodInspector`, `PayslipInspector`, `ReconciliationInspector`, `CorrectionConfirmationInspector`, `StaleConflictInspector`, `UnavailableInspector`, and `UncertainOutcomeInspector`.

- [ ] **Step 1: Write failing reconciliation/correction/outcome tests**

```dart
testWidgets('mixed gross and net evidence remains separate and has no combined difference', (tester) async {
  await tester.pumpWidget(TestReconciliationInspector.mixedBasis());
  expect(find.text('Gross and net evidence cannot be combined.'), findsOneWidget);
  expect(find.text('Single difference'), findsNothing);
});

testWidgets('stale save preserves register and draft and offers reload', (tester) async {
  await tester.pumpWidget(TestWorkScreen.withOutcome(const Stale()));
  expect(find.bySemanticsLabel('Work register'), findsOneWidget);
  expect(find.text('Your record is out of date. Reload and review before trying again.'), findsOneWidget);
  expect(find.text('Reload record'), findsOneWidget);
});
```

Add tests for multiple payslips, missing/unmatched/difference/balanced/unavailable reconciliation status explanation, reviewed period reopening, finalized shift correction naming exact record and explaining void/replacement, confirmation returning an editable selected replacement, `Uncertain` guidance, `Missing` unavailable state, and cancel preserving scope without mutation.

- [ ] **Step 2: Run tests and confirm failure**

Run: `flutter test test/features/work/presentation/period_payslip_forms_test.dart test/features/work/presentation/correction_and_outcome_test.dart`

Expected: FAIL because period/payslip/correction inspector states do not exist.

- [ ] **Step 3: Implement truthfully separated review and outcomes**

Render expected/paid/difference by compatible currency and basis. Labels must say **Expected under recorded agreement** and **Paid evidence**. The destructive button reads **Void original and create replacement** and its body explains that the original remains historical and is excluded from active totals. Map outcomes exactly: `Invalid` shows field errors; `Stale` keeps draft/register; `Missing`/`Unavailable` explain unavailable; `Uncertain` instructs reload/inspect; only `Committed` changes selected record or announces saved.

- [ ] **Step 4: Run outcome and full widget suites**

Run:

```bash
flutter test test/features/work/presentation/period_payslip_forms_test.dart test/features/work/presentation/correction_and_outcome_test.dart
flutter test
flutter analyze
```

Expected: PASS; no UI combines gross/net values or calls a calculated value a payment.

- [ ] **Step 5: Commit Work review and correction flows**

```bash
git add lib/features/work/presentation/period_payslip_forms.dart lib/features/work/presentation/correction_confirmation.dart lib/features/work/presentation/work_inspector.dart lib/features/work/presentation/work_controller.dart test/features/work/presentation/period_payslip_forms_test.dart test/features/work/presentation/correction_and_outcome_test.dart
git commit -m "feat: complete Work review and correction UI

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 7: Presentation verification and handoff to release

**Files:**
- Modify: `test/shared/workbench/lifeos_frame_test.dart`
- Modify: `test/features/work/presentation/live_shift_workflow_test.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes all presentation features completed in Tasks 1–6.
- Produces a verified native UI baseline for plan 05; no packaging, backup/export picker, finish review, `DESIGN.md`, or `.impeccable/design.json` change occurs here.

- [ ] **Step 1: Add the final cross-state widget regression matrix**

Add one parameterized test with fixtures for `noSelection`, `inspect`, `create`, `editDraft`, `running`, `onBreak`, `validationFailure`, `staleConflict`, `voidAndReplaceConfirmation`, `unavailable`, and `uncertainOutcome`. Assert each state has one inspector landmark, visible text state title, a register landmark, and no route containing fixture note/amount text.

- [ ] **Step 2: Run the matrix and confirm the final missing case fails before fixing it**

Run: `flutter test test/features/work/presentation/live_shift_workflow_test.dart --plain-name "all inspector states remain explicit"`

Expected: FAIL until every named inspector state is mapped by `WorkInspector`.

- [ ] **Step 3: Complete any omitted semantic state mapping and native README boundary**

Implement only missing `WorkInspector` mapping from the test. Update `README.md` to state that the active application is native Flutter, Work is the operational surface, Today/Money/Habits are unavailable destinations in this slice, and the archived Django implementation is not read or started by native workflows. Do not document hypothetical release artifact names; plan 05 establishes them.

- [ ] **Step 4: Run the UI verification suite**

Run:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Expected: all commands PASS with no format diff, analyzer warning, or widget failure.

- [ ] **Step 5: Commit UI verification baseline**

```bash
git add README.md test/shared/workbench/lifeos_frame_test.dart test/features/work/presentation/live_shift_workflow_test.dart lib/features/work/presentation/work_inspector.dart
git commit -m "test: verify native Work workbench states

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Plan self-review

Spec coverage: Tasks 1–3 implement safe GoRouter restoration, Riverpod controllers, LifeOS frame, rail/register/inspector geometry, contained width, and accessibility. Tasks 4–6 cover every required Work setup, shift, pay-period, payslip, reconciliation, mutation, and correction state. Task 7 locks the complete inspector-state and privacy boundary before release work. Each Review Focus item is exercised by its named task. This plan intentionally leaves WAL-safe backup/export, Linux integration, packaging, launcher cutover, legacy-plan cleanup, bounded finish review, and final design documentation to plan 05.

Placeholder scan: every implementation step has concrete commands, expected outcomes, signatures, files, and test assertions; plan-03 application commands are explicitly consumed and each new presentation interface is declared in its owning task.

Type consistency: all UI mutations use the master `MutationOutcome<T>` family; the stable route modes remain `inspect|create|edit|correct`; records are represented by typed IDs rather than raw personal content.

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-29-lifeos-native-04-workbench-ui.md`. Please review the plan. Does it capture what you want?
