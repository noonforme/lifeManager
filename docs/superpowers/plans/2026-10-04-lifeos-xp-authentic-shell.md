# LifeOS XP-Authentic Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rearrange the LifeOS shell the way a 2001 office program was built — records in Properties dialogs and dialog-box forms, a selection-aware task pane with Details and Working, LifeOS's own window frame, Tahoma-metric type, era scrollbars, painted icons and an XP address bar.

**Architecture:** The Work inspector stays route-driven (`WorkRouteState.mode`, `record`, `add=`); only its *container* changes, from a docked 300 px column to an in-tree modal `ShellDialog` that `ShellFrame` paints over the whole window. A new route mode, `properties`, separates "a row is selected" (Details and task links follow it) from "its Properties sheet is open". Window chrome, scrollbars, icons and type are new shared widgets in `lib/shared/shell` and `lib/shared/workbench`, wired once at the app root.

**Tech Stack:** Flutter 3.47.5 (Linux desktop), Riverpod, GoRouter, Drift, `window_manager` 0.5.2, flutter_test goldens.

**Spec:** `docs/superpowers/specs/2026-10-04-lifeos-xp-authentic-shell-design.md` (amends `docs/superpowers/specs/2026-10-02-lifeos-millennium-shell-design.md`).

## Global Constraints

- Colours come from `LifeOSTokens.millennium` and named constants on `MillenniumColors` (`lib/shared/workbench/millennium_style.dart`), never literals in widgets.
- No vendor names, logos, icons, wallpapers or sounds; every icon, arrow and glyph is painted (a test fails if `lib/` uses a font glyph as an icon).
- No drop shadows or blur. The single exception: a 1 px dark text shadow under the window caption title.
- Every key keeps a visible label and a 24 × 24 minimum target; caption keys meet it through their surround.
- Colour never carries meaning alone: Draft, Void, Open, Reviewed, over and under are always written.
- Text pairs meet 4.5:1; indicators, key outlines and focus meet 3:1 (`test/shared/workbench/lifeos_tokens_test.dart`).
- Synthetic data only in tests, goldens and screenshots.
- Copy is short, direct and factual; no roadmap sentences ("arrives in a later update").
- Run commands with the project Flutter: `FLUTTER=${FLUTTER:-$(command -v flutter || echo $HOME/.local/opt/flutter-3.47.5/bin/flutter)}`; every `flutter` below means `$FLUTTER`.
- Each slice ends green: `flutter analyze lib test tool`, `dart format --output=none --set-exit-if-changed lib test tool`, `flutter test`, goldens regenerated and looked at.

## Review Focus

1. **Typing in a dialog field while Escape is pressed** — Escape inside an open date/time calendar closes the calendar only, not the dialog. Pinned in Task 1 (`escape closes the calendar before the dialog`).
2. **Back and Forward across an open dialog** — Back after opening Properties closes it (the route returns to `mode=inspect`); Forward reopens it. Pinned in Task 3.
3. **A committed save from a dialog** — the dialog closes, the record is selected, and the status bar says what was saved; an `Invalid` or `Stale` result leaves the dialog open with the typed values. Pinned in Task 3.
4. **Clicking the same row twice slowly versus a double-click** — two clicks further apart than the double-click time only select; only a real double-click opens Properties. Pinned in Task 3.
5. **The window maximized** — the frame border and size grip disappear and the caption keys read "Restore"; un-maximizing brings them back. Pinned in Task 7.

## File Structure

| File | Responsibility |
|---|---|
| `lib/shared/shell/shell_dialog.dart` (new) | `ShellDialog`, `ShellDialogKind`, `ShellDialogLayer`, `ShellDialogScope`, `DialogCancelKey` |
| `lib/shared/shell/shell_frame.dart` | Two-column body; `dialog` slot replaces `inspector`/`inspectorOpen`/`onBackToList` |
| `lib/shared/shell/status_line.dart` | `StatusNoticeController`/`StatusNoticeScope`; first panel shows the notice; size grip |
| `lib/shared/shell/working_group_box.dart` | Becomes `WorkingDetails` for the task pane |
| `lib/features/work/presentation/work_route_state.dart` | `WorkInspectorMode.properties` |
| `lib/features/work/presentation/work_screen.dart` | Dialog predicate/title/kind; task groups; Details |
| `lib/features/work/presentation/work_tasks.dart` (new) | Selection-aware task groups and the record summary for Details |
| `lib/features/work/presentation/work_record_names.dart` (new) | `recordName`, `recordIcon` |
| `lib/shared/workbench/data_register.dart` | `onActivate` (Enter, double-click); sort tint; unfocused grey selection; header hover |
| `lib/shared/workbench/inspector_parts.dart` | XP file-properties layout: icon + name + etched line, `Label:` rows |
| `lib/app/window_controls.dart` (new) | `WindowControls` interface + `window_manager` implementation |
| `lib/shared/shell/era_window_frame.dart` (new) | Painted caption, caption keys, frame border, resize edges, `WindowTitleScope` |
| `lib/shared/workbench/era_scrollbar.dart` (new) | `EraScrollbar`, `EraScrollBehavior` |
| `lib/shared/workbench/era_icons.dart` (new) | `EraIconKind`, `EraIcon` painters |
| `lib/app/font_licenses.dart` (new) | Registers the EraSans licence |
| `lib/shared/workbench/era_form.dart` (new) | `EraFormScope`, `EraLabelled`, `EraFieldWidth`, `EraCheckBox`, `EraRadio` |
| `lib/shared/shell/address_bar.dart` | Path combo with the location tree |
| `lib/shared/shell/licenses_dialog.dart` (new) | Era licence dialog |

---

# Slice 1 — Records

### Task 1: The shell dialog and a two-column shell

**Files:**
- Create: `lib/shared/shell/shell_dialog.dart`
- Modify: `lib/shared/shell/shell_frame.dart`, `lib/shared/shell/menu_bar.dart:163-174`, `lib/app/app_router.dart` (`_JournalHost`, `_UnavailableSurface`), `lib/app/desk_host.dart:80-82`
- Test: `test/shared/shell/shell_dialog_test.dart` (new), `test/shared/shell/shell_frame_test.dart`, `test/shared/shell/quick_add_test.dart`

**Interfaces:**
- Produces:
  - `enum ShellDialogKind { properties, form, message }`
  - `ShellDialog({required String title, required Widget child, required VoidCallback onClose, ShellDialogKind kind = ShellDialogKind.form, Size size = const Size(440, 560)})`
  - `ShellDialogScope.closeOf(BuildContext) -> VoidCallback?`
  - `const DialogCancelKey()` — a **Cancel** key inside a dialog, nothing outside one.
  - `ShellFrame({required Widget desk, ShellDialog? dialog, List<Widget> tasks = const [], Widget? details})`
  - `ShellView({bool showTaskPane = true})` (no `showPropertySheet`).

- [ ] **Step 1: Write the failing dialog tests**

```dart
// test/shared/shell/shell_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/shell_dialog.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

Widget _host(Widget child) => MaterialApp(
  home: LifeOSSkinScope(child: Scaffold(body: child)),
);

void main() {
  testWidgets('a dialog shows its caption and content over the window', (
    tester,
  ) async {
    var behind = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Shift 2026-09-08 Properties',
            onClose: () {},
            child: const Text('General'),
          ),
          child: Center(
            child: KeyButton(label: 'Behind', onPressed: () => behind++),
          ),
        ),
      ),
    );
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    await tester.tap(find.text('Behind'), warnIfMissed: false);
    expect(behind, 0, reason: 'the window behind a dialog takes no input');
  });

  testWidgets('Escape and the close key close the dialog', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Record payslip',
            onClose: () => closed++,
            child: const SizedBox.shrink(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);
    await tester.tap(find.bySemanticsLabel('Close Record payslip'));
    expect(closed, 2);
  });

  testWidgets('a Properties sheet has OK and Cancel; both close it', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Pay period Properties',
            kind: ShellDialogKind.properties,
            onClose: () => closed++,
            child: const SizedBox.shrink(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.tap(find.text('OK'));
    await tester.tap(find.text('Cancel'));
    expect(closed, 2);
  });

  testWidgets('a form dialog adds no footer of its own', (tester) async {
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Manual shift',
            onClose: () {},
            child: const SizedBox.shrink(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('DialogCancelKey closes its dialog and is absent outside one', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Manual shift',
            onClose: () => closed++,
            child: const DialogCancelKey(),
          ),
          child: const DialogCancelKey(),
        ),
      ),
    );
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(closed, 1);
  });

  testWidgets('a dialog shrinks to 90 % of a small window', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Pay agreement',
            size: const Size(480, 600),
            onClose: () {},
            child: const SizedBox.expand(),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    final size = tester.getSize(find.bySemanticsLabel('Pay agreement').first);
    expect(size.width, lessThanOrEqualTo(360));
    expect(size.height, lessThanOrEqualTo(360));
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/shared/shell/shell_dialog_test.dart`
Expected: compile failure, `shell_dialog.dart` not found.

- [ ] **Step 3: Write `shell_dialog.dart`**

