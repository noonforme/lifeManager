# LifeOS Office Machine Shell Design

**Status:** Approved direction (owner choice, 2026-10-01), pending implementation plan review
**Date:** 2026-10-01
**Builds on:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md` and `docs/superpowers/specs/2026-10-01-work-employments-premiums-design.md`
**Supersedes:** section 15 (Native Workbench Design) of the foundation spec, and the visual direction recorded in `DESIGN.md`
**Phases:** 0 (Work in the new shell) and 1 (shell features). Phases 2–4 (Finance, Tracking, Knowledge) get their own specs.

## 1. Purpose

The owner reviewed the current Work screen and found it short on function and not tool-like enough. Three rounds of visual references settled a replacement:

1. **Structure:** a ledger. Registers with fixed columns, an entry row, and a formula bar that explains the selected value.
2. **Layout:** a merge of three studied layouts. A book tree for navigation, desks for arranging sheets, and a journal that lists every record by time.
3. **World:** Office Machine. Grey casing, black keys, signal orange for actions and running states, and one coloured keycap per area.

LifeOS grows from one shipped area (Work) to four: **Work, Finance, Tracking, Knowledge**. Money and Habits are renamed Finance and Tracking. Knowledge is new.

Phases 0 and 1 succeed when the owner can:

1. Do every existing Work task inside the new shell, with working employment, period and state controls.
2. Read a finalized shift's full facts and pay breakdown in the inspector.
3. Select any derived number and read its calculation in the formula bar.
4. See every change to a record in its History tab.
5. Move back and forward between sheets and records with toolbar buttons or mouse side buttons.
6. Add a record from anywhere with "+ Add", and start a common entry prefilled from the last one of its kind.
7. Open the Today, Weekly review and Month close desks, and arrange sheets on a desk.
8. Read the Journal for any day, filter it, and save a filter as a named view.
9. Keep navigation available at every window width.

## 2. Decisions

| Topic | Decision |
|---|---|
| Visual world | Office Machine (section 4). Day and night palettes and a high-contrast variant. Default follows the system; the owner can pin day or night |
| Appearances | One optional skin over the same shell: **Millennium** (inspired by the 2001 Windows XP desktop), chosen under View › Appearance. Structure and behaviour do not change between skins (section 4.7) |
| Fonts | Archivo for the interface, Azeret Mono for figures, both bundled as assets under the SIL Open Font License. No runtime font download |
| Navigation | Book tree on the left replaces the system rail. It is always reachable: at narrow widths it collapses to a **Books** button |
| Work area | Desks (tabs) hold one sheet full size or several tiles. Starter desks: Today, Weekly review, Month close |
| Journal | A derived, read-only union of records from every area, ordered by time. It has no table of its own |
| Inspector | A right pane with **Record** and **History** tabs |
| Formula bar | Global. It explains derived values and labels recorded facts as facts |
| History | A new append-only `record_events` table, written in the same transaction as every mutation |
| Desks and views | Stored in SQLite as structural configuration (sheet IDs, filters, columns). They never contain record content |
| Interaction | Mouse first. Every action is a labelled button in place, and right-click repeats the record's actions. Shortcuts appear in menus and tooltips |
| Unbuilt areas | Finance, Tracking and Knowledge appear in the tree as honest "Not built yet" nodes until their phase ships |

## 3. Scope

### 3.1 Included

- Office Machine theme: tokens, fonts, components and states
- Skin architecture, plus the Millennium appearance (section 4.7)
- Shell frame: menu bar, toolbar, formula bar, book tree, desk tabs, desk, inspector, status line
- Register v2: typed columns, group and subtotal rows, entry row, cell selection, row states, right-click menu
- Work moved into the shell, with the gaps listed in section 7.1 fixed
- Formula bar explanations for Work derived values
- Record history for Work records
- Back and forward navigation
- Quick add and "from last time" templates for Work entries
- Journal sheet, starter desks, desk arrangement
- Saved views

### 3.2 Excluded

- Finance, Tracking and Knowledge features (phases 2–4)
- Due rows and recurring entries (phase 2, though the Today desk keeps a "Needs you" tile for Work items now)
- Attachment store, receipts and media (phase 2 and 4)
- Agreement versions, archive and schedules (later phases of the premiums spec)
- Free-form tile resizing by dragging (tiles use fixed layouts in this phase; see 6.4)
- Tray balloons and other operating-system chrome (taskbar, desktop icons) for any skin

## 4. Visual System: Office Machine

### 4.1 Character

A machine built for one job: a 1970s office calculator rather than a website. A grey casing surrounds paper-white working surfaces, with black keys for headers and the status line. Orange marks the one thing to press and anything in motion (a running shift). Each area has a coloured keycap. Buttons have a pressable bottom edge.

Colour stays on chips, keys, states and indicators. Row fills never take area colours, and the palette never becomes decoration.

### 4.2 Colour tokens

Contrast ratios are against the surface each token sits on. Text pairs meet 4.5:1, and non-text indicators meet 3:1.

| Token | Role | Day | Night | High contrast |
|---|---|---|---|---|
| `ground` | Casing behind panes and tiles | `#cfd1cc` | `#161715` | `#bfc1bc` |
| `paper` | Registers, tiles, inspector, tree | `#f4f5f2` | `#242523` | `#ffffff` |
| `ink` | Primary text | `#1d1d1b` | `#ecebe6` | `#000000` |
| `muted` | Labels, secondary text | `#60635e` | `#a3a49e` | `#3d3f3b` |
| `rule` | Row and cell separators | `#dcded9` | `#383936` | `#7a7d77` |
| `band` | Alternate row band, column headers | `#ebede8` | `#2b2c29` | `#f0f1ee` |
| `chrome` | Menu bar, toolbar, tab strip | `#e2e4df` | `#1d1e1c` | `#e2e4df` |
| `chromeLine` | Pane and control borders | `#a9aca5` | `#454642` | `#3d3f3b` |
| `head` | Tile headers, status line, active segment | `#2b2c2a` | `#0f100e` | `#000000` |
| `headInk` | Text on `head` | `#f4f5f2` | `#ecebe6` | `#ffffff` |
| `signal` | Indicators: running dot, budget bars, selection outline | `#e8590c` | `#ff6a1a` | `#a83600` |
| `actionFill` | Primary button fill | `#c2410c` | `#ff6a1a` | `#a83600` |
| `actionInk` | Text on `actionFill` | `#ffffff` | `#161715` | `#ffffff` |
| `runInk` | Running-state text | `#c2410c` | `#ff6a1a` | `#a83600` |
| `selWash` | Selected row fill | `#fde3d2` | `#4a2b18` | `#ffd9c2` |
| `selInk` | Text on `selWash` | `#1d1d1b` | `#ecebe6` | `#000000` |
| `negative` | Over budget, short paid, negative amounts | `#c22a1e` | `#ff7d70` | `#a0150b` |
| `positive` | Under budget, positive amounts | `#2f7d32` | `#94d394` | `#1f5e22` |
| `focus` | Keyboard focus ring | `#1d1d1b` | `#ecebe6` | `#000000` |

