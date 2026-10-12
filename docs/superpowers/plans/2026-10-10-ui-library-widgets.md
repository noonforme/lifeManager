# UI Library Widgets (Phase 2a) Implementation Plan

**Status:** Reviewed and revised 2026-10-10; implementation pending.

**Goal:** Build the database shell's domain-free widgets in `lib/ui/`, with interaction tests, synthetic and real-font gallery goldens, and catalog entries. Production retains its current shell and behavior.

**Authority:** `docs/superpowers/specs/2026-10-08-database-shell-and-ui-library-design.md`, especially sections 3, 4.1–4.7, 5–7 and 10. `DESIGN.md` remains the visual reference; the new spec overrides its legacy keyboard and navigation rules only in the new hosts. Read `AGENTS.md`, `lib/ui/CATALOG.md` and `.agents/skills/lifeos-ui/SKILL.md` before implementation. Use Beads for progress, not checkboxes or an unavailable execution skill.

**Tracking:** `lifeManager-9pk.2` owns the whole of phase 2. This document covers 2a. Gallery migration is `lifeManager-9pk.2.1` (2b); deferred foundation minors remain `lifeManager-9pk.8`. Completing 2a does **not** close phase 2 or unblock phase 3.

**Toolchain:** Repository-pinned Flutter 3.47.5 / Dart 3.13. Use installed source and current repository APIs when implementing; do not add dependencies or upgrade the SDK for this work.

## Review corrections

The previous full-source recipes were exercised in a disposable copy, including their scoped shared-control modifications. The selected control/data/shell suites finished with 119 passing and 8 failing tests. Failures included a narrow time editor, the 260 px property column at 200% text, oversized trailing tab captions and status panels, and tests that missed the calendar/splitter hit targets or assumed touch drag movement without accounting for gesture slop. These are evidence about the original recipes, not validation of an implementation of this revision.

The tasks below replace those recipes with implementation contracts and regression cases. In particular:

- Editor drafts have an explicit flush/cancel boundary usable by Save, navigation and native close; a commit can be rejected without losing the draft.
- The keyboard policy covers focused descendants and open calendar/combo overlays, not just the outer control's key handler. Action-panel fields use the same policy and field traversal.
- Virtualisation, asynchronous selection decisions and responsive reparenting cannot silently discard or misapply an editor's value.
- Layout uses measured editor constraints, bounded descriptions and responsive wrapping. `OverflowBox` painting outside a cell is not a usable input surface.
- Properties docks as a tab beside the subform tabs, and Tree is a toolbar action, as required by section 3.
- Runtime interaction tests are authoritative. Source scans do not prove that nested controls ignore keyboard input.
- Golden checks preserve baseline PNG bytes and test exit statuses; newly generated images are visually reviewed and rerun without updating.

## Scope and shared rules

1. Changes belong in `lib/ui/`, `test/ui/`, relevant test support and gallery registration/catalog files. Do not change feature, app, bootstrap or legacy-shell behavior in 2a. Do not remove legacy widgets/tests or implement Work services, routes, persistence, repricing or the phase 3 edit session.
2. Public UI is exported through `lib/ui/ui.dart`; external consumers import that barrel. Library dependencies remain within the existing boundary guard: UI, `core/time`, `core/explain`, Dart and the already permitted Flutter/package imports. Gallery code and domain services must not leak through the public barrel.
3. Use the existing tokens, EraSans typography, painted glyphs, bevels and vertical gradients. No character glyph substitutes for selectors/arrows, font-size clamps, shadows or motion. Baseline pixel dimensions are minima at 100% text.
4. State owned by callers is controlled: selected record, sort order, picked IDs, field values, pending/error marks, enabled state and persisted layout preferences. Widgets report requests and edits; they never save domain records. Only local expansion/hover and editor presentation state may be internal.
5. `enabled`, `readOnly` and `active` have different meanings. Disabled controls produce no edits or commands. Read-only values remain selectable and explain why. `active` only controls selection paint. A row/cell may be read-only even when its column is generally editable.
6. Every new public widget has exactly one discoverable demo, a catalog entry with status `new`, and both golden variants. Non-widget models/controllers are documented with their owning widget and tested, without inventing widget demos for them. Keep helpers private unless part of the intended API.
7. Gallery fixtures are synthetic, deterministic, and use a fixed `today`; no production database, wall-clock dates or real licence registry in goldens. Enabled/error/long-text/scale knobs must affect the relevant demo. Do not make a widget pass by replacing it with a placeholder when disabled.
8. Tasks are implementation instructions, not progress records. Record completed work, test results and unresolved blockers with `bd update lifeManager-9pk.2 --append-notes='...'`. No commit, push or Dolt remote sync unless requested.

## Files and public components

