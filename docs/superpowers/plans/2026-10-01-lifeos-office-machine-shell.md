# Office Machine Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rail/register/inspector frame with the Office Machine shell (book tree, desks, journal, formula bar, inspector with history), move Work into it with its known gaps fixed, and ship the Phase 1 shell features the owner chose.

**Architecture:** Presentation stays a thin layer over Riverpod controllers and typed application outcomes. New shell state (desks, tiles, saved views) is structural configuration in SQLite. Record history is an append-only table written inside each mutation's transaction. The Journal and every live value in the tree are derived projections, never stored. Explanations for the formula bar are built in the application layer from the same results that produce the cells.

**Tech Stack:** Flutter `3.47.5`, Dart `3.13.4`, Drift `2.35.0`, `sqlite3` `3.6.0`, Riverpod `3.4.3`, GoRouter `18.0.2`, `flutter_test`, `integration_test`, Linux desktop. Fonts: Archivo and Azeret Mono (SIL OFL), bundled.

**Spec:** `docs/superpowers/specs/2026-10-01-lifeos-office-machine-shell-design.md`. Domain prerequisites: `docs/superpowers/specs/2026-10-01-work-employments-premiums-design.md`. Cross-phase contracts: `docs/superpowers/plans/2026-09-29-lifeos-native-implementation.md`.

## Prerequisite

Phase A of the employments and premiums spec must land before Task 6. Task 6 renders the `ExpectedPay` breakdown (regular, night, holiday and overtime seconds) and assumes manual overtime has been removed from `WorkShift` and every form. Tasks 1–5 do not depend on it and may run first.

## Global Constraints

- Keep every constraint in the master plan and plan 04: native Linux only, exact pins, no SQL in controllers, no pay derivation in widgets, typed `MutationOutcome<T>`, explicit stale and uncertain states, and safe routes.
- Add no dependencies beyond bundled font assets. Do not add Freezed, code-generated Riverpod, BLoC or mocking frameworks.
- Fonts are bundled under `assets/fonts/` with their OFL licence files. Never fetch fonts at runtime.
- Colour tokens come only from `LifeOSTokens`. No widget uses a literal colour.
- Every shell widget paints through the active `LifeOSSkin`. No widget branches on a skin's name, and switching skins never changes layout, behaviour, copy or data.
- Routes still carry only structural state. Desks, tiles and views are referenced by UUID; filter values in views are IDs, states and dates only.
- `record_events` is written in the same transaction as the mutation it records. A failed, stale or uncertain mutation writes no event.
- The Journal and tree values are derived on read. Do not add summary tables.
- Mouse-first: every action is a visible labelled button, and right-click menus repeat the record's actions. Shortcuts are shown in menus and tooltips.
- Synthetic data only in tests, goldens and screenshots.
- Before the first UI edit, load the Impeccable skill and its craft floor, and read the surface brief for `lib/features/work/presentation/work_screen.dart`. Its direction contract is the Office Machine contract.
- End every implementation commit with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.

## Review Focus

1. **Theme contrast:** every text token pair meets 4.5:1 and every indicator 3:1 in day, night and high contrast. Tested in Task 1.
2. **Navigation at every width:** at 960 pixels wide, the tree is reachable through **Books** and a selected record keeps its draft. Tested in Task 2.
3. **Formula bar agrees with the cell:** an explanation is built from the same result object as the value it explains, with no second calculation. Tested in Task 4.
4. **History is transactional:** a stale or failed command appends no event, and a committed one appends exactly one. Tested in Task 5.
5. **Derived Journal:** Journal rows come from facts and events, and a voided shift appears as voided with its replacement, never twice as effective. Tested in Task 9.
6. **Skins change paint only:** the same widget tree, semantics and hit targets exist under Office Machine and Millennium. Tested in Task 11.

---

## File responsibilities

