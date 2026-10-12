# LifeOS UI Library Catalog

The reusable era workbench lives in `lib/ui/`. The retiring shell
remains at `lib/shared/shell/` until cutover and cleanup; it is not a source
for new components. This
file is the inventory: read it before writing any UI, reuse what is here, and
add a widget here (with its gallery demo and goldens) before using it.

- **Import:** feature, app and shell code import only `lib/ui/ui.dart`
  (tests: `package:lifeos/ui/ui.dart`). A test fails on any other import of
  a `lib/ui/` file.
- **Look:** `./app.sh` › 5) Open widget gallery. Synthetic data only.
- **Rules:** `DESIGN.md` (colours only from `LifeOSTokens` /
  `MillenniumColors`, EraSans 11 px, painted glyphs, era bevels, no shadows
  or motion). Layout and interaction: `docs/superpowers/specs/2026-10-08-database-shell-and-ui-library-design.md`.
- **Status:** `stable` use freely; `new` just added; `deprecated (use X)`
  retain for existing screens. Demos and compatibility tests may use them
  until their replacements exist; new feature screens should use the
  replacement once available.
- **Folders:** `foundation/` tokens, type, theme, icons, dates;
  `controls/` keys, fields, pickers, menus; `data/` lists and states;
  `shell/` windows and page parts.

## Which widget for which job

| Job | Use | Not |
|---|---|---|
| A list of records | `DataGrid` (legacy screens: `DataRegister`) | hand-built `Table`/`ListView` rows |
| A hierarchy to navigate | `TreeView` | hand-built indented `Column`s |
| A record's facts | `PropertyGrid` (legacy Properties pages: `InspectorFacts`) | free `Text` columns |
| A record's children | `Subform` (tabs over a bordered region) | hand-built tab rows over a `Container` |
| An action the owner presses | `KeyButton` (`KeyKind.primary` first) | Material buttons, `GestureDetector` on text |
| A toolbar action | `BandedToolbar` with `ToolbarItem`s (a lone `KeyButton(kind: KeyKind.toolbar)` only outside it) | icon-only keys without a label |
| Step through periods or days | `StepKey` | arrow characters in text |
| A labelled form row | `EraLabelled` inside an `EraFormScope` | labels floating on the border |
| Free text | `EraField` | `TextField` directly |
| A date | `EraDateField` (`EraMonthCalendar` alone when inline) | Material date pickers |
| A time | `EraTimeField` | text fields parsed by hand |
| Era controls in a new editor host (spec 4.6) | `EraEditorHostScope` around them | per-control key filters, `ExcludeFocus` over editors |
| A value edited in a grid cell, property row or action panel | `CellEditor` on the aggregate's shared `EditorSessionController` | a bare era control with its own draft, commit on focus loss |
| A choice of a few | `EraRadioGroup` (`EraRadio` for one-offs) | a combo with two items |
| A choice of many | `EraCombo` | Material `DropdownButton` |
| Yes or no | `EraCheckBox` | Material `Checkbox`/`Switch` |
| Group related fields | `GroupBox` | cards, shadows |
| Separate blocks | `EtchedLine` | `Divider` |
| A drop-down menu | `EraMenuButton`; rows drawn by `EraMenuLabel` | Material `PopupMenuButton` |
| A right-click menu | `EraContextMenu` | Material menus |
| Tabs on a sheet | `TabStrip` (legacy: `PropertySheetTabs`) | Material `TabBar` |
| A loading, empty or failed sheet | `OperationalState` | a bare spinner |
| An icon | `EraIcon`; small marks `EraGlyph` | font glyphs (a test forbids them) |
| A count waiting on the owner | `CountBadge` | coloured text |
| An area marker | `AreaKey` | letter squares |
| A window | `ConfirmWindow` (confirmations only, spec 4.7) | forms in windows |
| Package and font licences | `LicencesPage` (a page with Back, spec 4.7) | Flutter's `LicensePage`/`showLicensePage`, a licences dialog |
| A multi-step action with inputs (form actions) | `ActionPanel` docked in the property column | form dialogs (`DialogForm`), keys in a hand-built footer |
| The window's layout: menus, toolbar, area tabs, tree, grid over subform, properties, status | `AppFrame` (one instance of each pane; it folds and docks them) | hand-built `Row`/`Column` shells, a second property pane for narrow windows |
| A custom scroll area | automatic through `EraScrollBehavior`; `EraScrollbar` only when drawing one yourself | Material `Scrollbar` |

## Foundation

Non-widget foundations, all exported by `ui.dart`:

- `LifeOSTokens`, `LifeOSArea` (`foundation/lifeos_tokens.dart`): the colour tokens and the four areas.
- `MillenniumColors`, `lifeOSTypography`, `LifeOSPainters`, `InsetRings`, `DottedFocusRectangle` (`foundation/millennium_style.dart`): named era colours, type and decorations.
- `LifeOSSkinData`, `LifeOSTypography`, `KeyKind`, `KeyState`, `KeySurface` (`foundation/lifeos_skin.dart`): the skin a widget reads with `LifeOSSkinScope.of(context)`.
- `buildLifeOSTheme()`, `lifeOSThemeFor(skin)` (`foundation/lifeos_theme.dart`): Material theme that follows the skin.
- `EraIconKind`, `areaIcon(area)` (`foundation/era_icons.dart`): painted icon kinds and the area-to-icon mapping.
- `eraBoxDate`, `eraWeekdayShort`, `spokenDate`, `eraMonthTitle`, `monthGridDays`, `eraMonthNames`, `eraWeekdayInitials` (`foundation/era_dates.dart`): fixed-format date labels and calendar helpers.
- `DateTrace`, `traceTarget` (`foundation/date_trace.dart`): opt-in trace of the date boxes (`LIFEOS_TRACE_DATES=1`).

### LifeOSSkinScope · foundation/lifeos_skin.dart · stable
Provides the LifeOS tokens, type and key painting to every LifeOS-owned widget below it; read with `LifeOSSkinScope.of(context)`.
Use for: the root of any LifeOS widget tree (app, gallery, tests). Not for: per-widget restyling.
API: LifeOSSkinScope(child:)
Gallery: foundation/lifeos_skin_scope · Goldens: test/ui/goldens/foundation_lifeos_skin_scope.png

### EraIcon · foundation/era_icons.dart · stable
The painted 16 and 32 px icon set: areas, record kinds, tasks and the app glyph; greyed when disabled.
Use for: every icon. Not for: small arrows and ticks (`EraGlyph`).
API: EraIcon(kind, size: 16, disabled: false, semanticLabel:)
Gallery: foundation/era_icon · Goldens: test/ui/goldens/foundation_era_icon.png

