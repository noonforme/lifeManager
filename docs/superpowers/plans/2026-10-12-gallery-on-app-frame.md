# Gallery on AppFrame (Phase 2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the widget gallery on the library's own shell (AppFrame, TreeView, PropertyGrid), remove the phase 1 gallery layout, and finish the deferred phase 1 review minors, so phase 2 can close.

**Architecture:** `GalleryHome` becomes an `AppFrame` owner. The tree lists demos by folder, the middle slot holds the unchanged `GalleryCanvas`, a Summary subform tab shows the demo's summary, and a `PropertyGrid` edits the knobs through one `EditorSessionController`. A knob's open draft is previewed live in the demo; Enter keeps it and Esc drops it. Knob-to-property mapping lives in a small pure file with its own unit tests. `GalleryHost`, `GalleryCanvas` and every demo stay as they are, so all existing demo goldens keep their bytes.

**Tech Stack:** Flutter 3.47.5 / Dart 3, `flutter_test` goldens, Beads (`bd`).

**Spec:** `docs/superpowers/specs/2026-10-08-database-shell-and-ui-library-design.md` (sections 4.6, 5.2–5.4, 7). Predecessor plan: `docs/superpowers/plans/2026-10-10-ui-library-widgets.md` (section "2a completion and 2b handoff").

**Beads:** `lifeManager-9pk.2.1` (this plan), `lifeManager-9pk.8` (deferred minors, Tasks 1–2), parent `lifeManager-9pk.2`. Claim `9pk.2.1` and `9pk.8` before Task 1.

**Review incorporated:** `lifeManager-9pk.2.8` (2026-10-12). The examples below include the missing gallery test import, fresh mounts for matrix cases, scrolling of lazy tree rows, a small-scrollbar fix before the gallery gate, and flush/close when selecting the current demo. Task 3a is required: the original live 200 % sequence reproduced a 2.6 px scrollbar overflow.

**Example validation (2026-10-12):** The revised Dart examples, with Task 3a's arrow sizing applied in a temporary fixture, pass 41 focused tests and targeted analysis. The shell matrix builds all 61 demos in 18 size/scale combinations with long labels and errors. This validates the recipes; the repository implementation and its phase gates remain to be performed.

## Global Constraints

- Feature, app and shell code import only `lib/ui/ui.dart`; gallery files import `../ui.dart` and gallery siblings.
- Colours only from `LifeOSTokens` / `MillenniumColors`; EraSans 11 px; painted glyphs; no shadows or motion (`DESIGN.md`).
- Keyboard only inside an open editor (typing, Enter/Tab to the next field, Esc drops the typed value); everything else by mouse (spec 4.6). No dialogs.
- The gallery boots with synthetic fixtures and never opens the production database (spec 5.3).
- Never bulk-update goldens. Generate only a named new golden with `--plain-name`, look at it, then rerun without `--update-goldens`. Every existing PNG under `test/goldens` and `test/ui/goldens` keeps its bytes in this plan.
- Do not pipe test or check commands into `tail`/`head`/`grep` and infer success from the last tool's status.
- Use `FLUTTER="$HOME/.local/opt/flutter-3.47.5/bin/flutter"` and `DART="$HOME/.local/opt/flutter-3.47.5/bin/dart"`.
- Commit only when the user or orchestrator has authorised commits for this session; otherwise leave the work staged-ready and report.

## Knob mapping (spec 5.3)

The spec's knob list maps to the existing `GalleryKnobs` with no new knob:

| Spec knob | Property row | `GalleryKnobs` field |
|---|---|---|
| enabled / read-only | State › Enabled (check). Off greys and locks the demo through `EraFormScope(enabled: false)`, which is the read-only look. | `enabled` |
| error | State › Show an error (check) | `error` |
| sample data | Sample data › Long text (check) | `longText` |
| sizes | Sizes › Text size (choice: 100 %, 200 %) | `textScale` |

## Review Focus

1. **A knob draft open when the owner picks another demo.** The draft is committed first (flush), then the demo changes. It is never lost or applied to the wrong demo. Test in Task 4.
2. **800 × 600 at 200 % text.** The tree folds into the Tree key and the knobs dock as a Knobs tab. Every knob and every demo stays reachable by mouse, with the page scrolling. Tests in Task 4.
3. **Esc on a previewed knob.** The demo returns exactly to the committed knobs. Test in Task 4.
4. **Clicking a folder node in the tree.** The open demo stays; nothing blanks. Test in Task 4.
5. **Narrowing the window while a knob editor is open.** The frame asks for the docked Knobs tab, the gallery follows, and the draft survives. Test in Task 4.
6. **Picking the current demo in the folded tree.** The knob draft is flushed and the overlay closes; the demo's own state is kept. Test in Task 4.
7. **Switching live to 200 % text.** A scrollbar rail shorter than its two usual arrow buttons still fits and works by mouse. Regression in Task 3a; the gallery sequence remains in Task 4.

## File map

| File | Change | Responsibility |
|---|---|---|
| `test/support/catalog.dart` | create | Pure catalog checks: entry bodies, job-table names, Foundation names, top-level declarations |
| `test/ui/catalog_test.dart` | modify | Use the checks, with negative cases |
| `test/ui/library_boundary_test.dart` | modify | Cover `lib/core` and `lib/bootstrap.dart`; forbid gallery code in `ui.dart` |
| `dart_test.yaml` | modify | Real-font skip message names every real-font file |
| `lib/ui/CATALOG.md` | modify | Foundation list format and Orb / OperationalState API lines (Task 1); intro, AppFrame entry, Next (Task 5) |
| `lib/ui/controls/era_scrollbar.dart` | modify | Constrain arrow lengths to a short rail, keeping normal bars unchanged (Task 3a) |
| `test/ui/controls/era_scrollbar_test.dart` | modify | Short vertical/horizontal rails, normal arrow size and mouse scrolling (Task 3a) |
| `test/support/gallery.dart` | modify | `openComboDemoList`, `pumpGalleryApp`, knob and tree helpers |
| `test/ui/gallery/gallery_goldens_test.dart` | modify | Combo-open golden (Task 2); gallery shell goldens (Task 5) |
| `test/ui/gallery/gallery_real_font_test.dart` | modify | Real-font twins of the same |
| `lib/ui/gallery/gallery_knob_properties.dart` | create | Knobs ⇄ `PropertyItem`s, commit and live preview |
| `test/ui/gallery/gallery_knob_properties_test.dart` | create | Unit tests of the mapping |
| `lib/ui/gallery/gallery_app.dart` | rewrite | `GalleryHome` as an `AppFrame` owner |
| `test/ui/gallery/gallery_app_test.dart` | rewrite | Tree, knobs, preview, flush, docking, isolation |
| `.claude/skills/lifeos-ui/SKILL.md`, `.agents/skills/lifeos-ui/SKILL.md` | modify | Drop the "phase 1 gallery" wording |

`lib/ui/gallery/gallery_host.dart`, `gallery_demo.dart`, `gallery_demos.dart`, `gallery_main.dart` and every demo file stay unchanged.

---

### Task 0: Baseline

- [ ] **Step 1: Claim the beads and record the golden baseline**

```bash
cd /home/aUser/lifeManager
set -euo pipefail
bd update lifeManager-9pk.2.1 --claim
bd update lifeManager-9pk.8 --claim
export FLUTTER="$HOME/.local/opt/flutter-3.47.5/bin/flutter"
export DART="$HOME/.local/opt/flutter-3.47.5/bin/dart"
UI_BASELINE_DIR=$(mktemp -d /tmp/lifeos-gallery-2b-baseline.XXXXXX)
export UI_BASELINE_DIR
echo "$UI_BASELINE_DIR"   # note it; later tasks need it
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

Expected: `Recorded 271 existing PNGs` (or the current count; note it).

---

### Task 1: Catalog, boundary and skip-message guards (`9pk.8` items 1–4)

**Files:**
- Create: `test/support/catalog.dart`
- Modify: `test/ui/catalog_test.dart`, `test/ui/library_boundary_test.dart`, `dart_test.yaml`, `lib/ui/CATALOG.md` (Foundation list format; Orb and OperationalState `API:` lines)

**Interfaces:**
- Produces (test support): `String catalogEntryBody(String catalog, int start)`, `List<String> undeclaredJobTableNames(String catalog, Map<String, String> sources)`, `List<String> undeclaredFoundationNames(String catalog, Map<String, String> sources)`, `bool declaresTopLevel(String source, String name)`, `Map<String, String> librarySources()` (keys relative to `lib/ui/`, gallery excluded).

Item 6 of `9pk.8` (data and shell demos missing from the knob-combination test) is already resolved: `test/ui/gallery/demos_test.dart` › "every demo builds alone, plain and with every knob" loops every `galleryDemos` entry through four knob sets. Record that in Step 9; no code.

- [ ] **Step 1: Write the catalog support file**

`test/support/catalog.dart`:

```dart
import 'dart:io';

