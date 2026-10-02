---
name: LifeOS
description: Private, local-first desktop records for one person, shaped as an office machine.
colors:
  ground: "#cfd1cc"
  paper: "#f4f5f2"
  ink: "#1d1d1b"
  muted: "#60635e"
  rule: "#dcded9"
  band: "#ebede8"
  chrome: "#e2e4df"
  chrome-line: "#a9aca5"
  head: "#2b2c2a"
  head-ink: "#f4f5f2"
  signal: "#e8590c"
  action-fill: "#c2410c"
  action-ink: "#ffffff"
  run-ink: "#b03a0a"
  sel-wash: "#fde3d2"
  sel-ink: "#1d1d1b"
  negative: "#b8261b"
  positive: "#2a6f2d"
  focus: "#1d1d1b"
  area-work: "#3a6ea5"
  area-finance: "#d9a400"
  area-tracking: "#3f7a2e"
  area-knowledge: "#7b5ea7"
typography:
  title:
    fontFamily: "Archivo"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: "20px"
  label:
    fontFamily: "Archivo"
    fontSize: "10.5px"
    fontWeight: 700
    lineHeight: "14px"
    letterSpacing: "0.08em"
    textTransform: "uppercase"
  body:
    fontFamily: "Archivo"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: "18px"
  small:
    fontFamily: "Archivo"
    fontSize: "11.5px"
    fontWeight: 400
    lineHeight: "16px"
  figure:
    fontFamily: "Azeret Mono"
    fontSize: "12.5px"
    fontWeight: 400
    lineHeight: "18px"
    fontFeature: "tabular-nums"
  counter:
    fontFamily: "Azeret Mono"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: "22px"
    fontFeature: "tabular-nums"
rounded:
  key: "4px"
  field: "2px"
  pane: "0px"
spacing:
  1: "4px"
  2: "8px"
  3: "12px"
  4: "16px"
components:
  key-primary:
    backgroundColor: "{colors.action-fill}"
    textColor: "{colors.action-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.key}"
    height: "30px"
    edge: "2px bottom, darker shade of the fill"
  key-secondary:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    border: "1px {colors.muted}"
    rounded: "{rounded.key}"
    height: "30px"
  field:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    border: "1px {colors.muted}, 2px {colors.focus} when focused"
    rounded: "{rounded.field}"
  register-row:
    backgroundColor: "{colors.paper}"
    height: "25px"
    selected: "{colors.sel-wash} with {colors.sel-ink} text"
---

# Design System: LifeOS

## Overview

**Creative North Star: "The Office Machine"**

LifeOS is a calculating machine for one person's records. Every figure sits in a register and can show its working in the formula bar; nothing is a detached KPI card. The shell is a grey casing around paper-white registers, with black keys for headers and the status line, one signal orange for the thing to press and anything running, and one coloured keycap per area.

The shipped shell, at 1280 × 800:

- **Menu bar** (28 px): File, Edit, View, Desk, Record, Window, Help.
- **Toolbar** (44 px): Back, Forward, the orange **+ Add**, up to four "from last time" keys, and the current location.
- **Formula bar** (34 px): the selected cell's calculation, with operand links.
- **Book tree** (228 px, left): Today, Journal, Views, each area with its sheets and live values, and Backup and export at the foot.
- **Desk** (centre): a Work register with its sheets, or a desk of tiles at `/today`.
- **Inspector** (320 px, right): Details and History tabs for the open record. Surfaces with nothing to inspect, such as Today and the Journal, leave it out.
- **Status line** (24 px): the running shift and the save state.

Below 1280 px the inspector alternates with the desk (**Back to desk**). Below 1024 px the tree folds into a **Books** key. Nothing is lost at any width, and every layout holds at 200 % text.

This record is derived from the built Flutter shell (`lib/shared/shell`, `lib/shared/workbench`) and its goldens in `test/goldens/`.

**Key Characteristics:**
- Grey casing, paper registers, black heads; flat, square panes.
- One orange for action and running state; colour supports words and never replaces them.
- Archivo for words, Azeret Mono with tabular figures for every date, time, duration and amount.
- Keys with a 2-pixel pressable edge are the only depth.
- Every derived number explains itself in the formula bar, and every record has a History.

## Colors

The palette is a set of named tokens (`LifeOSTokens`); widgets take every colour from tokens and never use a literal. Each palette passes a contrast test: text pairs at 4.5:1, indicators and outlines at 3:1.

### Neutrals
- **Ground** `#cfd1cc`: the casing behind panes and tiles.
- **Paper** `#f4f5f2`: registers, tiles, inspector and tree.
- **Ink** `#1d1d1b` and **Muted** `#60635e`: text and secondary text.
- **Rule** `#dcded9`: row and cell separators. **Band** `#ebede8`: column headers.
- **Chrome** `#e2e4df` with **Chrome line** `#a9aca5`: menu bar, toolbar and pane dividers.
- **Head** `#2b2c2a` with **Head ink**: tile headers, group rows, the active segment and the status line.

### Signal
- **Signal** `#e8590c`: the running dot and the selected-cell outline.
- **Action fill** `#c2410c` with white ink: the primary key.
- **Run ink** `#b03a0a`: "Running" text.
- **Selection wash** `#fde3d2` with **Selection ink**: the selected row. A selected row draws every cell in selection ink.

### Meaning
- **Negative** `#b8261b` and **Positive** `#2a6f2d`: short-paid and over amounts, always beside the words "under" and "over".
- **Area keys:** Work `#3a6ea5`, Finance `#d9a400`, Tracking `#3f7a2e`, Knowledge `#7b5ea7`, each with a letter (W, F, T, K) at 4.5:1.