| Path under `lib/ui/` | Responsibility |
|---|---|
| `controls/era_editor_host.dart` | `EraEditorHostScope`: opt-in policy for new hosts; normal or bare labels. |
| `controls/editor_session_controller.dart` | `EditorSessionController`, edit identity/value/result models; no domain state. |
| `controls/value_editor.dart` | `ValueKind`, `formatValue`, `valueEditor`: existing era controls per kind. |
| `controls/cell_editor.dart` | `CellEditor`: one registered value editor, focus, field completion and cancellation. |
| `data/record_navigator.dart` | `RecordNavigator`. |
| `data/data_grid.dart` | `DataGrid<T>`, `GridColumn<T>`, `GridLine<T>`, `GridGroup<T>`, `GridRow<T>`, `GridRowState`, `GridCell`. |
| `data/property_grid.dart` | `PropertyGrid`, `PropertyItem`. |
| `data/tree_view.dart` | `TreeView`, `TreeNodeData`. |
| `data/subform.dart` | `Subform`, `SubformTab` (the spec places Subform in `data/`). |
| `shell/tab_strip.dart` | `TabStrip`, `TabItem`, `TabStripSize`. |
| `shell/banded_toolbar.dart` | `BandedToolbar`, `ToolbarBand`, `ToolbarItem`. |
| `shell/pane_caption.dart` | `PaneCaption`. |
| `shell/splitter.dart` | `Splitter`. |
| `shell/details_box.dart` | `DetailsBox`, `DetailsSection`, `DetailsFact`. |
| `shell/status_bar.dart` | `StatusBar`, `StatusPanel`. |
| `shell/confirm_window.dart` | `ConfirmWindow<T>`, `ConfirmChoice<T>`, `ConfirmSign`, `showConfirmWindow`. |
| `shell/action_panel.dart` | `ActionPanel`, `ActionResult`. |
| `shell/licences_page.dart` | `LicencesPage`. |
| `shell/app_frame.dart` | `AppFrame`, layout preference model. |
| `gallery/demos/<name>_demo.dart` | One file per new widget demo. |

Modify shared controls only where required for scoped behavior: `era_form.dart`, `era_field.dart`, `era_date_field.dart`, `era_time_field.dart`, `era_month_calendar.dart`, `era_combo.dart`, and their existing internal popup/pressable helpers if necessary. Include those modifications in Task 1's legacy regression coverage; the original list of only four shared files was insufficient.

Tests live at `test/ui/{controls,data,shell}/<name>_test.dart`. Add behavioral `test/ui/keyboard_contract_test.dart`, a combined editor-host harness, and `test/ui/shell/app_frame_layout_test.dart`. Preserve the existing gallery/catalog/boundary test structure.

## Editor contract shared by Tasks 1, 2, 4, 5 and 10

### Draft ownership and command ordering

Use one caller-owned `EditorSessionController` for widgets that edit the same pending aggregate, including its child grid and property/action panel. It coordinates a single active field. An immutable identity includes owner/record identity and field key; a property key such as `end` alone is not enough. It must expose:

| Operation/state | Required result |
|---|---|
| Begin a field | Flush an existing different field first; begin only if that succeeds. Capture the original field value and retain the draft independently of a virtualised cell's element. |
| Draft update | Retain the current text/typed value immediately, including invalid text and text selection/composition where applicable. Do not write to a database. |
| `flush()` | Synchronously validate and offer the active value to its owner's commit callback. Return success or an error associated with that field. With no active edit, succeed without callbacks. |
| Commit accepted | Update the caller's pending record synchronously before returning; clear the field session once. Repeated flush or key-repeat is harmless. Unchanged values do not create a dirty record. |
| Commit rejected | Keep the same draft, editor and error; leave selection/navigation unchanged; allow correction and another attempt. Do not permanently mark an editor done before acceptance. |
| `cancel()` | Restore the field's value at editor entry and close it. Preserve other already accepted pending fields and child edits. |
| Identity/lifecycle | Bind callbacks to the current record and host, detach listeners on disposal, and never apply an old draft to a new record with the same property key. No callback into disposed widget state. |

The commit callback is a **UI draft acceptance** boundary, not a service save. Parse/field validation belongs to the caller or a supplied validator; aggregate validation and all asynchronous domain commands remain in phase 3. Text/number/money/duration editors must keep raw text until parsing accepts it; do not silently convert invalid input to zero, null or the old value.

Every command that may use or replace the draft must call `flush()` **before** its own action: Save, another row/cell, sort/filter, navigator, pick change, new row, property link, category/tab/tree change, action-panel primary action, menu route and normal window close. Library-local handlers enforce this ordering; external actions use the same public controller. Undo/discard and the field's Esc use `cancel()` intentionally. An invalid flush blocks the requested action; the future leave guard can explicitly discard or keep editing.

Selection is a request. The widget does not change `selectedId` until its owner supplies the accepted new value. While a future asynchronous leave guard runs, the old selection and accepted pending draft remain available. Repeated requests must not create a second active editor. If a caller refreshes/removes the record unexpectedly, retain an identifiable orphaned draft/error for explicit resolution; never silently `_clear()` it in `didUpdateWidget` or commit it to the replacement record.

Do not implement commit-on-focus-loss or a global pointer-down commit: calendar/combo overlay clicks are part of the editor, and commit-before-pick loses the chosen value. Flush on the actual outside action, after distinguishing editor-owned overlays. The controller and owning host outlive recycled rows; scrolling alone is not commit or cancel. Retain sufficient editor state to remount the same draft, and bring the next field into view before focusing it.

### Keyboard and pointer behavior