Area keys (chip fill / chip text):

| Area | Day | Night |
|---|---|---|
| Work | `#3a6ea5` / `#ffffff` | `#6e9fd4` / `#161715` |
| Finance | `#d9a400` / `#1d1d1b` | `#e8b923` / `#161715` |
| Tracking | `#3f7a2e` / `#ffffff` | `#7cbf62` / `#161715` |
| Knowledge | `#7b5ea7` / `#ffffff` | `#a98bd2` / `#161715` |

`signal` (`#e8590c`) is too light for small white text, so filled buttons use `actionFill` (`#c2410c`, 5.2:1 with white). A unit test computes the contrast of every listed text pair and fails below the threshold.

### 4.3 Type

| Style | Face | Size / line | Weight | Use |
|---|---|---|---|---|
| Title | Archivo | 16 / 20 | 600 | Inspector record title |
| Label | Archivo | 10.5 / 14, +0.08em, uppercase | 700 | Column headers, section labels, tree header |
| Body | Archivo | 13 / 18 | 500 | Controls, entries, menus |
| Small | Archivo | 11.5 / 16 | 400 | Secondary lines, hints |
| Figure | Azeret Mono | 12.5 / 18, tabular | 400 / 600 | Dates, times, durations, money, counts |
| Counter | Azeret Mono | 20 / 22 | 700 | Counter tiles |

