# LifeOS Database Shell and UI Library Design

Date: 2026-10-08
Status: layout C2, version 3 approved in conversation 2026-10-08. Revised
2026-10-09 at the owner's request after review: data-entry-only keyboard,
confirmation windows only, explicit save and finalization rules, guarded
shutdown, outcome recovery, complete Work navigation, and phased cutover.
Amends: `2026-10-04-lifeos-xp-authentic-shell-design.md` and
`2026-10-02-lifeos-millennium-shell-design.md`. This document replaces their
shell layout, task pane, address bar, Details group, Properties dialogs, form
dialogs, desks, saved views and Journal. Their era look (font, colours,
bevels, icons, scrollbars, pickers, menus) stays in force. Section 4.6
replaces their keyboard behavior, including picker keys.
Visual reference: `assets/2026-10-08-database-shell-mockup.html` and
`assets/2026-10-08-database-shell-1280x800.png` (next to this file).

## 1. Purpose

LifeOS looks like a 2001 office program but is arranged like that era's file
browser: a task pane on the left, a details list, and records that open in
Properties dialogs. For a records app this hides data behind clicks and
leaves the screen half empty.

This project rearranges LifeOS as a database program of the same era (an
Access or VB-style front end): area tabs across the top, an object tree on
the left, an editable datasheet in the middle with a subform of the record's
children under it, and the selected record's properties, edited in place, on
the right. Every region is filled with data; nothing on the screen is
decoration or empty space.

It also establishes a **UI library**: every visual part lives in one place
(`lib/ui/`), is listed in one inventory (`lib/ui/CATALOG.md`), can be seen in
a gallery, and is found by future sessions through a project skill.

## 2. Decisions

| Topic | Decision |
|---|---|
| Layout | C2: area tabs; object tree + Details (left); filter strip, data grid, subform (middle); property column (right). |
| Navigation | Area tabs (Work, Finance, Tracking, Knowledge) and the object tree. The address bar and task pane are removed. |
| Editing | Access-style pending edits, saved on leaving the record or with Save, reverted with Undo. The save matrix in section 4.2 governs persistence; finalization and repricing always require confirmation. Cells, properties and editable children share one pending edit. |
| Keyboard | Only for entering data in an editor (section 4.6). No shortcuts: selecting, moving between regions, saving, finding and navigating are done with the mouse. |
| Dialogs | None. Everything is inline: creating and editing in the grid and property column, multi-step actions as **action panels** in the property column. The only windows are small **confirmation windows** (section 4.7). |
| Desks | Retired, with their tables, menu and code. |
| Saved views | Retired with desks (they live in the desk tables). |
| Journal | Dropped. A record's History subform covers changes per record. |
| UI library | `lib/ui/` behind one import, `CATALOG.md`, a gallery, goldens, guard tests and the `lifeos-ui` project skill. |
| Migration | Approach A: one branch in five phases; the app stays runnable and `./app.sh` green after each phase. Build and test the new shell before a single production cutover in phase 4. No runtime flag or second production shell. |
| Data | Presentation only. Domain tables, services, calculations, history and outcomes do not change. Only the desk and saved-view tables are dropped. |

## 3. Layout (1280 × 800)

From top to bottom:

1. **Menu bar** (24 px): File, Edit, View, Record, Tools, Window, Help. The
   Desk menu goes.
2. **Banded toolbar** (38 px). Bands start with a dotted gripper and are
   split by etched lines:
   - Back and Forward (green orbs; grey when there is nowhere to go).
   - **Add ▾** (orange orb): **Employment…** is always available in Work,
     followed by the record kinds the current sheet can create.
   - Record band: Save, Undo, Delete.
   - Sheet band: the sheet's actions, for Shifts *Confirm worked days…*,
     *Mark as leave…*, *Correct…*. A key whose action does not apply is
     greyed, not removed, so the band never shifts.
   - Data band: Filter by selection, Remove filter, Sort.
   - **Find:** box on the right.
3. **Area tabs** (28 px; tabs 24 px, the active one 27 px with the amber top
   bar): Work, Finance, Tracking, Knowledge, each with its painted icon. An
   unbuilt area is muted, has a grey icon and the tooltip "Not built yet".