Section 4.6 is the oracle. Outside an open editor, keys do not select, expand, tick, scroll lists, operate menus or invoke commands. Mouse activation remains available. Enter/Tab commit once and advance to the next **eligible field of the same record**, without wrapping. Skip derived/read-only/disabled fields; check and choice fields are eligible too, even though their values change by mouse. At the last field close the editor, retain selection, and prevent Tab traversal into another region.

Inside text editors allow printable text, Shift for text, platform text composition, Backspace/Delete and Left/Right caret movement. Inside date/time editors also allow digit entry, separators and Up/Down part stepping. Plain Enter/Tab are handled by the host; Esc cancels the active field. Shift+Tab, command chords, F-keys, Page Up/Down and unlisted navigation keys have no application effect. Modified Enter/Tab must not accidentally commit. Test composition so accepting an IME candidate does not prematurely advance fields; retain normal character entry, including layouts using AltGr.

Date calendars and choice popups open **and operate** by mouse. Hosted date Enter/Space/Alt+Down never opens a calendar. Once an overlay is open, arrows/Space/Enter cannot pick a day/item or move its menu focus. Enter/Tab may close the overlay and complete the current draft under the host contract, without accepting a highlighted item; Esc closes both overlay and field while restoring the entry value. A mouse pick updates the draft and returns focus to its editor, with no premature commit.

A parent `Focus.onKeyEvent` runs after a focused descendant has had a chance to consume an event. Returning `ignored` from a combo face handler also permits other handlers/default actions to run. Apply suppression at the relevant hosted control/overlay handlers or an equivalent scoped interception point, and prove it with runtime tests. Preserve every legacy caller outside the scope. Do not use a blanket `ExcludeFocus` around editable content; exclude mouse command buttons and popup choices as appropriate while keeping the actual editor focusable.

## Task 1: Scoped shared-control behavior

**Files:** `controls/era_editor_host.dart`, the shared controls listed above, `test/ui/controls/era_editor_host_test.dart`, its demo, exports and catalog.

1. Add `EraEditorHostScope(child:, bare: false)` with a non-dependent lookup usable from event handlers and a dependent lookup for label/layout changes. The scope is opt-in and does not by itself turn an ordinary form into a complete editor sequence.
2. `EraLabelled` omits the separate label only when bare; retain semantic names, errors, enabled state and sufficient usable editor width. Read the actual `EraFieldWidth` and shared-control padding instead of assuming the painted value alone is the required width.
3. Apply the keyboard matrix to the date/time box, the **open** month calendar, combo face and **open** menu rows, checkbox/radio activation and text field actions. Modifier checks happen before time stepping; otherwise Alt+Up can still alter a value. Keyboard suppression must not stop mouse popup navigation, selection or text composition.
4. Keep default label and interaction behavior outside the scope byte-for-byte compatible where no intended visual change occurs.

**Regression tests:** legacy date Enter opens a calendar; legacy time Page Up still steps; labels remain outside/bare=false and disappear only for bare=true; hosted Enter/Space/Alt+Down do not open a calendar; hosted Page Up/Down and modified arrows do not change time; mouse opening/picking works; mouse-opened calendar and combo cannot be operated by banned keys; disabled scoped and legacy controls do not change. Use an actual pointer on the calendar's drop arrow, not the centre of `EraDateField`, which can select a date part. Scope a day finder to the popup and intended month instead of choosing an arbitrary `.last` match.

**Validation:** focused scoped tests plus existing control and production interaction tests. Inspect unchanged shared-control goldens without updating.

## Task 2: Value adapters, editor controller and CellEditor

**Files:** `controls/editor_session_controller.dart`, `controls/value_editor.dart`, `controls/cell_editor.dart`; corresponding tests; `cell_editor_demo.dart`; exports/catalog.

1. Implement the shared editor contract above before either grid. `CellEditor` accepts the controller, stable edit identity, field order/next-field callback and `bare` mode (true for cells, false for labelled action forms). Registration and disposal cannot leave dangling callbacks or reset another field's draft.
2. Retain `ValueKind.text`, `number`, `money`, `duration`, `date`, `time`, `choice`, `check`; numeric kinds align right and use tabular figures, date/time use figures, text aligns left. `formatValue` renders null empty, date/time with existing helpers, check Yes/No and choices by label. Callers can supply display text for amounts/durations; the library does not invent currency/rounding rules.
3. `valueEditor` reuses `EraField`, `EraDateField`, `EraTimeField`, `EraCombo` and `EraCheckBox`. Require explicit fixed `today` for dates. Controlled adapters rebuild with current draft values for date/time/choice/check; changing only a private `_draft` without rebuilding a controlled child is insufficient. Text controllers keep selection/composition and do not overwrite typing on unrelated rebuilds.
4. Enter/Tab/next is accepted only after flush success. Focus the next mounted eligible editor after scrolling it into view. Esc cancels only this field. Do not cache a permanent `_done` on a rejected commit. Mouse check toggling follows the same eligibility/validation path and cannot bypass disabled/read-only policy.
5. Expose flush/cancel to the future shell; do not access private grid State with a `GlobalKey` from feature code. The controller contains no database, service, navigation or asynchronous save policy.