Sizes are logical pixels at 100% text scale. Every layout must work at 200%.

### 4.4 Shape, spacing, depth

- **Spacing:** 4-pixel base. Steps are 4, 6, 8, 10, 12, 14 and 16.
- **Radius:** 4 pixels for keys (buttons, chips, tabs, tiles). Registers, panes and the tree are square.
- **Key edge:** buttons carry a 2-pixel bottom border in a darker shade of their fill. When pressed they lose the edge and move down 1 pixel, which is the only depth in the system.
- **No shadows, blur, gradients or glow** in Office Machine. Section 4.7 lists the only exceptions, each limited to one optional skin.
- **Heights:** toolbar buttons 30, small buttons 26, register rows 25, tree rows 23, desk tabs 26 (29 when active). Every target is at least 24 × 24.

### 4.5 States

| State | Signal |
|---|---|
| Selected row | `selWash` fill |
| Selected cell | 2-pixel `signal` outline plus `selWash` |
| Keyboard focus | 2-pixel `focus` ring offset by 2, always distinct from selection |
| Running | `signal` dot plus `runInk` text "Running" with the elapsed time |
| Draft | "Draft" in the State column. The row is not struck or faded |
| Void | Struck text in `muted`. The replacement row sits directly above it |
| Over / under | A number plus the word "over" or "under". Colour supports the word and never replaces it |
| Needs you | An orange count badge on the tree node, desk tile or status segment |
| Not built yet | Tree node in `muted` with the words "Not built yet". Selecting it opens an honest unavailable sheet |

### 4.6 Motion

Panes and inspector content change immediately, or with a 120 ms cross-fade. With reduced motion the duration is zero. Nothing pulses, and the running dot is static.

### 4.7 Appearances

Every visible part of the shell is a LifeOS-owned widget, and each widget paints through a `LifeOSSkin`. A skin supplies three things:

- a token set (the same names as 4.2)
- typography
- painters for buttons, tabs, tile headers, the tree, the formula bar, progress bars, selection, focus, area markers and the status line

Layout, regions, width behaviour, menus, copy, states and data are identical in every skin. Changing appearance never moves a control, and it never changes what a control does.

Shipped skin names are Office Machine and Millennium. Millennium borrows the conventions of its era but uses no Microsoft names, logos, icons, wallpapers or system sounds.

#### Millennium (inspired by the 2001 Windows XP desktop)

A friendly, glossy office PC. It is the most visibly clickable skin.

| Token | Value | Notes |
|---|---|---|
| `ground` | `#ece9d8` | Window face behind tiles |
| `paper` | `#ffffff` | |
| `ink` | `#000000` | |
| `muted` | `#555555` | |
| `rule` | `#ecebe5` | |
| `band` | `#f1efe2` | Column headers, painted as a light vertical gradient |
| `chrome` | `#ece9d8` | Menu bar and toolbar (toolbar has a light gradient) |
| `chromeLine` | `#c5c2b2` | |
| `head` | `#0046d5` | Group-box titles and the first task-pane header |
| `headInk` | `#ffffff` | |
| `signal` | `#e8590c` | Running indicator |
| `actionFill` | `#ffffff` | Painted as a white-to-face gradient. The primary (default) button carries a blue inner ring |
| `actionInk` | `#000000` | |
| `runInk` | `#c2410c` | |
| `selWash` | `#316ac5` | Selection blue |
| `selInk` | `#ffffff` | |
| `negative` | `#cc0000` | |
| `positive` | `#2f7d32` | |
| `focus` | `#000000` | Dotted focus rectangle |
| extra: `link` | `#1c50b0` | Task-pane links (5.5:1 on the pane body) |
| extra: `paneTop` / `paneBottom` | `#7ba2e7` / `#6375d6` | Book-tree background gradient |
| extra: `paneBody` | `#d6dff7` | Task-pane group body |
| extra: `tabAccent` | `#ffc83c` | Top edge of the active desk tab |
| extra: `progress` | `#2fbf2f` | Block progress bars |

