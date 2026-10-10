# LifeOS UI Library Catalog

The reusable era workbench lives in `lib/ui/` in phase 1. The retiring shell
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
  retain for existing screens. Phase 1 gallery hosts, demos and compatibility
  tests may use them until their replacements exist; new feature screens
  should use the replacement once available.
- **Folders:** `foundation/` tokens, type, theme, icons, dates;
  `controls/` keys, fields, pickers, menus; `data/` lists and states;
  `shell/` windows and page parts.

## Which widget for which job

| Job | Use | Not |
|---|---|---|
| A list of records | `DataRegister` (until `DataGrid`, phase 2) | hand-built `Table`/`ListView` rows |
| A record's facts | `InspectorFacts` today; `PropertyGrid` from phase 2 | free `Text` columns |
| An action the owner presses | `KeyButton` (`KeyKind.primary` first) | Material buttons, `GestureDetector` on text |
| A toolbar action | `KeyButton(kind: KeyKind.toolbar)` with an `Orb` or `EraIcon` | icon-only keys without a label |
| Step through periods or days | `StepKey` | arrow characters in text |
| A labelled form row | `EraLabelled` inside an `EraFormScope` | labels floating on the border |
| Free text | `EraField` | `TextField` directly |
| A date | `EraDateField` (`EraMonthCalendar` alone when inline) | Material date pickers |
| A time | `EraTimeField` | text fields parsed by hand |
| A choice of a few | `EraRadioGroup` (`EraRadio` for one-offs) | a combo with two items |
| A choice of many | `EraCombo` | Material `DropdownButton` |
| Yes or no | `EraCheckBox` | Material `Checkbox`/`Switch` |
| Group related fields | `GroupBox` | cards, shadows |
| Separate blocks | `EtchedLine` | `Divider` |
| A drop-down menu | `EraMenuButton`; rows drawn by `EraMenuLabel` | Material `PopupMenuButton` |
| A right-click menu | `EraContextMenu` | Material menus |
| Tabs on a sheet | `PropertySheetTabs` (until `TabStrip`, phase 2) | Material `TabBar` |
| A loading, empty or failed sheet | `OperationalState` | a bare spinner |
| An icon | `EraIcon`; small marks `EraGlyph` | font glyphs (a test forbids them) |
| A count waiting on the owner | `CountBadge` | coloured text |
| An area marker | `AreaKey` | letter squares |
| A window | `EraDialog`, only for confirmations (spec 4.7) | forms in windows |
| A custom scroll area | automatic through `EraScrollBehavior`; `EraScrollbar` only when drawing one yourself | Material `Scrollbar` |

## Foundation

Non-widget foundations, all exported by `ui.dart`:

- `LifeOSTokens`, `LifeOSArea` (`foundation/lifeos_tokens.dart`): the colour tokens and the four areas.
- `MillenniumColors`, `lifeOSTypography`, `LifeOSPainters`, `InsetRings`, `DottedFocusRectangle` (`foundation/millennium_style.dart`): named era colours, type and decorations.
- `LifeOSSkinData`, `LifeOSTypography`, `KeyKind`, `KeyState`, `KeySurface` (`foundation/lifeos_skin.dart`): the skin a widget reads with `LifeOSSkinScope.of(context)`.
- `buildLifeOSTheme()`, `lifeOSThemeFor(skin)` (`foundation/lifeos_theme.dart`): Material theme that follows the skin.
- `EraIconKind`, `areaIcon(area)` (`foundation/era_icons.dart`).
- `eraBoxDate`, `eraWeekdayShort`, `spokenDate`, `eraMonthTitle`, `monthGridDays`, `eraMonthNames`, `eraWeekdayInitials` (`foundation/era_dates.dart`).
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
API: Orb(glyph: OrbGlyph.back, tone: OrbTone.green, size: 20)
Gallery: controls/orb · Goldens: test/ui/goldens/controls_orb.png

### EraComboFace · controls/era_controls.dart · stable
What a combo box looks like closed: a white field with the blue arrow button. The surrounding menu button supplies the behavior.
Use for: the face of a custom drop-down (`EraCombo(face:)`, `EraMenuButton`). Not for: a working combo (`EraCombo`).
API: EraComboFace(value:, minWidth: 60, focused: false)
Gallery: controls/era_combo_face · Goldens: test/ui/goldens/controls_era_combo_face.png

### ComboArrow · controls/era_controls.dart · stable
The blue drop-arrow button at the right of a combo box.
Use for: building a combo-shaped control. Not for: a stand-alone arrow mark (`EraGlyph`).
API: ComboArrow()
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
Use for: an area column or marker. Not for: area tabs (phase 2 `TabStrip`).
API: AreaKey(area:)
Gallery: controls/area_key · Goldens: test/ui/goldens/controls_area_key.png

