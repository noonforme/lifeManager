# LifeOS XP-Authentic Shell Design

Date: 2026-10-04
Status: approved 2026-10-04. Amended 2026-10-04 during the build: the owner
kept the system window frame (section 5 withdrawn).
Amends: `2026-10-02-lifeos-millennium-shell-design.md`. This document
replaces its decisions on window frame, font and icons (section 2), the shell
layout (section 4), the property sheet (5.5), the **+ Desk** tab (5.7) and the
type table (3.4). Everything else in that spec stays in force.

## 1. Purpose

The Millennium shell has the era's parts but a modern web app's arrangement:
a docked right-hand inspector, stacked web forms with labels above
full-width fields, a GNOME title bar around the window, a modern sans serif,
thin overlay scrollbars and letter avatars. It reads as a theme laid over a
2020s app.

This project rearranges the shell the way an office program from around
2001 was built: the task pane follows the selection, records open in
Properties dialogs, forms are dialog boxes, and the window, type, scrollbars
and icons are the era's own. Records, calculations, routes and outcomes
behave as today except where section 9 lists a change.

## 2. Decisions

| Topic | Decision |
|---|---|
| Right-hand inspector | Removed. The selection's summary and its Working go to the task pane's **Details** group; records open in a **Properties** dialog; forms open as dialog boxes. |
| Working | In **Details**, whenever a figure is selected. |
| Task pane | Its top group follows the selection (Work tasks, Shift tasks, Period tasks, Payslip tasks). |
| Window frame | The system title bar stays. LifeOS draws nothing outside its client area (unchanged from the Millennium spec; a painted frame was built and withdrawn at the owner's request). |
| Font | Wine's Tahoma clone (LGPL-2.1-or-later), 11 px. Noto Sans stays only as a glyph fallback. Archivo and Azeret Mono are removed. |
| Icons | A painted, vendor-free 16 px and 32 px set for areas, record kinds and task links. The W/F/T/K letter squares go. |
| Scrollbars | One era scrollbar for every scroll area. |
| Address bar | A path combo (`Work\Synthetic depot\Shifts`) with a location tree drop-down. No › crumbs. |
| Delivery | One spec, built in three slices on `feat/era-pickers`, each ending with refreshed goldens and passing tests (section 11). |

## 3. Shell Layout (1280 × 800)

Top to bottom:

1. **Menu bar** (24 px): File, Edit, View, Desk, Record, Window, Help. The
   bold "LifeOS" label is removed; the system title bar names the app.
2. **Toolbar** (38 px): unchanged keys, drawn as bands, each with a dotted
   gripper at its left edge and an etched line between bands.
3. **Address bar** (26 px): the path combo and **Go** (section 6.3).
4. **Body**: **task pane** (200 px, left) and **content** (the rest). There
   is no third column.
5. **Status bar** (22 px): sunken panels.

### 3.1 Width behaviour

- 1024 px and wider: task pane and content.
- Below 1024 px: the **Tasks** toolbar key opens the task pane over the
  content, closed by Escape or a choice.
- The 300 px property sheet, the alternating layout below 1280 px and
  **Back to list** are removed.
- Dialogs size to their content, at most 90 % of the window, and scroll
  inside with the era scrollbar. Every layout holds at 200 % text.

## 4. Records: Task Pane, Details and Dialogs

### 4.1 Selection-aware task group

The first, special group of the task pane names the selection, as Explorer's
"File and Folder Tasks" did. Each link has a 16 px icon (section 7).

| Selection | Group | Links |
|---|---|---|
| None, or a Today/Journal row | Work tasks | Add a shift, New pay period, Record payslip, Save this view… |
| Draft shift with an end | Shift tasks | Finalize this shift, Properties |
| Finalized shift | Shift tasks | Correct this shift…, Properties |
| Pay period | Period tasks | Mark this period reviewed (or Reopen this period), Record payslip…, Properties |
| Effective payslip | Payslip tasks | Correct this payslip…, Properties |
| Employment, agreement | Employment tasks / Agreement tasks | Properties, plus the actions those records offer today |

Links run the same actions as today's inspector keys. A link whose action
is unavailable for the record is left out, not shown greyed. Desk surfaces
keep **Desk tasks**.

### 4.2 Details group

Under Books, **Details** shows, in this order of precedence:

1. **A figure is selected**: Working. The cell reference in bold, then the
   calculation wrapped to the group's width, operands as links that open
   their source, and the source link. This is today's `WorkingGroupBox`
   content, restyled for the task pane (Body type, link blue on the group
   body). Back still returns from an operand.
2. **A row is selected**: the record's name in bold, its kind ("Shift",
   "Pay period", …) and three to five key facts as label/value lines.
3. **Nothing is selected**: today's scope summary.

The group is a live region; a screen reader hears the new heading when the
selection changes.

### 4.3 Properties dialog

- **Opens from**: the Properties task link, Enter or a double-click on a
  row, Alt+Enter, and **Properties** at the foot of the row's right-click
  menu. One at a time; modal; Escape closes it.
- **Caption**: "{record name} Properties", for example
  "Shift 2026-09-08 Properties".