```dart
// lib/shared/shell/shell_dialog.dart
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/era_dialog.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';
import '../workbench/office_controls.dart';

/// What a dialog is for (XP-authentic shell spec 4): a record's Properties
/// sheet, which gets **OK** and **Cancel** at its foot; a form, which keeps
/// its own keys; or a message box.
enum ShellDialogKind { properties, form, message }

/// A dialog the shell paints over the whole window. Whether it is open
/// lives in the route, so Back and Forward close and reopen it.
@immutable
final class ShellDialog {
  const ShellDialog({
    required this.title,
    required this.child,
    required this.onClose,
    this.kind = ShellDialogKind.form,
    this.size = const Size(440, 560),
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final ShellDialogKind kind;

  /// The dialog's size; it shrinks to 90 % of a smaller window.
  final Size size;
}

/// Lets a key inside a dialog close it.
final class ShellDialogScope extends InheritedWidget {
  const ShellDialogScope({
    required this.onClose,
    required super.child,
    super.key,
  });

  final VoidCallback onClose;

  static VoidCallback? closeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellDialogScope>()?.onClose;

  @override
  bool updateShouldNotify(ShellDialogScope oldWidget) =>
      onClose != oldWidget.onClose;
}

/// **Cancel** at the end of a form's footer. Outside a dialog it is absent.
final class DialogCancelKey extends StatelessWidget {
  const DialogCancelKey({super.key});

  @override
  Widget build(BuildContext context) {
    final close = ShellDialogScope.closeOf(context);
    if (close == null) return const SizedBox.shrink();
    return KeyButton(label: 'Cancel', onPressed: close);
  }
}

/// The window, with [dialog] over it when one is open. The window keeps its
/// look but takes no input or focus while the dialog is up, as an era modal
/// dialog did. The window's subtree is never rebuilt into a new shape, so
/// its scroll positions, selection and drafts survive a dialog.
final class ShellDialogLayer extends StatelessWidget {
  const ShellDialogLayer({required this.dialog, required this.child, super.key});

  final ShellDialog? dialog;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dialog = this.dialog;
    final open = dialog != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: open,
          child: AbsorbPointer(
            absorbing: open,
            child: ExcludeSemantics(excluding: open, child: child),
          ),
        ),
        if (dialog != null)
          LayoutBuilder(
            builder: (context, constraints) => Center(
              child: SizedBox(
                width: math.min(dialog.size.width, constraints.maxWidth * 0.9),
                height: math.min(
                  dialog.size.height,
                  constraints.maxHeight * 0.9,
                ),
                child: _DialogWindow(dialog: dialog),
              ),
            ),
          ),
      ],
    );
  }
}

final class _DialogWindow extends StatelessWidget {
  const _DialogWindow({required this.dialog});

  final ShellDialog dialog;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): dialog.onClose,
      },
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: dialog.title,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tokens.chrome,
              border: Border.all(color: MillenniumColors.keyLine),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CaptionBar(title: dialog.title, onClose: dialog.onClose),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ShellDialogScope(
                      onClose: dialog.onClose,
                      child: DefaultTextStyle.merge(
                        style: skin.typography.body.copyWith(color: tokens.ink),
                        child: dialog.child,
                      ),
                    ),
                  ),
                ),
                if (dialog.kind == ShellDialogKind.properties)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: FormFooter(
                      children: [
                        KeyButton(
                          label: 'OK',
                          kind: KeyKind.primary,
                          onPressed: dialog.onClose,
                        ),
                        KeyButton(label: 'Cancel', onPressed: dialog.onClose),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the dialog tests**

Run: `flutter test test/shared/shell/shell_dialog_test.dart`
Expected: PASS (6 tests). If `find.bySemanticsLabel('Close Record payslip')` misses, confirm `CaptionBar` still defaults `closeLabel` to `'Close $title'` (`lib/shared/workbench/era_dialog.dart:126`).

- [ ] **Step 5: Add an Escape-ordering test with a date field inside a dialog**

Append to `test/shared/shell/shell_dialog_test.dart`:

```dart
  testWidgets('escape closes the calendar before the dialog', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _host(
        ShellDialogLayer(
          dialog: ShellDialog(
            title: 'Manual shift',
            onClose: () => closed++,
            child: EraDateField(
              label: 'Start date',
              fieldKey: const ValueKey('start'),
              value: const LocalDate(2026, 10, 3),
              today: const LocalDate(2026, 10, 3),
              onChanged: (_) {},
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('start')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsNothing);
    expect(closed, 0);
  });
```

Add imports `package:lifeos/core/time/local_date.dart` and `package:lifeos/shared/workbench/era_date_field.dart`. Run it. If it fails because the calendar does not consume Escape, make the calendar's own `CallbackShortcuts` (in `era_date_field.dart`, where it closes on Escape) return before the dialog sees the key: wrap the calendar overlay entry's content in `Shortcuts(shortcuts: {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()})` with `Actions(actions: {DismissIntent: CallbackAction(onInvoke: (_) => _close())})`, which stops propagation. Re-run until PASS.

- [ ] **Step 6: Change `ShellFrame` to two columns and a dialog slot**

In `lib/shared/shell/shell_frame.dart`:

1. Delete `ShellMetrics.propertySheetWidth` and `ShellMetrics.fullWidth`.
2. Replace `ShellView` with:

```dart
/// Which optional regions the owner shows (View menu).
@immutable
final class ShellView {
  const ShellView({this.showTaskPane = true});

  final bool showTaskPane;

  ShellView copyWith({bool? showTaskPane}) =>
      ShellView(showTaskPane: showTaskPane ?? this.showTaskPane);

  @override
  bool operator ==(Object other) =>
      other is ShellView && other.showTaskPane == showTaskPane;

  @override
  int get hashCode => showTaskPane.hashCode;
}
```

3. Replace the `ShellFrame` fields and constructor:

```dart
/// The shell (XP-authentic shell spec 3): menu bar, toolbar, Address bar,
/// task pane and content, status bar, and the open dialog over all of it.
final class ShellFrame extends StatefulWidget {
  const ShellFrame({
    required this.desk,
    this.dialog,
    this.tasks = const [],
    this.details,
    super.key,
  });

  final Widget desk;

  /// The open Properties sheet, form or message box, if any.
  final ShellDialog? dialog;

  /// The surface's own task-pane groups, shown above Books.
  final List<Widget> tasks;

  /// The Details group's content, shown below Books.
  final Widget? details;
```

4. In `build`, delete `full`, `inspecting`, `inspector` and the `work` switch; use `desk` directly: `Positioned.fill(child: desk)` in the folded stack and `Expanded(child: desk)` in the row. Wrap the returned `Column` in the dialog layer:

```dart
            return ShellDialogLayer(
              dialog: widget.dialog,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ /* the existing menu bar … status line children */ ],
              ),
            );
```

5. Delete `_PropertySheetRegion`. Add `import 'shell_dialog.dart';`.

- [ ] **Step 7: Remove the property-sheet View item and the dead parameters**

- `lib/shared/shell/menu_bar.dart`: delete the `viewItem('Show property sheet', …)` entry.
- `lib/app/app_router.dart`: in `_JournalHost.build` and `_UnavailableSurface.build`, delete `inspectorOpen: false,` and `onBackToList: _noop,`; delete `void _noop() {}`.
- `lib/app/desk_host.dart`: delete `inspectorOpen: false,` and `onBackToList: () {},`.
- `lib/features/work/presentation/work_screen.dart`: for now replace `inspector: _inspector(ready), inspectorOpen: inspectorActive, onBackToList: …` with nothing (Task 3 adds `dialog:`), and delete `_showRegister` and `inspectorActive`. The file must compile; `_inspector` may be temporarily unused (add `// ignore: unused_element` only until Task 3).

- [ ] **Step 8: Update the shell tests**

Run: `grep -rn "inspectorOpen\|onBackToList\|Record inspector\|Back to list\|showPropertySheet\|Show property sheet" test`
For each hit:
- Constructor calls: delete the two arguments.
- Tests that assert the three-column layout, `Back to list`, or the View › Show property sheet item: replace them with one test in `test/shared/shell/shell_frame_test.dart`:

```dart
  testWidgets('the body is the task pane and the content; no property sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(const ShellFrame(desk: Text('Register'))), // use the file's existing host helper
    );
    expect(find.bySemanticsLabel('Task pane'), findsOneWidget);
    expect(find.bySemanticsLabel('Desk workspace'), findsOneWidget);
    expect(find.bySemanticsLabel('Record inspector'), findsNothing);
    expect(find.text('Back to list'), findsNothing);
  });

  testWidgets('a dialog given to the frame is shown over it', (tester) async {
    await tester.pumpWidget(
      _shell(
        ShellFrame(
          desk: const Text('Register'),
          dialog: ShellDialog(
            title: 'New pay period',
            onClose: () {},
            child: const Text('Dates'),
          ),
        ),
      ),
    );
    expect(find.text('New pay period'), findsOneWidget);
    expect(find.text('Dates'), findsOneWidget);
  });
```

Use whatever host helper `shell_frame_test.dart` already defines (it pumps `ShellFrame` under `LifeOSSkinScope`); rename `_shell` to match.

- [ ] **Step 9: Run the shell tests and analyze**

Run: `flutter analyze lib test tool && flutter test test/shared/shell`
Expected: no analyzer errors; shell tests PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/shared/shell lib/app/app_router.dart lib/app/desk_host.dart lib/features/work/presentation/work_screen.dart test/shared/shell
git commit -m "feat: replace the docked property sheet with a shell dialog layer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Status-bar notices

**Files:**
- Modify: `lib/shared/shell/status_line.dart`, `lib/app/lifeos_app.dart`
- Test: `test/shared/shell/status_line_test.dart`

**Interfaces:**
- Produces:
  - `StatusNoticeController extends ValueNotifier<String?>`
  - `StatusNoticeScope({required StatusNoticeController controller, required Widget child})`
  - `StatusNoticeScope.read(BuildContext) -> StatusNoticeController?` (no dependency)
  - `StatusNoticeScope.valueOf(BuildContext) -> String?` (depends)

- [ ] **Step 1: Write the failing test**

Append to `test/shared/shell/status_line_test.dart` (reuse its host helper, which wraps in `LifeOSSkinScope`):

```dart
  testWidgets('the first panel shows the last notice', (tester) async {
    final notices = StatusNoticeController();
    addTearDown(notices.dispose);
    await tester.pumpWidget(
      _host( // the file's existing helper
        StatusNoticeScope(
          controller: notices,
          child: const StatusLine(snapshot: StatusSnapshot()),
        ),
      ),
    );
    expect(find.text('Shift saved.'), findsNothing);
    notices.value = 'Shift saved.';
    await tester.pump();
    expect(find.text('Shift saved.'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/shared/shell/status_line_test.dart`
Expected: FAIL, `StatusNoticeController` undefined.

- [ ] **Step 3: Implement**

Add to `lib/shared/shell/status_line.dart`:

```dart
/// What the last finished action did, for the status bar's first panel
/// ("Shift saved."). It stays until the next notice replaces it.
final class StatusNoticeController extends ValueNotifier<String?> {
  StatusNoticeController() : super(null);
}

final class StatusNoticeScope
    extends InheritedNotifier<StatusNoticeController> {
  const StatusNoticeScope({
    required StatusNoticeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static String? valueOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StatusNoticeScope>()
      ?.notifier
      ?.value;

  static StatusNoticeController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StatusNoticeScope>()?.notifier;
}
```

In `StatusLine.build`, read `final notice = StatusNoticeScope.valueOf(context);` and replace the first child `const Expanded(child: SizedBox.shrink()),` with:

```dart
            Expanded(
              child: notice == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      liveRegion: true,
                      child: _Panel(child: Text(notice, style: style)),
                    ),
            ),
```

In `lib/app/lifeos_app.dart`: add `final _notices = StatusNoticeController();`, dispose it in `dispose()`, and wrap `CellSelectionScope` in `StatusNoticeScope(controller: _notices, child: …)`. Import `../shared/shell/status_line.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/shared/shell/status_line_test.dart test/app/lifeos_app_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/shell/status_line.dart lib/app/lifeos_app.dart test/shared/shell/status_line_test.dart
git commit -m "feat: show what was just saved in the status bar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Properties mode, row activation and Work dialogs

**Files:**
- Modify: `lib/features/work/presentation/work_route_state.dart`, `lib/shared/workbench/data_register.dart`, `lib/features/work/presentation/work_sheets.dart`, `lib/features/work/presentation/work_register.dart`, `lib/features/work/presentation/work_screen.dart`, `lib/app/app_router.dart` (`_WorkRouteHost`), the five form footers listed in Step 9
- Create: `lib/features/work/presentation/work_record_names.dart`, `test/support/work_dialogs.dart`
- Test: `test/features/work/presentation/work_route_state_test.dart` (existing file name may differ — `grep -rln parseWorkRoute test`), `test/shared/workbench/data_register_test.dart`, `test/integration/work_dialogs_flow_test.dart` (new), plus migrated tests

**Interfaces:**
- Consumes: `ShellDialog`, `ShellDialogKind`, `DialogCancelKey` (Task 1); `StatusNoticeScope.read` (Task 2).
- Produces:
  - `enum WorkInspectorMode { inspect, properties, create, edit, correct }`; URL `mode=properties`.
  - `DataRegister.onActivate: ValueChanged<T>?` — Enter, Alt+Enter, double-click.
  - `ShiftsSheet/PeriodsSheet/PayslipsSheet/AgreementsSheet.onProperties: ValueChanged<WorkRecordRef>?` — Enter, double-click and right-click › Properties.
  - `WorkRegister.onProperties: ValueChanged<WorkRecordRef>?`
  - `WorkScreen.onOpenProperties: ValueChanged<WorkRecordRef>?`, `WorkScreen.onCloseDialog: VoidCallback?`
  - `String recordName(WorkRecordProjection)` in `work_record_names.dart`.
  - Test helper `Future<void> openProperties(WidgetTester tester)` in `test/support/work_dialogs.dart`.

- [ ] **Step 1: Write the failing route test**

In the existing route-state test file (find it with `grep -rln "parseWorkRoute" test`), add:

```dart
  test('properties mode round-trips through the URL', () {
    final uri = Uri.parse(
      '/work?employment=$employmentId&record=shift:$shiftId&mode=properties',
    ); // reuse the file's synthetic id constants
    final parsed = parseWorkRoute(uri) as ValidWorkRoute;
    expect(parsed.state.mode, WorkInspectorMode.properties);
    expect(workRouteUri(parsed.state).queryParameters['mode'], 'properties');
  });
```

- [ ] **Step 2: Implement the mode**

In `work_route_state.dart`:

```dart
enum WorkInspectorMode { inspect, properties, create, edit, correct }
```

and in `parseWorkRoute`'s mode switch add `'properties' => WorkInspectorMode.properties,`. Run the route test: PASS.

- [ ] **Step 3: Write the failing register activation tests**

Append to `test/shared/workbench/data_register_test.dart` (reuse its `_register`/host helpers that build a `DataRegister<String>` with rows `a`, `b`):

```dart
  testWidgets('Enter activates the row under the cursor; Space only opens', (
    tester,
  ) async {
    final opened = <String>[];
    final activated = <String>[];
    await tester.pumpWidget(
      _host(_register(onOpen: opened.add, onActivate: activated.add)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(opened, ['a']);
    expect(activated, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, ['a']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(activated, ['a', 'a'], reason: 'Alt+Enter opens Properties too');
  });

  testWidgets('a double-click activates; two slow clicks only open', (
    tester,
  ) async {
    final opened = <String>[];
    final activated = <String>[];
    await tester.pumpWidget(
      _host(_register(onOpen: opened.add, onActivate: activated.add)),
    );
    final cell = tester.getCenter(find.text('a').first);
    Future<void> click(Duration at) async {
      final gesture = await tester.createGesture();
      await gesture.down(cell, timeStamp: at);
      await gesture.up(timeStamp: at + const Duration(milliseconds: 40));
      await tester.pump();
    }

    await click(const Duration(seconds: 1));
    await click(const Duration(seconds: 2));
    expect(activated, isEmpty, reason: 'a second apart is two clicks');
    await click(const Duration(seconds: 2, milliseconds: 200));
    expect(activated, ['a']);
    expect(opened.length, 2, reason: 'the activating click does not reopen');
  });
```

If the helper does not accept `onActivate`, add that named parameter to it and pass it through to `DataRegister`.

- [ ] **Step 4: Implement activation in `DataRegister`**

In `lib/shared/workbench/data_register.dart`:

1. Add to the widget:

```dart
  /// Opens the row's Properties: Enter, Alt+Enter or a double-click.
  /// Without it, Enter opens the row as Space does.
  final ValueChanged<T>? onActivate;
```

(constructor: `this.onActivate,`).

2. In the state add:

```dart
  /// The last primary press: row index and event time, for double-clicks.
  (int, Duration)? _lastPress;
  bool _activatePending = false;

  void _press(int index, PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    final last = _lastPress;
    _lastPress = (index, event.timeStamp);
    // Synthetic events without a time stamp never pair into a double-click.
    if (last != null &&
        event.timeStamp > Duration.zero &&
        last.$1 == index &&
        event.timeStamp - last.$2 <= kDoubleTapTimeout) {
      _lastPress = null;
      _activatePending = true;
    }
  }
```

Import `package:flutter/gestures.dart` for `kPrimaryButton` and `kDoubleTapTimeout`.

3. In `_handleKey`, replace the Enter/Space branch:

```dart
    if (key == LogicalKeyboardKey.space && row != null) {
      widget.onOpen(rows[row].row);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && row != null) {
      (widget.onActivate ?? widget.onOpen)(rows[row].row);
      return KeyEventResult.handled;
    }
```

4. In `build`, the `_DataRow` gets `onPress: (event) => _press(index, event),` and its `onCellTap` becomes:

```dart
                  onCellTap: (column) {
                    _focus.requestFocus();
                    _moveCursor(index, column, visible);
                    if (_activatePending) {
                      _activatePending = false;
                      (widget.onActivate ?? widget.onOpen)(row);
                    } else {
                      widget.onOpen(row);
                    }
                  },
```

5. In `_DataRow`, add `required this.onPress,` / `final ValueChanged<PointerDownEvent> onPress;` and wrap its outer `Container` in `Listener(onPointerDown: onPress, child: …)`.

Run the register tests: PASS.

- [ ] **Step 5: Give the Work sheets Properties**

In `lib/features/work/presentation/work_sheets.dart`, each of `ShiftsSheet`, `PeriodsSheet`, `PayslipsSheet`, `AgreementsSheet` gets:

```dart
  /// Opens the row's Properties (Enter, double-click, right-click).
  final ValueChanged<WorkRecordRef>? onProperties;
```

(constructor `this.onProperties,`), and its `DataRegister` gets — shown for `ShiftsSheet`; use each sheet's own ref function (`_shiftRef(row)`, `ref(row)`, `ref(value)`):

```dart
      onActivate: onProperties == null
          ? null
          : (row) => onProperties!(_shiftRef(row)),
      actions: onProperties == null
          ? null
          : (row) => [
              RowAction(
                label: 'Properties',
                onInvoke: () => onProperties!(_shiftRef(row)),
              ),
            ],
```

In `work_register.dart`, add `final ValueChanged<WorkRecordRef>? onProperties;` (constructor `this.onProperties,`) and pass `onProperties: onProperties,` to all four sheets.

- [ ] **Step 6: Record names**

```dart
// lib/features/work/presentation/work_record_names.dart
import '../data/projections/work_record_projection.dart';

/// A record's name in captions and Details: "Shift 2026-09-08".
String recordName(WorkRecordProjection record) => switch (record) {
  ShiftRecordProjection(:final shift) => 'Shift ${shift.localStartDate}',
  PayPeriodRecordProjection(:final period) =>
    period.label ?? 'Pay period ${period.start} – ${period.end}',
  PayslipRecordProjection(:final payslip) => 'Payslip ${payslip.issuedDate}',
  EmploymentRecordProjection(:final employment) => employment.name,
  AgreementRecordProjection() => 'Pay agreement',
};
```

- [ ] **Step 7: Open the inspector content in a dialog**

In `lib/features/work/presentation/work_screen.dart`:

1. Add parameters:

```dart
  /// Opens a record's Properties sheet (route `mode=properties`).
  final ValueChanged<WorkRecordRef>? onOpenProperties;

  /// Closes whatever dialog the route opened (back to `mode=inspect`).
  final VoidCallback? onCloseDialog;
```

2. Replace `build`:

```dart
  @override
  Widget build(BuildContext context) {
    final ready = _current(widget.state);
    return ShellFrame(
      desk: _RegisterLandmark(child: _register(ready)),
      dialog: ready is WorkReady && _dialogOpen(ready)
          ? ShellDialog(
              title: _dialogTitle(ready),
              kind: _dialogKind(ready),
              size: _dialogSize(ready),
              onClose: _closeDialog,
              child: _inspector(ready),
            )
          : null,
      tasks: _taskGroups(ready),
      details: _details(ready),
    );
  }
```

For this task `_taskGroups` returns today's Work tasks group unchanged (move the existing `TaskGroup(title: 'Work tasks', …)` code into it, with `_showRegister` references removed) and `_details` returns today's `WorkDetails` or null. Task 4 replaces both.

3. Add, in the `extension on _WorkScreenState`:

```dart
  bool _dialogOpen(WorkReady state) {
    final route = state.route;
    return route.mode != WorkInspectorMode.inspect ||
        route.adding != null ||
        _creatingPeriod ||
        _payslipPeriod != null ||
        _periodFailure != null ||
        _reviseFailure != null;
  }

  void _closeDialog() {
    setState(() {
      _creatingPeriod = false;
      _payslipPeriod = null;
      _periodFailure = null;
      _reviseFailure = null;
    });
    widget.onCloseDialog?.call();
  }

  WorkRecordProjection? _selected(WorkReady state) => switch (state.inspector) {
    WorkInspectorRecord(:final record) => record,
    _ => null,
  };

  bool _failed() => _periodFailure != null || _reviseFailure != null;

  ShellDialogKind _dialogKind(WorkReady state) => _failed()
      ? ShellDialogKind.message
      : state.route.mode == WorkInspectorMode.properties
      ? ShellDialogKind.properties
      : ShellDialogKind.form;

  Size _dialogSize(WorkReady state) {
    if (_failed()) return const Size(380, 260);
    if (state.route.mode == WorkInspectorMode.properties) {
      return const Size(400, 480);
    }
    final agreement =
        state.route.adding == WorkAddKind.agreement ||
        _selected(state) is AgreementRecordProjection;
    return agreement ? const Size(480, 600) : const Size(440, 560);
  }

  String _dialogTitle(WorkReady state) {
    final route = state.route;
    if (_failed()) return 'Work';
    if (_creatingPeriod || route.adding == WorkAddKind.payPeriod) {
      return 'New pay period';
    }
    if (_payslipPeriod != null || route.adding == WorkAddKind.payslip) {
      return 'Record payslip';
    }
    if (route.adding == WorkAddKind.agreement) return 'Pay agreement';
    final record = _selected(state);
    return switch (route.mode) {
      WorkInspectorMode.create =>
        route.employmentId == null ? 'New employment' : 'Record work',
      WorkInspectorMode.edit => switch (record) {
        null =>
          route.fromLast && widget.lastShiftTemplate != null
              ? 'Manual shift from last time'
              : 'Manual shift',
        EmploymentRecordProjection() => 'Edit employment',
        AgreementRecordProjection() => 'Edit pay agreement',
        _ => 'Revise replacement shift',
      },
      WorkInspectorMode.correct =>
        record is PayslipRecordProjection ? 'Correct payslip' : 'Correct shift',
      WorkInspectorMode.properties || WorkInspectorMode.inspect =>
        record == null ? 'Work record' : '${recordName(record)} Properties',
    };
  }
```

4. In `_inspector`, delete the first branch (`route.record == null && employment != null && !state.register.hasAgreement` → `AgreementForm`) and the `_employmentHeader` branch keyed on `route.record == null`. In the final `switch (state.inspector)`, replace the employment case with two cases:

```dart
      WorkInspectorRecord(
        record: EmploymentRecordProjection(:final employment),
      )
          when route.mode == WorkInspectorMode.properties =>
        _employmentHeader(state.register, employment),
      WorkInspectorRecord(
        record: EmploymentRecordProjection(:final employment),
      ) =>
        _employmentEditor(employment),
```

5. In `_register(...)`, pass `onProperties: widget.onOpenProperties,` to `WorkRegister`.

6. Imports: `../../../shared/shell/shell_dialog.dart`, `work_record_names.dart`.

- [ ] **Step 8: Announce committed saves**

Still in `work_screen.dart`, add to the extension:

```dart
  /// Passes a mutation through and, when it committed, says so in the
  /// status bar.
  Future<MutationOutcome<T>> _saved<T>(
    Future<MutationOutcome<T>> pending,
    String notice,
  ) async {
    final outcome = await pending;
    if (outcome is Committed<T> && mounted) {
      StatusNoticeScope.read(context)?.value = notice;
    }
    return outcome;
  }
```

Wrap each submit at the point `_inspector` and its helpers hand it to a form:

| Callback | Notice |
|---|---|
| `onSaveManualShift` (`ShiftEditInspector.onSubmit: save`) | `Shift saved.` |
| `_reviseDraft` | `Shift saved.` |
| `onFinalize` (passed to `WorkInspector`) | `Shift finalized.` |
| `_createPeriod` | `Pay period created.` |
| `onRecordPayslip` (both `PayslipInspector.create` sites) | `Payslip recorded.` |
| `onCreateEmployment`, `onUpdateEmployment` | `Employment saved.` |
| `onDeleteEmployment` | `Employment deleted.` |
| `onCreateAgreement`, `onUpdateAgreement` | `Pay agreement saved.` |
| `_setPeriodState` | `Period marked reviewed.` / `Period reopened.` by the requested state |
| `onCorrectShift`, `onCorrectPayslip` | `Shift corrected.` / `Payslip corrected.` |

Example for the manual shift: `onSubmit: (value) => _saved(save(value), 'Shift saved.'),`. Import `../../../shared/shell/status_line.dart`.

- [ ] **Step 9: Cancel in every form footer**

Add `const DialogCancelKey(),` as the last child of these footers (after the primary key):

- `lib/features/work/presentation/employment_agreement_forms.dart:148` (employment form)
- `lib/features/work/presentation/employment_agreement_forms.dart:601` (agreement form)
- `lib/features/work/presentation/period_payslip_forms.dart:230` (pay period create)
- `lib/features/work/presentation/period_payslip_forms.dart:422` (payslip create)
- `lib/features/work/presentation/shift_forms.dart:534` (manual shift / revise)

Import `../../../shared/shell/shell_dialog.dart` in each. The correction confirmation already has its own Cancel.

- [ ] **Step 10: Wire the router**

In `_WorkRouteHost.build` (`lib/app/app_router.dart`) add to `WorkScreen(...)`:

```dart
        onOpenProperties: (record) {
          final parsed = ref.read(workRouteProvider);
          if (parsed case ValidWorkRoute(:final state)) {
            ref.read(replaceWorkRouteProvider)(
              state.copyWith(
                scope: () => record.kind == WorkRecordKind.payPeriod
                    ? PayPeriodScope(record.id as PayPeriodId)
                    : state.scope,
                record: () => record,
                mode: WorkInspectorMode.properties,
              ),
            );
          }
        },
        onCloseDialog: () {
          final parsed = ref.read(workRouteProvider);
          if (parsed case ValidWorkRoute(:final state)) {
            ref.read(replaceWorkRouteProvider)(
              state.copyWith(
                mode: WorkInspectorMode.inspect,
                adding: () => null,
                fromLast: false,
              ),
            );
          }
        },
```

- [ ] **Step 11: The test helper and the flow tests**

```dart
// test/support/work_dialogs.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/task_pane.dart';

/// Opens the selected record's Properties from its task link.
Future<void> openProperties(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TaskLink, 'Properties'));
  await tester.pumpAndSettle();
}

/// The open dialog, found by its caption.
Finder dialogTitled(String title) => find.bySemanticsLabel(title);
```

(`openProperties` relies on Task 4's Properties task link; until Task 4 lands, the flow test below uses Enter.)

```dart
// test/integration/work_dialogs_flow_test.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic_shell.dart';

void main() {
  testWidgets('selecting a row opens no dialog; Enter opens its Properties', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('Back closes Properties and Forward reopens it', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close Shift 2026-09-08 Properties'));
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
    await tester.tap(find.text('Forward'), warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('a saved manual shift closes the dialog and says so', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['form']!,
    );
    expect(find.text('Manual shift'), findsWidgets);
    // Fill the form with the era picker helpers in test/support/era_pickers.dart
    // (pick start/end times), then:
    await tester.tap(find.text('Save manual shift'));
    await tester.pumpAndSettle();
    expect(find.text('Save manual shift'), findsNothing);
    expect(find.text('Shift saved.'), findsOneWidget);
  });

  testWidgets('an invalid manual shift keeps the dialog and its values', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['form']!,
    );
    await tester.tap(find.text('Save manual shift'));
    await tester.pumpAndSettle();
    expect(find.text('Save manual shift'), findsOneWidget);
    expect(find.text('Shift saved.'), findsNothing);
  });
}
```

In the third test, use the existing helpers in `test/support/era_pickers.dart` (read that file first; it exposes functions that open a time box and pick a value) to set start 08:00 and end 16:00 before saving. In the Back/Forward test, the Back key is the toolbar key labelled `Back`; closing via the caption key pushes a new route (`mode=inspect`), so Back returns to `mode=properties`. If `go_router`'s `go` replaces rather than pushes history in `NavigationHistory`, assert against `NavigationHistory` behaviour as `test/shared/shell/navigation_history_test.dart` documents and keep the assertion that Back reopens the sheet.

- [ ] **Step 12: Migrate tests that relied on the inspector opening on click**

Run: `flutter test 2>&1 | grep -E "^\s*(test|.*_test.dart)" | sort -u` and `grep -rln "Mark reviewed\|Correct shift\|Correct payslip\|Record payslip\|Finalize\|Edit\b\|View agreement" test`.
For each failing test that taps a register row (or opens a record from the Journal/Today) and then expects record content (facts, "Mark reviewed", "Correct shift", "Finalize shift", History tab):
- after the tap, add `await tester.sendKeyEvent(LogicalKeyboardKey.enter); await tester.pumpAndSettle();` (Task 4 can switch these to `openProperties(tester)`);
- tests that navigate straight to a URL with `record=…&mode=inspect` and expect content: change the URL's mode to `properties`;
- tests that asserted the agreement form appears for an employment without an agreement: navigate to `add=agreement` instead (Task 4 adds the "Set up pay agreement…" link and a test for it);
- tests that tap behind an open form (for example a register row while a form shows): close the dialog first (`Cancel`).
Do not change assertions about record content, outcomes or copy.

- [ ] **Step 13: Run everything**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS, except golden tests. Goldens are regenerated at the end of the slice (Task 5).

- [ ] **Step 14: Commit**

```bash
git add -A lib test
git commit -m "feat: open records in Properties dialogs and forms in dialog boxes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Selection-aware task groups and Details with Working

**Files:**
- Create: `lib/features/work/presentation/work_tasks.dart`
- Modify: `lib/shared/shell/working_group_box.dart` (becomes `WorkingDetails`), `lib/features/work/presentation/record_history_panel.dart` (drop Working from General), `lib/features/work/presentation/work_screen.dart`, `lib/shared/shell/task_pane.dart` (link `icon` slot used in Task 9 — not here)
- Test: `test/shared/shell/working_group_box_test.dart` → rename to `test/shared/shell/working_details_test.dart`, `test/features/work/presentation/work_tasks_test.dart` (new), `test/integration/working_first_click_test.dart`

**Interfaces:**
- Consumes: `recordName` (Task 3); `WorkInspectorMode.properties` (Task 3).
- Produces:
  - `WorkingDetails({required ValueChanged<Uri> onNavigate, required Widget fallback})` — Working when the cell under the cursor is derived, else [fallback].
  - `List<Widget> workTaskGroups(WorkTaskContext context)` and `final class WorkTaskContext` (fields below).
  - `RecordSummary({required WorkRecordProjection record, TimezoneService? timezones})`.

- [ ] **Step 1: Write the failing Details tests**

`git mv test/shared/shell/working_group_box_test.dart test/shared/shell/working_details_test.dart`, then in that file:

1. In `_pump`, change the default `width` to `176` (the task-pane group's inner width) and replace `WorkingGroupBox(onNavigate: opened.add)` with:

```dart
                    child: WorkingDetails(
                      onNavigate: opened.add,
                      fallback: const Text('Synthetic depot'),
                    ),
```

2. In `_operand`, `find.byType(WorkingGroupBox)` → `find.byType(WorkingDetails)`.
3. Replace the first test and the recorded-fact test with:

```dart
  testWidgets('without a selection it shows the fallback', (tester) async {
    await _pump(tester, CellSelectionController());
    expect(find.text('Synthetic depot'), findsOneWidget);
    expect(find.byType(GroupBox), findsNothing);
  });

  testWidgets('a recorded cell shows the fallback, not a working', (
    tester,
  ) async {
    final cells = CellSelectionController()
      ..value = CellSelection(
        owner: Object(),
        reference: 'D4',
        columnLabel: 'Start',
        display: '07:00',
      );
    await _pump(tester, cells);
    expect(find.text('Synthetic depot'), findsOneWidget);
    expect(find.text('Working: Start'), findsNothing);
    expect(find.text('Recorded fact'), findsNothing);
  });
```

4. In the derived test add `expect(find.text('Synthetic depot'), findsNothing);` and `expect(find.byType(GroupBox), findsNothing, reason: 'Details has no box of its own');`.
5. The long-working test: change its comment/name from "300 px" to "176 px" and pass `width: 176`; its assertions (every operand still opens) stay.
6. Any test using `withMenu: true` (Edit › Copy explanation) stays unchanged apart from the widget name.

Run: `flutter test test/shared/shell/working_details_test.dart` — FAIL (`WorkingDetails` undefined).

- [ ] **Step 2: Turn `WorkingGroupBox` into `WorkingDetails`**

In `lib/shared/shell/working_group_box.dart`:
- Rename the class to `WorkingDetails` and add `required this.fallback` / `final Widget fallback;`.
- `selection == null` → `return widget.fallback;`
- `explanation == null` → `return widget.fallback;` (delete the recorded-fact box).
- The derived branch drops the `GroupBox` and lays out for the 176 px task-pane group:

```dart
    return Semantics(
      liveRegion: true,
      label: '${selection.reference}, ${explanation.plainText}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Working: ${selection.columnLabel}',
            style: skin.typography.body.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(TextSpan(style: figure, children: spans)),
          if (source != null && sourceLabel != null) ...[
            const SizedBox(height: 4),
            // the existing source link, unchanged
          ],
        ],
      ),
    );
```

- In `record_history_panel.dart`, delete the `WorkingGroupBox` padding block; General shows `widget.details` directly.

Run: `flutter test test/shared/shell/working_details_test.dart` → PASS.

- [ ] **Step 3: Write the failing task-group tests**

```dart
// test/features/work/presentation/work_tasks_test.dart
// Pump WorkScreen through pumpSyntheticShell and check the task pane.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/task_pane.dart';

import '../../../support/synthetic_shell.dart';

Finder _group(String title) => find.widgetWithText(TaskGroup, title);
Finder _link(String label) => find.widgetWithText(TaskLink, label);

void main() {
  testWidgets('nothing selected: Work tasks with the employment links', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    expect(_group('Work tasks'), findsOneWidget);
    expect(_link('Add a shift'), findsOneWidget);
    expect(_link('Employment properties'), findsOneWidget);
    expect(_link('Properties'), findsNothing);
  });

  testWidgets('a finalized shift selected: Shift tasks', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    expect(_group('Shift tasks'), findsOneWidget);
    expect(_link('Correct this shift…'), findsOneWidget);
    expect(_link('Finalize this shift'), findsNothing);
    await tester.tap(_link('Properties'));
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
  });

  testWidgets('a pay period selected: Period tasks', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['period']!,
    );
    // the period screen selects the period record by route
    expect(_group('Period tasks'), findsOneWidget);
    expect(_link('Mark this period reviewed'), findsOneWidget);
    expect(_link('Record payslip…'), findsOneWidget);
  });

  testWidgets('a selected row fills Details; a derived cell shows Working', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _group('Details'), matching: find.text('Shift 2026-09-08')),
      findsOneWidget,
    );
    await tester.tap(find.text('EUR 220.80'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _group('Details'), matching: find.textContaining('Working')),
      findsOneWidget,
    );
  });
}
```

If `syntheticScreens['period']` opens the period with `mode=inspect`, the period is selected but no dialog shows — that is the intended new behaviour; update the period golden screen in Task 5 to `mode=properties`.

- [ ] **Step 4: Implement the task groups and the summary**

```dart
// lib/features/work/presentation/work_tasks.dart
import 'package:flutter/widgets.dart';

import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/task_pane.dart';
import '../data/projections/work_record_projection.dart';
import '../domain/pay_period.dart';
import '../domain/shift.dart';
import 'work_formats.dart';
import 'work_record_names.dart';

/// What the task pane offers for the current selection (XP-authentic shell
/// spec 4.1). A null callback means the action is not offered, and its
/// link is left out rather than greyed.
final class WorkTaskContext {
  const WorkTaskContext({
    required this.selected,
    this.onAddShift,
    this.onNewPeriod,
    this.onRecordPayslip,
    this.onSaveView,
    this.onProperties,
    this.onEmploymentProperties,
    this.onSetUpAgreement,
    this.onFinalize,
    this.onCorrect,
    this.onMarkReviewed,
    this.onReopen,
    this.onRecordPayslipForPeriod,
  });

  final WorkRecordProjection? selected;
  final VoidCallback? onAddShift;
  final VoidCallback? onNewPeriod;
  final VoidCallback? onRecordPayslip;
  final VoidCallback? onSaveView;
  final VoidCallback? onProperties;
  final VoidCallback? onEmploymentProperties;
  final VoidCallback? onSetUpAgreement;
  final VoidCallback? onFinalize;
  final VoidCallback? onCorrect;
  final VoidCallback? onMarkReviewed;
  final VoidCallback? onReopen;
  final VoidCallback? onRecordPayslipForPeriod;
}

List<Widget> workTaskGroups(WorkTaskContext c) {
  List<Widget> links(List<(String, VoidCallback?)> entries) => [
    for (final (label, action) in entries)
      if (action != null) TaskLink(label: label, onPressed: action),
  ];

  Widget group(String title, List<(String, VoidCallback?)> entries) =>
      TaskGroup(
        // Keyed by title so each group keeps its own collapsed state.
        key: ValueKey('work-task-group-$title'),
        title: title,
        special: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: links(entries),
        ),
      );

  return switch (c.selected) {
    ShiftRecordProjection(:final shift) => [
      group('Shift tasks', [
        if (shift.state == ShiftState.draft && shift.endUtc != null)
          ('Finalize this shift', c.onFinalize),
        if (shift.state == ShiftState.finalized)
          ('Correct this shift…', c.onCorrect),
        ('Properties', c.onProperties),
      ]),
    ],
    PayPeriodRecordProjection(:final period) => [
      group('Period tasks', [
        if (period.state == PayPeriodState.reviewed)
          ('Reopen this period', c.onReopen)
        else
          ('Mark this period reviewed', c.onMarkReviewed),
        ('Record payslip…', c.onRecordPayslipForPeriod),
        ('Properties', c.onProperties),
      ]),
    ],
    PayslipRecordProjection(:final payslip) => [
      group('Payslip tasks', [
        if (payslip.isEffective) ('Correct this payslip…', c.onCorrect),
        ('Properties', c.onProperties),
      ]),
    ],
    EmploymentRecordProjection() => [
      group('Employment tasks', [('Properties', c.onProperties)]),
    ],
    AgreementRecordProjection() => [
      group('Agreement tasks', [('Properties', c.onProperties)]),
    ],
    null => [
      group('Work tasks', [
        ('Add a shift', c.onAddShift),
        ('New pay period', c.onNewPeriod),
        ('Record payslip', c.onRecordPayslip),
        ('Set up pay agreement…', c.onSetUpAgreement),
        ('Employment properties', c.onEmploymentProperties),
        ('Save this view…', c.onSaveView),
      ]),
    ],
  };
}

/// The selected record in the Details group: its name, kind and a few
/// facts (spec 4.2).
final class RecordSummary extends StatelessWidget {
  const RecordSummary({required this.record, this.timezones, super.key});

  final WorkRecordProjection record;
  final TimezoneService? timezones;

  @override
  Widget build(BuildContext context) {
    final (kind, facts) = switch (record) {
      ShiftRecordProjection(:final shift, :final pay) => (
        'Shift',
        [
          ('State', switch (shift.state) {
            ShiftState.draft => 'Draft',
            ShiftState.finalized => 'Finalized',
            ShiftState.voided => 'Void',
          }),
          if (pay != null) ('Paid time', formatDuration(pay.totalPaidSeconds)),
          if (pay != null) ('Expected pay', formatMoney(pay.amount)),
        ],
      ),
      PayPeriodRecordProjection(:final period) => (
        'Pay period',
        [
          ('Dates', '${period.start} – ${period.end}'),
          (
            'State',
            period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open',
          ),
        ],
      ),
      PayslipRecordProjection(:final payslip) => (
        'Payslip',
        [
          ('Amount', formatMoney(payslip.amount)),
          ('Issued', '${payslip.issuedDate}'),
          ('State', payslip.isEffective ? 'Effective' : 'Void'),
        ],
      ),
      EmploymentRecordProjection() => ('Employment', <(String, String)>[]),
      AgreementRecordProjection(:final finishedShifts) => (
        'Pay agreement',
        [('Finished shifts', '$finishedShifts')],
      ),
    };
    return Semantics(
      liveRegion: true,
      child: TaskDetails(
        lines: [
          Text(
            recordName(record),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(kind),
          for (final (label, value) in facts) Text('$label: $value'),
        ],
      ),
    );
  }
}
```

Check names against the domain before compiling: `Payslip.isEffective`, `PayPeriod.start/end/state/label`, `ExpectedPay.amount/totalPaidSeconds`, `ShiftState` values (`draft`, `finalized`, `voided` per `work_inspector.dart:94-126`). Adjust only names, not behaviour.

- [ ] **Step 5: Use them in `WorkScreen`**

Replace `_taskGroups` and `_details` in `work_screen.dart`:

```dart
  List<Widget> _taskGroups(WorkViewState? state) {
    if (state is! WorkReady) return const [];
    final route = state.route;
    final register = state.register;
    final employment = register.employment;
    final selected = _selected(state);
    final ref = route.record;
    final open = widget.onOpenProperties;
    final period = selected is PayPeriodRecordProjection ? selected.period : null;
    return workTaskGroups(
      WorkTaskContext(
        selected: selected,
        onAddShift: route.employmentId == null ? null : widget.onPrimaryAction,
        onNewPeriod: widget.onCreatePayPeriod == null || route.employmentId == null
            ? null
            : () => setState(() => _creatingPeriod = true),
        onRecordPayslip: widget.onRecordPayslip == null || register.period == null
            ? null
            : () => setState(() => _payslipPeriod = register.period!.id),
        onSaveView: widget.onSaveView == null || route.employmentId == null
            ? null
            : () => widget.onSaveView!(route),
        onProperties: ref == null || open == null ? null : () => open(ref),
        onEmploymentProperties: employment == null || open == null
            ? null
            : () => open(
                WorkRecordRef(kind: WorkRecordKind.employment, id: employment.id),
              ),
        onSetUpAgreement: employment == null || register.hasAgreement
            ? null
            : () => _go(route.copyWith(adding: () => WorkAddKind.agreement)),
        onFinalize: ref == null || open == null ? null : () => open(ref),
        onCorrect: widget.onOpenCorrection,
        onMarkReviewed: period == null || widget.onSetPeriodState == null
            ? null
            : () => _setPeriodState(period, PayPeriodState.reviewed),
        onReopen: period == null || widget.onSetPeriodState == null
            ? null
            : () => _setPeriodState(period, PayPeriodState.open),
        onRecordPayslipForPeriod: period == null || widget.onRecordPayslip == null
            ? null
            : () => setState(() => _payslipPeriod = period.id),
      ),
    );
  }

  Widget? _details(WorkViewState? state) {
    if (state is! WorkReady) return null;
    final chrome = ShellChrome.maybeOf(context);
    final selected = _selected(state);
    final register = state.register;
    final Widget fallback = selected != null
        ? RecordSummary(record: selected, timezones: widget.timezones)
        : register.employment == null
        ? const SizedBox.shrink()
        : register.hasAgreement
        ? WorkDetails(projection: register)
        : const TaskDetails(lines: [Text('No pay agreement yet.')]);
    return WorkingDetails(
      onNavigate: (route) => chrome?.onNavigate(route.toString()),
      fallback: fallback,
    );
  }
```

Notes for the implementer:
- "Finalize this shift" opens the shift's Properties, whose General tab is today's `FinalizeShiftInspector` with its **Finalize** key — the sheet is where finalizing happens (spec 4.1/4.3).
- `onCorrect` uses the existing `onOpenCorrection` (route `mode=correct`), which shows the correction dialog.
- Mark reviewed from the task pane calls `_setPeriodState` without a dialog; a failure sets `_periodFailure`, which opens the message box (Task 3 predicate).
- `_go(route.copyWith(adding: …))` keeps `mode` as is; `add=agreement` opens the Pay agreement dialog.

Delete the now-unused `EmploymentHeader` roadmap line: in `employment_agreement_forms.dart:806` remove the `'Has work history — archiving arrives in a later update.'` text widget (an employment that cannot be deleted simply shows no Delete key), and at `:681` remove `'New versions arrive in a later update.'`.

- [ ] **Step 6: Switch migrated tests to the task link**

Replace the `sendKeyEvent(LogicalKeyboardKey.enter)` lines added in Task 3 Step 12 with `await openProperties(tester);` where a test reads more naturally through the task pane; keep Enter in at least `work_dialogs_flow_test.dart` so both paths stay covered. Add to `work_dialogs_flow_test.dart`:

```dart
  testWidgets('right-click › Properties opens the sheet', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Properties').last);
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
  });

  testWidgets('an employment without an agreement offers to set one up', (
    tester,
  ) async {
    // Create a second synthetic employment without an agreement through the
    // providers as pumpSyntheticShell does, navigate to it, then:
    // expect(find.widgetWithText(TaskLink, 'Set up pay agreement…'), findsOneWidget);
    // tap it; expect(find.text('Pay agreement'), findsWidgets) (the dialog caption).
  });
```

Write the second test fully: extend `pumpSyntheticShell` with an optional `bool withAgreement = true` parameter that skips `createAgreement` when false, and use it here (`import 'package:flutter/gestures.dart'` for `kSecondaryButton` in the first).

- [ ] **Step 7: Run and commit**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS except goldens.

```bash
git add -A lib test
git commit -m "feat: task pane follows the selection; Details shows the record and its Working

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The Properties sheet's General layout, then slice-1 goldens

**Files:**
- Modify: `lib/shared/workbench/inspector_parts.dart`, `test/support/synthetic_shell.dart` (period screen → `mode=properties`)
- Test: `test/shared/workbench/inspector_parts_test.dart`, goldens

**Interfaces:**
- Produces: `InspectorTitle(String title, {String? meta, Widget? icon})` (icon slot filled in Task 9); `InspectorFacts` renders an etched separator and `Label:` rows.

- [ ] **Step 1: Write the failing layout test**

Append to `test/shared/workbench/inspector_parts_test.dart`:

```dart
  testWidgets('facts read as "Label:" rows under an etched line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host( // existing helper
        const InspectorPane(
          children: [
            InspectorTitle('Shift 2026-09-08'),
            InspectorFacts([Fact('Date', '2026-09-08')], legend: 'Shift'),
          ],
        ),
      ),
    );
    expect(find.text('Date:'), findsOneWidget);
    expect(find.byType(EtchedLine), findsNWidgets(2));
    expect(find.text('Shift'), findsNothing, reason: 'blocks have no legend');
    expect(find.bySemanticsLabel('Shift'), findsOneWidget);
  });