**Tests:** controller lifecycle/idempotence, unchanged flush, reject-correct-retry, invalid numeric text retention, all kinds, controlled date/time/choice repaint, next-field skipping including checks, last-field closure, keyboard matrix, IME, mouse calendar pick then Enter, Esc after a pick, and disposal with an overlay open. A synthetic toolbar Save callback must observe the newly typed text on the first click; rejection must prevent that callback. A grid and property editor sharing the controller must not hold conflicting drafts.

## Task 3: RecordNavigator

**Files:** `data/record_navigator.dart`, its tests/demo, exports/catalog.

Retain `position`, `count`, nullable `onGo`, `onNew`, `label` and `note`. Position is one-based, or zero when no record is selected; empty data shows `0 of 0`. Assert sensible input bounds. A null callback disables the relevant navigation action, including the navigator inside a read-only/unselectable grid.

Paint first/previous/next/last/new glyphs. Show the position as a read-only sunken number, not an implicit text editor. First/last are disabled at their endpoints; previous at position <=1; next when position >= count; empty data disables all record moves. New is enabled only when supplied and permitted by the form scope. Long filter notes wrap; the navigator must have a finite intrinsic width inside its parent, with no child expanding accidentally to infinity.

**Tests:** zero/one/many records, no selection, endpoints, disabled callbacks/form scope, click targets, no keyboard activation or traversal, long note at narrow width and 200% text. Assert every emitted target is within `1..count`.

## Task 4: DataGrid

**Files:** `data/data_grid.dart`, `test/ui/data/data_grid_test.dart`, a shared-editor integration test, its demo, exports/catalog.

**API:** Keep typed columns, group and record lines, stable `rowId`, controlled `selectedId`, selection request callback, accepted-edit callback, `today`, pending IDs, changed cells, cell errors, new-row callback, sort state/callback, footer values, pick mode/IDs/callback, baseline column widths/resize callback, optional navigator and filter note. Add the shared `editorController`, enabled state and a per-row/per-cell editability/reason predicate. Column-wide `editable` alone cannot protect finalized or otherwise read-only rows. Model the return value of draft acceptance explicitly; `void onEdit` cannot report rejection.

1. Paint bevelled sortable/resizable headers, sorted-column tint and ascending/descending indicator, group heading/summary, selector marks (current/pending/new), muted/voided rows, changed-value weight, red error edges and caller-supplied totals. Preserve readable semantics for row selection, pending changes, check state and errors.
2. Selection remains controlled. First click selects an unselected row; clicking an editable cell of the selected row opens it. Selector, header, navigator, pick checkbox and new-row actions flush first. Header resize must preserve the draft and clamp to the actual editor minimum. Read-only cells show their reason without opening an editor.
3. Use lazy row building with stable keys on the **list item root**, stable child-index lookup after reorder, and editor state outside recyclable row elements. Reordering/filtering cannot attach state to a different row. Avoid repeated full-list searches per built cell; construct row/index lookups once per input update.
4. Keep header, rows and totals horizontally aligned with shared widths. Horizontal and vertical scroll controllers have one position each, are disposed, and work under the real `EraScrollBehavior`. The horizontal scrollbar's parent must have a finite height; nested scrolling cannot put the era scrollbar's flex layout under unbounded constraints.
5. Editor width includes its full control chrome/padding and scales with text. Enforce usable minima during drag/restore and scroll the table horizontally. Do not place interactive editors in an `OverflowBox` over the following cell: painted overflow does not enlarge hit testing and the adjacent cell can intercept the click. Rows must fit the editor and error presentation without clipped hit targets. Avoid `IntrinsicHeight` around descendants that use `LayoutBuilder`; measure or lay out using finite constraints instead.
6. Enter/Tab advances across eligible columns in the same row, including check/choice, and then closes. Ensure horizontal visibility before focus. Scrolling the row offscreen and back preserves the raw draft and cancellation baseline. A selected-row removal or caller refresh uses the explicit resolution contract, never a silent clear.
7. Pick mode adds a painted tick column and count. Add per-row pick eligibility so unavailable records cannot be selected by the widget. The caller owns the picked set and filtered/picked totals; it must receive no pick callback when disabled. Keep selected record and picked records distinct. The synthetic demo recomputes its footer from its picked records so this path is observable.

**Tests:** rendering and semantics; controlled selection accepted/refused/delayed; row-specific read-only and disabled behavior; complete edit/validation keyboard sequence; Save outside grid; switching to properties; sort/filter/new/navigator while typing; two rapid requests; offscreen draft recovery; stable identity after sort/remove/reinsert; 5,000 rows with only viewport/cache rows built; horizontal overflow at 200%; minimum column drag; popup hit targets; eligible/ineligible picks and recomputed totals. Test with actual editor widgets and era scroll behavior, not only text cells.

## Task 5: PropertyGrid

**Files:** `data/property_grid.dart`, its tests/demo, shared-editor harness, exports/catalog.

**API:** `PropertyItem` retains key, label, category, kind, value/display, read-only reason, previous display (`was`), description, choices, `onFollow` and error; add enabled state. `PropertyGrid` takes record identity, controller, items, synchronous draft acceptance, fixed today, active state and initial ordering. Bind edit identity to record plus property key.