- `lib/shared/workbench/lifeos_tokens.dart`: Office Machine tokens for day, night and high contrast; area keys; contrast helper.
- `lib/shared/workbench/lifeos_skin.dart`: `LifeOSSkin` (tokens, typography, painters) and the appearance registry.
- `lib/shared/workbench/skins/millennium_skin.dart`: the optional Millennium appearance (spec 4.7).
- `lib/shared/workbench/lifeos_theme.dart`: builds `ThemeData` behaviour substrate from tokens; text styles; reduced motion.
- `lib/shared/workbench/office_controls.dart`: `KeyButton`, `KeyChip`, `AreaKey`, `CountBadge`, `SegmentedTabs`.
- `lib/shared/shell/shell_frame.dart`: regions and width behaviour (spec 5.1–5.2).
- `lib/shared/shell/menu_bar.dart`, `toolbar.dart`, `formula_bar.dart`, `status_line.dart`, `book_tree.dart`, `desk_view.dart`, `inspector_pane.dart`.
- `lib/shared/shell/navigation_history.dart`: back and forward stack.
- `lib/shared/workbench/data_register.dart`: Register v2 (spec 6.2).
- `lib/core/explain/explanation.dart`: `Explanation`, `ExplanationToken`, `SourceRef`.
- `lib/core/history/record_events.dart`: table, DAO and `RecordEvent` value.
- `lib/core/desks/`: desk, tile and saved-view tables, DAOs, repository and starter desks.
- `lib/features/journal/`: journal projection, controller and sheet.
- `lib/features/work/presentation/`: Work sheets, toolbar controls, inspector Record tab, quick-add entries.
- `lib/features/work/application/work_explanations.dart`: Work explanations from `ExpectedPay`, reconciliation and paid-time results.
- `assets/fonts/`: Archivo, Azeret Mono and the chosen Millennium face, each with its licence file.

### Task 1: Office Machine tokens, fonts and controls

**Files:**
- Create: `lib/shared/workbench/lifeos_tokens.dart`
- Create: `lib/shared/workbench/lifeos_skin.dart`
- Modify: `lib/shared/workbench/lifeos_theme.dart`
- Create: `lib/shared/workbench/office_controls.dart`
- Modify: `pubspec.yaml` (fonts)
- Create: `assets/fonts/` (Archivo, Azeret Mono, `OFL.txt`)
- Create: `test/shared/workbench/lifeos_tokens_test.dart`
- Create: `test/shared/workbench/office_controls_test.dart`

**Interfaces:**

```dart
enum LifeOSAppearance { system, day, night, highContrast }
enum LifeOSArea { work, finance, tracking, knowledge }

@immutable
final class LifeOSTokens {
  const LifeOSTokens({required this.ground, required this.paper, required this.ink,
    required this.muted, required this.rule, required this.band, required this.chrome,
    required this.chromeLine, required this.head, required this.headInk, required this.signal,
    required this.actionFill, required this.actionInk, required this.runInk,
    required this.selWash, required this.negative, required this.positive,
    required this.focus, required this.areaKeys});
  static const day = LifeOSTokens(/* spec 4.2 day column */);
  static const night = LifeOSTokens(/* spec 4.2 night column */);
  static const highContrast = LifeOSTokens(/* spec 4.2 high contrast column */);
  final Map<LifeOSArea, ({Color fill, Color ink})> areaKeys;
  // ...fields
}

double contrastRatio(Color a, Color b);

enum AreaMarkerStyle { colour, pattern }

abstract interface class LifeOSSkin {
  String get name;                       // "Office Machine", "Millennium"
  LifeOSTokens tokensFor(Brightness system, {required bool highContrast});
  LifeOSTypography typographyFor(double textScale);
  AreaMarkerStyle get areaMarkers;
  SkinPainters get painters;             // buttons, tabs, tile headers, tree, formula bar,
                                         // progress, selection, focus, status line
}

final class OfficeMachineSkin implements LifeOSSkin { /* spec 4.1–4.6 */ }
```

Task 1 implements only `OfficeMachineSkin`, but every control built here must take its painting from `LifeOSSkin.painters` so Task 11 adds skins without touching widgets.