- **Tabs**: **General | History**, in the existing property-sheet tab style.
- **General**, laid out like the era's file-properties sheet:
  - a 32 px record-kind icon beside the record name;
  - an etched separator;
  - blocks of "Label:" / value rows (label column left, values left-aligned
    after it, figures in tabular type), each block separated by an etched
    line; the blocks are today's fact groups (Shift, Expected pay, Payslip
    details, Period), and a pay period adds its reconciliation groups as
    further blocks;
  - notes in Small type under their block;
  - action keys beside the block they act on, for example **Correct…**
    beside the shift facts, **Mark reviewed** and **Record payslip…**
    beside the period facts.
- **History**: today's history panel, unchanged in content.
- **Footer**: **OK** (Default) and **Cancel**, bottom-right. There is no
  Apply because nothing on the sheet is edited in place. An action key
  closes the sheet and opens its own dialog.

### 4.4 Forms as dialog boxes

Every create, edit, finalize and correct form opens as a modal `EraDialog`:
Record Work, Manual Shift, Finalize Shift, New Pay Period, Record Payslip,
Correct {record}, Employment and Pay Agreement. The dialog caption is the
form's current title.

- The primary key keeps today's verb ("Save manual shift", "Mark reviewed"),
  is the Default key, and is joined by **Cancel**.
- **Committed**: the dialog closes, the list shows the record selected, and
  the status bar's first panel confirms it ("Shift saved.").
- **Invalid** or **stale**: the dialog stays open with today's messages on
  the fields; nothing typed is lost.
- **Pay Agreement** is a tabbed dialog: **Rate | Overtime | Night |
  Holidays | When several apply**. The tab holding the first invalid field
  is brought forward on save.

### 4.5 Message boxes

Outcomes the inspector showed as panels (missing, unavailable, uncertain,
a rejected lifecycle action, finalizing unavailable) become a message box:
an `EraDialog` with a painted ⓘ (blue disc) or ⚠ (amber triangle), the same
wording, and **OK**. A stale lifecycle action offers **Reload** and
**Cancel**.

## 5. Window Frame

Withdrawn. The system window frame and title bar stay; LifeOS paints
nothing outside its client area.

## 6. Type, Scrollbars, Address Bar, Menus

### 6.1 Type

- Bundle Wine's Tahoma clone, regular and bold, under `assets/fonts/tahoma/`
  with its licence file, registered as family `EraSans` and added to
  `LicenseRegistry`.
- `fontFamilyFallback: ['NotoSans']` covers any glyph the clone lacks.
- Archivo and Azeret Mono are removed from `pubspec.yaml` and `assets/`.
- The plan verifies that the clone's digits share one advance width. If
  they do not, the Figure style keeps tabular figures through Noto Sans.

| Style | Size / line | Weight | Use |
|---|---|---|---|
| Caption | 13 / 16 | 700 | Dialog caption |
| Body | 11 / 14 | 400 | Controls, rows, menus, facts, labels |
| Strong | 11 / 14 | 700 | Record name, group-task titles, Details heading |
| Label | 11 / 14 | 400 | Column headers, group-box legends (Head blue) |
| Small | 11 / 14 | 400, muted | Notes, hints |
| Figure | 11 / 14 | 400, tabular | Dates, times, durations, money |
| Counter | 18 / 20 | 700, tabular | Counter tiles |

The 14 px Title style is retired.

### 6.2 Scrollbars

`EraScrollbar`, applied through the app's `ScrollBehavior` so every
scrollable gets it:

- 17 px wide (or tall); a pale track; arrow keys at both ends with painted
  dark-blue arrows; a rounded blue gradient thumb with three grip lines.
- Visible whenever the content overflows; absent otherwise.
- Clicking the track pages; an arrow key steps one row (20 px); holding it
  repeats.
- Flutter's thin overlay scrollbar is not used anywhere.

### 6.3 Address bar

- "Address", then a white combo field: a 16 px icon of the current area and
  the location as a path, `Work\Synthetic depot\Shifts`; **Today** and
  **Journal** show their single name.
- Its drop arrow opens the location tree: Today, Journal, then each area
  with its levels indented below it; the current location is selected.
  Choosing an entry navigates; Escape closes.
- **Go** reloads the location, as today.

### 6.4 Menus and the licence page

- The bold "LifeOS" label leaves the menu bar.
- **Help › About LifeOS** stays. Its **Licenses** key opens an era dialog
  listing each package and font with its licence text in a read-only white
  box, instead of Flutter's Material licence page.

## 7. Icons

`lib/shared/workbench/era_icons.dart`: painted icons at 16 px and 32 px,
each a `CustomPainter` with a dark outline, a two-stop gradient fill and a
highlight, drawn in the era's manner. No vendor artwork or font glyphs.

| Group | Icons |
|---|---|
| App | App glyph (About) |
| Areas | Work (briefcase), Finance (coins), Tracking (chart), Knowledge (book) |
| Record kinds | Shift (clock), Pay period (calendar page), Payslip (lined slip), Employment (building), Agreement (sealed document) |
| Tasks | Add (page with green plus), Properties (page with lines), Correct (pencil), Mark reviewed (green tick), Record payslip, Save view, New desk |
| States | ⓘ blue disc, ⚠ amber triangle (existing painters moved here) |