1. Render collapsible categories or A–Z, a selected name cell, kind-specific in-row editor, muted read-only values/reason, changed `(was …)` display, follow links and a description pane. Surface the selected property's validation error before its read-only reason/description. Sorting changes only display order, not identity.
2. Flush before another property, category collapse, sort-mode change or link. A refused flush keeps the active field/category visible. Commit acceptance may alter derived values or eligibility; calculate the next field from the refreshed caller data, not the pre-commit object snapshot. Keep all previous pending fields when Esc cancels just the active one.
3. Measure the available width after borders and scrollbar. At 260/306 px and 200% text, a fixed `128 * scale` label leaves no room for values. Clamp label allocation and stack labels above editors when the label plus minimum editor width will not fit. If even the editor minimum exceeds available width, provide a bounded horizontal scroll region with reachable controls and error text; do not shrink the font.
4. Bound the description pane's height relative to the available region and scroll its full contents. Long errors cannot consume the field list or make Save/Cancel unreachable. Fit editor/error rows without relying on intrinsic sizing of `LayoutBuilder` descendants.
5. A record change must not reuse a text controller, draft, category selection or error for a same-named property of another record. Resolve the active field before replacement, including when the parent swaps the widget's key.

**Tests:** categorized/A–Z and collapse; every value kind; read-only reason and links; reject-correct-retry; next skips disabled/read-only but includes eligible checks; no wrap; external flush/cancel; record A→B with identical property keys; long description/error scrolling; real date/time/choice editing at 260 and 306 px, 100/200% text; popup selection; disabled form scope; no keyboard actions outside the editor.

## Task 6: TreeView

**Files:** `data/tree_view.dart`, its tests/demo, exports/catalog.

Use immutable `TreeNodeData` with unique stable id, label, icon, count, children, warning, muted, bold and initial expansion. Separate `enabled`/selectability from muted paint: ended employments can be muted yet still selectable. `TreeView` takes controlled selected ID, selection callback, active/enabled state and optional expansion-change reporting.

Paint dotted connectors and expand/collapse boxes, 16 px icons, counts and warning ink. Selection and expansion are mouse-operated. Honour initial expansion once per newly encountered ID, prune removed IDs to avoid stale state, and validate uniqueness. Use lazy rows for the flattened visible nodes, wrapping/truncating labels with a full accessible name without unbounded indentation overflow. Expose or support a bounded content-height mode so the tree cannot consume the Details box's space in AppFrame.

**Tests:** selection request without automatic acceptance; expansion separate from selection; new/removed/reinserted IDs; deep/long labels and counts at 200%; disabled nodes; warning/muted semantics; no keyboard selection, expansion or scroll navigation; large tree builds only visible rows. Shared harness verifies a tree request cannot bypass a rejected editor flush.

## Task 7: TabStrip and Subform

**Files:** `shell/tab_strip.dart`, `data/subform.dart`, tests for both, two demos, exports/catalog.

`TabItem` and `SubformTab` have stable IDs; selection is controlled by ID, not a fragile list index. Retain label/icon/enabled/tooltip/count and subform content builder. Validate unique IDs, handle empty tabs explicitly, and reconcile a removed selected tab without indexing an invalid position. Disabled tabs retain their place and explain why.

Area tabs use 24/27 px baseline minima; subform tabs 20/22. Paint the active amber edge, hover edge and disabled icon. Tabs and trailing caption must both receive bounded width. Wrap or move the caption onto a separate line when it competes with tabs; a non-flex trailing `Text` in a `Row` can take the entire width. A single oversized tab label also needs bounded wrapping, with full semantics.

Subform places the tabs over a bounded bordered content region and accepts the controller/guard contract for tab changes. Retain active editor state when switching tabs or moving the property content into the dock; do not depend on an unkeyed builder to preserve record identity. Keep nonvisible content free of keyboard focus. Support the Properties/action-panel tab required by Task 11.

**Tests:** empty/removed/reordered/disabled tabs, counts, controlled refusal, long caption plus long tabs at 200%, no keyboard navigation, child state identity, and edit→change subform→return with both accepted and rejected flushes. Verify actual caption/tabs remain visible and hit-testable.

## Task 8: BandedToolbar, PaneCaption and Splitter

**Files:** the three `shell/` files, focused tests, three demos, exports/catalog.

**BandedToolbar:** retain banded `ToolbarItem`s with label, icon, nullable callback, tooltip, optional icon-only presentation and drop arrow. Use painted grippers and etched separators; enabled actions have hover/pressed paint, unavailable actions stay grey in place. No keyboard activation. Add a Tree action supplied by AppFrame when folded. All supplied command callbacks use the common flush ordering where they depend on a draft. A Find editor is an explicit hosted editor, not a keyboard shortcut.

Wrap both between and **within** oversized bands; one wide `Row` inside a `Wrap` still overflows. Measure/reflow the trailing slot too, rather than letting it take unbounded width. Keep Save and Undo reachable at 800×600/200%. Test the full toolbar, not a single short button.

**PaneCaption:** icon, title, optional trailing content and close key. Bound title/trailing widths; wrap when needed while keeping Close visible. Give every icon-only action a semantic label and mouse hit target. A caller cannot smuggle keyboard-active command buttons through a trailing slot; document and exercise the slot contract.