Painting rules:
- **Book tree:** a task pane with collapsible groups: Record tasks (the "from last time" templates as links), Books, and Details for the selected record.
- **Formula bar:** an address-bar field with a green **Go to source** button.
- **Desk tabs:** property-sheet tabs.
- **Tiles:** group boxes with blue titles.
- **Progress bars:** green block bars.
- **Status line:** sunken status panels.
- **Area markers:** glossy squares using the Office Machine day area keys.
- **Gradients:** permitted in this skin only, for chrome and controls, never on data rows.
- **Night palette:** none. Choosing Millennium follows its own palette regardless of system brightness.

Fonts: the interface needs a free, Tahoma-metric face. Choose one at implementation after a licence review; an LGPL-2.1 face may be bundled with its notice. If none passes, use Noto Sans (SIL OFL). Figures use the same face with tabular figures where available.

#### Contrast and accessibility per skin

- Every text pair in every skin meets 4.5:1, and every indicator 3:1.
- The high-contrast setting from the operating system wins over any skin: when it is on, LifeOS uses the Office Machine high-contrast tokens.
- The focus ring stays distinct from selection in every skin: an outline in Office Machine, a dotted rectangle in Millennium.

## 5. Shell Layout

### 5.1 Regions (1280 × 800)

| Region | Size | Content |
|---|---|---|
| Menu bar | 28 high | File, Edit, View, Desk, Record, Window, Help |
| Toolbar | 44 high | Back ‹, Forward ›, **+ Add**, "From last time" templates, search (disabled until a later phase), History toggle |
| Formula bar | 34 high | Cell reference, ƒx, explanation, source link |
| Book tree | 228 wide (200–320, resizable) | Areas and sheets with live values |
| Desk tabs | 32 high | Desk tabs and **+ Desk** |
| Desk | remaining | One sheet, or tiles |
| Inspector | 252 wide (252–400, resizable) | Record and History tabs |
| Status line | 24 high | Running shift, Needs-you count, save state |

### 5.2 Width behaviour

- **1280 and wider:** all regions visible.
- **1024–1279:** the inspector becomes a pane that replaces the desk when a record is opened, with **Back to desk**. The desk keeps its scroll, selection and drafts.
- **Below 1024:** the tree collapses to a **Books** toolbar button that opens it as a pane. Tiles show one at a time, with a tile switcher in the desk header.

Navigation is never removed at any width. The page body never scrolls horizontally; only register viewports may.

### 5.3 Menu bar

| Menu | Items |
|---|---|
| File | Backup and export… (opens the existing System Files route), Quit |
| Edit | Copy cell, Copy row, Copy explanation (from the formula bar) |
| View | Appearance: System / Office Machine Day / Office Machine Night / High contrast / Millennium, Show book tree, Show inspector, Show formula bar |
| Desk | New desk, Add sheet to desk ▸, Layout ▸ (single, two columns, main and side), Rename desk, Reset starter desk |
| Record | + Add ▸ (types), Open in its sheet, Void and replace…, Show history |
| Window | Back, Forward, Today, Journal |
| Help | About LifeOS, Keyboard shortcuts |

Each item that has a shortcut shows it right-aligned.

### 5.4 Status line