### Named Rules
**The One-Orange Rule.** Orange means "press this" or "this is running". It is never decoration.

**The Words-First Rule.** Draft, Void, Running, over and under are always written. Colour only supports the word.

## Typography

- **Interface:** Archivo (OFL), bundled.
- **Figures:** Azeret Mono (OFL), bundled, with tabular figures.

### Hierarchy
- **Title** (600, 16/20): the inspector record title.
- **Label** (700, 10.5/14, +0.08em, uppercase): column headers, section labels and the tree header.
- **Body** (500, 13/18): controls, entries and menus.
- **Small** (400, 11.5/16): secondary lines and hints.
- **Figure** (400/600, 12.5/18, tabular): dates, times, durations, money and counts.
- **Counter** (700, 20/22): counter tiles.

### Named Rules
**The Figures-Line-Up Rule.** Anything a person might compare down a column is set in Figure and right-aligned.

## Layout

- **Spacing:** a 4-pixel base, using steps of 4, 6, 8, 10, 12, 14 and 16.
- **Heights:** toolbar keys 30, small keys 26, register rows 25, tree rows 23–25, desk tabs 26, popup menu rows 32. Every target is at least 24 × 24.
- **Register v2:** group rows in Head (for example a pay period or "October 2026"), data rows on Paper with Rule separators, and an entry row at the foot ("Add a manual shift"). Optional columns (Break, Night, Holiday) hide first when space runs short.
- **Desks:** single, two columns, or main and side (one main tile, up to three stacked). Each tile has a Head header with its area key, name, menu (Replace, Open full size, Remove) and close key. The starter desks are Today, Weekly review and Month close; Today cannot be deleted.

## Elevation & Depth

There are no shadows, blur or glow in Office Machine. Hierarchy comes from Ground versus Paper, 1-pixel Chrome lines, and Head bands. The only depth is the key edge: a 2-pixel bottom edge in a darker shade, which a pressed key loses as its face moves down 1 pixel. Neighbouring controls never move.

Motion is immediate, or a 120 ms cross-fade. With reduced motion it is zero. Nothing pulses.

### Named Rules
**The Flat-Casing Rule.** Regions are told apart by tone and lines, never by elevation.

## Shapes

- **Keys,** chips, tabs and tiles: 4-pixel radius.
- **Fields:** 2-pixel radius.
- **Registers,** panes and the tree: square.
- **Keyboard focus:** a 2-pixel ring offset by 2, always distinct from selection. A selected cell has a 2-pixel Signal outline.

## Components

### Keys (`KeyButton`)
- **Primary:** Action fill with white bold text.
- **Secondary:** Paper with a Muted outline.
- **Small:** 26 high.
- **Disabled:** Chrome with Muted text, and no edge.
- **Shared rules:** the label is always shown. Material buttons in forms are painted with the same key surfaces through the skin-derived theme.

### Segmented tabs
Sheet tabs, inspector tabs and desk tabs. The active segment is Head with Head ink, inactive segments are Paper, and all share a Muted outline.

### Book tree
- **Rows:** area rows on Band with their keycap, and sheet rows indented with a right-aligned live value. Unbuilt areas say "Not built yet".
- **Selection:** the selected row is Selection wash with Selection ink.
- **Right-click:** offers Open, plus each node's own actions (for a saved view: Add to a desk, Rename view…, Delete view).

### Formula bar
`ƒx`, then the reference, the calculation with operand links, and the source. It is empty when nothing is selected; it never shows placeholder text.

### Inspector
Details and History tabs. Facts are label/value pairs with figures right-aligned. History lists created, changed, finalized, voided, replaced and reviewed events, newest first.

### Status line
A Head strip showing "● Shift running since 07:02" (the start on the shift's own clock), then counts, then "Local database" or "Last save uncertain. Reload to check".

### Forms, dialogs and menus
These use Material widgets themed from the active skin. Fields are Paper with a Muted outline and a 2-pixel focus outline. Dialogs and menus are Paper with a Muted outline and no elevation. Menu rows are 32 high.

## Appearances

The shell paints through a `LifeOSSkin`, which supplies tokens, typography and painters. Layout, regions, menus, copy and behaviour are identical in every appearance; a test checks that every semantics node keeps its label and position. Choose an appearance under **View › Appearance**. The choice is kept in the database and restored at start.

- **Office Machine Day** (default), **Night** (charcoal with glowing orange) and **High contrast**. **System** follows the platform's brightness and high-contrast setting.
- **Millennium:** a glossy 2001-era office PC.
  - **Palette:** `#ece9d8` face, `#0046d5` heads and `#316ac5` selection.
  - **Type:** Noto Sans (OFL).
  - **Painting:** gradient keys with a dark-blue outline, glossy area keys, property-sheet tabs with a warm top edge, a dotted focus rectangle, a task-pane tree and a face-coloured status line.
  - **Rules:** it has no night palette. The system high-contrast setting replaces it with Office Machine high contrast. It uses no vendor names, logos, icons, wallpapers or sounds.

## Do's and Don'ts

### Do:
- **Do** put every figure in a register and give every derived figure an explanation.
- **Do** take colours only from tokens and painting only from the skin's painters.
- **Do** keep keys labelled, targets at least 24 × 24, and focus distinct from selection.
- **Do** keep routes, view filters and tile references structural: ids, dates, states and flags only.
- **Do** use synthetic data in tests, goldens and screenshots.

### Don't:
- **Don't** add KPI cards, dashboards or a scaled-up tablet layout.
- **Don't** add shadows, blur, glow or gradients to Office Machine; gradients belong to Millennium chrome only, never to data rows.
- **Don't** let a skin move, resize or re-word a control.
- **Don't** signal state by colour alone.