**Splitter:** a 5 px hit region with the proper resize cursor, axis-specific drag deltas and end callback; no keyboard interaction. The parent applies/clamps/reports layout. Fill the cross axis explicitly and use mouse drag behavior that accounts for the initial pointer movement. Tests must use `PointerDeviceKind.mouse`, a hit-testable bounded splitter, and several move events with pumps; do not accept a missed hit or confuse Flutter touch slop with resizing logic. Dragging far past either clamp, then back, must be reversible.

**Tests:** disabled controls/form scope, tooltip and semantic labels, mouse pressed/cancelled states, full long toolbar/Find at 100/200%, caption close reachability, both splitter axes, applied geometry matching reported values, and no keyboard actions.

## Task 9: DetailsBox and StatusBar

**Files:** the two `shell/` files, focused tests, two demos, exports/catalog.

**DetailsBox:** caption, sections, optional section titles, label/value facts, follow links and warnings separated by rules. Needs bounded height and independent scrolling. Labels and values wrap at 200%; long values do not hide the label. Links are mouse-operated and use guarded callbacks. Display text comes from the caller; there is no domain calculation.

**StatusBar:** last notice/pending summary, caller-supplied sunken panels, warning text and painted size grip. Reflow according to actual text/available width, not just a fixed 640 px breakpoint. In a wide layout, several unconstrained panels can still exceed the width at 200%. Give each panel finite constraints; wrap panels and long notices and cap/scroll an unusually long notice so the bar cannot consume the entire AppFrame. The size grip must not expand to fill an unbounded row. Document whether it is decorative; actual native-window resize integration belongs to the shell phase.

**Tests:** facts and link callbacks, independent scroll, warning semantics, long notice and several totals at 640/800/1280 and 100/200%, no flex overflow, bounded status height in the full frame, and no keyboard navigation into links/commands.

## Task 10: ConfirmWindow and ActionPanel

**Files:** the two `shell/` files, focused tests, two demos, exports/catalog.

**ConfirmWindow:** retain typed choices, title, message and warning/info sign. Validate two or three choices; affirmative is first. Make the cancellation result explicit (`cancelValue` or a designated cancelling choice), rather than silently assuming an arbitrary last choice is safe. Closing the caption chooses cancellation. When disabled, both choices and close are disabled in behavior and paint.

`showConfirmWindow` creates a modal, mouse-operated route with a non-dismissible barrier and no animation/shadow. Prevent keys from reaching underlying editors or activating choices; barrier taps do nothing. Capture the caller's skin/theme correctly across the route boundary and retain a Material/text-style context. Native application close remains phase 3's responsibility. Reuse the era dialog/caption visuals, but constrain the confirmation to available screen height/width, with wrapped choices and a scrollable message if needed. No form fields. Do not nest movable dialogs or rely on an unbounded-height demo host.

**ActionPanel:** title, scrollable group-box form, result/error rows, primary verb and Cancel pinned below the scroll region. Keep `title`, labelled `children`, `primaryLabel`, callbacks, results and busy state; add the shared editor controller and explicit ordered field registrations. Form fields use `CellEditor(bare: false)` or the same registered host adapter. Merely wrapping children in `EraEditorHostScope` does not implement Enter/Tab/Esc or last-field behavior.

Every editable child registers a stable ID, current value/validator and ordered eligibility. Enter/Tab advances among those fields and then closes the final editor; it never invokes the primary action. Esc rolls back just the field. Mouse primary flushes before callback; invalid input blocks it. Cancel explicitly cancels the editor before reporting the panel cancellation request to the owner. Prevent repeated submissions and lock **fields, pick changes and buttons** while busy; disabling only the footer leaves an in-flight request's input mutable. Already completed bulk results remain visible and unchanged on a later failure.

**Tests:** confirmation choice order/cancel/close, disabled close, modal barrier, all banned keys with an underlying focused editor, inherited skin and two/three long choices at 800×600/200%; panel actual text/date/time/choice/check fields, next/last/Esc, primary flush failure, busy field immutability, single callback, partial results, tall form/result lists and pointer-reachable footer. Gallery fixtures use bounded sizes and synthetic outcomes.

## Task 11: LicencesPage and AppFrame

**Files:** the two `shell/` files, `licences_page_test.dart`, `app_frame_layout_test.dart`, two demos, exports/catalog.

**LicencesPage:** injectable async loader (default Flutter `LicenseRegistry`), title and guarded Back, read-only package/font licence text. Implement loading, empty and failure/retry states with existing `OperationalState`; a failed loader must not silently show a blank page. Render long lists lazily and keep Back reachable. The gallery uses fixed synthetic entries and no live registry. Tests cover success, failure/retry, empty, long text at 200%, no completion updates after disposal and keyboard-inert Back.

**AppFrame:** menu, banded toolbar, area tabs, three-column page, grid/subform splitter, status. Baseline left/right widths 196/306, subform height 168, 5 px splitters. Accept stable pane identities, caller-owned layout preferences and callbacks for left/right width **and subform/dock height**; the owner persists them per area. Store/report baseline logical dimensions and apply scaling exactly once. Changing the supplied area/preferences must update the frame; a permanent local `_left` override must not mask restored preferences.