Area icons replace the letter keycaps in Books, the Journal's Area column
(icon plus the area word) and tile captions. Every icon sits beside a word
or carries a semantics label, never meaning alone.

## 8. Forms, Lists, Desks

### 8.1 Dialog forms

- Group boxes: 1 px etched outline, 3 px radius, legend in Head blue.
- Inside: a left column of "Label:" captions with colons and one fixed
  column width per dialog, fields after them.
- Field widths by kind:

  | Field | Width |
  |---|---|
  | Date | 120 px |
  | Time | 72 px |
  | Money | 88 px |
  | Multiplier, hours | 48 px |
  | Text | 200 px |
  | Note | full width of its group |

- Sentence fields read as one line: "After [8] hours per shift, pay [1.5] ×".
  A unit or × is a label after the field, never inside it.
- Check boxes and radios: 13 px, 4 px from their label; the whole row is the
  click target so the 24 × 24 minimum holds.
- Spacing: 12 px dialog padding, 7 px between rows, 4 px between a label
  and its field.
- Keys: at least 75 × 23 px, bottom-right, 6 px apart.
- Validation messages stay where they are today.

### 8.2 Details list

- The sorted column shows its ▴ / ▾ arrow and a faint grey tint (`#f7f7f7`)
  down its cells. The amber bottom edge appears on a header only while it
  is hovered.
- A selected row is selection blue while the list has focus and face grey
  with ink text while it does not.
- The "Add a manual shift" entry row is removed; Add a shift stays in the
  task pane and the toolbar.
- The period ‹ › keys become one matched pair of keys with painted arrows,
  labelled "Previous period" and "Next period", both greyed together when
  unavailable.

### 8.3 Desks and Books

- The **+ Desk** tab is removed; **New desk…** stays in Desk tasks and the
  **Desk ▾** menu.
- Tile captions use the area icons; tiles are otherwise unchanged.
- An unbuilt area is one muted row: its icon greyed and
  "Finance (not built yet)".
- Roadmap sentences shown to the owner ("archiving arrives in a later
  update") are removed; an unavailable action is simply absent.

## 9. Behaviour Changes

Only these change; everything else behaves as today.

1. The right-hand inspector and **Back to list** are gone; records open in
   Properties dialogs and forms in dialog boxes.
2. The task pane's first group follows the selection.
3. Working shows in Details.
5. The address bar is a path combo with a location tree.
6. The "Add a manual shift" entry row and the **+ Desk** tab are removed.
7. Licences open in an era dialog.

## 10. Testing

- Existing behaviour tests keep their assertions; finders move from the
  inspector to the dialogs.
- New widget tests:
  - Properties opens from Enter, double-click, Alt+Enter, the right-click
    menu and the task link; Escape and Cancel close it.
  - The task group's title and links follow the selection, and unavailable
    actions are absent.
  - Details shows Working for a selected figure and the record summary for
    a selected row; operand links navigate and Back returns.
  - A form dialog stays open on invalid and stale outcomes with input kept,
    and closes on commit with the status message.
  - Each former inspector failure shows its message box.
  - The address drop-down lists the tree and navigates.
  - Every scroll area builds an `EraScrollbar`.
  - A selected row turns grey when the list loses focus.
- The glyph test keeps failing on any font glyph used as an icon.
- Token contrast test adds: scrollbar arrow on its key, ink on the
  unfocused selection.
- Goldens at 1280 × 800 and 960 × 760: register; row selected with Details;
  figure selected with Working; Properties dialog; Manual Shift dialog; Pay
  Agreement dialog; calendar open inside a dialog; Today desk. The
  real-font renders under `test/goldens/real_font/` are regenerated and
  checked by eye before merge.
- Semantics test: every region and dialog keeps its label at
  both sizes.
- `./app.sh` start, tests and checks still pass.

## 11. Delivery Slices

1. **Records**: section 3 layout, section 4, the message boxes, and the
   tests and goldens they touch.
2. **Type**: sections 6.1, 6.2, and the icons of section 7.
3. **Era sweep and forms**: sections 6.3, 6.4, 8, the remaining goldens,
   and the documentation of section 12.

## 12. Documentation

- `DESIGN.md` is rewritten for the shipped result: layout without the
  property-sheet column, the dialog patterns, EraSans and the type table,
  scrollbars, icons. No shadows anywhere; the system window frame stays.
- The Millennium shell spec gets a note at its top pointing to this
  document for the replaced sections.
- The Work surface brief in `.impeccable/surfaces/` is rewritten to the
  Millennium world (it still describes Office Machine).
- `README.md` screenshots are updated if any show the old layout.

## 13. Out of Scope

- Rethinking the Today desk's tiles.
- Finance, Tracking and Knowledge.
- Sounds, wallpaper, a start menu or a taskbar.
- Any second style, dark mode or high contrast.
