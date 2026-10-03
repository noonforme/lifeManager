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
  pane-top: "#7ba2e7"
  pane-bottom: "#6375d6"
  pane-body: "#d6dff7"
  link: "#1c50b0"
  signal: "#d9500b"
  run-ink: "#b83d0b"
  negative: "#cc0000"
  positive: "#2a752d"
  progress: "#2fbf2f"
  close: "#c1300f"
  area-work: "#3a6ea5"
  area-finance: "#d9a400"
  area-tracking: "#3f7a2e"
  area-knowledge: "#7b5ea7"
typography:
  title:
    fontFamily: "Noto Sans"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: "18px"
  label:
    fontFamily: "Noto Sans"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: "14px"
  body:
    fontFamily: "Noto Sans"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: "16px"
  small:
    fontFamily: "Noto Sans"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: "14px"
  figure:
    fontFamily: "Noto Sans"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: "16px"
    fontFeature: "tabular-nums"
  counter:
    fontFamily: "Noto Sans"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: "22px"
    fontFeature: "tabular-nums"
rounded:
  key: "3px"
  task-group-top: "5px"
  tile-top: "5px"
  group-box: "3px"
  pane: "0px"
spacing:
  1: "2px"
  2: "4px"
  3: "8px"
  4: "12px"
components:
  push-button:
    background: "white-to-face gradient"
    border: "1px {colors.key-line}"
    rounded: "{rounded.key}"
    height: "24px min"
    default: "inner double ring #6c9cec / #b9d1fa"
    hover: "inner warm ring #f9b119 / #ffe7a2"
    pressed: "gradient inverted"
  toolbar-key:
    background: "flat; raised face on hover, focus or press"
    height: "30px min"
  combo:
    background: "{colors.paper}"
    border: "1px {colors.field-line}"
    arrow: "blue gradient button with a painted drop arrow"
  group-box:
    border: "1px #d0d0bf"
    legend: "{typography.label} in {colors.head}"
  property-sheet-tab:
    active: "{colors.page} with a 2px {colors.tab-accent} top edge"
    inactive: "white-to-face gradient"
  details-list-row:
    height: "20px"
    selected: "{colors.selection} with {colors.selection-ink}"
    cursor: "1px dotted rectangle"
---

# Design System: LifeOS

## Overview

**Creative North Star: "The 2001 Office PC"**

LifeOS looks and behaves like a friendly, glossy office PC from around 2001, shaped like that era's file browser. Every design choice mimics that era: bevelled toolbars, glossy orbs, a blue task pane of rounded groups, details lists with bevelled column headers, property sheets with tabs and group boxes, push buttons with a dark blue outline, and a sunken status bar. It is the only style; there is no second palette, dark mode or appearance setting.

The shipped shell, at 1280 × 800:

- **Menu bar** (24 px): LifeOS, File, Edit, View, Desk, Record, Window, Help.
- **Toolbar** (38 px): Back and Forward with green orbs, **Add** with an orange orb and a drop arrow, then "From last time:" and up to four flat keys.
- **Address bar** (26 px): the location as crumbs in a read-only field, and **Go**.
- **Task pane** (200 px, left): the surface's tasks (Work tasks, Desk tasks), Books, and Details.
- **Content** (centre): a filter toolbar row of era dropdowns over a sunken details list, or a desk of tile windows.
- **Property sheet** (300 px, right): **General | History** for the open record, with the **Working** group box on top when a calculated cell is selected. Surfaces with nothing to inspect leave it out.
- **Status bar** (22 px): sunken panels for counts and the save state; the first, stretching panel is empty until there is something to confirm.

Below 1280 px the property sheet alternates with the content (**Back to list**). Below 1024 px the task pane folds into a **Tasks** toolbar key that opens it over the content. Every layout holds at 200 % text.

This record is derived from the built Flutter shell (`lib/shared/shell`, `lib/shared/workbench`), its goldens in `test/goldens/`, and the spec `docs/superpowers/specs/2026-10-02-lifeos-millennium-shell-design.md`.

**Key characteristics:**
- Face-coloured chrome, white lists and pages, blue heads and selection.
- Bevels, vertical gradients and inner rings are the only depth. No drop shadows.
- Noto Sans for everything, tabular figures for every date, time, duration and amount.
- Every derived number explains itself in the Working group box, and every record has a History.

## Colors

Widgets take colours from `LifeOSTokens.millennium` and the named constants in `MillenniumColors` (`lib/shared/workbench/millennium_style.dart`), never from literals. Text pairs meet 4.5:1; indicators, key outlines and focus meet 3:1 (`test/shared/workbench/lifeos_tokens_test.dart`).

- **Face** `#ece9d8`: menu bar, toolbars, the property-sheet region, forms and the status bar.
- **Paper** `#ffffff` and **Page** `#fcfcfe`: lists, fields, tile bodies; the property-sheet page.
- **Ink** `#000000` and **Muted** `#555555`.
- **Head** `#0046d5`: caption bars, group-box legends, group rows and the special task-group header.
- **Selection** `#316ac5` with white ink: the selected row.
- **Field line** `#7f9db9` and **Key line** `#003c74`: field and list borders; push-button outlines.
- **Task pane:** gradient `#7ba2e7` → `#6375d6`, group bodies `#d6dff7`, links `#1c50b0`.
- **Accents:** tab top edge `#ffc83c`, sorted-column edge `#f9b119`.
- **Signal** `#d9500b` and **Run ink** `#b83d0b`: progress indicators and an active live value in Books.
- **Negative** `#cc0000` and **Positive** `#2a752d`, always beside the words "under" and "over".
- **Area keys:** Work `#3a6ea5`, Finance `#d9a400`, Tracking `#3f7a2e`, Knowledge `#7b5ea7`, each with its letter.