## Controls

### Orb · controls/era_controls.dart · stable
A painted glossy orb with a white glyph, as on the era's toolbar keys. Decorative; the key beside it carries the words.
Use for: Back, Forward and Add toolbar keys. Not for: standalone buttons.
API: Orb(glyph:, tone:, size: 20) with OrbGlyph.back | .forward | .add and OrbTone.green | .orange | .grey
Gallery: controls/orb · Goldens: test/ui/goldens/controls_orb.png

### EraComboFace · controls/era_controls.dart · stable
What a combo box looks like closed: a white field with the blue arrow button. The surrounding menu button supplies the behavior.
Use for: the face of a custom drop-down (`EraCombo(face:)`, `EraMenuButton`). Not for: a working combo (`EraCombo`).
API: EraComboFace(value:, minWidth: 60, focused: false, enabled: true, fill: false) — `fill` puts the arrow at the right edge of a box wider than its text (a hosted combo uses it; needs a bounded width)
Gallery: controls/era_combo_face · Goldens: test/ui/goldens/controls_era_combo_face.png

### ComboArrow · controls/era_controls.dart · stable
The blue drop-arrow button at the right of a combo box.
Use for: building a combo-shaped control. Not for: a stand-alone arrow mark (`EraGlyph`).
API: ComboArrow(enabled: true)
Gallery: controls/combo_arrow · Goldens: test/ui/goldens/controls_combo_arrow.png

### GroupBox · controls/era_controls.dart · stable
A titled frame around related content, its legend in Head blue.
Use for: grouping form rows (Rate, Breaks). Not for: cards or page sections.
API: GroupBox(legend:, child:, background:)
Gallery: controls/group_box · Goldens: test/ui/goldens/controls_group_box.png

### FormFooter · controls/era_controls.dart · stable
A form's keys, right-aligned and wrapping when narrow; the affirmative key first.
Use for: the keys at the foot of a form or action panel. Not for: toolbars.
API: FormFooter(children:)
Gallery: controls/form_footer · Goldens: test/ui/goldens/controls_form_footer.png

### EraGlyph · controls/era_controls.dart · stable
A small painted mark: drop arrow, sort arrows, step arrows, collapse chevrons or a tick. Painted because the bundled fonts lack these characters.
Use for: arrows and ticks inside controls. Not for: icons (`EraIcon`).
API: EraGlyph(kind, color:, size: 9)
Gallery: controls/era_glyph · Goldens: test/ui/goldens/controls_era_glyph.png

### EraPressable · controls/era_controls.dart · stable
A small pressable control announced as a button or link, with the era's dotted focus rectangle.
Use for: links and small pressable areas that are not push keys. Not for: actions that deserve a key (`KeyButton`).
API: EraPressable(label:, onPressed:, child:, link: false)
Gallery: controls/era_pressable · Goldens: test/ui/goldens/controls_era_pressable.png

### KeyButton · controls/keys.dart · stable
A labelled era push key with a pressable bottom edge: primary (blue double ring), secondary, small and the flat toolbar kind. Greyed when `onPressed` is null.
Use for: every action the owner presses. Not for: links (`EraPressable`).
API: KeyButton(label:, onPressed:, kind: KeyKind.secondary, leading:, trailing:, semanticLabel:, tooltip:)
Gallery: controls/key_button · Goldens: test/ui/goldens/controls_key_button.png

### StepKey · controls/keys.dart · stable
A small key with a painted step arrow (◂ or ▸), for stepping through periods or days.
Use for: previous/next period, month or day. Not for: scrolling.
API: StepKey(forward:, semanticLabel:, onPressed:)
Gallery: controls/step_key · Goldens: test/ui/goldens/controls_step_key.png

### AreaKey · controls/keys.dart · stable
The painted icon that marks a record's area, announced by the area's name.
Use for: an area column or marker. Not for: area tabs (`TabStrip`).
API: AreaKey(area:)
Gallery: controls/area_key · Goldens: test/ui/goldens/controls_area_key.png

### CountBadge · controls/keys.dart · stable
An orange count of something waiting on the owner, such as days to confirm.
Use for: counts beside a tree node or key. Not for: plain totals.
API: CountBadge(count:, semanticLabel:)
Gallery: controls/count_badge · Goldens: test/ui/goldens/controls_count_badge.png

### PropertySheetTabs · controls/property_sheet_tabs.dart · deprecated (use TabStrip)
Property-sheet tabs: inactive tabs white-to-face, the active tab joined to the page with a warm top edge.
Use for: existing Properties sheets only. Not for: new tab rows.
API: PropertySheetTabs(labels:, selectedIndex:, onSelected:)
Gallery: controls/property_sheet_tabs · Goldens: test/ui/goldens/controls_property_sheet_tabs.png

### EtchedLine · controls/etched_line.dart · stable
A 2 px etched separator: a grey line over a white one.
Use for: separating blocks of facts or toolbar bands. Not for: table rules.
API: EtchedLine()
Gallery: controls/etched_line · Goldens: test/ui/goldens/controls_etched_line.png

### EraCombo · controls/era_combo.dart · stable
An era drop-down list combo: the value in a white box beside the blue arrow; its list drops below, at least as wide, with the current value lit.
Use for: choosing one of many values. Not for: two or three choices (`EraRadioGroup`).
API: EraCombo<T>(items: [EraComboItem(value, label, icon:, depth:, muted:, command:)], value:, onSelected:, semanticLabel:, semanticValue:, face:, minWidth: 60, focusNode:); EraCombo.enabledOf(context) tells a custom `face` whether the combo is locked. A hosted combo's face fills its cell.
Gallery: controls/era_combo · Goldens: test/ui/goldens/controls_era_combo.png

### EraField · controls/era_field.dart · stable
A labelled text field in the era's shape: "Label:" in the label column, then a sunken white field; the error shows under it.
Use for: free text and numbers. Not for: dates and times (`EraDateField`, `EraTimeField`).
API: EraField(controller:, label:, fieldKey:, semanticLabel:, error:, hint:, keyboardType:, maxLines: 1, autofocus: false, onSubmitted:, width: EraFieldWidth.text, focusNode:, textAlign: TextAlign.start, figures: false). In an editor host its error shows under the box, left-aligned and wrapping, as the date and time boxes show theirs.
Gallery: controls/era_field · Goldens: test/ui/goldens/controls_era_field.png