- [x] **Step 1: Write failing token tests.** For each palette, assert `contrastRatio` ≥ 4.5 for ink, muted, runInk, negative and positive on paper, band and chrome; for actionInk on actionFill; for headInk on head; and for each area key's ink on its fill. Assert ≥ 3.0 for signal on paper.
- [x] **Step 2: Run** `flutter test test/shared/workbench/lifeos_tokens_test.dart`. Expected: FAIL (no tokens).
- [x] **Step 3: Implement tokens** with the exact values from spec 4.2. Expose them through a `LifeOSTheme` `InheritedWidget` or `ThemeExtension`. Resolve `system` from `MediaQuery.platformBrightness` and `highContrast`.
- [x] **Step 4: Bundle fonts.** Add the font files and `OFL.txt`, declare the families in `pubspec.yaml`, and build text styles per spec 4.3. Figures use `FontFeature.tabularFigures()`.
- [x] **Step 5: Implement controls through `SkinPainters` and test them.**
  - `KeyButton` (primary, secondary, small) has a 2-pixel bottom edge and loses it when pressed.
  - `AreaKey` chip with letter and semantics label (for example "Work").
  - `CountBadge`.
  - `SegmentedTabs`.
  - Widget tests: the focus ring is distinct from selection, the pressed state removes the edge, and 200% text scale does not overflow.
- [x] **Step 6: Run** `flutter test test/shared/workbench && flutter analyze`. Expected: PASS.
- [x] **Step 7: Commit** `feat: add Office Machine tokens, fonts and key controls`.

### Task 2: Shell frame, tree, menus, toolbar and status line

**Files:**
- Create: `lib/shared/shell/shell_frame.dart`, `menu_bar.dart`, `toolbar.dart`, `status_line.dart`, `book_tree.dart`, `inspector_pane.dart`
- Modify: `lib/app/app_router.dart` (shell route wrapping `/today`, `/work`, `/journal`, `/views/<uuid>`, `/finance`, `/tracking`, `/knowledge`, `/system/files`)
- Delete after migration: `lib/shared/workbench/system_rail.dart`, `lib/shared/workbench/lifeos_frame.dart`
- Create: `test/shared/shell/shell_frame_test.dart`, `book_tree_test.dart`, `status_line_test.dart`

**Interfaces:**

```dart
final class ShellFrame extends StatelessWidget {
  const ShellFrame({required this.tree, required this.desk, required this.inspector,
    required this.formulaBar, required this.status, required this.inspectorOpen,
    required this.onBackToDesk, super.key});
}

sealed class TreeNode { const TreeNode(); }
final class TreeArea extends TreeNode { /* area, label, children, built */ }
final class TreeSheet extends TreeNode { /* sheetRef, label, liveValue, needsYou */ }

final class StatusSnapshot {
  const StatusSnapshot({this.runningShift, required this.needsYou,
    required this.openDrafts, required this.lastSave});
}
```

- [x] **Step 1: Write failing frame tests.**
  - At 1280 × 800, all eight landmarks are present (spec 9).
  - At 1100, opening a record shows the inspector in place of the desk with **Back to desk**, and the desk's selection survives.
  - At 960, **Books** opens the tree pane, and choosing a sheet returns to the desk.
  - No width produces page-level horizontal overflow.
- [x] **Step 2: Write failing tree tests.**
  - Finance, Tracking and Knowledge show "Not built yet" and open an honest unavailable sheet.
  - A Work employment node shows the running state from the projection.
  - Right-click lists Open, Open on new desk and Add to desk.
- [x] **Step 3: Run** the shell tests. Expected: FAIL.
- [x] **Step 4: Implement** the frame, menu bar (spec 5.3; unbuilt items disabled with a reason tooltip), toolbar, tree, status line and routes. Rename `/money` to `/finance` and `/habits` to `/tracking`, and add `/knowledge`. Keep `/work` query parameters exactly as the master plan defines them.
- [x] **Step 5: Run** the shell tests, then `flutter test` and `flutter analyze`. Expected: PASS.
- [x] **Step 6: Commit** `feat: replace the rail frame with the Office Machine shell`.

### Task 3: Register v2

**Files:**
- Modify: `lib/shared/workbench/data_register.dart`
- Modify: `test/shared/workbench/data_register_test.dart`

**Interfaces:**