Two era colours stay below 3:1 by choice: the field outline, because fields are also told apart by their white fill and label, and the sorted-column amber, because the sort order is also painted as an arrow and announced as "sorted ascending".

### Named rules

**The Words-First Rule.** Draft, Void, Open, Reviewed, over and under are always written. Colour only supports the word.

**The No-Vendor Rule.** No vendor names, logos, icons, wallpapers or sounds. Orbs, arrows, ticks and glyphs are painted.

## Typography

- **Noto Sans** (OFL), bundled, for all text. Arrows, chevrons and ticks are painted because the font has none of them.

| Style | Size / line | Weight | Use |
|---|---|---|---|
| Title | 14 / 18 | 700 | Property-sheet record title |
| Label | 11 / 14 | 400 | Column headers, group-box legends |
| Body | 12 / 16 | 400 | Controls, rows, menus, facts |
| Small | 11 / 14 | 400 | Notes, hints |
| Figure | 12 / 16 | 400, tabular | Dates, times, durations, money |
| Counter | 20 / 22 | 700, tabular | Counter tiles |

Labels are not uppercased.

## Layout

- Spacing steps of 2, 4, 8 and 12 px; task-pane padding 12; property-sheet page padding 8.
- Heights: toolbar keys 30, push buttons 24, list rows 20, task links and menu rows 24, desk tabs 24 (active 26). Every target is at least 24 × 24 except list rows, whose hit area spans the row's full width and which the keyboard reaches row by row.

## Elevation & depth

Depth comes from the era's bevels: vertical gradients on toolbars, keys, tabs, column headers and caption bars; sunken status panels (dark top-left edge, white bottom-right edge); and the inner rings of default and hovered keys. There are no drop shadows or blur. Motion is immediate.

## Components

- **Push button** (`KeyButton`, Material buttons through the theme): white-to-face gradient, key-line outline, 3 px radius. The default key has a blue inner double ring; hover adds a warm inner ring; pressing inverts the gradient. Disabled is face with muted ink.
- **Toolbar key** (`KeyKind.toolbar`): flat until hovered, focused or pressed. **Orbs** (`Orb`) are painted glossy circles: green for Back and Forward, orange for Add, grey when unavailable.
- **Address bar** (`AddressBar`): crumbs, each a link to its level, in a read-only field; **Go** reopens the location.
- **Task pane** (`TaskPane`, `TaskGroup`, `TaskLink`, `TaskDetails`): rounded groups with a collapse key; the first, special group has a solid blue header. Books lists Today, Journal, Views and each area with its keycap and live values; the selected row is bold ink.
- **Filter row and combos** (`EraComboFace`): "View:", "Employment:", "Period:", "Status:" beside white fields with a blue drop-arrow button.
- **Date and time boxes** (`EraDateField`, `EraTimeField`, `EraMonthCalendar`): a date shows as `Mon 2026-10-05` beside the blue drop arrow, which opens a Monday-first month calendar: the month on a Head-blue band between ◂ and ▸, today circled in red, the chosen day filled with selection blue, and a **Today:** link. A time shows `07:00` beside stacked ▴▾ spin arrows; the selected part fills with selection blue, and seconds appear only for times that have them. Both are picked, never typed. An optional date has a check box inside its box; clear means none.
- **Details list** (`DataRegister`): bevelled headers with a sorted-column edge and arrow, blue group rows over a pale rule, 20 px rows, solid blue selection and a dotted cell cursor (white on a selected row).
- **Property sheet** (`RecordTabs`, `inspector_parts.dart`): General | History tabs (`PropertySheetTabs`), a title, facts in group boxes (`GroupBox`), notes, and right-aligned keys (`FormFooter`). The **Working** group box (`WorkingGroupBox`) shows the selected cell's calculation with operand links.
- **Forms:** group boxes on the face colour holding labelled white fields (`EraField` for text, `EraDateField`/`EraTimeField` for dates and times: the label above the field, never on its border), radios and check boxes for choices, and their actions right-aligned with the primary one as the default key.
- **Desks:** desk tabs plus a **+ Desk** tab, and tiles drawn as small windows with a blue caption bar (`CaptionBar`), keycap, drop-arrow menu and red close key.
- **Dialogs** (`EraDialog`): blue caption with a red close key, face-coloured body, keys bottom-right.
- **Information panel** (`OperationalState`): a painted ⓘ in a blue disc or ! in an amber triangle, a bold title and the message.
- **Status bar** (`StatusLine`): sunken panels.

### Focus and selection

Keyboard focus is a 1 px dotted rectangle inside the control (`DottedFocusRectangle`); text fields show it as a key-line blue border and the caret. Selection is a solid blue fill. They never look the same.

## Do's and Don'ts

### Do:
- **Do** choose the era-authentic control: property sheets, group boxes, task panes, details lists, radios and check boxes.
- **Do** put every figure in a list and give every derived figure an explanation in Working.
- **Do** take colours only from tokens and `MillenniumColors`.
- **Do** keep keys labelled, targets at least 24 × 24, and focus distinct from selection.
- **Do** paint glyphs the bundled font lacks; a test fails if `lib/` uses one.
- **Do** use synthetic data in tests, goldens and screenshots.

### Don't:
- **Don't** add a second palette, dark mode or an appearance setting.
- **Don't** add KPI cards, dashboards or a scaled-up tablet layout.
- **Don't** use vendor names, logos, icons, wallpapers or sounds.
- **Don't** add drop shadows or blur; depth is bevels only.
- **Don't** signal state by colour alone.
