---
name: LifeOS
description: Private, local-first desktop records for one person, shaped as a 2001 office PC.
colors:
  face: "#ece9d8"
  paper: "#ffffff"
  page: "#fcfcfe"
  ink: "#000000"
  muted: "#555555"
  rule: "#ecebe5"
  band: "#f1efe2"
  chrome-line: "#c5c2b2"
  head: "#0046d5"
  head-ink: "#ffffff"
  selection: "#316ac5"
  selection-ink: "#ffffff"
  field-line: "#7f9db9"
  key-line: "#003c74"
  tab-accent: "#ffc83c"
  sort-accent: "#f9b119"
  sort-tint: "#f7f7f7"
  pane-top: "#7ba2e7"
  pane-bottom: "#6375d6"
  pane-body: "#d6dff7"
  link: "#1c50b0"
  choice-line: "#1c5180"
  choice-mark: "#21a121"
  scroll-track: "#f4f3ee"
  scroll-face-top: "#cadaff"
  scroll-face-bottom: "#b5c9f7"
  scroll-face-edge: "#98b0e8"
  signal: "#d9500b"
  run-ink: "#b83d0b"
  negative: "#cc0000"
  positive: "#2a752d"
  progress: "#2fbf2f"
  close: "#c1300f"
typography:
  caption:
    fontFamily: "EraSans"
    fontSize: "13px"
    fontWeight: 700
    lineHeight: "16px"
  body:
    fontFamily: "EraSans"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: "14px"
  strong:
    fontFamily: "EraSans"
    fontSize: "11px"
    fontWeight: 700
    lineHeight: "14px"
  label:
    fontFamily: "EraSans"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: "14px"
  small:
    fontFamily: "EraSans"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: "14px"
  figure:
    fontFamily: "EraSans"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: "14px"
    fontFeature: "tabular-nums"
  counter:
    fontFamily: "EraSans"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: "20px"
    fontFeature: "tabular-nums"
rounded:
  key: "3px"
  task-group-top: "5px"
  dialog-top: "6px"
  group-box: "3px"
spacing:
  1: "2px"
  2: "4px"
  3: "7px"
  4: "12px"
components:
  push-button:
    background: "white-to-face gradient"
    border: "1px {colors.key-line}"
    rounded: "{rounded.key}"
    size: "75 × 24 px min"
    default: "inner double ring #6c9cec / #b9d1fa"
    hover: "inner warm ring #f9b119 / #ffe7a2"
  toolbar-key:
    background: "flat; raised face on hover, focus or press"
    height: "30px min"
  properties-dialog:
    caption: "{typography.caption} on a Head-blue gradient, red close key"
    tabs: "General | History"
    footer: "OK (default) and Cancel"
  dialog-form:
    rows: "'Label:' column, then a field at its kind width"
    footer: "primary verb (default) and Cancel"
  check-box:
    size: "13px, {colors.choice-line} outline, {colors.choice-mark} tick"
  radio:
    size: "13px circle, green dot"
  scrollbar:
    width: "17px"
    parts: "arrow keys, pale track, blue thumb with grip lines"
  address-combo:
    path: "Work\\Synthetic depot\\Shifts"
    drop-down: "every location, indented"
  details-list-row:
    height: "20px"
    selected: "{colors.selection} while focused, {colors.face} otherwise"
    cursor: "1px dotted rectangle"
---

# Design System: LifeOS

## Overview

**Creative North Star: "The 2001 Office PC"**

LifeOS looks and behaves like a friendly, glossy office program from around 2001, shaped like that era's file browser. Every choice mimics the era, in the arrangement as well as the paint: the task pane follows the selection, records open in Properties dialogs, forms are dialog boxes, and type, scrollbars and icons are the era's own. It is the only style; there is no second palette, dark mode or appearance setting. The system window frame and title bar stay; LifeOS paints nothing outside its client area.

The shipped shell, at 1280 × 800:

- **Menu bar** (24 px): File, Edit, View, Desk, Record, Window, Help. No app label and no roadmap items.
- **Toolbar** (38 px): bands, each starting with a dotted gripper and split by etched lines: Back and Forward with green orbs; **Add** with an orange orb and a drop arrow; "From last time:" and up to four flat keys.
- **Address bar** (26 px): a combo box showing the location as a path (`Work\Synthetic depot\Shifts`) with the area's icon; its drop-down lists every location; **Go**.
- **Task pane** (200 px, left): the selection's task group, Books, and Details.
- **Content**: a filter row of era dropdowns over a sunken details list, or a desk of tile windows.
- **Status bar** (22 px): sunken panels; the first says what was just done ("Shift saved.").
- **Dialogs** over everything when the route opens one: a Properties sheet, a form or a message box.