### EraFormScope · controls/era_form.dart · stable
Sets a form's "Label:" column width and enables or greys every era field below it.
Use for: the root of every form or action panel. Not for: layout.
API: EraFormScope(labelWidth: 110, enabled: true, child:)
Gallery: controls/era_form_scope · Goldens: test/ui/goldens/controls_era_form_scope.png

### EraLabelled · controls/era_form.dart · stable
"Label:" in the label column, then the field at its kind width (`EraFieldWidth.date`, `time`, `money`, `short`, `text`).
Use for: every labelled row of a form. Not for: fields that carry their own label (`EraField`, `EraDateField`).
API: EraLabelled(label:, field:, fieldWidth:, grow: false)
Gallery: controls/era_labelled · Goldens: test/ui/goldens/controls_era_labelled.png

### EraCheckBox · controls/era_form.dart · stable
A 13 px era check box with its label; the whole row toggles it.
Use for: a yes/no setting. Not for: one of several exclusive choices (`EraRadioGroup`).
API: EraCheckBox(value:, onChanged:, label:, focusNode:). In an editor host a click also focuses it; a bare host shows the box alone (the label stays its name).
Gallery: controls/era_check_box · Goldens: test/ui/goldens/controls_era_check_box.png

### EraRadio · controls/era_form.dart · stable
A 13 px era radio with its label and optional detail; the whole row selects it.
Use for: radios laid out by hand. Not for: an ordinary group (`EraRadioGroup`).
API: EraRadio<T>(value:, groupValue:, onChanged:, label:, detail:, focusable: true, highlighted: false, focusNode:)
Gallery: controls/era_radio · Goldens: test/ui/goldens/controls_era_radio.png

### EraRadioGroup · controls/era_form.dart · stable
Era radios that act as one choice.
Use for: choosing one of a few. Not for: many values (`EraCombo`).
API: EraRadioGroup<T>(options: [EraRadioOption(value, label, detail:)], groupValue:, onChanged:, direction: Axis.vertical)
Gallery: controls/era_radio_group · Goldens: test/ui/goldens/controls_era_radio_group.png

### EraDateField · controls/era_date_field.dart · stable
A date box in the era's Date/Time Picker shape: the label above a white box showing "Wed 2026-10-07" beside a blue drop arrow to the month calendar; digits can be typed into its parts.
Use for: every date value. Not for: a calendar shown inline (`EraMonthCalendar`).
API: EraDateField(label:, value:, onChanged:, today:, optional: false, error:, fieldKey:, focusNode:, autofocus: false)
Gallery: controls/era_date_field · Goldens: test/ui/goldens/controls_era_date_field.png

### EraTimeField · controls/era_time_field.dart · stable
A time box in the era's Date/Time Picker shape: hours and minutes beside stacked spin arrows; parts are stepped or typed.
Use for: every time of day. Not for: durations shown read-only.
API: EraTimeField(value:, onChanged:, label:, semanticLabel:, emptyStart:, enabled: true, error:, fieldKey:, focusNode:, autofocus: false)
Gallery: controls/era_time_field · Goldens: test/ui/goldens/controls_era_time_field.png

### EraMonthCalendar · controls/era_month_calendar.dart · stable
The era month calendar: the month on a blue band between ◂ and ▸, six Monday-first weeks with today circled, and a Today link.
Use for: an inline month, or the drop-down of a date box. Not for: the Work calendar sheet (`WorkCalendar`).
API: EraMonthCalendar(today:, onPicked:, selected:, onCancel:, autofocus: false, focusNode:, traceName: 'calendar')
Gallery: controls/era_month_calendar · Goldens: test/ui/goldens/controls_era_month_calendar.png

### EraEditorHostScope · controls/era_editor_host.dart · new
Opts the era controls below it into the database shell keyboard (spec 4.6): they take only data entry (typing, Backspace/Delete, Left/Right; date and time digits, separators and Up/Down part steps), hand each plain Enter, Tab or Esc press to the host's `onKey`, and hold every other key. Calendars and combo lists open and pick by mouse only and never take focus; while one is open, Enter, Tab and Esc close it without taking its lit day or row, then reach `onKey`. `bare` drops the "Label:" and row spacing for an editor in a grid or property cell; the field keeps its semantic name, error, enabled state and at least its kind width. A hosted combo also greys and locks in a read-only `EraFormScope`.
Use for: the controls inside a new editor host (`CellEditor`, grid and property cells, action-panel fields). Not for: legacy forms, which keep their keys outside it; it does not commit, advance or cancel by itself (the host does that in `onKey`).
API: EraEditorHostScope(child:, bare: false, onKey: (EraEditorKey key) {}); EraEditorKey.enter, .tab, .escape; EraEditorHostScope.maybeOf(context) (no dependency, for handlers), .watch(context) and .bareOf(context) (dependent, for build), .editorKeyOf(event), .handleKey(context, event)
Gallery: controls/era_editor_host_scope · Goldens: test/ui/goldens/controls_era_editor_host_scope.png

### CellEditor · controls/cell_editor.dart · new
One field's era editor under a shared `EditorSessionController`: bare in a grid or property cell, labelled in an action-panel row. It reuses the era control of its `ValueKind` (via `valueEditor`) inside an `EraEditorHostScope`. Enter or Tab flushes the field and, only when the draft is accepted, opens the next eligible field of the same record (scrolled into view, then focused); at the last field the editor closes, with no wrap or traversal. Esc cancels this field only. A rejected draft stays in the red editor with its reason and keeps the keyboard. The draft lives in the controller, so a recycled cell remounts with it; a closed editor shows the caller's value and opens on focus, click, typing or a tick, and a click while another field's draft is rejected does nothing to it.
Use for: every editable value of the database shell's grid, property grid, subform and action panel. Not for: legacy forms (`EraField`, `EraDateField`… directly); saving records (the caller's commit only accepts a UI draft).
API: CellEditor(controller:, field: EditField(id: EditIdentity(record:, field:), kind: ValueKind.text, value:, commit: (EditIdentity id, Object? draft) => EditResult.accepted() / EditResult.rejected('reason'), text:), label:, bare: true, host:, next: () => EditField?, choices: [EraComboItem<Object?>], today:, optional: false, enabled: true, error:, fieldKey:)
- `EditorSessionController` (`controls/editor_session_controller.dart`, a `ChangeNotifier` the caller owns, one per pending aggregate): `session` (`EditSession`: `id`, `kind`, `host`, `original`, `entry`, `draft`, `editing`, `error`, `changed`), `active`, `isActive(id)`, `begin(field, host:)` (flushes a different open field first; refuses when that is rejected), `update(id, draft, editing:)`, `flush()` (synchronous; accepted with no or an unchanged field; every command that may use the draft calls it first), `cancel()`, `requestFocus()`, `takeFocusRequest(id, host:)` (for editor widgets). No database, service, navigation or asynchronous save.
- `ValueKind` (`controls/value_editor.dart`): `text`, `number`, `money`, `duration`, `date`, `time`, `choice`, `check`; `isNumeric`, `usesFigures`, `typedAsText`, `align`, `fieldWidth`. Number, money and duration edit as raw text the caller parses.
- `formatValue(kind, value, choices:, display:)`: null empty, dates "Thu 2026-10-08", times "07:00", checks Yes/No, choices by label, `display` for amounts and durations (no invented currency or rounding).
- `valueEditor(kind:, label:, value:, controller:, onChanged:, choices:, today:, optional:, error:, enabled:, focusNode:, fieldKey:)`: the controlled era editor of a kind.
Gallery: controls/cell_editor · Goldens: test/ui/goldens/controls_cell_editor.png