### CountBadge · controls/keys.dart · stable
An orange count of something waiting on the owner, such as days to confirm.
Use for: counts beside a tree node or key. Not for: plain totals.
API: CountBadge(count:, semanticLabel:)
Gallery: controls/count_badge · Goldens: test/ui/goldens/controls_count_badge.png

### PropertySheetTabs · controls/property_sheet_tabs.dart · deprecated (use TabStrip, phase 2)
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
API: EraCombo<T>(items: [EraComboItem(value, label, icon:, depth:, muted:, command:)], value:, onSelected:, semanticLabel:, semanticValue:, face:, minWidth: 60)
Gallery: controls/era_combo · Goldens: test/ui/goldens/controls_era_combo.png

### EraField · controls/era_field.dart · stable
A labelled text field in the era's shape: "Label:" in the label column, then a sunken white field; the error shows under it.
Use for: free text and numbers. Not for: dates and times (`EraDateField`, `EraTimeField`).
API: EraField(controller:, label:, fieldKey:, semanticLabel:, error:, hint:, keyboardType:, maxLines: 1, autofocus: false, onSubmitted:, width: EraFieldWidth.text)
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
API: EraCheckBox(value:, onChanged:, label:)
Gallery: controls/era_check_box · Goldens: test/ui/goldens/controls_era_check_box.png

### EraRadio · controls/era_form.dart · stable
A 13 px era radio with its label and optional detail; the whole row selects it.
Use for: radios laid out by hand. Not for: an ordinary group (`EraRadioGroup`).
API: EraRadio<T>(value:, groupValue:, onChanged:, label:, detail:, focusable: true, highlighted: false)
Gallery: controls/era_radio · Goldens: test/ui/goldens/controls_era_radio.png

### EraRadioGroup · controls/era_form.dart · stable
Era radios that act as one choice.
Use for: choosing one of a few. Not for: many values (`EraCombo`).
API: EraRadioGroup<T>(options: [EraRadioOption(value, label, detail:)], groupValue:, onChanged:, direction: Axis.vertical)
Gallery: controls/era_radio_group · Goldens: test/ui/goldens/controls_era_radio_group.png

### EraDateField · controls/era_date_field.dart · stable
A date box in the era's Date/Time Picker shape: the label above a white box showing "Wed 2026-10-07" beside a blue drop arrow to the month calendar; digits can be typed into its parts.
Use for: every date value. Not for: a calendar shown inline (`EraMonthCalendar`).
API: EraDateField(label:, value:, onChanged:, today:, optional: false, error:, fieldKey:)
Gallery: controls/era_date_field · Goldens: test/ui/goldens/controls_era_date_field.png

### EraTimeField · controls/era_time_field.dart · stable
A time box in the era's Date/Time Picker shape: hours and minutes beside stacked spin arrows; parts are stepped or typed.
Use for: every time of day. Not for: durations shown read-only.
API: EraTimeField(value:, onChanged:, label:, semanticLabel:, emptyStart:, enabled: true, error:, fieldKey:)
Gallery: controls/era_time_field · Goldens: test/ui/goldens/controls_era_time_field.png

### EraMonthCalendar · controls/era_month_calendar.dart · stable
The era month calendar: the month on a blue band between ◂ and ▸, six Monday-first weeks with today circled, and a Today link.
Use for: an inline month, or the drop-down of a date box. Not for: the Work calendar sheet (`WorkCalendar`).
API: EraMonthCalendar(today:, onPicked:, selected:, onCancel:, autofocus: false, focusNode:, traceName: 'calendar')
Gallery: controls/era_month_calendar · Goldens: test/ui/goldens/controls_era_month_calendar.png

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

### DataRegister · data/data_register.dart · deprecated (use DataGrid, phase 2)
The details list: bevelled sortable headers, the sorted column tinted, blue group rows, 20 px rows, planned rows greyed, subtotals, a cell cursor and right-click row actions.
Use for: existing lists until DataGrid exists. Not for: new screens of the database shell.
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
API: OperationalState(kind: OperationalStateKind.empty, title:, message:, action:)
Gallery: data/operational_state · Goldens: test/ui/goldens/data_operational_state.png

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

## Coming in phase 2

Planned by the spec (section 6); not built yet, so not catalogued above:
`DataGrid`, `PropertyGrid`, `TreeView`, `TabStrip`, `Subform`,
`RecordNavigator`, `BandedToolbar`, `ConfirmWindow`, `LicencesPage`,
`ActionPanel`, `AppFrame`, `Splitter`, `PaneCaption`, `DetailsBox`,
`StatusBar`.

## Not in the library

`lib/shared/shell/` is the old shell (task pane, address bar, Books tree,
desks, menu bar, status line, shell dialogs). It is replaced in phases 2–4
and deleted in phase 5. Do not build on it.
