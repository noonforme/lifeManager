# LifeOS Millennium Shell Design

Date: 2026-10-02
Status: approved in conversation, awaiting written-spec review
Amended by: `2026-10-04-lifeos-xp-authentic-shell-design.md` (font, icons,
layout, property sheet, desk tabs; the system window frame stays).
Supersedes: the visual system and shell layout of
`2026-10-01-lifeos-office-machine-shell-design.md` (sections 4 and 5, and
the presentation parts of 6). Its behaviour, data and routing decisions stay
in force unless this document changes them.

## 1. Purpose

LifeOS gets one look: a friendly, glossy office PC from around 2001, shaped
like that era's file browser. The Office Machine appearance and the
appearance setting are removed. The Millennium skin, until now an optional
appearance, becomes the only style and the design goal for every surface.

This is a presentation project. Records, calculations, routes, copy and the
Work workflow behave as they do today, except
where section 8 lists a change. Custom rotating work schedules are a
separate project with its own spec.

## 2. Decisions

| Topic | Decision |
|---|---|
| Direction | "File explorer" (mockup A): toolbar with orb keys, Address bar, blue task pane on the left, details list in the middle, property sheet on the right, sunken status bar. |
| Appearances | One style. Office Machine Day, Night, High contrast, the System option and View › Appearance are removed. |
| High contrast and dark mode | None. One light palette whatever the platform asks for. The palette itself meets 4.5:1 for text and 3:1 for indicators. |
| Window frame | The system title bar stays. LifeOS draws nothing outside its client area. |
| Formula bar | Removed as a row. The calculation appears as a **Working** group box at the top of the property sheet. |
| Sheets | The segmented sheet tabs become a **View:** dropdown. |
| Filters | The chip-style filter keys become era dropdowns in a filter toolbar row. |
| Font | Noto Sans (OFL, already bundled) for everything; tabular figures for numbers. No Tahoma. |
| Icons | No vendor icons, logos, wallpapers, sounds or names. Toolbar orbs and status glyphs are painted. Task-pane links are text only. |
| Style layer | Collapse the skin system to one style behind the existing scope API (section 3). |

## 3. Style Layer

### 3.1 Removed

- `OfficeMachineSkin`, the `LifeOSSkin` interface and skin resolution.
- The Office palettes in `LifeOSTokens` (`day`, `night`, `highContrast`) and
  their area-key sets, except the area-key colours Millennium already uses.
- The `LifeOSAppearance` enum, `LifeOSAppearanceScope`, the Appearance
  submenu, and appearance restore and save in `lifeos_app.dart`.
- `PreferenceKey.appearance` and the preference repository wiring, since no
  other preference exists. The `preferences` table stays in the schema; no
  migration runs and the stored row is simply never read.
- `buildLifeOSTheme(highContrast:)` becomes `buildLifeOSTheme()`.

### 3.2 Kept

- `LifeOSSkinScope.of(context)` keeps returning `LifeOSSkinData` with
  `tokens`, `typography` and `painters`, so widgets keep one way to read the
  style. The scope always provides the single style; it takes no
  appearance. Tests keep wrapping widgets in `LifeOSSkinScope`.
- `SkinPainters` becomes one concrete class (the Millennium painters, moved
  out of `skins/`), extended with the painters section 5 needs.
- `lifeos_theme.dart` keeps theming Material widgets from the tokens, with
  the key edge and title size fixed in the inspector work.

### 3.3 Palette

The Millennium tokens are the palette. Named colours used beyond the token
set (task-pane gradient, link blue, tab amber, key outline, progress green)
become named constants on the style, not literals in widgets.

| Role | Value |
|---|---|
| Face (ground, chrome) | `#ece9d8` |
| Paper (lists, fields, pages) | `#ffffff`; property-sheet page `#fcfcfe` |
| Ink / muted | `#000000` / `#555555` |
| Rule / band / chrome line | `#ecebe5` / `#f1efe2` / `#c5c2b2` |
| Head (caption, group row ink) | `#0046d5` |
| Selection | `#316ac5` with white ink |
| Field and list border | `#7f9db9` |
| Key outline | `#003c74` |
| Tab and sorted-column accent | `#ffc83c` / `#f9b119` |
| Task pane | gradient `#7ba2e7` → `#6375d6`; group body `#d6dff7`; links `#1c50b0` |
| Signal / running ink | `#d9500b` / `#b83d0b` |
| Negative / positive | `#cc0000` / `#2a752d` |
| Progress | `#2fbf2f` |

### 3.4 Type

| Style | Size / line | Weight | Use |
|---|---|---|---|
| Title | 14 / 18 | 700 | Property-sheet record title, dialog captions |
| Label | 11 / 14 | 400 | Column headers, group-box legends (in Head blue) |
| Body | 12 / 16 | 400 | Controls, rows, menus, facts |
| Small | 11 / 14 | 400 | Notes, hints |
| Figure | 12 / 16 | 400, tabular | Dates, times, durations, money |
| Counter | 20 / 22 | 700, tabular | Counter tiles |