4. **Tab page**, three columns split by 5 px draggable splitters whose
   positions are remembered per area:
   - **Left, 196 px.** A pane caption with the area's icon and name, then the
     **object tree**: each employment, expanded, with its sheets and live
     counts: Calendar, Shifts (n), Leave (n), Schedules (n), Pay periods (n),
     Payslips (n), Agreements (n), and **⚠ To confirm (n)** in run ink when
     n > 0. Ended employments sit in a muted "Ended employments (n)" folder.
     The tree takes its content height. Under it, a **Details** box fills the
     rest: the employment's agreement (link), hourly rate, night premium,
     schedule (link), open period, confirmed pay so far, last payslip (link),
     leave left; then the period's counts (finalized, to confirm, planned,
     leave, off); then the next shift.
   - **Middle, flexible.**
     - **Filter strip** (32 px): Period with ◂ ▸ step keys and a range combo,
       Status, Type, an *Off days* check box, and **Clear**.
     - **Data grid**: bevelled headers, the sorted column tinted, group rows
       (`October 2026`), 20 px rows, a totals footer (`Total (15 shifts)`,
       break, paid, night, holiday, est. pay), and a bottom bar with the
       record navigator (`Record: |◂ ◂ [7] ▸ ▸| ▸* of 31`), the active filter
       ("Filtered: Period") and the horizontal scrollbar.
     - A 5 px splitter.
     - **Subform** (168 px): tabs for the selected record's children with a
       count, and on the right "for Shift Wed 2026-10-07". Shifts have
     Breaks, History, Working and Day plan. A planned day has no shift record
     yet: History shows only persisted events, with an empty state when
     there are none. Pending changes are never fabricated history events.
   - **Right, 306 px: the property column.**
     - **Object box** (22 px): record icon, bold name, muted kind, and a drop
       arrow listing the sheet's records.
     - Toolbar (26 px): Categorized, A↓Z, and an *Edited* marker while an
       edit is pending.
     - **Property grid** filling the height.
     - **Description pane** (58 px): the selected property's name in bold and
       one or two lines about it, or the reason it is read-only, or the
       validation problem.