There is no right-hand column. Below 1024 px the task pane folds into a **Tasks** toolbar key that opens it over the content. Every layout holds at 200 % text.

This record is derived from the built Flutter shell (`lib/shared/shell`, `lib/shared/workbench`), its goldens in `test/goldens/`, and the specs `docs/superpowers/specs/2026-10-02-lifeos-millennium-shell-design.md` and `docs/superpowers/specs/2026-10-04-lifeos-xp-authentic-shell-design.md`.

**Key characteristics:**
- Face-coloured chrome, white lists and pages, blue heads and selection.
- Bevels, vertical gradients and inner rings are the only depth. No shadows or blur.
- EraSans at 11 px for everything; tabular figures for every date, time, duration and amount.
- Select a row to see it in Details; open it to see its Properties. Every derived number explains itself in Working, and every record has a History.

## Colors

Widgets take colours from `LifeOSTokens.millennium` and the named constants in `MillenniumColors` (`lib/shared/workbench/millennium_style.dart`), never from literals. The one exception is icon artwork: the painted icons in `era_icons.dart` keep their colours beside their shapes. Text pairs meet 4.5:1; indicators, key outlines and focus meet 3:1 (`test/shared/workbench/lifeos_tokens_test.dart`).

- **Face** `#ece9d8`: menu bar, toolbars, dialogs, forms, the status bar, and a selected row while its list has no focus.
- **Paper** `#ffffff` and **Page** `#fcfcfe`: lists, fields, tile bodies; the Properties page.
- **Ink** `#000000` and **Muted** `#555555`.
- **Head** `#0046d5`: caption bars, group-box legends, group rows and the special task-group header.
- **Selection** `#316ac5` with white ink: the selected row while its list has focus.
- **Field line** `#7f9db9` and **Key line** `#003c74`: field and list borders; push-button outlines.
- **Task pane:** gradient `#7ba2e7` → `#6375d6`, group bodies `#d6dff7`, links `#1c50b0`.
- **Lists:** sorted-column tint `#f7f7f7`; the amber `#f9b119` edge marks a header only while it is hovered.
- **Choices:** check-box and radio outline `#1c5180`, tick and dot `#21a121`.
- **Menus:** panel edge `#aca899`.
- **Scrollbars:** track `#f4f3ee`, face `#cadaff` → `#b5c9f7`, edge `#98b0e8`.
- **Signal** `#d9500b` and **Run ink** `#b83d0b`; **Negative** `#cc0000` and **Positive** `#2a752d`, always beside the words "under" and "over".

### Named rules

**The Words-First Rule.** Draft, Void, Open, Reviewed, over and under are always written. Colour only supports the word; an icon always sits beside a word or carries a label.

**The No-Vendor Rule.** No vendor names, logos, icons, wallpapers or sounds. Orbs, arrows, ticks, icons and glyphs are painted.

## Typography

- **EraSans** — Wine's Tahoma-metric font (LGPL-2.1-or-later, `assets/fonts/era_sans/`, licence in Help › About › Licenses) — for all text, at the era's 8 pt (11 px). Its digits share one advance width. **Noto Sans** is bundled as the fallback for any glyph EraSans lacks.

| Style | Size / line | Weight | Use |
|---|---|---|---|
| Caption | 13 / 16 | 700 | Dialog captions |
| Body | 11 / 14 | 400 | Controls, rows, menus, facts, labels |
| Strong | 11 / 14 | 700 | Record names, task-group titles |
| Label | 11 / 14 | 400 | Column headers, group-box legends |
| Small | 11 / 14 | 400 | Notes, hints |
| Figure | 11 / 14 | 400, tabular | Dates, times, durations, money |
| Counter | 18 / 20 | 700, tabular | Counter tiles |

Labels are not uppercased.

## Layout

- Spacing steps of 2, 4, 7 and 12 px; task-pane padding 12; dialog padding 8.
- Heights: toolbar keys 30, push buttons 24, list rows 20, task links and menu rows 24, desk tabs 24 (active 26). Push buttons are at least 75 px wide. Every target is at least 24 × 24 except list rows, whose hit area spans the row's full width.
- Field widths by kind: date 120 (140 with its check box), time 72 (grows to fit), money 88, short numbers 48, text 200, notes the full row.