The composition API must make responsive behavior possible without two property instances: provide the toolbar with a folded-Tree action and let the middle/subform composition receive the same property/action-panel content as a dock tab. For example, use `toolbarBuilder(context, treeAction)` and `middleBuilder(context, dockedPropertyTab, layout)` slots, or equivalent typed slots. The contract is one property editor/controller, stable identity and shared tab selection/guarding. Document slot requirements in the catalog and demonstrate the whole composition.

1. At sufficient width show all three columns. Below **client width** 1024 fold the left into the toolbar Tree action and narrow the property column toward 260 px. Check breakpoints before subtracting internal padding; exactly 1024 must not fold solely because page padding reduces its inner width. Fold earlier when measured/scaled minima cannot fit.
2. Tree opens a bounded overlay anchored to its toolbar action; give it explicit mouse close/outside-dismiss behavior. Keep Details reachable under a capped tree region. Switching views uses the editor guard.
3. Below client width 860, or whenever the scaled minima cannot fit beside the grid, Properties becomes a tab **beside the subform tabs**, sharing the resizable lower region. An action panel occupies that same property tab. Do not replace this with an always-visible second property pane underneath the grid. Selecting the tab reveals the current editor/error/footer.
4. Preserve active draft, tab identity and scroll positions across folding/docking and area restoration. Reparenting must not call commit/cancel or throw away the focused editor. Keep only visible panes focusable. If geometry changes hide the active region, reveal its dock tab through controlled selection.
5. Clamp restored widths/heights to the space actually available after measured chrome, splitters and minimum usable grid/content regions. Include extreme restored values and shrinking height. A fixed `max(120, height-160)` can still exceed a small page. When chrome is too tall, bound/scroll its region while retaining access to commands/footer; never shrink text or silently clip it.

**Layout matrix:** client sizes 1280×800, 1024×768, 960×700, 860×650, 800×600 at 100% and 200%; also 1023/1025 and 859/861 widths. Use the real toolbar with Save/Undo/Find, long area/subform tabs, Tree/Details, DataGrid, PropertyGrid, error descriptions, StatusBar and ActionPanel, not fixed-height placeholder boxes. Start an edit and resize through every transition. At each size open every editor/popup, reveal errors, click Save/Undo, and reach action-panel primary/Cancel. Assert hit testing/visibility as well as absence of framework exceptions. Test mouse splitters and restored per-area preferences at both scales.

## Task 12: Gallery coverage, guards and 2a gate

### Demos and catalog

Register all new demos in `lib/ui/gallery/gallery_demos.dart`, sorted by folder/id. The intended new-widget demo map is:

| Widget | Demo ID |
|---|---|
| EraEditorHostScope | `controls/era_editor_host_scope` |
| CellEditor | `controls/cell_editor` |
| RecordNavigator | `data/record_navigator` |
| DataGrid | `data/data_grid` |
| PropertyGrid | `data/property_grid` |
| TreeView | `data/tree_view` |
| Subform | `data/subform` |
| TabStrip | `shell/tab_strip` |
| BandedToolbar | `shell/banded_toolbar` |
| PaneCaption | `shell/pane_caption` |
| Splitter | `shell/splitter` |
| DetailsBox | `shell/details_box` |
| StatusBar | `shell/status_bar` |
| ConfirmWindow | `shell/confirm_window` |
| ActionPanel | `shell/action_panel` |
| LicencesPage | `shell/licences_page` |
| AppFrame | `shell/app_frame` |

Use catalog format `### Name · folder/file.dart · new`, followed by purpose, `Use for: … Not for: …`, accurate API and `Gallery: <id> · Goldens: test/ui/goldens/<id_with_underscores>.png`. Model/controller APIs live with the relevant entry. Update the jobs table: lists→DataGrid, facts→PropertyGrid, children→Subform, form actions→ActionPanel, confirmation→ConfirmWindow, licences→LicencesPage, layout→AppFrame. Keep deprecated widgets/catalog entries while their legacy consumers or temporary gallery composition still exist.

Derive expected widget/demo/golden counts from the actual inventory. Do not hard-code 61 when an implementation may introduce a justified public helper. Require exactly one entry/demo and both image files per public widget. Extend knob coverage to **all** new demos, including data/shell; callback counters must prove Enabled off prevents action, not merely detect nullable `KeyButton` callbacks. Verify disabled painting and hover/pressed states visually.

### Behavioral guards

`test/ui/keyboard_contract_test.dart` mounts the actual new widgets with era scroll behavior and tests closed editors, active editors, open overlays, blurred/closed editors and confirmation routes. Exercise Tab/Shift+Tab, Enter/numpad Enter, Esc, arrows, Space, Home/End, Page Up/Down, F2/F4 and Ctrl/Alt/Meta command chords. Assert values, selection, scroll positions, callbacks and focus destination, not only a lack of exceptions.

Retain useful source guards for library boundaries; do not claim `source.contains('ExcludeFocus(')` proves every button is excluded or prohibit necessary internal focus containment. Controls may own focus machinery to suppress keys while remaining mouse-operated. Runtime behavior is the acceptance criterion.

### Verification commands and golden policy

