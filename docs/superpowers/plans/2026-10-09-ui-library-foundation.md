# UI Library Foundation (Phase 1) Implementation Plan

> **Execution:** Follow the active repository instructions and use Beads for progress. Before implementation, run `bd prime`, inspect and claim `lifeManager-9pk.1`; record checkpoints there. The numbered steps below describe the procedure, not a second task tracker. Do not assume any external skill is installed or any subagent/commit authorization is granted by this document.

**Goal:** Every era widget lives in `lib/ui/` behind one import (`lib/ui/ui.dart`), is listed in `lib/ui/CATALOG.md`, can be seen in a widget gallery opened from `./app.sh`, and is found by future sessions through the `lifeos-ui` skill, while the production app stays pixel-identical.

**Architecture:** The 23 files of `lib/shared/workbench/` move with `git mv` into `lib/ui/{foundation,controls,data,shell}/` and their tests into `test/ui/`. Two files that mix concerns are split (`PropertySheetTabs`, `EtchedLine`). Feature, app and legacy-shell code then import only the barrel `lib/ui/ui.dart`, enforced by guard tests. A phase 1 gallery host (the existing `DataRegister` as its list, era check boxes as knobs) shows one demo per widget on synthetic data and never opens a database. Every demo renders a synthetic golden and a real-font golden. The old shell (`lib/shared/shell/`) is not part of the library: it stays where it is until phase 5 deletes it.

**Tech Stack:** Flutter 3.47.5, Dart 3.13, flutter_test goldens, Python 3 (one-off move scripts run from the shell, not committed), Bash (`app.sh`).

**Spec:** `docs/superpowers/specs/2026-10-08-database-shell-and-ui-library-design.md`. This plan covers section 5 and the phase 1 row of section 7. Beads: `lifeManager-9pk.1`.

## Global Constraints

- Commands use `export FLUTTER=$HOME/.local/opt/flutter-3.47.5/bin/flutter DART=$HOME/.local/opt/flutter-3.47.5/bin/dart` (or `flutter` / `dart` when on `PATH`), run from the repository root `/home/aUser/lifeManager`.
- **Production remains pixel-identical:** existing goldens pass unchanged. Never run `--update-goldens` on `test/goldens/`. `git status --porcelain -- ':(glob)test/goldens/**/*.png'` must print nothing at the end of every task.
- Moves use `git mv` so history stays. No behavior change to any moved widget.
- `lib/ui/` may import only `lib/ui/**`, `lib/core/time/**`, `lib/core/explain/**`, `dart:*`, `package:flutter/*` and `package:path/*`.
- `lib/features/`, `lib/app/` and `lib/shared/` import the library only through `lib/ui/ui.dart`. `lib/main.dart` may also import `lib/ui/gallery/gallery_main.dart`. Tests import `package:lifeos/ui/ui.dart` and, for gallery tests, files under `package:lifeos/ui/gallery/`.
- The gallery boots with synthetic fixtures and never opens the production database (spec 5.3).
- Era look only (DESIGN.md): colours from `LifeOSTokens` / `MillenniumColors`, EraSans 11 px, painted glyphs; no literal colours in demos.
- Catalog status is exactly one of `stable`, `new` or `deprecated (use X)` (spec 5.2).
- Analyzer: `$FLUTTER analyze lib test tool` reports `No issues found!`. Formatting: `$DART format --output=none --set-exit-if-changed lib test tool` exits 0.
- Do not commit, push or sync Dolt unless the owner explicitly authorizes it. After each task, inspect the diff and update the Beads checkpoint; do not stage unrelated work or add a fabricated co-author identity.
- Synthetic data only in tests, goldens and the gallery.
- Treat test counts in this plan as estimates; the current suite and a zero exit status are authoritative. Run commands without output-filtering pipelines that can hide failures. If saving a log through `tee`, enable `set -o pipefail` first.
- Inventory existing changes before starting. Preserve owner changes. Save hashes of every existing `test/goldens/**/*.png` and verify those hashes after moves and at the phase gate; clean Git status alone cannot detect a committed or pre-existing golden change.

## Review Focus

1. **The owner opens the app after the move and sees exactly what they saw before.** A wrong import or a split that drops a private helper must not change one pixel → Tasks 2, 3 and 4 each run `test/goldens` without updating and check `git status --porcelain -- ':(glob)test/goldens/**/*.png'` is empty.
2. **Starting the gallery must never open or lock the production database, even if it is corrupt or another LifeOS is running.** → Task 5 executes the startup selector with `--dart-define=LIFEOS_GALLERY=1` and a production callback that must never run. Source wiring and the import boundary are additional guards, not substitutes for executing the selector.
3. **The gallery at 200 % text with long labels stays usable:** the list, knobs and canvas must not throw overflow errors. → Task 5 test "the gallery holds at 200 % text with long labels".
4. **A catalog entry that silently goes stale** (a file renamed, a demo id changed, a golden missing) misleads every later session. → Task 8's catalog test checks each entry's file path, gallery id and golden file.
5. **The "Enabled" knob turned off must really disable a demo's keys**, or the owner judges a disabled look that never renders. → Task 6 test "the Enabled knob disables the key demo's keys".

---

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `lib/ui/ui.dart` | The barrel: exports every library file except the gallery. |
| `lib/ui/CATALOG.md` | The inventory: job table plus one entry per widget. |
| `lib/ui/controls/property_sheet_tabs.dart` | `PropertySheetTabs`, split out of `office_controls.dart`. |
| `lib/ui/controls/etched_line.dart` | `EtchedLine`, split out of `inspector_parts.dart`. |
| `lib/ui/gallery/gallery_demo.dart` | `GalleryDemo`, `GalleryKnobs`, `GalleryValue<T>`, `galleryToday`. |
| `lib/ui/gallery/gallery_host.dart` | `GalleryHost` (MaterialApp + LifeOS scopes) and `GalleryCanvas`. |
| `lib/ui/gallery/gallery_app.dart` | `GalleryApp` and `GalleryHome` (list, demo, knobs). |
| `lib/ui/gallery/gallery_demos.dart` | `galleryDemos`: every demo in catalog order. |
| `lib/ui/gallery/gallery_main.dart` | `runGallery(...)`, called by `main.dart`. |
| `lib/app/startup_mode.dart` | Select gallery or production before invoking either startup callback; tested with the exact launcher define. |
| `lib/ui/gallery/demos/foundation_demos.dart` | Demos for `LifeOSSkinScope`, `EraIcon`. |
| `lib/ui/gallery/demos/control_demos.dart` | Demos for the 27 control widgets. |
| `lib/ui/gallery/demos/data_demos.dart` | Demos for `DataRegister`, `CellSelectionScope`, `OperationalState`. |
| `lib/ui/gallery/demos/shell_demos.dart` | Demos for the 12 shell widgets. |
| `test/ui/library_boundary_test.dart` | Import guards (spec 5.4). |
| `test/ui/catalog_test.dart` | CATALOG.md ↔ widgets ↔ demos ↔ goldens guard. |
| `test/ui/gallery/gallery_app_test.dart` | Host behavior. |
| `test/ui/gallery/gallery_main_test.dart` | The gallery never reaches the database. |
| `test/ui/gallery/demos_test.dart` | Demos build; knobs; coverage guard. |
| `test/ui/gallery/gallery_goldens_test.dart` | One synthetic golden per demo. |
| `test/ui/gallery/gallery_real_font_test.dart` | One real-font golden per demo (tag `real-font`). |
| `test/support/gallery.dart` | `pumpGalleryDemo`. |
| `test/support/ui_library.dart` | `libraryWidgetClasses()`. |
| `test/repository/app_launcher_test.dart` | `app.sh` offers the gallery. |
| `test/repository/ui_library_pointers_test.dart` | Sessions are pointed at the catalog. |
| `.claude/skills/lifeos-ui/SKILL.md`, `.agents/skills/lifeos-ui/SKILL.md`, `.agents/skills/lifeos-ui/agents/openai.yaml` | The skill and its Codex mirror. |

**Moved** (`git mv`, contents unchanged except import lines)

| From `lib/shared/workbench/` | To |
|---|---|
| `lifeos_tokens.dart`, `millennium_style.dart`, `lifeos_skin.dart`, `lifeos_theme.dart`, `era_icons.dart`, `era_dates.dart`, `date_trace.dart` | `lib/ui/foundation/` (same names) |
| `era_controls.dart`, `era_combo.dart`, `era_field.dart`, `era_form.dart`, `era_date_field.dart`, `era_time_field.dart`, `era_month_calendar.dart`, `era_menu.dart`, `era_scrollbar.dart` | `lib/ui/controls/` (same names) |
| `office_controls.dart` | `lib/ui/controls/keys.dart` |
| `data_register.dart`, `cell_selection.dart`, `operational_state.dart` | `lib/ui/data/` (same names) |
| `era_dialog.dart`, `property_sheet.dart` | `lib/ui/shell/` (same names) |
| `inspector_parts.dart` | `lib/ui/shell/dialog_parts.dart` |

Tests in `test/shared/workbench/` follow their files into `test/ui/<folder>/` (`office_controls_test.dart` → `test/ui/controls/keys_test.dart`, `inspector_parts_test.dart` → `test/ui/shell/dialog_parts_test.dart`).

**Modified:** every file that imported a workbench file (about 106 in `lib/` and `test/`), `lib/main.dart`, `app.sh`, `test/repository/flutter_only_boundary_test.dart`, `DESIGN.md`, `CLAUDE.md`, `AGENTS.md`.

**Not moved:** `lib/shared/shell/` (the old shell: task pane, address bar, Books tree, desks, menu bar, status line, dialogs). It depends on the old app composition, is replaced in phases 2–4 and deleted in phase 5. Its files import `lib/ui/ui.dart` after Task 3.

---

### Task 1: Baseline green — the specs test ignores the assets folder

The approved spec added `docs/superpowers/specs/assets/`. `test/repository/flutter_only_boundary_test.dart` lists every entry of the specs folder; a directory's URI ends in `/`, so its name reads as `''`, which sorts before `2026-09-29` and fails "only native specifications remain". Everything else passes (1032 tests, 1 skipped real-font test).

**Files:**
- Modify: `test/repository/flutter_only_boundary_test.dart:40-45`

**Interfaces:** none.

- **Step 1: Confirm the failure**

Run: `$FLUTTER test test/repository/flutter_only_boundary_test.dart`
Expected: FAIL in `only native specifications remain` with ` predates the native foundation` (an empty spec name).

- **Step 2: List only the Markdown specs**

In `test/repository/flutter_only_boundary_test.dart`, replace

```dart
    final specs = Directory('docs/superpowers/specs')
        .listSync()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();
```

with

```dart
    // Specs are the Markdown files; folders such as assets/ hold their
    // reference images and mockups.
    final specs = Directory('docs/superpowers/specs')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.md'))
        .toList();
```

- **Step 3: Run it**

Run: `$FLUTTER test test/repository/flutter_only_boundary_test.dart`
Expected: PASS (3 tests).

- **Step 4: Record checkpoint**

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 2: Move the workbench into `lib/ui/` and its tests into `test/ui/`

**Files:**
- Move: the 23 files in the File Structure table, and their 19 tests.
- Modify: every Dart file under `lib/`, `test/`, `tool/` whose import points at a moved file; `DESIGN.md:140,150`.

**Interfaces:**
- Consumes: nothing.
- Produces: the library files at their new paths (Task 3 relies on them): `lib/ui/foundation/{lifeos_tokens,millennium_style,lifeos_skin,lifeos_theme,era_icons,era_dates,date_trace}.dart`, `lib/ui/controls/{era_controls,keys,era_combo,era_field,era_form,era_date_field,era_time_field,era_month_calendar,era_menu,era_scrollbar}.dart`, `lib/ui/data/{data_register,cell_selection,operational_state}.dart`, `lib/ui/shell/{era_dialog,dialog_parts,property_sheet}.dart`.

- **Step 1: Record the baseline**

Run: `$FLUTTER test --reporter expanded`
Expected: `+1033 ~1: All tests passed!` (after Task 1).

- **Step 2: Move the files and rewrite every import**

Run this from the repository root (it uses `git mv`, then recomputes every relative and `package:lifeos/` import whose source or target moved):