Labels are no longer uppercased. Every size scales with the platform text
scale and every layout holds at 200 %.

## 4. Shell Layout (1280 × 800)

Top to bottom:

1. **Menu bar** (24 px): LifeOS, File, Edit, View, Desk, Record, Window,
   Help. Menus are white with a blue highlighted item. View has no Appearance submenu.
2. **Toolbar** (38 px): **Back** and **Forward** keys with green orbs (grey
   when unavailable), a separator, **Add ▾** with an orange orb (opens quick
   add), a separator, then "From last time:" and up to four flat keys.
   Flat keys show a raised face only on hover, focus or press.
3. **Address bar** (26 px): the word "Address", a read-only white field with
   the location as crumbs (`Work › Synthetic depot › Shifts`), and a **Go**
   key that reloads the current location. Each crumb is a link to its level.
4. **Body:**
   - **Task pane** (200 px, left).
   - **Content** (flexible, centre): a filter toolbar row, then the sunken
     details list or the desk.
   - **Property sheet** (300 px, right) when a record is open. Surfaces with
     nothing to inspect (Today, Journal) leave it out.
5. **Status bar** (22 px): sunken panels: running shift ("● Shift running
   since 07:02"), counts, and "Local database" or "Last save uncertain.
   Reload to check".

### 4.1 Width behaviour

- At 1280 px and wider, all three body columns show.
- Below 1280 px the property sheet alternates with the content. A **Back to
  list** key at the top of the sheet returns.
- Below 1024 px the task pane folds into a **Tasks** toolbar key that opens
  it as an overlay over the content, closed by Escape or a choice.
- Nothing is lost at any width; every layout holds at 200 % text.

## 5. Components

### 5.1 Keys

- **Push button** (forms, dialogs, property sheet): 24 px min height, 3 px
  radius, Key outline, white-to-face vertical gradient. **Default** button
  adds an inner blue double ring. Hover adds an amber inner edge; pressed
  inverts the gradient. Disabled is face with muted ink and a grey outline.
- **Toolbar key**: flat until hovered, focused or pressed; then a raised
  face with chrome-line outline. Optional painted orb on the left.
- **Orbs**: 20 px painted circles with a radial highlight: green (Back,
  Forward), orange (Add), grey (unavailable).
- Every key keeps a visible label and a 24 × 24 minimum target. Material
  buttons in forms are painted the same way through the theme.

### 5.2 Task pane

- Blue gradient background with 12 px padding.
- **Groups** with a 5 px rounded top: a header strip (white-to-pale-blue
  gradient, Head-blue bold title) and a pale body. The first group is
  **special**: a solid blue header with white title.
- Each header has a round collapse key (︽ / ︾). Collapsed state is kept per
  group for the session.
- **{Area} tasks** (special): the current surface's actions as links:
  Work: Add a shift, New pay period, Record payslip, Save this view….
  Desk: New desk, Rename desk…, Reset desk, Delete desk (adding a sheet
  and changing the layout stay in the desk's **Desk ▾** menu, which needs
  a choice list). Journal has no tasks group. Links run the same actions
  as today's keys.
- **Books**: today's book tree inside the group: Today, Journal, Views, each
  area with its keycap, sheets indented with right-aligned live values,
  unbuilt areas "Not built yet". Selection is a bold, non-link row.
  Right-click menus are unchanged.
- **Details**: a short summary of the current scope (for Work: employment,
  current period and state, shift count and estimated total).
- Backup and export leaves the pane; it stays under File.

### 5.3 Filter toolbar row and dropdowns

- One row above the list: **View:** (sheets), then the surface's filters
  (Work: Employment, Period with ‹ › keys, Status).
- **Dropdown**: white field with field border and a blue gradient arrow
  button on the right; its menu is the shared menu style.
- Save view moves to the task pane as "Save this view…".

### 5.4 Details list (register)

- Sunken white list with field border.
- **Column headers**: white-to-band gradient, 1 px separators; the sorted
  column has a 3 px amber bottom edge and ▾ / ▴.
- **Group rows**: Head-blue bold text with a pale blue rule under it (no
  filled band).
- **Rows**: 20 px, Body type, figures right-aligned in Figure.
- **Selected row**: solid selection blue, white ink. The selected cell has a
  1 px dotted white rectangle (focus is never shown by colour alone).
- **Entry row** at the foot, muted italic ("Add a manual shift…").

### 5.5 Property sheet (inspector)

- Tabs **General | History** in property-sheet style: inactive tabs a
  white-to-face gradient, the active tab joined to the page with a 2 px
  amber top edge.
- Page `#fcfcfe` with a grey border and 8 px padding.
- **Title** line (Title type), then **group boxes**: 1 px light outline,
  3 px radius, legend in Head blue.
- **Working** group box first whenever a derived value is selected: the
  reference, the calculation with operand links, and the source link (the
  content of today's formula bar, wrapped onto several lines).
- **Facts** inside group boxes are label/value rows; values right-aligned,
  figures in Figure. Notes in Small.
- **Actions** at the foot as push buttons, the primary one as Default.
- Forms (create, edit, correct) use the same page: group boxes of sunken
  white fields with labels above. Each form keeps the actions it has
  today, right-aligned in a footer, its primary action as Default.
- **History** tab: one entry per event, newest first: event word in bold,
  time in Figure right-aligned, changes in Small.

### 5.6 Fields and choice controls

- Text fields: white, 1 px field border, 2 px inner padding; keyboard focus
  turns the border Key-outline blue and shows the caret.
- Checkboxes: 13 px white box with field border, green tick. Radios: 13 px
  circle, green dot. Segmented choices (Gross / Net) become radios.

### 5.7 Desks

- Desk tabs in property-sheet style above the tiles, plus a **+ Desk** tab.
- **Tiles**: small windows with a 22 px blue gradient caption (area keycap,
  title, ▾ menu key, red close key) over a white body with a light blue
  border. Layouts (single, two columns, main and side) are unchanged.
- Tile contents use the list, fact and counter styles; progress uses the
  green segmented bar.

### 5.8 Journal

A details list grouped by day with blue group rows. No property sheet.

### 5.9 Dialogs and menus

- In-app dialogs: blue gradient caption with the title and a red close key,
  face-coloured body, push buttons bottom-right. No shadow beyond a 1 px
  dark outline.
- Menus and popups: white, a 1 px grey outline, blue selected row with
  white text, 24 px rows, separators as etched lines. No icon gutter.

### 5.10 States

Empty, loading, unavailable, stale, conflict and uncertain states become an
information panel: a painted ⓘ (blue) or ⚠ (amber) glyph, a bold title and
the message, on the page colour. Wording is unchanged.

### 5.11 Status bar

Face background, each panel sunken (darker top-left, white bottom-right
edge). The running-shift panel shows a Signal dot and Running ink.

### 5.12 Focus and selection

Keyboard focus is a 1 px dotted rectangle inside the control (or around a
list cell). Selection is a solid blue fill. They never look the same.

## 6. Accessibility

- Every control keeps its semantics label, role and order; tests check the
  labels of the main regions and keys.
- Text pairs meet 4.5:1; indicators, key outlines and focus meet 3:1,
  checked by the token contrast test against the single palette (white on
  Head blue, white on selection blue, link blue on the task-pane body, ink
  on face). Two era colours stay below 3:1 by choice: the field outline
  (#7f9db9), because fields are also marked by their white fill and label,
  and the sorted-column amber, because the order is written as ▴ / ▾.
- Targets are at least 24 × 24 (list rows are 20 px high but the row's hit
  area spans the full width and the keyboard reaches every row).
- Layouts hold at 200 % text.
- Colour never carries meaning alone: Running, Draft, Void, over and under
  are always written.

## 7. Documentation

- `DESIGN.md` is rewritten for the Millennium style: north star "The 2001
  Office PC", palette, type, components and rules from this spec, including
  the no-vendor-assets rule.
- `PRODUCT.md`'s shell line points to this spec.
- `README.md` and any screenshots or goldens that show Office Machine are
  updated.
- `.impeccable/design.json` is regenerated from `DESIGN.md`.

## 8. Behaviour Changes

Only these change; everything else behaves as today.

1. View › Appearance and the saved appearance are gone.
2. The ƒx formula bar row is gone; its content is the Working group box.
3. Sheet tabs are the View dropdown; filter chips are dropdowns.
4. Save view, New pay period and Add shift move from content keys into the
   task pane's Work tasks (Add stays in the toolbar too).
5. Backup and export leaves the tree foot (it stays under File).
6. Below 1024 px the tree folds into a **Tasks** key instead of **Books**.
7. "Back to desk" is renamed "Back to list".

## 9. Testing

- All existing behaviour tests stay. Finders change only where a control
  changed type (sheet tab to dropdown item, chip to dropdown, formula bar to
  Working group box, Books key to Tasks key).
- Removed: skin, appearance-switching and appearance-persistence tests.
- Token contrast test runs against the single palette.
- Goldens (single style) at 1280 × 800 and 960 × 760: Work register,
  pay period open in the property sheet, a create form, Today desk. A
  real-font render of the same screens is checked by eye before merge.
- Semantics test: every region and key keeps its label at both sizes.
- `./app.sh` start, tests and checks still pass.

## 10. Out of Scope

- Custom rotating work schedules (`2026-10-02-work-schedules-design.md`).
  That spec removes the live tracker, so this project does not restyle the
  running and on-break inspectors, Start shift, or the running-shift status
  panel; they stay as they are until removed.
- A custom-drawn window title bar.
- Dark mode, high contrast, or any second palette.
- New areas (Finance, Tracking, Knowledge).