```dart
enum ColumnKind { text, date, time, duration, money, quantity, state, area, derived }

final class RegisterColumn<Row> {
  const RegisterColumn({required this.key, required this.label, required this.kind,
    required this.width, required this.value, this.explain, this.optional = false});
  final Explanation? Function(Row row)? explain; // derived cells only
}

sealed class RegisterLine<Row> { const RegisterLine(); }
final class GroupLine<Row> extends RegisterLine<Row> { /* label, summary */ }
final class RowLine<Row> extends RegisterLine<Row> { /* row, state */ }
final class SubtotalLine<Row> extends RegisterLine<Row> { /* cells */ }
final class EntryLine<Row> extends RegisterLine<Row> { /* hint, onOpen */ }

enum RowState { normal, draft, running, voided }

final class CellRef { const CellRef(this.rowId, this.columnKey); }
```

- [x] **Step 1: Write failing tests.**
  - Clicking or using the arrow keys moves the cell selection, and Enter opens the row.
  - Group and subtotal lines are not selectable.
  - A voided row is struck and announced as "Void".
  - The entry line calls `onOpen`.
  - The right-click menu lists the actions passed for the row.
  - Optional columns hide before the table scrolls at narrow widths.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** with tokens only. Publish the selected `CellRef` and its `Explanation` through a provider that the formula bar watches.
- [x] **Step 4: Run** the register tests and analysis. Expected: PASS.
- [x] **Step 5: Commit** `feat: add typed register lines, cell selection and entry row`.

### Task 4: Explanations and formula bar

**Files:**
- Create: `lib/core/explain/explanation.dart` (created in Task 3)
- Create: `lib/features/work/presentation/work_explanations.dart` and `work_formats.dart` (presentation, because explanations hold display text and record routes)
- Create: `lib/shared/shell/formula_bar.dart`
- Create: `test/features/work/presentation/work_explanations_test.dart`
- Create: `test/shared/shell/formula_bar_test.dart`

**Interfaces:**

```dart
sealed class ExplanationToken { const ExplanationToken(); }
final class TextToken extends ExplanationToken { const TextToken(this.text); final String text; }
final class OperandToken extends ExplanationToken {
  const OperandToken(this.text, this.source); final String text; final SourceRef source;
}
final class ResultToken extends ExplanationToken { const ResultToken(this.text); final String text; }

final class SourceRef { const SourceRef(this.route); final Uri route; } // structural route only

final class Explanation {
  const Explanation({required this.label, required this.tokens, this.source});
  final String label; final List<ExplanationToken> tokens; final SourceRef? source;
}

Explanation explainPaidTime(FinalizationFacts facts, TimezoneService zones);
Explanation explainExpectedPay(FinalizationFacts facts, ExpectedPay pay);
Explanation explainPeriodExpected(ReconciliationGroup group);
Explanation explainDifference(ReconciliationGroup group);
```

- [x] **Step 1: Write failing explanation tests.**
  - The `ResultToken` text equals the formatted cell value from the same `ExpectedPay`, with and without overtime. The night, holiday and stacking cases are added when the premiums spec lands and `ExpectedPay` gains its breakdown.
  - Operand routes are structural: they contain no money, notes or labels.
- [x] **Step 2: Write failing formula-bar tests.**
  - Shows the cell reference, label and tokens.
  - Clicking an operand navigates to its source.
  - A non-derived cell reads "Recorded fact · entered …".
  - The bar is empty with no selection.
  - **Copy explanation** copies the plain text.
- [x] **Step 3: Run.** Expected: FAIL.
- [x] **Step 4: Implement.** Build explanations only from result objects; never recompute pay.
- [x] **Step 5: Run** the tests and analysis. Expected: PASS.
- [x] **Step 6: Commit** `feat: explain derived Work values in the formula bar`.

### Task 5: Record history

**Files:**
- Create: `lib/core/history/record_events.dart` (types, table, `diffFacts`), `lib/core/history/record_event_dao.dart`, `lib/features/work/data/work_history.dart` (fact describers, `WorkHistoryWriter`)
- Modify: `lib/core/database/app_database.dart` and its generated file (schema per spec 8, joining the reset history from the premiums spec)
- Modify: Work repositories (`DriftWorkRepository`, `DriftShiftRepository` take an `AppClock`; each write appends its event inside its transaction)
- Create: `test/core/history/record_events_test.dart`
- Modify: Work application tests