Segments, left to right: a running shift ("● Shift running · 6:46", which opens the shift on click), a Needs-you count, the open draft count, and on the right "Local database · saved 13:48". The save time is the last committed mutation. An uncertain outcome replaces it with "Last save uncertain. Reload to check", in `negative`.

## 6. Shell Components

### 6.1 Book tree

```text
Journal                    11 today
Views ▸                    2
[W] Work
    <employment name>      running | 563.81 est.
    Shifts                 1 draft
    Pay periods            1 open
    Payslips
    Agreements
[F] Finance                Not built yet
[T] Tracking               Not built yet
[K] Knowledge              Not built yet
Backup and export
```

- The second column shows a live value from the area's projection, never a stored total.
- A node with something waiting shows an orange count.
- Clicking a node opens its sheet on the current desk. A single-sheet desk replaces its sheet; a tiled desk replaces the focused tile.
- Right-click on a node offers: Open, Open on new desk, Add to desk ▸, and Save as view (for a filtered sheet).
- Collapsed branches and the tree width are stored as preferences.

### 6.2 Register v2

The existing `DataRegister` evolves into the shared register used by every sheet.

- **Column types:** text, date, time, duration, money, quantity, state, area chip, derived. Numeric types are right-aligned and use the Figure style.
- **Group rows:** `head`-style rows, for example "September 2026" or "Pay period 14–27 Sep", with a right-aligned summary.
- **Subtotal rows:** a 2-pixel top rule and bold figures.
- **Entry row:** an optional last row that opens the sheet's create form in place, prefilled from last time (6.7).
- **Cell selection:** a click selects a cell and its row. The arrow keys move the cell, and Enter opens the record in the inspector.
- **Row states:** as in 4.5.
- **Right-click menu:** the row's actions (Open, Void and replace…, Show history, Copy cell, Copy row).
- **Columns:** a sheet declares its default columns. Narrowing hides optional columns before the table scrolls.

### 6.3 Formula bar

Every derived cell carries an `Explanation`: a list of tokens (text, operand, operator, result) and a source.

- **Operands** link to the fact or rule they came from, such as a break, an agreement field or a payslip. Clicking one navigates there, and Back returns.
- **A recorded fact** (not derived) shows "Recorded fact · entered Thu 1 Oct 12:41".
- **An empty selection** shows nothing; the bar never shows placeholder text.

Work explanations in Phase 0:

| Value | Explanation |
|---|---|
| Paid time | `end − start − breaks = 07:00→15:45 − 0:30 = 8:15` |
| Expected pay | `regular 8:00 × 18.40 + overtime 0:15 × 18.40 × 1.5 = 154.10 · agreement "Standard" v1 · highest wins` |
| Night, holiday, overtime hours | The segments that carry each flag, for example `22:00→06:00 window ∩ paid time = 1:30` |
| Period expected | `Σ 8 finalized shifts = 1,246.60 · gross` |
| Difference | `paid 1,219.00 − expected 1,246.60 = −27.60 (paid short)` |

Explanations are built from the same `ExpectedPay` breakdown the premiums spec defines (section 5.3), so the bar can never disagree with the cell.

### 6.4 Desks

A desk is an ordered set of tiles plus a layout:

- **Single:** one sheet full size.
- **Two columns:** two sheets side by side.
- **Main and side:** one sheet on the left, up to three stacked on the right.

Free-form dragging is excluded from this phase.

- Each tile shows a `head`-style header with the area chip, the sheet name, a tile menu (Replace sheet, Open full size, Remove) and a close button.
- **Starter desks:** *Today*, *Weekly review* and *Month close*. Starter desks can be edited and reset. Today cannot be deleted.

| Starter desk | Phase 1 content |
|---|---|
| Today | Main: Journal for today and yesterday. Side: Needs you (running shift, drafts, open periods with a difference), Work this period (paid time and expected so far) |
| Weekly review | Two columns: Shifts for the last 7 days, and Pay periods |
| Month close | Main: Pay periods of the month. Side: a checklist of factual checks: every shift finalized, every period has a payslip, every difference reviewed. Finance adds rows in Phase 2 |