## Elevation & depth

Depth comes from the era's bevels: vertical gradients on toolbars, keys, tabs, column headers and caption bars; sunken status panels; etched lines between toolbar bands and Properties blocks; and the inner rings of default and hovered keys. There are no shadows or blur. Motion is immediate.

## Components

- **Push button** (`KeyButton`): white-to-face gradient, key-line outline, 3 px radius, at least 75 × 24. The default key has a blue inner double ring; hover adds a warm ring; pressing inverts the gradient.
- **Toolbar key** (`KeyKind.toolbar`): flat until hovered, focused or pressed. **Orbs** are painted glossy circles. **Step keys** (`StepKey`) are small keys with painted ◂ ▸ arrows, each grey when its direction has nothing.
- **Task pane** (`TaskPane`, `TaskGroup`, `TaskLink`): rounded groups with a collapse key. The first, special group follows the selection — **Work tasks** with nothing selected, **Shift / Period / Payslip / Employment / Agreement tasks** for a selected row. Each link has a 16 px painted icon; a link whose action is unavailable is left out, not greyed.
- **Details** (`WorkingDetails`, `RecordSummary`): Working for a selected derived figure (the calculation with operand links); otherwise the selected record's name, kind and facts above the scope's totals; otherwise the scope's totals.
- **Shell dialog** (`ShellDialog`, `ShellDialogLayer`): an in-window modal over the whole shell; the window behind keeps its look but takes no input. Open state lives in the route (`mode=properties|create|edit|correct`, `add=`), so Back and Forward close and reopen it. Escape and the caption's red key close it; focus returns to where it was. Dragging the blue caption moves it, as it does an `EraDialog` (`EraMovableDialog`); a dialog stays inside the window. Message boxes and one-key steps fit their content; forms keep a fixed size and scroll.
- **Properties sheet**: caption "{record} Properties", **General | History** tabs (an agreement: **Rate | Premiums | Leave | Notes | History**), and **OK / Cancel / Apply**. Fields are edited in place where the record allows it (an employment, an agreement no finished shift uses, a draft shift) and shown greyed where it does not (a finalized shift, a pay period, a payslip, an agreement in use, which says why). Apply greys until a field changes; OK saves and closes, a refused save keeps the sheet open on the problem; Cancel and Escape discard. Enter is OK unless a key inside has focus. Actions such as Mark reviewed, Finalize shift and Correct… sit on General. There are no separate Edit dialogs; an old edit link opens the record's sheet (`PropertySheetController`, `EraFormScope(enabled: false)`).
- **Dialog forms** (`EraFormScope`, `EraLabelled`, `EraField`, `EraDateField`, `EraTimeField`): group boxes of `Label:` rows with fields at their kind width (the label moves above its field when the row is too narrow); sentence fields read on one line ("After [8] hours per shift, pay [1.5] ×"); the primary verb key plus **Cancel** (`DialogCancelKey`), both era push buttons, pinned bottom-right of the dialog however short the form (`DialogForm`); the affirmative key always comes first. The Pay agreement is tabbed: Rate | Premiums | Leave | Notes.
- **Check boxes and radios** (`EraCheckBox`, `EraRadio`, `EraRadioGroup`): 13 px, 4 px from their label; the whole row is the target. A radio group is one Tab stop; the arrow keys move the choice.
- **Details list** (`DataRegister`): bevelled headers with a sort arrow; the sorted column tinted; amber edge on the hovered header; blue group rows; 20 px rows; blue selection while focused, face grey while not; a dotted cell cursor. Click selects; Enter, Alt+Enter, a double-click (400 ms) or right-click › Properties opens the record.
- **Menus** (`EraContextMenu`, `eraMenuStyle`, `eraMenuItemStyle`): right-click and menu-bar drop-downs share one look. A white panel sized to its rows, a 1 px menu edge and 2 px inset; row text after an 18 px gutter; selection blue with white text under the pointer or the keyboard; the default command (the one a double-click runs) bold; disabled rows muted and inert. A right-click menu opens at once with its corner at the pointer. Down lights its first row; Esc or a click outside closes it, and focus goes back to the list.
- **Date and time boxes** (`EraDateField`, `EraTimeField`): a click outside an open calendar closes it and leaves focus on what was clicked. In a time box, Left and Right stop at its first and last part; only the main button selects a part or spins; a spin arrow looks pressed while held.
- **Work calendar** (`WorkCalendar`, `WorkCalendarSheet`): a Monday-first month in the details-list style; bevelled weekday heads, white cells, out-of-month days on the face colour. Each day shows its date and up to two written entries ("Day 07:00–19:00", "Cancelled · Swapped", "Vacation", "Needs review"), then "+N more"; a swatch beside the words is outlined while planned and filled once confirmed. Today has the amber outline; the selected day the selection fill and dotted focus rectangle. Arrow keys move, Enter or a double-click opens the day, Page Up/Down change month. Above it ‹ [Month ▾] [Year ▾] › [Today]; below it the month's shifts, paid time, planned and confirmed pay.
- **Day Properties** (`DaySheet`): "{weekday} {d} {Month} {yyyy}"; the planned shift's facts with **Confirm** (today or earlier), **Change…**, **Cancel shift…**, **Mark as leave…**, or an Off day's **Add extra shift…**. Change… and Add extra shift… edit the times in place; OK and Apply save them. Cancel shift… and Mark as leave… are small era dialogs of radios. A confirmed day opens its shift's or leave's own Properties instead.
- **Confirm worked days**: every past unconfirmed day, ticked, with date, what, times, paid time and pay; the footer totals the ticked days. Each day is its own transaction; a day that fails keeps its row and says why.
- **Schedule Properties** (`ScheduleEditor`): **Schedule | Cycle | Preview | History**. The cycle is a list of blocks — grip, count, ×, type or Off, the type's times — reordered by dragging the grip or Alt+↑/↓. Shift types… opens the Shift types dialog (Add… / Edit… / Remove; a type the cycle uses stays). Saving a version a confirmed day uses asks "Use the new cycle from:" and starts a new version.
- **Scrollbars** (`EraScrollbar`, `EraScrollBehavior`): 17 px, arrow keys at both ends, a pale track and a blue thumb with grip lines; shown only when content overflows; one-line text fields have none.
- **Icons** (`EraIcon`): painted at 16 and 32 px — areas (Work briefcase, Finance coins, Tracking chart, Knowledge book), record kinds, tasks and an app glyph; greyed for unbuilt areas.
- **Address bar** (`AddressBar`): the path combo and **Go**.
- **Desks**: desk tabs (desks only), tiles drawn as small windows with a blue caption bar, area icon, drop-arrow menu and red close key. New desks come from Desk tasks or the Desk menu.
- **Books**: Today, Journal, Views and each area with its icon and live values; an unbuilt area or sheet is one muted row, "Finance (not built yet)".
- **Message box**: a dialog with the painted ⚠ sign, the message and **OK**.
- **Licences** (`LicensesDialog`): every package and font with its licence in a read-only white box.
- **Status bar** (`StatusLine`, `StatusNoticeScope`): sunken panels; the first shows the last notice until the owner leaves that area.

