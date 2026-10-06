# Editable Property Sheets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every Work record opens as an XP property sheet: editable in place where the domain allows (employment, an unused agreement, a draft shift) with **OK / Cancel / Apply**, the same fields greyed where it does not, and a **History** tab on every sheet. The separate Edit dialogs go away.

**Architecture:** A `PropertySheetController` lives in the shell dialog layer for a Properties dialog. Editable content registers an `apply` callback and reports whether it is dirty; the dialog footer drives OK (apply then close), Cancel (close) and Apply (apply, stay). Read-only content renders the same era form fields under `EraFormScope(enabled: false)`, which every era field reads. Work routing sends every existing record's Properties to one sheet per kind; `mode=edit` keeps only the new-manual-shift case.

**Tech Stack:** Flutter 3.47.5, Dart 3.13, Riverpod 3, GoRouter 18, flutter_test.

**Spec:** Owner decisions of 2026-10-05/06 in this session (critique `.impeccable/critique/2026-10-05T16-55-02Z__lib.md`, priority issue 3), and `DESIGN.md` › Components › Properties sheet / Dialog forms.

## Global Constraints

- Era look only: EraSans 11 px, `LifeOSTokens.millennium`, `MillenniumColors`; no shadows, no motion; push buttons ≥ 75 × 24.
- Footer order on a sheet: **OK**, **Cancel**, **Apply** (affirmative first), bottom-right, 8 px from the edges.
- Apply is greyed until a field changes; OK on an unchanged sheet only closes.
- A failed save keeps the sheet open with the field errors shown; nothing is overwritten silently (mutation outcomes stay explicit).
- Domain rules are unchanged: finalized shifts are corrected by void-and-replace; an agreement used by a finished shift is read-only; periods change only through Mark reviewed; payslips only through Correct.
- Enter on a sheet presses OK unless a key inside has focus (existing rule).
- Synthetic data only in tests; run `./app.sh` options 2 and 3 at the end.

## Review Focus

1. **Cancel after typing** must discard: reopening the sheet shows the stored values, not the typed ones.
2. **Apply then Cancel** keeps the applied save (Cancel only discards unapplied edits) and Apply greys again after a save.
3. **OK with an invalid field** stays open on the field's tab with its error; it never closes on `Invalid`.
4. **A record that becomes read-only while open** (agreement gains a finished shift) shows greyed fields on the next build; Apply is greyed.
5. **Escape** behaves as Cancel on a dirty sheet (closes, discards), matching XP.

Each is pinned by a test in the task that owns the code (Tasks 2–5).

---

### Task 1: Read-only era form fields

**Files:**
- Modify: `lib/shared/workbench/era_form.dart` (EraFormScope, EraCheckBox, EraRadio)
- Modify: `lib/shared/workbench/era_field.dart`, `era_date_field.dart`, `era_time_field.dart`
- Test: `test/shared/workbench/era_form_test.dart`

**Interfaces:**
- Produces: `EraFormScope({double labelWidth = 110, bool enabled = true, required Widget child})`, `static bool EraFormScope.enabledOf(BuildContext)`.

- [ ] **Step 1: Failing test** — in `era_form_test.dart`:

```dart
testWidgets('a disabled form scope greys and locks every era field', (tester) async {
  final text = TextEditingController(text: 'Warehouse');
  addTearDown(text.dispose);
  var changed = 0;
  await tester.pumpWidget(MaterialApp(
    theme: buildLifeOSTheme(),
    home: LifeOSSkinScope(child: Scaffold(body: EraFormScope(
      enabled: false,
      child: Column(children: [
        EraField(controller: text, label: 'Name', fieldKey: const ValueKey('name')),
        EraDateField(label: 'Starts on', value: const LocalDate(2026, 10, 1),
            today: const LocalDate(2026, 10, 6), fieldKey: const ValueKey('date'),
            onChanged: (_) => changed++),
        EraTimeField(label: 'Start', value: const LocalTime(8, 0),
            fieldKey: const ValueKey('time'), onChanged: (_) => changed++),
        EraCheckBox(value: true, label: 'Night pay', onChanged: (_) => changed++),
      ]),
    ))),
  ));
  expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  await tester.tap(find.byKey(const ValueKey('date')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('era-calendar-title')), findsNothing);
  await tester.tap(find.byKey(const ValueKey('era-time-up')));
  await tester.tap(find.text('Night pay'));
  await tester.pump();
  expect(changed, 0);
});
```