**Interfaces:**

```dart
enum RecordEventKind { created, changed, finalized, voided, replaced, reviewed }

final class FieldChange { const FieldChange(this.field, this.before, this.after); /* display strings */ }

final class RecordEvent {
  const RecordEvent({required this.id, required this.recordKind, required this.recordId,
    required this.atUtc, required this.kind, required this.changes, this.reason,
    required this.revisionAfter});
}

abstract interface class RecordHistory {
  Stream<List<RecordEvent>> watch(String recordKind, String recordId);
}
```

- [x] **Step 1: Write failing tests.**
  - Each Work command (create employment, update employment, create or update agreement, start shift, start or end break, end shift, finalize, manual shift, revise draft, void and replace, create period, review period, record payslip, correct payslip) appends exactly one event with the correct kind.
  - Stale, invalid and missing outcomes append none.
  - An injected commit failure leaves no orphan event.
  - Decisions made while building: a correction touches two records, so it appends `voided` on the original (with the reason) and `replaced` on the replacement, one event per record. A manual shift is `created`, and a revised replacement draft is `finalized`. Deleting an employment deletes its history and its agreements' history.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** the table, DAO and appends. `changes_json` holds formatted field values for display. It is local data, so it is never logged, never in diagnostics, and never in routes.
- [x] **Step 4: Regenerate Drift output and update the fingerprint test.** Run `dart run build_runner build --delete-conflicting-outputs`, then the database tests.
- [x] **Step 5: Run** the full suite and analysis. Expected: PASS.
- [x] **Step 6: Commit** `feat: record an append-only history for Work records`.

### Task 6: Work in the shell (Phase 0)

**Files:**
- Modify: `lib/features/work/presentation/work_screen.dart`, `work_register.dart`, `work_inspector.dart`, `shift_forms.dart`, `period_payslip_forms.dart`, `employment_agreement_forms.dart`, `work_controller.dart`
- Create: `lib/features/work/presentation/work_sheets.dart` (Shifts, Pay periods, Payslips, Agreements)
- Create: `lib/features/work/presentation/work_toolbar_controls.dart` (employment switcher, period picker, state filter)
- Modify: `test/features/work/presentation/*`
- Also built: `record_history_panel.dart` (Details/History tabs over `record_events`), the unified register load in `work_repository.dart` with `ShiftSheetRow`, `PeriodSheetRow` and `AgreementSheetRow`, and `sheet` and `void` route parameters. The forms keep their Material controls inside the shell; restyling them into office controls is left for the finish review (Task 12).

- [x] **Step 1: Write failing tests for every gap in spec 7.1.**
  - The employment switcher lists employments, marks the current one, and offers All employments and Create employment.
  - The period picker steps with ‹ › and accepts an explicit range.
  - The state filter hides voided rows by default and shows them on request.
  - Shift columns match spec 7.2, and states read Running, On break, Draft, Finalized and Void.
  - A finalized shift's inspector shows its facts and the regular, night, holiday and overtime breakdown with the estimate note.
- [x] **Step 2: Write failing state-matrix tests.** Every inspector mode from foundation spec 15.4, except overtime confirmation, renders inside the shell with one inspector landmark and a stable desk.
- [x] **Step 3: Run.** Expected: FAIL.
- [x] **Step 4: Implement** the sheets on Register v2, attach explanations to Paid, Night, Holiday, OT, Est. pay, Expected, Paid and Difference, add the History tab, and apply the copy from spec 7.3.
- [x] **Step 5: Run** the Work presentation tests, the full suite and analysis. Expected: PASS.
- [x] **Step 6: Commit** `feat: move Work into the Office Machine shell`.

### Task 7: Back and forward

**Files:**
- Create: `lib/shared/shell/navigation_history.dart`
- Modify: `toolbar.dart`, `menu_bar.dart`, `shell_frame.dart`
- Create: `test/shared/shell/navigation_history_test.dart`