```bash
python3 - <<'EOF'
import os, re, subprocess, pathlib

W, T = 'lib/shared/workbench', 'test/shared/workbench'
lib_moves = {
    **{f'{W}/{n}.dart': f'lib/ui/foundation/{n}.dart' for n in
       ['lifeos_tokens', 'millennium_style', 'lifeos_skin', 'lifeos_theme',
        'era_icons', 'era_dates', 'date_trace']},
    **{f'{W}/{n}.dart': f'lib/ui/controls/{n}.dart' for n in
       ['era_controls', 'era_combo', 'era_field', 'era_form', 'era_date_field',
        'era_time_field', 'era_month_calendar', 'era_menu', 'era_scrollbar']},
    f'{W}/office_controls.dart': 'lib/ui/controls/keys.dart',
    **{f'{W}/{n}.dart': f'lib/ui/data/{n}.dart' for n in
       ['data_register', 'cell_selection', 'operational_state']},
    f'{W}/era_dialog.dart': 'lib/ui/shell/era_dialog.dart',
    f'{W}/property_sheet.dart': 'lib/ui/shell/property_sheet.dart',
    f'{W}/inspector_parts.dart': 'lib/ui/shell/dialog_parts.dart',
}
test_moves = {
    **{f'{T}/{n}_test.dart': f'test/ui/foundation/{n}_test.dart' for n in
       ['date_trace', 'era_dates', 'era_icons', 'lifeos_tokens', 'lifeos_typography']},
    **{f'{T}/{n}_test.dart': f'test/ui/controls/{n}_test.dart' for n in
       ['era_combo', 'era_controls', 'era_date_field', 'era_field', 'era_form',
        'era_menu', 'era_month_calendar', 'era_scrollbar', 'era_time_field']},
    f'{T}/office_controls_test.dart': 'test/ui/controls/keys_test.dart',
    **{f'{T}/{n}_test.dart': f'test/ui/data/{n}_test.dart' for n in
       ['data_register', 'operational_state']},
    f'{T}/property_sheet_test.dart': 'test/ui/shell/property_sheet_test.dart',
    f'{T}/inspector_parts_test.dart': 'test/ui/shell/dialog_parts_test.dart',
}
moves = {**lib_moves, **test_moves}
for src in moves:
    assert os.path.exists(src), src
present = set(map(str, pathlib.Path(W).glob('*.dart'))) | set(map(str, pathlib.Path(T).glob('*.dart')))
left = sorted(present - set(moves))
assert not left, f'unmapped files: {left}'

for src, dst in moves.items():
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    subprocess.run(['git', 'mv', src, dst], check=True)
for d in (W, T):
    os.rmdir(d)

old_of = {dst: src for src, dst in moves.items()}
directive = re.compile(r"^(import|export|part)(\s+)'([^']+)'", re.M)

def target(old_file, uri):
    if uri.startswith('package:lifeos/'):
        return 'lib/' + uri[len('package:lifeos/'):], 'package'
    if uri.startswith(('package:', 'dart:')):
        return None, None
    return os.path.normpath(os.path.join(os.path.dirname(old_file), uri)), 'relative'

changed = 0
for root in ('lib', 'test', 'tool'):
    for path in map(str, pathlib.Path(root).rglob('*.dart')):
        old_path = old_of.get(path, path)
        text = open(path).read()
        def rewrite(m):
            kind_word, space, uri = m.groups()
            dest, kind = target(old_path, uri)
            if dest is None:
                return m.group(0)
            dest = moves.get(dest, dest)
            if kind == 'package':
                return f"{kind_word}{space}'package:lifeos/{dest[len('lib/'):]}'"
            return f"{kind_word}{space}'{os.path.relpath(dest, os.path.dirname(path))}'"
        new = directive.sub(rewrite, text)
        if new != text:
            open(path, 'w').write(new)
            changed += 1
print(f'moved {len(moves)} files, rewrote imports in {changed} files')
EOF
```

Expected: `moved 42 files, rewrote imports in …` and no assertion error.

- **Step 3: Point DESIGN.md at the new paths**

In `DESIGN.md` line 140 replace `` (`lib/shared/shell`, `lib/shared/workbench`) `` with `` (`lib/shared/shell`, `lib/ui`) ``.
In `DESIGN.md` line 150 replace `` `lib/shared/workbench/millennium_style.dart` `` with `` `lib/ui/foundation/millennium_style.dart` `` and `` `test/shared/workbench/lifeos_tokens_test.dart` `` with `` `test/ui/foundation/lifeos_tokens_test.dart` ``.

- **Step 4: Format and analyze**

Run: `$DART format lib test tool && $FLUTTER analyze lib test tool`
Expected: `No issues found!` If `directives_ordering` is reported, run `$DART fix --apply --code=directives_ordering lib test tool` and analyze again.

- **Step 5: Run the whole suite, goldens untouched**

Run: `$FLUTTER test --reporter expanded && git status --porcelain -- ':(glob)test/goldens/**/*.png'`
Expected: `+1033 ~1: All tests passed!` and no output from `git status`.

- **Step 6: Record checkpoint**

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 3: The `ui.dart` barrel and the import guards

**Files:**
- Create: `lib/ui/ui.dart`, `test/ui/library_boundary_test.dart`
- Modify: every file under `lib/features/`, `lib/app/`, `lib/shared/`, `test/` that imports a `lib/ui/` file.

**Interfaces:**
- Consumes: Task 2's paths.
- Produces: `lib/ui/ui.dart` (relative import from `lib/`; `package:lifeos/ui/ui.dart` from tests). Every later task imports the library through it.

- **Step 1: Write the guard test**

Create `test/ui/library_boundary_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The UI library's import boundaries (database shell spec 5.4).
void main() {
  final directive = RegExp(r"^(?:import|export)\s+'([^']+)'", multiLine: true);

  Iterable<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  /// The repository path a directive in [file] points at, or null for a
  /// `dart:` or third-party package.
  String? target(File file, String uri) {
    if (uri.startsWith('package:lifeos/')) {
      return p.posix.join('lib', uri.substring('package:lifeos/'.length));
    }
    if (uri.startsWith('package:') || uri.startsWith('dart:')) return null;
    return p.posix.normalize(p.posix.join(p.posix.dirname(file.path), uri));
  }

  List<String> offenders(
    Iterable<File> files,
    bool Function(File file, String target) allowed,
  ) => [
    for (final file in files)
      for (final match in directive.allMatches(file.readAsStringSync()))
        if (target(file, match.group(1)!) case final to?)
          if (to.startsWith('lib/ui/') && !allowed(file, to))
            '${file.path} → $to',
  ];

  test('features, app and the old shell reach the library only through '
      'ui.dart', () {
    final files = [
      ...dartFiles('lib/features'),
      ...dartFiles('lib/app'),
      ...dartFiles('lib/shared'),
      File('lib/main.dart'),
    ];
    expect(
      offenders(
        files,
        (file, to) =>
            to == 'lib/ui/ui.dart' ||
            (file.path == 'lib/main.dart' &&
                to == 'lib/ui/gallery/gallery_main.dart'),
      ),
      isEmpty,
    );
  });

  test('tests reach the library through ui.dart or the gallery', () {
    expect(
      offenders(
        dartFiles('test'),
        (file, to) => to == 'lib/ui/ui.dart' || to.startsWith('lib/ui/gallery/'),
      ),
      isEmpty,
    );
  });

  test('the library depends only on itself, time and explanations', () {
    bool allowed(File file, String uri) {
      if (uri.startsWith('dart:') ||
          uri.startsWith('package:flutter/') ||
          uri.startsWith('package:path/')) {
        return true;
      }
      final to = target(file, uri);
      if (to == null) return false; // any other third-party package
      return to.startsWith('lib/ui/') ||
          to.startsWith('lib/core/time/') ||
          to.startsWith('lib/core/explain/');
    }

    final outside = [
      for (final file in dartFiles('lib/ui'))
        for (final match in directive.allMatches(file.readAsStringSync()))
          if (!allowed(file, match.group(1)!))
            '${file.path} → ${match.group(1)}',
    ];
    expect(outside, isEmpty);
  });

  test('the old workbench folders are gone', () {
    expect(Directory('lib/shared/workbench').existsSync(), isFalse);
    expect(Directory('test/shared/workbench').existsSync(), isFalse);
  });
}
```

- **Step 2: Run it to see it fail**

Run: `$FLUTTER test test/ui/library_boundary_test.dart`
Expected: the first two tests FAIL, listing files such as `lib/features/work/presentation/day_sheet.dart → lib/ui/controls/keys.dart`. The last two PASS.

- **Step 3: Create the barrel**

Create `lib/ui/ui.dart`:

```dart
/// The LifeOS UI library (database shell spec 5): the one import for
/// feature, app and shell code. Its inventory is `lib/ui/CATALOG.md`; see a
/// widget with `./app.sh` › Open widget gallery.
library;

export 'controls/era_combo.dart';
export 'controls/era_controls.dart';
export 'controls/era_date_field.dart';
export 'controls/era_field.dart';
export 'controls/era_form.dart';
export 'controls/era_menu.dart';
export 'controls/era_month_calendar.dart';
export 'controls/era_scrollbar.dart';
export 'controls/era_time_field.dart';
export 'controls/keys.dart';
export 'data/cell_selection.dart';
export 'data/data_register.dart';
export 'data/operational_state.dart';
export 'foundation/date_trace.dart';
export 'foundation/era_dates.dart';
export 'foundation/era_icons.dart';
export 'foundation/lifeos_skin.dart';
export 'foundation/lifeos_theme.dart';
export 'foundation/lifeos_tokens.dart';
export 'foundation/millennium_style.dart';
export 'shell/dialog_parts.dart';
export 'shell/era_dialog.dart';
export 'shell/property_sheet.dart';
```

- **Step 4: Collapse every outside import of the library into the barrel**

```bash
python3 - <<'EOF'
import os, re, pathlib

files = [str(p) for d in ('lib/features', 'lib/app', 'lib/shared', 'test')
         for p in pathlib.Path(d).rglob('*.dart')] + ['lib/main.dart']
imp = re.compile(r"^import\s+'([^']+)'[^;]*;\n", re.M)

def target(path, uri):
    if uri.startswith('package:lifeos/'):
        return 'lib/' + uri[len('package:lifeos/'):]
    if uri.startswith(('package:', 'dart:')):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(path), uri))

changed = 0
for path in files:
    text = open(path).read()
    hits = [m for m in imp.finditer(text)
            if (t := target(path, m.group(1))) and t.startswith('lib/ui/')
            and t != 'lib/ui/ui.dart' and not t.startswith('lib/ui/gallery/')]
    if not hits:
        continue
    barrel = ('package:lifeos/ui/ui.dart' if path.startswith('test/')
              else os.path.relpath('lib/ui/ui.dart', os.path.dirname(path)))
    has_barrel = any(target(path, m.group(1)) == 'lib/ui/ui.dart'
                     for m in imp.finditer(text))
    out, last = [], 0
    for i, m in enumerate(hits):
        out.append(text[last:m.start()])
        if i == 0 and not has_barrel:
            out.append(f"import '{barrel}';\n")
        last = m.end()
    out.append(text[last:])
    open(path, 'w').write(''.join(out))
    changed += 1
print(f'collapsed library imports in {changed} files')
EOF
$DART fix --apply --code=directives_ordering lib test tool
$DART format lib test tool
```

Expected: `collapsed library imports in …` (about 105 files), then `dart fix` and `dart format` finish without errors.

- **Step 5: Analyze**

Run: `$FLUTTER analyze lib test tool`
Expected: `No issues found!` If an `ambiguous_import` appears (a name declared both in the library and elsewhere), add `hide <Name>` to that file's `ui.dart` import and re-run; the pre-plan scan found no such names.

- **Step 6: Run the guards, then everything, goldens untouched**

Run: `$FLUTTER test test/ui/library_boundary_test.dart && $FLUTTER test --reporter expanded && git status --porcelain -- ':(glob)test/goldens/**/*.png'`
Expected: 4 guard tests PASS; `All tests passed!`; no `git status` output.

- **Step 7: Record checkpoint**

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 4: Split `PropertySheetTabs` and `EtchedLine` into their own files

Spec 5.1: the mixed files are split into their homes. `PropertySheetTabs` (a tab control) leaves the keys file; `EtchedLine` (a control used by the dialog parts) leaves `dialog_parts.dart`.

**Files:**
- Create: `lib/ui/controls/property_sheet_tabs.dart`, `lib/ui/controls/etched_line.dart`
- Modify: `lib/ui/controls/keys.dart`, `lib/ui/shell/dialog_parts.dart`, `lib/ui/ui.dart`