- [ ] **Step 2:** Run `flutter test test/shared/workbench/era_form_test.dart` — FAIL (`enabled` not a parameter).

- [ ] **Step 3: Implement.**
  - `EraFormScope`: add `final bool enabled;`, `static bool enabledOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<EraFormScope>()?.enabled ?? true;`, include it in `updateShouldNotify`.
  - `EraField.build`: `enabled: EraFormScope.enabledOf(context)` on its `TextField` (grey fill comes from the theme's disabled input).
  - `EraDateField`: `bool get _enabled => widget.value != null && EraFormScope.enabledOf(context);` — the existing disabled path already greys the box, drop arrow and text and blocks opening; the optional check box's `onToggle` becomes null when the scope is disabled.
  - `EraTimeField.build`: `final enabled = widget.enabled && EraFormScope.enabledOf(context);` and use `enabled` everywhere `widget.enabled` is read in `build`, `_step`, `_startRepeat`.
  - `EraCheckBox` / `EraRadio`: treat `onChanged` as null when `!EraFormScope.enabledOf(context)`.

- [ ] **Step 4:** Run the test — PASS; run `flutter test test/shared/workbench` — PASS.
- [ ] **Step 5:** Commit `feat: a disabled era form scope greys and locks its fields`.

---

### Task 2: Property sheet controller and OK / Cancel / Apply

**Files:**
- Create: `lib/shared/workbench/property_sheet.dart`
- Modify: `lib/shared/shell/shell_dialog.dart` (properties footer, Enter, Escape)
- Test: `test/shared/workbench/property_sheet_test.dart`, `test/shared/shell/shell_dialog_test.dart`

**Interfaces:**
- Produces:

```dart
/// Applies a sheet's edits; true when they were saved.
typedef ApplySheet = Future<bool> Function();

final class PropertySheetController extends ChangeNotifier {
  bool get dirty;
  bool get applying;
  /// Called by editable content; null when the content is read-only.
  void attach({required ApplySheet apply});
  void detach(ApplySheet apply);
  void markDirty(bool dirty);
  /// Applies when dirty; true when there was nothing to save or it saved.
  Future<bool> apply();
}

final class PropertySheetScope extends InheritedNotifier<PropertySheetController> {
  static PropertySheetController? maybeOf(BuildContext context);
}
```

- [ ] **Step 1: Failing tests** — `property_sheet_test.dart`:

```dart
test('apply runs only when dirty and clears dirty after a save', () async {
  final sheet = PropertySheetController();
  var saves = 0;
  Future<bool> save() async { saves++; return true; }
  sheet.attach(apply: save);
  expect(await sheet.apply(), isTrue);
  expect(saves, 0);
  sheet.markDirty(true);
  expect(await sheet.apply(), isTrue);
  expect(saves, 1);
  expect(sheet.dirty, isFalse);
});

test('a failed save stays dirty', () async {
  final sheet = PropertySheetController()..attach(apply: () async => false);
  sheet.markDirty(true);
  expect(await sheet.apply(), isFalse);
  expect(sheet.dirty, isTrue);
});
```

  In `shell_dialog_test.dart`, a Properties dialog whose child is a `_DirtyField` test widget (a `TextField` that calls `PropertySheetScope.maybeOf(context)!.markDirty(true)` on change and attaches `apply` returning a configurable bool):

```dart
testWidgets('Apply greys until a change; OK applies then closes; a failed OK stays', (tester) async {
  var closed = 0;
  var result = true;
  var saves = 0;
  await tester.pumpWidget(_host(ShellDialogLayer(
    dialog: ShellDialog(title: 'Synthetic depot Properties', kind: ShellDialogKind.properties,
        onClose: () => closed++,
        child: _DirtyField(onApply: () async { saves++; return result; })),
    child: const SizedBox.expand())));
  KeyButton key(String label) => tester.widget<KeyButton>(find.widgetWithText(KeyButton, label));
  expect(key('Apply').onPressed, isNull);
  await tester.enterText(find.byType(TextField), 'Changed');
  await tester.pump();
  expect(key('Apply').onPressed, isNotNull);
  result = false;
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect((saves, closed), (1, 0));          // Review Focus 3
  result = true;
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
  expect((saves, closed), (2, 0));
  expect(key('Apply').onPressed, isNull);   // Review Focus 2
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect((saves, closed), (2, 1));          // unchanged OK only closes
});

testWidgets('Cancel and Escape close a dirty sheet without saving', (tester) async { ... });
```

  (Write the second test in full: type, press Escape, expect `saves == 0` and `closed == 1`; repeat with Cancel.)

- [ ] **Step 2:** Run both files — FAIL.

- [ ] **Step 3: Implement** `property_sheet.dart` per the interface (a single attached `ApplySheet`; `apply()` sets `applying`, awaits, clears `dirty` on true, notifies). In `ShellDialogLayer`, own one `PropertySheetController` per opened properties dialog (create in `didUpdateWidget` when a dialog opens, dispose on close) and wrap `_DialogWindow` in `PropertySheetScope`. Footer for `ShellDialogKind.properties`:

```dart
FormFooter(children: [
  KeyButton(label: 'OK', kind: KeyKind.primary,
      onPressed: sheet.applying ? null : () async { if (await sheet.apply()) dialog.onClose(); }),
  KeyButton(label: 'Cancel', onPressed: dialog.onClose),
  KeyButton(label: 'Apply',
      onPressed: sheet.dirty && !sheet.applying ? () => sheet.apply() : null),
]),
```

  Enter on the sheet's own focus runs the OK path; Escape stays `dialog.onClose`. Rebuild the footer with `ListenableBuilder(listenable: sheet, ...)`.

- [ ] **Step 4:** Run both files — PASS; run `flutter test test/shared` — PASS.
- [ ] **Step 5:** Commit `feat: property sheets have OK, Cancel and Apply`.

---

### Task 3: Employment sheet

**Files:**
- Modify: `lib/features/work/presentation/employment_agreement_forms.dart` (`EmploymentForm` sheet mode; `EmploymentHeader` → `EmploymentSheet`)
- Modify: `lib/features/work/presentation/work_screen.dart` (`_employmentHeader`, `_employmentEditor`, `_inspector` switch, `_dialogTitle`)
- Test: `test/features/work/presentation/employment_sheet_test.dart`, update `test/integration/work_dialogs_flow_test.dart`

**Interfaces:**
- Consumes: `PropertySheetScope.maybeOf`, `EraFormScope(enabled:)`.
- Produces: `EmploymentForm` builds fields only (no `DialogForm` keys) when `PropertySheetScope.maybeOf(context) != null`, attaches `apply: _applySheet` returning `outcome is Committed<Employment>`, and calls `markDirty(true)` from listeners on `_name` / `_legalLabel`.

- [ ] **Step 1: Failing test** (synthetic shell, `employment_sheet_test.dart`):

```dart
testWidgets('employment Properties edits the name in place with Apply', (tester) async {
  await pumpSyntheticShell(tester, size: const Size(1280, 800), screen: syntheticScreens['shell']!);
  await tester.tap(find.widgetWithText(TaskLink, 'Employment properties'));
  await tester.pumpAndSettle();
  expect(find.text('General'), findsOneWidget);
  expect(find.text('History'), findsOneWidget);
  await tester.enterText(find.byKey(const ValueKey('employment-name')), 'Night depot');
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
  expect(find.text('Night depot Properties'), findsOneWidget);   // caption follows the save
  await tester.enterText(find.byKey(const ValueKey('employment-name')), 'Typo');
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TaskLink, 'Employment properties'));
  await tester.pumpAndSettle();
  expect(find.text('Night depot'), findsWidgets);                  // Review Focus 1
  expect(find.text('Typo'), findsNothing);
});
```

- [ ] **Step 2:** Run — FAIL (no tabs, no Apply).

- [ ] **Step 3: Implement.** `EmploymentSheet` = `RecordTabs(record: employment ref, details: InspectorPane([InspectorTitle(name, icon: employment), EmploymentForm(initial: employment, onSubmit: update) , InspectorFacts(legend: 'Agreement', [...current agreement label, rate, shift count]), InspectorActions([KeyButton('View agreement'), KeyButton('Delete…')])]))`, keeping the existing delete confirmation state from `EmploymentHeader`. Route `WorkInspectorRecord(record: EmploymentRecordProjection)` in properties **and** inspect mode to it; remove the `mode=edit` employment branch and the "Edit employment" title.

- [ ] **Step 4:** Run the new test and `flutter test test/features test/integration` — PASS (update tests that tapped "Edit" to edit in the sheet instead).
- [ ] **Step 5:** Commit `feat: employment Properties edits in place`.

---

### Task 4: Agreement sheet — Rate | Premiums | Leave | Notes | History

**Files:**
- Modify: `lib/features/work/presentation/employment_agreement_forms.dart` (`AgreementForm`: sheet mode, `readOnly`, History tab)
- Modify: `lib/features/work/presentation/work_screen.dart` (`_agreement`)
- Test: `test/features/work/presentation/agreement_sheet_test.dart`

**Interfaces:**
- Produces: `AgreementForm({..., bool readOnly = false, WorkRecordRef? historyRecord})`. With `historyRecord` set the tab strip gains **History** showing `RecordHistoryPanel(record: historyRecord)`; with `readOnly` the tab bodies sit under `EraFormScope(enabled: false)` and nothing attaches to the sheet.

- [ ] **Step 1: Failing tests:**

```dart
testWidgets('an unused agreement edits in place; History is the fifth tab', (tester) async { ...
  // open Agreements view, Enter on the row, expect tabs 'Rate','Premiums','Leave','Notes','History',
  // enterText hourly rate '19.00', tap OK, expect dialog closed and list shows EUR 19.00 rate.
});

testWidgets('an agreement used by finished shifts is greyed and cannot apply', (tester) async { ...
  // synthetic shell has 3 finalized shifts on the agreement: open it, expect
  // tester.widget<TextField>(find.byKey(ValueKey('agreement-rate'))).enabled == false
  // and Apply's onPressed == null.                                      // Review Focus 4
});
```

  Write both in full against the synthetic shell (`syntheticScreens['shell']`, View combo → Agreements via `openSheet` from `test/support/work_sheets.dart`).

- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3: Implement.** In sheet mode drop the form's own footer, attach `apply: () async => (await _submitOutcome()) is Committed`, where `_submitOutcome` is the existing `_submit` body returning its outcome (it already moves `_tab` to the first tab holding an error). Mark dirty from every controller and from each `setState` that changes a field. `_agreement(record)` always returns `AgreementForm(initial: agreement, readOnly: record.inUse || update == null, historyRecord: ref, ...)`; `AgreementView` and its Edit button are removed. The "Pay agreement" create dialog keeps its own Save/Cancel footer (no sheet scope there).
- [ ] **Step 4:** Run the new tests and the full suite — PASS.
- [ ] **Step 5:** Commit `feat: the agreement is a five-tab property sheet`.

---

### Task 5: Shift sheet — draft editable, finalized greyed

**Files:**
- Modify: `lib/features/work/presentation/shift_forms.dart` (`ShiftEditInspector` sheet mode)
- Modify: `lib/features/work/presentation/work_inspector.dart` (`_FinalizedShift`, draft branch)
- Modify: `lib/features/work/presentation/work_screen.dart` (`_revision`, `_recordInspector`), `lib/features/work/presentation/work_controller.dart:603` (correction lands on Properties)
- Test: `test/features/work/presentation/shift_sheet_test.dart`, update `test/app/router_test.dart` revision tests

**Interfaces:**
- Produces: `ShiftEditInspector` in sheet mode renders fields only and attaches `apply` returning `outcome is Committed<WorkShift>`; `readOnly: true` renders under `EraFormScope(enabled: false)`.

- [ ] **Step 1: Failing tests:** a draft replacement (create via Correct shift on 2026-09-08 in the synthetic shell) opens as `Shift … Properties` with General | History, editable times, **Finalize shift** on General, OK/Cancel/Apply; changing End time and pressing OK saves and closes. A finalized shift's General shows the same date/time fields greyed (`tester.widget<EraTimeField>(...)` reads disabled through the scope), the pay facts below, and **Correct shift**.
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3: Implement.** Draft: `RecordTabs(details: InspectorPane([ShiftEditInspector(prefill: fromShift, onSubmit: _reviseDraft), InspectorActions([KeyButton('Finalize shift')])]))`. Finalized: `ShiftEditInspector(readOnly: true, prefill: fromShift)` above the existing pay `InspectorFacts` and Correct key. `correctShift` routes with `mode: WorkInspectorMode.properties`. Remove the `mode=edit` revision branch and "Revise replacement shift" title.
- [ ] **Step 4:** Run new + router tests and the full suite — PASS.
- [ ] **Step 5:** Commit `feat: shifts open as property sheets; drafts edit in place`.

---

### Task 6: Period and payslip sheets greyed; History everywhere

**Files:**
- Modify: `lib/features/work/presentation/period_payslip_forms.dart` (record view: greyed Start/End/Label fields above reconciliation and actions)
- Modify: `lib/features/work/presentation/work_inspector.dart` (`_PayslipDetail`: greyed Amount/Basis/Issued/Paid/Reference fields + Correct payslip)
- Test: `test/features/work/presentation/period_payslip_sheet_test.dart`

- [ ] **Step 1: Failing test:** period Properties shows `EraDateField`s for Start and End that do not open on tap, the reconciliation facts, **Mark reviewed**, and General | History; payslip Properties likewise with **Correct payslip**; neither shows an enabled Apply.
- [ ] **Step 2:** Run — FAIL.
- [ ] **Step 3: Implement** by rendering the create-form field widgets with the stored values under `EraFormScope(enabled: false)`; keep the action keys and facts.
- [ ] **Step 4:** Run — PASS; full suite — PASS.
- [ ] **Step 5:** Commit `feat: periods and payslips show their fields greyed`.

---

### Task 7: Retire Edit dialogs, document, verify

**Files:**
- Modify: `lib/features/work/presentation/work_tasks.dart` / any "Edit…" task links, `work_route_state.dart` (keep `edit` only for a new manual shift), `DESIGN.md` (Properties sheet bullet), `test/goldens/*` (regenerate after review)

- [ ] **Step 1:** `grep -rn "Edit employment\|Edit agreement\|Edit pay agreement\|Revise replacement" lib test` — remove or repoint each to Properties; a stale `mode=edit&record=…` URL opens that record's Properties (test in `router_test.dart`).
- [ ] **Step 2:** Update DESIGN.md: "Properties sheet: General | History (agreements: Rate | Premiums | Leave | Notes | History); fields editable where the record allows, greyed otherwise; **OK / Cancel / Apply**, Apply greyed until a change."
- [ ] **Step 3:** `flutter test --update-goldens test/goldens`, render real-font goldens, inspect `period`, `agreement`, `selected` by eye.
- [ ] **Step 4:** `./app.sh` option 2 (all tests pass) and option 3 (analyze, format, schema clean).
- [ ] **Step 5:** Commit `docs: property sheets edit in place`.