/// Checks of `lib/ui/CATALOG.md` against the library source, kept pure so
/// their negative cases can be tested on small texts.

final _code = RegExp('`([^`]+)`');
final _typeName = RegExp(r'\b[A-Z]\w*');
final _anyHeading = RegExp(r'^##', multiLine: true);

/// The source of every library file outside the gallery, keyed by its path
/// relative to `lib/ui/`: `'controls/keys.dart'`.
Map<String, String> librarySources() => {
  for (final file in Directory('lib/ui').listSync(recursive: true))
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.startsWith('lib/ui/gallery/'))
      file.path.substring('lib/ui/'.length): file.readAsStringSync(),
};

/// Whether [source] declares [name] at the top level: a class, enum,
/// typedef, mixin or extension, or a column-0 function, getter, variable
/// or constant. A mere mention (a parameter or return type) does not count.
bool declaresTopLevel(String source, String name) {
  final n = RegExp.escape(name);
  const declaration =
      r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
      r'(?:class|enum|typedef|mixin|extension(?:\s+type)?)\s+';
  const value = r'^(?!import|export|part|library|return|//|\s)[^\n=(]*\b';
  const valueEnd = r'\s*(?:[(<=;]|=>)';
  const getter = r'^(?!import|export|//|\s)[^\n=(]*\bget\s+';
  return RegExp(
        '$declaration$n\\b',
        multiLine: true,
      ).hasMatch(source) ||
      RegExp(
        '$value$n$valueEnd',
        multiLine: true,
      ).hasMatch(source) ||
      RegExp(
        '$getter$n\\b',
        multiLine: true,
      ).hasMatch(source);
}

/// The body of the entry whose heading ends at [start]: up to the next
/// `##` or `###` heading, so a section's last entry does not run into the
/// next section.
String catalogEntryBody(String catalog, int start) {
  final rest = catalog.substring(start);
  final next = _anyHeading.firstMatch(rest);
  return next == null ? rest : rest.substring(0, next.start);
}

/// Capitalised names in backticks in the Use column of the job table that
/// no library source declares.
List<String> undeclaredJobTableNames(
  String catalog,
  Map<String, String> sources,
) {
  final start = catalog.indexOf('## Which widget for which job');
  if (start < 0) return ['no job table'];
  final end = catalog.indexOf('\n## ', start + 1);
  final table = catalog.substring(start, end < 0 ? catalog.length : end);
  return [
    for (final row in table.split('\n'))
      if (row.startsWith('| ') && !row.startsWith('| Job '))
        for (final code in _code.allMatches(row.split('|')[2]))
          for (final name in _typeName.allMatches(code.group(1)!))
            if (!sources.values.any(
              (source) => declaresTopLevel(source, name.group(0)!),
            ))
              name.group(0)!,
  ];
}

/// Names in the Foundation list that the file named on their line does not
/// declare, as `name (file)`, plus every list line not in the
/// "- `A`, `B` (`foundation/x.dart`): …" format.
List<String> undeclaredFoundationNames(
  String catalog,
  Map<String, String> sources,
) {
  final start = catalog.indexOf('## Foundation');
  if (start < 0) return ['no Foundation section'];
  final end = catalog.indexOf('\n### ', start);
  final section = catalog.substring(start, end < 0 ? catalog.length : end);
  final line = RegExp(r'^- (.*) \(`(foundation/[\w/]+\.dart)`\):');
  final problems = <String>[];
  for (final text in section.split('\n')) {
    if (!text.startsWith('- ')) continue;
    final match = line.firstMatch(text);
    if (match == null) {
      problems.add('unparsed: $text');
      continue;
    }
    final source = sources[match.group(2)!] ?? '';
    for (final code in _code.allMatches(match.group(1)!)) {
      final name = RegExp(r'\w+').firstMatch(code.group(1)!)!.group(0)!;
      if (!declaresTopLevel(source, name)) {
        problems.add('$name (${match.group(2)})');
      }
    }
  }
  return problems;
}
```

- [ ] **Step 2: Rewrite the catalog test to use it, with negative cases**

`test/ui/catalog_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';

import '../support/catalog.dart';
import '../support/ui_library.dart';