```

- [ ] **Step 2: Implement**

In `inspector_parts.dart`:

```dart
/// A 2 px etched separator: a grey line over a white one.
final class EtchedLine extends StatelessWidget {
  const EtchedLine({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Container(height: 1, color: tokens.chromeLine),
          Container(height: 1, color: tokens.paper),
        ],
      ),
    );
  }
}
```

`InspectorTitle.build` becomes a row of the optional `icon` (32 px slot, Task 9) and the title in **Strong** body weight (`skin.typography.body.copyWith(fontWeight: FontWeight.w700)`), followed by `const EtchedLine()`; keep `meta` under the title in Small.

`InspectorFacts.build`:

```dart
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: legend,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fact in facts) InspectorFactRow(fact: fact),
        const EtchedLine(),
      ],
    ),
  );
```

`InspectorFactRow`: label text becomes `'${fact.label}:'` in ink (not muted), in a fixed 96 px column; the value follows left-aligned. Keep the wrap-under rule for 200 % text: when label + value do not fit, the value goes under its label, left-aligned.

```dart
              if (!fits) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, value],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(width: 96, child: label),
                  Expanded(child: value),
                ],
              );
```

with `final value = Text(fact.value, style: valueStyle);` (no `textAlign.end`) and the fit test `96 + width(value) <= maxWidth`.

- [ ] **Step 3: Point the period golden at the sheet**

In `test/support/synthetic_shell.dart`, change the `period` screen URL's `mode=inspect` (or missing mode) to `mode=properties`. Add two screens:

```dart
  'selected': (employment, _) => '/work?employment=$employment', // + a selected shift: use the shift id pumpSyntheticShell creates; add it to the closure arguments if needed
  'working': (employment, _) => '/work?employment=$employment',