Run from the repository, preserving unrelated changes. Before implementation record Git status and hashes of existing PNGs in a temporary baseline outside the repository. Use the same shell for these commands:

```bash
set -euo pipefail
export FLUTTER="$HOME/.local/opt/flutter-3.47.5/bin/flutter"
export DART="$HOME/.local/opt/flutter-3.47.5/bin/dart"
UI_BASELINE_DIR=$(mktemp -d /tmp/lifeos-ui-widgets-baseline.XXXXXX)
export UI_BASELINE_DIR
git status --short
python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
paths = sorted({p for root in ('test/goldens', 'test/ui/goldens')
                for p in Path(root).rglob('*.png')})
baseline = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
(Path(os.environ['UI_BASELINE_DIR']) / 'goldens.json').write_text(json.dumps(baseline))
print(f'Recorded {len(baseline)} existing PNGs')
PY
```

Within each task, write the focused failing regression, implement, format the files touched and run the focused tests. After adding a demo, create **only its** two goldens. For example:

```bash
"$FLUTTER" test --update-goldens --plain-name data_data_grid test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font --update-goldens --plain-name real_font/data_data_grid test/ui/gallery/gallery_real_font_test.dart
"$FLUTTER" test --plain-name data_data_grid test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font --plain-name real_font/data_data_grid test/ui/gallery/gallery_real_font_test.dart
```

Inspect each synthetic and real-font image before accepting it, including representative enabled/disabled, selected, pending/error and open-editor/popup states. Add focused variants where the default golden cannot show those states, with separate names and targeted generation. Increasing the standalone demo canvas cannot replace the real-width layout tests. Run `test/ui` and `test/repository` after each complete widget/demo/catalog task; a known future demo's absence is not a reason to disable the guard.

Production PNGs must keep their baseline bytes in 2a. Existing gallery PNGs should stay unchanged unless an intentional shared-control/demo correction requires a specifically named, visually reviewed change under spec section 7. Never bulk-update either suite. Verify all unaffected baseline images; if an intended gallery image changes, report its path/reason and compare it explicitly rather than overwriting the original baseline. New images are allowed and are covered by inventory/tests.

```bash
"$FLUTTER" analyze lib test tool
"$DART" format --output=none --set-exit-if-changed lib test tool
"$DART" run tool/schema_check.dart
"$FLUTTER" test --reporter expanded
"$FLUTTER" test test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font test/ui/gallery/gallery_real_font_test.dart
python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
baseline = json.loads((Path(os.environ['UI_BASELINE_DIR']) / 'goldens.json').read_text())
changed = [name for name, digest in baseline.items()
           if not Path(name).exists()
           or hashlib.sha256(Path(name).read_bytes()).hexdigest() != digest]
print('Changed baseline PNGs:', changed)
assert not changed, 'Review each named change; production PNG changes fail phase 2a'
PY
git diff --check
git status --short
```

The default hash gate deliberately fails on any changed baseline PNG. For a justified gallery-only correction, keep the original manifest and rerun the comparison with an explicit reviewed gallery-path allowlist, still failing on every production or unexplained change. Record that exception and its visual comparison in Beads. Git cleanliness alone cannot prove byte preservation, and Dart test-file changes under `test/goldens/` do not by themselves mean an image changed.

Do not pipe test/check commands into `tail`, `head` or `grep` and infer success from the last tool's status. If saving logs, preserve the original exit status (`pipefail` with `tee`, or redirect to a file and check the command result). Do not weaken failing matchers, suppress hit-test warnings or accept errors with blanket golden regeneration.

### 2a completion and 2b handoff

Open `./app.sh` option 5, exercise the new demos, toggle all knobs, and test at 800×600/200%. Close normally. For the full phase 2 completion gate, also run the launcher tests/checks and production smoke start/normal close as specified by section 7; preserve existing data and do not enter mutations merely to smoke-test startup. Direct commands above provide unmasked diagnostics.

Record implemented APIs, targeted regression results, golden paths/reviews and any remaining work in `lifeManager-9pk.2`. Leave that feature open. The catalog's Next section must say that the widgets are available but gallery migration and deferred minors remain; do not claim phase 2 is complete.

The required 2b work in `lifeManager-9pk.2.1` is concrete:

1. Replace temporary gallery navigation/layout/knobs with AppFrame, TreeView and PropertyGrid using the editor controller. Preserve synthetic-only startup, selected-demo state isolation and knob updates. Remove the old composition while retaining any shared theme/test wrapper still required by tests.
2. Complete `lifeManager-9pk.8`: validate job-table/Foundation names and catalog section boundaries; correct the real-font skip instructions and required-parameter API descriptions; forbid barrel exports of gallery code and cover `lib/core`/`lib/bootstrap.dart` in boundary tests; show the combo's open list in a dedicated golden; cover data/shell knob combinations. Recheck which minors were already addressed by 2a and close only verified work.
3. Review and update only intentionally affected gallery goldens; rerun both suites without updating and all phase gates. Confirm every new demo still works in the new gallery shell at the full scaling matrix.
4. Close `lifeManager-9pk.2.1`, then `lifeManager-9pk.2`, only once both sets of acceptance criteria hold. Phase 3 remains dependent on that completed phase 2 gate. Commits and sync remain subject to the active repository policy.