**Interfaces:**
- Consumes: `lib/ui/ui.dart` from Task 3.
- Produces: `PropertySheetTabs` in `lib/ui/controls/property_sheet_tabs.dart` and `EtchedLine` in `lib/ui/controls/etched_line.dart`. Tasks 6–8 refer to these paths.

- **Step 1: Write the failing check**

Append to `test/ui/library_boundary_test.dart`, inside `main()`:

```dart
  test('mixed files are split into their homes (spec 5.1)', () {
    String source(String path) => File(path).readAsStringSync();
    expect(
      source('lib/ui/controls/property_sheet_tabs.dart'),
      contains('final class PropertySheetTabs '),
    );
    expect(source('lib/ui/controls/keys.dart'), isNot(contains('PropertySheetTabs')));
    expect(
      source('lib/ui/controls/etched_line.dart'),
      contains('final class EtchedLine '),
    );
    expect(
      source('lib/ui/shell/dialog_parts.dart'),
      isNot(contains('final class EtchedLine ')),
    );
  });
```

Run: `$FLUTTER test test/ui/library_boundary_test.dart`
Expected: the new test FAILS (`PathNotFoundException` for `property_sheet_tabs.dart`).

- **Step 2: Split the files**

```bash
python3 - <<'EOF'
keys_path = 'lib/ui/controls/keys.dart'
keys = open(keys_path).read()
cut = keys.index('/// Property-sheet tabs (spec 5.5)')
open(keys_path, 'w').write(keys[:cut].rstrip() + '\n')
open('lib/ui/controls/property_sheet_tabs.dart', 'w').write(
    "import 'package:flutter/widgets.dart';\n\n"
    "import '../foundation/lifeos_skin.dart';\n"
    "import '../foundation/millennium_style.dart';\n\n" + keys[cut:])

parts_path = 'lib/ui/shell/dialog_parts.dart'
parts = open(parts_path).read()
start = parts.index('/// A 2 px etched separator')
end = parts.index('/// A block of "Label:" rows')
open('lib/ui/controls/etched_line.dart', 'w').write(
    "import 'package:flutter/widgets.dart';\n\n"
    "import '../foundation/lifeos_skin.dart';\n\n" + parts[start:end].rstrip() + '\n')
parts = parts[:start] + parts[end:]
parts = parts.replace("import 'package:flutter/widgets.dart';\n\n",
                      "import 'package:flutter/widgets.dart';\n\nimport '../controls/etched_line.dart';\n", 1)
open(parts_path, 'w').write(parts)

barrel_path = 'lib/ui/ui.dart'
barrel = open(barrel_path).read()
barrel = barrel.replace("export 'controls/era_time_field.dart';\n",
                        "export 'controls/era_time_field.dart';\nexport 'controls/etched_line.dart';\n")
barrel = barrel.replace("export 'controls/keys.dart';\n",
                        "export 'controls/keys.dart';\nexport 'controls/property_sheet_tabs.dart';\n")
open(barrel_path, 'w').write(barrel)
EOF
$DART fix --apply --code=directives_ordering lib
$DART format lib/ui
```

- **Step 3: Analyze and clean imports**

Run: `$FLUTTER analyze lib test tool`
Expected: `No issues found!` If `unused_import` is reported in `keys.dart` or `dialog_parts.dart`, delete exactly the reported import line and analyze again.

- **Step 4: Run guards, all tests, goldens untouched**

Run: `$FLUTTER test test/ui/library_boundary_test.dart && $FLUTTER test --reporter expanded && git status --porcelain -- ':(glob)test/goldens/**/*.png'`
Expected: 5 guard tests PASS; `All tests passed!`; no `git status` output.

- **Step 5: Record checkpoint**

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 5: The gallery host, its entry point and the `app.sh` item

**Files:**
- Create: `lib/app/startup_mode.dart`, `lib/ui/gallery/gallery_demo.dart`, `lib/ui/gallery/gallery_host.dart`, `lib/ui/gallery/gallery_app.dart`, `lib/ui/gallery/gallery_demos.dart`, `lib/ui/gallery/gallery_main.dart`, `lib/ui/gallery/demos/foundation_demos.dart`, `test/support/gallery.dart`, `test/ui/gallery/gallery_app_test.dart`, `test/ui/gallery/gallery_main_test.dart`, `test/repository/app_launcher_test.dart`
- Modify: `lib/main.dart:21-22`, `app.sh`

**Interfaces:**
- Consumes: `lib/ui/ui.dart`; `LocalDate` from `lib/core/time/local_date.dart`.
- Produces (used by Tasks 6–8):
  - `const LocalDate galleryToday` = `LocalDate(2026, 10, 8)`.
  - `final class GalleryKnobs { const GalleryKnobs({bool enabled = true, bool error = false, bool longText = false, double textScale = 1}); String text(String short, String long); String? get errorText; VoidCallback? press(VoidCallback action); GalleryKnobs copyWith({bool? enabled, bool? error, bool? longText, double? textScale}); }`
  - `final class GalleryDemo { const GalleryDemo({required String id, required String widget, required String summary, required Widget Function(BuildContext, GalleryKnobs) build, Size size = const Size(480, 240)}); String get folder; String get goldenName; }`
  - `final class GalleryValue<T> extends StatefulWidget { const GalleryValue({required T initial, required Widget Function(BuildContext context, T value, ValueChanged<T> update) builder}); }`
  - `final class GalleryHost extends StatefulWidget { const GalleryHost({required Widget home}); }`
  - `final class GalleryCanvas extends StatelessWidget { const GalleryCanvas({required GalleryDemo demo, required GalleryKnobs knobs}); final GalleryDemo demo; final GalleryKnobs knobs; }`
  - `final class GalleryApp extends StatelessWidget { const GalleryApp({List<GalleryDemo>? demos, GalleryKnobs initialKnobs = const GalleryKnobs()}); }`
  - `final List<GalleryDemo> galleryDemos` in `gallery_demos.dart`; `final List<GalleryDemo> foundationDemos` in `demos/foundation_demos.dart`.
  - `Future<void> runGallery({required Future<void> Function() prepareWindow, required Future<void> Function() showWindow, void Function(Widget app) mount = runApp})`.
  - `Future<void> pumpGalleryDemo(WidgetTester tester, GalleryDemo demo, {GalleryKnobs knobs = const GalleryKnobs()})` in `test/support/gallery.dart`.

- **Step 1: Write the failing tests**

Create `test/support/gallery.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

/// Pumps one gallery demo alone on its canvas, at the demo's golden size.
Future<void> pumpGalleryDemo(
  WidgetTester tester,
  GalleryDemo demo, {
  GalleryKnobs knobs = const GalleryKnobs(),
}) async {
  tester.view.physicalSize = demo.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryHost(
      home: GalleryCanvas(key: ValueKey(demo.id), demo: demo, knobs: knobs),
    ),
  );
  await tester.pumpAndSettle();
}
```

Create `test/ui/gallery/gallery_app_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_app.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/gallery.dart';

void main() {
  Future<void> pumpGallery(
    WidgetTester tester, {
    GalleryKnobs knobs = const GalleryKnobs(),
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GalleryApp(initialKnobs: knobs));
    await tester.pumpAndSettle();
  }

  GalleryCanvas canvas(WidgetTester tester) =>
      tester.widget<GalleryCanvas>(find.byType(GalleryCanvas));

  testWidgets('opens on the first demo and opens another from the list', (
    tester,
  ) async {
    await pumpGallery(tester);
    expect(canvas(tester).demo.id, galleryDemos.first.id);

    await tester.tap(find.text(galleryDemos[1].widget).first);
    await tester.pumpAndSettle();
    expect(canvas(tester).demo.id, galleryDemos[1].id);
  });

  testWidgets('the knobs reach the demo', (tester) async {
    await pumpGallery(tester);
    await tester.tap(find.text('Enabled'));
    await tester.tap(find.text('Show an error'));
    await tester.tap(find.text('Long text'));
    await tester.tap(find.text('200 % text'));
    await tester.pumpAndSettle();
    final knobs = canvas(tester).knobs;
    expect(knobs.enabled, isFalse);
    expect(knobs.error, isTrue);
    expect(knobs.longText, isTrue);
    expect(knobs.textScale, 2);
  });

  testWidgets('the gallery holds at 200 % text with long labels', (
    tester,
  ) async {
    await pumpGallery(
      tester,
      knobs: const GalleryKnobs(longText: true, textScale: 2),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryCanvas), findsOneWidget);
  });

  testWidgets('every demo builds alone without errors', (tester) async {
    for (final demo in galleryDemos) {
      await pumpGalleryDemo(tester, demo);
      expect(tester.takeException(), isNull, reason: demo.id);
    }
  });
}
```

Create `test/ui/gallery/gallery_main_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/startup_mode.dart';
import 'package:lifeos/ui/gallery/gallery_app.dart';
import 'package:lifeos/ui/gallery/gallery_main.dart';

void main() {
  test('startup executes only the mode selected by the launcher define', () async {
    const expectedGallery = String.fromEnvironment('LIFEOS_GALLERY') == '1';
    final calls = <String>[];
    await startSelectedMode(
      startGallery: () async => calls.add('gallery'),
      startProduction: () async {
        if (expectedGallery) fail('Gallery reached production startup');
        calls.add('production');
      },
    );
    expect(calls, [expectedGallery ? 'gallery' : 'production']);
  });

  test('main wires the isolated gallery and production callbacks', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('startSelectedMode('));
    expect(source, contains('startGallery: _startGallery'));
    expect(source, contains('startProduction: _startProduction'));
    final galleryStart = source.indexOf('Future<void> _startGallery()');
    final productionStart = source.indexOf('Future<void> _startProduction()');
    expect(galleryStart, isNonNegative);
    expect(productionStart, greaterThan(galleryStart));
    final gallery = source.substring(galleryStart, productionStart);
    expect(gallery, contains('runGallery('));
    expect(gallery, isNot(contains('bootstrap(')));
    expect(gallery, isNot(contains('DatabaseService')));
  });

  test('runGallery prepares the window, mounts the gallery, then shows it',
      () async {
    final calls = <String>[];
    Widget? mounted;
    await runGallery(
      prepareWindow: () async => calls.add('prepare'),
      showWindow: () async => calls.add('show'),
      mount: (app) {
        calls.add('mount');
        mounted = app;
      },
    );
    expect(calls, ['prepare', 'mount', 'show']);
    expect(mounted, isA<GalleryApp>());
  });
}
```

Create `test/repository/app_launcher_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the launcher opens the widget gallery from its menu', () {
    final launcher = File('app.sh').readAsStringSync();
    expect(launcher, contains("printf '  5) Open widget gallery\\n'"));
    expect(launcher, contains("printf '  6) Exit\\n'"));
    expect(launcher, contains('5) start_gallery ;;'));
    expect(launcher, contains('6) exit 0 ;;'));
    expect(launcher, contains('run -d linux --dart-define=LIFEOS_GALLERY=1'));
  });
}
```

- **Step 2: Run them to see them fail**

Run: `$FLUTTER test test/ui/gallery test/repository/app_launcher_test.dart`
Expected: FAIL. Compilation errors for the missing `package:lifeos/ui/gallery/...` files, and the launcher test fails on `5) Open widget gallery`.

- **Step 3: Write the demo model**

Create `lib/ui/gallery/gallery_demo.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';

/// The date the gallery treats as today: fixed, so goldens hold.
const galleryToday = LocalDate(2026, 10, 8);

/// The gallery's knobs: what the owner can vary on a demo.
@immutable
final class GalleryKnobs {
  const GalleryKnobs({
    this.enabled = true,
    this.error = false,
    this.longText = false,
    this.textScale = 1,
  });

  final bool enabled;
  final bool error;
  final bool longText;
  final double textScale;

  /// [long] while the Long text knob is on, otherwise [short].
  String text(String short, String long) => longText ? long : short;

  /// A validation message while the error knob is on.
  String? get errorText => error ? 'Enter a valid value.' : null;

  /// [action], or null so the key greys while the Enabled knob is off.
  VoidCallback? press(VoidCallback action) => enabled ? action : null;

  GalleryKnobs copyWith({
    bool? enabled,
    bool? error,
    bool? longText,
    double? textScale,
  }) => GalleryKnobs(
    enabled: enabled ?? this.enabled,
    error: error ?? this.error,
    longText: longText ?? this.longText,
    textScale: textScale ?? this.textScale,
  );
}

/// One library widget's demo (database shell spec 5.3). [id] is
/// `<folder>/<name>`; the folder is the widget's folder under `lib/ui/`.
@immutable
final class GalleryDemo {
  const GalleryDemo({
    required this.id,
    required this.widget,
    required this.summary,
    required this.build,
    this.size = const Size(480, 240),
  });

  final String id;

  /// The widget class the demo shows, as named in CATALOG.md.
  final String widget;
  final String summary;
  final Widget Function(BuildContext context, GalleryKnobs knobs) build;

  /// The canvas size of the demo's goldens.
  final Size size;

  String get folder => id.split('/').first;

  /// The golden's file name without extension: "controls_key_button".
  String get goldenName => id.replaceAll('/', '_');
}

/// Holds one demo value, so a demo's control can change it.
final class GalleryValue<T> extends StatefulWidget {
  const GalleryValue({required this.initial, required this.builder, super.key});

  final T initial;
  final Widget Function(BuildContext context, T value, ValueChanged<T> update)
  builder;

  @override
  State<GalleryValue<T>> createState() => _GalleryValueState<T>();
}

final class _GalleryValueState<T> extends State<GalleryValue<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, (value) => setState(() => _value = value));
}
```