The checklist states only what is true in the data. It never ticks itself on a guess.

### 6.5 Journal

The Journal is a read-only, time-ordered projection over every area's facts. In Phase 1 it holds these Work events:

- shift started, ended, finalized, voided or replaced
- break recorded
- pay period created or reviewed
- payslip recorded or voided
- employment or agreement created or changed

Columns are Time, Area, Entry, Amount and State. Days are group rows with a summary (paid time, expected, paid in). Filters cover area, entry kind, state and date range, and any filter can be saved as a view.

The Journal is computed from existing tables and `record_events`. It is never stored.

### 6.6 Inspector

- **Record tab:** the record's facts, derived values (each also explained in the formula bar), links (from Phase 4), and actions next to what they affect.
- **History tab:** `record_events` for this record, newest first. Each event shows its time and what happened, plus a value change (old struck, new) and a reason where the event has them.

Every inspector mode from foundation spec section 15.4 remains, except the removed overtime confirmation (premiums spec section 4).

### 6.7 Quick add and templates

- **+ Add** lists every record type the shipped areas support. In Phase 0–1 those are Start shift, Manual shift, Pay period, Payslip, Employment and Agreement.
- **"From last time" buttons** sit beside + Add for the owner's most recent kinds, up to four. Each opens the create form prefilled from the most recent record of that kind, for example a manual shift with the last employment, start time, end time and break pattern on today's date.
- Prefill is computed when the button is pressed. Templates are not stored in Phase 1.

### 6.8 Back and forward

An in-memory stack of route locations, capped at 100. Back and Forward are toolbar buttons, Window menu items, and mouse buttons 4 and 5. Routes still carry only safe structural state (foundation spec section 14).

### 6.9 Saved views

A saved view is a name plus a sheet, filters, sort and visible columns. Views appear under **Views** in the tree and can be added to desks. They are created from **Save as view** on any filtered sheet, and can be renamed and deleted.

## 7. Phase 0: Work in the New Shell

### 7.1 Gaps fixed

| Found in the current code | Fix |
|---|---|
| Employment, Scope and Status controls have empty handlers (`work_register.dart`) | The Employment switcher (premiums spec 8.4), a period picker with ‹ › stepping and an explicit date range, and a state filter (effective, draft, void) |
| Register shows four columns. Duration ignores breaks, and state shows enum names such as `onBreak` | Columns: Date, Start, End, Break, Paid, Night, Holiday, OT, Est. pay, State. State reads Running, On break, Draft, Finalized or Void |
| A finalized shift's inspector says only "Shift finalized" | Full facts plus the pay breakdown (premiums spec 8.6) |
| Navigation disappears below 1138 pixels | Width behaviour in 5.2 |
| Shifts, periods and payslips are interleaved in one list | Separate sheets: Shifts, Pay periods, Payslips, Agreements. Shifts are grouped by pay period when one exists, otherwise by month |

### 7.2 Work sheets

| Sheet | Columns | Groups | Entry row |
|---|---|---|---|
| Shifts | Date, Start, End, Break, Paid, Night, Holiday, OT, Est. pay, State | Pay period or month | Manual shift |
| Pay periods | Start, End, Shifts, Expected, Paid, Difference, State | Year | Pay period |
| Payslips | Issued, Paid on, Period, Basis, Amount, Reference, State | Year | Payslip |
| Agreements | Version, From, To, Rate, Basis, Overtime, Night, Holiday, Stacking, In use | Employment | Agreement |

### 7.3 Copy

- **First launch, Work sheet empty:** "Track shifts, see what you should be paid, and compare it with your payslips. Start by adding where you work." The button is **Create employment**.
- **Today desk with no employment:** the Needs you tile reads "Nothing waiting. Work is ready when you add an employment."
- **Errors:** copy follows premiums spec section 9.
- **Uncertain outcome:** "LifeOS can't tell whether this was saved. Reload to check before trying again."