### EraMenuLabel · controls/era_menu.dart · stable
A menu row's gutter (icon or check) and text; the default command bold, disabled rows muted.
Use for: drawing rows inside era menus. Not for: lists.
API: EraMenuLabel(item)
Gallery: controls/era_menu_label · Goldens: test/ui/goldens/controls_era_menu_label.png

### EraMenuButton · controls/era_menu.dart · stable
A key that drops an era menu, as the toolbar's Add does; `builder` draws the key and calls its toggle.
Use for: drop-down command menus. Not for: choosing a value (`EraCombo`).
API: EraMenuButton(items: [EraMenuItem(label, onSelected, isDefault:, icon:, checked:), EraMenuItem.separator()], builder: (context, toggle) => …, tooltip:)
Gallery: controls/era_menu_button · Goldens: test/ui/goldens/controls_era_menu_button.png

### EraContextMenu · controls/era_menu.dart · stable
Hosts the era right-click menu over its child; `show` opens it at once with its corner at the pointer.
Use for: right-click menus on rows and nodes. Not for: the only route to an action (also offer a key or menu-bar item).
API: EraContextMenu(key: GlobalKey<EraContextMenuState>(), child:); open with key.currentState!.show(globalPosition, items)
Gallery: controls/era_context_menu · Goldens: test/ui/goldens/controls_era_context_menu.png

### EraScrollbar · controls/era_scrollbar.dart · stable
The 17 px era scrollbar beside or under its scroll area: arrow keys, a pale track and a blue thumb with grip lines; shown only while content overflows.
Use for: a scroll area that draws its own bar. Not for: ordinary scrolling (`EraScrollBehavior` adds it automatically).
API: EraScrollbar(controller:, axis:, child:, depth: 0)
Gallery: controls/era_scrollbar · Goldens: test/ui/goldens/controls_era_scrollbar.png

## Data

### DataGrid · data/data_grid.dart · new
A controlled editable datasheet: bevelled sort/resize headers, group summaries, current/pending/new selectors, muted and void rows, changed values, cell errors, aligned caller totals, pick counts and a record navigator. Rows are lazy even across distant jumps; stable row keys and the shared controller preserve drafts through reorder, filtering and disposal. Click once to select, then an eligible cell to edit. Enter/Tab accepts and advances within the same row; Esc cancels the field. Commands flush first, rejected drafts stay open, and resizing preserves the draft. Editor widths include chrome and scaled text; the table scrolls horizontally under the era scrollbars.
Use for: lists of records and child records with inline editing or picking. Not for: a record's property sheet, persistence or domain validation.
API: DataGrid<T>(label:, columns: [GridColumn<T>(key:, label:, kind:, width:, value:, display:, editText:, choices:, editable: false, optional: false, sortable: true, description:, minWidth: 24)], lines: [GridGroup<T>(label:, summary:), GridRow<T>(row, state: GridRowState.normal | muted | voided)], rowId:, rowLabel:, selectedId:, editorController:, onSelect:, onEdit: (GridCell cell, Object? draft) => EditResult, currentRow:, readOnlyReason:, onExplain:, today:, enabled: true, active: true, pendingIds:, changed:, errors:, onNew:, sortColumn:, sortDescending: false, onSort:, footer:, footerLabel:, pickMode: false, pickedIds:, canPick:, onPick:, widths:, onResize:, showNavigator: true, note:)
- `GridCell(rowId, column)` names a cell; `.identity` is its shared `EditIdentity`. `onEdit` accepts into caller-owned pending rows synchronously or rejects with a reason. Immutable replacement works by default: next-field value and eligibility are read after the caller rebuilds. Optional `currentRow(id)` supplies live rows for mouse transitions; Enter/Tab always wait for the rebuilt columns too. `readOnlyReason(row, column)` returns null for eligible editable columns. `canPick(row)` prevents unavailable picks. The caller owns selection, sort, picks, totals and stored widths.
- Removal or refresh never clears an open draft. Removed rows display an orphan notice; the controller retains the original identity, draft and rejection until the caller explicitly flushes or cancels. A disposed grid rejects a retained draft instead of calling its former owner.
Gallery: data/data_grid · Goldens: test/ui/goldens/data_data_grid.png


### DataRegister · data/data_register.dart · deprecated (use DataGrid, phase 2)
The details list: bevelled sortable headers, the sorted column tinted, blue group rows, 20 px rows, planned rows greyed, subtotals, a cell cursor and right-click row actions.
Use for: existing lists in legacy screens. Not for: new screens of the database shell.
API: DataRegister<T>(label:, lines: [GroupLine(label:, summary:), RowLine(row, state:), SubtotalLine(cells:, label:)], columns: [RegisterColumn(key:, label:, kind:, width:, value:, explain:, cell:, optional:, description:)], rowId:, rowLabel:, selectedId:, onOpen:, onActivate:, actions:, sortedColumn:, sortDescending: false)
Gallery: data/data_register · Goldens: test/ui/goldens/data_data_register.png

### CellSelectionScope · data/cell_selection.dart · stable
Shares the selected list cell (and its explanation) with the whole window.
Use for: the window root, so derived figures can explain themselves. Not for: row selection.
API: CellSelectionScope(controller: CellSelectionController(), child:); read with CellSelectionScope.maybeOf(context)
Gallery: data/cell_selection_scope · Goldens: test/ui/goldens/data_cell_selection_scope.png