- **Step 4: Write the host and canvas**

Create `lib/ui/gallery/gallery_host.dart`:

```dart
import 'package:flutter/material.dart';

import '../ui.dart';
import 'gallery_demo.dart';

/// The app around the gallery: the LifeOS theme, skin, era scrolling and
/// cell selection, as the real app provides them. Synthetic only; it opens
/// no database.
final class GalleryHost extends StatefulWidget {
  const GalleryHost({required this.home, super.key});

  final Widget home;

  @override
  State<GalleryHost> createState() => _GalleryHostState();
}

final class _GalleryHostState extends State<GalleryHost> {
  final _cells = CellSelectionController();

  @override
  void dispose() {
    _cells.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LifeOS widget gallery',
    debugShowCheckedModeBanner: false,
    theme: buildLifeOSTheme(),
    scrollBehavior: const EraScrollBehavior(),
    builder: (context, child) => CellSelectionScope(
      controller: _cells,
      child: LifeOSSkinScope(
        child: Builder(
          builder: (context) => Theme(
            data: lifeOSThemeFor(LifeOSSkinScope.of(context)),
            // Text fields need a Material ancestor; it paints nothing.
            child: Material(
              type: MaterialType.transparency,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
    home: widget.home,
  );
}

/// One demo on the property-sheet page colour, under its knobs: text scale,
/// and Enabled for every era field through [EraFormScope]. Scrolls when the
/// bounded demo surface is larger than the viewport in either axis.
final class GalleryCanvas extends StatelessWidget {
  const GalleryCanvas({required this.demo, required this.knobs, super.key});

  final GalleryDemo demo;
  final GalleryKnobs knobs;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: MillenniumColors.page,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(knobs.textScale)),
        child: EraFormScope(
          enabled: knobs.enabled,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              // The horizontal era scrollbar stacks under its content and
              // needs a bounded height: the demo's, plus the 17 px bar when
              // the demo is wider than the canvas.
              child: SizedBox(
                height:
                    demo.size.height * knobs.textScale +
                    (demo.size.width * knobs.textScale > viewport.maxWidth
                        ? 17
                        : 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: demo.size.width * knobs.textScale,
                    height: demo.size.height * knobs.textScale,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Builder(
                          builder: (context) => demo.build(context, knobs),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
```

- **Step 5: Write the gallery app**

Create `lib/ui/gallery/gallery_app.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../ui.dart';
import 'gallery_demo.dart';
import 'gallery_demos.dart';
import 'gallery_host.dart';

/// The widget gallery (database shell spec 5.3): every library widget on
/// synthetic data, picked from a list, with knobs. This phase 1 host is made
/// of moved controls and the existing list; phase 2 rebuilds it on AppFrame.
final class GalleryApp extends StatelessWidget {
  const GalleryApp({
    this.demos,
    this.initialKnobs = const GalleryKnobs(),
    super.key,
  });

  /// The demos to list; every library demo when null.
  final List<GalleryDemo>? demos;
  final GalleryKnobs initialKnobs;

  @override
  Widget build(BuildContext context) => GalleryHost(
    home: GalleryHome(
      demos: demos ?? galleryDemos,
      initialKnobs: initialKnobs,
    ),
  );
}

final class GalleryHome extends StatefulWidget {
  const GalleryHome({
    required this.demos,
    required this.initialKnobs,
    super.key,
  });

  final List<GalleryDemo> demos;
  final GalleryKnobs initialKnobs;

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

final class _GalleryHomeState extends State<GalleryHome> {
  static const _folders = {
    'foundation': 'Foundation',
    'controls': 'Controls',
    'data': 'Data',
    'shell': 'Shell',
  };

  late GalleryDemo _demo = widget.demos.first;
  late GalleryKnobs _knobs = widget.initialKnobs;

  void _knob(GalleryKnobs knobs) => setState(() => _knobs = knobs);

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return ColoredBox(
      color: skin.tokens.ground,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(_knobs.textScale)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DataRegister<GalleryDemo>(
                  label: 'Widgets',
                  lines: [
                    for (final MapEntry(key: folder, value: title)
                        in _folders.entries)
                      if (widget.demos.where((d) => d.folder == folder)
                          case final demos when demos.isNotEmpty) ...[
                        GroupLine<GalleryDemo>(
                          label: '$title (${demos.length})',
                        ),
                        for (final demo in demos) RowLine<GalleryDemo>(demo),
                      ],
                  ],
                  columns: [
                    RegisterColumn<GalleryDemo>(
                      key: 'widget',
                      label: 'Widget',
                      kind: ColumnKind.text,
                      width: 180,
                      value: (demo) => demo.widget,
                    ),
                    RegisterColumn<GalleryDemo>(
                      key: 'folder',
                      label: 'Folder',
                      kind: ColumnKind.text,
                      width: 80,
                      value: (demo) => demo.folder,
                    ),
                  ],
                  rowId: (demo) => demo.id,
                  rowLabel: (demo) => demo.widget,
                  selectedId: _demo.id,
                  onOpen: (demo) => setState(() => _demo = demo),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                    child: Text(_demo.widget, style: skin.typography.caption),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(_demo.summary, style: skin.typography.body),
                  ),
                  Expanded(
                    child: GalleryCanvas(
                      key: ValueKey(_demo.id),
                      demo: _demo,
                      knobs: _knobs,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 220,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: GroupBox(
                  legend: 'Knobs',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EraCheckBox(
                        value: _knobs.enabled,
                        onChanged: (on) => _knob(_knobs.copyWith(enabled: on)),
                        label: 'Enabled',
                      ),
                      EraCheckBox(
                        value: _knobs.error,
                        onChanged: (on) => _knob(_knobs.copyWith(error: on)),
                        label: 'Show an error',
                      ),
                      EraCheckBox(
                        value: _knobs.longText,
                        onChanged: (on) => _knob(_knobs.copyWith(longText: on)),
                        label: 'Long text',
                      ),
                      EraCheckBox(
                        value: _knobs.textScale == 2,
                        onChanged: (on) =>
                            _knob(_knobs.copyWith(textScale: on ? 2 : 1)),
                        label: '200 % text',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- **Step 6: Write the foundation demos and the registry**

Create `lib/ui/gallery/demos/foundation_demos.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final foundationDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'foundation/lifeos_skin_scope',
    widget: 'LifeOSSkinScope',
    summary:
        'Provides tokens, type and key painting to every LifeOS widget '
        'below it.',
    build: (context, knobs) => LifeOSSkinScope(
      child: Builder(
        builder: (context) {
          final t = LifeOSSkinScope.of(context).tokens;
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (name, colour) in [
                ('ground', t.ground),
                ('paper', t.paper),
                ('ink', t.ink),
                ('muted', t.muted),
                ('chrome', t.chrome),
                ('head', t.head),
                ('signal', t.signal),
                ('selWash', t.selWash),
                ('negative', t.negative),
                ('positive', t.positive),
              ])
                _Swatch(name: name, colour: colour),
            ],
          );
        },
      ),
    ),
  ),
  GalleryDemo(
    id: 'foundation/era_icon',
    widget: 'EraIcon',
    summary: 'The painted 16 and 32 px icon set; greyed when disabled.',
    build: (context, knobs) => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final kind in EraIconKind.values) ...[
          EraIcon(kind, disabled: !knobs.enabled),
          EraIcon(kind, size: 32, disabled: !knobs.enabled),
        ],
      ],
    ),
  ),
];

final class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.colour});

  final String name;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return SizedBox(
      width: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: colour,
              border: Border.all(color: skin.tokens.chromeLine),
            ),
          ),
          Text(name, style: skin.typography.small),
        ],
      ),
    );
  }
}
```

Create `lib/ui/gallery/gallery_demos.dart`:

```dart
import 'demos/foundation_demos.dart';
import 'gallery_demo.dart';

/// Every library widget's demo, in catalog order.
final List<GalleryDemo> galleryDemos = [...foundationDemos];
```

- **Step 7: Write the entry point and route `main.dart` to it**

Create `lib/app/startup_mode.dart`:

```dart
/// The launcher passes the exact value 1. bool.fromEnvironment would treat
/// that value as false, falling through to production startup.
const galleryRequested = String.fromEnvironment('LIFEOS_GALLERY') == '1';

Future<void> startSelectedMode({
  required Future<void> Function() startGallery,
  required Future<void> Function() startProduction,
}) => galleryRequested ? startGallery() : startProduction();
```

Create `lib/ui/gallery/gallery_main.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'gallery_app.dart';

/// Starts the widget gallery instead of LifeOS (`./app.sh` › Open widget
/// gallery, `--dart-define=LIFEOS_GALLERY=1`). It shows synthetic data only
/// and never opens a database.
Future<void> runGallery({
  required Future<void> Function() prepareWindow,
  required Future<void> Function() showWindow,
  void Function(Widget app) mount = runApp,
}) async {
  await prepareWindow();
  mount(const GalleryApp());
  await showWindow();
}
```

In `lib/main.dart`, add sorted imports for `app/startup_mode.dart` and
`ui/gallery/gallery_main.dart`. Rename the existing `main` function to
`_startProduction`, keeping its body unchanged, and insert these functions
before it:

```dart
Future<void> main() => startSelectedMode(
  startGallery: _startGallery,
  startProduction: _startProduction,
);

Future<void> _startGallery() async {
  if (Platform.isLinux) TrailingFrameBinding();
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final window = WindowManagerDesktopWindowService();
  await runGallery(
    prepareWindow: () async {
      await window.prepare();
      await window.setTitle('LifeOS widget gallery');
    },
    showWindow: window.show,
  );
}
```

The selector invokes exactly one callback. The gallery callback constructs no
clock, timezone service, providers or database. Production keeps its current
bootstrap and the trailing-frame workaround remains in both entry paths.

- **Step 8: Add the gallery to `app.sh`**

In `app.sh`, after the `start_debug()` function, add:

```bash
# The widget gallery: every UI library widget on synthetic data. It never
# opens the database.
start_gallery() {
    printf '\nPreparing LifeOS...\n'
    "$flutter" pub get
    printf '\nOpening the LifeOS widget gallery (debug build with hot reload)...\n'
    "$flutter" run -d linux --dart-define=LIFEOS_GALLERY=1
}
```

Replace the menu lines and cases:

```bash
    printf '  4) Start app in debug mode (hot reload)\n'
    printf '  5) Open widget gallery\n'
    printf '  6) Exit\n'
```

```bash
        4) start_debug ;;
        5) start_gallery ;;
        6) exit 0 ;;
        *) printf 'Invalid choice. Enter 1, 2, 3, 4, 5, or 6.\n' ;;