## 8. Data Additions

| Table | Columns | Notes |
|---|---|---|
| `record_events` | `id`, `record_kind`, `record_id`, `at_utc`, `kind` (created, changed, finalized, voided, replaced, reviewed), `changes_json` (field, old, new), `reason`, `revision_after` | Append-only, written in the mutation's transaction. Never logged or exported to diagnostics |
| `desks` | `id`, `name`, `starter_key` (nullable), `layout`, `position`, `revision` | Structural only |
| `desk_tiles` | `id`, `desk_id`, `position`, `sheet_ref`, `view_id` (nullable) | `sheet_ref` is a stable sheet key such as `work.shifts` |
| `saved_views` | `id`, `name`, `sheet_ref`, `filters_json`, `sort_json`, `columns_json`, `revision` | Filters hold structural values only: IDs, states, dates |

Preferences gain the appearance mode, tree width, inspector width and collapsed tree nodes. Preferences still never hold record content.

The schema is unreleased, so these tables join the reset schema history the premiums spec introduces.

## 9. Accessibility

- Landmarks: menu bar, toolbar, formula bar (live region, polite), book tree (tree semantics), desk, each tile, inspector, status line.
- A cell selection change announces the cell and the first line of its explanation.
- Every button has visible text. The only icon-only buttons are ‹ and ›, which carry the labels "Back" and "Forward".
- High contrast and 200% text scale keep every region reachable. Optional register columns hide before the layout breaks.
- Colour is never the only signal (section 4.5).

## 10. Testing

**Theme:** contrast test over every token pair in 4.2 and 4.7, for every appearance. Golden tests for the shell at 1280 × 800 in each appearance (Office Machine day, night and high contrast; Millennium), using synthetic data only.

**Shell:**
- Tree navigation opens sheets on the current desk.
- Width behaviour at 1280, 1100 and 960.
- Back and forward, including mouse buttons.
- Status line segments.

**Register:**
- Cell selection with keyboard and pointer.
- Group and subtotal rows.
- The entry row opens a prefilled form.
- Void and replacement ordering.
- The right-click menu matches the inspector's actions.

**Formula bar:**
- Each explanation in 6.3 matches its cell exactly, for day, night, holiday and stacking cases taken from the premiums spec's test list.
- Clicking an operand navigates to its source, and Back returns.

**History:** every Work command appends exactly one event in the same transaction. A failed or stale command appends none. The History tab renders created, changed, finalized, voided and replaced events.

**Desks and views:**
- Starter desks are created on first launch, and resetting one restores it.
- Today cannot be deleted.
- A saved view round-trips its filters, sort and columns.
- The Journal lists Work events in time order with correct day summaries.

**Integration:** fresh install → Today desk → create employment from Needs you → agreement with defaults → start shift → end → finalize. The formula bar explains the expected pay, History shows four events, and the Journal shows the shift.

**Final:** analyze, format and the full test suite pass, and `./app.sh` starts and tests the app.

## 11. Out of Scope Here, Planned Later

| Phase | Area | Owner-selected ideas |
|---|---|---|
| 2 | Finance | Payslips as income; miscellaneous spending with quick categories and receipts; budgets with over/under in words; fuel log (L/100 km, cost per km, price trend); recurring entries as due rows you confirm; subscriptions (monthly equivalent, yearly cost, price history, cancel-by date); savings goals with a computed reached-by date; month close checklist rows |
| 3 | Tracking | Custom tracker types (days-since, yes/no, count, measurement, sets); lapses recorded as facts with earlier runs kept; lift log with e1RM, volume and personal bests; bodyweight with a 7-day average; gym membership cost per visit |
| 4 | Knowledge | Inbox for quick captures; ideas with status (raw, exploring, doing, dropped); media grid for images and videos |

The attachment store that receipts and media share is specified with Phase 2.