/// CATALOG.md stays the truth about the library (database shell spec 5.2).
void main() {
  final heading = RegExp(
    r'^### (\w+) · (\S+\.dart) · (stable|new|deprecated \(use [^)]+\))$',
    multiLine: true,
  );
  final catalog = File('lib/ui/CATALOG.md').readAsStringSync();

  test('CATALOG.md has one complete, current entry per library widget', () {
    final classes = libraryWidgetClasses();
    final entries = heading.allMatches(catalog).toList();
    expect({
      for (final entry in entries) entry.group(1)!,
    }, classes.keys.toSet());
    expect(entries, hasLength(classes.length), reason: 'duplicate entries');

    final demos = {for (final demo in galleryDemos) demo.widget: demo};
    for (final entry in entries) {
      final name = entry.group(1)!;
      expect(entry.group(2), classes[name], reason: '$name: file');
      final body = catalogEntryBody(catalog, entry.end);
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
      final realGolden = 'test/ui/goldens/real_font/${demo.goldenName}.png';
      expect(File(realGolden).existsSync(), isTrue, reason: realGolden);
    }
  });

  test('an entry body ends at the next section heading', () {
    const text =
        '### A · a.dart · new\nUse for: a\n\n## Shell\n\nAPI: A()\n'
        '### B · b.dart · new\nAPI: B()\n';
    final body = catalogEntryBody(text, text.indexOf('\n'));
    expect(body, contains('Use for: a'));
    expect(body, isNot(contains('API: A()')));
  });

  test('the catalog opens with the job table', () {
    expect(catalog, contains('## Which widget for which job'));
    expect(
      catalog.indexOf('## Which widget for which job'),
      lessThan(catalog.indexOf('### ')),
    );
  });

  test("every name in the job table's Use column is declared in lib/ui", () {
    expect(undeclaredJobTableNames(catalog, librarySources()), isEmpty);
  });

  test('the job table check reports a misspelt name', () {
    const table =
        '## Which widget for which job\n\n| Job | Use | Not |\n'
        '|---|---|---|\n'
        '| A list | `DataGird` (legacy: `DataGrid`) | `ListView` |\n\n'
        '## Foundation\n';
    expect(
      undeclaredJobTableNames(table, {
        'data/data_grid.dart': 'final class DataGrid<T> extends StatefulWidget {}',
      }),
      ['DataGird'],
    );
  });

  test('every Foundation name is declared in the file it names', () {
    expect(undeclaredFoundationNames(catalog, librarySources()), isEmpty);
  });

  test('the Foundation check reports a wrong file and an unparsed line', () {
    const section =
        '## Foundation\n\n'
        '- `EraIconKind`, `areaIcon(area)` (`foundation/era_icons.dart`): x.\n'
        '- `LifeOSArea` (`foundation/era_icons.dart`): y.\n'
        '- `Loose` without a file.\n'
        '\n### LifeOSSkinScope · foundation/lifeos_skin.dart · stable\n';
    expect(
      undeclaredFoundationNames(section, {
        'foundation/era_icons.dart':
            'enum EraIconKind { app }\n'
            'EraIconKind areaIcon(LifeOSArea area) => EraIconKind.app;\n',
      }),
      [
        'LifeOSArea (foundation/era_icons.dart)',
        'unparsed: - `Loose` without a file.',
      ],
    );
  });
}
```

- [ ] **Step 2a: Normalize the two Foundation list lines**

The current `EraIconKind` and date-helper lines end with `).`, whereas the new guard requires the same `): description` format as the other Foundation entries. Replace those two lines in `lib/ui/CATALOG.md` with:

```text
- `EraIconKind`, `areaIcon(area)` (`foundation/era_icons.dart`): painted icon kinds and the area-to-icon mapping.
- `eraBoxDate`, `eraWeekdayShort`, `spokenDate`, `eraMonthTitle`, `monthGridDays`, `eraMonthNames`, `eraWeekdayInitials` (`foundation/era_dates.dart`): fixed-format date labels and calendar helpers.
```

- [ ] **Step 3: Run the catalog tests**

Run: `"$FLUTTER" test test/ui/catalog_test.dart`
Expected: all 7 tests PASS after Step 2a. The negative tests prove the checks can fail. If another real-catalog check fails, fix the catalog text it names, not the checker.

- [ ] **Step 4: Extend the boundary test (failing first)**

In `test/ui/library_boundary_test.dart`, replace the first test and add one after it:

```dart
  test('features, app, core, bootstrap and the old shell reach the library '
      'only through ui.dart', () {
    final files = [
      ...dartFiles('lib/features'),
      ...dartFiles('lib/app'),
      ...dartFiles('lib/shared'),
      ...dartFiles('lib/core'),
      File('lib/bootstrap.dart'),
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

  test('ui.dart neither imports nor exports gallery code', () {
    final barrel = File('lib/ui/ui.dart');
    final targets = [
      for (final match in directive.allMatches(barrel.readAsStringSync()))
        if (target(barrel, match.group(1)!) case final to?) to,
    ];
    expect(targets, isNotEmpty);
    expect(targets.where((to) => to.startsWith('lib/ui/gallery/')), isEmpty);
  });
```

Before keeping it, check that the new test can fail: temporarily add `export 'gallery/gallery_demo.dart';` to `lib/ui/ui.dart` and run `"$FLUTTER" test test/ui/library_boundary_test.dart`. Expect FAIL on "ui.dart neither imports nor exports gallery code". Remove the line again.

- [ ] **Step 5: Run the boundary tests**

Run: `"$FLUTTER" test test/ui/library_boundary_test.dart`
Expected: all PASS (nothing in `lib/core` or `lib/bootstrap.dart` imports `lib/ui/` today).

- [ ] **Step 6: Correct the real-font skip message**

`dart_test.yaml`:

```yaml
tags:
  real-font:
    skip: "Real-font (EraSans) goldens are skipped by default. Run one file with: flutter test --run-skipped -t real-font <file>, where <file> is test/goldens/real_font_check_test.dart, test/ui/gallery/gallery_real_font_test.dart or a test/ui/**/*_real_font_test.dart. Add --update-goldens only for a named, reviewed golden (--plain-name)."
```

Then make sure nothing asserts the old text: `grep -rn "real_font_check_test.dart" test tool app.sh`. The only expected hit is the doc comment in `test/goldens/real_font_check_test.dart`.

- [ ] **Step 7: Correct the two API lines in CATALOG.md**

Required parameters must not read as defaults. Replace:

```
API: Orb(glyph: OrbGlyph.back, tone: OrbTone.green, size: 20)
```
with
```
API: Orb(glyph:, tone:, size: 20) with OrbGlyph.back | .forward | .add and OrbTone.green | .orange | .grey
```

and replace:

```
API: OperationalState(kind: OperationalStateKind.empty, title:, message:, action:)
```
with
```
API: OperationalState(kind:, title:, message:, action:) with OperationalStateKind.loading | .empty | .unavailable | .invalidScope | .conflict | .uncertain
```

A sweep of all `API:` lines found no other required parameter shown with a literal or enum value. That sweep compared each constructor's `required` parameters with `name: <Enum.value | number | bool | 'text'>` in its API line.

- [ ] **Step 8: Run the UI guard suite and format**

```bash
"$DART" format test/support/catalog.dart test/ui/catalog_test.dart test/ui/library_boundary_test.dart
"$FLUTTER" test test/ui/catalog_test.dart test/ui/library_boundary_test.dart test/ui/gallery/demos_test.dart
"$FLUTTER" analyze test/support/catalog.dart test/ui/catalog_test.dart test/ui/library_boundary_test.dart
```

Expected: all PASS, `No issues found!`.

- [ ] **Step 9: Record and commit**

```bash
bd update lifeManager-9pk.8 --notes "Items 1-4 done in plan 2026-10-12-gallery-on-app-frame Task 1 (catalog body/job-table/Foundation checks with negative tests; boundary covers lib/core, lib/bootstrap.dart, no gallery in ui.dart; skip message; Orb/OperationalState API lines). Item 6 already resolved by 2a: demos_test loops every demo through four knob sets. Item 5 in Task 2."
git add test/support/catalog.dart test/ui/catalog_test.dart test/ui/library_boundary_test.dart dart_test.yaml lib/ui/CATALOG.md
git commit -m "test: catalog name, section and boundary guards (phase 1 minors)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: EraCombo open-list golden (`9pk.8` item 5)

**Files:**
- Modify: `test/support/gallery.dart`, `test/ui/gallery/gallery_goldens_test.dart`, `test/ui/gallery/gallery_real_font_test.dart`
- Create: `test/ui/goldens/controls_era_combo_open.png`, `test/ui/goldens/real_font/controls_era_combo_open.png`

**Interfaces:**
- Produces: `Future<void> openComboDemoList(WidgetTester tester)` in `test/support/gallery.dart`.

The combo demo reserves 280 px so its list fits, but its default golden shows it closed. A dedicated golden shows the list open. The capture is the whole window (`GalleryHost`) because the list paints in the overlay, the same way the editor host's popup variants are captured.

- [ ] **Step 1: Add the helper**

Append to `test/support/gallery.dart`, adding `import 'package:flutter/gestures.dart';` and `import 'package:lifeos/ui/ui.dart';`:

```dart
/// Opens the combo demo's list with a mouse click on its face.
Future<void> openComboDemoList(WidgetTester tester) async {
  await tester.tap(find.byType(EraComboFace), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Add the synthetic golden test**

Append inside `main()` of `test/ui/gallery/gallery_goldens_test.dart`:

```dart
  testWidgets('controls_era_combo_open', (tester) async {
    await pumpGalleryDemo(
      tester,
      galleryDemos.singleWhere((demo) => demo.id == 'controls/era_combo'),
    );
    await openComboDemoList(tester);
    expect(find.text('All records'), findsOneWidget, reason: 'list open');
    await expectLater(
      find.byType(GalleryHost),
      matchesGoldenFile('../goldens/controls_era_combo_open.png'),
    );
  });
```

- [ ] **Step 3: Add the real-font twin**

Append inside `main()` of `test/ui/gallery/gallery_real_font_test.dart`, after the loop:

```dart
  testWidgets('real_font/controls_era_combo_open', (tester) async {
    await pumpGalleryDemo(
      tester,
      galleryDemos.singleWhere((demo) => demo.id == 'controls/era_combo'),
    );
    await openComboDemoList(tester);
    expect(find.text('All records'), findsOneWidget, reason: 'list open');
    await expectLater(
      find.byType(GalleryHost),
      matchesGoldenFile('../goldens/real_font/controls_era_combo_open.png'),
    );
  });
```

- [ ] **Step 4: Run it without goldens to see it fail**

Run: `"$FLUTTER" test --plain-name controls_era_combo_open test/ui/gallery/gallery_goldens_test.dart`
Expected: FAIL, golden file `controls_era_combo_open.png` not found. Earlier failures (no list) mean the helper is wrong; fix the finder first.

- [ ] **Step 5: Generate only these two goldens and look at them**

```bash
"$FLUTTER" test --update-goldens --plain-name controls_era_combo_open test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font --update-goldens --plain-name real_font/controls_era_combo_open test/ui/gallery/gallery_real_font_test.dart
git status --short test/ui/goldens
```

Expected: exactly two new files, no modified PNG. Open both images. The list must hang below the face, be at least as wide as it, have Effective lit, and be fully inside the 480 × 280 canvas.

- [ ] **Step 6: Rerun without updating**

```bash
"$FLUTTER" test --plain-name controls_era_combo test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font --plain-name real_font/controls_era_combo test/ui/gallery/gallery_real_font_test.dart
```

Expected: PASS (this also reruns `controls_era_combo` and `controls_era_combo_face`, unchanged).

- [ ] **Step 7: Close the minors bead and commit**

```bash
bd close lifeManager-9pk.8 --reason "Items 1-4 Task 1, item 5 open-list goldens Task 2, item 6 already covered by demos_test (plan 2026-10-12-gallery-on-app-frame)."
git add test/support/gallery.dart test/ui/gallery/gallery_goldens_test.dart test/ui/gallery/gallery_real_font_test.dart test/ui/goldens/controls_era_combo_open.png test/ui/goldens/real_font/controls_era_combo_open.png
git commit -m "test: golden of the era combo with its list open

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Knobs as property rows

**Files:**
- Create: `lib/ui/gallery/gallery_knob_properties.dart`, `test/ui/gallery/gallery_knob_properties_test.dart`

**Interfaces:**
- Consumes: `GalleryKnobs` (`gallery_demo.dart`); `PropertyItem`, `ValueKind`, `EraComboItem`, `EditSession`, `EditIdentity`, `EditorSessionController`, `EditField` (`ui.dart`).
- Produces:
  - `const String galleryKnobRecord` (`'gallery:knobs'`)
  - `const List<EraComboItem<Object?>> galleryTextSizes`
  - `List<PropertyItem> galleryKnobItems(GalleryKnobs knobs)` (keys `enabled`, `error`, `longText`, `textScale`, in that order)
  - `GalleryKnobs applyGalleryKnob(GalleryKnobs knobs, String key, Object? value)`
  - `GalleryKnobs previewGalleryKnobs(GalleryKnobs knobs, EditSession? session)`

- [ ] **Step 1: Write the failing tests**

`test/ui/gallery/gallery_knob_properties_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_knob_properties.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  test('every knob is a property row, in traversal order', () {
    const knobs = GalleryKnobs(enabled: false, longText: true, textScale: 2);
    final items = galleryKnobItems(knobs);
    expect(items.map((item) => item.key), [
      'enabled',
      'error',
      'longText',
      'textScale',
    ]);
    expect(items.map((item) => item.category), [
      'State',
      'State',
      'Sample data',
      'Sizes',
    ]);
    expect(items.map((item) => item.value), [false, false, true, 2.0]);
    expect(items.last.kind, ValueKind.choice);
    expect(items.last.choices.map((choice) => choice.label), [
      '100 %',
      '200 %',
    ]);
    expect(items.every((item) => item.editable), isTrue);
    expect(items.every((item) => item.description != null), isTrue);
  });

  test('a committed value changes only its own knob', () {
    const knobs = GalleryKnobs();
    expect(applyGalleryKnob(knobs, 'enabled', false).enabled, isFalse);
    expect(applyGalleryKnob(knobs, 'error', true).error, isTrue);
    expect(applyGalleryKnob(knobs, 'longText', true).longText, isTrue);
    final scaled = applyGalleryKnob(knobs, 'textScale', 2.0);
    expect(scaled.textScale, 2);
    expect((scaled.enabled, scaled.error, scaled.longText), (
      true,
      false,
      false,
    ));
  });

  test('an unknown knob or a wrong value type is a programming error', () {
    expect(
      () => applyGalleryKnob(const GalleryKnobs(), 'colour', true),
      throwsArgumentError,
    );
    expect(
      () => applyGalleryKnob(const GalleryKnobs(), 'enabled', 'yes'),
      throwsArgumentError,
    );
  });

  test("the open knob's draft is previewed; other records are not", () {
    final controller = EditorSessionController();
    addTearDown(controller.dispose);
    const knobs = GalleryKnobs();
    expect(previewGalleryKnobs(knobs, controller.session), same(knobs));

    const id = EditIdentity(record: galleryKnobRecord, field: 'error');
    controller.begin(
      EditField(
        id: id,
        kind: ValueKind.check,
        value: false,
        commit: (_, _) => const EditResult.accepted(),
      ),
    );
    controller.update(id, true);
    expect(previewGalleryKnobs(knobs, controller.session).error, isTrue);
    controller.cancel();
    expect(previewGalleryKnobs(knobs, controller.session).error, isFalse);

    const other = EditIdentity(record: 'shift:7', field: 'error');
    controller.begin(
      EditField(
        id: other,
        kind: ValueKind.check,
        value: false,
        commit: (_, _) => const EditResult.accepted(),
      ),
    );
    controller.update(other, true);
    expect(previewGalleryKnobs(knobs, controller.session), same(knobs));
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `"$FLUTTER" test test/ui/gallery/gallery_knob_properties_test.dart`
Expected: FAIL to compile, `gallery_knob_properties.dart` not found.

- [ ] **Step 3: Implement**

`lib/ui/gallery/gallery_knob_properties.dart`:

```dart
import '../ui.dart';
import 'gallery_demo.dart';

/// The record the gallery's property grid edits: the knobs.
const galleryKnobRecord = 'gallery:knobs';

/// The text sizes the Text size knob offers.
const galleryTextSizes = [
  EraComboItem<Object?>(1.0, '100 %'),
  EraComboItem<Object?>(2.0, '200 %'),
];

/// The knobs as property rows (database shell spec 5.3), in the order
/// Enter and Tab walk them.
List<PropertyItem> galleryKnobItems(GalleryKnobs knobs) => [
  PropertyItem(
    key: 'enabled',
    label: 'Enabled',
    category: 'State',
    kind: ValueKind.check,
    value: knobs.enabled,
    description:
        'No greys and locks the demo, as a read-only sheet shows its '
        'values; its keys do nothing.',
  ),
  PropertyItem(
    key: 'error',
    label: 'Show an error',
    category: 'State',
    kind: ValueKind.check,
    value: knobs.error,
    description: "Shows the demo's validation message.",
  ),
  PropertyItem(
    key: 'longText',
    label: 'Long text',
    category: 'Sample data',
    kind: ValueKind.check,
    value: knobs.longText,
    description: 'Swaps labels and values for long ones, to see wrapping.',
  ),
  PropertyItem(
    key: 'textScale',
    label: 'Text size',
    category: 'Sizes',
    kind: ValueKind.choice,
    value: knobs.textScale,
    choices: galleryTextSizes,
    description:
        'Scales the text of the gallery and the demo, as the system text '
        'size does.',
  ),
];

/// [knobs] with knob [key] set to [value], as the property grid commits it.
GalleryKnobs applyGalleryKnob(GalleryKnobs knobs, String key, Object? value) =>
    switch ((key, value)) {
      ('enabled', final bool on) => knobs.copyWith(enabled: on),
      ('error', final bool on) => knobs.copyWith(error: on),
      ('longText', final bool on) => knobs.copyWith(longText: on),
      ('textScale', final double scale) => knobs.copyWith(textScale: scale),
      _ => throw ArgumentError.value(value, key, 'Not a gallery knob value'),
    };

/// The knobs the demo shows: [knobs] with the open knob's draft applied, so
/// a tick or a pick shows at once; Enter keeps it and Esc drops it.
GalleryKnobs previewGalleryKnobs(GalleryKnobs knobs, EditSession? session) {
  if (session == null ||
      session.id.record != galleryKnobRecord ||
      !session.changed) {
    return knobs;
  }
  return applyGalleryKnob(knobs, session.id.field, session.draft);
}
```

- [ ] **Step 4: Run the tests**

Run: `"$FLUTTER" test test/ui/gallery/gallery_knob_properties_test.dart`
Expected: 4 PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
"$DART" format lib/ui/gallery/gallery_knob_properties.dart test/ui/gallery/gallery_knob_properties_test.dart
"$FLUTTER" analyze lib/ui/gallery test/ui/gallery
git add lib/ui/gallery/gallery_knob_properties.dart test/ui/gallery/gallery_knob_properties_test.dart
git commit -m "feat: the gallery knobs as property rows with a live preview

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3a: Short scrollbar rails before the gallery gate

**Files:**
- Modify: `lib/ui/controls/era_scrollbar.dart`, `test/ui/controls/era_scrollbar_test.dart`

The reviewed Task 4 sequence at 800 × 600 switches to 200 % text while a knob editor is open. It produces a 31.4 px vertical rail, shorter than the two fixed 17 px arrow buttons, and overflows by 2.6 px at `era_scrollbar.dart`'s `Column`. This is a required shared-control fix, not a reason to remove the gallery assertion or change its dimensions. The public API, 17 px cross-axis thickness and normal scrollbar painting stay the same.

- [ ] **Step 1: Add short-rail mouse regressions**

Append inside `main()` in `test/ui/controls/era_scrollbar_test.dart`, adding `import 'package:flutter/gestures.dart';` for `PointerDeviceKind.mouse` if needed:

```dart
  for (final axis in Axis.values) {
    for (final length in [31.4, 34.0, 80.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$axis rail $length px at $scale text fits and scrolls', (
          tester,
        ) async {
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final vertical = axis == Axis.vertical;
          await tester.pumpWidget(
            _host(
              MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: vertical ? 160 : length,
                  height: vertical ? length : 60,
                  child: ListView(
                    controller: controller,
                    scrollDirection: axis,
                    padding: EdgeInsets.zero,
                    children: const [
                      SizedBox(width: 1000, height: 1000, child: Text('Rows')),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final bar = tester.getRect(
            find.byKey(const ValueKey('era-scrollbar')),
          );
          final back = find.byKey(const ValueKey('era-scrollbar-back'));
          final forward = find.byKey(const ValueKey('era-scrollbar-forward'));
          final backRect = tester.getRect(back);
          final forwardRect = tester.getRect(forward);
          expect(vertical ? bar.width : bar.height, EraScrollbar.thickness);
          expect(bar.contains(backRect.center), isTrue);
          expect(bar.contains(forwardRect.center), isTrue);
          expect(
            vertical ? backRect.bottom : backRect.right,
            lessThanOrEqualTo(vertical ? forwardRect.top : forwardRect.left),
          );
          if (length >= 2 * EraScrollbar.thickness) {
            expect(backRect.size, const Size(17, 17));
            expect(forwardRect.size, const Size(17, 17));
          }
          expect(forward.hitTestable(), findsOneWidget);
          await tester.tap(forward, kind: PointerDeviceKind.mouse);
          await tester.pumpAndSettle();
          expect(controller.offset, EraScrollbar.step);
          await tester.tap(back, kind: PointerDeviceKind.mouse);
          await tester.pumpAndSettle();
          expect(controller.offset, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
```

- [ ] **Step 2: Run the short-rail cases before the fix**

Run: `"$FLUTTER" test --plain-name 'rail 31.4 px' test/ui/controls/era_scrollbar_test.dart`
Expected: FAIL on a 2.6 px `RenderFlex` overflow on both axes; the 31.4 px geometry is the real gallery regression, not an arbitrary smaller window.

- [ ] **Step 3: Bound the arrow lengths by the rail**

Make `_bar` measure its bounded main-axis length with a `LayoutBuilder`. Give each `_ArrowKey` a main-axis extent of `min(17, max(0, availableLength / 2))`, keeping its cross-axis extent 17 px. Pass the axis and extent into the private arrow widget and replace its fixed square with a `SizedBox` of those dimensions. The middle track gets the remaining non-negative space; a track with zero travel must keep drag handling disabled. Keep the existing arrow callbacks, repeat timers, key names, scroll controller and normal track/thumb calculation. Do not put a minimum height on the surrounding viewport or enlarge the gallery to hide the overflow.

- [ ] **Step 4: Run the control suite and preserve existing goldens**

```bash
"$DART" format lib/ui/controls/era_scrollbar.dart test/ui/controls/era_scrollbar_test.dart
"$FLUTTER" analyze lib/ui/controls/era_scrollbar.dart test/ui/controls/era_scrollbar_test.dart
"$FLUTTER" test test/ui/controls/era_scrollbar_test.dart
"$FLUTTER" test test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font test/ui/gallery/gallery_real_font_test.dart
```

Expected: all PASS without `--update-goldens`. Task 4's existing live scaling test must also pass after the gallery migration; a fresh mount at 200 % does not replace that transition test. Record this regression/fix in `lifeManager-9pk.2.1`.

---

### Task 4: The gallery on AppFrame

**Files:**
- Rewrite: `lib/ui/gallery/gallery_app.dart`, `test/ui/gallery/gallery_app_test.dart`
- Modify: `test/support/gallery.dart`

**Interfaces:**
- Consumes: Task 3's `galleryKnobRecord`, `galleryKnobItems`, `applyGalleryKnob`, `previewGalleryKnobs`; `AppFrame`, `AppFrameState` (`closeTree()`, `treeOpen`, `layout`), `AppFramePanes.baseline`, `TreeView`, `TreeNodeData`, `DetailsBox`, `DetailsSection`, `DetailsFact`, `PropertyGrid`, `SubformTab`, `BandedToolbar`, `ToolbarBand`, `ToolbarItem`, `TabItem`, `StatusBar`, `StatusPanel`, `EditorSessionController`, `EditResult`; `GalleryHost`, `GalleryCanvas` (unchanged).
- Produces (unchanged public names): `GalleryApp({demos, initialKnobs})`, `GalleryHome({demos, initialKnobs})`. Test support: `pumpGalleryApp`, `galleryCanvas`, `galleryFrame`, `galleryTreeRow`, `openDemoInTree`, `showDockedKnobs`, `openKnob`, `tickOpenKnob`, `pickOpenTextSize`, `pressKey`.

Layout of the gallery shell:

| AppFrame slot | Content |
|---|---|
| toolbar | Tree key while folded; a band with **Reset knobs** (cancels an open knob draft, restores the opening knobs) |
| areas | One tab, **Widgets** |
| tree | `TreeView`: one bold, expanded node per folder (Foundation, Controls, Data, Shell) with its demo count, the demos under it by widget name. Folder clicks select nothing. Every valid demo click flushes the knob editor and closes the folded tree's overlay. A different demo replaces the canvas; the current demo keeps its own state. |
| details | Widget, Folder, Gallery id, Golden path, Canvas size |
| middle | `GalleryCanvas(key: ValueKey(demo.id), …)` with the previewed knobs |
| subform | One tab, **Summary**: the demo's summary, scrolling |
| properties | `PropertyGrid` of the knobs, labelled **Knobs** (docks as a Knobs tab below 860 px) |
| status | "Synthetic data only; no database is open." · `N widgets` · demo id · `Text 100 %` |

The whole frame sits under `MediaQuery(textScaler: previewed textScale)`, as the phase 1 host scaled the whole gallery. The frame's own `enabled` stays true: the Enabled knob applies to the demo only.

- [ ] **Step 1: Add the test helpers**

Append to `test/support/gallery.dart`, adding `import 'package:flutter/services.dart';` and `import 'package:lifeos/ui/gallery/gallery_app.dart';`:

```dart
/// Pumps a fresh gallery on a window of [size], including in a matrix loop.
/// To test resizing with a draft, change tester.view.physicalSize directly
/// after this mount; calling this helper again deliberately resets state.
Future<void> pumpGalleryApp(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  GalleryKnobs knobs = const GalleryKnobs(),
  List<GalleryDemo>? demos,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryApp(key: UniqueKey(), demos: demos, initialKnobs: knobs),
  );
  await tester.pumpAndSettle();
}

/// The gallery's demo canvas (the gallery's own, not a nested demo's).
GalleryCanvas galleryCanvas(WidgetTester tester) =>
    tester.widget<GalleryCanvas>(find.byType(GalleryCanvas).first);

/// The gallery's own frame state (the first AppFrame in the tree).
AppFrameState galleryFrame(WidgetTester tester) =>
    tester.state<AppFrameState>(find.byType(AppFrame).first);

/// Finds a folder or demo row in the gallery's lazy tree. Open the overlay
/// if needed, scroll back to the top, then wheel until the row is built.
/// ensureVisible alone cannot find rows that ListView has not built yet.
Future<Finder> galleryTreeRow(WidgetTester tester, String label) async {
  final frame = galleryFrame(tester);
  if ((frame.layout?.treeFolded ?? false) && !frame.treeOpen) {
    await tester.tap(find.text('Tree').first, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  }
  final tree = find.byType(TreeView).first;
  final list = find.descendant(of: tree, matching: find.byType(ListView));
  await tester.ensureVisible(list);
  await tester.pumpAndSettle();
  final scrollable = find.descendant(
    of: list,
    matching: find.byType(Scrollable),
  ).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var attempts = 0;
      position.pixels > position.minScrollExtent + 0.5;
      attempts++) {
    expect(attempts, lessThan(100), reason: 'rewind tree for $label');
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(list),
        scrollDelta: const Offset(0, -160),
      ),
    );
    await tester.pumpAndSettle();
  }
  final row = find.descendant(
    of: tree,
    matching: find.text(label),
  );
  for (var attempts = 0; row.evaluate().isEmpty; attempts++) {
    expect(attempts, lessThan(100), reason: 'build tree row $label');
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(list),
        scrollDelta: const Offset(0, 160),
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  expect(row.hitTestable(), findsOneWidget, reason: label);
  return row;
}

/// Clicks [widget]'s row, including rows initially outside the lazy list.
Future<void> openDemoInTree(WidgetTester tester, String widget) async {
  final row = await galleryTreeRow(tester, widget);
  await tester.tap(row, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Shows the docked Knobs tab beside Summary (windows under 860 px).
Future<void> showDockedKnobs(WidgetTester tester) async {
  final tab = find.descendant(
    of: find.byType(TabStrip),
    matching: find.text('Knobs'),
  );
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Clicks knob [key]'s value, opening its editor.
Future<void> openKnob(WidgetTester tester, String key) async {
  final value = find.byKey(ValueKey('property-value:$key'));
  await tester.ensureVisible(value);
  await tester.pumpAndSettle();
  expect(value.hitTestable(), findsOneWidget, reason: key);
  await tester.tap(value, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Ticks or unticks the check box of the open knob [key].
Future<void> tickOpenKnob(WidgetTester tester, String key) async {
  final box = find.descendant(
    of: find.byKey(ValueKey('property-editor:$key')),
    matching: find.byKey(const ValueKey('era-check-box')),
  );
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Picks [label] from the open Text size editor's list.
Future<void> pickOpenTextSize(WidgetTester tester, String label) async {
  final face = find.byKey(const ValueKey('property-editor:textScale'));
  await tester.ensureVisible(face);
  await tester.pumpAndSettle();
  await tester.tap(face, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Write the failing app tests**

Replace `test/ui/gallery/gallery_app_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/control_demos.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demos.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

void main() {
  GalleryKnobs knobs(WidgetTester tester) => galleryCanvas(tester).knobs;

  Finder knobEditor(String key) =>
      find.byKey(ValueKey('property-editor:$key'));

  testWidgets('the gallery is an AppFrame with the tree, Details, the demo '
      'and the knobs', (tester) async {
    await pumpGalleryApp(tester);
    expect(find.byType(AppFrame), findsOneWidget);
    expect(find.byType(TreeView), findsOneWidget);
    expect(find.byType(PropertyGrid), findsOneWidget);
    expect(find.byType(DataRegister), findsNothing, reason: 'old list gone');
    expect(galleryCanvas(tester).demo.id, galleryDemos.first.id);
    for (final folder in ['Foundation', 'Controls', 'Data', 'Shell']) {
      final row = await galleryTreeRow(tester, folder);
      expect(row.hitTestable(), findsOneWidget);
    }
    expect(
      find.text('Synthetic data only; no database is open.'),
      findsOneWidget,
    );
  });

  testWidgets('a demo opens from the tree; a folder click keeps the demo', (
    tester,
  ) async {
    await pumpGalleryApp(tester);
    await openDemoInTree(tester, galleryDemos[1].widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
    expect(
      find.descendant(
        of: find.byType(DetailsBox),
        matching: find.text(galleryDemos[1].id),
      ),
      findsOneWidget,
    );
    final folder = await galleryTreeRow(tester, 'Data');
    await tester.tap(folder, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
  });

  testWidgets('the knobs reach the demo through the property grid; Enter '
      'walks them in order', (tester) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'enabled');
    await tickOpenKnob(tester, 'enabled');
    expect(knobs(tester).enabled, isFalse, reason: 'previewed before Enter');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobEditor('error'), findsOneWidget, reason: 'Enter opens next');
    await tickOpenKnob(tester, 'error');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'longText');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await pickOpenTextSize(tester, '200 %');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobEditor('textScale'), findsNothing, reason: 'last closes');
    final shown = knobs(tester);
    expect(
      (shown.enabled, shown.error, shown.longText, shown.textScale),
      (false, true, true, 2.0),
    );
    expect(find.text('Text 200 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Esc drops a previewed knob; the demo returns to the kept '
      'knobs', (tester) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'error');
    await tickOpenKnob(tester, 'error');
    expect(knobs(tester).error, isTrue);
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(knobs(tester).error, isFalse);
    expect(knobEditor('error'), findsNothing);
  });

  testWidgets('picking another demo keeps an open knob draft first', (
    tester,
  ) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'longText');
    await tickOpenKnob(tester, 'longText');
    await openDemoInTree(tester, galleryDemos[1].widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
    expect(knobs(tester).longText, isTrue);
    expect(knobEditor('longText'), findsNothing);
  });

  testWidgets('picking the current demo flushes its knob, closes the folded '
      'tree and keeps demo state', (tester) async {
    final demo = controlDemos.singleWhere(
      (demo) => demo.id == 'controls/era_check_box',
    );
    await pumpGalleryApp(tester, size: const Size(800, 600), demos: [demo]);
    final box = find.descendant(
      of: find.byType(GalleryCanvas),
      matching: find.byType(EraCheckBox),
    );
    await tester.tap(find.text('Off days'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.widget<EraCheckBox>(box).value, isFalse);
    await showDockedKnobs(tester);
    await openKnob(tester, 'error');
    await tickOpenKnob(tester, 'error');
    await openDemoInTree(tester, demo.widget);
    expect(galleryFrame(tester).treeOpen, isFalse);
    expect(knobEditor('error'), findsNothing, reason: 'draft flushed');
    expect(knobs(tester).error, isTrue);
    expect(galleryCanvas(tester).demo.id, demo.id);
    expect(tester.widget<EraCheckBox>(box).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distant tree demos and the first demo are reachable by mouse '
      'at wide and folded sizes, at both text scales', (tester) async {
    for (final size in const [Size(1280, 800), Size(800, 600)]) {
      for (final scale in [1.0, 2.0]) {
        await pumpGalleryApp(
          tester,
          size: size,
          knobs: GalleryKnobs(textScale: scale),
        );
        await openDemoInTree(tester, galleryDemos.last.widget);
        expect(galleryCanvas(tester).demo.id, galleryDemos.last.id);
        await openDemoInTree(tester, galleryDemos.first.widget);
        expect(galleryCanvas(tester).demo.id, galleryDemos.first.id);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Reset knobs drops the draft and restores the opening knobs', (
    tester,
  ) async {
    await pumpGalleryApp(tester, knobs: const GalleryKnobs(longText: true));
    await openKnob(tester, 'enabled');
    await tickOpenKnob(tester, 'enabled');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'error');
    await tester.tap(find.text('Reset knobs'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final shown = knobs(tester);
    expect(
      (shown.enabled, shown.error, shown.longText),
      (true, false, true),
    );
    expect(knobEditor('error'), findsNothing);
  });

  testWidgets("a demo's own state does not survive leaving it", (
    tester,
  ) async {
    final checkBox = controlDemos.singleWhere(
      (demo) => demo.id == 'controls/era_check_box',
    );
    final keys = controlDemos.singleWhere(
      (demo) => demo.id == 'controls/key_button',
    );
    await pumpGalleryApp(tester, demos: [checkBox, keys]);
    EraCheckBox box() => tester.widget<EraCheckBox>(
      find.descendant(
        of: find.byType(GalleryCanvas),
        matching: find.byType(EraCheckBox),
      ),
    );
    expect(box().value, isTrue);
    await tester.tap(find.text('Off days'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(box().value, isFalse);
    await openDemoInTree(tester, 'KeyButton');
    await openDemoInTree(tester, 'EraCheckBox');
    expect(box().value, isTrue);
  });

  testWidgets('narrowing with a knob editor open shows the docked Knobs tab '
      'and keeps the draft', (tester) async {
    await pumpGalleryApp(tester);
    await openKnob(tester, 'error');
    await tickOpenKnob(tester, 'error');
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    expect(galleryFrame(tester).layout?.propertiesDocked, isTrue);
    expect(knobEditor('error'), findsOneWidget);
    expect(knobs(tester).error, isTrue, reason: 'still previewed');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobs(tester).error, isTrue);
  });

  testWidgets('at 800 x 600 every knob and the tree are reachable, also '
      'at 200 % text', (tester) async {
    await pumpGalleryApp(tester, size: const Size(800, 600));
    expect(galleryFrame(tester).layout?.treeFolded, isTrue);
    await openDemoInTree(tester, galleryDemos[1].widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos[1].id);
    expect(galleryFrame(tester).treeOpen, isFalse, reason: 'a pick closes');

    await showDockedKnobs(tester);
    await openKnob(tester, 'enabled');
    await tickOpenKnob(tester, 'enabled');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'error');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await tickOpenKnob(tester, 'longText');
    await pressKey(tester, LogicalKeyboardKey.enter);
    await pickOpenTextSize(tester, '200 %');
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(knobs(tester).textScale, 2);
    expect(tester.takeException(), isNull);

    // At 200 % text, untick each check again. Enter keeps it and opens the
    // next knob unchanged; Esc closes that one, so the next click lands on
    // a plain value.
    for (final key in ['enabled', 'error', 'longText']) {
      await openKnob(tester, key);
      await tickOpenKnob(tester, key);
      await pressKey(tester, LogicalKeyboardKey.enter);
      await pressKey(tester, LogicalKeyboardKey.escape);
    }
    final shown = knobs(tester);
    expect(
      (shown.enabled, shown.error, shown.longText, shown.textScale),
      (true, false, false, 2.0),
    );
    await openDemoInTree(tester, galleryDemos.first.widget);
    expect(galleryCanvas(tester).demo.id, galleryDemos.first.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the gallery holds at 200 % text with long labels', (
    tester,
  ) async {
    await pumpGalleryApp(
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

Also add the shell-matrix test inside the same `main()` (2b item 3: every demo still works inside the new gallery shell). Cover every size in spec section 10, plus either side of the 1024/860 px fold/dock breakpoints, at both text scales with long labels and errors. Each demo is shown first, so no tree navigation is needed. `pumpGalleryApp` uses a fresh key for every case: changing constructor arguments alone would keep the first demo and knobs. Assert both the demo's knobs and the frame's actual `MediaQuery` scale so a stale 100 % mount cannot pass as 200 %.

```dart
  testWidgets('every demo runs inside the gallery shell across the full '
      'size and text-scale matrix', (tester) async {
    for (final size in const [
      Size(1280, 800),
      Size(1025, 768),
      Size(1024, 768),
      Size(1023, 768),
      Size(960, 760),
      Size(861, 600),
      Size(860, 600),
      Size(859, 600),
      Size(800, 600),
    ]) {
      for (final scale in [1.0, 2.0]) {
        for (final demo in galleryDemos) {
          final reason = '${demo.id} at $size x$scale';
          await pumpGalleryApp(
            tester,
            size: size,
            knobs: GalleryKnobs(textScale: scale, longText: true, error: true),
            demos: [demo],
          );
          expect(tester.takeException(), isNull, reason: reason);
          final canvas = galleryCanvas(tester);
          expect(canvas.demo.id, demo.id, reason: reason);
          expect(canvas.knobs.textScale, scale, reason: reason);
          final context = tester.element(find.byType(AppFrame).first);
          expect(
            MediaQuery.textScalerOf(context).scale(100),
            100 * scale,
            reason: reason,
          );
        }
      }
    }
  });
```

- [ ] **Step 3: Run them to see them fail**

Run: `"$FLUTTER" test test/ui/gallery/gallery_app_test.dart`
Expected: FAIL. The first test fails because the old host has no `AppFrame`, and the knob tests fail on a missing `property-value:enabled`.

- [ ] **Step 4: Rewrite `gallery_app.dart`**

```dart
import 'package:flutter/widgets.dart';

import '../ui.dart';
import 'gallery_demo.dart';
import 'gallery_demos.dart';
import 'gallery_host.dart';
import 'gallery_knob_properties.dart';

/// The widget gallery (database shell spec 5.3): every library widget on
/// synthetic data in the library's own shell. The tree lists the widgets by
/// folder, the middle shows the live demo over its summary, and the
/// property grid edits the demo's knobs.
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
    home: GalleryHome(demos: demos ?? galleryDemos, initialKnobs: initialKnobs),
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
  static const _area = 'widgets';
  static const _summaryTab = 'summary';

  final _controller = EditorSessionController();
  final _frame = GlobalKey<AppFrameState>();

  late GalleryDemo _demo = widget.demos.first;
  late GalleryKnobs _knobs = widget.initialKnobs;
  AppFramePanes _panes = AppFramePanes.baseline;
  String? _lowerTab = _summaryTab;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the demo [id] names; a folder node names none. An open knob
  /// draft is kept first, as any command that leaves the field does.
  void _open(String id) {
    final demo = widget.demos.where((demo) => demo.id == id).firstOrNull;
    if (demo == null) return;
    if (!_controller.flush().isAccepted) return;
    _frame.currentState?.closeTree();
    if (demo.id != _demo.id) setState(() => _demo = demo);
  }

  EditResult _commit(EditIdentity id, Object? draft) {
    setState(() => _knobs = applyGalleryKnob(_knobs, id.field, draft));
    return const EditResult.accepted();
  }

  void _reset() {
    _controller.cancel();
    setState(() => _knobs = widget.initialKnobs);
  }

  List<TreeNodeData> _nodes() => [
    for (final MapEntry(key: folder, value: title) in _folders.entries)
      if (widget.demos.where((demo) => demo.folder == folder).toList()
          case final demos when demos.isNotEmpty)
        TreeNodeData(
          id: 'folder:$folder',
          label: title,
          count: demos.length,
          bold: true,
          expanded: true,
          children: [
            for (final demo in demos)
              TreeNodeData(id: demo.id, label: demo.widget),
          ],
        ),
  ];

  Widget _details() => DetailsBox(
    caption: 'Details',
    sections: [
      DetailsSection(
        facts: [
          DetailsFact('Widget', _demo.widget, figure: false),
          DetailsFact('Folder', _demo.folder, figure: false),
          DetailsFact('Gallery id', _demo.id, figure: false),
          DetailsFact(
            'Golden',
            'test/ui/goldens/${_demo.goldenName}.png',
            figure: false,
          ),
          DetailsFact(
            'Canvas',
            '${_demo.size.width.round()} x ${_demo.size.height.round()} px',
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final shown = previewGalleryKnobs(_knobs, _controller.session);
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(shown.textScale)),
        child: AppFrame(
          key: _frame,
          controller: _controller,
          toolbarBuilder: (context, tree) => BandedToolbar(
            bands: [
              if (tree != null) ToolbarBand(items: [tree]),
              ToolbarBand(
                items: [ToolbarItem(label: 'Reset knobs', onPressed: _reset)],
              ),
            ],
          ),
          areas: const [
            TabItem(id: _area, label: 'Widgets', icon: EraIconKind.app),
          ],
          areaId: _area,
          onAreaSelect: (_) {},
          treeTitle: 'Widgets',
          treeIcon: EraIconKind.app,
          tree: TreeView(
            label: 'Widgets by folder',
            nodes: _nodes(),
            selectedId: _demo.id,
            onSelect: _open,
          ),
          details: _details(),
          middle: GalleryCanvas(
            key: ValueKey(_demo.id),
            demo: _demo,
            knobs: shown,
          ),
          subformTabs: [
            SubformTab(
              id: _summaryTab,
              label: 'Summary',
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: Text(_demo.summary),
              ),
            ),
          ],
          subformSelectedId: _lowerTab,
          onSubformSelect: (id) => setState(() => _lowerTab = id),
          subformLabel: _demo.widget,
          properties: PropertyGrid(
            record: galleryKnobRecord,
            controller: _controller,
            items: galleryKnobItems(_knobs),
            onCommit: _commit,
            today: galleryToday,
            label: 'Knobs',
          ),
          propertiesLabel: 'Knobs',
          status: StatusBar(
            notice: 'Synthetic data only; no database is open.',
            panels: [
              StatusPanel('${widget.demos.length} widgets'),
              StatusPanel(_demo.id),
              StatusPanel('Text ${(shown.textScale * 100).round()} %'),
            ],
          ),
          panes: _panes,
          onPanesChanged: (panes) => setState(() => _panes = panes),
        ),
      );
    },
  );
}
```

- [ ] **Step 5: Run the app tests**

Run: `"$FLUTTER" test test/ui/gallery/gallery_app_test.dart`
Expected: all PASS. If one fails, debug it with superpowers:systematic-debugging. Do not loosen an assertion. In particular:
- If ticking a check box does not change `knobs(tester)` before Enter, the preview is not rebuilding. Check that `ListenableBuilder` listens to the same controller the `PropertyGrid` uses.
- If the 800 × 600 test cannot hit a knob, record which knob and its rectangle. That is a reachability defect in the gallery composition or in `AppFrame`, and it needs fixing, not skipping.
- Task 3a must be implemented before this run. The live Text size transition must have no short-rail scrollbar overflow, and both a current-demo pick and a different-demo pick must close the folded tree.
- Keep the tree lazy. If a folder or distant demo is not found, fix the helper's scoped scrolling rather than forcing all tree rows to build at once.

- [ ] **Step 6: Run the whole gallery, UI and keyboard suites**

```bash
"$DART" format lib/ui/gallery test/ui/gallery test/support/gallery.dart
"$FLUTTER" analyze lib test tool
"$FLUTTER" test test/ui
```

Expected: `No issues found!` and all PASS. The demo golden tests still pass byte-for-byte, because `GalleryCanvas` and the demos are unchanged.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/gallery/gallery_app.dart test/ui/gallery/gallery_app_test.dart test/support/gallery.dart lib/ui/controls/era_scrollbar.dart test/ui/controls/era_scrollbar_test.dart
git commit -m "feat: the widget gallery runs on AppFrame, TreeView and PropertyGrid

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Shell goldens, docs and the phase 2 gate

**Files:**
- Modify: `test/ui/gallery/gallery_goldens_test.dart`, `test/ui/gallery/gallery_real_font_test.dart`, `lib/ui/CATALOG.md`, `.claude/skills/lifeos-ui/SKILL.md`, `.agents/skills/lifeos-ui/SKILL.md`
- Create: `test/ui/goldens/gallery_shell.png`, `test/ui/goldens/gallery_shell_docked.png` and their `real_font/` twins

- [ ] **Step 1: Add the shell golden tests**

Append inside `main()` of `test/ui/gallery/gallery_goldens_test.dart`, adding `import 'package:flutter/widgets.dart';` if it is not there yet:

```dart
  testWidgets('gallery_shell', (tester) async {
    await pumpGalleryApp(tester);
    await expectLater(
      find.byType(GalleryHost),
      matchesGoldenFile('../goldens/gallery_shell.png'),
    );
  });

  testWidgets('gallery_shell_docked', (tester) async {
    await pumpGalleryApp(tester, size: const Size(800, 600));
    await showDockedKnobs(tester);
    await expectLater(
      find.byType(GalleryHost),
      matchesGoldenFile('../goldens/gallery_shell_docked.png'),
    );
  });
```

Append the same two tests to `test/ui/gallery/gallery_real_font_test.dart`, named `real_font/gallery_shell` and `real_font/gallery_shell_docked`, matching `../goldens/real_font/gallery_shell.png` and `../goldens/real_font/gallery_shell_docked.png`.

- [ ] **Step 2: Generate only these four goldens and look at them**

```bash
"$FLUTTER" test --update-goldens --plain-name gallery_shell test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font --update-goldens --plain-name real_font/gallery_shell test/ui/gallery/gallery_real_font_test.dart
git status --short test/ui/goldens
```

Expected: four new PNGs and no modified PNG. Look at each image:
- **Wide:** menu bar, toolbar with Reset knobs, the Widgets tab, the tree with four bold folders and counts, Details, the first demo in the middle, the Summary tab, the Knobs grid in three categories, and the status bar with three panels.
- **Docked:** the Tree key in the toolbar, and the Knobs tab selected beside Summary.

- [ ] **Step 3: Update the catalog and the skill**

In `lib/ui/CATALOG.md`:
- Intro: replace "The reusable era workbench lives in `lib/ui/` in phase 1." with "The reusable era workbench lives in `lib/ui/`.".
- Status bullet: replace "Phase 1 gallery hosts, demos and compatibility tests may use them until their replacements exist;" with "Demos and compatibility tests may use them until their replacements exist;".
- AppFrame entry `Use for:`: "the database shell's window, the widget gallery and the gallery's whole-composition demo."
- Replace the `## Next` body with:

```
Phase 2 is complete: the widgets above are available and the gallery runs
on `AppFrame`, `TreeView` and `PropertyGrid` (tree by folder, demo in the
middle, knobs in the property grid). Next is phase 3 (`lifeManager-9pk.3`):
the new shell and edit session in an integration harness. Production keeps
the old shell until phase 4.
```

In both `.claude/skills/lifeos-ui/SKILL.md` and `.agents/skills/lifeos-ui/SKILL.md`, replace step 2's text with:

```
2. Reuse a `stable` or `new` widget. Deprecated widgets remain valid in
   existing screens, demos and compatibility tests until their
   replacements exist; new screens use the replacement.
```

Check that the two copies match: `diff .claude/skills/lifeos-ui/SKILL.md .agents/skills/lifeos-ui/SKILL.md` prints nothing.

- [ ] **Step 4: Full quality gate and golden hash check**

Run in one shell, with `UI_BASELINE_DIR` from Task 0:

```bash
set -euo pipefail
"$FLUTTER" analyze lib test tool
"$DART" format --output=none --set-exit-if-changed lib test tool
"$DART" run tool/schema_check.dart
"$FLUTTER" test --reporter expanded
"$FLUTTER" test test/ui/gallery/gallery_goldens_test.dart
"$FLUTTER" test --run-skipped -t real-font $(find test -name '*real_font*_test.dart' | sort)
python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
baseline = json.loads((Path(os.environ['UI_BASELINE_DIR']) / 'goldens.json').read_text())
changed = [name for name, digest in baseline.items()
           if not Path(name).exists()
           or hashlib.sha256(Path(name).read_bytes()).hexdigest() != digest]
now = {str(p) for root in ('test/goldens', 'test/ui/goldens') for p in Path(root).rglob('*.png')}
print('Changed baseline PNGs:', changed)
print('New PNGs:', sorted(now - set(baseline)))
assert not changed, 'This plan changes no existing PNG'
PY
git diff --check
```

Expected: analyze clean, format clean, `schema_check` ok, every test passes, `Changed baseline PNGs: []`. New PNGs are exactly the six from Tasks 2 and 5: `controls_era_combo_open` and `gallery_shell`, `gallery_shell_docked`, each with a `real_font/` twin.

- [ ] **Step 5: Launcher check (CLAUDE.md)**

Run `printf '2\n6\n' | ./app.sh` (tests) and `printf '3\n6\n' | ./app.sh` (checks). Both must end green. Then start option 5 (gallery) and option 1 (production) by hand and close each normally. `app.sh` needs no change; if a command or requirement did change, update it.

- [ ] **Step 6: Owner's manual pass**

Ask the owner to open `./app.sh` › 5 and check five things:
- Pick demos in every folder.
- Tick each knob and watch the preview; Esc drops it and Enter keeps it.
- Use Reset knobs.
- Drag both splitters.
- Narrow the window to 800 × 600: the Tree key and the Knobs tab must work, also at 200 % text.

Record the result in Beads. Do not close the phase before the owner confirms.

- [ ] **Step 7: Commit, record, close**

```bash
git add test/ui/gallery/gallery_goldens_test.dart test/ui/gallery/gallery_real_font_test.dart test/ui/goldens/gallery_shell.png test/ui/goldens/gallery_shell_docked.png test/ui/goldens/real_font/gallery_shell.png test/ui/goldens/real_font/gallery_shell_docked.png lib/ui/CATALOG.md .claude/skills/lifeos-ui/SKILL.md .agents/skills/lifeos-ui/SKILL.md
git commit -m "docs: the gallery on AppFrame closes phase 2; shell goldens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
bd close lifeManager-9pk.2.1 --reason "Gallery on AppFrame/TreeView/PropertyGrid; old layout removed; gates green, no baseline PNG changed; owner manual pass <date>."
bd close lifeManager-9pk.2 --reason "Phase 2a widgets and 2b gallery migration complete; 9pk.8 closed."
bd ready
```

Expected: `lifeManager-9pk.3` (phase 3) appears in `bd ready`.