```

and in the golden test, for `selected` tap `2026-09-08`, for `working` tap `EUR 220.80`, before matching. Implement by adding an optional `Future<void> Function(WidgetTester)? after` to a new `syntheticInteractions` map in `synthetic_shell.dart`, applied in both `shell_goldens_test.dart` and `real_font_check_test.dart`.

- [ ] **Step 4: Regenerate and look at goldens**

Run:
```bash
flutter test --update-goldens test/goldens/shell_goldens_test.dart
flutter test --run-skipped -t real-font --update-goldens test/goldens/real_font_check_test.dart
```
Open every PNG under `test/goldens/real_font/` and check: no right column; Details shows the record or Working; Properties dialog centred with OK/Cancel; manual shift dialog with Save and Cancel; nothing clipped at 960 × 760.

- [ ] **Step 5: Full run, app.sh check, commit**

Run: `flutter analyze lib test tool && dart format --output=none --set-exit-if-changed lib test tool && flutter test`
Expected: PASS.

```bash
git add -A lib test
git commit -m "feat: lay out the Properties sheet like an era file-properties page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
# Slice 2 — Window and Type

### Task 6: EraSans, the era type scale

**Files:**
- Create: `assets/fonts/era_sans/EraSans-Regular.ttf`, `assets/fonts/era_sans/EraSans-Bold.ttf`, `assets/fonts/era_sans/LICENSE`, `assets/fonts/era_sans/SOURCE`, `lib/app/font_licenses.dart`
- Delete: `assets/fonts/archivo/`, `assets/fonts/azeret_mono/`
- Modify: `pubspec.yaml`, `lib/shared/workbench/lifeos_skin.dart` (`LifeOSTypography`), `lib/shared/workbench/millennium_style.dart` (`lifeOSTypography`), `lib/shared/workbench/era_dialog.dart` (`CaptionBar.large`), `lib/shared/shell/shell_dialog.dart`, `lib/shared/workbench/operational_state.dart`, `lib/app/app_router.dart` (`_UnavailableSurface`), `lib/main.dart`, `test/goldens/real_font_check_test.dart`
- Test: `test/app/font_licenses_test.dart` (new), `test/shared/workbench/lifeos_typography_test.dart` (new)

**Interfaces:**
- Produces: `LifeOSTypography({caption, strong, label, body, small, figure, counter})` — `title` is removed; `void registerFontLicenses()`; `CaptionBar(..., bool large = false)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/workbench/lifeos_typography_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/millennium_style.dart';

void main() {
  test('everything is EraSans at 11 px, falling back to Noto Sans', () {
    const type = lifeOSTypography;
    for (final style in [
      type.body,
      type.strong,
      type.label,
      type.small,
      type.figure,
    ]) {
      expect(style.fontFamily, 'EraSans');
      expect(style.fontSize, 11);
      expect(style.fontFamilyFallback, ['NotoSans']);
    }
    expect(type.caption.fontSize, 13);
    expect(type.caption.fontWeight, FontWeight.w700);
    expect(type.strong.fontWeight, FontWeight.w700);
    expect(type.counter.fontSize, 18);
  });
}
```

(add `import 'package:flutter/widgets.dart';` for `FontWeight`.)

```dart
// test/app/font_licenses_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the EraSans licence is registered', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final era = entries.where((entry) => entry.packages.contains('EraSans'));
    expect(era, isNotEmpty);
    final text = era.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('GNU Lesser General Public License'));
  });
}
```

Run: `flutter test test/shared/workbench/lifeos_typography_test.dart test/app/font_licenses_test.dart` — FAIL (compile).

- [ ] **Step 2: Bring in the font**

```bash
mkdir -p assets/fonts/era_sans
curl -sSfL -o assets/fonts/era_sans/EraSans-Regular.ttf https://gitlab.winehq.org/wine/wine/-/raw/master/fonts/tahoma.ttf
curl -sSfL -o assets/fonts/era_sans/EraSans-Bold.ttf https://gitlab.winehq.org/wine/wine/-/raw/master/fonts/tahomabd.ttf
curl -sSfL -o assets/fonts/era_sans/LICENSE https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt
{
  echo "EraSans is Wine's Tahoma-metric font (fonts/tahoma.ttf, fonts/tahomabd.ttf),"
  echo "from https://gitlab.winehq.org/wine/wine, (C) 2004 Larry Snyder, based on"
  echo "Bitstream Vera Sans. LGPL-2.1-or-later; see LICENSE. Renamed in LifeOS's"
  echo "pubspec only; the files are unmodified."
  echo
  sha256sum assets/fonts/era_sans/*.ttf
} > assets/fonts/era_sans/SOURCE
git rm -r -q assets/fonts/archivo assets/fonts/azeret_mono
```

Check: `grep -rn "Archivo\|AzeretMono" lib test` → no hits outside `pubspec.yaml`.

In `pubspec.yaml`, replace the `Archivo` and `AzeretMono` families with:

```yaml
    - family: EraSans
      fonts:
        - asset: assets/fonts/era_sans/EraSans-Regular.ttf
        - asset: assets/fonts/era_sans/EraSans-Bold.ttf
          weight: 700
```

and add under `flutter:` (create the key if absent):

```yaml
  assets:
    - assets/fonts/era_sans/LICENSE
```

Run `flutter pub get`.

- [ ] **Step 3: Register the licence**

```dart
// lib/app/font_licenses.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled EraSans font's licence to Help › About › Licenses.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/era_sans/LICENSE');
    yield LicenseEntryWithLineBreaks(
      const ['EraSans'],
      "EraSans is Wine's Tahoma-metric font, (C) 2004 Larry Snyder, based on "
      'Bitstream Vera Sans, used under the GNU Lesser General Public License '
      'version 2.1 or later.\n\n$text',
    );
  });
}
```

Call `registerFontLicenses();` in `lib/main.dart` right after `WidgetsFlutterBinding.ensureInitialized();`.

- [ ] **Step 4: The type scale**

In `lib/shared/workbench/lifeos_skin.dart`, `LifeOSTypography` fields become `caption`, `strong`, `label`, `body`, `small`, `figure`, `counter` (delete `title`; doc comments: caption = window and dialog captions, strong = record names and group titles).

In `millennium_style.dart`:

```dart
const _family = 'EraSans';
const _fallback = ['NotoSans'];

const lifeOSTypography = LifeOSTypography(
  caption: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w700,
  ),
  strong: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
  ),
  label: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
  ),
  body: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
  ),
  small: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
  ),
  // EraSans digits share one advance width (checked 2026-10-04: 1118 units
  // regular, 1304 bold), so figures line up without a feature.
  figure: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
  counter: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 18,
    height: 20 / 18,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
);
```

Replace the three `typography.title` uses with `typography.strong` (`app_router.dart` `_UnavailableSurface`, `operational_state.dart`, `inspector_parts.dart` if Task 5 left one). In `lifeos_theme.dart`, replace every `'NotoSans'` family with `'EraSans'` plus `fontFamilyFallback: ['NotoSans']` (grep `NotoSans` in `lib/`).

`CaptionBar` gets `this.large = false` / `final bool large;` and uses `skin.typography.caption` for its title when `large`, keeping today's body-bold for desk tiles; its `minHeight` becomes `large ? 26 : 24`. `_DialogWindow` passes `large: true`.

- [ ] **Step 5: Load EraSans in the real-font harness**

In `test/goldens/real_font_check_test.dart`, load both families in `setUpAll`:

```dart
  setUpAll(() async {
    for (final (family, dir) in [
      ('EraSans', 'assets/fonts/era_sans'),
      ('NotoSans', 'assets/fonts/noto_sans'),
    ]) {
      final loader = FontLoader(family);
      for (final file in Directory(dir).listSync().whereType<File>().where(
        (file) => file.path.endsWith('.ttf'),
      )) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
      await loader.load();
    }
  });
```

Update its doc comment to "rendered with the bundled EraSans".

- [ ] **Step 6: Run and commit**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS except goldens (regenerated in Task 9). Layout tests that measured 12 px text may need their expected sizes updated; change only the numbers.

```bash
git add -A pubspec.yaml pubspec.lock assets lib test
git commit -m "feat: set LifeOS in EraSans, Wine's Tahoma-metric font, at 11 px

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Painted era icons

**Files:**
- Create: `lib/shared/workbench/era_icons.dart`
- Modify: `lib/shared/workbench/office_controls.dart` (`AreaKey`), `lib/shared/shell/task_pane.dart` (`TaskLink.icon`), `lib/shared/workbench/inspector_parts.dart` (`InspectorTitle.icon`), `lib/features/work/presentation/work_tasks.dart`, `lib/features/work/presentation/work_record_names.dart`, `lib/features/work/presentation/work_inspector.dart`, `lib/features/work/presentation/period_payslip_forms.dart`, `lib/features/work/presentation/shift_forms.dart`, `lib/app/desk_host.dart`, `lib/features/journal/journal_sheet.dart`
- Test: `test/shared/workbench/era_icons_test.dart` (new), `test/shared/workbench/office_controls_test.dart`

**Interfaces:**
- Produces:
  - `enum EraIconKind { app, work, finance, tracking, knowledge, shift, payPeriod, payslip, employment, agreement, add, properties, correct, reviewed, recordPayslip, saveView, newDesk, delete }`
  - `EraIcon(EraIconKind kind, {double size = 16, bool disabled = false, String? semanticLabel})`
  - `EraIconKind areaIcon(LifeOSArea area)`
  - `TaskLink({required String label, required VoidCallback? onPressed, EraIconKind? icon})`
  - `InspectorTitle(String title, {String? meta, EraIconKind? icon})` (32 px icon)
  - `EraIconKind recordIcon(WorkRecordProjection record)`

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/workbench/era_icons_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_icons.dart';

void main() {
  testWidgets('every icon paints at 16 and 32 px without text', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          children: [
            for (final kind in EraIconKind.values) ...[
              EraIcon(kind),
              EraIcon(kind, size: 32),
              EraIcon(kind, disabled: true),
            ],
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Text), findsNothing, reason: 'icons are painted');
    expect(
      tester.getSize(find.byType(EraIcon).first),
      const Size(16, 16),
    );
  });

  testWidgets('an icon with a label is announced; without one it is silent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            EraIcon(EraIconKind.work, semanticLabel: 'Work'),
            EraIcon(EraIconKind.add),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Work'), findsOneWidget);
  });
}
```

In `office_controls_test.dart`, change the `AreaKey` test (it expects the letter `W`) to:

```dart
  testWidgets('an area key is its painted icon, announced by name', (tester) async {
    await tester.pumpWidget(_host(const AreaKey(area: LifeOSArea.work)));
    expect(find.text('W'), findsNothing);
    expect(find.byType(EraIcon), findsOneWidget);
    expect(find.bySemanticsLabel('Work'), findsOneWidget);
  });
```

- [ ] **Step 2: Implement `era_icons.dart`**

```dart
// lib/shared/workbench/era_icons.dart
import 'package:flutter/widgets.dart';

import 'lifeos_tokens.dart';

/// The painted icon set (XP-authentic shell spec 7). No vendor artwork and
/// no font glyphs: each is drawn on a 16-unit grid with a dark outline, a
/// two-stop gradient and a highlight, then scaled.
enum EraIconKind {
  app,
  work,
  finance,
  tracking,
  knowledge,
  shift,
  payPeriod,
  payslip,
  employment,
  agreement,
  add,
  properties,
  correct,
  reviewed,
  recordPayslip,
  saveView,
  newDesk,
  delete,
}

EraIconKind areaIcon(LifeOSArea area) => switch (area) {
  LifeOSArea.work => EraIconKind.work,
  LifeOSArea.finance => EraIconKind.finance,
  LifeOSArea.tracking => EraIconKind.tracking,
  LifeOSArea.knowledge => EraIconKind.knowledge,
};

final class EraIcon extends StatelessWidget {
  const EraIcon(
    this.kind, {
    this.size = 16,
    this.disabled = false,
    this.semanticLabel,
    super.key,
  });

  final EraIconKind kind;
  final double size;

  /// Painted in greys, for an unbuilt area or an unavailable action.
  final bool disabled;

  /// Announced when the icon stands for something; silent otherwise.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(kind, disabled: disabled)),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: icon)
        : Semantics(label: label, excludeSemantics: true, child: icon);
  }
}

// Icon colours. They are artwork, not interface tokens, so they live here
// beside the shapes that use them.
const _outline = Color(0xff3b3b3b);
const _paperTop = Color(0xffffffff);
const _paperBottom = Color(0xffe6e6e0);
const _paperLine = Color(0xff8a8a8a);
const _rule = Color(0xff9aa6c0);
const _brownTop = Color(0xffe2a85c);
const _brownBottom = Color(0xff9a5a1a);
const _brownEdge = Color(0xff5a3410);
const _goldTop = Color(0xffffe27a);
const _goldBottom = Color(0xffd09a10);
const _goldEdge = Color(0xff8a6400);
const _greenTop = Color(0xff8fd46a);
const _greenBottom = Color(0xff2f8a1f);
const _greenEdge = Color(0xff1f5a14);
const _purpleTop = Color(0xffb7a0e0);
const _purpleBottom = Color(0xff6a4ea0);
const _purpleEdge = Color(0xff3e2a66);
const _blueTop = Color(0xff8fb4f5);
const _blueBottom = Color(0xff2a5fd0);
const _blueEdge = Color(0xff163a8a);
const _redTop = Color(0xffff8a6a);
const _redBottom = Color(0xffc1300f);
const _redEdge = Color(0xff7a1c06);
const _ink = Color(0xff1a1a1a);
const _pencilTip = Color(0xfff2c09a);

final class _IconPainter extends CustomPainter {
  const _IconPainter(this.kind, {required this.disabled});

  final EraIconKind kind;
  final bool disabled;

  static const _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.55, 0,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    if (disabled) {
      canvas.saveLayer(Offset.zero & size, Paint()..colorFilter = _grey);
    } else {
      canvas.save();
    }
    canvas.scale(size.width / 16, size.height / 16);
    switch (kind) {
      case EraIconKind.app:
        _orb(canvas, const Offset(8, 8), 6.5, _blueTop, _blueBottom, _blueEdge);
        _tick(canvas, const Offset(4.8, 8.2), 3, const Color(0xffffffff));
      case EraIconKind.work:
        _shape(
          canvas,
          RRect.fromLTRBR(1.5, 5, 14.5, 14, const Radius.circular(1.5)),
          _brownTop,
          _brownBottom,
          _brownEdge,
        );
        _stroke(
          canvas,
          RRect.fromLTRBR(5.5, 2.5, 10.5, 5, const Radius.circular(1)),
          _brownEdge,
        );
        _line(canvas, const Offset(1.5, 9), const Offset(14.5, 9), _brownEdge);
        _shape(
          canvas,
          RRect.fromLTRBR(7, 8, 9, 10.5, const Radius.circular(0.5)),
          _goldTop,
          _goldBottom,
          _goldEdge,
        );
      case EraIconKind.finance:
        for (final (x, y) in const [(3.0, 9.0), (8.0, 11.0), (6.0, 5.5)]) {
          final coin = Rect.fromLTWH(x, y, 7, 4);
          _ovalShape(canvas, coin, _goldTop, _goldBottom, _goldEdge);
        }
      case EraIconKind.tracking:
        _paper(canvas, const Rect.fromLTRB(1.5, 1.5, 14.5, 14.5));
        for (final (x, top) in const [(3.5, 9.0), (7.0, 5.0), (10.5, 7.0)]) {
          _shape(
            canvas,
            RRect.fromLTRBR(x, top, x + 2.5, 12.5, Radius.zero),
            _greenTop,
            _greenBottom,
            _greenEdge,
          );
        }
      case EraIconKind.knowledge:
        _shape(
          canvas,
          RRect.fromLTRBR(2.5, 1.5, 12.5, 14.5, const Radius.circular(1)),
          _purpleTop,
          _purpleBottom,
          _purpleEdge,
        );
        _fillRect(canvas, const Rect.fromLTRB(12.5, 2.5, 14, 14), _paperTop);
        _line(canvas, const Offset(14, 2.5), const Offset(14, 14), _paperLine);
        _line(canvas, const Offset(5, 5), const Offset(10, 5), _goldTop);
      case EraIconKind.shift:
        _orb(canvas, const Offset(8, 8), 6.5, _paperTop, _paperBottom, _blueEdge);
        _line(canvas, const Offset(8, 8), const Offset(8, 4), _ink);
        _line(canvas, const Offset(8, 8), const Offset(11, 9.5), _ink);
      case EraIconKind.payPeriod:
        _paper(canvas, const Rect.fromLTRB(1.5, 2.5, 14.5, 14.5));
        _fillRect(canvas, const Rect.fromLTRB(2, 3, 14, 6), _redBottom);
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 4; col++) {
            _fillRect(
              canvas,
              Rect.fromLTWH(3.5 + col * 2.6, 7.5 + row * 2.2, 1.4, 1.2),
              _rule,
            );
          }
        }
      case EraIconKind.payslip:
        _slip(canvas);
      case EraIconKind.employment:
        _shape(
          canvas,
          RRect.fromLTRBR(3, 2, 13, 14.5, Radius.zero),
          _blueTop,
          _blueBottom,
          _blueEdge,
        );
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 2; col++) {
            _fillRect(
              canvas,
              Rect.fromLTWH(5 + col * 3.5, 4 + row * 3, 2, 1.8),
              _goldTop,
            );
          }
        }
      case EraIconKind.agreement:
        _paper(canvas, const Rect.fromLTRB(2.5, 1.5, 13.5, 14.5));
        for (final y in const [4.5, 6.5, 8.5]) {
          _line(canvas, Offset(4.5, y), Offset(11.5, y), _paperLine);
        }
        _orb(canvas, const Offset(10.5, 11.5), 2.5, _redTop, _redBottom, _redEdge);
      case EraIconKind.add:
        _paper(canvas, const Rect.fromLTRB(2.5, 1.5, 12.5, 13.5));
        _plus(canvas, const Offset(11.5, 11.5));
      case EraIconKind.properties:
        _paper(canvas, const Rect.fromLTRB(2.5, 1.5, 13.5, 14.5));
        for (final y in const [5.0, 8.0, 11.0]) {
          _fillRect(canvas, Rect.fromLTWH(4.5, y - 0.75, 1.5, 1.5), _blueBottom);
          _line(canvas, Offset(7, y), Offset(11.5, y), _paperLine);
        }
      case EraIconKind.correct:
        final pencil = Path()
          ..moveTo(3, 13)
          ..lineTo(4, 10)
          ..lineTo(11.5, 2.5)
          ..lineTo(13.5, 4.5)
          ..lineTo(6, 12)
          ..close();
        _pathShape(canvas, pencil, _goldTop, _goldBottom, _goldEdge);
        _fillPath(
          canvas,
          Path()
            ..moveTo(3, 13)
            ..lineTo(4, 10)
            ..lineTo(6, 12)
            ..close(),
          _pencilTip,
        );
      case EraIconKind.reviewed:
        _tick(canvas, const Offset(2.5, 8.5), 5.5, _greenBottom, width: 2.6);
      case EraIconKind.recordPayslip:
        _slip(canvas);
        _plus(canvas, const Offset(11.5, 11.5));
      case EraIconKind.saveView:
        _shape(
          canvas,
          RRect.fromLTRBR(2, 2, 14, 14, const Radius.circular(1)),
          _blueTop,
          _blueBottom,
          _blueEdge,
        );
        _fillRect(canvas, const Rect.fromLTRB(4, 2.5, 12, 7), _paperTop);
        _fillRect(canvas, const Rect.fromLTRB(5, 9.5, 11, 13.5), _paperBottom);
      case EraIconKind.newDesk:
        _shape(
          canvas,
          RRect.fromLTRBR(1.5, 2.5, 12.5, 12.5, const Radius.circular(1)),
          _paperTop,
          _paperBottom,
          _blueEdge,
        );
        _fillRect(canvas, const Rect.fromLTRB(2, 3, 12, 5.5), _blueBottom);
        _plus(canvas, const Offset(11.5, 11.5));
      case EraIconKind.delete:
        final paint = Paint()
          ..color = _redBottom
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(const Offset(4, 4), const Offset(12, 12), paint)
          ..drawLine(const Offset(12, 4), const Offset(4, 12), paint);
    }
    canvas.restore();
  }

  void _shape(Canvas canvas, RRect shape, Color top, Color bottom, Color edge) {
    canvas.drawRRect(shape, _gradient(shape.outerRect, top, bottom));
    _stroke(canvas, shape, edge);
  }

  void _pathShape(Canvas canvas, Path path, Color top, Color bottom, Color edge) {
    canvas.drawPath(path, _gradient(path.getBounds(), top, bottom));
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _ovalShape(Canvas canvas, Rect oval, Color top, Color bottom, Color edge) =>
      _pathShape(canvas, Path()..addOval(oval), top, bottom, edge);

  void _orb(Canvas canvas, Offset centre, double radius, Color top, Color bottom, Color edge) =>
      _ovalShape(
        canvas,
        Rect.fromCircle(center: centre, radius: radius),
        top,
        bottom,
        edge,
      );

  void _stroke(Canvas canvas, RRect shape, Color edge) => canvas.drawRRect(
    shape,
    Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  void _paper(Canvas canvas, Rect rect) => _shape(
    canvas,
    RRect.fromRectAndRadius(rect, Radius.zero),
    _paperTop,
    _paperBottom,
    _paperLine,
  );

  void _slip(Canvas canvas) {
    _paper(canvas, const Rect.fromLTRB(3, 1.5, 13, 14.5));
    for (final y in const [4.5, 6.5, 8.5]) {
      _line(canvas, Offset(5, y), Offset(11, y), _paperLine);
    }
    _line(canvas, const Offset(5, 11.5), const Offset(8, 11.5), _greenBottom);
  }

  void _plus(Canvas canvas, Offset centre) {
    _orb(canvas, centre, 3.5, _greenTop, _greenBottom, _greenEdge);
    final paint = Paint()
      ..color = const Color(0xffffffff)
      ..strokeWidth = 1.4;
    canvas
      ..drawLine(centre.translate(-2, 0), centre.translate(2, 0), paint)
      ..drawLine(centre.translate(0, -2), centre.translate(0, 2), paint);
  }

  void _tick(Canvas canvas, Offset start, double size, Color color, {double width = 1.6}) {
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx + size * 0.4, start.dy + size * 0.45)
        ..lineTo(start.dx + size * 1.4, start.dy - size * 0.75),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color) =>
      canvas.drawLine(a, b, Paint()..color = color..strokeWidth = 1);

  void _fillRect(Canvas canvas, Rect rect, Color color) =>
      canvas.drawRect(rect, Paint()..color = color);

  void _fillPath(Canvas canvas, Path path, Color color) =>
      canvas.drawPath(path, Paint()..color = color);

  Paint _gradient(Rect bounds, Color top, Color bottom) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    ).createShader(bounds);

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.disabled != disabled;
}
```