- [x] **Step 1: Write failing tests.**
  - Back returns to the previous location and Forward re-applies it.
  - New navigation clears the forward stack.
  - The stack caps at 100 entries.
  - Pointer buttons 4 and 5 (`kBackMouseButton`, `kForwardMouseButton`) trigger Back and Forward.
  - Disabled buttons announce "Back, unavailable".
- [x] **Step 2: Run, implement, run.** Expected: FAIL, then PASS.
- [x] **Step 3: Commit** `feat: add back and forward navigation`.

### Task 8: Quick add and "from last time"

**Files:**
- Create: `lib/shared/shell/quick_add.dart`
- Create: `lib/features/work/application/work_templates.dart`
- Create: `test/features/work/application/work_templates_test.dart`, `test/shared/shell/quick_add_test.dart`

**Interfaces:**

```dart
final class QuickAddEntry {
  const QuickAddEntry({required this.area, required this.label, required this.open});
  final LifeOSArea area; final String label; final VoidCallback open;
}

ManualShiftDraft? manualShiftFromLastTime(ShiftRecordProjection? last, LocalDate today);
```

- [ ] **Step 1: Write failing tests.**
  - "+ Add" lists the six Phase 0–1 record types.
  - "Manual shift from last time" uses the last shift's employment, local start and end times, break pattern and timezone on today's date.
  - With no previous shift, the button is absent.
  - Prefill never sets a value the owner did not enter before.
- [ ] **Step 2: Run, implement, run.** Expected: FAIL, then PASS.
- [ ] **Step 3: Commit** `feat: add quick add and prefilled Work templates`.

### Task 9: Journal, desks and starter desks

**Files:**
- Create: `lib/features/journal/journal_projection.dart`, `journal_controller.dart`, `journal_sheet.dart`
- Create: `lib/core/desks/desk_tables.dart`, `desk_repository.dart`, `starter_desks.dart`
- Create: `lib/shared/shell/desk_view.dart`
- Create: `test/features/journal/journal_projection_test.dart`, `test/core/desks/desk_repository_test.dart`, `test/shared/shell/desk_view_test.dart`

**Interfaces:**

```dart
final class JournalEntry {
  const JournalEntry({required this.atUtc, required this.area, required this.kind,
    required this.recordRef, required this.summary, this.amount, required this.state});
}

abstract interface class JournalSource { Stream<List<JournalEntry>> watch(LocalDate from, LocalDate to); }

enum DeskLayout { single, twoColumns, mainAndSide }
final class Desk { /* id, name, starterKey, layout, position, revision, tiles */ }
final class DeskTile { /* id, position, sheetRef, viewId */ }
```

- [ ] **Step 1: Write failing journal tests.**
  - Work events appear in time order.
  - A void-and-replace shows the original as Void and the replacement once.
  - Day summaries equal the sum of their rows.
  - Days use the shift's captured timezone.
- [ ] **Step 2: Write failing desk tests.**
  - First launch creates Today, Weekly review and Month close as in spec 6.4.
  - Today cannot be deleted.
  - Reset restores a starter desk.
  - Adding a sheet to a tiled desk replaces the focused tile.
  - Concurrent edits return `Stale`.
- [ ] **Step 3: Write failing tile tests.**
  - Needs you lists the running shift, drafts and open periods with a difference, and shows the empty copy from spec 7.3.
  - The Month close checklist reflects only facts.
- [ ] **Step 4: Run, implement, run.** Expected: FAIL, then PASS.
- [ ] **Step 5: Commit** `feat: add the Journal and starter desks`.

### Task 10: Saved views

**Files:**
- Create: `lib/core/desks/saved_views.dart`
- Modify: `book_tree.dart`, `data_register.dart` (Save as view), `desk_view.dart`
- Create: `test/core/desks/saved_views_test.dart`

- [ ] **Step 1: Write failing tests.**
  - Save as view stores the sheet, filters, sort and columns, and the view re-opens identically.
  - Rename and delete work; a stale revision returns `Stale`.
  - Filters reject free text, so personal values cannot be stored.
  - Views appear under Views in the tree and can be placed on a desk.