```

(The old lines were `5) Exit`, `5) exit 0 ;;` and `Enter 1, 2, 3, 4, or 5.`.)

- **Step 9: Run the tests**

Run: `$DART format lib test && $FLUTTER test test/ui test/repository`
Then run `$FLUTTER test --dart-define=LIFEOS_GALLERY=1 test/ui/gallery/gallery_main_test.dart`
and `$FLUTTER test --dart-define=LIFEOS_GALLERY=0 test/ui/gallery/gallery_main_test.dart`.
Expected: all pass; the exact value 1 selects only gallery, while unset/0
select only production. Never validate the mode switch only by matching source text.

- **Step 10: Analyze, full suite, goldens untouched**

Run: `$FLUTTER analyze lib test tool && $FLUTTER test --reporter expanded && git status --porcelain -- ':(glob)test/goldens/**/*.png'`
Expected: `No issues found!`, `All tests passed!`, no `git status` output.

- **Step 11: Record checkpoint**

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 6: Demos for the 27 control widgets

**Files:**
- Create: `lib/ui/gallery/demos/control_demos.dart`, `test/ui/gallery/demos_test.dart`
- Modify: `lib/ui/gallery/gallery_demos.dart`

**Interfaces:**
- Consumes: `GalleryDemo`, `GalleryKnobs`, `GalleryValue<T>`, `galleryToday`, `pumpGalleryDemo` (Task 5); `LocalDate`, `LocalTime`.
- Produces: `final List<GalleryDemo> controlDemos` with these ids and widgets (Tasks 7 and 8 rely on the ids):
  `controls/orb` Orb · `controls/era_combo_face` EraComboFace · `controls/combo_arrow` ComboArrow · `controls/group_box` GroupBox · `controls/form_footer` FormFooter · `controls/era_glyph` EraGlyph · `controls/era_pressable` EraPressable · `controls/key_button` KeyButton · `controls/step_key` StepKey · `controls/area_key` AreaKey · `controls/count_badge` CountBadge · `controls/property_sheet_tabs` PropertySheetTabs · `controls/etched_line` EtchedLine · `controls/era_combo` EraCombo · `controls/era_field` EraField · `controls/era_form_scope` EraFormScope · `controls/era_labelled` EraLabelled · `controls/era_check_box` EraCheckBox · `controls/era_radio` EraRadio · `controls/era_radio_group` EraRadioGroup · `controls/era_date_field` EraDateField · `controls/era_time_field` EraTimeField · `controls/era_month_calendar` EraMonthCalendar · `controls/era_menu_label` EraMenuLabel · `controls/era_menu_button` EraMenuButton · `controls/era_context_menu` EraContextMenu · `controls/era_scrollbar` EraScrollbar.

- **Step 1: Write the failing tests**

Create `test/ui/gallery/demos_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/control_demos.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

void main() {
  testWidgets('every control demo builds alone, plain and with every knob', (
    tester,
  ) async {
    for (final demo in controlDemos) {
      for (final knobs in const [
        GalleryKnobs(),
        GalleryKnobs(enabled: false, error: true, longText: true),
      ]) {
        await pumpGalleryDemo(tester, demo, knobs: knobs);
        expect(tester.takeException(), isNull, reason: demo.id);
      }
    }
  });

  testWidgets("the Enabled knob disables the key demo's keys", (tester) async {
    final demo = controlDemos.singleWhere((d) => d.id == 'controls/key_button');
    await pumpGalleryDemo(
      tester,
      demo,
      knobs: const GalleryKnobs(enabled: false),
    );
    final keys = tester.widgetList<KeyButton>(find.byType(KeyButton)).toList();
    expect(keys, hasLength(KeyKind.values.length));
    expect(keys.map((key) => key.onPressed), everyElement(isNull));
  });

  testWidgets('the check box demo toggles', (tester) async {
    final demo = controlDemos.singleWhere(
      (d) => d.id == 'controls/era_check_box',
    );
    await pumpGalleryDemo(tester, demo);
    expect(tester.widget<EraCheckBox>(find.byType(EraCheckBox)).value, isTrue);
    await tester.tap(find.text('Off days'));
    await tester.pump();
    expect(tester.widget<EraCheckBox>(find.byType(EraCheckBox)).value, isFalse);
  });
}
```

Run: `$FLUTTER test test/ui/gallery/demos_test.dart`
Expected: FAIL to compile: `control_demos.dart` not found.

- **Step 2: Write the control demos**

Create `lib/ui/gallery/demos/control_demos.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

final controlDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'controls/orb',
    widget: 'Orb',
    summary:
        'The glossy toolbar orb: green Back and Forward, orange Add, grey '
        'when unavailable.',
    build: (context, knobs) => Wrap(
      spacing: 8,
      children: [
        Orb(
          glyph: OrbGlyph.back,
          tone: knobs.enabled ? OrbTone.green : OrbTone.grey,
        ),
        Orb(
          glyph: OrbGlyph.forward,
          tone: knobs.enabled ? OrbTone.green : OrbTone.grey,
        ),
        Orb(
          glyph: OrbGlyph.add,
          tone: knobs.enabled ? OrbTone.orange : OrbTone.grey,
        ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/era_combo_face',
    widget: 'EraComboFace',
    summary: 'A closed combo box: a white field beside the blue drop arrow.',
    build: (context, knobs) => EraComboFace(
      value: knobs.text('Shifts', 'Shifts and planned days for October 2026'),
    ),
  ),
  GalleryDemo(
    id: 'controls/combo_arrow',
    widget: 'ComboArrow',
    summary: 'The blue drop-arrow button at the right of a combo box.',
    build: (context, knobs) =>
        const SizedBox(width: 17, height: 21, child: ComboArrow()),
  ),
  GalleryDemo(
    id: 'controls/group_box',
    widget: 'GroupBox',
    summary: 'A titled frame around related fields, its legend in Head blue.',
    build: (context, knobs) => SizedBox(
      width: 300,
      child: GroupBox(
        legend: knobs.text('Rate', 'Rate, premiums and leave terms'),
        child: const Text('Hourly rate: EUR 18.40'),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/form_footer',
    widget: 'FormFooter',
    summary: "A form's keys, right-aligned, the affirmative key first.",
    build: (context, knobs) => SizedBox(
      width: 360,
      child: FormFooter(
        children: [
          KeyButton(
            label: knobs.text('Save', 'Save and reprice confirmed days'),
            kind: KeyKind.primary,
            onPressed: knobs.press(() {}),
          ),
          KeyButton(label: 'Cancel', onPressed: knobs.press(() {})),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_glyph',
    widget: 'EraGlyph',
    summary:
        'Painted marks: drop, sort and step arrows, collapse chevrons and a '
        'tick.',
    build: (context, knobs) => Wrap(
      spacing: 12,
      children: [
        for (final kind in EraGlyphKind.values)
          EraGlyph(
            kind,
            color: LifeOSSkinScope.of(context).tokens.ink,
            size: 12,
          ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/era_pressable',
    widget: 'EraPressable',
    summary:
        'A small pressable link or button with the dotted focus rectangle.',
    build: (context, knobs) => EraPressable(
      label: 'Confirm this day',
      link: true,
      onPressed: () {},
      child: Text(
        knobs.text(
          'Confirm this day…',
          'Confirm this day and every earlier unconfirmed day…',
        ),
        style: const TextStyle(color: MillenniumColors.link),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/key_button',
    widget: 'KeyButton',
    summary:
        'The era push key: primary (default ring), secondary, small and the '
        'flat toolbar kind.',
    build: (context, knobs) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in KeyKind.values)
          KeyButton(
            label: switch (kind) {
              KeyKind.primary => knobs.text('OK', 'Save agreement'),
              KeyKind.secondary => 'Cancel',
              KeyKind.small => 'Change…',
              KeyKind.toolbar => 'Back',
            },
            kind: kind,
            onPressed: knobs.press(() {}),
          ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/step_key',
    widget: 'StepKey',
    summary: 'Small keys with painted step arrows, for periods and days.',
    build: (context, knobs) => Wrap(
      spacing: 4,
      children: [
        StepKey(
          forward: false,
          semanticLabel: 'Previous month',
          onPressed: knobs.press(() {}),
        ),
        StepKey(
          forward: true,
          semanticLabel: 'Next month',
          onPressed: knobs.press(() {}),
        ),
      ],
    ),
  ),
  GalleryDemo(
    id: 'controls/area_key',
    widget: 'AreaKey',
    summary: "The painted icon that marks a record's area.",
    build: (context, knobs) => Wrap(
      spacing: 8,
      children: [for (final area in LifeOSArea.values) AreaKey(area: area)],
    ),
  ),
  GalleryDemo(
    id: 'controls/count_badge',
    widget: 'CountBadge',
    summary: 'An orange count of things waiting on the owner.',
    build: (context, knobs) => CountBadge(
      count: knobs.longText ? 128 : 2,
      semanticLabel: 'days to confirm',
    ),
  ),
  GalleryDemo(
    id: 'controls/property_sheet_tabs',
    widget: 'PropertySheetTabs',
    summary:
        'Property-sheet tabs; the active one joins the page with a warm top '
        'edge.',
    build: (context, knobs) => SizedBox(
      width: 360,
      child: GalleryValue<int>(
        initial: 0,
        builder: (context, index, select) => PropertySheetTabs(
          labels: [
            'Rate',
            'Premiums',
            'Leave',
            knobs.text('Notes', 'Notes and history of changes'),
          ],
          selectedIndex: index,
          onSelected: select,
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/etched_line',
    widget: 'EtchedLine',
    summary: 'A 2 px etched separator: a grey line over a white one.',
    build: (context, knobs) => const SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paid time: 11:30'),
          EtchedLine(),
          Text('Est. pay: EUR 211.60'),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_combo',
    widget: 'EraCombo',
    summary:
        'A drop-down list combo; its list drops below with the current value '
        'lit.',
    size: const Size(480, 280),
    build: (context, knobs) => GalleryValue<String>(
      initial: 'effective',
      builder: (context, value, select) => EraCombo<String>(
        items: [
          const EraComboItem('effective', 'Effective'),
          const EraComboItem('all', 'All records'),
          EraComboItem(
            'voided',
            knobs.text('Voided', 'Voided and replaced records'),
          ),
        ],
        value: value,
        onSelected: select,
        semanticLabel: 'Status',
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_field',
    widget: 'EraField',
    summary: '"Label:" and a sunken white text field; an error shows under it.',
    build: (context, knobs) => _FieldDemo(knobs: knobs),
  ),
  GalleryDemo(
    id: 'controls/era_form_scope',
    widget: 'EraFormScope',
    summary:
        "Sets a form's label-column width and greys every era field when "
        'disabled.',
    build: (context, knobs) => SizedBox(
      width: 360,
      child: EraFormScope(
        labelWidth: 120,
        enabled: knobs.enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EraLabelled(label: 'Hourly rate (€)', field: Text('18.40')),
            EraLabelled(
              label: 'Basis',
              field: GalleryValue<String>(
                initial: 'gross',
                builder: (context, value, select) => EraRadioGroup<String>(
                  options: const [
                    EraRadioOption('gross', 'Gross'),
                    EraRadioOption('net', 'Net'),
                  ],
                  groupValue: value,
                  onChanged: knobs.enabled ? select : null,
                  direction: Axis.horizontal,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_labelled',
    widget: 'EraLabelled',
    summary: '"Label:" in the label column, then the field at its kind width.',
    build: (context, knobs) => SizedBox(
      width: 360,
      child: EraLabelled(
        label: knobs.text(
          'Hourly rate (€)',
          'Hourly rate before tax and premiums (€)',
        ),
        fieldWidth: EraFieldWidth.money,
        field: const EraComboFace(value: '18.40'),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_check_box',
    widget: 'EraCheckBox',
    summary: 'A 13 px era check box; the whole row toggles it.',
    build: (context, knobs) => GalleryValue<bool>(
      initial: true,
      builder: (context, value, set) => EraCheckBox(
        value: value,
        onChanged: knobs.enabled ? set : null,
        label: knobs.text(
          'Off days',
          'Show off days between shifts in the list',
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_radio',
    widget: 'EraRadio',
    summary: 'A 13 px era radio with its label; the whole row selects it.',
    build: (context, knobs) => GalleryValue<String>(
      initial: 'gross',
      builder: (context, value, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraRadio<String>(
            value: 'gross',
            groupValue: value,
            onChanged: knobs.enabled ? set : null,
            label: 'Gross',
          ),
          EraRadio<String>(
            value: 'net',
            groupValue: value,
            onChanged: knobs.enabled ? set : null,
            label: 'Net',
            detail: knobs.text(
              'After tax',
              'After income tax and social insurance',
            ),
          ),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_radio_group',
    widget: 'EraRadioGroup',
    summary: 'Era radios that act as one choice.',
    build: (context, knobs) => GalleryValue<String>(
      initial: 'vacation',
      builder: (context, value, set) => EraRadioGroup<String>(
        options: const [
          EraRadioOption('vacation', 'Vacation'),
          EraRadioOption('sick', 'Sick leave'),
          EraRadioOption('unpaid', 'Unpaid leave'),
        ],
        groupValue: value,
        onChanged: knobs.enabled ? set : null,
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_date_field',
    widget: 'EraDateField',
    summary:
        'A date box ("Wed 2026-10-07") with a drop arrow to the month '
        'calendar.',
    size: const Size(480, 320),
    build: (context, knobs) => GalleryValue<LocalDate?>(
      initial: const LocalDate(2026, 10, 7),
      builder: (context, value, set) => EraDateField(
        label: knobs.text('Starts on', 'Agreement starts on (first paid day)'),
        value: value,
        onChanged: set,
        today: galleryToday,
        error: knobs.errorText,
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_time_field',
    widget: 'EraTimeField',
    summary: 'A time box with spin arrows; its parts are stepped or typed.',
    build: (context, knobs) => GalleryValue<LocalTime?>(
      initial: const LocalTime(19, 45),
      builder: (context, value, set) => EraTimeField(
        label: knobs.text('End', 'End of the shift (next day after midnight)'),
        value: value,
        onChanged: set,
        enabled: knobs.enabled,
        error: knobs.errorText,
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_month_calendar',
    widget: 'EraMonthCalendar',
    summary:
        'The month calendar: Monday-first weeks, today circled, a Today '
        'link.',
    size: const Size(480, 320),
    build: (context, knobs) => GalleryValue<LocalDate?>(
      initial: const LocalDate(2026, 10, 7),
      builder: (context, value, set) => EraMonthCalendar(
        today: galleryToday,
        selected: value,
        onPicked: set,
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_menu_label',
    widget: 'EraMenuLabel',
    summary: "A menu row's icon gutter and text; the default command is bold.",
    size: const Size(680, 240),
    build: (context, knobs) => SizedBox(
      width: 620 * knobs.textScale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraMenuLabel(
            EraMenuItem(
              'Open',
              () {},
              isDefault: true,
              icon: EraIconKind.properties,
            ),
          ),
          EraMenuLabel(
            EraMenuItem(
              knobs.text('Delete', 'Delete this shift and its breaks'),
              () {},
              icon: EraIconKind.delete,
            ),
          ),
          EraMenuLabel(EraMenuItem('Off days', () {}, checked: true)),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_menu_button',
    widget: 'EraMenuButton',
    summary: 'A key that drops an era menu, as Add does.',
    build: (context, knobs) => EraMenuButton(
      items: [
        EraMenuItem('Shift', () {}, icon: EraIconKind.shift),
        EraMenuItem('Pay period', () {}, icon: EraIconKind.payPeriod),
        const EraMenuItem.separator(),
        EraMenuItem('Employment…', () {}, icon: EraIconKind.employment),
      ],
      builder: (context, toggle) => KeyButton(
        label: 'Add',
        kind: KeyKind.toolbar,
        leading: const Orb(glyph: OrbGlyph.add, tone: OrbTone.orange),
        onPressed: knobs.press(toggle),
      ),
    ),
  ),
  GalleryDemo(
    id: 'controls/era_context_menu',
    widget: 'EraContextMenu',
    summary: 'The right-click menu, opened at once with its corner at the pointer.',
    build: (context, knobs) => const _ContextMenuDemo(),
  ),
  GalleryDemo(
    id: 'controls/era_scrollbar',
    widget: 'EraScrollbar',
    summary:
        'The 17 px era scrollbar: arrow keys, a pale track and a blue thumb '
        'with grip lines.',
    build: (context, knobs) => const _ScrollbarDemo(),
  ),
];

final class _FieldDemo extends StatefulWidget {
  const _FieldDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_FieldDemo> createState() => _FieldDemoState();
}

final class _FieldDemoState extends State<_FieldDemo> {
  final _controller = TextEditingController(text: 'Stayed for handover');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: EraField(
      controller: _controller,
      label: widget.knobs.text(
        'Note',
        'A note about this day for the payroll office',
      ),
      error: widget.knobs.errorText,
    ),
  );
}

final class _ContextMenuDemo extends StatefulWidget {
  const _ContextMenuDemo();

  @override
  State<_ContextMenuDemo> createState() => _ContextMenuDemoState();
}

final class _ContextMenuDemoState extends State<_ContextMenuDemo> {
  final _menu = GlobalKey<EraContextMenuState>();

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return EraContextMenu(
      key: _menu,
      child: GestureDetector(
        onSecondaryTapDown: (details) => _menu.currentState?.show(
          details.globalPosition,
          [
            EraMenuItem(
              'Open',
              () {},
              isDefault: true,
              icon: EraIconKind.properties,
            ),
            const EraMenuItem.separator(),
            EraMenuItem('Delete', () {}, icon: EraIconKind.delete),
          ],
        ),
        child: Container(
          width: 240,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.paper,
            border: Border.all(color: tokens.chromeLine),
          ),
          child: const Text('Right-click here'),
        ),
      ),
    );
  }
}

final class _ScrollbarDemo extends StatefulWidget {
  const _ScrollbarDemo();

  @override
  State<_ScrollbarDemo> createState() => _ScrollbarDemoState();
}

final class _ScrollbarDemoState extends State<_ScrollbarDemo> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return SizedBox(
      width: 240,
      height: 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          border: Border.all(color: MillenniumColors.fieldLine),
        ),
        // The era scroll behavior would add a second bar; this demo draws
        // the bar itself.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false),
          child: EraScrollbar(
            controller: _controller,
            axis: Axis.vertical,
            child: ListView(
              controller: _controller,
              children: [
                for (var row = 1; row <= 30; row++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text('Row $row'),
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

In `lib/ui/gallery/gallery_demos.dart` add `import 'demos/control_demos.dart';` (sorted first) and change the list to `[...foundationDemos, ...controlDemos]`.

- **Step 3: Run the tests**

Run: `$DART format lib test && $FLUTTER test test/ui/gallery`
Expected: PASS. If one demo throws a layout error (for example an unbounded width), give that demo a `SizedBox(width: …)` around its widget, as the other demos do, and re-run. Do not change the library widget.

- **Step 4: Analyze and record checkpoint**

Run: `$FLUTTER analyze lib test tool`
Expected: `No issues found!`

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 7: Data and shell demos, the coverage guard and the demo goldens

**Files:**
- Create: `lib/ui/gallery/demos/data_demos.dart`, `lib/ui/gallery/demos/shell_demos.dart`, `test/support/ui_library.dart`, `test/ui/gallery/gallery_goldens_test.dart`, `test/ui/gallery/gallery_real_font_test.dart`, `test/ui/goldens/*.png` (generated)
- Modify: `lib/ui/gallery/gallery_demos.dart`, `test/ui/gallery/demos_test.dart`

**Interfaces:**
- Consumes: Task 5 and Task 6.
- Produces:
  - `final List<GalleryDemo> dataDemos` with ids `data/data_register` DataRegister · `data/cell_selection_scope` CellSelectionScope · `data/operational_state` OperationalState.
  - `final List<GalleryDemo> shellDemos` with ids `shell/era_dialog` EraDialog · `shell/era_movable_dialog` EraMovableDialog · `shell/caption_bar` CaptionBar · `shell/inspector_pane` InspectorPane · `shell/dialog_form` DialogForm · `shell/inspector_title` InspectorTitle · `shell/inspector_facts` InspectorFacts · `shell/inspector_fact_row` InspectorFactRow · `shell/inspector_note` InspectorNote · `shell/inspector_text` InspectorText · `shell/inspector_actions` InspectorActions · `shell/property_sheet_scope` PropertySheetScope.
  - `Map<String, String> libraryWidgetClasses()` in `test/support/ui_library.dart`: every public widget class in `lib/ui/` (gallery excluded) → its path relative to `lib/ui/`, for example `'KeyButton': 'controls/keys.dart'`.
  - Goldens at `test/ui/goldens/<goldenName>.png` and `test/ui/goldens/real_font/<goldenName>.png`.

- **Step 1: Write the coverage guard**

Create `test/support/ui_library.dart`:

```dart
import 'dart:io';

final _widgetClass = RegExp(
  r'^(?:(?:final|abstract|base|sealed|interface)\s+)*class\s+([A-Z]\w*)'
  r'(?:<[^{]*?>)?\s+extends\s+(?:StatelessWidget|StatefulWidget|'
  r'InheritedWidget|InheritedNotifier|InheritedModel|ProxyWidget|'
  r'RenderObjectWidget|SingleChildRenderObjectWidget|LeafRenderObjectWidget|'
  r'MultiChildRenderObjectWidget)\b',
  multiLine: true,
);

/// Every public widget class in the UI library (the gallery excluded), with
/// its file relative to `lib/ui/`: `'KeyButton': 'controls/keys.dart'`.
Map<String, String> libraryWidgetClasses() => {
  for (final file in Directory('lib/ui').listSync(recursive: true))
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.startsWith('lib/ui/gallery/'))
      for (final match in _widgetClass.allMatches(file.readAsStringSync()))
        match.group(1)!: file.path.substring('lib/ui/'.length),
};
```

Append to `test/ui/gallery/demos_test.dart` (add `import 'package:lifeos/ui/gallery/gallery_demos.dart';` and `import '../../support/ui_library.dart';` to its imports):

```dart
  test('every library widget has exactly one demo, in its own folder', () {
    final classes = libraryWidgetClasses();
    expect(classes.length, greaterThanOrEqualTo(44));
    final byWidget = <String, List<GalleryDemo>>{};
    for (final demo in galleryDemos) {
      byWidget.putIfAbsent(demo.widget, () => []).add(demo);
    }
    expect(byWidget.keys.toSet(), classes.keys.toSet());
    for (final MapEntry(key: name, value: demos) in byWidget.entries) {
      expect(demos, hasLength(1), reason: name);
      expect(demos.single.folder, classes[name]!.split('/').first, reason: name);
    }
    expect(
      galleryDemos.map((demo) => demo.id).toSet(),
      hasLength(galleryDemos.length),
    );
  });
```

Run: `$FLUTTER test test/ui/gallery/demos_test.dart`
Expected: the new test FAILS: the demo widget set lacks `DataRegister`, `EraDialog` and the other data and shell widgets.

- **Step 2: Write the data demos**

Create `lib/ui/gallery/demos/data_demos.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final dataDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'data/data_register',
    widget: 'DataRegister',
    summary:
        'The details list: bevelled sortable headers, group rows, 20 px rows, '
        'planned rows greyed, a subtotal.',
    size: const Size(640, 260),
    build: (context, knobs) => GalleryValue<String?>(
      initial: '2026-10-06',
      builder: (context, selected, select) => SizedBox(
        width: 600,
        height: 220,
        child: DataRegister<_Day>(
          label: 'Shifts',
          lines: [
            GroupLine<_Day>(
              label: 'October 2026',
              summary: knobs.text(
                '3 shifts',
                '3 shifts, 34:30 paid, EUR 634.80 expected',
              ),
            ),
            for (final day in _days)
              RowLine<_Day>(
                day,
                state: day.planned ? RowState.planned : RowState.normal,
              ),
            const SubtotalLine<_Day>(
              label: 'Total',
              cells: {'paid': '34:30', 'pay': 'EUR 634.80'},
            ),
          ],
          columns: [
            RegisterColumn<_Day>(
              key: 'date',
              label: 'Date',
              kind: ColumnKind.date,
              width: 96,
              value: (day) => day.date,
            ),
            RegisterColumn<_Day>(
              key: 'type',
              label: 'Type',
              kind: ColumnKind.text,
              width: 64,
              value: (day) => day.type,
            ),
            RegisterColumn<_Day>(
              key: 'paid',
              label: 'Paid',
              kind: ColumnKind.duration,
              width: 64,
              value: (day) => day.paid,
            ),
            RegisterColumn<_Day>(
              key: 'pay',
              label: 'Est. pay',
              kind: ColumnKind.money,
              width: 96,
              value: (day) => day.pay,
            ),
            RegisterColumn<_Day>(
              key: 'state',
              label: 'State',
              kind: ColumnKind.state,
              width: 96,
              value: (day) => day.state,
            ),
          ],
          rowId: (day) => day.date,
          rowLabel: (day) => 'Shift ${day.date}',
          selectedId: selected,
          onOpen: (day) => select(day.date),
          sortedColumn: 'date',
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'data/cell_selection_scope',
    widget: 'CellSelectionScope',
    summary:
        'Shares the selected list cell with the window, for a derived '
        "figure's explanation.",
    build: (context, knobs) => const _CellSelectionDemo(),
  ),
  GalleryDemo(
    id: 'data/operational_state',
    widget: 'OperationalState',
    summary:
        "A sheet's loading, empty, unavailable, conflict and uncertain "
        'states.',
    build: (context, knobs) => SizedBox(
      width: 420,
      height: 180,
      child: OperationalState(
        kind: knobs.error
            ? OperationalStateKind.unavailable
            : OperationalStateKind.empty,
        title: knobs.error ? 'Shifts are unavailable' : 'No shifts yet',
        message: knobs.text(
          'Add a shift or set up a schedule.',
          'Add a shift by hand, or set up a pay agreement and a schedule so '
              'planned days appear here.',
        ),
        action: KeyButton(label: 'Add a shift', onPressed: knobs.press(() {})),
      ),
    ),
  ),
];

final class _Day {
  const _Day(
    this.date,
    this.type,
    this.paid,
    this.pay,
    this.state, {
    this.planned = false,
  });

  final String date;
  final String type;
  final String paid;
  final String pay;
  final String state;
  final bool planned;
}

const _days = [
  _Day('2026-10-05', 'Day', '11:30', 'EUR 211.60', 'Finalized'),
  _Day('2026-10-06', 'Day', '11:30', 'EUR 211.60', 'To confirm'),
  _Day('2026-10-07', 'Day', '11:30', 'EUR 211.60', 'To confirm'),
  _Day('2026-10-11', 'Night', '11:30', 'EUR 280.60', 'Planned', planned: true),
];

final class _CellSelectionDemo extends StatefulWidget {
  const _CellSelectionDemo();

  @override
  State<_CellSelectionDemo> createState() => _CellSelectionDemoState();
}

final class _CellSelectionDemoState extends State<_CellSelectionDemo> {
  final _cells = CellSelectionController();

  @override
  void dispose() {
    _cells.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CellSelectionScope(
    controller: _cells,
    child: ValueListenableBuilder<CellSelection?>(
      valueListenable: _cells,
      builder: (context, cell, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cell == null ? 'No cell selected.' : '${cell.columnLabel}: ${cell.display}'),
          KeyButton(
            label: 'Select paid time',
            onPressed: () => _cells.value = CellSelection(
              owner: this,
              reference: 'D1',
              columnLabel: 'Paid',
              display: '11:30',
            ),
          ),
          KeyButton(label: 'Clear selection', onPressed: () => _cells.clearFrom(this)),
        ],
      ),
    ),
  );
}
```

- **Step 3: Write the shell demos**

Create `lib/ui/gallery/demos/shell_demos.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final shellDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'shell/era_dialog',
    widget: 'EraDialog',
    summary:
        'An era window: blue caption, red close key, keys bottom-right. The '
        'base of the coming confirmation window.',
    size: const Size(600, 380),
    build: (context, knobs) => SizedBox(
      width: 560,
      height: 340,
      child: EraDialog(
        title: knobs.text('Delete record?', 'Delete this unused synthetic record?'),
        body: const Text('This unused synthetic record will be deleted.'),
        actions: [
          KeyButton(
            label: 'Delete',
            kind: KeyKind.primary,
            onPressed: knobs.press(() {}),
          ),
          KeyButton(label: 'Cancel', onPressed: knobs.press(() {})),
        ],
        onClose: () {},
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/era_movable_dialog',
    widget: 'EraMovableDialog',
    summary: 'Lets a dialog be dragged by its caption, kept inside its space.',
    size: const Size(600, 380),
    build: (context, knobs) => SizedBox(
      width: 560,
      height: 340,
      // EraDialog supplies the EraMovableDialog under test. Do not nest a
      // second movable shell around a dialog that expands to its bounds.
      child: EraDialog(
            title: 'Drag the caption',
            body: const Text('The window stays inside this area.'),
            actions: [
              KeyButton(label: 'OK', kind: KeyKind.primary, onPressed: knobs.press(() {})),
            ],
          ),
    ),
  ),
  GalleryDemo(
    id: 'shell/caption_bar',
    widget: 'CaptionBar',
    summary: 'The blue gradient caption with a title and a red close key.',
    build: (context, knobs) => SizedBox(
      width: 320,
      child: CaptionBar(
        title: knobs.text(
          'Pay agreement',
          'Pay agreement from 2026-10-01 for Synthetic depot',
        ),
        onClose: () {},
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_pane',
    widget: 'InspectorPane',
    summary: 'A scrolling Properties page on the inspector inset.',
    size: const Size(480, 280),
    build: (context, knobs) => SizedBox(
      width: 340,
      height: 240,
      child: InspectorPane(
        children: [
          const InspectorTitle(
            'Synthetic depot',
            meta: 'Employment',
            icon: EraIconKind.employment,
          ),
          const InspectorFacts([
            Fact('Hourly rate', 'EUR 18.40'),
            Fact('Night premium', '+50 %'),
          ], legend: 'Pay'),
          InspectorNote(
            knobs.text(
              'Defaults follow the agreement.',
              'Defaults follow the pay agreement; change it from Agreements.',
            ),
          ),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/dialog_form',
    widget: 'DialogForm',
    summary: 'Form fields that scroll above keys pinned bottom-right.',
    size: const Size(480, 280),
    build: (context, knobs) => SizedBox(
      width: 380,
      height: 220,
      child: DialogForm(
        fields: const [
          EraLabelled(label: 'Hourly rate (€)', field: Text('18.40')),
          EraLabelled(label: 'Basis', field: Text('Gross')),
        ],
        keys: [
          KeyButton(
            label: 'Save agreement',
            kind: KeyKind.primary,
            onPressed: knobs.press(() {}),
          ),
          KeyButton(label: 'Cancel', onPressed: knobs.press(() {})),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_title',
    widget: 'InspectorTitle',
    summary: "A record's name, kind and icon atop a Properties page.",
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorTitle(
        knobs.text(
          'Shift 2026-10-07',
          'Shift on Wednesday 2026-10-07, Synthetic depot',
        ),
        meta: 'To confirm',
        icon: EraIconKind.shift,
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_facts',
    widget: 'InspectorFacts',
    summary: 'A block of "Label:" facts closed by an etched line.',
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorFacts([
        const Fact('Paid time', '12:15'),
        const Fact('Est. pay', 'EUR 225.40'),
        Fact(
          'Difference',
          '+0:45',
          tone: knobs.error ? FactTone.negative : FactTone.positive,
        ),
      ], legend: 'Pay'),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_fact_row',
    widget: 'InspectorFactRow',
    summary: 'One "Label:" fact row.',
    build: (context, knobs) => const SizedBox(
      width: 340,
      child: InspectorFactRow(fact: Fact('Hourly rate', 'EUR 18.40')),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_note',
    widget: 'InspectorNote',
    summary: 'A secondary line under the facts; red when negative.',
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorNote(
        knobs.text(
          'Finalized. Use Correct… to change it.',
          'Finalized on 2026-10-06. Use Correct… to void it and record a '
              'replacement.',
        ),
        tone: knobs.error ? FactTone.negative : null,
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_text',
    widget: 'InspectorText',
    summary: 'Body text that is the content itself.',
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorText(
        knobs.text(
          'Defaults follow the Lithuanian Labour Code minimums.',
          'Defaults follow the Lithuanian Labour Code minimums. They are '
              'defaults, not legal advice.',
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_actions',
    widget: 'InspectorActions',
    summary: "A record's keys at the foot of a page, right-aligned.",
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorActions(
        children: [
          KeyButton(label: 'Correct…', onPressed: knobs.press(() {})),
          KeyButton(label: 'History', onPressed: knobs.press(() {})),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/property_sheet_scope',
    widget: 'PropertySheetScope',
    summary:
        "Gives a Properties sheet's OK, Cancel and Apply keys their edit "
        'state.',
    build: (context, knobs) => const _PropertySheetDemo(),
  ),
];

final class _PropertySheetDemo extends StatefulWidget {
  const _PropertySheetDemo();

  @override
  State<_PropertySheetDemo> createState() => _PropertySheetDemoState();
}

final class _PropertySheetDemoState extends State<_PropertySheetDemo> {
  final _sheet = PropertySheetController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PropertySheetScope(
    controller: _sheet,
    child: ListenableBuilder(
      listenable: _sheet,
      builder: (context, _) => Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EraCheckBox(
            value: _sheet.dirty,
            onChanged: _sheet.markDirty,
            label: 'A field has changed',
          ),
          KeyButton(label: 'Apply', onPressed: _sheet.dirty ? () {} : null),
        ],
      ),
    ),
  );
}
```

Change `lib/ui/gallery/gallery_demos.dart` to:

```dart
import 'demos/control_demos.dart';
import 'demos/data_demos.dart';
import 'demos/foundation_demos.dart';
import 'demos/shell_demos.dart';
import 'gallery_demo.dart';

/// Every library widget's demo, in catalog order.
final List<GalleryDemo> galleryDemos = [
  ...foundationDemos,
  ...controlDemos,
  ...dataDemos,
  ...shellDemos,
];
```

- **Step 4: Run the guard and the build tests**

Run: `$DART format lib test && $FLUTTER test test/ui/gallery`
Expected: PASS (the coverage guard now sees 44 widgets and 44 demos; "every demo builds alone without errors" covers the new demos). If a demo throws a layout error, bound it with a `SizedBox` and re-run.

- **Step 5: Write the golden tests**

Create `test/ui/gallery/gallery_goldens_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/gallery.dart';

/// One golden per library widget (database shell spec 5.3), in the test
/// font: colour, painting and layout rather than glyphs.
void main() {
  for (final demo in galleryDemos) {
    testWidgets(demo.goldenName, (tester) async {
      await pumpGalleryDemo(tester, demo);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/${demo.goldenName}.png'),
      );
    });
  }
}
```

Create `test/ui/gallery/gallery_real_font_test.dart`:

```dart
@Tags(['real-font'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';

import '../../support/gallery.dart';

/// Every gallery demo in the bundled EraSans, for a look by eye. Skipped by
/// default; run:
/// flutter test --run-skipped -t real-font --update-goldens
///   test/ui/gallery/gallery_real_font_test.dart
void main() {
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

  for (final demo in galleryDemos) {
    testWidgets('real_font/${demo.goldenName}', (tester) async {
      await pumpGalleryDemo(tester, demo);
      await expectLater(
        find.byType(GalleryCanvas),
        matchesGoldenFile('../goldens/real_font/${demo.goldenName}.png'),
      );
    });
  }
}
```

- **Step 6: Generate the new goldens (library goldens only)**

Run: `$FLUTTER test --update-goldens test/ui/gallery/gallery_goldens_test.dart`
Then: `$FLUTTER test --run-skipped -t real-font --update-goldens test/ui/gallery/gallery_real_font_test.dart`
Expected: one synthetic and one real-font PNG per discovered library widget (currently 44 of each); production golden hashes are unchanged. Then rerun both commands **without** `--update-goldens` and require successful comparisons. The default suite skips the `real-font` tag, so a normal green run alone does not verify these images.

- **Step 7: Look at the real-font goldens**

Inspect every new synthetic and real-font golden, using a contact sheet if useful, and open detailed images for keys, pickers, menus, DataRegister and both dialog demos. In particular inspect `test/ui/goldens/real_font/controls_key_button.png`, `controls_era_date_field.png`, `data_data_register.png` and `shell_era_dialog.png`. Each must show the widget in EraSans on the page colour, matching how it looks in the app (compare with `test/goldens/real_font/agreement.png`). If a demo is clipped, give its golden a larger `size:` in its `GalleryDemo` and regenerate only that file's goldens.

- **Step 8: Verify and record checkpoint**

Run: `$FLUTTER analyze lib test tool && $FLUTTER test --reporter expanded && git status --porcelain -- ':(glob)test/goldens/**/*.png'`
Expected: `No issues found!`, `All tests passed!`, no `git status` output.

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 8: `CATALOG.md` and its guard

**Files:**
- Create: `lib/ui/CATALOG.md`, `test/ui/catalog_test.dart`

**Interfaces:**
- Consumes: `libraryWidgetClasses()` (Task 7), `galleryDemos` (Task 7), goldens (Task 7).
- Produces: `lib/ui/CATALOG.md`; entry heading format `### <Widget> · <folder>/<file>.dart · <status>`, followed by a description line, `Use for:` / `Not for:`, `API: <Widget>(…)`, `Gallery: <id> · Goldens: test/ui/goldens/<goldenName>.png`.

- **Step 1: Write the failing guard**

Create `test/ui/catalog_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';

import '../support/ui_library.dart';

/// CATALOG.md stays the truth about the library (database shell spec 5.2).
void main() {
  final heading = RegExp(
    r'^### (\w+) · (\S+\.dart) · (stable|new|deprecated \(use [^)]+\))$',
    multiLine: true,
  );

  test('CATALOG.md has one complete, current entry per library widget', () {
    final catalog = File('lib/ui/CATALOG.md').readAsStringSync();
    final classes = libraryWidgetClasses();
    final entries = heading.allMatches(catalog).toList();
    expect({for (final entry in entries) entry.group(1)!}, classes.keys.toSet());
    expect(entries, hasLength(classes.length), reason: 'duplicate entries');

    final demos = {for (final demo in galleryDemos) demo.widget: demo};
    for (final (index, entry) in entries.indexed) {
      final name = entry.group(1)!;
      expect(entry.group(2), classes[name], reason: '$name: file');
      final end = index + 1 < entries.length
          ? entries[index + 1].start
          : catalog.length;
      final body = catalog.substring(entry.end, end);
      expect(body, contains('Use for:'), reason: name);
      expect(body, contains('API: $name'), reason: name);
      final demo = demos[name]!;
      final golden = 'test/ui/goldens/${demo.goldenName}.png';
      expect(
        body,
        contains('Gallery: ${demo.id} · Goldens: $golden'),
        reason: name,
      );
      expect(File(golden).existsSync(), isTrue, reason: golden);
      final realGolden =
          'test/ui/goldens/real_font/${demo.goldenName}.png';
      expect(File(realGolden).existsSync(), isTrue, reason: realGolden);
    }
  });

  test('the catalog opens with the job table', () {
    final catalog = File('lib/ui/CATALOG.md').readAsStringSync();
    expect(catalog, contains('## Which widget for which job'));
    expect(
      catalog.indexOf('## Which widget for which job'),
      lessThan(catalog.indexOf('### ')),
    );
  });
}
```

Run: `$FLUTTER test test/ui/catalog_test.dart`
Expected: FAIL with `PathNotFoundException` for `lib/ui/CATALOG.md`.

- **Step 2: Write the catalog**

Create `lib/ui/CATALOG.md`:

````markdown
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
````

- **Step 3: Run the guard**

Run: `$FLUTTER test test/ui/catalog_test.dart`
Expected: PASS (2 tests). If a widget is missing or a file path differs, fix the entry, not the guard.

- **Step 4: Record checkpoint**

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 9: Point every session at the catalog

**Files:**
- Create: `.claude/skills/lifeos-ui/SKILL.md`, `.agents/skills/lifeos-ui/SKILL.md`, `.agents/skills/lifeos-ui/agents/openai.yaml`, `test/repository/ui_library_pointers_test.dart`
- Modify: `CLAUDE.md` (top), `AGENTS.md` (after the opening paragraph), `DESIGN.md:140`

**Interfaces:**
- Consumes: `lib/ui/CATALOG.md` (Task 8).
- Produces: the `lifeos-ui` skill; one pointer line each in `CLAUDE.md`, `AGENTS.md` and `DESIGN.md`; a `bd remember` entry.

- **Step 1: Write the failing test**

Create `test/repository/ui_library_pointers_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Future sessions find the UI library (database shell spec 5.5).
void main() {
  test('instructions, the design record and the skill point at the catalog',
      () {
    for (final path in [
      'CLAUDE.md',
      'AGENTS.md',
      'DESIGN.md',
      '.claude/skills/lifeos-ui/SKILL.md',
      '.agents/skills/lifeos-ui/SKILL.md',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('lib/ui/CATALOG.md'),
        reason: path,
      );
    }
  });

  test('the Codex skill mirrors the Claude skill', () {
    final skill = File('.claude/skills/lifeos-ui/SKILL.md').readAsStringSync();
    expect(skill, startsWith('---\nname: lifeos-ui\ndescription: '));
    expect(File('.agents/skills/lifeos-ui/SKILL.md').readAsStringSync(), skill);
    expect(
      File('.agents/skills/lifeos-ui/agents/openai.yaml').existsSync(),
      isTrue,
    );
  });
}
```

Run: `$FLUTTER test test/repository/ui_library_pointers_test.dart`
Expected: FAIL (`CLAUDE.md` lacks `lib/ui/CATALOG.md`; the skill files do not exist).

- **Step 2: Write the skill**

Create `.claude/skills/lifeos-ui/SKILL.md`:

```markdown
---
name: lifeos-ui
description: Use for any UI work in the LifeOS repository - building, changing, reviewing or styling a screen, widget, control, form, list, layout or visual detail under lib/. Read lib/ui/CATALOG.md first and reuse the UI library; add a missing widget to lib/ui with a gallery demo, goldens and a catalog entry before using it.
---

# LifeOS UI library

LifeOS has one UI library, `lib/ui/`. Its inventory is `lib/ui/CATALOG.md`.
The visual rules are in `DESIGN.md`. The layout and interaction spec is
`docs/superpowers/specs/2026-10-08-database-shell-and-ui-library-design.md`.

## Before writing any UI

1. Read `lib/ui/CATALOG.md`, starting with "Which widget for which job".
2. Reuse a `stable` or `new` widget. Deprecated widgets remain valid in
   existing screens and in the phase 1 gallery, demos and compatibility
   tests until their replacements exist. Do not implement a phase 2 widget
   early just to avoid this temporary host dependency.
3. Import only `lib/ui/ui.dart` (relative from `lib/`,
   `package:lifeos/ui/ui.dart` from tests). Importing any other `lib/ui/`
   file from feature, app or shell code fails `test/ui/library_boundary_test.dart`.
4. See a widget before using it: `./app.sh` › 5) Open widget gallery.

## When nothing fits

Build the widget in the library, not inside the feature:

1. Put it in its folder: `foundation/` (tokens, type, theme, icons, dates),
   `controls/` (keys, fields, pickers, menus), `data/` (lists, grids,
   trees, states) or `shell/` (frames, panes, windows). Export its file from
   `lib/ui/ui.dart`.
2. Follow `DESIGN.md`: colours only from `LifeOSTokens` / `MillenniumColors`,
   EraSans 11 px, painted glyphs, era bevels, no shadows or motion.
3. Add one demo entry for it to the matching file in `lib/ui/gallery/demos/`,
   on synthetic data, honouring the knobs (`knobs.press`, `knobs.errorText`,
   `knobs.text`).
4. Generate and look at its goldens:
   `flutter test --update-goldens test/ui/gallery/gallery_goldens_test.dart`
   and `flutter test --run-skipped -t real-font --update-goldens test/ui/gallery/gallery_real_font_test.dart`.
   Phase 1 keeps all existing production golden bytes unchanged. From
   phase 2 onward, update only goldens affected by an intended behavior
   change, alongside that change and after visual review (spec section 7).
   Never bulk-accept failing goldens. Run both gallery golden suites again
   without `--update-goldens`, including the explicitly selected real-font tag.
5. Add its `lib/ui/CATALOG.md` entry in the standard format:
   `### Name · folder/file.dart · status`, a description line,
   `Use for: … Not for: …`, `API: Name(…)`,
   `Gallery: <id> · Goldens: test/ui/goldens/<id with _>.png`. Add a row to
   "Which widget for which job" if it serves a new job.
6. `flutter test test/ui` must pass; its guards fail on a widget without a
   demo, a golden or a catalog entry.

## Database shell rules (spec 4.6, 4.7)

New shell widgets use the keyboard only inside an open editor (typing,
Enter/Tab to the next field, Esc to drop the typed value); everything else
is done with the mouse. Date/time part stepping is editor-local data entry;
Enter/Tab at the last editable field closes that editor without moving to
another record. They open no window except a confirmation window. During
phases 1–3, preserve legacy callers and their existing interaction tests;
apply the new contract only in new editor hosts until phase 4 cutover.
```

Create `.agents/skills/lifeos-ui/SKILL.md` with exactly the same content (copy the file: `mkdir -p .agents/skills/lifeos-ui/agents && cp -f .claude/skills/lifeos-ui/SKILL.md .agents/skills/lifeos-ui/SKILL.md`).

Create `.agents/skills/lifeos-ui/agents/openai.yaml`:

```yaml
interface:
  display_name: "LifeOS UI"
  short_description: "Reuse and extend the lib/ui widget library"
  default_prompt: "Use $lifeos-ui to find the right LifeOS widget in lib/ui/CATALOG.md before writing UI."
```

- **Step 3: Add the pointer lines**

In `CLAUDE.md`, after the first line (`After successfully completing an implementation plan, …`) and its blank line, insert:

```markdown
Before any UI work, read `lib/ui/CATALOG.md` (the UI library inventory) and follow the `lifeos-ui` skill (`.claude/skills/lifeos-ui/SKILL.md`). Feature, app and shell code import only `lib/ui/ui.dart`.
```

In `AGENTS.md`, after the paragraph that ends `reach for third-party Dolt hosting before trying the default).` and its blank line, insert:

```markdown
Before any UI work, read `lib/ui/CATALOG.md` (the UI library inventory) and follow the `lifeos-ui` skill (`.agents/skills/lifeos-ui/SKILL.md`). Feature, app and shell code import only `lib/ui/ui.dart`.
```

In `DESIGN.md`, after line 140 (`This record is derived from the built Flutter shell …`) insert a new paragraph:

```markdown
The component inventory is `lib/ui/CATALOG.md`: one entry per widget, with its gallery demo and goldens. This file is the visual system; the catalog is the parts list.
```

- **Step 4: Run the test**

Run: `$FLUTTER test test/repository`
Expected: PASS (pointers 2, launcher 1, boundary tests 3).

- **Step 5: Remember it in Beads**

Run:

```bash
bd remember --key lifeos-ui-library "UI library: lib/ui, one import lib/ui/ui.dart. Inventory lib/ui/CATALOG.md; gallery ./app.sh option 5; skill .claude/skills/lifeos-ui (Codex: .agents/skills/lifeos-ui). Read the catalog before any UI work; add new widgets to lib/ui with a gallery demo, goldens and a catalog entry."
```

Expected: `Remembered [lifeos-ui-library]: …`

- **Step 6: Record checkpoint**

Inspect `git diff --stat` and `git status --short`, then record this task's changes and validation in `bd update lifeManager-9pk.1 --notes="..."`. Keep earlier checkpoint information when updating notes. Leave changes uncommitted unless explicitly authorized.

---

### Task 10: Phase gate — `./app.sh`, the gallery and the bead

**Files:** none changed unless a check fails.

**Interfaces:** Consumes everything above.

- **Step 1: Tests through the launcher**

Run: `printf '2\n6\n' | ./app.sh`
Expected: `All tests passed!` (about 1033 earlier tests plus the new UI tests) and the menu exits on 6.

- **Step 2: Checks through the launcher**

Run: `printf '3\n6\n' | ./app.sh`
Expected: `No issues found!`, format reports nothing to change, and the schema check passes.

- **Step 3: The app starts**

Open `./app.sh` in an interactive terminal and select 1. Confirm the release
build succeeds and the window looks as before; use synthetic fixture screenshots
for any captured comparison. Close the window normally and choose 6 to exit.
Keep the complete output and check the process result. Do not pipe startup
through `grep`/`head` or treat an arbitrary timeout as successful completion.

- **Step 4: The gallery starts and leaves the database alone**

Run the startup-selector regression with the exact launcher define:

```bash
$FLUTTER test --dart-define=LIFEOS_GALLERY=1 test/ui/gallery/gallery_main_test.dart
```

It must prove the production callback is never invoked. The library import
boundary must also pass. Then open `./app.sh`, select 5, and confirm the title
"LifeOS widget gallery", list, demo and knobs. Visit field, menu, list and
dialog demos; toggle Enabled, Long text and 200 % text, and inspect at 800 × 600.
Close normally and select 6. The gallery must work independently of an open
production app. Do not corrupt or rename the owner's database to exercise
isolation. File timestamps/sizes alone do not prove that a database was never
opened or locked; the executed selector and isolated dependency boundary are
the automated regression evidence.

- **Step 5: Goldens and tree clean**

Run: `git status --porcelain -- ':(glob)test/goldens/**/*.png' && git status --short`
Expected: no production PNG changes; Dart import rewrites under `test/goldens/` are expected. Confirm baseline PNG hashes match and inspect the remaining intended changes.

- **Step 6: Close the bead and hand off**

Run: `bd close lifeManager-9pk.1 --reason="lib/ui library, ui.dart barrel, CATALOG.md, gallery, guards and lifeos-ui skill in place; production goldens unchanged"`

Report to the owner: the changed files, the test and check results, the gallery check, and that phase 2 (`lifeManager-9pk.2`) is now ready.