Global Constraints say "colours from tokens"; icon artwork colours are the documented exception (record it in DESIGN.md in Task 15).

- [ ] **Step 3: Use the icons**

- `AreaKey.build` (`office_controls.dart`) becomes `EraIcon(areaIcon(area), semanticLabel: area.label)` (16 px). Delete `areaMarker` from `LifeOSPainters` and `AreaKeyColors`/`areaKeys` from tokens only if nothing else reads them (`grep -rn "areaKeys\|areaMarker" lib test`); keep `LifeOSArea.letter` only if referenced.
- `journal_sheet.dart:147`: the Area cell becomes `Row(mainAxisSize: MainAxisSize.min, children: [AreaKey(area: entry.area), const SizedBox(width: 4), Text(entry.area.label)])`; widen that column by 50 px.
- `TaskLink` gets `this.icon` / `final EraIconKind? icon;` and, inside its `Container`, a `Row(children: [if (icon != null) ...[EraIcon(icon!, disabled: !enabled), const SizedBox(width: 6)], Flexible(child: Text(...)))])`.
- `InspectorTitle` gets `this.icon` / `final EraIconKind? icon;`, painting `EraIcon(icon!, size: 32)` left of the title with 8 px between.
- `work_record_names.dart`:

```dart
EraIconKind recordIcon(WorkRecordProjection record) => switch (record) {
  ShiftRecordProjection() => EraIconKind.shift,
  PayPeriodRecordProjection() => EraIconKind.payPeriod,
  PayslipRecordProjection() => EraIconKind.payslip,
  EmploymentRecordProjection() => EraIconKind.employment,
  AgreementRecordProjection() => EraIconKind.agreement,
};
```

- `work_tasks.dart`: entries become triples `(label, icon, action)`; `TaskLink(label: label, icon: icon, onPressed: action)`. Icons:

| Link | Icon |
|---|---|
| Add a shift, New pay period | `add` |
| Record payslip, Record payslip… | `recordPayslip` |
| Set up pay agreement… | `agreement` |
| Employment properties, Properties | `properties` |
| Save this view… | `saveView` |
| Finalize this shift, Mark this period reviewed | `reviewed` |
| Correct this shift…, Correct this payslip… | `correct` |
| Reopen this period | `payPeriod` |

  `RecordSummary`'s first line becomes a `Row` of `EraIcon(recordIcon(record))` and the bold name.
- `desk_host.dart` Desk tasks: New desk → `newDesk`, Rename desk… → `correct`, Reset desk → `newDesk`, Delete desk → `delete`.
- Inspector titles get record icons: `work_inspector.dart` 'Shift finalized' → `EraIconKind.shift`, 'Paid evidence' (twice: `work_inspector.dart`, `period_payslip_forms.dart`) → `payslip`; `period_payslip_forms.dart` period title → `payPeriod`; `shift_forms.dart` 'Finalize shift' → `shift`; `EmploymentHeader` and `AgreementView` titles → `employment` / `agreement`.

- [ ] **Step 4: Run and commit**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS except goldens. The glyph test in `test/shared/workbench/era_controls_test.dart` must still pass.

```bash
git add -A lib test
git commit -m "feat: paint era icons for areas, records and tasks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: LifeOS's own window frame

**Files:**
- Create: `lib/shared/shell/era_window_frame.dart`, `lib/app/window_controls.dart`
- Modify: `linux/runner/my_application.cc:27-53`, `lib/app/desktop_window_service.dart`, `lib/app/lifeos_app.dart`, `lib/main.dart`, `lib/app/shell_host.dart`, `lib/shared/shell/status_line.dart`, `lib/shared/workbench/millennium_style.dart`, `test/shared/workbench/lifeos_tokens_test.dart`
- Test: `test/shared/shell/era_window_frame_test.dart` (new), `test/shared/shell/status_line_test.dart`

**Interfaces:**
- Consumes: `EraIcon(EraIconKind.app)` (Task 7); `typography.caption` (Task 6).
- Produces (all in `era_window_frame.dart`):
  - `enum WindowEdge { top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight }`
  - `WindowFrameState({bool maximized = false, bool active = true})`
  - `abstract interface class WindowControls { ValueListenable<WindowFrameState> get state; Future<void> minimize(); Future<void> toggleMaximize(); Future<void> close(); Future<void> startDragging(); Future<void> startResizing(WindowEdge edge); Future<void> setTitle(String title); }`
  - `InertWindowControls` (tests, goldens): paints the frame, does nothing.
  - `WindowControlsScope.maybeOf(BuildContext) -> WindowControls?`
  - `WindowTitleController extends ValueNotifier<String?>`, `WindowTitleScope`
  - `EraWindowFrame({required WindowControls controls, required WindowTitleController title, required Widget child})`
  - `WindowManagerControls implements WindowControls` (in `lib/app/window_controls.dart`)
  - `LifeOsApp({required GoRouter router, VoidCallback? onQuit, WindowControls? window})`

- [ ] **Step 1: Write the failing frame tests**

```dart
// test/shared/shell/era_window_frame_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/era_window_frame.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

final class _FakeControls implements WindowControls {
  final calls = <String>[];
  final _state = ValueNotifier(const WindowFrameState());

  @override
  ValueListenable<WindowFrameState> get state => _state;
  set frame(WindowFrameState value) => _state.value = value;

  @override
  Future<void> minimize() async => calls.add('minimize');
  @override
  Future<void> toggleMaximize() async => calls.add('toggleMaximize');
  @override
  Future<void> close() async => calls.add('close');
  @override
  Future<void> startDragging() async => calls.add('drag');
  @override
  Future<void> startResizing(WindowEdge edge) async => calls.add('resize $edge');
  @override
  Future<void> setTitle(String title) async => calls.add('title $title');
}

Future<_FakeControls> _pump(WidgetTester tester, {String? title}) async {
  final controls = _FakeControls();
  final titles = WindowTitleController()..value = title;
  addTearDown(titles.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: LifeOSSkinScope(
        child: EraWindowFrame(
          controls: controls,
          title: titles,
          child: const ColoredBox(color: Color(0xffece9d8)),
        ),
      ),
    ),
  );
  return controls;
}

void main() {
  testWidgets('the caption names the location and the app', (tester) async {
    final controls = await _pump(tester, title: 'Shifts');
    expect(find.text('Shifts - LifeOS'), findsOneWidget);
    await tester.pump();
    expect(controls.calls, contains('title Shifts - LifeOS'));
  });

  testWidgets('caption keys minimize, maximize and close', (tester) async {
    final controls = await _pump(tester);
    expect(find.text('LifeOS'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Minimize'));
    await tester.tap(find.bySemanticsLabel('Maximize'));
    await tester.tap(find.bySemanticsLabel('Close'));
    expect(controls.calls, containsAllInOrder(['minimize', 'toggleMaximize', 'close']));
  });

  testWidgets('dragging the caption moves; double-clicking maximizes', (
    tester,
  ) async {
    final controls = await _pump(tester);
    await tester.drag(find.text('LifeOS'), const Offset(40, 0));
    expect(controls.calls, contains('drag'));
    await tester.tap(find.text('LifeOS'));
    await tester.tap(find.text('LifeOS'));
    await tester.pumpAndSettle();
    expect(controls.calls, contains('toggleMaximize'));
  });

  testWidgets('maximized: Restore, no border, no resize edges', (tester) async {
    final controls = await _pump(tester);
    expect(find.byKey(const ValueKey('window-edge-bottomRight')), findsOneWidget);
    controls.frame = const WindowFrameState(maximized: true);
    await tester.pump();
    expect(find.bySemanticsLabel('Restore'), findsOneWidget);
    expect(find.byKey(const ValueKey('window-edge-bottomRight')), findsNothing);
  });

  testWidgets('a border edge starts a resize from that edge', (tester) async {
    final controls = await _pump(tester);
    await tester.drag(
      find.byKey(const ValueKey('window-edge-right')),
      const Offset(20, 0),
    );
    expect(controls.calls, contains('resize WindowEdge.right'));
  });
}
```

Move `_FakeControls` into `test/support/fake_window_controls.dart` as a public `FakeWindowControls` (same body) and import it from both test files. Add to `status_line_test.dart`:

```dart
  testWidgets('the size grip shows unless maximized and resizes the corner', (
    tester,
  ) async {
    final controls = FakeWindowControls();
    await tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: WindowControlsScope(
                controls: controls,
                child: const StatusLine(snapshot: StatusSnapshot()),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('size-grip')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('size-grip')),
      const Offset(20, 20),
    );
    expect(controls.calls, contains('resize WindowEdge.bottomRight'));
    controls.frame = const WindowFrameState(maximized: true);
    await tester.pump();
    expect(find.byKey(const ValueKey('size-grip')), findsNothing);
  });
```

- [ ] **Step 2: Add the frame colours**

In `MillenniumColors`:

```dart
  // Window frame and caption (XP-authentic shell spec 5).
  static const frameActive = Color(0xff0831d9);
  static const frameInactive = Color(0xff7b8fd6);
  static const windowCaptionLight = Color(0xff3d95ff);
  static const windowCaptionDeep = Color(0xff0040c8);
  static const inactiveCaptionLight = Color(0xff9db3ec);
  static const inactiveCaption = Color(0xff5670c4);
  static const captionShadow = Color(0xff0a1a64);
  static const captionKeyTop = Color(0xff5a8ff8);
  static const captionKeyBottom = Color(0xff2259d8);
```

Add to `lifeos_tokens_test.dart`:

```dart
  test('caption titles read on their caption, active and inactive', () {
    expect(contrast(const Color(0xffffffff), LifeOSTokens.millennium.head), greaterThanOrEqualTo(4.5));
    expect(contrast(const Color(0xffffffff), MillenniumColors.inactiveCaption), greaterThanOrEqualTo(4.5));
  });
```

(use the file's existing contrast helper name).

- [ ] **Step 3: Implement `era_window_frame.dart`**

```dart
// lib/shared/shell/era_window_frame.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/era_icons.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

enum WindowEdge {
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

@immutable
final class WindowFrameState {
  const WindowFrameState({this.maximized = false, this.active = true});

  final bool maximized;
  final bool active;

  @override
  bool operator ==(Object other) =>
      other is WindowFrameState &&
      other.maximized == maximized &&
      other.active == active;

  @override
  int get hashCode => Object.hash(maximized, active);
}

/// What the painted caption asks of the real window.
abstract interface class WindowControls {
  ValueListenable<WindowFrameState> get state;
  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
  Future<void> startDragging();
  Future<void> startResizing(WindowEdge edge);
  Future<void> setTitle(String title);
}

/// A frame with no window behind it, for tests and goldens.
final class InertWindowControls implements WindowControls {
  InertWindowControls();

  final _state = ValueNotifier(const WindowFrameState());

  @override
  ValueListenable<WindowFrameState> get state => _state;
  @override
  Future<void> minimize() async {}
  @override
  Future<void> toggleMaximize() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> startDragging() async {}
  @override
  Future<void> startResizing(WindowEdge edge) async {}
  @override
  Future<void> setTitle(String title) async {}
}

final class WindowControlsScope extends InheritedWidget {
  const WindowControlsScope({
    required this.controls,
    required super.child,
    super.key,
  });

  final WindowControls controls;

  static WindowControls? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WindowControlsScope>()
      ?.controls;

  @override
  bool updateShouldNotify(WindowControlsScope oldWidget) =>
      controls != oldWidget.controls;
}

/// The current location's name for the caption ("Shifts").
final class WindowTitleController extends ValueNotifier<String?> {
  WindowTitleController() : super(null);
}

final class WindowTitleScope extends InheritedNotifier<WindowTitleController> {
  const WindowTitleScope({
    required WindowTitleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static WindowTitleController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WindowTitleScope>()?.notifier;
}

/// The window as the era drew it: a blue frame and caption around the app.
final class EraWindowFrame extends StatefulWidget {
  const EraWindowFrame({
    required this.controls,
    required this.title,
    required this.child,
    super.key,
  });

  final WindowControls controls;
  final WindowTitleController title;
  final Widget child;

  static const border = 4.0;
  static const captionHeight = 30.0;

  @override
  State<EraWindowFrame> createState() => _EraWindowFrameState();
}

final class _EraWindowFrameState extends State<EraWindowFrame> {
  String _caption() {
    final title = widget.title.value;
    return title == null ? 'LifeOS' : '$title - LifeOS';
  }

  void _syncTitle() {
    widget.controls.setTitle(_caption());
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.title.addListener(_syncTitle);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controls.setTitle(_caption()),
    );
  }

  @override
  void didUpdateWidget(covariant EraWindowFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      oldWidget.title.removeListener(_syncTitle);
      widget.title.addListener(_syncTitle);
    }
  }

  @override
  void dispose() {
    widget.title.removeListener(_syncTitle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controls = widget.controls;
    return WindowControlsScope(
      controls: controls,
      child: WindowTitleScope(
        controller: widget.title,
        child: ValueListenableBuilder<WindowFrameState>(
          valueListenable: controls.state,
          builder: (context, state, _) {
            final edge = state.maximized ? 0.0 : EraWindowFrame.border;
            final frame = state.active
                ? MillenniumColors.frameActive
                : MillenniumColors.frameInactive;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: frame,
                borderRadius: state.maximized
                    ? null
                    : const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(edge, 0, edge, edge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Caption(
                          title: _caption(),
                          state: state,
                          controls: controls,
                        ),
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                  if (!state.maximized) ..._edges(controls),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _edges(WindowControls controls) {
    const b = EraWindowFrame.border;
    const corner = 12.0;
    Widget edge(
      WindowEdge which,
      SystemMouseCursor cursor, {
      double? left,
      double? top,
      double? right,
      double? bottom,
      double? width,
      double? height,
    }) => Positioned(
      key: ValueKey('window-edge-${which.name}'),
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => controls.startResizing(which),
        ),
      ),
    );
    return [
      edge(WindowEdge.top, SystemMouseCursors.resizeUp, left: corner, right: corner, top: 0, height: b),
      edge(WindowEdge.bottom, SystemMouseCursors.resizeDown, left: corner, right: corner, bottom: 0, height: b),
      edge(WindowEdge.left, SystemMouseCursors.resizeLeft, left: 0, top: corner, bottom: corner, width: b),
      edge(WindowEdge.right, SystemMouseCursors.resizeRight, right: 0, top: corner, bottom: corner, width: b),
      edge(WindowEdge.topLeft, SystemMouseCursors.resizeUpLeft, left: 0, top: 0, width: corner, height: b),
      edge(WindowEdge.topRight, SystemMouseCursors.resizeUpRight, right: 0, top: 0, width: corner, height: b),
      edge(WindowEdge.bottomLeft, SystemMouseCursors.resizeDownLeft, left: 0, bottom: 0, width: corner, height: corner),
      edge(WindowEdge.bottomRight, SystemMouseCursors.resizeDownRight, right: 0, bottom: 0, width: corner, height: corner),
    ];
  }
}

final class _Caption extends StatelessWidget {
  const _Caption({
    required this.title,
    required this.state,
    required this.controls,
  });

  final String title;
  final WindowFrameState state;
  final WindowControls controls;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final colors = state.active
        ? [
            MillenniumColors.windowCaptionLight,
            MillenniumColors.captionTop,
            tokens.head,
            MillenniumColors.windowCaptionDeep,
          ]
        : [
            MillenniumColors.inactiveCaptionLight,
            MillenniumColors.inactiveCaption,
            MillenniumColors.inactiveCaption,
            MillenniumColors.frameInactive,
          ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => controls.startDragging(),
      onDoubleTap: controls.toggleMaximize,
      child: Container(
        height: EraWindowFrame.captionHeight,
        padding: const EdgeInsets.only(left: 6, right: 4),
        decoration: BoxDecoration(
          borderRadius: state.maximized
              ? null
              : const BorderRadius.vertical(top: Radius.circular(8)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: const [0, 0.12, 0.6, 1],
          ),
        ),
        child: Row(
          children: [
            const EraIcon(EraIconKind.app),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: skin.typography.caption.copyWith(
                  color: tokens.headInk,
                  // The era's caption text shadow: the style's one shadow.
                  shadows: const [
                    Shadow(
                      color: MillenniumColors.captionShadow,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
            _CaptionKey(
              label: 'Minimize',
              glyph: _CaptionGlyph.minimize,
              faded: !state.active,
              onPressed: controls.minimize,
            ),
            _CaptionKey(
              label: state.maximized ? 'Restore' : 'Maximize',
              glyph: state.maximized
                  ? _CaptionGlyph.restore
                  : _CaptionGlyph.maximize,
              faded: !state.active,
              onPressed: controls.toggleMaximize,
            ),
            _CaptionKey(
              label: 'Close',
              glyph: _CaptionGlyph.close,
              faded: !state.active,
              onPressed: controls.close,
            ),
          ],
        ),
      ),
    );
  }
}

enum _CaptionGlyph { minimize, maximize, restore, close }

final class _CaptionKey extends StatelessWidget {
  const _CaptionKey({
    required this.label,
    required this.glyph,
    required this.faded,
    required this.onPressed,
  });

  final String label;
  final _CaptionGlyph glyph;
  final bool faded;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final close = glyph == _CaptionGlyph.close;
    return EraPressable(
      label: label,
      onPressed: onPressed,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Opacity(
            opacity: faded ? 0.6 : 1,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(3)),
                border: Border.all(color: const Color(0xffffffff)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: close
                      ? const [MillenniumColors.closeTop, MillenniumColors.closeBottom]
                      : const [MillenniumColors.captionKeyTop, MillenniumColors.captionKeyBottom],
                ),
              ),
              child: CustomPaint(painter: _GlyphPainter(glyph)),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph);

  final _CaptionGlyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xffffffff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final w = size.width;
    switch (glyph) {
      case _CaptionGlyph.minimize:
        canvas.drawLine(Offset(w * 0.3, w * 0.72), Offset(w * 0.6, w * 0.72), ink);
      case _CaptionGlyph.maximize:
        canvas.drawRect(Rect.fromLTRB(w * 0.27, w * 0.27, w * 0.73, w * 0.73), ink..strokeWidth = 1);
        canvas.drawLine(Offset(w * 0.27, w * 0.3), Offset(w * 0.73, w * 0.3), ink..strokeWidth = 2);
      case _CaptionGlyph.restore:
        final thin = ink..strokeWidth = 1;
        canvas.drawRect(Rect.fromLTRB(w * 0.4, w * 0.22, w * 0.76, w * 0.55), thin);
        canvas.drawRect(Rect.fromLTRB(w * 0.24, w * 0.42, w * 0.6, w * 0.76), thin);
      case _CaptionGlyph.close:
        canvas
          ..drawLine(Offset(w * 0.3, w * 0.3), Offset(w * 0.7, w * 0.7), ink)
          ..drawLine(Offset(w * 0.7, w * 0.3), Offset(w * 0.3, w * 0.7), ink);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.glyph != glyph;
}
```

The caption title also includes `EraIcon(EraIconKind.app)`, which is silent; the Row's text is the caption's semantics. Mark the caption `Semantics(header: true, …)` around the title `Text`.

Run: `flutter test test/shared/shell/era_window_frame_test.dart` — PASS. The double-tap test relies on `GestureDetector.onDoubleTap`; `pumpAndSettle` after two taps flushes the double-tap timer.

- [ ] **Step 4: The size grip**

In `status_line.dart`, after the last `_Panel`, add:

```dart
            if (WindowControlsScope.maybeOf(context) case final controls?)
              ValueListenableBuilder<WindowFrameState>(
                valueListenable: controls.state,
                builder: (context, state, _) => state.maximized
                    ? const SizedBox.shrink()
                    : _SizeGrip(controls: controls),
              ),
```

```dart
/// Diagonal dots at the status bar's right end; dragging resizes the
/// window from its bottom-right corner.
final class _SizeGrip extends StatelessWidget {
  const _SizeGrip({required this.controls});

  final WindowControls controls;

  @override
  Widget build(BuildContext context) => MouseRegion(
    key: const ValueKey('size-grip'),
    cursor: SystemMouseCursors.resizeDownRight,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => controls.startResizing(WindowEdge.bottomRight),
      child: const SizedBox(
        width: 14,
        child: CustomPaint(painter: _GripPainter()),
      ),
    ),
  );
}

final class _GripPainter extends CustomPainter {
  const _GripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = MillenniumColors.sunkenEdge;
    final light = Paint()..color = const Color(0xffffffff);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col <= row; col++) {
        final x = size.width - 4 - col * 4.0;
        final y = size.height - 4 - (row - col) * 4.0;
        canvas
          ..drawRect(Rect.fromLTWH(x + 1, y + 1, 2, 2), light)
          ..drawRect(Rect.fromLTWH(x, y, 2, 2), dark);
      }
    }
  }

  @override
  bool shouldRepaint(_GripPainter oldDelegate) => false;
}
```

Import `package:flutter/services.dart` and `era_window_frame.dart`.

- [ ] **Step 5: The real window**

```dart
// lib/app/window_controls.dart
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../shared/shell/era_window_frame.dart';

/// The painted frame's requests, carried out by window_manager.
final class WindowManagerControls with WindowListener implements WindowControls {
  WindowManagerControls() {
    windowManager.addListener(this);
    _sync();
  }

  final _state = ValueNotifier(const WindowFrameState());

  @override
  ValueListenable<WindowFrameState> get state => _state;

  Future<void> _sync() async {
    _state.value = WindowFrameState(
      maximized: await windowManager.isMaximized(),
      active: await windowManager.isFocused(),
    );
  }

  @override
  void onWindowMaximize() => _sync();
  @override
  void onWindowUnmaximize() => _sync();
  @override
  void onWindowFocus() => _sync();
  @override
  void onWindowBlur() => _sync();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async => await windowManager.isMaximized()
      ? windowManager.unmaximize()
      : windowManager.maximize();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> startResizing(WindowEdge edge) =>
      windowManager.startResizing(switch (edge) {
        WindowEdge.top => ResizeEdge.top,
        WindowEdge.bottom => ResizeEdge.bottom,
        WindowEdge.left => ResizeEdge.left,
        WindowEdge.right => ResizeEdge.right,
        WindowEdge.topLeft => ResizeEdge.topLeft,
        WindowEdge.topRight => ResizeEdge.topRight,
        WindowEdge.bottomLeft => ResizeEdge.bottomLeft,
        WindowEdge.bottomRight => ResizeEdge.bottomRight,
      });

  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);
}
```

- `desktop_window_service.dart`: add `titleBarStyle: TitleBarStyle.hidden,` to `WindowOptions`.
- `linux/runner/my_application.cc`: replace the whole `use_header_bar` block (comment through the `else` branch) with:

```cpp
  // LifeOS paints its own era caption and frame (XP-authentic shell spec 5),
  // so the window starts undecorated and no system frame flashes on launch.
  gtk_window_set_title(window, "LifeOS");
  gtk_window_set_decorated(window, FALSE);
```

- `lifeos_app.dart`: add `final WindowControls? window;` (constructor `this.window`), `late final _inertWindow = InertWindowControls();`, `final _title = WindowTitleController();` (dispose it), and in `builder` wrap the innermost `Theme(...)` child: `EraWindowFrame(controls: widget.window ?? _inertWindow, title: _title, child: child ?? const SizedBox.shrink())`. The frame must sit inside `LifeOSSkinScope` and `Theme`.
- `main.dart`: `LifeOsApp(router: createAppRouter(), onQuit: window.close, window: WindowManagerControls())`.
- `shell_host.dart` (`ShellChromeHost.build`): after computing `crumbs`, publish the title once per change:

```dart
    final title = crumbs.lastOrNull?.label;
    final titles = WindowTitleScope.read(context);
    if (titles != null && titles.value != title) {
      WidgetsBinding.instance.addPostFrameCallback((_) => titles.value = title);
    }
```

  Use the crumbs list the method already builds (`_crumbs(location, employmentName)`) — hoist it into a local first.

- [ ] **Step 6: Run, check on the desktop, commit**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS except goldens.
Then: `flutter run -d linux` — check by eye: no GNOME header bar; caption drags the window; double-click maximizes and the border/grip go; edges and the grip resize; Minimize/Close work; clicking another window fades the caption. Record the result in the commit message body if anything differs on Wayland.

```bash
git add -A lib test linux
git commit -m "feat: paint LifeOS's own era window caption, frame and size grip

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Era scrollbars, then slice-2 goldens

**Files:**
- Create: `lib/shared/workbench/era_scrollbar.dart`
- Modify: `lib/app/lifeos_app.dart` (`scrollBehavior`), `lib/shared/workbench/data_register.dart:404` (drop `Scrollbar`), `lib/shared/workbench/millennium_style.dart`, `test/shared/workbench/lifeos_tokens_test.dart`
- Test: `test/shared/workbench/era_scrollbar_test.dart` (new)

**Interfaces:**
- Produces: `EraScrollbar({required ScrollController controller, required Axis axis, required Widget child})`, `EraScrollBehavior` (`const`), `EraScrollbar.thickness == 17`, keys `era-scrollbar-thumb`, `era-scrollbar-back`, `era-scrollbar-forward`, `era-scrollbar-track`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/workbench/era_scrollbar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_scrollbar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

Widget _host(Widget child) => MaterialApp(
  scrollBehavior: const EraScrollBehavior(),
  home: LifeOSSkinScope(child: Scaffold(body: child)),
);

Widget _list(int count, ScrollController controller) => SizedBox(
  height: 200,
  width: 300,
  child: ListView(
    controller: controller,
    children: [
      for (var i = 0; i < count; i++)
        SizedBox(height: 20, child: Text('Row $i')),
    ],
  ),
);

void main() {
  testWidgets('a list that overflows gets a 17 px bar; a short one none', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_list(100, controller)));
    await tester.pump();
    expect(find.byKey(const ValueKey('era-scrollbar-thumb')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('era-scrollbar-track'))).width,
      EraScrollbar.thickness,
    );
    await tester.pumpWidget(_host(_list(3, ScrollController())));
    await tester.pump();
    expect(find.byKey(const ValueKey('era-scrollbar-thumb')), findsNothing);
  });

  testWidgets('arrows step a row; the track pages', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_list(100, controller)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('era-scrollbar-forward')));
    await tester.pump();
    expect(controller.offset, 20);
    final track = tester.getRect(find.byKey(const ValueKey('era-scrollbar-track')));
    await tester.tapAt(Offset(track.center.dx, track.bottom - 4));
    await tester.pump();
    expect(controller.offset, greaterThanOrEqualTo(200));
  });

  testWidgets('dragging the thumb scrolls', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(_list(100, controller)));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('era-scrollbar-thumb')),
      const Offset(0, 40),
    );
    await tester.pump();
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('a one-line text field never gets a bar', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 80,
          child: TextField(
            controller: TextEditingController(text: 'x' * 200),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('era-scrollbar-thumb')), findsNothing);
  });
}
```

- [ ] **Step 2: Colours**

```dart
  // Scrollbars (XP-authentic shell spec 6.2).
  static const scrollTrack = Color(0xfff4f3ee);
  static const scrollTrackEdge = Color(0xffeeede5);
  static const scrollFaceTop = Color(0xffcadaff);
  static const scrollFaceBottom = Color(0xffb5c9f7);
  static const scrollFaceEdge = Color(0xff98b0e8);
  static const scrollGripLight = Color(0xffeef4fe);
  static const scrollGripDark = Color(0xff8cb0f8);