### Focus and selection

Keyboard focus is a 1 px dotted rectangle inside the control; text fields show it as a key-line blue border and the caret. Selection is a solid blue fill while its list has focus. They never look the same.

## Do's and Don'ts

### Do:
- **Do** arrange the way the era did: selection in the task pane and Details, records in Properties dialogs, forms as dialog boxes.
- **Do** choose the era-authentic control: property sheets, group boxes, task panes, details lists, radios and check boxes.
- **Do** put every figure in a list and give every derived figure an explanation in Working.
- **Do** take colours only from tokens and `MillenniumColors` (icon artwork excepted).
- **Do** keep keys labelled, targets at least 24 × 24, and focus distinct from selection.
- **Do** paint glyphs and icons; a test fails if `lib/` uses a font glyph as one.
- **Do** use synthetic data in tests, goldens and screenshots.

### Don't:
- **Don't** add a docked inspector column or a second palette, dark mode or appearance setting.
- **Don't** paint a window frame; the system one stays.
- **Don't** add KPI cards, dashboards or a scaled-up tablet layout.
- **Don't** use vendor names, logos, icons, wallpapers or sounds.
- **Don't** add drop shadows or blur; depth is bevels only.
- **Don't** signal state by colour alone, or show roadmap sentences ("arrives in a later update").