5. **Status bar** (22 px), sunken panels: the last notice or the pending
   edit ("Unsaved plan change: 2026-10-07, End 19:00 → 19:45. Save, or
   leave the day, to keep it. Confirmation is separate."), the count, paid
   time, est. pay, "n days to confirm" in run ink, "Local database", and a
   size grip.

**Narrow windows.** Below 1024 px the left column folds into a **Tree**
toolbar key that opens it over the content, and the property column narrows
to 260 px. Below 860 px the property column docks under the grid as a tab
beside the subform tabs. An active action panel occupies that same docked
property tab; its primary and Cancel keys remain reachable.

**Text scaling and overflow.** Pixel dimensions above are baseline sizes at
100 % text. Text-bearing rows and controls use those dimensions as minima
and grow to fit measured text plus padding; font size is never clamped to
make them fit. The toolbar and filters wrap into additional rows. Status
panels wrap, and long notices and validation descriptions grow and scroll
within their region. Property labels may stack above values. The tree,
Details and property contents scroll independently; the tree's content
height is capped so it cannot consume the whole left column. Grid columns
keep usable field widths and scroll horizontally. Splitters clamp restored
positions to the available space and permit vertical resizing of the
subform. Folding also occurs when measured minimum widths no longer fit,
even above the nominal breakpoints. At 800 × 600 and 200 % text the owner
can still reach every editor, error, Save, Undo and action-panel footer.

**The Calendar sheet** shows the existing month view (`WorkCalendar`) in the
middle column instead of the grid; the subform and property column follow
the selected day.

**Retired:** task pane, address bar, desks and desk tabs, saved views,
Journal, Properties dialogs, form dialogs (`ShellDialog` forms), the Books
tree.

## 4. Interaction

### 4.1 Focus and selection

Exactly one region is active: the tree, grid, subform or property grid
last clicked. Its selection is solid blue; the others show their selection
in face grey. Clicking a row selects it; clicking an editable cell of the
selected row, or an editable value in the property grid, opens its editor.
An open editor shows the 1 px key-line border and caret; selection and
editing never look the same (DESIGN.md rule unchanged).

### 4.2 The edit session

- Editing a grid cell or a property starts a **pending edit** on that
  record. The row selector shows ✎; changed values are bold; the property
  grid shows "(was …)" after a changed value; derived values (paid time,
  premiums, est. pay, plan difference) are recomputed live as a preview; the
  status bar describes the change.
- **Save** and leaving the record use the same guarded save operation.
  A different row, sheet, area, tree node or navigation is applied only
  after a successful save or an explicit discard. The matrix below defines
  what is written; selecting another row must never silently finalize work.
- **Undo** reverts the record to its saved values. While a value is being
  typed, Esc throws away that value only (section 4.6).
- **Validation** runs when a field is left. A bad value stays in a
  red-bordered editor with the reason in the description pane; the record
  cannot be left until it is fixed or reverted.
- **Repricing guard.** If an agreement correction changes confirmed pay,
  preview the existing service's full impact, including affected leave,
  before asking *Save and reprice*, *Revert*, *Cancel*. Pass that confirmed
  impact to the existing command. If it changes before commit, refresh the
  preview and ask again; never reuse consent for a different impact.
- **Read-only facts.** Finalized and voided shifts, existing pay periods
  and payslips show grey values; the description names their permitted
  action. An agreement in use retains the current app's guarded correction
  behavior, as specified below. Derived values are always read-only.

**Save matrix.** The adapter selects the existing command by object kind
and lifecycle state, not just by the visible sheet or edited field.

| Object being edited | Save / leave behavior | Existing service boundary |
|---|---|---|
| Unconfirmed planned work day | Save a day exception; it remains unconfirmed. Confirm worked days is a separate action. A planned day is identified by employment and local date, not a fabricated shift ID. | `DayPlanService.changeDay` for times, type and breaks; other day changes use the existing day-plan actions. |
| New manual shift or existing draft shift, including a correction's replacement draft | Ask **Save and finalize / Revert / Cancel** before calling the service, including on leave. The window says the shift will become finalized and future changes require Correct. For a new row, Revert is labelled Discard. | `ManualShiftService.createAndFinalize` or `ShiftDraftRevisionService.reviseAndFinalize`; no new save-only draft command. |
| Finalized shift | Facts are read-only. Correct opens an action panel, explicitly voids and replaces through the existing lifecycle command, then selects the replacement draft. Void asks for its reason inline. | `ShiftLifecycleService`; subsequent draft editing follows the row above. |
| Employment; new or unused agreement | Save through the existing create/update command and its validation. Archive, delete and date-changing actions stay explicit. | `EmploymentService`, `AgreementService`. |
| Agreement in use | Editing existing terms is a correction with the repricing guard. **Change terms from…** starts new terms from a date; **End agreement…** changes its end through their existing commands. | `AgreementService.updateAgreement`, `changeAgreementTerms`, `closeAgreement` and the existing correction-impact preview. |
| New or unused schedule | Save the schedule, shift types and cycle together. | `ScheduleService.create` / `update`. |
| Schedule version used by confirmed days | Keep saved facts read-only; **Change schedule from…** opens an action panel with a new-version start date and editable cycle. Apply calls the existing versioning command. | `ScheduleService.update(newVersionFrom: ...)`; confirmed days retain their version. |
| New pay period or payslip | Save through its existing create/record command. Recording a payslip asks **Record payslip / Discard / Cancel** before writing money evidence, including on leave. | `PayPeriodService`, `PayslipService`. |
| Existing pay period, payslip or confirmed leave | Facts are read-only. Review/reopen and correction actions use their existing commands; a correction's form stays inline. | Existing period, payslip and day-plan services. |

**One pending parent and its children.** Shift/day times and breaks share
one edit session and one service submission. A schedule's fields, cycle
blocks and shift types likewise form one pending value. Moving between the
grid, property grid and that parent's child rows or subform tabs does not
save the parent. New child rows have temporary identities until their parent
save succeeds. Save validates the complete parent and children, and Undo
reverts all of them. History and Working are read-only. Starting a separate
action first resolves the pending edit; it must not replace and lose it.

**Navigation during a save.** Flush the active editor into the session,
validate, obtain any confirmation, then await the command. Only one save
may run; repeated Save/leave requests cannot issue duplicate commands.
Freeze editing while it runs. Advance the route and selection only on
`Committed`; failures and cancelled confirmations retain the current
selection and pending values. Cancel means stay; Revert/Discard permits
the original navigation after dropping the pending values. Filtering or
sorting must not evict a dirty row before this guard completes.

### 4.3 Creating and deleting

- **Add ▾** or typing into the `*` row creates a **new row**, selected, with
  defaults filled from the schedule and agreement. The property grid opens
  on its first required field. The record is created only on a successful
  first save under the save matrix. Undo drops an untouched new row; if
  values were entered, Undo or leaving offers **Save / Discard / Cancel**.
  A lifecycle-specific save label, such as **Save and finalize**, replaces
  Save in that same window rather than asking twice. Invalid entered values
  can always be discarded. Merely accepting defaults without entering data
  does not create a record on leave.
- **Delete** asks in a confirmation window. A record the domain only voids (a
  finalized shift) offers **Void…** instead, which runs as an action panel.

### 4.4 Action panels

Multi-step actions (the complete mapping is in section 4.9) open an
**action panel** in the property column:

- The object box shows the action's title; the panel is group boxes of
  `Label:` rows (the existing `EraLabelled` rules), with the primary verb and
  **Cancel** pinned at the bottom, primary first.
- An action over several records puts the grid in **pick mode**: a tick
  column appears, the footer totals the ticked rows, and the tree, filter
  strip and subform are disabled until the panel confirms or cancels.
- Results and failures appear in the panel and the status bar. A record that
  fails keeps its row, marked, with the reason (each day is its own
  transaction, as today).
- An open panel is not part of the route; navigating away cancels it, after
  a confirmation window if anything was entered.
  Cancellation discards only unsubmitted input. Successfully committed
  items in a partly completed bulk action remain saved; the confirmation
  names that fact. Retrying submits only failed eligible items, never the
  already committed ones. An uncertain item follows section 9 before retry.

### 4.5 Navigation and routes

The route carries the area, employment, sheet, filters, selection and subform
tab, for example
`/work?employment={id}&sheet=shifts&from=2026-10-01&to=2026-10-31&record=shift:{id}&sub=breaks`.
Back and Forward walk this history. Following a "Belongs to" link or a
Details link pushes an entry. Leaving a record with a pending edit saves it
first; a failed save stops the navigation on the problem. The existing
`WorkRecordRef` parsing is kept. Planned/off days use the existing `day=`
local-date parameter with `employment=`, mutually exclusive with `record=`.
After confirmation, select the returned stored record. New unsaved rows
never add fabricated IDs to a route. `mode=` and `add=` parameters are removed;
old links ignore these obsolete parameters while retaining a valid target.
The `/today` and `/journal` routes are removed; an old link to either opens
`/work`. The app starts where it was last closed, or, the first time, on
the first active employment's Shifts for the current month. With no active
employment, use the Work overview in section 4.9. Restoring a missing
employment, record or sheet falls back to the nearest valid Work location.
Persist the last successfully resolved location, never an unfinished save
or an action panel.

### 4.6 Keyboard: data entry only

The keyboard is used only inside an open editor, to enter a value:

- typing, Backspace, Delete, and ← → to move the caret within the value;
- the date and time boxes' digit entry and part stepping: Left/Right choose
  a part, Up/Down step that part, and the existing date/time separators
  advance parts; these are editor-local data entry;
- **Enter** or **Tab** commits the value and opens the next editable field
  (the next cell to the right in the grid, the next value down in the
  property grid), skipping derived, read-only and disabled fields; at the
  last editable field, commit and close the editor while retaining the
  same selected record. Do not wrap to another row, region or record;
- **Esc** throws away the value being typed and closes the editor.

There are no other keys. No global shortcuts (no Ctrl+S, Ctrl+F, F-keys or
Alt combinations), no arrow-key movement between rows, tree nodes or
regions, no keyboard menus, and no accelerators shown in menus. Selecting,
expanding, ticking, saving, finding, opening menus and navigating are done
with the mouse. The existing list, tree and menu keyboard handling is
removed with the old shell.

This section overrides the older picker rules: Enter advances fields and
never opens a calendar; Space and Alt+Down no longer open it either. Open
and operate the calendar by mouse. Choice popups are mouse-operated too.
The keys listed above are tested per editor type; printable characters,
Shift for text and platform text composition remain data entry. There are
no application command shortcuts. Enter/Tab do not activate a command or
submit an action panel, and keyboard focus does not traverse into menus,
buttons or other regions when an editor closes.

### 4.7 Confirmation windows

The only windows LifeOS opens. A confirmation window is a small era message
box over the shell: the ⚠ or ℹ sign, one or two sentences, and two or three
push buttons, the affirmative first. It is used only to confirm something
that cannot be taken back or that changes money: deleting a record, the
repricing or finalization guard, leaving an action panel or a new record
with entered values, and a second confirmation for bulk changes (for example
confirming more than one worked day reads "Confirm 3 days? Their pay becomes
final.").
It never holds a form; anything with fields is inline.

### 4.8 Closing the application

Native window close and File › Quit use the same leave guard as navigation.
Intercept the native close request before the window is destroyed. Flush
the current editor, validate and resolve pending edits under section 4.2;
for an invalid draft offer **Discard and quit / Keep editing** so the owner
is not trapped. An action panel with input asks **Discard input and quit /
Keep editing**, identifying any bulk results already committed. Cancelled
confirmation, failed save or unresolved uncertain outcome keeps the window
open. If a command is in flight, wait for its result before deciding to
close; repeated close requests neither resubmit nor bypass the guard.
Remember the resolved route and release database/window resources only
after resolution. Force-kill, crash and power-loss draft recovery are not
promised; these rules cover normal application close.

### 4.9 Work overview and action destinations

Selecting the Work tree root shows an Employments sheet. With no employment,
it displays **Add employment…** in the grid's empty state; when only ended
employments remain, show that action above their rows. **Add ▾ → Employment…**
and **File → New employment…** are always available in Work. Creation is inline: name and
legal label in the property column. After saving, select the employment and
show **Set up pay agreement…**, then **New schedule…** as inline next steps.
Missing agreement/schedule details say what is missing and link to that
action. Selecting an employment node opens its editable properties; its
child sheet nodes open the corresponding sheets. Adding another employment
uses the same flow without disturbing existing employments.

The Record menu and the sheet toolbar expose the same applicable actions.
Unavailable actions are disabled with a reason. This mapping preserves
existing service behavior; it does not grant new domain capabilities.

| Existing workflow | Destination in the new shell |
|---|---|
| Employment create/edit/archive/delete | Work overview or employment node; inline properties; Record actions for archive/delete, with existing eligibility and confirmation. |
| Set up/extend/edit/correct agreement | Agreements sheet and missing-agreement link; inline fields and repricing guard. |
| Change terms from…; End agreement…; remove unused agreement | Agreement toolbar/Record menu; date forms in action panels; deletion confirmation. |
| New schedule; edit unused schedule; change used schedule from a date | Schedules sheet; inline properties and Cycle subform; version-date action panel when used. |
| Shift types add/edit/remove; cycle reorder; schedule preview/delete | Schedule toolbar opens Shift types within the same pending schedule; mouse drag reorders Cycle; Preview subform; deletion confirmation when eligible. |
| New manual shift; from-last-time prefill; finalize draft | Shifts Add menu and inline draft fields; finalization guard on Save; explicit Finalize action for an unchanged draft. |
| Change planned day; Cancel shift; Add extra shift; Mark as leave; revert exception | Shifts, Calendar or To confirm selection; inline day fields or action panel, preserving existing day eligibility and commands. |
| Confirm one day or multiple worked days | Sheet toolbar/Record menu; action panel, eligible-day pick mode, explicit finalization and bulk confirmation. |
| Correct/void recorded shift; correct confirmed leave | Selected record's toolbar/Record menu; action panel using the existing reason and replacement flow. |
| New pay period; Mark reviewed; Reopen period | Pay periods sheet; inline creation; explicit state actions retaining service validation. |
| Record payslip; record for selected period; correct payslip | Payslips Add menu or period's Record payslip action; inline creation or correction panel. |
| Record History, Working and operand links | Subform tabs for the applicable object; operand links use guarded navigation. |
| Licences | Help → Licences in the tab page; guarded Back returns to the prior location. |

Desks, saved views, Journal and their commands are intentionally retired.
Before cutover, audit current menus, forms and task links against this table;
every retained workflow must have a reachable destination and integration
coverage, including zero-employment and no-agreement cases.

## 5. UI Library

### 5.1 Structure

```
lib/ui/
  ui.dart          the one import for feature code
  CATALOG.md       the inventory, one entry per public widget
  foundation/      LifeOSTokens, MillenniumColors, typography, theme and skin,
                   EraIcon, metrics, era dates
  controls/        KeyButton, StepKey, Orb, EraPressable, EraCombo, EraField,
                   EraDateField, EraTimeField, EraMonthCalendar, EraCheckBox,
                   EraRadio, EraMenu / EraContextMenu, EraScrollbar, GroupBox,
                   EtchedLine, CountBadge
  data/            DataGrid, PropertyGrid, TreeView, Subform, RecordNavigator,
                   CellSelection
  shell/           AppFrame, LifeOSMenuBar, BandedToolbar, TabStrip, Splitter,
                   PaneCaption, DetailsBox, StatusBar, ActionPanel,
                   ConfirmWindow, LicencesPage
  gallery/         the gallery app and one demo file per widget
```

Files move with `git mv` so their history stays. Duplicates merge:
`office_controls.dart`, `era_controls.dart`, `inspector_parts.dart` and
`property_sheet.dart` are split into the homes above. `DataRegister`,
`BookTree` and `PropertySheetTabs` are replaced by `DataGrid`, `TreeView` and
`TabStrip` (phase 2) and deleted (phase 5). Diagnostic helpers
(`date_trace.dart`) move to `lib/ui/foundation/` unchanged.

### 5.2 CATALOG.md

It opens with a **"which widget for which job"** table (a list of records →
DataGrid; a record's facts → PropertyGrid; a choice of a few → EraRadio …),
then one entry per public widget in this format:

```
### DataGrid · data/data_grid.dart · stable
Editable datasheet: row selector (▸ ✎ *), sortable bevelled headers, group
rows, totals footer, record navigator, XP scrollbars, pending-edit marks,
pick mode.
Use for: any list of records. Not for: key/value facts (PropertyGrid).
API: DataGrid(columns:, rows:, selection:, onSelect:, onEdit:, footer:, ...)
Gallery: data/data_grid · Goldens: test/ui/goldens/data_grid_*.png
```

Status is `stable`, `new` or `deprecated (use X)`. A deprecated entry stays
until its widget is deleted.

### 5.3 Gallery

`./app.sh` gains **Open widget gallery**, which runs the app with
`--dart-define=LIFEOS_GALLERY=1`. In phase 1 it uses a small gallery-only
host composed of already moved controls and the existing list, with demo
selection and knobs; it depends on none of the phase 2 widgets. In phase 2
the gallery switches to the new library shell as those widgets become ready:
the tree lists the widgets by folder, the middle shows the live demo, and
the property grid edits the demo's knobs (enabled, read-only, error, sizes,
sample data). Every demo also renders a synthetic golden and a real-font
golden. The gallery boots with synthetic fixtures and never opens the
production database. The temporary host is removed in phase 2.

### 5.4 Guard rails (tests)

- No file under `lib/features/` or `lib/app/` imports a file under
  `lib/ui/` other than `ui.dart`.
- Every public widget class in `lib/ui/` has a CATALOG.md entry and a
  gallery demo.
- The existing rules stay: colours only from tokens and `MillenniumColors`;
  glyphs are painted, never font characters.

### 5.5 How sessions find it

- Project skill `.claude/skills/lifeos-ui/SKILL.md`, triggered by any UI
  work in this repository: before writing UI, read `lib/ui/CATALOG.md` and
  reuse; if nothing fits, build the widget in `lib/ui/` with a gallery demo,
  goldens and a catalog entry, then use it. Mirrored for Codex under
  `.agents/`.
- One line in `CLAUDE.md` and in `AGENTS.md` pointing to the catalog and the
  skill.
- A `bd remember` entry with the same pointer.
- `DESIGN.md` stays the visual system and links to `CATALOG.md` as the
  component inventory.

## 6. New Widgets (phase 2)

| Widget | Purpose | Behaviour |
|---|---|---|
| **DataGrid** | The editable datasheet | Typed columns (text, date, time, duration, money, choice, check) flagged editable or derived. Row selector ▸ / ✎ / `*`. Group rows; tinted sorted column; header click sorts ascending, then descending; resizable columns; totals footer; `RecordNavigator`; **pick mode** with a tick column and footer totals of the ticked rows. Rows are virtualised. |
| **PropertyGrid** | Key/value editor | Collapsible categories; Categorized / A↓Z; an in-row editor per value kind reusing EraDateField, EraTimeField, EraCombo, EraCheckBox and EraField; read-only values grey with a reason; "(was …)" after changes; links (`onFollow`); description pane. |
| **TreeView** | The object tree | XP dotted lines, ⊞/⊟ boxes (click to expand or collapse), 16 px icons, counts, warning and muted nodes. Mouse only. |
| **TabStrip** | Era tabs | Area size (24 / 27 px) and subform size (20 / 22 px); amber bar on the active tab; hover edge; disabled tabs. |
| **Subform** | A record's children | TabStrip over a DataGrid, a free panel (Working) or a comparison table (Day plan); tabs declared per record kind. |
| **BandedToolbar** | The toolbar | Bands with grippers and etched lines; flat keys raised on hover, focus or press; disabled keys greyed in place. |
| **ConfirmWindow** | The only window (section 4.7) | Era message box: sign, one or two sentences, two or three push buttons, affirmative first. No fields. |
| **LicencesPage** | Help › Licences | Every package and font with its licence, read-only, shown in the tab page in place of the sheet; Back returns. Replaces LicensesDialog. |
| **ActionPanel** | Inline multi-step action | Title for the object box, group-box form, primary verb + Cancel pinned bottom, result and error rows, drives pick mode. |
| **AppFrame, Splitter, PaneCaption, DetailsBox, StatusBar** | The layout | Three-column page, draggable remembered splitters, the fold rules of section 3, sunken status panels and size grip. |

The **edit session** is not a widget. `EditSession` (in `lib/app/`) holds
the pending record, the dirty field set, validation results, the derived
preview and save / revert. A per-area adapter (`WorkEditAdapter`) calls the
existing application services according to section 4.2
(`day_plan_service`, `shift_lifecycle_service`, `manual_shift_service`,
`agreement_correction`, `schedule_service`, …). It retains the original
revision and parent/child draft, and distinguishes idle, dirty, validating,
awaiting confirmation, saving, committed, failed, stale and uncertain states.
Navigation and native-close guards both use this coordinator. The
widgets render state and report edits only, so they stay free of domain code
and testable in the gallery.

## 7. Phases

Each phase ends with `./app.sh` options 1 to 3 green (start, tests, checks:
analyze, format, schema check), its beads closed and a handoff. Commits and
pushes only when the owner asks.

The production app retains its current shell through phase 3. Shared
controls preserve existing callers' behavior during this transition; the
new editor hosts explicitly apply section 4.6 until the old callers are
removed. The new shell is exercised in gallery and integration harnesses until all Work
destinations are ready. Phase 4 makes one production cutover; no user-facing
feature flag, second shell or temporary loss of a retained Work workflow.
Migrate behavior tests and affected goldens in the same phase as their
behavior changes. Do not postpone updates to obsolete expectations until
phase 5, disable failing tests, or bulk-accept goldens to make checks green.
Unaffected goldens stay unchanged; changed ones are visually reviewed.

| Phase | Done when |
|---|---|
| **1. Library foundation** | Every era widget is under `lib/ui/` behind `ui.dart`; CATALOG.md covers each; the gallery opens from `./app.sh` using its temporary host; guard tests pass; the skill, CLAUDE.md / AGENTS.md lines and `bd remember` pointer exist. Production remains pixel-identical: existing goldens pass unchanged. |
| **2. Data widgets** | Section 6 widgets exist with synthetic and real-font goldens and tests for the editor-specific keyboard contract, mouse selection, pick mode, virtualisation and scaling. The gallery now uses AppFrame, TreeView and PropertyGrid; its temporary host is removed. Production still uses the existing shell and interaction rules. |
| **3. Shell and edit session** | AppFrame and WorkEditAdapter run Shifts end to end in the new-shell integration harness: planned-day versus stored-record selection, parent/child edits, guarded finalization, repricing, validation, all mutation outcomes, single-flight saves, close guards and route round trips. Include inline employment/agreement setup so the harness can start from an empty database. The production shell remains in place until phase 4. |
| **4. Work sheets and production cutover** | All section 4.9 workflows run inline in the new shell, including Employment overview, Leave, Schedules with Cycle and Preview, periods, payslips, agreements, Calendar and To confirm. Each is covered before the single production cutover to AppFrame. Migrate app-level tests and goldens alongside the cutover; remove retired-workflow tests then, retaining all domain safety coverage. The old shell is now unreachable. Update DESIGN.md's interaction/layout rules and library links in this phase. |
| **5. Clean-up** | Delete unreachable old shell, task pane, address bar, desks, saved views, Journal, Properties/form dialogs and remaining tests specific to deleted components. A Drift migration drops only desk, desk-tile and saved-view tables; migration and schema checks pass. Remove obsolete DESIGN.md references. Verify the final 1280 × 800 layout against the corrected mockup and the scaling matrix; only cleanup-induced visual changes require new golden updates. |

Each phase gets its own implementation plan in `docs/superpowers/plans/`.

## 8. Data Safety

- Domain tables, repositories, services, calculations, history and outcomes
  are unchanged. Saves go through the existing commands.
- The only schema change is a forward-only migration in phase 5 that drops
  the desk, desk-tile and saved-view tables, with a test that a database
  from before the migration opens and keeps every Work record.

## 9. Errors

Keep every existing `MutationOutcome` distinct in the adapter and UI:

| Outcome | Required behavior |
|---|---|
| `Committed` | Replace the baseline with the returned saved object, clear only the submitted draft, refresh dependent totals/history, then complete pending navigation or close. |
| `Invalid` | Keep the draft; mark the affected field/child or show a record-level error in the description pane and status bar. Select the failing field. Undo/Discard remains available. |
| `Stale` | Stop saving and retain the draft for inspection. Offer **Reload record**, warning that reloading discards pending values, or **Keep editing** to retain them without submitting. Reload refreshes the baseline and revision. There is no force-overwrite or automatic "Keep mine and save"; changes must be re-entered against current facts and pass normal guards. |
| `Missing` | Explain that the target no longer exists. Preserve pending values for inspection and offer **Discard and return to sheet**. Never recreate the record automatically. |
| `Unavailable` | Keep pending values, show the existing safe failure message, and permit an explicit retry through validation and guards. Do not claim a successful save. |
| `Uncertain` | Say that the save may have succeeded. Retain the submitted values and original identity, freeze mutations, and offer **Reload and check**. Do not auto-retry, show an ordinary Retry button, navigate away or quit through the normal guard while unresolved. Read the existing object, replacement links and history to establish the result. If read-back cannot establish it, keep the result explicitly unresolved; no new idempotency guarantee or service behavior is invented. |

An action-panel failure stays inline on the failing item. Bulk results
retain committed identities and outcomes, so retries cannot resubmit known
successes. A partial success is reported as such; cancelling does not undo
already committed days. An agreement whose confirmed repricing impact
changed uses the existing fresh-preview/reconfirmation flow; other stale
revisions follow Reload record above. A stale/uncertain notice never replaces
the edit session and loses its pending values.

## 10. Testing

- TDD per widget and per edit-session rule.
- Widget tests for each library widget; synthetic and real-font goldens for
  each state.
- Integration tests drive the real app with a desktop mouse, as the era
  date-box tests do.
- Save-matrix tests distinguish planned-day exceptions from manual/draft
  finalization, assert no write before consent, and prove that parent and
  child changes save or revert together. Test new-row defaults, dirty-row
  filtering, double Save and repeated navigation during a delayed command.
- Exercise every `MutationOutcome`, including uncertain create/correction
  read-back, changed repricing impact, and mixed committed/failed/uncertain
  bulk results. Assert that no automatic retry duplicates a write.
- Test native close and File › Quit with a clean session, valid and invalid
  edits, new rows, entered action-panel input, an in-flight command and each
  failed outcome; cancelling must leave the window and draft intact.
- Run retained-workflow tests from an empty database and from existing
  active/ended employments, missing agreements and stored records. Verify
  all section 4.9 destinations, old-link normalization and route restoration.
- Test Enter/Tab at the last editable field and inside each date/time
  editor, Esc rollback, mouse-only calendars/menus and absence of command
  shortcuts. The test oracle is section 4.6, not the old picker bindings.
- Layout matrix: 1280 × 800, 1024 × 768, 960 × 760, 860 × 600 and 800 × 600
  at both 100 % and 200 % text, plus either side of fold breakpoints. Include
  long validation text, many employments, a new record and an action panel.
  Assert no clipped editors or unreachable footer keys, no framework
  overflow, and working mouse scroll/splitter access. The HTML reference
  illustrates 1280 × 800 at 100 %; it is not proof of responsive behavior.
- The trailing-frame workaround (`lib/app/trailing_frame.dart`, for the
  owner's KDE Plasma Wayland + NVIDIA desktop) keeps wrapping the new shell,
  with a test.
- Synthetic data only in tests, goldens and screenshots.

## 11. Reference Content

The mockup's sample data, reused by goldens and the gallery:

- Employment "Synthetic depot", agreement from 2026-10-01, EUR 18.40 an hour
  gross, night premium 50 % for 22:00 to 06:00.
- Schedule "3 days / 3 nights": Day 07:00 to 19:00 and Night 19:00 to 07:00,
  each with a 30-minute unpaid break; paid 11:30, EUR 211.60 (day) and
  EUR 280.60 (night, 7:30 at night).
- The night of 24 to 25 October 2026 runs 13 hours (clocks go back): paid
  12:30, night 8:30, EUR 308.20.
- The unconfirmed planned day 2026-10-07 is edited from End 19:00 to 19:45:
  paid 12:15, planned-pay preview EUR 225.40. The existing planner excludes
  overtime from planned-pay previews; confirmed pay is calculated by the
  existing confirmation service and may differ. Saving this edit stores a
  day exception, not a finalized shift or history of a shift that does not
  yet exist.
- 2026-10-12 vacation replaces a night shift.

The corrected HTML and PNG use only domain-backed fields. Overtime is a
derived fact on ordinary scheduled/manual shifts; **Counts as overtime**
belongs only to the existing Add extra shift flow where the domain supports
it, including later edits of that extra-day exception. Breaks expose
start/end dates and times plus derived duration, not a
Paid toggle or a per-break Note. A changed planned work day has no note
field in the existing command; notes are offered only on supported objects.
No synthetic pending edit is shown as a committed History event. Fixture
totals and stored facts must come from the existing domain when implemented
in Flutter; the HTML is a layout reference, not a replacement pay engine.

## 12. Out of Scope

- Finance, Tracking and Knowledge content (their tabs stay "Not built yet").
- Changes to pay rules, schedules or other domain behaviour.
- A dark mode, second palette or appearance setting (DESIGN.md rule
  unchanged).