### OperationalState · data/operational_state.dart · stable
A sheet's loading, empty, unavailable, invalid-scope, conflict and uncertain states, with an optional key.
Use for: whatever a sheet shows instead of its rows. Not for: field errors.
API: OperationalState(kind:, title:, message:, action:) with OperationalStateKind.loading | .empty | .unavailable | .invalidScope | .conflict | .uncertain
Gallery: data/operational_state · Goldens: test/ui/goldens/data_operational_state.png

### PropertyGrid · data/property_grid.dart · new
The key/value editor of the selected record, as VB's Properties window: a Categorized / A–Z toolbar (painted mouse-only keys) with an optional "Edited" marker, collapsible category headings, a name column whose selection is blue while `active` and face grey otherwise, a kind-specific bare `CellEditor` in the row of the open value, muted read-only values, bold changed values followed by "(was …)", follow links and a description pane (the selected property's name, then its validation error, read-only reason and description). Edits go through the aggregate's shared `EditorSessionController` with the grid's own host token, identity `EditIdentity(record:, field: item.key)`; a field opened by another region (the data grid) shows the same draft here while the keyboard stays with that region. A click on an editable value opens it; Enter/Tab commit and open the next eligible value down (disabled, read-only and link rows skipped, checks and choices included), chosen after the caller has rebuilt the grid from its refreshed items, so a commit that changes eligibility is respected; no wrap at the last value; Esc drops the open value only. Selecting another property, collapsing, sorting and following a link each flush first and do nothing when the flush is refused. Mouse only outside an editor: the grid keeps the keyboard on its own node when an editor closes, and no key selects, opens, collapses, sorts or scrolls. Layout is measured from the width inside the border and scrollbar: the label column is clamped (128 px at 100 %) to leave the widest editor its minimum, a row whose value minimum or a label word does not fit puts the label above the value, and an editor wider than the grid scrolls sideways. The description grows with its text up to 35 % of the grid's height and scrolls. Needs a bounded height. Selection, collapse and order are local view state; a new `record` resets selection and collapse, and drafts never cross records (an orphaned draft stays in the controller under its own record).
Use for: the property column's facts and in-place edits of one record. Not for: lists of records (`DataGrid`), multi-step actions (`ActionPanel`) or the tree pane's read-only summary (`DetailsBox`).
API: PropertyGrid(record:, controller:, items: [PropertyItem(key:, label:, category:, kind: ValueKind.text, value:, display:, text:, readOnlyReason:, was:, description:, choices:, optional: false, onFollow:, error:, enabled: true)], onCommit: (EditIdentity id, Object? draft) => EditResult, today:, active: true, enabled: true, initialOrder: PropertyGridOrder.categorized, onOrderChanged:, edited: false, label: 'Properties'). `onCommit` is synchronous UI draft acceptance applied to `id.record`. Duplicate keys throw. `PropertyItem.editable` is enabled, not read-only and not a link.
Gallery: data/property_grid · Goldens: test/ui/goldens/data_property_grid.png

### RecordNavigator · data/record_navigator.dart · new
First, previous, "3 of 12", next, last and new keys with painted glyphs, a read-only sunken position and an optional wrapping note. Controlled: it reports requests, the owner supplies the new position (and flushes any open editor first). Mouse only: the keys take no focus and ignore the keyboard.
Use for: stepping through a form's or grid's records. Not for: stepping through days or periods (`StepKey`).
API: RecordNavigator(position:, count:, label:, onGo: (target) {}, onNew:, note:). `position` is one-based, 0 for no selection; `0 of 0` when empty. `onGo` always receives a target in `1..count`; null disables the four moves. `onNew` is enabled only when supplied and the `EraFormScope` is enabled.
Gallery: data/record_navigator · Goldens: test/ui/goldens/data_record_navigator.png

### Subform · data/subform.dart · new
A record's children: subform tabs (20 px, active 22) over a bordered content region. Tabs are `SubformTab`s selected by id (controlled, like `TabStrip`); each carries a content builder, so the owner can append a Properties or action-panel tab beside the children tabs. With a shared `EditorSessionController`, a tab request first flushes it: a rejected draft keeps the tab and does not ask the owner, an accepted one calls `onSelect(id)`. Every tab shown once keeps its content in the tree, keyed by tab id, so state survives a round trip and reordering; hidden content is not painted, hit-tested or announced, takes no focus and runs no tickers. An unknown or null `selectedId` shows nothing and indexes nothing (reconcile with `TabStrip.resolveSelection`); no tabs shows `emptyText`; duplicate ids throw. Fills a bounded height, otherwise takes the content's. Mouse only.
Use for: the child grids and the Properties tab of a record. Not for: area tabs (`TabStrip`) or keyboard tabs.
API: Subform(tabs: [SubformTab(id:, label:, builder:, icon:, enabled: true, disabledReason:, tooltip:, count:, countLabel: 'waiting')], selectedId:, onSelect: (id) {}, controller:, trailing:, label:, emptyText:)
Gallery: data/subform · Goldens: test/ui/goldens/data_subform.png

### TreeView · data/tree_view.dart · new
The object tree: XP dotted connector lines, boxed plus/minus expanders, 16 px icons, counts, warning (run ink) and muted nodes. Mouse only: no key selects, expands or scrolls. Selection is a controlled request; expansion is local state keyed by node id (initial expansion honoured once per newly seen id, removed ids pruned, duplicate ids rejected). Rows are lazy and fixed-height; labels truncate (full name in semantics); indentation is capped. Takes its content height, capped by `maxContentHeight`, then scrolls.
Use for: the object tree above the Details box. Not for: lists of records (`DataGrid`) or menus.
API: TreeView(label:, nodes: [TreeNodeData(id:, label:, icon:, count:, children:, warning: false, muted: false, bold: false, expanded: false, enabled: true)], selectedId:, onSelect:, active: true, enabled: true, onExpansionChanged:, maxContentHeight:)
Gallery: data/tree_view · Goldens: test/ui/goldens/data_tree_view.png

## Shell

### EraDialog · shell/era_dialog.dart · stable
An in-app window in the era's shape: a blue caption with the title and red close key, a face-coloured body and keys bottom-right.
Use for: confirmation windows only (spec 4.7). Not for: forms (they are inline).
API: EraDialog(title:, body:, actions:, onClose:)
Gallery: shell/era_dialog · Goldens: test/ui/goldens/shell_era_dialog.png

### EraMovableDialog · shell/era_dialog.dart · deprecated (use ConfirmWindow, phase 2)
Centres a dialog in its space and lets the owner drag it by its caption, kept wholly inside.
Use for: existing dialogs only. Not for: anything new (no movable windows in the database shell).
API: EraMovableDialog(child:)
Gallery: shell/era_movable_dialog · Goldens: test/ui/goldens/shell_era_movable_dialog.png