```

Contrast test addition: `contrast(MillenniumColors.comboArrowInk, MillenniumColors.scrollFaceBottom) >= 3`.

- [ ] **Step 3: Implement**

```dart
// lib/shared/workbench/era_scrollbar.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'era_controls.dart';
import 'millennium_style.dart';

/// Gives every scroll area the era scrollbar and no overscroll glow.
/// One-line text fields ask for no scrollbar and get none.
final class EraScrollBehavior extends MaterialScrollBehavior {
  const EraScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final controller = details.controller;
    if (controller == null) return child;
    return EraScrollbar(
      controller: controller,
      axis: axisDirectionToAxis(details.direction),
      child: child,
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// A 17 px era scrollbar beside (or under) its scroll area: arrow keys at
/// both ends, a pale track and a blue thumb with grip lines. Shown only
/// while the content overflows.
final class EraScrollbar extends StatefulWidget {
  const EraScrollbar({
    required this.controller,
    required this.axis,
    required this.child,
    super.key,
  });

  static const thickness = 17.0;
  static const step = 20.0;

  final ScrollController controller;
  final Axis axis;
  final Widget child;

  @override
  State<EraScrollbar> createState() => _EraScrollbarState();
}

final class _EraScrollbarState extends State<EraScrollbar> {
  ScrollMetrics? _metrics;
  Timer? _repeat;

  bool get _vertical => widget.axis == Axis.vertical;

  void _update(ScrollMetrics metrics) {
    if (metrics.axis != widget.axis) return;
    final old = _metrics;
    if (old != null &&
        old.pixels == metrics.pixels &&
        old.minScrollExtent == metrics.minScrollExtent &&
        old.maxScrollExtent == metrics.maxScrollExtent &&
        old.viewportDimension == metrics.viewportDimension) {
      return;
    }
    setState(() => _metrics = metrics.copyWith());
  }

  void _scrollBy(double delta) {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    widget.controller.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _startRepeat(double delta) {
    _scrollBy(delta);
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _scrollBy(delta),
      );
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _update(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _update(notification.metrics);
          return false;
        },
        child: widget.child,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Without bounded room there is nothing to overflow; the structure
        // stays fixed for a given parent, so scroll state is never rebuilt.
        if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
          return content;
        }
        final metrics = _metrics;
        final overflow =
            metrics != null && metrics.maxScrollExtent > metrics.minScrollExtent;
        final bar = SizedBox(
          width: _vertical ? (overflow ? EraScrollbar.thickness : 0) : null,
          height: _vertical ? null : (overflow ? EraScrollbar.thickness : 0),
          child: overflow ? _bar(metrics) : null,
        );
        return _vertical
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Expanded(child: content), bar],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Expanded(child: content), bar],
              );
      },
    );
  }

  Widget _bar(ScrollMetrics metrics) {
    final children = [
      _ArrowKey(
        key: const ValueKey('era-scrollbar-back'),
        glyph: _vertical ? EraGlyphKind.collapse : EraGlyphKind.stepBack,
        onDown: () => _startRepeat(-EraScrollbar.step),
        onUp: _stopRepeat,
      ),
      Expanded(
        child: LayoutBuilder(
          key: const ValueKey('era-scrollbar-track'),
          builder: (context, constraints) {
            final track = _vertical
                ? constraints.maxHeight
                : constraints.maxWidth;
            final range = metrics.maxScrollExtent - metrics.minScrollExtent;
            final thumb = math.max(
              EraScrollbar.thickness,
              track *
                  metrics.viewportDimension /
                  (range + metrics.viewportDimension),
            );
            final travel = math.max(0.0, track - thumb);
            final offset = range == 0
                ? 0.0
                : travel * (metrics.pixels - metrics.minScrollExtent) / range;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final at = _vertical
                    ? details.localPosition.dy
                    : details.localPosition.dx;
                _scrollBy(
                  at < offset
                      ? -metrics.viewportDimension
                      : metrics.viewportDimension,
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: _vertical
                        ? Alignment.centerLeft
                        : Alignment.topCenter,
                    end: _vertical
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                    colors: const [
                      MillenniumColors.scrollTrackEdge,
                      MillenniumColors.scrollTrack,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: _vertical ? 0 : offset,
                      right: _vertical ? 0 : null,
                      top: _vertical ? offset : 0,
                      bottom: _vertical ? null : 0,
                      width: _vertical ? null : thumb,
                      height: _vertical ? thumb : null,
                      child: GestureDetector(
                        key: const ValueKey('era-scrollbar-thumb'),
                        onVerticalDragUpdate: _vertical && travel > 0
                            ? (details) =>
                                  _scrollBy(details.delta.dy * range / travel)
                            : null,
                        onHorizontalDragUpdate: !_vertical && travel > 0
                            ? (details) =>
                                  _scrollBy(details.delta.dx * range / travel)
                            : null,
                        child: _Face(grip: true, vertical: _vertical),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      _ArrowKey(
        key: const ValueKey('era-scrollbar-forward'),
        glyph: _vertical ? EraGlyphKind.expand : EraGlyphKind.stepForward,
        onDown: () => _startRepeat(EraScrollbar.step),
        onUp: _stopRepeat,
      ),
    ];
    // Decorative for screen readers: the scroll area itself is announced
    // and scrolled by them.
    return ExcludeSemantics(
      child: _vertical ? Column(children: children) : Row(children: children),
    );
  }
}

final class _ArrowKey extends StatelessWidget {
  const _ArrowKey({
    required this.glyph,
    required this.onDown,
    required this.onUp,
    super.key,
  });

  final EraGlyphKind glyph;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => onDown(),
    onTapUp: (_) => onUp(),
    onTapCancel: onUp,
    child: SizedBox.square(
      dimension: EraScrollbar.thickness,
      child: _Face(
        grip: false,
        vertical: true,
        child: Center(
          child: EraGlyph(glyph, color: MillenniumColors.comboArrowInk, size: 7),
        ),
      ),
    ),
  );
}

final class _Face extends StatelessWidget {
  const _Face({required this.grip, required this.vertical, this.child});

  final bool grip;
  final bool vertical;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(0.5),
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.all(Radius.circular(3)),
      border: Border.all(color: MillenniumColors.scrollFaceEdge),
      gradient: LinearGradient(
        begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
        end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
        colors: const [
          MillenniumColors.scrollFaceTop,
          MillenniumColors.scrollFaceBottom,
        ],
      ),
    ),
    child: grip
        ? CustomPaint(painter: _GripLines(vertical: vertical))
        : child,
  );
}

final class _GripLines extends CustomPainter {
  const _GripLines({required this.vertical});

  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = MillenniumColors.scrollGripLight;
    final dark = Paint()..color = MillenniumColors.scrollGripDark;
    final centre = size.center(Offset.zero);
    for (var i = -1; i <= 1; i++) {
      if (vertical) {
        final y = centre.dy + i * 2.0;
        canvas
          ..drawLine(Offset(centre.dx - 3, y), Offset(centre.dx + 3, y), light)
          ..drawLine(
            Offset(centre.dx - 3, y + 1),
            Offset(centre.dx + 3, y + 1),
            dark,
          );
      } else {
        final x = centre.dx + i * 2.0;
        canvas
          ..drawLine(Offset(x, centre.dy - 3), Offset(x, centre.dy + 3), light)
          ..drawLine(
            Offset(x + 1, centre.dy - 3),
            Offset(x + 1, centre.dy + 3),
            dark,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_GripLines oldDelegate) => oldDelegate.vertical != vertical;
}
```

The `EraGlyph` kinds `collapse`/`expand` are the double chevrons; if they read wrong at 7 px, add `EraGlyphKind.arrowUp`/`arrowDown` (solid triangles) to `era_controls.dart` alongside `sortUp`/`sortDown` (reuse the sort-triangle painter) and use those instead.

- [ ] **Step 4: Wire it in**

- `lifeos_app.dart`: `MaterialApp.router(scrollBehavior: const EraScrollBehavior(), …)`.
- `data_register.dart`: replace `Scrollbar(controller: _horizontal, child: SingleChildScrollView(…))` with the `SingleChildScrollView` alone.
- Golden and widget tests that pump widgets outside `LifeOsApp` keep Flutter's default behaviour; that is fine.

- [ ] **Step 5: Slice-2 goldens and a look**

Run:
```bash
flutter analyze lib test tool && flutter test --exclude-tags real-font --update-goldens test/goldens
flutter test --run-skipped -t real-font --update-goldens test/goldens/real_font_check_test.dart
flutter test
```
Open each PNG under `test/goldens/real_font/`. Check: caption with app glyph, "Shifts - LifeOS" and the three keys; EraSans everywhere (no Noto shapes); bold text kerning (the Wine bold has a known gap in some letter pairs — if a label like "Pay agreement" shows a visible gap, note it in the commit body; it is a font defect, not a layout bug); icons in Books, tasks and Properties; the scrollbar on the Pay agreement dialog; Details text fits 176 px.

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "feat: give every scroll area the era scrollbar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

# Slice 3 — Era Sweep and Forms

### Task 10: The Address bar as a path combo

**Files:**
- Modify: `lib/shared/shell/address_bar.dart`, `lib/shared/shell/shell_frame.dart` (`ShellChrome`), `lib/app/shell_host.dart`
- Test: `test/shared/shell/address_bar_test.dart`

**Interfaces:**
- Consumes: `EraIcon`, `areaIcon` (Task 7); `TreeNode`, `TreeSheet`, `TreeGroup`, `TreeArea` (`book_tree.dart`).
- Produces:
  - `AddressLocation(String label, String route, {int depth = 0, EraIconKind? icon})`
  - `List<AddressLocation> addressTreeFrom(List<TreeNode> nodes)`
  - `AddressBar({required List<AddressCrumb> crumbs, required List<AddressLocation> tree, EraIconKind? icon, required ValueChanged<String> onNavigate, required VoidCallback onGo})`
  - `ShellChrome` gains `addressTree` (`List<AddressLocation>`, default `const []`) and `addressIcon` (`EraIconKind?`).

- [ ] **Step 1: Write the failing tests**

Replace the crumb tests in `test/shared/shell/address_bar_test.dart` with:

```dart
  testWidgets('the location reads as a path, without crumbs', (tester) async {
    await tester.pumpWidget(
      _host( // existing helper
        AddressBar(
          crumbs: const [
            AddressCrumb('Work', '/work'),
            AddressCrumb('Synthetic depot', '/work?employment=e'),
            AddressCrumb('Shifts', '/work?employment=e&sheet=shifts'),
          ],
          tree: const [],
          icon: EraIconKind.work,
          onNavigate: (_) {},
          onGo: () {},
        ),
      ),
    );
    expect(find.text(r'Work\Synthetic depot\Shifts'), findsOneWidget);
    expect(find.textContaining('›'), findsNothing);
  });

  testWidgets('the drop arrow lists the locations and opens one', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _host(
        AddressBar(
          crumbs: const [AddressCrumb('Today', '/today')],
          tree: const [
            AddressLocation('Today', '/today'),
            AddressLocation('Journal', '/journal'),
            AddressLocation('Work', '/work', icon: EraIconKind.work),
            AddressLocation('Synthetic depot', '/work?employment=e', depth: 1),
          ],
          onNavigate: opened.add,
          onGo: () {},
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Address, Today'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic depot'), findsOneWidget);
    await tester.tap(find.text('Synthetic depot'));
    await tester.pumpAndSettle();
    expect(opened, ['/work?employment=e']);
  });

  test('the tree follows the book nodes', () {
    final tree = addressTreeFrom(const [
      TreeSheet(label: 'Today', route: '/today'),
      TreeGroup(label: 'Views', children: [
        TreeSheet(label: 'Night shifts', route: '/work?view=1'),
      ]),
      TreeArea(
        area: LifeOSArea.work,
        route: '/work',
        built: true,
        children: [TreeSheet(label: 'Synthetic depot', route: '/work?employment=e')],
      ),
      TreeArea(area: LifeOSArea.finance, route: '/finance', built: false),
    ]);
    expect(
      [for (final entry in tree) '${entry.depth}:${entry.label}'],
      ['0:Today', '0:Night shifts', '0:Work', '1:Synthetic depot', '0:Finance'],
    );
  });
```

- [ ] **Step 2: Implement**

In `address_bar.dart`: keep `AddressCrumb`. Add:

```dart
/// One entry in the Address drop-down's location tree.
@immutable
final class AddressLocation {
  const AddressLocation(this.label, this.route, {this.depth = 0, this.icon});

  final String label;
  final String route;
  final int depth;
  final EraIconKind? icon;

  @override
  bool operator ==(Object other) =>
      other is AddressLocation &&
      other.label == label &&
      other.route == route &&
      other.depth == depth &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(label, route, depth, icon);
}

/// The Address drop-down's tree, from the same nodes as Books.
List<AddressLocation> addressTreeFrom(List<TreeNode> nodes) => [
  for (final node in nodes)
    ...switch (node) {
      TreeSheet(:final label, :final route) => [AddressLocation(label, route)],
      TreeGroup(:final children) => [
        for (final sheet in children) AddressLocation(sheet.label, sheet.route),
      ],
      TreeArea(:final area, :final route, :final children) => [
        AddressLocation(area.label, route, icon: areaIcon(area)),
        for (final sheet in children)
          AddressLocation(sheet.label, sheet.route, depth: 1),
      ],
    },
];
```

Rewrite `AddressBar.build`'s white field as a combo (delete `_Crumb`):

```dart
            Expanded(
              child: Builder(
                builder: (fieldContext) => EraPressable(
                  label: 'Address, ${crumbs.map((c) => c.label).join(', ')}',
                  onPressed: () => _openTree(fieldContext),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 22),
                    padding: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: tokens.paper,
                      border: Border.all(color: MillenniumColors.fieldLine),
                    ),
                    child: Row(
                      children: [
                        if (icon case final icon?) ...[
                          EraIcon(icon),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            crumbs.map((crumb) => crumb.label).join(r'\'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body,
                          ),
                        ),
                        const ComboArrow(), // the filter row's blue drop-arrow button; see below
                      ],
                    ),
                  ),
                ),
              ),
            ),