- [ ] **Step 2: Run, implement, run.** Expected: FAIL, then PASS.
- [ ] **Step 3: Commit** `feat: save filtered sheets as named views`.

### Task 11: Millennium appearance

**Files:**
- Create: `lib/shared/workbench/skins/millennium_skin.dart`
- Modify: `lib/shared/workbench/lifeos_skin.dart` (registry), `lib/shared/shell/menu_bar.dart` (View › Appearance), preferences (appearance value)
- Modify: `pubspec.yaml` and `assets/fonts/` (the Millennium face after licence review)
- Create: `test/shared/workbench/skins_test.dart`, goldens under `test/goldens/skins_*`

- [ ] **Step 1: Write failing tests.**
  - Every Millennium text pair meets 4.5:1, and every indicator 3:1 (spec 4.7).
  - The semantics tree and hit-test regions of the 1280 × 800 shell are identical under Office Machine and Millennium.
  - With the system high-contrast flag on, Millennium falls back to the Office Machine high-contrast tokens.
  - Choosing an appearance persists it as a preference and restores it on restart.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Choose and bundle the Millennium face.** Review candidate Tahoma-metric faces' licences, and bundle one with its notice, or fall back to Noto Sans. Record the decision and licence in `assets/fonts/README.md`.
- [ ] **Step 4: Implement the skin** with the tokens and painting rules from spec 4.7. Use no Microsoft names, logos, icons, wallpapers or sounds.
- [ ] **Step 5: Run** the skin tests, the full suite and analysis. Expected: PASS.
- [ ] **Step 6: Commit** `feat: add the Millennium appearance`.

### Task 12: Verification, finish review and documentation

**Files:**
- Create: `test/goldens/shell_*` (day, night, high contrast; synthetic data)
- Create: `integration_test/shell_work_flow_test.dart`
- Modify: `app.sh` (only if commands changed), `README.md`, `DESIGN.md`, `.impeccable/design.json`

- [ ] **Step 1: Add the integration flow from spec 10.** Fresh install → Today → create employment from Needs you → agreement with defaults → start shift → end → finalize. Then check the formula bar explanation, four History events and the Journal row.
- [ ] **Step 2: Add goldens** at 1280 × 800 and 960 × 760 for every appearance: Office Machine day, night and high contrast; Millennium.
- [ ] **Step 3: Run** `dart format --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test`, and the integration test against a guarded disposable root. Expected: all PASS.
- [ ] **Step 4: Run the bounded Impeccable finish.** One batched capture of the shipped device classes, the finish reviewer against the direction contract, one batch of fixes and at most one confirmation pass.
- [ ] **Step 5: Rewrite `DESIGN.md` and `.impeccable/design.json` from the built shell** using the Impeccable documenter. Remove the superseded-direction note at the top of `DESIGN.md`.
- [ ] **Step 6: Verify `./app.sh`** starts and tests the app (repository rule in `CLAUDE.md`), and update it if commands changed.
- [ ] **Step 7: Commit** `docs: document the shipped Office Machine shell`.

## Plan self-review

**Spec coverage:**
- Spec section 4 → Task 1.
- Section 5 and 6.1 → Task 2.
- Section 6.2 → Task 3.
- Section 6.3 → Task 4.
- Sections 6.6 and 8 (`record_events`) → Task 5.
- Section 7 → Task 6.
- Section 6.8 → Task 7.
- Section 6.7 → Task 8.
- Sections 6.4, 6.5 and 8 (desks) → Task 9.
- Section 6.9 → Task 10.
- Section 4.7 → Task 11.
- Sections 9 and 10 → Tasks 1–12, closed in Task 12.

Each Review Focus item names its task.

**Ordering:** Tasks 1–5 are independent of the premiums prerequisite. Task 6 needs it. Tasks 7–10 build on Tasks 2–3. Task 11 needs only Tasks 1–3, so it can run in parallel with 4–10. Task 12 closes the phase.

**Privacy:**
- Routes, view filters and tile references are structural.
- History values live only in SQLite.
- Goldens use synthetic data.

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-10-01-lifeos-office-machine-shell.md`. Review the plan and the spec before execution.