### CaptionBar · shell/era_dialog.dart · stable
A blue gradient caption with a title and a red close key, shared by windows and tiles.
Use for: the caption of an era window. Not for: pane captions (phase 2 `PaneCaption`).
API: CaptionBar(title:, onClose:, leading:, trailing: const [], closeLabel:, large: false)
Gallery: shell/caption_bar · Goldens: test/ui/goldens/shell_caption_bar.png

### InspectorPane · shell/dialog_parts.dart · deprecated (use PropertyGrid, phase 2)
A scrolling Properties page on the inspector inset.
Use for: existing Properties dialogs only. Not for: new screens.
API: InspectorPane(children:)
Gallery: shell/inspector_pane · Goldens: test/ui/goldens/shell_inspector_pane.png

### DialogForm · shell/dialog_parts.dart · deprecated (use ActionPanel, phase 2)
A dialog form: fields scroll on the inspector inset and keys stay bottom-right.
Use for: existing form dialogs only. Not for: new forms (inline action panels).
API: DialogForm(fields:, keys:)
Gallery: shell/dialog_form · Goldens: test/ui/goldens/shell_dialog_form.png

### InspectorTitle · shell/dialog_parts.dart · deprecated (use PropertyGrid, phase 2)
A record's name, optional secondary line and 32 px icon at the top of a Properties page, then an etched line.
Use for: existing Properties pages only. Not for: the database shell's object box.
API: InspectorTitle(title, meta:, icon:)
Gallery: shell/inspector_title · Goldens: test/ui/goldens/shell_inspector_title.png

### InspectorFacts · shell/dialog_parts.dart · deprecated (use PropertyGrid, phase 2)
A block of "Label:" fact rows closed by an etched line.
Use for: existing Properties pages and the old Details group. Not for: editable values.
API: InspectorFacts(facts, legend:) with Fact(label, value, figure: true, tone:) or Fact.words(label, value)
Gallery: shell/inspector_facts · Goldens: test/ui/goldens/shell_inspector_facts.png

### InspectorFactRow · shell/dialog_parts.dart · deprecated (use PropertyGrid, phase 2)
One row of `InspectorFacts`.
Use for: a single fact in an existing page. Not for: new screens.
API: InspectorFactRow(fact:)
Gallery: shell/inspector_fact_row · Goldens: test/ui/goldens/shell_inspector_fact_row.png

### InspectorNote · shell/dialog_parts.dart · deprecated (use PropertyGrid, phase 2)
A secondary line under the facts, red or green by tone.
Use for: an explanation in an existing page. Not for: validation errors.
API: InspectorNote(text, tone:)
Gallery: shell/inspector_note · Goldens: test/ui/goldens/shell_inspector_note.png

### InspectorText · shell/dialog_parts.dart · deprecated (use PropertyGrid, phase 2)
Body text in an inspector page, for a sentence that is the content itself.
Use for: existing pages only. Not for: labels.
API: InspectorText(text)
Gallery: shell/inspector_text · Goldens: test/ui/goldens/shell_inspector_text.png

### InspectorActions · shell/dialog_parts.dart · deprecated (use ActionPanel, phase 2)
A record's keys at the foot of a page, right-aligned and wrapping.
Use for: existing pages only. Not for: new action rows (`FormFooter`).
API: InspectorActions(children:)
Gallery: shell/inspector_actions · Goldens: test/ui/goldens/shell_inspector_actions.png

### PropertySheetScope · shell/property_sheet.dart · deprecated (use EditSession, phase 3)
Gives an open Properties sheet's OK, Cancel and Apply keys its edit state through a `PropertySheetController`.
Use for: existing Properties dialogs only. Not for: the database shell's pending edits.
API: PropertySheetScope(controller: PropertySheetController(), child:); read with PropertySheetScope.maybeOf(context)
Gallery: shell/property_sheet_scope · Goldens: test/ui/goldens/shell_property_sheet_scope.png

### ActionPanel · shell/action_panel.dart · new
An inline multi-step action in the property column (spec 4.4): the action's title in a white object box, group boxes of labelled fields that scroll, an error row and result rows (done, failed with its reason, uncertain) after them, and the primary verb and Cancel pinned below the scroll region, primary first (the footer scrolls on its own past half the height). Fields are registered in order (`ActionField`: stable id, the owner's value, `validate`, `enabled` eligibility) and edited as labelled `CellEditor`s on the owner's shared `EditorSessionController`, identified by (`record`, field id): Enter or Tab commits and opens the next enabled field, and at the last closes it; neither ever presses a key. Esc throws away the open field only. An accepted draft reaches `onChanged` synchronously. `groups` is a builder that reads the owner's live input: after a commit, the next field, its eligibility and its entry value are read again before the owner rebuilds. Removing the committed field closes editing without wrapping. The keys are mouse only (no focus, no Tab stop). The primary key flushes the open editor first and does nothing when the draft is refused; it fires once per click and not again before the next frame. Cancel cancels this panel's open field (another region's draft is left alone), then asks the owner (`onCancel`), who confirms with a `ConfirmWindow` if anything was entered and closes the panel. When a focused editor is locked or goes away and focus falls to an enclosing non-root scope, the panel holds every key. A live editor losing focus, another region, the application root scope and inactive/resumed lifecycle transitions are left alone. Controlled: the owner keeps the input, `results`, `error` and `busy`. While `busy` every field, the group children and both keys are locked (wait cursor), and a draft cannot be committed. The owner drives pick mode: it passes its grid no pick callback while `busy` and resubmits only failed items. Results are shown as given, so a later failure never changes completed rows. A remounted panel of the same `record` keeps the open draft (AppFrame docking); a removed one leaves it as an orphan, rejected with "This action was closed.", until the owner cancels it.
Use for: actions with inputs or over several picked records (confirm days, correct, void with a reason, change from a date). Not for: confirming one irreversible step (`ConfirmWindow`); editing a record's own values (`PropertyGrid`); legacy dialogs (`DialogForm`).
API: ActionPanel(title:, record:, controller:, groups: () => [ActionGroup(legend:, fields: [ActionField(id:, label:, kind: ValueKind.text, value:, text:, validate: (draft) => 'reason' or null, enabled: true, choices:, optional: false, error:, fieldKey:)], children: [Widget])], onChanged: (field, value) {}, primaryLabel:, onPrimary:, onCancel:, cancelLabel: 'Cancel', results: [ActionResult.done(label, detail:) | ActionResult.failed(label, reason) | ActionResult.uncertain(label, detail:)], resultsLegend: 'Results', error:, busy: false, enabled: true, today:, labelWidth: 96). `onPrimary` null greys the key (nothing picked). `ActionResult(label:, outcome: ActionOutcome.done | failed | uncertain, detail:)`.
Gallery: shell/action_panel · Goldens: test/ui/goldens/shell_action_panel.png