```

```dart
  Future<void> _openTree(BuildContext fieldContext) async {
    final box = fieldContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height));
    final here = crumbs.lastOrNull?.route;
    final chosen = await showMenu<String>(
      context: fieldContext,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        origin.dx + box.size.width,
        origin.dy,
      ),
      constraints: BoxConstraints.tightFor(width: box.size.width),
      items: [
        for (final entry in tree)
          PopupMenuItem<String>(
            height: menuRowHeight,
            value: entry.route,
            child: Padding(
              padding: EdgeInsets.only(left: entry.depth * 16.0),
              child: Row(
                children: [
                  if (entry.icon case final icon?) ...[
                    EraIcon(icon),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    entry.label,
                    style: entry.route == here
                        ? const TextStyle(fontWeight: FontWeight.w700)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (chosen != null) onNavigate(chosen);
  }
```

`showMenu` and `PopupMenuItem` need `package:flutter/material.dart`; switch the file's import. `ComboArrow`: reuse the drop-arrow button `EraComboFace` paints (`lib/shared/workbench/era_controls.dart`); if it is private there, extract it as a public `ComboArrow` widget in `era_controls.dart` and use it from both places.

- [ ] **Step 3: Feed it**

- `ShellChrome`: add `this.addressTree = const []`, `this.addressIcon`, include both in `updateShouldNotify` (`!listEquals(addressTree, oldWidget.addressTree) || addressIcon != oldWidget.addressIcon`).
- `ShellFrame.build`: `AddressBar(crumbs: …, tree: chrome?.addressTree ?? const [], icon: chrome?.addressIcon, onNavigate: …, onGo: …)`.
- `ShellChromeHost.build`: `addressTree: addressTreeFrom(nodes)`, `addressIcon: switch (location.path) { '/work' => EraIconKind.work, '/finance' => EraIconKind.finance, '/tracking' => EraIconKind.tracking, '/knowledge' => EraIconKind.knowledge, '/today' => EraIconKind.payPeriod, '/journal' => EraIconKind.properties, _ => null }`.

- [ ] **Step 4: Run and commit**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS except goldens. Update tests that tapped a crumb link: they now open the drop-down and choose the entry.

```bash
git add -A lib test
git commit -m "feat: show the location as an era path with a location drop-down

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Menus without the app label or roadmap items; the licence dialog

**Files:**
- Create: `lib/shared/shell/licenses_dialog.dart`
- Modify: `lib/shared/shell/menu_bar.dart`, `lib/app/app_router.dart:50-65`
- Test: `test/shared/shell/menu_bar_test.dart` (create if absent), `test/shared/shell/licenses_dialog_test.dart` (new)

**Interfaces:**
- Produces: `LicensesDialog()` (an `EraDialog`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/shell/licenses_dialog_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/licenses_dialog.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  testWidgets('lists each package with its licence text', (tester) async {
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(['SyntheticPackage'], 'Synthetic terms.'),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: LifeOSSkinScope(child: Scaffold(body: LicensesDialog()))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Licenses'), findsOneWidget);
    expect(find.text('SyntheticPackage'), findsOneWidget);
    expect(find.textContaining('Synthetic terms.'), findsOneWidget);
  });
}
```

In the menu-bar test (pump `LifeOSMenuBar` under `LifeOSSkinScope` + `MaterialApp`):

```dart
  testWidgets('no app label and no roadmap items in the menus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SizedBox(
              height: 28,
              child: LifeOSMenuBar(onNavigate: (_) {}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('LifeOS'), findsNothing);
    for (final menu in ['File', 'Edit', 'View', 'Desk', 'Record', 'Window', 'Help']) {
      await tester.tap(find.text(menu));
      await tester.pumpAndSettle();
      expect(find.textContaining('later'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }
  });
```

- [ ] **Step 2: Implement**

```dart
// lib/shared/shell/licenses_dialog.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../workbench/era_dialog.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';
import '../workbench/office_controls.dart';

/// Help › About › Licenses: every package and font with its licence, in a
/// read-only white box.
final class LicensesDialog extends StatelessWidget {
  const LicensesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return EraDialog(
      title: 'Licenses',
      body: SizedBox(
        height: 360,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.paper,
            border: Border.all(color: MillenniumColors.fieldLine),
          ),
          child: FutureBuilder<List<LicenseEntry>>(
            future: LicenseRegistry.licenses.toList(),
            builder: (context, snapshot) {
              final entries = snapshot.data;
              if (entries == null) return const SizedBox.shrink();
              return ListView(
                padding: const EdgeInsets.all(6),
                children: [
                  for (final entry in entries) ...[
                    Text(
                      entry.packages.join(', '),
                      style: skin.typography.strong.copyWith(color: tokens.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.paragraphs.map((p) => p.text).join('\n\n'),
                      style: skin.typography.small.copyWith(color: tokens.ink),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        KeyButton(
          label: 'OK',
          kind: KeyKind.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
```

`menu_bar.dart`:
- Delete the `Padding(… Text('LifeOS' …))` before `MenuBar`.
- Delete every `later(…)` entry and the `later` helper, and the constants they used (`_desks`, `_history`) if now unused.
- The About dialog's **Licenses** key: `onPressed: () => showDialog<void>(context: context, builder: (_) => const LicensesDialog())`.

`app_router.dart:53,58,63`: the unavailable messages become `'Finance is not built yet.'`, `'Tracking is not built yet.'`, `'Knowledge is not built yet.'`.

- [ ] **Step 3: Toolbar bands with grippers (spec §3 item 3)**

Test first, in `test/shared/shell/shell_frame_test.dart` (its host helper provides `NavigationHistoryScope` and quick-add entries the way the existing toolbar tests do — reuse that setup):

```dart
  testWidgets('each toolbar band starts with a gripper', (tester) async {
    // pump the frame with history and one quick-add entry, as the existing
    // toolbar test in this file does
    expect(find.byKey(const ValueKey('toolbar-gripper')), findsNWidgets(2));
  });
```

Write the pump call by copying the existing toolbar test's setup verbatim. Then in `shell_frame.dart`'s `_Toolbar`, replace `separator()` with an etched vertical line and start each band (Back/Forward; Add; From last time) with a gripper:

```dart
    Widget etched() => Container(
      width: 2,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: tokens.chromeLine),
          right: BorderSide(color: tokens.paper),
        ),
      ),
    );
    Widget gripper() => const SizedBox(
      key: ValueKey('toolbar-gripper'),
      width: 6,
      height: 24,
      child: CustomPaint(painter: _GripperPainter()),
    );
```

```dart
/// The dotted handle at the left of a toolbar band.
final class _GripperPainter extends CustomPainter {
  const _GripperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xffffffff);
    final dark = Paint()..color = MillenniumColors.sunkenEdge;
    for (var y = 3.0; y < size.height - 3; y += 4) {
      canvas
        ..drawRect(Rect.fromLTWH(2, y + 1, 2, 2), light)
        ..drawRect(Rect.fromLTWH(1, y, 2, 2), dark);
    }
  }

  @override
  bool shouldRepaint(_GripperPainter oldDelegate) => false;
}
```

Band order in the `Wrap`: `[if (showTasks) Tasks key, if (history != null) ...[gripper(), Back, Forward], if (quickAdd.isNotEmpty) ...[etched(), gripper(), QuickAddMenu], if (fromLastTime.isNotEmpty) ...[etched(), gripper(), 'From last time:', keys]]`. With history and quick add, that is 2 grippers (3 with From last time). Import `millennium_style.dart` if missing.

- [ ] **Step 4: Run and commit**

Run: `flutter test test/shared/shell && flutter analyze lib test tool`
Expected: PASS.

```bash
git add -A lib test
git commit -m "feat: drop the app label and roadmap menu items; era licence dialog

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Dialog forms in the era's layout; the tabbed Pay agreement

**Files:**
- Create: `lib/shared/workbench/era_form.dart`
- Modify: `lib/shared/workbench/era_field.dart`, `lib/shared/workbench/era_date_field.dart` (~line 190–240), `lib/shared/workbench/era_time_field.dart` (its label column), `lib/shared/workbench/millennium_style.dart`, `lib/features/work/presentation/employment_agreement_forms.dart`, `lib/features/work/presentation/period_payslip_forms.dart`, `lib/features/work/presentation/shift_forms.dart`, `docs/superpowers/specs/2026-10-04-lifeos-xp-authentic-shell-design.md` (§4.4 tab list)
- Test: `test/shared/workbench/era_form_test.dart` (new), `test/shared/workbench/era_field_test.dart`, `test/features/work/presentation/*agreement*` (migrate)

**Interfaces:**
- Produces:
  - `abstract final class EraFieldWidth { date = 120; time = 72; money = 88; short = 48; text = 200; }`
  - `EraFormScope({double labelWidth = 110, required Widget child})`, `EraFormScope.labelWidthOf(BuildContext) -> double`
  - `EraLabelled({required String label, required Widget field, double? fieldWidth})` — `"Label:"` column + field; `fieldWidth` null = rest of the row.
  - `EraCheckBox({required bool value, required ValueChanged<bool>? onChanged, required String label, Key? key})`
  - `EraRadio<T>({required T value, required T groupValue, required ValueChanged<T>? onChanged, required String label, String? detail})`
  - `EraField(..., double? width = EraFieldWidth.text)` (null for full width; notes pass null).

- [ ] **Step 1: Write the failing tests**

```dart
// test/shared/workbench/era_form_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_field.dart';
import 'package:lifeos/shared/workbench/era_form.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

Widget _host(Widget child) => MaterialApp(
  home: LifeOSSkinScope(child: Scaffold(body: Center(child: SizedBox(width: 420, child: child)))),
);

void main() {
  testWidgets('a field sits after its "Label:" at its kind width', (tester) async {
    await tester.pumpWidget(
      _host(
        EraField(
          controller: TextEditingController(),
          label: 'Hourly rate (€)',
          fieldKey: const ValueKey('rate'),
          width: EraFieldWidth.money,
        ),
      ),
    );
    expect(find.text('Hourly rate (€):'), findsOneWidget);
    final label = tester.getRect(find.text('Hourly rate (€):'));
    final field = tester.getRect(find.byKey(const ValueKey('rate')));
    expect(field.left, greaterThan(label.right));
    expect(field.width, EraFieldWidth.money);
    expect((field.top - label.top).abs(), lessThan(8), reason: 'same row');
  });

  testWidgets('a check box is 13 px, beside its label, toggled by the row', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => EraCheckBox(
            key: const ValueKey('night'),
            value: value,
            label: 'Night pay',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('era-check-box'))), const Size(13, 13));
    await tester.tap(find.text('Night pay'));
    await tester.pump();
    expect(value, isTrue);
    expect(tester.getSize(find.byKey(const ValueKey('night'))).height, greaterThanOrEqualTo(24));
    expect(tester.getSemantics(find.byKey(const ValueKey('night'))),
        matchesSemantics(label: 'Night pay', hasCheckedState: true, isChecked: true, hasEnabledState: true, isEnabled: true, hasTapAction: true, isFocusable: true));
  });

  testWidgets('radios choose one value', (tester) async {
    var basis = 'gross';
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              for (final option in ['gross', 'net'])
                EraRadio<String>(
                  value: option,
                  groupValue: basis,
                  label: option == 'gross' ? 'Gross' : 'Net',
                  onChanged: (next) => setState(() => basis = next),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Net'));
    await tester.pump();
    expect(basis, 'net');
  });
}
```

- [ ] **Step 2: Colours**

```dart
  // Check boxes and radios (XP-authentic shell spec 8.1).
  static const choiceLine = Color(0xff1c5180);
  static const choiceMark = Color(0xff21a121);
  static const choiceMarkLight = Color(0xff55d651);
```

Contrast test: `contrast(MillenniumColors.choiceMark, tokens.paper) >= 3` and `contrast(MillenniumColors.choiceLine, tokens.paper) >= 3`.

- [ ] **Step 3: Implement `era_form.dart`**

```dart
// lib/shared/workbench/era_form.dart
import 'package:flutter/material.dart';

import 'era_controls.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// Field widths by kind (XP-authentic shell spec 8.1).
abstract final class EraFieldWidth {
  static const date = 120.0;
  static const time = 72.0;
  static const money = 88.0;
  static const short = 48.0;
  static const text = 200.0;
}

/// The width of a dialog's "Label:" column.
final class EraFormScope extends InheritedWidget {
  const EraFormScope({this.labelWidth = 110, required super.child, super.key});

  final double labelWidth;

  static double labelWidthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EraFormScope>()?.labelWidth ??
      110;

  @override
  bool updateShouldNotify(EraFormScope oldWidget) =>
      labelWidth != oldWidget.labelWidth;
}

/// "Label:" in the label column, then the field.
final class EraLabelled extends StatelessWidget {
  const EraLabelled({
    required this.label,
    required this.field,
    this.fieldWidth,
    super.key,
  });

  final String label;
  final Widget field;

  /// Null gives the field the rest of the row.
  final double? fieldWidth;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final width = fieldWidth;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: EraFormScope.labelWidthOf(context),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ExcludeSemantics(
                child: Text(
                  '$label:',
                  style: skin.typography.body.copyWith(color: skin.tokens.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (width == null)
            Expanded(child: field)
          else
            Flexible(
              child: SizedBox(width: width, child: field),
            ),
        ],
      ),
    );
  }
}

/// A 13 px era check box with its label; the whole row toggles it.
final class EraCheckBox extends StatelessWidget {
  const EraCheckBox({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => _Choice(
    label: label,
    checked: value,
    radio: false,
    onPressed: onChanged == null ? null : () => onChanged!(!value),
    mark: _Box(checked: value, enabled: onChanged != null),
  );
}

/// A 13 px era radio with its label; the whole row selects it.
final class EraRadio<T> extends StatelessWidget {
  const EraRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
    this.detail,
    super.key,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T>? onChanged;
  final String label;

  /// A muted line under the label, such as an example.
  final String? detail;

  @override
  Widget build(BuildContext context) => _Choice(
    label: label,
    detail: detail,
    checked: value == groupValue,
    radio: true,
    onPressed: onChanged == null ? null : () => onChanged!(value),
    mark: _Dot(selected: value == groupValue, enabled: onChanged != null),
  );
}

final class _Choice extends StatefulWidget {
  const _Choice({
    required this.label,
    required this.checked,
    required this.radio,
    required this.onPressed,
    required this.mark,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool checked;
  final bool radio;
  final VoidCallback? onPressed;
  final Widget mark;

  @override
  State<_Choice> createState() => _ChoiceState();
}

final class _ChoiceState extends State<_Choice> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final enabled = widget.onPressed != null;
    return Semantics(
      container: true,
      label: widget.label,
      checked: widget.checked,
      inMutuallyExclusiveGroup: widget.radio ? true : null,
      enabled: enabled,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.mark,
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    foregroundDecoration: _focused
                        ? DottedFocusRectangle(color: tokens.focus, inset: 0)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: skin.typography.body.copyWith(
                            color: enabled ? tokens.ink : tokens.muted,
                          ),
                        ),
                        if (widget.detail case final detail?)
                          Text(
                            detail,
                            style: skin.typography.small.copyWith(
                              color: tokens.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _Box extends StatelessWidget {
  const _Box({required this.checked, required this.enabled});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      key: const ValueKey('era-check-box'),
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: enabled ? tokens.paper : tokens.chrome,
        border: Border.all(color: MillenniumColors.choiceLine),
      ),
      child: checked
          ? const Center(
              child: EraGlyph(
                EraGlyphKind.tick,
                color: MillenniumColors.choiceMark,
                size: 9,
              ),
            )
          : null,
    );
  }
}

final class _Dot extends StatelessWidget {
  const _Dot({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      key: const ValueKey('era-radio'),
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? tokens.paper : tokens.chrome,
        border: Border.all(color: MillenniumColors.choiceLine),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MillenniumColors.choiceMarkLight,
                      MillenniumColors.choiceMark,
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
```

Check the exact names in `era_controls.dart`: `DottedFocusRectangle` (used by `TaskLink`) and `EraGlyphKind.tick`.

- [ ] **Step 4: Fields use the label column**

- `EraField`: add `this.width = EraFieldWidth.text` / `final double? width;`. Its body becomes `EraLabelled(label: label, fieldWidth: maxLines > 1 ? null : width, field: TextField(...))` inside the existing `Semantics` (the label text is excluded inside `EraLabelled`; the outer `Semantics` still names the field).
- `EraDateField` and `EraTimeField`: find the `Column` that puts `Text(widget.label)` above the box (`era_date_field.dart` ~197; the same shape in `era_time_field.dart`). Replace it with `EraLabelled(label: widget.label, fieldWidth: EraFieldWidth.date /* .time */, field: <the box>)`; leave the box, popup and error painting unchanged. Their existing tests that measured label-above geometry: change the assertions to the label-left geometry (same row, field right of label).

- [ ] **Step 5: Rework the forms**

`employment_agreement_forms.dart`:
- `_Field` forwards a `width` (`EraFieldWidth.money` for hourly rate, `EraFieldWidth.short` for the % and day fields, `null` for Note).
- Gross/Net: replace the `RadioGroup<RateBasis>` block with

```dart
                EraLabelled(
                  label: 'Basis',
                  field: Row(
                    children: [
                      for (final (value, label) in const [
                        (GrossBasis(), 'Gross'),
                        (NetBasis(), 'Net'),
                      ]) ...[
                        EraRadio<RateBasis>(
                          value: value,
                          groupValue: _basis,
                          label: label,
                          onChanged: (next) => setState(() => _basis = next),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
```

  (`RateBasis` equality: the existing code compares `GrossBasis()`/`NetBasis()` constants through `RadioGroup`; if `==` is identity, compare with `value.runtimeType == _basis.runtimeType` inside `EraRadio` by passing `groupValue: _basis is GrossBasis ? const GrossBasis() : const NetBasis()`.)
- Overtime sentence:

```dart
                _Sentence(
                  children: [
                    const Text('After'),
                    _Short(controller: _overtimeHours, …),
                    const Text('hours per shift, pay'),
                    _Short(controller: _overtimeMultiplier, …), // no prefix
                    const Text('×'),
                  ],
                ),
```

  Delete `_Short.prefix`; its width becomes `error == null ? EraFieldWidth.short : 240`. Night and Holidays multipliers get the same trailing `const Text('×')`.
- `CheckboxListTile` (night, holidays) → `EraCheckBox(key: const ValueKey('agreement-night-enabled'), value: _nightEnabled, label: 'Night pay', onChanged: (v) => setState(() => _nightEnabled = v))` (and the holidays one with its key).
- `_StackingOption` → `EraRadio<PremiumStacking>(value: …, groupValue: _stacking, label: title, detail: example, onChanged: (v) => setState(() => _stacking = v))`; delete the `RadioGroup` wrapper.
- The `ExpansionTile('More')` goes away: its Label and Note fields move to the Notes tab below.
- **Tabs.** The agreement form's scrolling body becomes `PropertySheetTabs(labels: const ['Rate', 'Premiums', 'Leave', 'Notes'], selectedIndex: _tab, onSelected: (i) => setState(() => _tab = i))` over an `IndexedStack(index: _tab, children: [...])` of four `ListView`s:
  - **Rate**: the Rate group (dates, hourly rate, basis).
  - **Premiums**: Overtime, Night, Holidays, When several apply.
  - **Leave**: Leave pay.
  - **Notes**: Label, Note.
  Keep the footer (save key + `DialogCancelKey`) and `_formError` under the stack. On save with errors, bring the first erroring tab forward:

```dart
  static const _tabOf = {
    'hourlyRate': 0,
    'effectiveFrom': 0,
    'effectiveTo': 0,
    'overtimeHours': 1,
    'overtimeMultiplier': 1,
    'nightEnd': 1,
    'nightMultiplier': 1,
    'holidayMultiplier': 1,
    'vacationPercent': 2,
    'sickPercent': 2,
    'sickDays': 2,
  };
  // after computing _errors in the save handler:
  final first = _errors.keys.map((key) => _tabOf[key] ?? 0).fold<int?>(
    null,
    (best, tab) => best == null || tab < best ? tab : best,
  );
  if (first != null) setState(() => _tab = first);
```

  Check the real error keys in the form's validation code and complete `_tabOf` with any others (date keys).
- Wrap each form's body in `EraFormScope(labelWidth: …)`: employment 90, agreement 120, pay period 90, payslip 100, manual shift 90.
- Remove the `InspectorTitle` at the top of each form (the dialog caption names it now): `'Pay period'` create, `'Paid evidence'` create, `'Manual shift'`/`widget.title` in `ShiftEditInspector`, the agreement form's title. Keep explanatory notes.

Agreement tests in `test/features/work/presentation/`: before addressing a field on another tab, tap that tab (`await tester.tap(find.text('Premiums')); await tester.pumpAndSettle();`); replace `find.byType(Checkbox)`/`CheckboxListTile` finders with the keys; replace `'hours per shift,'` with `'hours per shift, pay'`.

- [ ] **Step 6: Dialog keys at least 75 px wide**

Test in `test/shared/workbench/office_controls_test.dart` (its `_host` helper):

```dart
  testWidgets('push buttons are at least 75 × 24; small and toolbar keys are not widened', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyButton(key: const ValueKey('ok'), label: 'OK', kind: KeyKind.primary, onPressed: () {}),
            KeyButton(key: const ValueKey('go'), label: 'Go', kind: KeyKind.small, onPressed: () {}),
          ],
        ),
      ),
    );
    final ok = tester.getSize(find.byKey(const ValueKey('ok')));
    expect(ok.width, greaterThanOrEqualTo(75));
    expect(ok.height, greaterThanOrEqualTo(24));
    expect(tester.getSize(find.byKey(const ValueKey('go'))).width, lessThan(75));
  });
```

In `KeyButton`'s build (`office_controls.dart`), wrap the painted face in
`ConstrainedBox(constraints: BoxConstraints(minWidth: widget.kind == KeyKind.primary || widget.kind == KeyKind.secondary ? 75 : 0), child: …)`, keeping the label centred. Run the test: PASS. Golden diffs from wider keys are expected.

- [ ] **Step 7: Amend the spec's tab list**

In the spec §4.4 replace the Pay Agreement tab sentence with: "**Pay Agreement** is a tabbed dialog: **Rate | Premiums | Leave | Notes** (Premiums holds Overtime, Night, Holidays and When several apply). The tab holding the first invalid field is brought forward on save." Append to its Status line: "§4.4 tabs amended 2026-10-04 during planning: the form also has Leave pay and Notes."

- [ ] **Step 8: Run and commit**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS except goldens.

```bash
git add -A lib test docs/superpowers/specs/2026-10-04-lifeos-xp-authentic-shell-design.md
git commit -m "feat: lay dialog forms out as era dialogs; tab the pay agreement

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Details lists the era's way

**Files:**
- Modify: `lib/shared/workbench/data_register.dart`, `lib/shared/workbench/millennium_style.dart`, `lib/features/work/presentation/work_sheets.dart`, `lib/features/work/presentation/work_toolbar_controls.dart:176-232`
- Test: `test/shared/workbench/data_register_test.dart`, `test/features/work/presentation/work_sheets_test.dart` (or wherever entry rows are tested: `grep -rln "Add a manual shift\|Add a pay period\|Record a payslip for this period" test`)

**Interfaces:**
- Produces: `MillenniumColors.sortTint`; `EntryLine` removed from the register API.

- [ ] **Step 1: Write the failing tests**

Append to `data_register_test.dart`:

```dart
  testWidgets('the sorted column is tinted and its header has no amber edge', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_register(sortedColumn: 'name')));
    final cell = tester.widget<Container>(
      find.ancestor(of: find.text('a').first, matching: find.byType(Container)).first,
    );
    expect((cell.decoration as BoxDecoration?)?.color, MillenniumColors.sortTint);
    // Hover the header: the amber edge appears.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('Name')));
    await tester.pump();
    expect(find.byKey(const ValueKey('header-hot-name')), findsOneWidget);
  });

  testWidgets('a selected row turns grey when the list loses focus', (
    tester,
  ) async {
    final other = FocusNode();
    addTearDown(other.dispose);
    await tester.pumpWidget(
      _host(Column(children: [
        Expanded(child: _register(selectedId: 'a')),
        Focus(focusNode: other, child: const SizedBox(height: 10)),
      ])),
    );
    await tester.tap(find.text('a').first);
    await tester.pump();
    expect(_rowColour(tester, 'a'), LifeOSTokens.millennium.selWash);
    other.requestFocus();
    await tester.pump();
    expect(_rowColour(tester, 'a'), LifeOSTokens.millennium.chrome);
  });
```

with a helper

```dart
Color? _rowColour(WidgetTester tester, String rowText) {
  final row = find.ancestor(
    of: find.text(rowText).first,
    matching: find.byKey(ValueKey('register-row-$rowText')),
  );
  final box = tester.widget<Container>(
    find.descendant(of: row, matching: find.byType(Container)).first,
  );
  return (box.decoration as BoxDecoration?)?.color;
}
```

Adapt `_register` (the file's helper) to take `sortedColumn` and `selectedId`, and to use a column keyed `name` labelled `Name` whose `rowId` is the text itself.

- [ ] **Step 2: Implement**

- `MillenniumColors.sortTint = Color(0xfff7f7f7)`.
- `_DataRegisterState`: `bool _hasFocus = false;` with `_focus.addListener(() => setState(() => _hasFocus = _focus.hasFocus));` in `initState`; pass `focused: _hasFocus` and `sortedColumn: widget.sortedColumn` to `_DataRow`.
- `_DataRow`: wrap its `Semantics` child in `KeyedSubtree(key: ValueKey('register-row-$label'), …)` — no: put `key: ValueKey('register-row-${label}')` on the row's outer `Container` via a `KeyedSubtree`, using the row id (pass `rowId`), so the test key is `register-row-<rowId>`. Row background: `selected ? (focused ? tokens.selWash : tokens.chrome) : tokens.paper`; cell text colour: `selected && focused ? tokens.selInk : voided ? tokens.muted : tokens.ink`; cursor painter `onSelection: selected && focused`. Each cell `Container` gets `color: !selected && column.key == sortedColumn ? MillenniumColors.sortTint : null`.
- `_HeaderRow`: each header cell becomes a small stateful `_HeaderCell` with a `MouseRegion` hover flag; the bottom border is amber 3 px **only while hovered** (with `key: ValueKey('header-hot-${column.key}')` on the hot decoration's child), never for the sorted column; the sort arrow and its "sorted ascending/descending" semantics stay.
- Delete `EntryLine`, `_EntryRow` and their `switch` arm. In `work_sheets.dart` delete the three `lines.add(EntryLine(…))` calls and any parameters only they used (`onAddManualShift`, `onNewPeriod`, `onRecordPayslip` on the sheets — keep them if anything else uses them; `grep` first). Remove the matching arguments in `work_register.dart` and `work_screen.dart`.
- Period keys (`work_toolbar_controls.dart`):

```dart
        KeyButton(
          label: '',
          leading: EraGlyph(
            EraGlyphKind.stepBack,
            color: previous == null ? tokens.muted : tokens.ink,
          ),
          semanticLabel: previous == null
              ? 'Previous period, unavailable'
              : 'Previous period',
          kind: KeyKind.small,
          onPressed: previous == null ? null : () => onScope(previous),
        ),
```

  and the same for **Next** with `stepForward`. (`tokens = LifeOSSkinScope.of(context).tokens`.) Each key is available on its own; at the last period only **Next** is grey. If `KeyButton` pads an empty label, give it a `minWidth` of 24 by wrapping in `SizedBox(width: 24)`.

- [ ] **Step 3: Run and commit**

Run: `flutter analyze lib test tool && flutter test --exclude-tags real-font`
Expected: PASS except goldens. Tests that tapped "Add a manual shift" in the list now use the task link "Add a shift" or the toolbar Add.

```bash
git add -A lib test
git commit -m "feat: era details lists: sort tint, hover edge, grey unfocused selection

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Desks and Books cleanup

**Files:**
- Modify: `lib/shared/shell/desk_view.dart:82-90`, `lib/shared/shell/book_tree.dart:140-180, 250-258`
- Test: `test/shared/shell/desk_view_test.dart`, `test/shared/shell/book_tree_test.dart`, `test/integration/today_desk_flow_test.dart`

- [ ] **Step 1: Write the failing tests**

In `desk_view_test.dart`:

```dart
  testWidgets('desk tabs are only desks', (tester) async {
    // pump DeskView as the file does
    expect(find.text('+ Desk'), findsNothing);
  });
```

In `book_tree_test.dart`:

```dart
  testWidgets('an unbuilt area is one muted row', (tester) async {
    // pump BookTree with TreeArea(area: LifeOSArea.finance, route: '/finance', built: false)
    expect(find.text('Finance (not built yet)'), findsOneWidget);
    expect(find.text('Not built yet'), findsNothing);
    final icon = tester.widget<EraIcon>(find.byType(EraIcon));
    expect(icon.disabled, isTrue);
  });
```

- [ ] **Step 2: Implement**

- `desk_view.dart`: `labels: [for (final desk in desks) desk.name]`, `onSelected: (index) => onSelectDesk(desks[index])`; delete the "+ Desk" comment. Keep `onNewDesk` for the Desk ▾ menu.
- `book_tree.dart`: an unbuilt `TreeArea` row renders `EraIcon(areaIcon(node.area), disabled: true)` and a single muted `Text('${node.area.label} (not built yet)')`; delete the second "Not built yet" line (~:171-176) and its `semanticValue` (the label now says it). At ~:254, the sheet value for an unbuilt sheet becomes null (the row name carries "(not built yet)" the same way).
- `today_desk_flow_test.dart`: replace taps on `+ Desk` with the task link `New desk`.

- [ ] **Step 3: Run and commit**

Run: `flutter test test/shared/shell test/integration && flutter analyze lib test tool`

```bash
git add -A lib test
git commit -m "feat: drop the + Desk tab; one-line unbuilt areas in Books

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Documentation, final goldens and the app script

**Files:**
- Modify: `DESIGN.md`, `docs/superpowers/specs/2026-10-02-lifeos-millennium-shell-design.md` (header note), `docs/superpowers/specs/2026-10-04-lifeos-xp-authentic-shell-design.md` (§8.2 period keys), `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md`, `README.md` (only if it shows or describes the old layout), `test/goldens/**`

- [ ] **Step 1: Amend the spec's period-key line**

In §8.2 replace "both greyed together when unavailable" with "each greyed when its direction has no period (at the last period only **Next** is grey)".

- [ ] **Step 2: Rewrite DESIGN.md**

Keep the front-matter format. Update:
- `colors`: add `frame-active #0831d9`, `frame-inactive #7b8fd6`, `inactive-caption #5670c4`, `sort-tint #f7f7f7`, `choice-line #1c5180`, `choice-mark #21a121`, the scrollbar face/track colours; remove `area-*` if `AreaKeyColors` was deleted in Task 7.
- `typography`: EraSans for all styles; caption 13/16 700, body/strong/label/small/figure 11/14, counter 18/20; drop `title`.
- `components`: add `window-caption`, `properties-dialog`, `dialog-form`, `check-box`, `radio`, `scrollbar`, `address-combo`; remove `property-sheet-tab` as a docked region (keep it as the dialog's tabs).
- Prose: the shipped shell list (window frame, menu bar without the app label, toolbar bands, Address path combo, task pane with selection-aware group, Books, Details/Working, content, status bar with notice panel and size grip; no right column); Properties dialog; forms as dialogs with the `Label:` column; message boxes; icons (painted; the icon artwork colours are the documented exception to "colours only from tokens"); the caption text shadow as the one allowed shadow; scrollbars; EraSans (Wine's Tahoma-metric font, LGPL, Noto Sans fallback).
- Width behaviour: two columns at ≥ 1024 px; Tasks key below.
- Point "derived from" at the new spec as well.

- [ ] **Step 3: Header note on the Millennium spec**

Under its `Status:` line add: `Amended by: 2026-10-04-lifeos-xp-authentic-shell-design.md (window frame, font, icons, layout, property sheet, desk tabs).`

- [ ] **Step 4: Refresh the surface brief**

Rewrite `.impeccable/surfaces/lib-features-work-presentation-work-screen-dart.md`: keep its front matter (update `related_targets` to `lib/shared/shell/shell_frame.dart`, `lib/shared/shell/shell_dialog.dart`, `lib/features/work/presentation/work_tasks.dart`, `lib/shared/workbench/millennium_style.dart`, `lib/app/app_router.dart`); Scope: Operate, the LifeOS shell and Work, one style (Millennium); Direction contract: THESIS (a 2001 office program for one person's records; every figure can show its working), OWN-WORLD (the XP-authentic shell as in DESIGN.md), STORY (open Today, select a row, read Details and Working, open Properties, record from a dialog), FIRST VIEWPORT (window caption … status bar, as DESIGN.md), FORM (file-explorer shell: task pane follows the selection; Properties dialogs), FINISH (goldens + real-font renders looked at). Remove every Office Machine reference.

- [ ] **Step 5: Semantics at both sizes (spec §10)**

Extend `test/shared/shell/shell_semantics_test.dart` (it already checks region labels at both sizes via `pumpSyntheticShell`): for each of `Size(1280, 800)` and `Size(960, 760)`, also expect `find.bySemanticsLabel('Minimize')`, `'Maximize'`, `'Close'` (caption keys, painted with `InertWindowControls`), `'Address, Work, Synthetic depot, Shifts'`, and — after `await tester.sendKeyEvent(LogicalKeyboardKey.enter)` on a selected row — the dialog's label `'Shift 2026-09-08 Properties'`. Run it: PASS.

- [ ] **Step 6: Final goldens and a full run**

```bash
flutter test --update-goldens test/goldens/shell_goldens_test.dart
flutter test --run-skipped -t real-font --update-goldens test/goldens/real_font_check_test.dart
flutter analyze lib test tool
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/schema_check.dart
flutter test
```

Expected: all PASS. Look at every PNG under `test/goldens/real_font/` (register, selected, working, period Properties, form, agreement, calendar, today) and check against the spec: no right column; caption, icons, path Address bar; Label: columns; 13 px choices; tabbed Pay agreement; scrollbars only where content overflows; nothing clipped at 960 × 760.

- [ ] **Step 7: The app script still starts and tests the app (CLAUDE.md)**

```bash
printf '2\n4\n' | ./app.sh    # tests
printf '3\n4\n' | ./app.sh    # checks
timeout 180 bash -c "printf '1\n' | ./app.sh" || true   # starts; close the window by hand
```

Confirm the window opens with the painted caption and no GNOME header bar. `app.sh` needs no change unless a command failed; if it did, fix `app.sh` and re-run.

- [ ] **Step 8: Commit**

```bash
git add -A DESIGN.md docs .impeccable/surfaces README.md test/goldens
git commit -m "docs: record the XP-authentic shell in DESIGN.md and the surface brief

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