### AppFrame · shell/app_frame.dart · new
The database shell's window (spec 3): a mouse-only menu bar, the caller's banded toolbar, area tabs, the tree pane (caption, the tree capped at 60 %, Details under it), the middle column (the caller's grid over a 5 px splitter and the subform) and the property column, then the status bar. The 196/306/168 baseline sizes are the owner's per-area `AppFramePanes`, scaled by the text size exactly once and clamped to the room left after chrome, splitters, the page scrollbar and the panes' scaled minima (extreme, negative or missing values included); each splitter drag reports baseline pixels and the frame keeps no copy, so supplied (restored) sizes always win. By **client width**, before the page padding: below 1024 px, or whenever three columns' scaled minima do not fit, the tree folds into a **Tree** key handed to `toolbarBuilder` and the property column narrows to at most 260 px (scaled); the key opens the same tree and Details as an overlay hanging from it, bounded by the page and closed by its Close key or any click outside (the click only closes). Below 860 px, or whenever grid and property column do not fit side by side, `properties` becomes a tab (`AppFrame.propertiesTabId`) beside the subform tabs in the resizable lower region; an action panel in `properties` goes with it. Each pane (tree pane, middle, lower region, properties) is one element under a frame-owned global key: it moves between column, overlay, docked tab and an off-stage park without being rebuilt, so drafts, the focused editor, scroll positions and the property grid's host stay; parked or hidden panes are not painted, hit or focusable; moving never flushes or cancels. When the window narrows while the property column is the active region (last clicked or focused), the frame shows the docked tab at once and asks the owner through `onSubformSelect` (no flush); widening with that tab selected asks for the child tab shown before; the owner's later selection wins. After any resize the focused editor is scrolled back into view. The chrome scrolls in a bounded top region and the page scrolls below its minimum (which includes the subform's measured, wrapped tab strip), so at 800 x 600 and 200 % text every command, editor, error and footer is reachable without shrinking or clipping. Menu rows and area tabs flush `controller` first and drop the request when it is refused; subform tabs flush through `Subform`; toolbar callbacks are the owner's. Nothing in the chrome takes focus.
Use for: the database shell's window, the widget gallery and the gallery's whole-composition demo. Not for: a second property pane for narrow windows, dialogs, or keeping layout sizes (the owner persists `AppFramePanes` per area).
API: AppFrame(toolbarBuilder: (context, ToolbarItem? treeAction) => BandedToolbar(…), areas: [TabItem], areaId:, onAreaSelect:, tree: TreeView(…), details: DetailsBox(…), middle: DataGrid(…), properties: PropertyGrid(…) or ActionPanel(…), panes: AppFramePanes(left: 196, right: 306, dock: 168), onPanesChanged:, onPanesChangeEnd:, menus: [AppMenu(label, [EraMenuItem])], treeTitle: 'Objects', treeIcon: EraIconKind.work, subformTabs: [SubformTab], subformSelectedId:, onSubformSelect:, subformTrailing:, subformLabel:, propertiesLabel: 'Properties', status: StatusBar(…), controller:, enabled: true). Slots: put `treeAction` in a band (first key) when non-null; `middle` needs no size; `properties` and subform tab builders must not hold global keys of their own beyond the frame's (one instance each), and `subformTrailing` is also measured off-stage, so it holds none either; `status` caps its own height (`StatusBar`). `GlobalKey<AppFrameState>`: `openTree()`, `closeTree()`, `treeOpen`, `layout`.
- `AppFramePanes` (`left`, `right`, `dock`; `baseline`; `copyWith`): baseline logical pixels at 100 % text.
- `AppFrameLayout.resolve(width:, scale:, panes:)`: the pure fold/dock decision and clamped widths (`treeFolded`, `propertiesDocked`, `left`, `leftMax`, `right`, `rightMax`, `flyoutWidth`, `pageMinHeight(lower:, strip:)`, `lowerHeight(height, panes, strip:)`); constants `AppFrame.foldWidth` 1024, `dockWidth` 860, `narrowRight` 260 and the scaled minima `minLeft`, `minMiddle`, `minRight`, `minGrid`, `minLower`, `minDock`, `minPaneHeight`, `minPropertiesHeight`.
Gallery: shell/app_frame · Goldens: test/ui/goldens/shell_app_frame.png

### ConfirmWindow · shell/confirm_window.dart · new
The confirmation window in the era's shape: blue caption with a red close key, a painted warning or information sign, a message and two or three keys in a wrapping row. The first choice is the affirmative one. The close key reports the caller's explicit `cancelValue` (it may equal a choice, such as "Keep editing"); nothing is guessed. Mouse only: no part takes focus, so Enter and Space activate nothing. It fits the space given (wider with larger text, never past the bounds): a long message scrolls and keys wrap. Not movable, no form fields. Disabled greys the keys and the close key and makes them inert. `showConfirmWindow` hosts it in a modal route: non-dismissible barrier (taps do nothing), no animation or shadow, every key consumed so none reaches an editor under the route, the caller's theme and skin carried across. A route closed by other means completes with `cancelValue`. Native application close is phase 3.
Use for: confirming or choosing before a leave, discard or replace. Not for: forms (`ActionPanel`) or keyboard-driven dialogs.
API: ConfirmWindow<T>(title:, message:, choices: [ConfirmChoice(value:, label:, semanticLabel:)], cancelValue:, onChoose:, sign: ConfirmSign.warning | info, enabled: true); `Future<T> showConfirmWindow<T>(context, title:, message:, choices:, cancelValue:, sign:, useRootNavigator: true)`. `CaptionBar` gains `closeEnabled`.
Gallery: shell/confirm_window · Goldens: test/ui/goldens/shell_confirm_window.png

### DetailsBox · shell/details_box.dart · new
The object pane's Details box: a caption, then sections of "Label: value" facts, follow links and warnings (run ink, painted warning mark) separated by etched rules. The caption is pinned and the sections scroll on their own under a bounded height; labels and values wrap, and a value that does not fit beside its label moves under it. Display text comes from the caller. Links are mouse-only (no focus, no Tab stop); `onFollow` is a plain callback, so a caller with a pending edit flushes its editor before acting.
Use for: the facts, links and warnings of the selected record in a pane. Not for: editable values (`PropertyGrid`).
API: DetailsBox(caption:, sections:, emptyText:) with DetailsSection(title:, facts:, warnings:), DetailsFact(label, value, onFollow:, figure: true) and DetailsWarning(text, onFollow:)
Gallery: shell/details_box · Goldens: test/ui/goldens/shell_details_box.png

### StatusBar · shell/status_bar.dart · new
The status bar: the last notice or pending summary, caller-supplied sunken panels, run-ink warning text and a painted size grip. Reflows by measured text: one row when everything fits, else the notice (capped at three lines, scrolling inside) over wrapping panels, each limited to the bar's width. The bar itself is capped (`maxHeight`, default 30 % of a bounded parent) and scrolls past it, so it cannot consume the page. The size grip is decorative (no native resize in 2a) and the bar has no focusable parts.
Use for: the bottom line of a page or window. Not for: commands (`KeyButton`) or modal results (`ConfirmWindow`).
API: StatusBar(notice:, panels:, warning:, sizeGrip: true, maxHeight:) with StatusPanel(text, semanticLabel:)
Gallery: shell/status_bar · Goldens: test/ui/goldens/shell_status_bar.png

### BandedToolbar · shell/banded_toolbar.dart · new
The banded toolbar: bands that start with a painted gripper and are split by etched lines; flat mouse-only keys that rise on hover or press; unavailable keys greyed in place. Wraps between bands and within an oversized band, and bounds its trailing slot (a Find editor), so Save and Undo stay reachable at 800 x 600 and 200 % text. Keys take no focus; Enter and Space never activate one.
Use for: the window's command bands, including AppFrame's Tree key when the tree column is folded (an ordinary `ToolbarItem`). Not for: form footers (`FormFooter`) or keyboard-operated commands.
API: BandedToolbar(bands: [ToolbarBand(items: [ToolbarItem(label:, onPressed:, icon:, leading:, tooltip:, iconOnly: false, dropArrow: false) | ToolbarItem.separator()])], trailing:, trailingWidth: 200). Callbacks are plain; an owner whose command uses a draft flushes the editor first.
Gallery: shell/banded_toolbar · Goldens: test/ui/goldens/shell_banded_toolbar.png

### PaneCaption · shell/pane_caption.dart · new
The caption over a pane: icon, title, passive trailing content, icon-only mouse actions and a Close key. The title and trailing wrap within the width; Close stays visible. Nothing takes keyboard focus: focus is removed from `trailing`, so a key placed there works by mouse only.
Use for: the caption over a tree, details or property pane. Not for: window captions (`CaptionBar`) or commands that need the keyboard.
API: PaneCaption(title:, icon:, trailing:, actions: [PaneCaptionAction(icon:, semanticLabel:, onPressed:)], onClose:, closeLabel:)
Gallery: shell/pane_caption · Goldens: test/ui/goldens/shell_pane_caption.png

### Splitter · shell/splitter.dart · new
The 5 px draggable divider between two panes, mouse only, with the resize cursor for its axis. It owns no size: it reports the pointer's total displacement since the press and the parent applies and clamps it, so dragging past a clamp and back is reversible.
Use for: dividing panes of the page; `axis` is the direction the panes lie in (horizontal for side by side). Not for: any keyboard resizing.
API: Splitter(axis:, onDrag: (offset) {}, onDragStart:, onDragEnd:, semanticLabel:). The parent sets `size = sizeAtPress + offset`, clamped.
Gallery: shell/splitter · Goldens: test/ui/goldens/shell_splitter.png

### LicencesPage · shell/licences_page.dart · new
The Licences page: a title bar with a Back key over a read-only white list of every package and font licence, built lazily and scrolling with the era scrollbar. The loader is injectable (default: Flutter's `LicenseRegistry`); loading, empty and failed loads each show an `OperationalState`, a failure with a Retry key, never a blank page. Back and Retry are mouse keys: no focus, and Enter or Space never activates them. `onBack` is a plain callback, so the owner guards or flushes a pending edit before leaving; null greys Back. A late load result after disposal or after the loader changed is ignored. Replaces `LicensesDialog` in production in phase 4.
Use for: the Help > Licences page of the database shell. Not for: dialogs (`EraDialog`) or editable text.
API: LicencesPage(onBack:, loader: loadRegistryLicences, title: 'Licences') with LicenceEntry(packages:, text:) and typedef LicenceLoader = Future<List<LicenceEntry>> Function(). A different `loader` function reloads, so pass a stable one.
Gallery: shell/licences_page · Goldens: test/ui/goldens/shell_licences_page.png

### TabStrip · shell/tab_strip.dart · new
A row of tabs selected by id, in two sizes: area tabs (24 px, active 27) and subform tabs (20 px, active 22). The active tab has an amber top edge, a hovered enabled tab shows it too, and a disabled tab keeps its place with a greyed icon and label and its reason as tooltip and semantics hint. An optional count badge follows the label. Selection is controlled: a tap on an enabled, unselected tab only calls `onSelect(id)`; the owner flushes its editor and then supplies the new `selectedId` (or refuses by not doing so). Duplicate ids throw; an empty list or an unknown/null `selectedId` paints no active tab and never indexes; `TabStrip.resolveSelection` picks the id to select after tabs change. Tabs take no keyboard focus (mouse and assistive activation only). Labels wrap within the width with full semantics; tabs wrap onto further rows; the trailing caption sits at the right when it fits and otherwise takes its own line above, wrapping.
Use for: area tabs of the frame and the tabs over a subform. Not for: keyboard-operated tabs or commands.
API: TabStrip(tabs: [TabItem(id:, label:, icon:, enabled: true, disabledReason:, tooltip:, count:, countLabel: 'waiting')], selectedId:, onSelect: (id) {}, size: TabStripSize.area | TabStripSize.subform, trailing:); static TabStrip.resolveSelection(tabs, selectedId) -> String?
Gallery: shell/tab_strip · Goldens: test/ui/goldens/shell_tab_strip.png

## Next

Phase 2 is complete: the widgets above are available and the gallery runs
on `AppFrame`, `TreeView` and `PropertyGrid` (tree by folder, demo in the
middle, knobs in the property grid). Next is phase 3 (`lifeManager-9pk.3`):
the new shell and edit session in an integration harness. Production keeps
the old shell until phase 4.

## Not in the library

`lib/shared/shell/` is the old shell (task pane, address bar, Books tree,
desks, menu bar, status line, shell dialogs). It is replaced in phases 2–4
and deleted in phase 5. Do not build on it.
