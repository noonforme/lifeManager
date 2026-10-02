# LifeOS Millennium Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 2001 office-PC "Millennium" look the only LifeOS style and reshape the shell into the file-explorer layout (orb toolbar, Address bar, blue task pane, details list, property sheet, sunken status bar).

**Architecture:** The skin switch collapses into one fixed style read through the existing `LifeOSSkinScope.of(context)` (tokens, typography, painters). New era controls (orbs, push buttons, combo faces, group boxes, property-sheet tabs, dialogs, information panel) live in `lib/shared/workbench/`. The shell frame gains an Address bar and a task pane, loses the formula bar row (its content becomes the **Working** group box in the property sheet), and every surface supplies its own task group and details.

**Tech Stack:** Flutter 3.47.5 (desktop Linux), Dart, Riverpod, GoRouter, Drift. Tests: `flutter_test` widget, integration and golden tests.

**Spec:** `docs/superpowers/specs/2026-10-02-lifeos-millennium-shell-design.md` (read it before Task 1; section numbers below refer to it).

## Global Constraints

- Flutter binary: `F=~/.local/opt/flutter-3.47.5/bin` (not on PATH). Run tests with `$F/flutter test <path>`, analysis with `$F/flutter analyze lib test tool`, formatting with `$F/dart format lib test tool`.
- Every task ends with `$F/flutter analyze lib test tool` reporting "No issues found!" and `$F/dart format --output=none --set-exit-if-changed lib test tool` passing.
- One style only: no Office Machine, no Night, no High contrast, no View › Appearance, no second palette (spec §2, §3.1).
- Widgets take colours from `LifeOSTokens` or `MillenniumColors` named constants, never `Color(0x…)` literals (spec §3.3).
- Font: Noto Sans (`NotoSans`, bundled) for all text; numbers use `FontFeature.tabularFigures()` (spec §3.4).
- No vendor names, logos, icons, wallpapers or sounds. Toolbar orbs and status glyphs are painted (spec §2).
- Every key keeps a visible label and a 24 × 24 minimum target; menu rows are 24 px (spec §5.1, §5.9, §6).
- Text pairs meet 4.5:1. Indicators, the key outline and focus meet 3:1. The era field outline (#7f9db9) and the sorted-column amber are kept as era colours below 3:1: fields are also told apart by their white fill and label, and the sort order is written (▴ / ▾) (spec §6).
- Keyboard focus is a dotted rectangle; selection is a solid `selWash` (#316ac5) fill with `selInk` (white) text. They never look the same (spec §5.12).
- Copy, routes, records and calculations are unchanged except the behaviour changes in spec §8.
- The live shift tracker (running / on-break inspectors, Start shift, running-shift status panel) is not restyled beyond what shared widgets give it for free (spec §10).
- Synthetic data only in tests, goldens and screenshots.
- Commit after every task with a message ending in `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **200 % text in the 200 px task pane and 300 px property sheet:** long employment names, long crumbs and long task links must wrap or ellipsize, never overflow. Test in Task 6 and Task 9.
2. **Folding and unfolding across 1024 px with the Tasks overlay open:** widening the window must show the docked task pane and drop the overlay state, without losing the current route or selection. Test in Task 6.
3. **Keyboard focus on a selected row:** the dotted cell cursor on a blue selected row must use white (`selInk`) dots so focus stays visible on selection. Test in Task 7.
4. **An appearance saved by an older build** (`preferences` row `appearance = night`) must be ignored: the app starts in the single style and never reads it. Test in Task 2.
5. **A long Working explanation** (several operands) in the 300 px property sheet must wrap onto several lines with every operand link still tappable; with nothing selected the Working box is absent. Test in Task 9.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/shared/workbench/lifeos_tokens.dart` | `LifeOSTokens` with the single `LifeOSTokens.millennium` palette, area keys, contrast helpers. |
| `lib/shared/workbench/millennium_style.dart` (new) | `MillenniumColors`, `lifeOSTypography`, `LifeOSPainters`, `InsetRings`, `DottedFocusRectangle`. |
| `lib/shared/workbench/lifeos_skin.dart` | Typography/key value types, `LifeOSSkinData`, `LifeOSSkinScope` (single style). |
| `lib/shared/workbench/lifeos_theme.dart` | Material theme from the single style. |
| `lib/shared/workbench/office_controls.dart` | `KeyButton` (push and toolbar keys), `AreaKey`, `CountBadge`, `PropertySheetTabs`. |
| `lib/shared/workbench/era_controls.dart` (new) | `Orb`, `EraComboFace`, `GroupBox`, `FormFooter`. |
| `lib/shared/workbench/era_dialog.dart` (new) | `EraDialog` (caption bar, body, footer). |
| `lib/shared/workbench/operational_state.dart` | Information panel with painted ⓘ / ⚠ glyphs. |
| `lib/shared/workbench/data_register.dart` | Details-list painting (headers, sorted column, group rows, 20 px rows, dotted cell cursor). |
| `lib/shared/workbench/inspector_parts.dart` | Property-sheet content parts (title, facts in group boxes, notes, actions). |
| `lib/shared/shell/shell_frame.dart` | Frame: menu bar, toolbar, Address bar, task pane, content, property sheet, status bar; width behaviour. |
| `lib/shared/shell/address_bar.dart` (new) | `AddressCrumb`, `AddressBar`. |
| `lib/shared/shell/task_pane.dart` (new) | `TaskPane`, `TaskGroup`, `TaskLink`, `TaskDetails`. |
| `lib/shared/shell/working_group_box.dart` (new, replaces `formula_bar.dart`) | The selected cell's working as a group box. |
| `lib/shared/shell/book_tree.dart` | Books rows drawn as task-pane links. |
| `lib/shared/shell/status_line.dart` | Sunken status panels. |
| `lib/shared/shell/menu_bar.dart` | Menu bar without Appearance; renamed View items. |
| `lib/shared/shell/desk_view.dart` | Property-sheet desk tabs and window-style tiles. |
| `lib/app/shell_host.dart`, `lib/app/desk_host.dart`, `lib/app/app_router.dart`, `lib/app/lifeos_app.dart` | Wiring: crumbs, task groups, removal of appearance. |
| `lib/features/work/presentation/*` | View combo, filter row, Work tasks and details, property-sheet content, forms. |
| `test/support/work_sheets.dart` (new) | `chooseSheet` test helper for the View combo. |

---

### Task 1: Commit the inspector groundwork

The working tree holds an uncommitted inspector refactor (`inspector_parts.dart`, Material buttons with the key edge, test harness scopes). Later tasks build on it.

**Files:**
- Commit only: `lib/shared/workbench/inspector_parts.dart`, `lib/shared/workbench/lifeos_theme.dart`, `lib/features/work/presentation/{period_payslip_forms,record_history_panel,shift_forms,work_inspector}.dart`, `DESIGN.md`, the modified tests under `test/`, and the four updated `test/goldens/shell_*_1280x800.png`.

**Interfaces:**
- Produces: `InspectorPane`, `InspectorTitle`, `InspectorSection`, `InspectorFacts`, `InspectorFactRow`, `Fact`, `Fact.words`, `FactTone`, `InspectorNote`, `InspectorText`, `InspectorActions`, `inspectorInset` (all in `lib/shared/workbench/inspector_parts.dart`).

- [ ] **Step 1: Verify the tree is green**

Run: `$F/flutter test`
Expected: final line `All tests passed!`

- [ ] **Step 2: Commit**

```bash
git status --short
git add lib/shared/workbench/inspector_parts.dart lib/shared/workbench/lifeos_theme.dart \
  lib/features/work/presentation/period_payslip_forms.dart \
  lib/features/work/presentation/record_history_panel.dart \
  lib/features/work/presentation/shift_forms.dart \
  lib/features/work/presentation/work_inspector.dart DESIGN.md test/
git commit -m "fix: build the inspector from shared parts and the skin's keys

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Expected: `git status --short` afterwards shows nothing under `lib/`, `test/` or `DESIGN.md`.

---

### Task 2: One palette, one style

Removes Office Machine, the appearance setting and its persistence; moves Millennium into a single style file (spec §3.1–§3.3).

**Files:**
- Modify: `lib/shared/workbench/lifeos_tokens.dart`
- Create: `lib/shared/workbench/millennium_style.dart`
- Modify: `lib/shared/workbench/lifeos_skin.dart`
- Delete: `lib/shared/workbench/skins/millennium_skin.dart`
- Modify: `lib/shared/workbench/lifeos_theme.dart`
- Modify: `lib/app/lifeos_app.dart`, `lib/main.dart`, `lib/app/production_work_providers.dart`, `lib/shared/shell/menu_bar.dart`, `lib/shared/shell/book_tree.dart:92`
- Delete: `lib/core/preferences/preference_repository.dart` (keep `lib/core/preferences/preferences.dart`: the table stays, no migration)
- Delete: `test/shared/workbench/skins_test.dart`
- Modify: `test/shared/workbench/lifeos_tokens_test.dart`, `test/shared/workbench/office_controls_test.dart`, `test/app/lifeos_app_test.dart`, `test/goldens/shell_goldens_test.dart`, every test calling `buildLifeOSTheme(highContrast: …)`

**Interfaces:**
- Produces:
  - `LifeOSTokens.millennium` (const), `LifeOSTokens.standardAreaKeys`.
  - `MillenniumColors.*` named colours (listed in Step 3).
  - `const LifeOSTypography lifeOSTypography`.
  - `final class LifeOSPainters` with `key`, `areaMarker`, `countBadge`, `countBadgeInk`, `focusRing`, `toolbar`, `cellCursor` (same signatures as today's `SkinPainters` minus `treeBackground`, `statusLine`, `segment`, `segmentInk`).
  - `final class DottedFocusRectangle extends Decoration` (`DottedFocusRectangle({required Color color, double inset = 2.5})`).
  - `LifeOSSkinData({required LifeOSTokens tokens, required LifeOSTypography typography, required LifeOSPainters painters})`, `LifeOSSkinData.standard` (const).
  - `LifeOSSkinScope({required Widget child})`, `LifeOSSkinScope.of(context)`.
  - `ThemeData buildLifeOSTheme()`.
- Removed: `LifeOSAppearance`, `LifeOSAppearanceController`, `LifeOSAppearanceScope`, `LifeOSSkin`, `OfficeMachineSkin`, `MillenniumSkin`, `SkinPainters`, `AreaMarkerStyle`, `StatusLineStyle`, `PreferenceRepository`, `PreferenceKey`, `LifeOsApp.preferences`.

- [ ] **Step 1: Write the failing palette test**

Replace `test/shared/workbench/lifeos_tokens_test.dart` with:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';
import 'package:lifeos/shared/workbench/millennium_style.dart';

void main() {
  const t = LifeOSTokens.millennium;

  test('contrast ratio matches the WCAG reference values', () {
    expect(
      contrastRatio(const Color(0xff000000), const Color(0xffffffff)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xff777777), const Color(0xffffffff)),
      closeTo(4.48, 0.01),
    );
  });

  // Selected rows draw every cell in selInk, so muted, run, negative and
  // positive text never sits on the saturated selWash.
  final text = <String, (Color, List<Color>)>{
    'ink': (
      t.ink,
      [t.paper, t.band, t.chrome, MillenniumColors.paneBody, MillenniumColors.page],
    ),
    'muted': (t.muted, [t.paper, t.band, t.chrome, MillenniumColors.paneBody]),
    'runInk': (t.runInk, [t.paper, t.band, t.chrome]),
    'negative': (t.negative, [t.paper, t.band, t.chrome]),
    'positive': (t.positive, [t.paper, t.band, t.chrome]),
    'selInk': (t.selInk, [t.selWash]),
    'headInk': (t.headInk, [t.head, MillenniumColors.captionBottom]),
    'head as text': (t.head, [t.paper, MillenniumColors.page]),
    'link': (MillenniumColors.link, [MillenniumColors.paneBody, t.paper]),
  };
  for (final MapEntry(key: name, value: (ink, surfaces)) in text.entries) {
    test('$name text meets 4.5:1', () {
      for (final surface in surfaces) {
        expect(
          contrastRatio(ink, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name on $surface',
        );
      }
    });
  }

  test('area key letters meet 4.5:1 on their keys', () {
    expect(t.areaKeys.keys, unorderedEquals(LifeOSArea.values));
    for (final key in t.areaKeys.values) {
      expect(contrastRatio(key.ink, key.fill), greaterThanOrEqualTo(4.5));
    }
  });

  test('indicators and outlines meet 3:1', () {
    for (final (name, color, surface) in [
      ('signal', t.signal, t.paper),
      ('signal on face', t.signal, t.chrome),
      ('focus', t.focus, t.paper),
      ('focus on face', t.focus, t.chrome),
      ('key outline', MillenniumColors.keyLine, t.chrome),
      ('key outline on white', MillenniumColors.keyLine, t.paper),
      ('progress', MillenniumColors.progress, t.ink),
    ]) {
      expect(
        contrastRatio(color, surface),
        greaterThanOrEqualTo(3),
        reason: name,
      );
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `$F/flutter test test/shared/workbench/lifeos_tokens_test.dart`
Expected: compile error, `millennium_style.dart` not found / `LifeOSTokens.millennium` undefined.

- [ ] **Step 3: Rewrite the tokens and create the style file**

In `lib/shared/workbench/lifeos_tokens.dart`:
- Delete the `LifeOSAppearance` enum and its doc comment.
- Delete `_nightKeys`, `day`, `night`, `highContrast`.
- Rename `_dayKeys` to `standardAreaKeys` (public, `static const`), delete the `dayAreaKeys` alias, and add after it:

```dart
  /// The LifeOS palette: the 2001 office PC (Millennium shell spec 3.3).
  static const millennium = LifeOSTokens(
    ground: Color(0xffece9d8),
    paper: Color(0xffffffff),
    ink: Color(0xff000000),
    muted: Color(0xff555555),
    rule: Color(0xffecebe5),
    band: Color(0xfff1efe2),
    chrome: Color(0xffece9d8),
    chromeLine: Color(0xffc5c2b2),
    head: Color(0xff0046d5),
    headInk: Color(0xffffffff),
    signal: Color(0xffd9500b),
    actionFill: Color(0xffffffff),
    actionInk: Color(0xff000000),
    runInk: Color(0xffb83d0b),
    selWash: Color(0xff316ac5),
    selInk: Color(0xffffffff),
    negative: Color(0xffcc0000),
    positive: Color(0xff2a752d),
    focus: Color(0xff000000),
    areaKeys: standardAreaKeys,
  );
```

Create `lib/shared/workbench/millennium_style.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'lifeos_skin.dart';
import 'lifeos_tokens.dart';

/// Named colours of the 2001 office-PC style that sit outside the token
/// set (Millennium shell spec 3.3). Widgets use these names, never
/// literals.
abstract final class MillenniumColors {
  /// Task-pane links, 5.5:1 on [paneBody].
  static const link = Color(0xff1c50b0);
  static const paneTop = Color(0xff7ba2e7);
  static const paneBottom = Color(0xff6375d6);
  static const paneBody = Color(0xffd6dff7);

  /// The light end of an ordinary task-group header.
  static const groupHeaderEnd = Color(0xffc6d3f7);

  /// The light end of the special task-group header.
  static const specialHeaderEnd = Color(0xff2a6ee8);

  /// The active property-sheet tab's top edge.
  static const tabAccent = Color(0xffffc83c);

  /// The sorted column's bottom edge. Decorative: the ▴ / ▾ beside the
  /// column name says the order.
  static const sortAccent = Color(0xfff9b119);
  static const keyLine = Color(0xff003c74);
  static const fieldLine = Color(0xff7f9db9);

  /// The property-sheet page.
  static const page = Color(0xfffcfcfe);
  static const groupLine = Color(0xffd0d0bf);
  static const tabLine = Color(0xff919b9c);
  static const progress = Color(0xff2fbf2f);

  /// The pale rule under a details-list group row.
  static const groupRowRule = Color(0xffa0b8e8);

  /// Caption bars of dialogs and tiles: top, then [LifeOSTokens.head],
  /// then [captionBottom].
  static const captionTop = Color(0xff0a5fe8);
  static const captionBottom = Color(0xff003cb8);
  static const closeTop = Color(0xffe87c5a);
  static const closeBottom = Color(0xffc1300f);

  /// The default push button's inner double ring.
  static const defaultRingOuter = Color(0xff6c9cec);
  static const defaultRingInner = Color(0xffb9d1fa);

  /// The hovered push button's warm inner edge.
  static const hotRingOuter = Color(0xfff9b119);
  static const hotRingInner = Color(0xffffe7a2);

  /// The push button face's lower stop.
  static const keyFaceLow = Color(0xffd6d0c5);
  static const comboArrowTop = Color(0xffe6eeff);
  static const comboArrowBottom = Color(0xffb9cdf5);
  static const comboArrowInk = Color(0xff4d6185);

  /// The dark edge of a sunken panel.
  static const sunkenEdge = Color(0xffa0a0a0);
  static const orbGreenLight = Color(0xffa6e88a);
  static const orbGreen = Color(0xff2f9a1f);
  static const orbGreenEdge = Color(0xff23741a);
  static const orbOrangeLight = Color(0xffffd08a);
  static const orbOrange = Color(0xffe0700f);
  static const orbOrangeEdge = Color(0xffb3530a);
  static const orbGreyLight = Color(0xffdddddd);
  static const orbGrey = Color(0xff9a9a9a);
  static const orbGreyEdge = Color(0xff888888);
  static const orbGlyph = Color(0xffffffff);

  /// A transparent edge that keeps a flat key the same size as a raised one.
  static const clear = Color(0x00000000);
  static const infoGlyph = Color(0xff215dc6);
  static const warningGlyph = Color(0xfff2b01e);
}

/// LifeOS type (Millennium shell spec 3.4): Noto Sans throughout, tabular
/// figures for numbers. Sizes scale with the platform text scale.
const lifeOSTypography = LifeOSTypography(
  title: TextStyle(
    fontFamily: 'NotoSans',
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w700,
  ),
  label: TextStyle(
    fontFamily: 'NotoSans',
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
  ),
  body: TextStyle(
    fontFamily: 'NotoSans',
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  ),
  small: TextStyle(
    fontFamily: 'NotoSans',
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
  ),
  figure: TextStyle(
    fontFamily: 'NotoSans',
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
  counter: TextStyle(
    fontFamily: 'NotoSans',
    fontSize: 20,
    height: 22 / 20,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
);

/// How LifeOS-owned controls are painted.
final class LifeOSPainters {
  const LifeOSPainters();

  static const _radius = BorderRadius.all(Radius.circular(3));

  /// A push button (spec 5.1), or a flat toolbar key that shows a raised
  /// face only when hovered, focused or pressed. No state changes a key's
  /// size.
  KeySurface key(LifeOSTokens tokens, KeyKind kind, KeyState state) {
    if (!state.enabled) {
      return KeySurface(
        decoration: BoxDecoration(
          color: kind == KeyKind.toolbar ? null : tokens.chrome,
          borderRadius: _radius,
          border: Border.all(
            color: kind == KeyKind.toolbar
                ? MillenniumColors.clear
                : tokens.chromeLine,
          ),
        ),
        ink: tokens.muted,
      );
    }
    if (kind == KeyKind.toolbar) {
      final raised = state.hovered || state.focused || state.pressed;
      return KeySurface(
        decoration: BoxDecoration(
          gradient: raised
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: state.pressed
                      ? [tokens.chrome, tokens.paper]
                      : [tokens.paper, tokens.chrome],
                )
              : null,
          borderRadius: _radius,
          border: Border.all(
            color: raised ? tokens.chromeLine : MillenniumColors.clear,
          ),
        ),
        ink: tokens.ink,
      );
    }
    return KeySurface(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: state.pressed
              ? [MillenniumColors.keyFaceLow, tokens.chrome, tokens.paper]
              : [tokens.paper, tokens.chrome, MillenniumColors.keyFaceLow],
          stops: const [0, 0.85, 1],
        ),
        borderRadius: _radius,
        border: Border.all(color: MillenniumColors.keyLine),
      ),
      ink: tokens.ink,
      rings: state.hovered && !state.pressed
          ? (MillenniumColors.hotRingOuter, MillenniumColors.hotRingInner)
          : kind == KeyKind.primary
          ? (MillenniumColors.defaultRingOuter, MillenniumColors.defaultRingInner)
          : null,
    );
  }

  BoxDecoration areaMarker(LifeOSTokens tokens, LifeOSArea area) {
    final fill = tokens.areaKeys[area]!.fill;
    return BoxDecoration(
      borderRadius: _radius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(fill, tokens.paper, 0.35)!, fill, fill],
        stops: const [0, 0.5, 1],
      ),
    );
  }

  BoxDecoration countBadge(LifeOSTokens tokens) => BoxDecoration(
    color: tokens.runInk,
    borderRadius: const BorderRadius.all(Radius.circular(8)),
  );

  Color countBadgeInk(LifeOSTokens tokens) => tokens.headInk;

  Decoration focusRing(LifeOSTokens tokens) =>
      DottedFocusRectangle(color: tokens.focus);

  Decoration toolbar(LifeOSTokens tokens) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [tokens.paper, tokens.chrome],
    ),
    border: Border(
      top: BorderSide(color: tokens.paper),
      bottom: BorderSide(color: tokens.chromeLine),
    ),
  );

  /// The dotted cell cursor: white on a selected (blue) row, ink elsewhere.
  Decoration cellCursor(LifeOSTokens tokens, {required bool onSelection}) =>
      DottedFocusRectangle(
        color: onSelection ? tokens.selInk : tokens.focus,
        inset: 1.5,
      );
}

/// Two 1-pixel rings painted just inside a key's outline: the default
/// key's blue double ring or the hovered key's warm edge.
final class InsetRings extends Decoration {
  const InsetRings(this.outer, this.inner);

  final Color outer;
  final Color inner;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _InsetRingsPainter(outer, inner);

  @override
  bool operator ==(Object other) =>
      other is InsetRings && other.outer == outer && other.inner == inner;

  @override
  int get hashCode => Object.hash(outer, inner);
}

final class _InsetRingsPainter extends BoxPainter {
  _InsetRingsPainter(this.outer, this.inner);

  final Color outer;
  final Color inner;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(2)),
        stroke..color = outer,
      )
      ..drawRect(rect.deflate(2.5), stroke..color = inner);
  }
}

/// The era's dotted focus rectangle, drawn [inset] pixels inside the box.
final class DottedFocusRectangle extends Decoration {
  const DottedFocusRectangle({required this.color, this.inset = 2.5});

  final Color color;
  final double inset;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DottedPainter(color, inset);

  @override
  bool operator ==(Object other) =>
      other is DottedFocusRectangle &&
      other.color == color &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(color, inset);
}

final class _DottedPainter extends BoxPainter {
  _DottedPainter(this.color, this.inset);

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = (offset & size).deflate(inset);
    final paint = Paint()..color = color;
    void dots(Offset from, Offset to) {
      final length = (to - from).distance;
      if (length == 0) return;
      final step = (to - from) / length;
      for (var at = 0.0; at < length; at += 2) {
        canvas.drawRect(
          Rect.fromLTWH(from.dx + step.dx * at, from.dy + step.dy * at, 1, 1),
          paint,
        );
      }
    }

    dots(rect.topLeft, rect.topRight);
    dots(rect.topRight, rect.bottomRight);
    dots(rect.bottomRight, rect.bottomLeft);
    dots(rect.bottomLeft, rect.topLeft);
  }
}
```

- [ ] **Step 4: Collapse the skin scope**

In `lib/shared/workbench/lifeos_skin.dart`, keep `LifeOSTypography`, `KeyState`, and replace everything from `enum AreaMarkerStyle` to the end of the file except `LifeOSTypography`/`KeyState` with:

```dart
/// The kinds of key LifeOS paints: [primary] is the default push button,
/// [secondary] an ordinary push button, [small] a compact push button and
/// [toolbar] a flat key that rises when hovered, focused or pressed.
enum KeyKind { primary, secondary, small, toolbar }

/// What one key looks like: its face, text colour and optional inner rings.
@immutable
final class KeySurface {
  const KeySurface({required this.decoration, required this.ink, this.rings});

  final BoxDecoration decoration;
  final Color ink;

  /// (outer, inner) 1-pixel rings inside the outline, or none.
  final (Color, Color)? rings;
}

/// The LifeOS style: tokens, typography and painters.
@immutable
final class LifeOSSkinData {
  const LifeOSSkinData({
    required this.tokens,
    required this.typography,
    required this.painters,
  });

  /// The one LifeOS style.
  static const standard = LifeOSSkinData(
    tokens: LifeOSTokens.millennium,
    typography: lifeOSTypography,
    painters: LifeOSPainters(),
  );

  final LifeOSTokens tokens;
  final LifeOSTypography typography;
  final LifeOSPainters painters;
}

/// Provides the LifeOS style to every LifeOS-owned widget below it.
final class LifeOSSkinScope extends StatelessWidget {
  const LifeOSSkinScope({required this.child, super.key});

  final Widget child;

  static LifeOSSkinData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedLifeOSSkin>();
    assert(scope != null, 'No LifeOSSkinScope above this widget.');
    return scope!.data;
  }

  @override
  Widget build(BuildContext context) =>
      _InheritedLifeOSSkin(data: LifeOSSkinData.standard, child: child);
}

final class _InheritedLifeOSSkin extends InheritedWidget {
  const _InheritedLifeOSSkin({required this.data, required super.child});

  final LifeOSSkinData data;

  @override
  bool updateShouldNotify(_InheritedLifeOSSkin oldWidget) =>
      data != oldWidget.data;
}
```

Add `bool focused` to `KeyState` (constructor `this.focused = false`, field `final bool focused;`). Replace the file's imports with `import 'package:flutter/widgets.dart';`, `import 'lifeos_tokens.dart';` and `import 'millennium_style.dart';`. Update the `LifeOSTypography.label` doc comment to "Column headers and group-box legends." Delete `lib/shared/workbench/skins/millennium_skin.dart` and the empty `skins/` directory.

- [ ] **Step 5: Single Material theme and app root**

In `lib/shared/workbench/lifeos_theme.dart`:
- In `lifeOSThemeFor`, delete `final dark = …` and set `brightness: Brightness.light` in both the `ColorScheme` and `ThemeData`.
- Replace the key `backgroundBuilder` body with:

```dart
    backgroundBuilder: (context, states, child) {
      final surface = skin.painters.key(
        t,
        kind,
        KeyState(
          enabled: !states.contains(WidgetState.disabled),
          pressed: states.contains(WidgetState.pressed),
          hovered: states.contains(WidgetState.hovered),
          focused: states.contains(WidgetState.focused),
        ),
      );
      final rings = surface.rings;
      return DecoratedBox(
        decoration: surface.decoration,
        position: DecorationPosition.background,
        child: rings == null
            ? child
            : DecoratedBox(
                decoration: InsetRings(rings.$1, rings.$2),
                position: DecorationPosition.foreground,
                child: child,
              ),
      );
    },
```

- Set `minimumSize: const WidgetStatePropertyAll(Size(24, 24))` and `padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12))`; keep `tapTargetSize: MaterialTapTargetSize.shrinkWrap`; change the key `textStyle` to `WidgetStatePropertyAll(type.body)` (no bold: era push buttons are not bold).
- Replace `buildLifeOSTheme` with:

```dart
/// The LifeOS Material theme without a skin scope, for the app's base theme
/// and for widget tests that pump a form on its own.
ThemeData buildLifeOSTheme() => lifeOSThemeFor(LifeOSSkinData.standard);
```

- Add `import 'millennium_style.dart';`.

In `lib/app/lifeos_app.dart`:
- Delete the `preferences` field and parameter, `_appearance`, `_restoreAppearance`, `_saveAppearance`, the `_restoreAppearance()` call, the appearance lines in `dispose`, the `LifeOSAppearanceScope` wrapper, `highContrastTheme:`, and the imports of `preference_repository.dart` and `lifeos_tokens.dart`.
- Set `theme: buildLifeOSTheme(),`.

In `lib/main.dart` delete `preferences: work?.preferences,`. In `lib/app/production_work_providers.dart` delete the `preferences` constructor argument, field, initializer (`preferences: PreferenceRepository(database),`) and the import. Delete `lib/core/preferences/preference_repository.dart`.

In `lib/shared/shell/menu_bar.dart` delete `appearance`, `appearanceItem` and the `menu('Appearance', …)` entry.

In `lib/shared/shell/book_tree.dart:92` replace `skin.painters.treeBackground(tokens)` with `tokens.paper` (Task 6 restyles the tree).

Fix the remaining references the analyzer reports (`painters.segment`, `painters.segmentInk`, `painters.statusLine`, `cellCursor(tokens)`): in this task make them compile with minimal stand-ins so the app still runs —
- `office_controls.dart` `_Segment`: `decoration: BoxDecoration(color: widget.selected ? skin.tokens.paper : skin.tokens.chrome, border: Border.all(color: skin.tokens.chromeLine))`, ink `skin.tokens.ink` (replaced in Task 4).
- `status_line.dart`: fill `BoxDecoration(color: tokens.chrome)`, ink `tokens.ink`, alert `tokens.negative`, indicator `tokens.signal`, divider `tokens.chromeLine` read straight from tokens (replaced in Task 5).
- `data_register.dart`: `foregroundDecoration: cursorColumn == column.key ? skin.painters.cellCursor(tokens, onSelection: selected) : null` (Task 7 finishes the list).
- `office_controls.dart` `KeyButton`: `KeySurface` no longer has `edgeColor`, `edgeWidth`, `topInset` or `radius`. Replace the two nested containers (`key-edge` and `key-face`) with one `Container(key: const ValueKey('key-face'), constraints: BoxConstraints(minHeight: small ? 22 : 24, minWidth: 24), padding: EdgeInsets.symmetric(horizontal: small ? 9 : 10), decoration: surface.decoration, child: <the existing Row>)` (Task 3 adds rings and toolbar keys). Delete the test "pressing narrows the bottom edge and lowers the face" from `office_controls_test.dart` (Task 3 replaces it).

- [ ] **Step 6: Tests for the single style and the ignored old preference**

Delete `test/shared/workbench/skins_test.dart`. In `test/shared/workbench/office_controls_test.dart` delete the appearance group (the three tests "system appearance follows the platform", "a pinned appearance overrides the platform brightness", "the platform high-contrast setting wins over day or night") and any helper only they use.

Replace `test/app/lifeos_app_test.dart` with:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

void main() {
  testWidgets('the app paints in the one LifeOS style', (tester) async {
    final router = createAppRouter(initialLocation: '/system/files');
    addTearDown(router.dispose);
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Backup and export').first);
    expect(LifeOSSkinScope.of(context).tokens, same(LifeOSTokens.millennium));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('an appearance saved by an older build is ignored', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(
      () => database.customStatement(
        "INSERT INTO preferences (key, value) VALUES ('appearance', 'night')",
      ),
    );
    final router = createAppRouter(initialLocation: '/system/files');
    addTearDown(router.dispose);
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Backup and export').first);
    expect(LifeOSSkinScope.of(context).tokens, same(LifeOSTokens.millennium));
  });
}
```

(If `/system/files` needs providers in a bare pump, wrap `LifeOsApp` the way `test/app/shell_routes_test.dart` does and reuse its setup; the assertion stays the same.)

Fix every call site of the removed parameter:

```bash
grep -rl "buildLifeOSTheme(highContrast: false)" test lib | xargs sed -i 's/buildLifeOSTheme(highContrast: false)/buildLifeOSTheme()/g'
grep -rn "buildLifeOSTheme(highContrast" test lib
```

Expected: the second grep prints nothing.

In `test/goldens/shell_goldens_test.dart`: replace the `appearances` map and the loop over it with a single style; drop the View › Appearance taps; name files `shell_${size.width.round()}x${size.height.round()}`. Delete the eight old `test/goldens/shell_*_*.png` files (`git rm`).

- [ ] **Step 7: Run tests**

Run: `$F/flutter test test/shared/workbench test/app`
Expected: PASS.

Run: `$F/flutter test --update-goldens test/goldens && $F/flutter test`
Expected: `All tests passed!` Any remaining failure is a test still naming a removed type; fix the reference (do not reintroduce the type).

- [ ] **Step 8: Analyze, format, commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "refactor: keep one LifeOS style and drop the appearance setting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Push buttons, toolbar keys and orbs

Spec §5.1.

**Files:**
- Modify: `lib/shared/workbench/office_controls.dart` (`KeyButton`)
- Create: `lib/shared/workbench/era_controls.dart` (`Orb`, `OrbGlyph`, `OrbTone`)
- Test: `test/shared/workbench/office_controls_test.dart`, `test/shared/workbench/era_controls_test.dart` (new)

**Interfaces:**
- Consumes: `LifeOSPainters.key`, `KeySurface`, `KeyKind.toolbar`, `KeyState.focused`, `InsetRings` (Task 2).
- Produces: `KeyButton({required String label, required VoidCallback? onPressed, KeyKind kind = KeyKind.secondary, Widget? leading, Widget? trailing, String? semanticLabel})`; `Orb({required OrbGlyph glyph, required OrbTone tone, double size = 20})`; `enum OrbGlyph { back, forward, add }`; `enum OrbTone { green, orange, grey }`.

- [ ] **Step 1: Write failing tests**

In `test/shared/workbench/office_controls_test.dart` replace "pressing narrows the bottom edge and lowers the face" and "primary keys use the action fill and ink" with:

```dart
    testWidgets('pressing changes the face but never the size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(KeyButton(label: 'Save', onPressed: () {})),
      );
      final before = tester.getSize(find.byKey(const ValueKey('key-face')));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Save')),
      );
      await tester.pump();
      expect(tester.getSize(find.byKey(const ValueKey('key-face'))), before);
      await gesture.up();
    });

    testWidgets('push buttons are at least 24 high and 24 wide', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(KeyButton(label: 'x', onPressed: () {})));
      final size = tester.getSize(find.byKey(const ValueKey('key-face')));
      expect(size.height, greaterThanOrEqualTo(24));
      expect(size.width, greaterThanOrEqualTo(24));
    });

    testWidgets('the default key carries the blue double ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          KeyButton(label: 'Save', kind: KeyKind.primary, onPressed: () {}),
        ),
      );
      final face = tester.widget<Container>(
        find.byKey(const ValueKey('key-face')),
      );
      expect(
        face.foregroundDecoration,
        const InsetRings(
          MillenniumColors.defaultRingOuter,
          MillenniumColors.defaultRingInner,
        ),
      );
    });

    testWidgets('a toolbar key is flat until hovered', (tester) async {
      await tester.pumpWidget(
        _harness(
          KeyButton(label: 'Back', kind: KeyKind.toolbar, onPressed: () {}),
        ),
      );
      BoxDecoration face() =>
          tester
                  .widget<Container>(find.byKey(const ValueKey('key-face')))
                  .decoration!
              as BoxDecoration;
      expect(face().gradient, isNull);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Back')));
      await tester.pump();
      expect(face().gradient, isNotNull);
      await mouse.removePointer();
    });
```

(`_harness` is the file's existing wrapper; if it is named differently, use that name. Add imports for `package:flutter/gestures.dart` and `package:lifeos/shared/workbench/millennium_style.dart`.)

Create `test/shared/workbench/era_controls_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_controls.dart';

void main() {
  testWidgets('orbs are decorative and sized as asked', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Orb(glyph: OrbGlyph.back, tone: OrbTone.green, size: 20),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Orb)), const Size(20, 20));
    final semantics = tester.getSemantics(find.byType(Orb));
    expect(semantics.label, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/shared/workbench/office_controls_test.dart test/shared/workbench/era_controls_test.dart`
Expected: FAIL (`InsetRings` not applied, `era_controls.dart` missing).

- [ ] **Step 3: Implement KeyButton and Orb**

In `office_controls.dart` `_KeyButtonState.build`, replace the `surface` and `face` construction with:

```dart
    final kind = widget.kind;
    final surface = skin.painters.key(
      skin.tokens,
      kind,
      KeyState(
        enabled: _enabled,
        pressed: _pressed,
        hovered: _hovered,
        focused: _focused,
      ),
    );
    final rings = surface.rings;
    final face = Container(
      key: const ValueKey('key-face'),
      constraints: BoxConstraints(
        minHeight: kind == KeyKind.toolbar ? 30 : 24,
        minWidth: 24,
      ),
      padding: EdgeInsets.symmetric(horizontal: kind == KeyKind.small ? 7 : 10),
      decoration: surface.decoration,
      foregroundDecoration: rings == null
          ? null
          : InsetRings(rings.$1, rings.$2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading case final leading?) ...[
            leading,
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (kind == KeyKind.small
                      ? skin.typography.small
                      : skin.typography.body)
                  .copyWith(color: surface.ink),
            ),
          ),
          if (widget.trailing case final trailing?) ...[
            const SizedBox(width: 4),
            trailing,
          ],
        ],
      ),
    );
```

Add the `trailing` field (`final Widget? trailing;`, constructor `this.trailing`). The focus ring stays `_FocusRing(visible: _focused, …)`; change its inset so the dotted rectangle sits inside the key: in `_FocusRing.build` replace the `Positioned(left: -4, …)` values with `left: 0, top: 0, right: 0, bottom: 0` (the `DottedFocusRectangle` already insets 2.5). Add `import 'millennium_style.dart';`.

Create `lib/shared/workbench/era_controls.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'millennium_style.dart';

enum OrbGlyph { back, forward, add }

enum OrbTone { green, orange, grey }

/// A painted glossy orb with a white glyph, as on the era's toolbar keys.
/// Decorative: the key beside it carries the words.
final class Orb extends StatelessWidget {
  const Orb({
    required this.glyph,
    required this.tone,
    this.size = 20,
    super.key,
  });

  final OrbGlyph glyph;
  final OrbTone tone;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _OrbPainter(glyph, tone),
    ),
  );
}

final class _OrbPainter extends CustomPainter {
  const _OrbPainter(this.glyph, this.tone);

  final OrbGlyph glyph;
  final OrbTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final (light, fill, edge) = switch (tone) {
      OrbTone.green => (
        MillenniumColors.orbGreenLight,
        MillenniumColors.orbGreen,
        MillenniumColors.orbGreenEdge,
      ),
      OrbTone.orange => (
        MillenniumColors.orbOrangeLight,
        MillenniumColors.orbOrange,
        MillenniumColors.orbOrangeEdge,
      ),
      OrbTone.grey => (
        MillenniumColors.orbGreyLight,
        MillenniumColors.orbGrey,
        MillenniumColors.orbGreyEdge,
      ),
    };
    final rect = Offset.zero & size;
    final circle = rect.deflate(0.5);
    canvas
      ..drawOval(
        circle,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [light, fill],
            stops: const [0, 0.7],
          ).createShader(rect),
      )
      ..drawOval(
        circle,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = edge,
      );
    final white = Paint()..color = MillenniumColors.orbGlyph;
    final s = size.width;
    switch (glyph) {
      case OrbGlyph.back || OrbGlyph.forward:
        final left = glyph == OrbGlyph.back;
        final path = Path()
          ..moveTo(left ? s * 0.25 : s * 0.75, s * 0.5)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.25)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.4)
          ..lineTo(left ? s * 0.75 : s * 0.25, s * 0.4)
          ..lineTo(left ? s * 0.75 : s * 0.25, s * 0.6)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.6)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.75)
          ..close();
        canvas.drawPath(path, white);
      case OrbGlyph.add:
        canvas
          ..drawRect(
            Rect.fromLTRB(s * 0.42, s * 0.24, s * 0.58, s * 0.76),
            white,
          )
          ..drawRect(
            Rect.fromLTRB(s * 0.24, s * 0.42, s * 0.76, s * 0.58),
            white,
          );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.tone != tone;
}
```

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/shared/workbench`
Expected: PASS. Then `$F/flutter test` — fix any test that asserted the old 2-pixel edge (`key-edge` key no longer exists; assert on `key-face` instead).

- [ ] **Step 5: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: paint keys as era push buttons and add toolbar orbs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Group boxes, tabs, combo faces, dialogs, information panel and Material controls

Spec §5.3, §5.5 (tabs, group boxes), §5.6, §5.9, §5.10.

**Files:**
- Modify: `lib/shared/workbench/era_controls.dart` (add `EraComboFace`, `GroupBox`, `FormFooter`)
- Modify: `lib/shared/workbench/office_controls.dart` (replace `SegmentedTabs` with `PropertySheetTabs`; `menuRowHeight = 24`)
- Create: `lib/shared/workbench/era_dialog.dart`
- Modify: `lib/shared/workbench/operational_state.dart`
- Modify: `lib/shared/workbench/lifeos_theme.dart` (fields, checkbox, radio, menus, dialogs)
- Modify: `lib/features/work/presentation/record_history_panel.dart`, `lib/shared/shell/desk_view.dart` (call sites of `SegmentedTabs`)
- Modify: `lib/shared/shell/name_dialog.dart`, `lib/features/work/presentation/work_toolbar_controls.dart` (`_RangeDialog`), `lib/shared/shell/menu_bar.dart` (About)
- Test: `test/shared/workbench/era_controls_test.dart`, `test/shared/workbench/office_controls_test.dart`, `test/shared/workbench/operational_state_test.dart` (new)

**Interfaces:**
- Produces:
  - `EraComboFace({required String value, double minWidth = 60})`.
  - `GroupBox({required String legend, required Widget child, Color? background})` — `background` is what sits behind the legend (default `MillenniumColors.page`).
  - `FormFooter({required List<Widget> children})` — right-aligned wrapping row of keys.
  - `PropertySheetTabs({required List<String> labels, required int selectedIndex, required ValueChanged<int> onSelected})`.
  - `EraDialog({required String title, required Widget body, required List<Widget> actions, VoidCallback? onClose})`.
  - `const menuRowHeight = 24.0`.

- [ ] **Step 1: Write failing tests**

Append to `test/shared/workbench/era_controls_test.dart`:

```dart
  testWidgets('a group box announces its legend and shows its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scoped(const GroupBox(legend: 'Shift', child: Text('Date'))),
    );
    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.bySemanticsLabel('Shift'), findsOneWidget);
  });

  testWidgets('a combo face shows its value and a drop arrow', (tester) async {
    await tester.pumpWidget(_scoped(const EraComboFace(value: 'Shifts')));
    expect(find.text('Shifts'), findsOneWidget);
    expect(
      tester.getSize(find.byType(EraComboFace)).height,
      greaterThanOrEqualTo(24),
    );
  });

  testWidgets('a form footer keeps its keys at the right edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scoped(
        SizedBox(
          width: 300,
          child: FormFooter(
            children: [KeyButton(label: 'Save', onPressed: () {})],
          ),
        ),
      ),
    );
    expect(
      tester.getTopRight(find.byKey(const ValueKey('key-face'))).dx,
      closeTo(300, 1),
    );
  });
```

with a helper at the bottom of the file:

```dart
Widget _scoped(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: LifeOSSkinScope(
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);
```

and imports `package:lifeos/shared/workbench/lifeos_skin.dart`, `package:lifeos/shared/workbench/office_controls.dart`.

In `office_controls_test.dart` rename the test "segmented tabs mark the selected segment and switch" to "property-sheet tabs mark the selected tab and switch" and change `SegmentedTabs(` to `PropertySheetTabs(` in it.

Create `test/shared/workbench/operational_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/operational_state.dart';

void main() {
  for (final kind in OperationalStateKind.values) {
    testWidgets('$kind keeps its words and uses no Material icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: OperationalState(
                kind: kind,
                title: 'Work record unavailable',
                message: 'The requested record is not available.',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Work record unavailable'), findsOneWidget);
      expect(
        find.text('The requested record is not available.'),
        findsOneWidget,
      );
      expect(find.byType(Icon), findsNothing);
    });
  }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/shared/workbench`
Expected: FAIL (`GroupBox`, `EraComboFace`, `FormFooter`, `PropertySheetTabs` undefined; `Icon` found).

- [ ] **Step 3: Implement the controls**

Append to `lib/shared/workbench/era_controls.dart` (add `import 'lifeos_skin.dart';`):

```dart
/// What a dropdown looks like closed: a white field with a blue arrow
/// button (spec 5.3). The surrounding menu button supplies the behaviour.
final class EraComboFace extends StatelessWidget {
  const EraComboFace({required this.value, this.minWidth = 60, super.key});

  final String value;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: 24, minWidth: minWidth),
      decoration: BoxDecoration(
        color: skin.tokens.paper,
        border: Border.all(color: MillenniumColors.fieldLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: skin.typography.body.copyWith(color: skin.tokens.ink),
              ),
            ),
          ),
          Container(
            width: 17,
            constraints: const BoxConstraints(minHeight: 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MillenniumColors.comboArrowTop,
                  MillenniumColors.comboArrowBottom,
                ],
              ),
            ),
            child: const CustomPaint(painter: _DownArrow()),
          ),
        ],
      ),
    );
  }
}

final class _DownArrow extends CustomPainter {
  const _DownArrow();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 4, c.dy - 2)
        ..lineTo(c.dx + 4, c.dy - 2)
        ..lineTo(c.dx, c.dy + 2)
        ..close(),
      Paint()..color = MillenniumColors.comboArrowInk,
    );
  }

  @override
  bool shouldRepaint(_DownArrow oldDelegate) => false;
}

/// A titled frame around related content, its legend in Head blue
/// (spec 5.5).
final class GroupBox extends StatelessWidget {
  const GroupBox({
    required this.legend,
    required this.child,
    this.background,
    super.key,
  });

  final String legend;
  final Widget child;

  /// The colour behind the legend: the surface the box sits on.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: legend,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 7),
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              decoration: BoxDecoration(
                border: Border.all(color: MillenniumColors.groupLine),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
            Positioned(
              left: 8,
              top: 0,
              child: ExcludeSemantics(
                child: Container(
                  color: background ?? MillenniumColors.page,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    legend,
                    style: skin.typography.label.copyWith(
                      color: skin.tokens.head,
                    ),
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

/// A form's actions, right-aligned and wrapping when narrow.
final class FormFooter extends StatelessWidget {
  const FormFooter({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 6,
        children: children,
      ),
    ),
  );
}
```

In `office_controls.dart`, set `const menuRowHeight = 24.0;` and replace `SegmentedTabs` and `_Segment`/`_SegmentState` with:

```dart
/// Property-sheet tabs (spec 5.5): inactive tabs are white-to-face, the
/// active tab is joined to the page with a warm top edge. Tabs hug their
/// labels and sit on a line the page continues.
final class PropertySheetTabs extends StatelessWidget {
  const PropertySheetTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: MillenniumColors.tabLine)),
    ),
    child: Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (var index = 0; index < labels.length; index++)
            _Tab(
              label: labels[index],
              selected: index == selectedIndex,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    ),
  );
}

final class _Tab extends StatefulWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

final class _TabState extends State<_Tab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final selected = widget.selected;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: ExcludeSemantics(
              child: Container(
                margin: EdgeInsets.only(top: selected ? 0 : 2, right: 1),
                constraints: BoxConstraints(minHeight: selected ? 26 : 24),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected ? MillenniumColors.page : null,
                  gradient: selected
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [tokens.paper, tokens.chrome],
                        ),
                  border: Border(
                    top: BorderSide(
                      color: selected
                          ? MillenniumColors.tabAccent
                          : MillenniumColors.tabLine,
                      width: selected ? 2 : 1,
                    ),
                    left: const BorderSide(color: MillenniumColors.tabLine),
                    right: const BorderSide(color: MillenniumColors.tabLine),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
                foregroundDecoration: _focused
                    ? DottedFocusRectangle(color: tokens.focus)
                    : null,
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skin.typography.body.copyWith(color: tokens.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Replace `SegmentedTabs(` with `PropertySheetTabs(` in `record_history_panel.dart` and `desk_view.dart`; change their labels: in `record_history_panel.dart` `['Details', 'History']` becomes `['General', 'History']`. Update tests that tap `'Details'` (inspector tab) to `'General'`:

```bash
grep -rn "'Details'" test | grep -v "Details group"
```

and change each inspector-tab finder to `'General'`.

Create `lib/shared/workbench/era_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'era_controls.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// An in-app dialog in the era's shape (spec 5.9): a blue caption with the
/// title and a red close key, a face-coloured body and keys bottom-right.
final class EraDialog extends StatelessWidget {
  const EraDialog({
    required this.title,
    required this.body,
    required this.actions,
    this.onClose,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// The close key; defaults to popping the dialog.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Dialog(
      backgroundColor: tokens.chrome,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: MillenniumColors.keyLine),
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CaptionBar(
              title: title,
              onClose: onClose ?? () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DefaultTextStyle.merge(
                style: skin.typography.body.copyWith(color: tokens.ink),
                child: body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FormFooter(children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

/// A blue gradient caption with a title and a red close key, shared by
/// dialogs and desk tiles.
final class CaptionBar extends StatelessWidget {
  const CaptionBar({
    required this.title,
    required this.onClose,
    this.leading,
    this.trailing = const [],
    this.closeLabel,
    super.key,
  });

  final String title;
  final VoidCallback? onClose;
  final Widget? leading;
  final List<Widget> trailing;

  /// Announced for the close key; defaults to "Close [title]".
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MillenniumColors.captionTop,
            tokens.head,
            MillenniumColors.captionBottom,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Row(
        children: [
          if (leading case final leading?) ...[
            leading,
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: skin.typography.body.copyWith(
                  color: tokens.headInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ...trailing,
          if (onClose case final close?)
            _CloseKey(label: closeLabel ?? 'Close $title', onPressed: close),
        ],
      ),
    );
  }
}

final class _CloseKey extends StatelessWidget {
  const _CloseKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              border: Border.all(color: LifeOSSkinScope.of(context).tokens.paper),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MillenniumColors.closeTop,
                  MillenniumColors.closeBottom,
                ],
              ),
            ),
            child: CustomPaint(
              painter: _Cross(LifeOSSkinScope.of(context).tokens.headInk),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _Cross extends CustomPainter {
  const _Cross(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    final inset = size.width * 0.3;
    canvas
      ..drawLine(
        Offset(inset, inset),
        Offset(size.width - inset, size.height - inset),
        paint,
      )
      ..drawLine(
        Offset(size.width - inset, inset),
        Offset(inset, size.height - inset),
        paint,
      );
  }

  @override
  bool shouldRepaint(_Cross oldDelegate) => oldDelegate.ink != ink;
}
```

Rewrite `lib/shared/workbench/operational_state.dart` `build` so it uses no `Icon`:

```dart
  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final warning = switch (kind) {
      OperationalStateKind.unavailable ||
      OperationalStateKind.invalidScope ||
      OperationalStateKind.conflict ||
      OperationalStateKind.uncertain => true,
      OperationalStateKind.loading || OperationalStateKind.empty => false,
    };
    return Semantics(
      container: true,
      liveRegion: kind == OperationalStateKind.loading,
      label: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Glyph(warning: warning),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: skin.typography.body.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: skin.typography.body.copyWith(color: tokens.ink),
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 12),
                        action!,
                      ],
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

/// A painted ⓘ in a blue disc, or ! in an amber triangle.
final class _Glyph extends StatelessWidget {
  const _Glyph({required this.warning});

  final bool warning;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CustomPaint(
          painter: _GlyphPainter(warning: warning, ink: skin.tokens.paper),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: warning ? 8 : 0),
              child: Text(
                warning ? '!' : 'i',
                style: skin.typography.title.copyWith(
                  color: warning ? skin.tokens.ink : skin.tokens.paper,
                  fontFamily: 'NotoSans',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.warning, required this.ink});

  final bool warning;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (warning) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 1)
          ..lineTo(size.width - 1, size.height - 2)
          ..lineTo(1, size.height - 2)
          ..close(),
        Paint()..color = MillenniumColors.warningGlyph,
      );
    } else {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width / 2 - 1,
        Paint()..color = MillenniumColors.infoGlyph,
      );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.warning != warning || oldDelegate.ink != ink;
}
```

Replace the file's imports with `package:flutter/widgets.dart`, `lifeos_skin.dart`, `millennium_style.dart`.

In `lib/shared/workbench/lifeos_theme.dart`:
- `inputDecorationTheme`: `contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 6)`, `border`/`enabledBorder: outline(MillenniumColors.fieldLine)`, `focusedBorder: outline(MillenniumColors.keyLine)` (width 1), `disabledBorder: outline(t.chromeLine)`, `errorBorder`/`focusedErrorBorder: outline(t.negative)`, `fillColor: t.paper`; labels stay above the field (`floatingLabelBehavior: FloatingLabelBehavior.always`).
- `checkboxTheme`: `fillColor: WidgetStatePropertyAll(t.paper)`, `checkColor: const WidgetStatePropertyAll(MillenniumColors.orbGreen)`, `side: const BorderSide(color: MillenniumColors.fieldLine)`, `shape: const RoundedRectangleBorder()`.
- `radioTheme`: `fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? MillenniumColors.orbGreen : MillenniumColors.fieldLine)`.
- `popupMenuTheme` and `menuTheme`: `shape: RoundedRectangleBorder(side: BorderSide(color: t.muted))` (square), and the selected/hovered item uses `t.selWash`/`t.selInk` as the menu bar already does.
- `dialogTheme`: `backgroundColor: t.chrome`, `shape: const RoundedRectangleBorder(side: BorderSide(color: MillenniumColors.keyLine))`.

Convert dialogs to `EraDialog`:
- `lib/shared/shell/name_dialog.dart`: the `AlertDialog(title: …, content: …, actions: …)` becomes `EraDialog(title: title, body: <the content widget>, actions: [<cancel>, <confirm>])` with the confirm key `KeyButton(label: action, kind: KeyKind.primary, onPressed: …)` and cancel `KeyButton(label: 'Cancel', onPressed: …)`; keep the existing callbacks and keys (`ValueKey`s) on those keys. If a test finds `widgetWithText(FilledButton, 'Save'|'Rename')` (see `test/integration/saved_views_flow_test.dart:84,128`), change it to `widgetWithText(KeyButton, …)` and import `office_controls.dart`.
- `_RangeDialog` in `work_toolbar_controls.dart`: same conversion, title unchanged.
- `menu_bar.dart` About: replace `showAboutDialog(…)` with

```dart
() => showDialog<void>(
  context: context,
  builder: (context) => EraDialog(
    title: 'About LifeOS',
    body: const Text(
      'LifeOS\nPrivate, local-first records. Nothing leaves this computer.',
    ),
    actions: [
      KeyButton(
        label: 'Licenses',
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'LifeOS',
        ),
      ),
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  ),
),
```

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/shared test/features test/integration test/app`
Expected: PASS after finder updates ('Details' tab → 'General', FilledButton → KeyButton in name dialogs). Then `$F/flutter test --update-goldens test/goldens` and look at `test/goldens/shell_1280x800.png`.

- [ ] **Step 5: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: add group boxes, property-sheet tabs, combo faces and era dialogs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Status bar and menu bar

Spec §4 items 1 and 5, §5.11.

**Files:**
- Modify: `lib/shared/shell/status_line.dart`, `lib/shared/shell/menu_bar.dart`
- Test: `test/shared/shell/status_line_test.dart` (new)

**Interfaces:**
- Consumes: `MillenniumColors.sunkenEdge`.
- Produces: `StatusLine` unchanged API (`StatusSnapshot`), painted as sunken panels at 22 px.

- [ ] **Step 1: Write the failing test**

Create `test/shared/shell/status_line_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/status_line.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  Widget host(StatusSnapshot snapshot) => Directionality(
    textDirection: TextDirection.ltr,
    child: LifeOSSkinScope(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 900, child: StatusLine(snapshot: snapshot)),
      ),
    ),
  );

  testWidgets('every fact sits in its own sunken panel at 22 px', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        StatusSnapshot(
          runningShift: RunningShiftStatus(
            label: 'Shift running since 07:02',
            onOpen: () {},
          ),
          openDrafts: 2,
        ),
      ),
    );
    expect(tester.getSize(find.byType(StatusLine)).height, 22);
    expect(find.text('Shift running since 07:02'), findsOneWidget);
    expect(find.text('2 drafts'), findsOneWidget);
    expect(find.text('Local database'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-panel')), findsNWidgets(3));
  });

  testWidgets('an uncertain save is written, not only coloured', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const StatusSnapshot(lastSaveUncertain: true)),
    );
    expect(find.text('Last save uncertain. Reload to check'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/shared/shell/status_line_test.dart`
Expected: FAIL (height 24, no `status-panel` keys).

- [ ] **Step 3: Implement**

In `status_line.dart` replace `StatusLine.build` and `_Segment` with:

```dart
  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final style = skin.typography.small.copyWith(color: tokens.ink);
    final running = snapshot.runningShift;
    final save = snapshot.lastSaveUncertain
        ? 'Last save uncertain. Reload to check'
        : snapshot.lastSave == null
        ? 'Local database'
        : 'Local database · saved ${snapshot.lastSave}';
    return Container(
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(top: BorderSide(color: tokens.paper)),
      ),
      child: Row(
        children: [
          Expanded(
            child: running == null
                ? const SizedBox.shrink()
                : _Panel(
                    onTap: running.onOpen,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: tokens.signal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            running.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style.copyWith(color: tokens.runInk),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (snapshot.needsYou > 0)
            _Panel(
              child: Text('Needs you: ${snapshot.needsYou}', style: style),
            ),
          if (snapshot.openDrafts > 0)
            _Panel(
              child: Text(
                snapshot.openDrafts == 1
                    ? '1 draft'
                    : '${snapshot.openDrafts} drafts',
                style: style,
              ),
            ),
          _Panel(
            child: Text(
              save,
              style: snapshot.lastSaveUncertain
                  ? style.copyWith(color: tokens.negative)
                  : style,
            ),
          ),
        ],
      ),
    );
  }
}

/// A sunken status panel: dark top-left edge, white bottom-right edge.
final class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    final panel = Container(
      key: const ValueKey('status-panel'),
      margin: const EdgeInsets.only(left: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: MillenniumColors.sunkenEdge),
          left: const BorderSide(color: MillenniumColors.sunkenEdge),
          bottom: BorderSide(color: tokens.paper),
          right: BorderSide(color: tokens.paper),
        ),
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: panel),
      ),
    );
  }
}
```

Add `import '../workbench/millennium_style.dart';`. Update the class doc comment to "The sunken status bar at the bottom of the shell." The running panel is the empty first `Expanded` slot when nothing runs, so the remaining panels keep to the right.

In `menu_bar.dart`:
- Bar decoration: `gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tokens.paper, tokens.chrome])`, bottom border `tokens.chromeLine`.
- `itemStyle.minimumSize`: `Size(0, menuRowHeight)` (import `../workbench/office_controls.dart`), padding horizontal 8.
- `menuStyle` side `BorderSide(color: tokens.muted)`, shape `RoundedRectangleBorder()` (square), padding `EdgeInsets.symmetric(vertical: 2)`.
- View menu items: `'Show book tree'` → `'Show task pane'`, `'Show inspector'` → `'Show property sheet'`; delete the `'Show formula bar'` item.
- Delete `showFormulaBar` from `ShellView` (field, constructor, `copyWith`, `==`, `hashCode`). In `shell_frame.dart` drop the `if (view.showFormulaBar)` guard so the formula row is always shown until Task 9 removes it.
- Delete the shell test "the formula bar can be hidden" from `test/shared/shell/shell_frame_test.dart`.
- Update tests that tap 'Show book tree' / 'Show inspector':

```bash
grep -rln "Show book tree\|Show inspector\|Show formula bar" test lib
```

Rename the strings in each file found.

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/shared test/app test/integration`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: sunken status panels and an era menu bar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Shell frame: toolbar, Address bar, task pane and Books

Spec §4, §4.1, §5.2; behaviour changes §8 items 5–7.

**Files:**
- Create: `lib/shared/shell/address_bar.dart`, `lib/shared/shell/task_pane.dart`
- Modify: `lib/shared/shell/shell_frame.dart`, `lib/shared/shell/book_tree.dart`, `lib/shared/shell/quick_add.dart`, `lib/app/shell_host.dart`
- Test: `test/shared/shell/shell_frame_test.dart`, `test/shared/shell/book_tree_test.dart`, `test/shared/shell/task_pane_test.dart` (new), `test/shared/shell/address_bar_test.dart` (new)

**Interfaces:**
- Consumes: `KeyButton(kind: KeyKind.toolbar|small)`, `Orb`, `EraComboFace` (Tasks 3–4).
- Produces:
  - `AddressCrumb(String label, [String? route])`; `AddressBar({required List<AddressCrumb> crumbs, required ValueChanged<String> onNavigate, required VoidCallback onGo})`.
  - `TaskPane({required List<Widget> groups})`; `TaskGroup({required String title, required Widget child, bool special = false})`; `TaskLink({required String label, required VoidCallback? onPressed})`; `TaskDetails({required List<Widget> lines})`.
  - `ShellChrome` field `crumbs: List<AddressCrumb>` replacing `title: String`.
  - `ShellFrame({required Widget desk, required bool inspectorOpen, required VoidCallback onBackToList, Widget? inspector, List<Widget> tasks = const [], Widget? details, Widget? formulaBar})` — `formulaBar` is removed in Task 9.
  - `ShellView({bool showTaskPane = true, bool showPropertySheet = true})` (renamed fields).
  - `ShellMetrics` constants: `menuBarHeight 24`, `toolbarHeight 38`, `addressBarHeight 26`, `statusBarHeight 22`, `taskPaneWidth 200`, `propertySheetWidth 300`, `fullWidth 1280`, `taskPaneFoldWidth 1024`.

- [ ] **Step 1: Write failing tests**

Create `test/shared/shell/task_pane_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  Widget host(Widget child, {double scale = 1}) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 200, height: 600, child: child),
        ),
      ),
    ),
  );

  testWidgets('a group collapses and expands from its header key', (
    tester,
  ) async {
    var added = 0;
    await tester.pumpWidget(
      host(
        TaskPane(
          groups: [
            TaskGroup(
              title: 'Work tasks',
              special: true,
              child: TaskLink(label: 'Add a shift', onPressed: () => added++),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Add a shift'));
    expect(added, 1);
    await tester.tap(find.bySemanticsLabel('Collapse Work tasks'));
    await tester.pump();
    expect(find.text('Add a shift'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Expand Work tasks'));
    await tester.pump();
    expect(find.text('Add a shift'), findsOneWidget);
  });

  testWidgets('long links wrap at 200 % text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TaskPane(
          groups: [
            TaskGroup(
              title: 'Synthetic depot with a very long employment name',
              child: TaskLink(
                label: 'Record a payslip for the selected pay period',
                onPressed: () {},
              ),
            ),
          ],
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

Create `test/shared/shell/address_bar_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/address_bar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  testWidgets('crumbs open their level and Go reloads', (tester) async {
    final opened = <String>[];
    var reloaded = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LifeOSSkinScope(
          child: SizedBox(
            width: 800,
            child: AddressBar(
              crumbs: const [
                AddressCrumb('Work', '/work'),
                AddressCrumb('Synthetic depot', '/work?employment=e1'),
                AddressCrumb('Shifts'),
              ],
              onNavigate: opened.add,
              onGo: () => reloaded++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Work'));
    expect(opened, ['/work']);
    await tester.tap(find.text('Go'));
    expect(reloaded, 1);
    expect(find.bySemanticsLabel('Address'), findsOneWidget);
  });
}
```

In `test/shared/shell/shell_frame_test.dart`:
- Rename `'narrow windows fold the tree into Books'` to `'narrow windows fold the task pane into Tasks'` and change its `'Books'` key finders to `'Tasks'` and `'Close books'` to `'Close tasks'`.
- Rename `'hiding the tree keeps navigation behind Books'` likewise, toggling `showTaskPane: false`.
- Rename `showInspector:` uses to `showPropertySheet:`, `onBackToDesk:` to `onBackToList:`, `'Back to desk'` to `'Back to list'`.
- Add this test (Review Focus 2):

```dart
  testWidgets('widening past 1024 docks the task pane and drops the overlay', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_frame());
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Task pane'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.text('Close tasks'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    expect(find.bySemanticsLabel('Task pane'), findsOneWidget);
    expect(find.bySemanticsLabel('Desk workspace'), findsOneWidget);
    tester.view.physicalSize = const Size(960, 760);
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.bySemanticsLabel('Desk workspace'), findsOneWidget);
  });
```

(`_frame()` is the file's existing frame builder; if its name differs, use it.)

In `test/shared/shell/book_tree_test.dart` delete any expectation on the `BOOKS`/`NOW` header or the footer row, and change `footer:` arguments to nothing (the parameter is removed).

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/shared/shell`
Expected: FAIL (new files missing, labels not found).

- [ ] **Step 3: Implement Address bar and task pane**

Create `lib/shared/shell/address_bar.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../workbench/era_controls.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';
import '../workbench/office_controls.dart';

/// One level of the current location. A crumb with a [route] opens it.
@immutable
final class AddressCrumb {
  const AddressCrumb(this.label, [this.route]);

  final String label;
  final String? route;

  @override
  bool operator ==(Object other) =>
      other is AddressCrumb && other.label == label && other.route == route;

  @override
  int get hashCode => Object.hash(label, route);
}

/// Where the owner is, as crumbs in a read-only field, with **Go** to
/// reload (spec 4 item 3).
final class AddressBar extends StatelessWidget {
  const AddressBar({
    required this.crumbs,
    required this.onNavigate,
    required this.onGo,
    super.key,
  });

  final List<AddressCrumb> crumbs;
  final ValueChanged<String> onNavigate;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final body = skin.typography.body.copyWith(color: tokens.ink);
    return Semantics(
      container: true,
      label: 'Address',
      explicitChildNodes: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: tokens.chrome,
          border: Border(bottom: BorderSide(color: tokens.chromeLine)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Text(
                'Address',
                style: body.copyWith(color: tokens.muted),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: tokens.paper,
                  border: Border.all(color: MillenniumColors.fieldLine),
                ),
                child: Row(
                  children: [
                    for (final (index, crumb) in crumbs.indexed) ...[
                      if (index > 0)
                        ExcludeSemantics(child: Text(' › ', style: body)),
                      Flexible(
                        child: _Crumb(
                          crumb: crumb,
                          last: index == crumbs.length - 1,
                          onNavigate: onNavigate,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            KeyButton(
              label: 'Go',
              kind: KeyKind.small,
              leading: const Orb(
                glyph: OrbGlyph.forward,
                tone: OrbTone.green,
                size: 14,
              ),
              onPressed: onGo,
            ),
          ],
        ),
      ),
    );
  }
}

final class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.crumb,
    required this.last,
    required this.onNavigate,
  });

  final AddressCrumb crumb;
  final bool last;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final route = crumb.route;
    final text = Text(
      crumb.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: skin.typography.body.copyWith(
        color: skin.tokens.ink,
        fontWeight: last ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    if (route == null || last) return text;
    return Semantics(
      link: true,
      child: GestureDetector(
        onTap: () => onNavigate(route),
        child: MouseRegion(cursor: SystemMouseCursors.click, child: text),
      ),
    );
  }
}
```

Create `lib/shared/shell/task_pane.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

/// The blue task pane on the left (spec 5.2): rounded groups of links.
final class TaskPane extends StatelessWidget {
  const TaskPane({required this.groups, super.key});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [MillenniumColors.paneTop, MillenniumColors.paneBottom],
      ),
    ),
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final group in groups) ...[group, const SizedBox(height: 12)],
      ],
    ),
  );
}

/// One collapsible task-pane group. The [special] group has a solid blue
/// header. Collapsed state lasts for the session (page storage).
final class TaskGroup extends StatefulWidget {
  const TaskGroup({
    required this.title,
    required this.child,
    this.special = false,
    super.key,
  });

  final String title;
  final Widget child;
  final bool special;

  @override
  State<TaskGroup> createState() => _TaskGroupState();
}

final class _TaskGroupState extends State<TaskGroup> {
  late bool _open =
      PageStorage.maybeOf(context)?.readState(
            context,
            identifier: 'task-group-${widget.title}',
          )
          as bool? ??
      true;

  void _toggle() {
    setState(() => _open = !_open);
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _open, identifier: 'task-group-${widget.title}');
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final special = widget.special;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 25),
            padding: const EdgeInsets.fromLTRB(9, 2, 4, 2),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              gradient: LinearGradient(
                colors: special
                    ? [tokens.head, MillenniumColors.specialHeaderEnd]
                    : [tokens.paper, MillenniumColors.groupHeaderEnd],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: skin.typography.body.copyWith(
                        color: special ? tokens.headInk : tokens.head,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _CollapseKey(
                  open: _open,
                  special: special,
                  title: widget.title,
                  onPressed: _toggle,
                ),
              ],
            ),
          ),
          if (_open)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MillenniumColors.paneBody,
                border: Border(
                  left: BorderSide(color: tokens.paper),
                  right: BorderSide(color: tokens.paper),
                  bottom: BorderSide(color: tokens.paper),
                ),
              ),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

final class _CollapseKey extends StatelessWidget {
  const _CollapseKey({
    required this.open,
    required this.special,
    required this.title,
    required this.onPressed,
  });

  final bool open;
  final bool special;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Semantics(
      button: true,
      label: open ? 'Collapse $title' : 'Expand $title',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: special ? MillenniumColors.specialHeaderEnd : tokens.paper,
                  border: Border.all(
                    color: special
                        ? tokens.paper
                        : MillenniumColors.groupHeaderEnd,
                  ),
                ),
                child: Text(
                  open ? '︽' : '︾',
                  style: skin.typography.small.copyWith(
                    color: special ? tokens.headInk : tokens.head,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A task-pane link (spec 5.2): link blue, underlined on hover, at least
/// 24 px high. Null [onPressed] shows it unavailable.
final class TaskLink extends StatefulWidget {
  const TaskLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<TaskLink> createState() => _TaskLinkState();
}

final class _TaskLinkState extends State<TaskLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final enabled = widget.onPressed != null;
    return MergeSemantics(
      child: Semantics(
        link: true,
        enabled: enabled,
        label: widget.label,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
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
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minHeight: 24),
                alignment: Alignment.centerLeft,
                foregroundDecoration: _focused
                    ? DottedFocusRectangle(color: tokens.focus, inset: 0.5)
                    : null,
                child: Text(
                  widget.label,
                  style: skin.typography.body.copyWith(
                    color: enabled ? MillenniumColors.link : tokens.muted,
                    decoration: _hovered && enabled
                        ? TextDecoration.underline
                        : null,
                    decorationColor: MillenniumColors.link,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain lines in a Details group.
final class TaskDetails extends StatelessWidget {
  const TaskDetails({required this.lines, super.key});

  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return DefaultTextStyle.merge(
      style: skin.typography.body.copyWith(color: skin.tokens.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(padding: const EdgeInsets.only(bottom: 2), child: line),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rebuild the shell frame**

In `lib/shared/shell/shell_frame.dart`:
- Replace `ShellMetrics` with the constants listed in **Interfaces**.
- Rename `ShellView` fields to `showTaskPane`/`showPropertySheet` (keep `copyWith`, `==`, `hashCode`), and drop `showFormulaBar` if Task 5 left it.
- In `ShellChrome` replace `final String title;` with `final List<AddressCrumb> crumbs;` (constructor `required this.crumbs`, `updateShouldNotify` compares with `!listEquals(crumbs, oldWidget.crumbs)`; import `package:flutter/foundation.dart`). Update the `tree` doc comment to "Builds the Books group's content."
- `ShellFrame` constructor: rename `onBackToDesk` → `onBackToList`; add `final List<Widget> tasks;` (default `const []`) and `final Widget? details;`.
- Replace `_ShellFrameState.build`'s `LayoutBuilder` body with:

```dart
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final full =
                width >= ShellMetrics.fullWidth && view.showPropertySheet;
            final folded =
                width < ShellMetrics.taskPaneFoldWidth || !view.showTaskPane;
            // Widening the window docks the pane; the overlay state goes.
            if (!folded && _tasksOpen) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _closeTasks(),
              );
            }
            final pane = _Landmark(
              label: 'Task pane',
              child: TaskPane(
                groups: [
                  ...widget.tasks,
                  TaskGroup(
                    title: 'Books',
                    child: chrome?.tree(_closeTasks) ?? const SizedBox.shrink(),
                  ),
                  if (widget.details case final details?)
                    TaskGroup(title: 'Details', child: details),
                ],
              ),
            );
            final desk = _Landmark(label: 'Desk workspace', child: widget.desk);
            final inspecting = widget.inspector;
            final inspector = inspecting == null
                ? null
                : _Landmark(
                    label: 'Record inspector',
                    child: _PropertySheetRegion(
                      showBackToList: !full,
                      onBackToList: widget.onBackToList,
                      child: inspecting,
                    ),
                  );
            final Widget work = inspector == null
                ? desk
                : full
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: desk),
                      SizedBox(
                        width: ShellMetrics.propertySheetWidth,
                        child: inspector,
                      ),
                    ],
                  )
                : IndexedStack(
                    index: widget.inspectorOpen ? 1 : 0,
                    sizing: StackFit.expand,
                    children: [desk, inspector],
                  );
            final Widget body = folded
                ? Stack(
                    children: [
                      Positioned.fill(child: work),
                      if (_tasksOpen)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: ShellMetrics.taskPaneWidth,
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.escape):
                                  _closeTasks,
                            },
                            child: Focus(autofocus: true, child: pane),
                          ),
                        ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: ShellMetrics.taskPaneWidth, child: pane),
                      Expanded(child: work),
                    ],
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Landmark(
                  label: 'Menu bar',
                  child: SizedBox(
                    height: ShellMetrics.menuBarHeight,
                    child: chrome?.menuBar ?? const SizedBox.shrink(),
                  ),
                ),
                _Landmark(
                  label: 'Toolbar',
                  child: _Toolbar(
                    showTasks: folded,
                    tasksOpen: _tasksOpen,
                    onTasks: _toggleTasks,
                    quickAdd: chrome?.quickAdd ?? const [],
                    fromLastTime: chrome?.fromLastTime ?? const [],
                  ),
                ),
                AddressBar(
                  crumbs: chrome?.crumbs ?? const [],
                  onNavigate: (route) => chrome?.onNavigate(route),
                  // Go reopens the current location (its last crumb).
                  onGo: () {
                    final here = chrome?.crumbs.lastOrNull?.route;
                    if (here != null) chrome?.onNavigate(here);
                  },
                ),
                // Removed in Task 9, when its content moves to Working.
                _Landmark(
                  label: 'Formula bar',
                  liveRegion: true,
                  child: _FormulaBarRegion(
                    child:
                        widget.formulaBar ??
                        FormulaBar(
                          onNavigate: (route) =>
                              chrome?.onNavigate(route.toString()),
                        ),
                  ),
                ),
                Expanded(child: body),
                _Landmark(
                  label: 'Status line',
                  child: SizedBox(
                    height: ShellMetrics.statusBarHeight,
                    child: chrome?.status ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
```

Rename state members: `_treeOpen` → `_tasksOpen`, `_toggleTree` → `_toggleTasks`, `_closeTree` → `_closeTasks`. Import `package:flutter/services.dart` (for `LogicalKeyboardKey`), `address_bar.dart`, `task_pane.dart`, `../workbench/era_controls.dart`. Remove `_Divider` uses (the pane and sheet draw their own edges) and delete `_Divider` if unused.

Replace `_Toolbar` with:

```dart
final class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.showTasks,
    required this.tasksOpen,
    required this.onTasks,
    required this.quickAdd,
    required this.fromLastTime,
  });

  final bool showTasks;
  final bool tasksOpen;
  final VoidCallback onTasks;
  final List<QuickAddEntry> quickAdd;
  final List<QuickAddEntry> fromLastTime;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final history = NavigationHistoryScope.maybeOf(context);
    Widget separator() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: tokens.chromeLine,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: ShellMetrics.toolbarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: skin.painters.toolbar(tokens),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          if (showTasks)
            KeyButton(
              label: tasksOpen ? 'Close tasks' : 'Tasks',
              kind: KeyKind.toolbar,
              onPressed: onTasks,
            ),
          if (history != null) ...[
            KeyButton(
              label: 'Back',
              kind: KeyKind.toolbar,
              leading: Orb(
                glyph: OrbGlyph.back,
                tone: history.canGoBack ? OrbTone.green : OrbTone.grey,
              ),
              semanticLabel: history.canGoBack ? 'Back' : 'Back, unavailable',
              onPressed: history.canGoBack ? history.goBack : null,
            ),
            KeyButton(
              label: 'Forward',
              kind: KeyKind.toolbar,
              leading: Orb(
                glyph: OrbGlyph.forward,
                tone: history.canGoForward ? OrbTone.green : OrbTone.grey,
              ),
              semanticLabel: history.canGoForward
                  ? 'Forward'
                  : 'Forward, unavailable',
              onPressed: history.canGoForward ? history.goForward : null,
            ),
          ],
          if (quickAdd.isNotEmpty) ...[
            separator(),
            QuickAddMenu(entries: quickAdd),
          ],
          if (fromLastTime.isNotEmpty) ...[
            separator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'From last time:',
                style: skin.typography.body.copyWith(color: tokens.muted),
              ),
            ),
            for (final entry in fromLastTime.take(4))
              KeyButton(
                label: entry.label,
                kind: KeyKind.toolbar,
                onPressed: entry.open,
              ),
          ],
        ],
      ),
    );
  }
}
```

Rename `_InspectorRegion` to `_PropertySheetRegion` with:

```dart
  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      color: tokens.chrome,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBackToList)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: KeyButton(
                  label: 'Back to list',
                  kind: KeyKind.small,
                  onPressed: onBackToList,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
```

with fields `showBackToList`, `onBackToList`, `child`.

In `lib/shared/shell/quick_add.dart`, the menu's child becomes:

```dart
        child: IgnorePointer(
          child: KeyButton(
            key: const ValueKey('quick-add'),
            label: 'Add',
            kind: KeyKind.toolbar,
            leading: const Orb(glyph: OrbGlyph.add, tone: OrbTone.orange),
            trailing: const Text('▾'),
            onPressed: () {},
          ),
        ),
```

(import `../workbench/era_controls.dart`; drop the `Icons.add` import if unused). Then:

```bash
grep -rn "'+ Add'" test lib
```

Change each test finder `find.text('+ Add')` to `find.byKey(const ValueKey('quick-add'))`.

- [ ] **Step 5: Books inside the task pane**

In `lib/shared/shell/book_tree.dart`:
- Remove the `footer` parameter and field, the header `Container` with `BOOKS`/`NOW`, the footer loop and `_label`.
- `BookTree.build` returns a `Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...])` of the same rows (no `ListView`, no `ColoredBox`): the task pane scrolls.
- `_TreeRow`: `minHeight: 24`, `padding: const EdgeInsets.symmetric(horizontal: 2)`, no bottom border, no fill except none; focus `foregroundDecoration: _focused ? DottedFocusRectangle(color: tokens.focus, inset: 0.5) : null`. Text colour: selected → `tokens.ink` with `FontWeight.w700`; otherwise `MillenniumColors.link`; unbuilt → `tokens.muted`. Underline the label while hovered.
- `_AreaRow`: no `background`; label weight w700 and colour as above.
- `_SheetRow`: indent 20; live value in `skin.typography.figure` with `tokens.ink` (or `tokens.runInk` w700 when `liveValueIsActive`).
- `_GroupRow`: label in `tokens.ink` w700, count in figure.

In `lib/app/shell_host.dart`: delete the `footer:` argument; replace `title: _title(location.path, employmentName)` with `crumbs: _crumbs(location, employmentName)` and replace `_title` with:

```dart
  static List<AddressCrumb> _crumbs(Uri location, String? employmentName) {
    switch (location.path) {
      case '/work':
        final employment = location.queryParameters['employment'];
        if (employment == null || employmentName == null) {
          return const [AddressCrumb('Work', '/work')];
        }
        final sheet = location.queryParameters['sheet'];
        return [
          const AddressCrumb('Work', '/work'),
          AddressCrumb(employmentName, '/work?employment=$employment'),
          AddressCrumb(switch (sheet) {
            'periods' => 'Pay periods',
            'payslips' => 'Payslips',
            'agreements' => 'Agreements',
            _ => 'Shifts',
          }, location.toString()),
        ];
      case '/journal':
        return const [AddressCrumb('Journal', '/journal')];
      case '/finance':
        return const [AddressCrumb('Finance', '/finance')];
      case '/tracking':
        return const [AddressCrumb('Tracking', '/tracking')];
      case '/knowledge':
        return const [AddressCrumb('Knowledge', '/knowledge')];
      case '/system/files':
        return const [AddressCrumb('Backup and export', '/system/files')];
      case '/today':
        return [AddressCrumb('Today', location.toString())];
      default:
        return const [AddressCrumb('LifeOS')];
    }
  }
```

(`WorkSheet` names are `shifts`, `periods`, `payslips`, `agreements`; confirm against `lib/features/work/presentation/work_route_state.dart` and adjust the strings if they differ.) Import `../shared/shell/address_bar.dart`.

Rename `onBackToDesk:` → `onBackToList:` at every `ShellFrame(` call site (`app_router.dart`, `desk_host.dart`, `work_screen.dart`, tests):

```bash
grep -rl "onBackToDesk" lib test | xargs sed -i 's/onBackToDesk/onBackToList/g'
grep -rl "'Back to desk'" lib test | xargs sed -i "s/'Back to desk'/'Back to list'/g"
grep -rl "showInspector" lib test | xargs sed -i 's/showInspector/showPropertySheet/g'
grep -rl "showTree" lib test | xargs sed -i 's/showTree/showTaskPane/g'
```

Fix tests that used the toolbar title text (for example `find.text('Work › Synthetic depot')`): assert on the crumbs instead, e.g. `find.descendant(of: find.bySemanticsLabel('Address'), matching: find.text('Synthetic depot'))`.

- [ ] **Step 6: Run tests**

Run: `$F/flutter test`
Expected: PASS. Then `$F/flutter test --update-goldens test/goldens`, open `test/goldens/shell_1280x800.png` and `shell_960x760.png`: menu bar, orb toolbar, Address bar, blue task pane with Books, register, status panels.

- [ ] **Step 7: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: shape the shell as a file explorer with a task pane and Address bar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Details list

Spec §5.4, Review Focus 3.

**Files:**
- Modify: `lib/shared/workbench/data_register.dart`, `lib/features/work/presentation/work_sheets.dart` (pass `sortedColumn: 'date'` on the Shifts sheet)
- Test: `test/shared/workbench/data_register_test.dart` (create if absent; otherwise add to it)

**Interfaces:**
- Consumes: `LifeOSPainters.cellCursor(tokens, onSelection:)`, `DottedFocusRectangle`, `MillenniumColors.sortAccent`, `MillenniumColors.groupRowRule`, `MillenniumColors.fieldLine`.
- Produces: `DataRegister` gains `final String? sortedColumn;` and `final bool sortDescending;` (default `false`).

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/data_register.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';
import 'package:lifeos/shared/workbench/millennium_style.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildLifeOSTheme(),
    home: LifeOSSkinScope(child: Scaffold(body: child)),
  );

  DataRegister<String> register({String? selectedId}) => DataRegister<String>(
    label: 'Synthetic rows',
    lines: const [
      GroupLine(label: '2026-09'),
      RowLine(row: 'a'),
      RowLine(row: 'b'),
    ],
    columns: [
      RegisterColumn<String>(
        key: 'name',
        label: 'Name',
        width: 120,
        kind: ColumnKind.text,
        value: (row) => row,
      ),
    ],
    rowId: (row) => row,
    rowLabel: (row) => 'Row $row',
    selectedId: selectedId,
    onOpen: (_) {},
    sortedColumn: 'name',
  );

  testWidgets('headers are not uppercased and the sorted column says so', (
    tester,
  ) async {
    await tester.pumpWidget(host(register()));
    expect(find.text('Name ▴'), findsOneWidget);
    expect(find.text('NAME'), findsNothing);
  });

  testWidgets('rows are 20 px and a selected row is solid blue', (
    tester,
  ) async {
    await tester.pumpWidget(host(register(selectedId: 'a')));
    final row = find.bySemanticsLabel('Row a');
    expect(tester.getSize(row).height, 20);
    final box = tester.widget<Container>(
      find.ancestor(of: find.text('a'), matching: find.byType(Container)).last,
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      LifeOSTokens.millennium.selWash,
    );
  });

  testWidgets('the cell cursor on a selected row is dotted in white', (
    tester,
  ) async {
    await tester.pumpWidget(host(register(selectedId: 'a')));
    await tester.tap(find.text('a'));
    await tester.pump();
    final cursor = tester
        .widgetList<Container>(find.byType(Container))
        .map((value) => value.foregroundDecoration)
        .whereType<DottedFocusRectangle>()
        .single;
    expect(cursor.color, LifeOSTokens.millennium.selInk);
  });
}
```

(Adjust the `GroupLine`/`RowLine`/`RegisterColumn` constructor arguments to the real signatures in `data_register.dart:34-110` if they differ; keep the assertions.)

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/shared/workbench/data_register_test.dart`
Expected: FAIL (`sortedColumn` undefined, `NAME`, 25 px rows).

- [ ] **Step 3: Implement**

In `data_register.dart`:
- Add `this.sortedColumn,` and `this.sortDescending = false,` to the constructor with fields and doc comments ("The column the lines are ordered by, marked in its header." / "Whether that order is descending."). Pass both to `_HeaderRow`.
- `_HeaderRow.build`:

```dart
    final tokens = skin.tokens;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.paper, tokens.band],
        ),
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Row(
        children: [
          for (final column in columns)
            Container(
              width: column.width,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: tokens.chromeLine),
                  bottom: column.key == sortedColumn
                      ? const BorderSide(
                          color: MillenniumColors.sortAccent,
                          width: 3,
                        )
                      : BorderSide.none,
                ),
              ),
              child: Text(
                column.key == sortedColumn
                    ? '${column.label} ${sortDescending ? '▾' : '▴'}'
                    : column.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: column.kind.isNumeric
                    ? TextAlign.right
                    : TextAlign.left,
                style: skin.typography.label.copyWith(color: tokens.ink),
              ),
            ),
        ],
      ),
    );
```

- `_GroupRow.build`: `Container(constraints: BoxConstraints(minHeight: 22), padding: EdgeInsets.fromLTRB(5, 5, 5, 1), decoration: BoxDecoration(color: tokens.paper, border: Border(bottom: BorderSide(color: MillenniumColors.groupRowRule))), …)` with the label `skin.typography.body.copyWith(color: tokens.head, fontWeight: FontWeight.w700)` and the summary in the same colour at w400.
- `_SubtotalRow`: top border `BorderSide(color: tokens.ink)` (1 px), padding vertical 2.
- `_EntryRow`: `minHeight: 20`, padding horizontal 5.
- `_DataRow`: row `foregroundDecoration: cursor && cursorColumn == null ? skin.painters.cellCursor(tokens, onSelection: selected) : null`; cell `constraints: const BoxConstraints(minHeight: 20)`, `padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2)`, `foregroundDecoration: cursorColumn == column.key ? skin.painters.cellCursor(tokens, onSelection: selected) : null`. Remove the row's bottom `rule` border (the era list has none) — keep `color: selected ? tokens.selWash : tokens.paper`.
- Keep all semantics as they are.

In `work_sheets.dart`, add `sortedColumn: 'date',` to the Shifts `DataRegister<ShiftSheetRow>(`.

- [ ] **Step 4: Run tests**

Run: `$F/flutter test`
Expected: PASS (fix any test that matched upper-case header text such as `'DATE'`: use `'Date'`). Update goldens and look at them.

- [ ] **Step 5: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: draw registers as era details lists

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Work surface: View combo, filters, Work tasks and Details

Spec §5.2 (Work tasks, Details), §5.3, §8 items 3–4.

**Files:**
- Modify: `lib/features/work/presentation/work_register.dart`, `work_toolbar_controls.dart`, `work_screen.dart`
- Create: `test/support/work_sheets.dart`
- Test: `test/features/work/presentation/work_register_test.dart`, `test/features/work/presentation/work_screen_test.dart`, `test/app/router_test.dart`, `test/integration/*.dart` (finder updates)

**Interfaces:**
- Consumes: `EraComboFace`, `TaskGroup`, `TaskLink`, `TaskDetails`, `ShellFrame(tasks:, details:)`.
- Produces:
  - `WorkRegister` without the Add shift, New pay period and Save view keys in its body and without the `onSaveView` parameter (it keeps `onPrimaryAction` for the empty state and `onNewPeriod` for the Pay periods entry row).
  - `WorkDetails({required WorkRegisterProjection projection})` (in `work_register.dart`).
  - `ValueKey('work-view-combo')` on the View combo.
  - `Future<void> chooseSheet(WidgetTester tester, String sheet)` in `test/support/work_sheets.dart`.

- [ ] **Step 1: Write the helper and failing tests**

Create `test/support/work_sheets.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the Work View combo and picks [sheet] ("Shifts", "Pay periods",
/// "Payslips" or "Agreements").
Future<void> chooseSheet(WidgetTester tester, String sheet) async {
  await tester.tap(find.byKey(const ValueKey('work-view-combo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(sheet).last);
  await tester.pumpAndSettle();
}
```

Add to `test/features/work/presentation/work_screen_test.dart` (reuse the file's existing pump helper that shows an employment with shifts; call it `pumpWork` below and substitute the real name):

```dart
  testWidgets('Work tasks live in the task pane, sheets in the View combo', (
    tester,
  ) async {
    await pumpWork(tester);
    final pane = find.bySemanticsLabel('Task pane');
    for (final task in [
      'Add a shift',
      'New pay period',
      'Record payslip',
      'Save this view…',
    ]) {
      expect(
        find.descendant(of: pane, matching: find.text(task)),
        findsOneWidget,
        reason: task,
      );
    }
    expect(find.byKey(const ValueKey('work-view-combo')), findsOneWidget);
    await chooseSheet(tester, 'Pay periods');
    expect(find.text('Pay periods'), findsWidgets);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/presentation/work_screen_test.dart`
Expected: FAIL (no task pane links, no combo).

- [ ] **Step 3: Implement the filter row**

In `work_toolbar_controls.dart` replace `_MenuFace.build` with a labelled combo:

```dart
  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: skin.typography.body.copyWith(color: skin.tokens.ink),
        ),
        const SizedBox(width: 4),
        EraComboFace(value: detail ?? 'All'),
      ],
    );
  }
```

Import `../../../shared/workbench/era_controls.dart`; remove the `Icons.arrow_drop_down` use. The `‹` / `›` keys in `PeriodPicker` use `kind: KeyKind.small`.

Add a View combo to `work_toolbar_controls.dart`:

```dart
/// The sheet shown in the list (spec 5.3 "View:").
final class SheetPicker extends StatelessWidget {
  const SheetPicker({required this.sheet, required this.onSheet, super.key});

  final WorkSheet sheet;
  final ValueChanged<WorkSheet> onSheet;

  static const labels = {
    WorkSheet.shifts: 'Shifts',
    WorkSheet.periods: 'Pay periods',
    WorkSheet.payslips: 'Payslips',
    WorkSheet.agreements: 'Agreements',
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<WorkSheet>(
    key: const ValueKey('work-view-combo'),
    tooltip: 'Choose what the list shows',
    onSelected: onSheet,
    itemBuilder: (context) => [
      for (final MapEntry(key: value, value: label) in labels.entries)
        PopupMenuItem(height: menuRowHeight, value: value, child: Text(label)),
    ],
    child: _MenuFace(label: 'View', detail: labels[sheet]),
  );
}
```

(If `WorkSheet` value names differ, use the real ones; the labels stay.)

In `work_register.dart` replace the `SegmentedTabs` padding block and the `Wrap` of keys with:

```dart
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: skin.painters.toolbar(skin.tokens),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SheetPicker(
                sheet: route.sheet,
                onSheet: (sheet) => change(route.copyWith(sheet: sheet)),
              ),
              EmploymentSwitcher(
                current: value.employment?.id,
                currentName: value.employment?.name,
                employments: value.availableEmployments,
                onOpen: onOpenEmployment,
                onAll: onAllEmployments,
                onCreate: create,
              ),
              PeriodPicker(
                scope: route.scope,
                periods: [for (final row in value.periodSheet) row.period],
                onScope: (scope) => change(
                  route.copyWith(scope: () => scope, record: () => null),
                ),
              ),
              StateFilter(
                showVoid: route.showVoid,
                onChanged: (show) => change(route.copyWith(showVoid: show)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: skin.tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: sheet,
          ),
        ),
```

(`final skin = LifeOSSkinScope.of(context);` at the top of `build`.) Delete `_Summary` and `_SummaryValue` from the list body and add `WorkDetails`:

```dart
/// The Details group for a Work scope (spec 5.2): employment, period,
/// shift count and the reconciliation per basis.
final class WorkDetails extends StatelessWidget {
  const WorkDetails({required this.projection, super.key});

  final WorkRegisterProjection projection;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final figure = skin.typography.figure.copyWith(color: skin.tokens.ink);
    final period = projection.period;
    final groups = projection.reconciliation?.groups ?? const [];
    return TaskDetails(
      lines: [
        if (projection.employment case final employment?)
          Text(
            employment.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        if (period != null)
          Text('${period.start} – ${period.end}', style: figure),
        Text(
          projection.shiftSheet.length == 1
              ? '1 shift'
              : '${projection.shiftSheet.length} shifts',
        ),
        if (groups.isEmpty)
          Text('Paid evidence ${_money(projection.paid)}', style: figure),
        for (final group in groups) ...[
          Text('${_basis(group.basis)} · ${group.currency.value}'),
          Text('Expected ${_optionalMoney(group.expected)}', style: figure),
          Text('Paid ${_optionalMoney(group.paid)}', style: figure),
          if (group.difference case final difference?)
            Text('Difference ${_money(difference)}', style: figure),
        ],
      ],
    );
  }
}
```

(Import `../../../shared/shell/task_pane.dart`, `../../../shared/workbench/millennium_style.dart`. `projection.shiftSheet` is the Shifts rows list used by `ShiftsSheet(rows: value.shiftSheet)`; if the period summary needs the state word, add `period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open'` after the dates.)

In `work_screen.dart` `build`, pass tasks and details to `ShellFrame`:

```dart
    final ready = …; // existing
    final register = ready is WorkReady ? ready.register : null;
    final route = ready is WorkReady ? ready.route : null;
    final employmentId = route?.employmentId;
    return ShellFrame(
      desk: _RegisterLandmark(child: _register(ready)),
      inspector: _inspector(ready),
      inspectorOpen: inspectorActive,
      onBackToList: () => setState(() => _showRegister = true),
      tasks: [
        if (employmentId != null && route != null)
          TaskGroup(
            title: 'Work tasks',
            special: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskLink(label: 'Add a shift', onPressed: widget.onPrimaryAction),
                TaskLink(
                  label: 'New pay period',
                  onPressed: widget.onCreatePayPeriod == null
                      ? null
                      : () => setState(() {
                          _creatingPeriod = true;
                          _showRegister = false;
                        }),
                ),
                TaskLink(
                  label: 'Record payslip',
                  onPressed:
                      widget.onRecordPayslip == null || register?.period == null
                      ? null
                      : () => setState(() {
                          _payslipPeriod = register!.period!.id;
                          _showRegister = false;
                        }),
                ),
                TaskLink(
                  label: 'Save this view…',
                  onPressed: widget.onSaveView == null
                      ? null
                      : () => widget.onSaveView!(route),
                ),
              ],
            ),
          ),
      ],
      details: register == null || register.employment == null
          ? null
          : WorkDetails(projection: register),
    );
```

Remove the `onSaveView` argument from the `WorkRegister(...)` call and the parameter and field from `WorkRegister`. Keep `onNewPeriod`: it still feeds the Pay periods sheet's own entry row (`PeriodsSheet(onNewPeriod:)`); only the key in the register body goes.

- [ ] **Step 4: Update finders**

```bash
grep -rn "find.text('Pay periods')\|find.text('Payslips')\|find.text('Agreements')\|find.text('Shifts')\|'Save view'\|'New pay period'\|'Add shift'" test
```

For each sheet switch (`tap(find.text('Pay periods'))` and similar) replace with `await chooseSheet(tester, 'Pay periods');` and import `../../support/work_sheets.dart` (path relative to the test). For `'Save view'` use `'Save this view…'`; for `'Add shift'` use `'Add a shift'`; `'New pay period'` stays but is now a task link (no change to the finder).

- [ ] **Step 5: Run tests**

Run: `$F/flutter test`
Expected: PASS. Update goldens; check the filter row and task pane at both sizes.

- [ ] **Step 6: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: move Work's sheets and filters into combos and its actions into Work tasks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Property sheet: Working group box, General | History, group-box content and forms

Spec §5.5, §5.6, §8 item 2, Review Focus 1 and 5.

**Files:**
- Create: `lib/shared/shell/working_group_box.dart`
- Delete: `lib/shared/shell/formula_bar.dart`, `test/shared/shell/formula_bar_test.dart` (its cases move to `working_group_box_test.dart`)
- Modify: `lib/shared/shell/shell_frame.dart` (drop the formula row and `formulaBar` parameter), `lib/features/work/presentation/record_history_panel.dart`, `lib/shared/workbench/inspector_parts.dart`, `lib/features/work/presentation/{work_inspector,period_payslip_forms,shift_forms,employment_agreement_forms,correction_confirmation,work_screen}.dart`
- Test: `test/shared/shell/working_group_box_test.dart` (new), `test/shared/workbench/inspector_parts_test.dart` (new)

**Interfaces:**
- Consumes: `GroupBox`, `FormFooter`, `PropertySheetTabs`, `CellSelectionScope`, `ShellChrome.onNavigate`.
- Produces:
  - `WorkingGroupBox({required ValueChanged<Uri> onNavigate})` — nothing without a selection.
  - `InspectorFacts(List<Fact> facts, {String? legend})` (legend wraps the facts in a `GroupBox`); `InspectorSection` removed.
  - `RecordTabs` pages: General = `Column([WorkingGroupBox, Expanded(details)])` on the property-sheet page.

- [ ] **Step 1: Write failing tests**

Create `test/shared/shell/working_group_box_test.dart` by moving the four cases from `formula_bar_test.dart` (keep its fixture builders) and changing:
- `FormulaBar(onNavigate: …)` → `WorkingGroupBox(onNavigate: …)`.
- "shows nothing without a selection": `expect(find.byType(GroupBox), findsNothing);`.
- "a derived cell shows its reference, label and working": expect `find.text('Working: <column label>')` (the legend) plus the existing working text.
- Add (Review Focus 5):

```dart
  testWidgets('a long working wraps in 300 px and every operand still opens', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      _host(
        width: 300,
        selection: _longSelection(operands: 6),
        child: WorkingGroupBox(onNavigate: opened.add),
      ),
    );
    expect(tester.takeException(), isNull);
    final box = tester.getSize(find.byType(WorkingGroupBox));
    expect(box.height, greaterThan(60));
    // Tap the last operand's text span.
    await tester.tapOnText(find.textRange.ofSubstring('operand 6'));
    expect(opened, isNotEmpty);
  });
```

where `_host` pumps `LifeOSSkinScope` + `CellSelectionScope` with a controller set to the selection inside a `SizedBox(width:)`, and `_longSelection` builds a `CellSelection` whose `explanation.tokens` alternate `TextToken(' + ')` and `OperandToken('operand $i', source: …)` for `i` in `1..operands` (use the same `Explanation`/`OperandToken` constructors the existing fixture uses).

Create `test/shared/workbench/inspector_parts_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_controls.dart';
import 'package:lifeos/shared/workbench/inspector_parts.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  Widget host(Widget child, {double scale = 1}) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 292, height: 600, child: child),
        ),
      ),
    ),
  );

  testWidgets('facts with a legend sit in a group box', (tester) async {
    await tester.pumpWidget(
      host(
        const InspectorPane(
          children: [
            InspectorFacts([Fact('Date', '2026-09-09')], legend: 'Shift'),
          ],
        ),
      ),
    );
    expect(find.widgetWithText(GroupBox, 'Date'), findsOneWidget);
    expect(find.text('Shift'), findsOneWidget);
  });

  testWidgets('long facts hold at 200 % text in the property sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const InspectorPane(
          children: [
            InspectorTitle('Synthetic depot with a long employment name'),
            InspectorFacts([
              Fact.words('Timezone', 'America/Argentina/Buenos_Aires'),
              Fact('Expected under recorded agreement', 'EUR 12,345.67'),
            ], legend: 'Shift'),
          ],
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/shared/shell/working_group_box_test.dart test/shared/workbench/inspector_parts_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the Working group box**

`git mv lib/shared/shell/formula_bar.dart lib/shared/shell/working_group_box.dart`, rename `FormulaBar` → `WorkingGroupBox`, and replace both returned `Row`s:

- Recorded fact:

```dart
      return Semantics(
        label:
            '${selection.reference}, ${selection.columnLabel}, '
            'recorded fact, ${selection.display}',
        excludeSemantics: true,
        child: GroupBox(
          legend: 'Working: ${selection.columnLabel}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${selection.reference} = ${selection.display}', style: figure),
              Text(
                'Recorded fact',
                style: skin.typography.small.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
      );
```

- Derived value:

```dart
    return Semantics(
      label: '${selection.reference}, ${explanation.plainText}',
      excludeSemantics: true,
      child: GroupBox(
        legend: 'Working: ${selection.columnLabel}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(style: figure, children: spans)),
            if (source != null && sourceLabel != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => onNavigate(source.route),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    sourceLabel,
                    style: skin.typography.small.copyWith(
                      color: MillenniumColors.link,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
```

Operand spans: `color: MillenniumColors.link, decoration: TextDecoration.underline` (drop the signal-coloured underline). The first span becomes `TextSpan(text: '${selection.reference}: ${explanation.label} = ')`. Delete the `reference` box widget. Imports: `../workbench/era_controls.dart`, `../workbench/millennium_style.dart`.

In `shell_frame.dart` delete the `formulaBar` parameter and field, the `Formula bar` landmark, `_FormulaBarRegion`, `ShellMetrics.formulaBarHeight` if still present, and the `formula_bar.dart` import. Then:

```bash
grep -rn "formulaBar:\|FormulaBar\|'Formula bar'" lib test
```

Remove or redirect every hit (tests asserting the formula row should assert `find.byType(WorkingGroupBox)` inside `find.bySemanticsLabel('Record inspector')` after opening a record and selecting a cell).

- [ ] **Step 4: Property-sheet page and General tab**

In `record_history_panel.dart` `_RecordTabsState.build`:

```dart
  @override
  Widget build(BuildContext context) {
    final chrome = ShellChrome.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PropertySheetTabs(
          labels: const ['General', 'History'],
          selectedIndex: _history ? 1 : 0,
          onSelected: (index) => setState(() => _history = index == 1),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: MillenniumColors.page,
              border: Border(
                left: BorderSide(color: MillenniumColors.tabLine),
                right: BorderSide(color: MillenniumColors.tabLine),
                bottom: BorderSide(color: MillenniumColors.tabLine),
              ),
            ),
            child: _history
                ? RecordHistoryPanel(record: widget.record)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: WorkingGroupBox(
                          onNavigate: (route) =>
                              chrome?.onNavigate(route.toString()),
                        ),
                      ),
                      Expanded(child: widget.details),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
```

Imports: `../../../shared/shell/shell_frame.dart`, `../../../shared/shell/working_group_box.dart`, `../../../shared/workbench/millennium_style.dart`.

In `inspector_parts.dart`:
- `inspectorInset = EdgeInsets.all(8)`.
- `InspectorTitle`: style `skin.typography.title`, bottom padding 8.
- `InspectorFacts`: add `{this.legend}`; drop the top/bottom rule borders; when `legend != null`, wrap the column in `GroupBox(legend: legend!, child: …)`. Row padding vertical 2, `minHeight: 20`.
- Delete `InspectorSection` (grep its uses and replace each `InspectorSection('X'), InspectorFacts([...])` pair with `InspectorFacts([...], legend: 'X')`).
- `InspectorActions`: `FormFooter(children: children)`.
- Update the `work_inspector.dart` views: `_FinalizedShift` facts get `legend: 'Shift'` and `legend: 'Expected pay'`; `_PayslipDetail` `legend: 'Paid evidence'` with title `'Payslip'`; `period_payslip_forms.dart` period facts `legend: 'Pay period'`, reconciliation groups `legend: '${_basisLabel(group.basis)} · ${group.currency.value}'` (not uppercased; revert the test expectation `'GROSS · EUR'` → `'Gross · EUR'` in `period_payslip_forms_test.dart:48-49`).

- [ ] **Step 5: Forms**

For each form below, wrap its fields in a `GroupBox` with the given legend and put its action keys in a `FormFooter` (keep every existing `key:`, label and callback; the primary action becomes `KeyButton(kind: KeyKind.primary)` only if no test finds it by `FilledButton` — otherwise keep the `FilledButton`, which the theme paints the same):

| File | Form | Legend(s) |
|---|---|---|
| `period_payslip_forms.dart` | `PeriodInspector.create` | `Dates` (start, end, label) |
| `period_payslip_forms.dart` | `PayslipInspector` | `Payslip` (dates, amount), `Basis` (Gross / Net radios), `Breakdown` (gross, net, deductions), `Reference` (reference, note) |
| `shift_forms.dart` | `ShiftEditInspector` | `Times` (start/end dates and times, timezone), `Breaks` (break rows and Add break), `Note` |
| `employment_agreement_forms.dart` | `EmploymentForm` | `Employment` |
| `employment_agreement_forms.dart` | `AgreementForm` | `Rate`, `Overtime`, `Night`, `Holidays`, `When several apply` (replace each `Text('…', style: text.titleMedium)` section heading with a `GroupBox` of that name around the section's fields) |
| `employment_agreement_forms.dart` | employment editor / delete confirmation | `Employment` |
| `correction_confirmation.dart` | correction confirmation | `Reason` |

Gross / Net becomes radios in the `Basis` group:

```dart
RadioGroup<RateBasis>(
  groupValue: _basis,
  onChanged: (value) {
    if (value != null) setState(() => _basis = value);
  },
  child: Row(
    children: [
      for (final (value, label) in const [
        (GrossBasis(), 'Gross'),
        (NetBasis(), 'Net'),
      ])
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _basis = value),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Radio<RateBasis>(value: value), Text(label)],
            ),
          ),
        ),
    ],
  ),
),
```

(`RateBasis` subclasses must have value equality for `Radio`; they are `const` singletons today — if `==` is identity, `const GrossBasis()` instances are canonical and compare equal.) Tests that tapped the `SegmentedButton` segment `'Net'` keep working because the label row is tappable.

Form pages sit on the face colour (no page border), so pass `background: tokens.chrome` to these `GroupBox`es (forms render on `_PropertySheetRegion`'s chrome background).

- [ ] **Step 6: Run tests**

Run: `$F/flutter test`
Expected: PASS. Update goldens; open `shell_1280x800.png` (pay period in the property sheet) and check: General | History tabs with amber edge, group boxes, keys at the right.

- [ ] **Step 7: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: show records as property sheets with a Working group box

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Desks and Journal

Spec §5.7, §5.8, §5.2 (Desk tasks).

**Files:**
- Modify: `lib/shared/shell/desk_view.dart`, `lib/app/desk_host.dart`, `lib/features/journal/journal_sheet.dart`, `lib/features/work/presentation/work_desk_tiles.dart` (only colours that read `tokens.head` for bands)
- Test: `test/shared/shell/desk_view_test.dart`, `test/integration/today_desk_flow_test.dart`

**Interfaces:**
- Consumes: `CaptionBar` (Task 4), `PropertySheetTabs`, `TaskGroup`, `TaskLink`.
- Produces: `DeskView` without the `onNewDesk`, `onRename`, `onReset`, `onDelete` keys in its tab row (callbacks move to Desk tasks); its `+ Desk` tab stays.

- [ ] **Step 1: Write the failing test**

Add to `test/integration/today_desk_flow_test.dart` (reuse its app pump):

```dart
  testWidgets('desk actions live in Desk tasks', (tester) async {
    await pumpToday(tester);
    final pane = find.bySemanticsLabel('Task pane');
    for (final task in ['New desk', 'Rename desk…', 'Reset desk']) {
      expect(
        find.descendant(of: pane, matching: find.text(task)),
        findsOneWidget,
        reason: task,
      );
    }
    // Today cannot be deleted.
    final delete = tester.widget<TaskLink>(
      find.widgetWithText(TaskLink, 'Delete desk'),
    );
    expect(delete.onPressed, isNull);
  });
```

(Use the file's real pump helper name for `pumpToday`.)

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/integration/today_desk_flow_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`desk_view.dart`:
- Tab row: `Container(padding: EdgeInsets.fromLTRB(6, 6, 6, 0), color: tokens.chrome, child: Row([Expanded(PropertySheetTabs(labels: [...desks, '+ Desk'] …)), _DeskMenu(...)]))`. Selecting the last index calls `onNewDesk`; otherwise `onSelectDesk(desks[index])`. Keep `onNewDesk` as a parameter (the tab uses it). The `_DeskMenu` key becomes `KeyButton(label: 'Desk ▾', kind: KeyKind.small, onPressed: () {})` inside the existing `PopupMenuButton` (keep its items: add sheet, add view, layout, rename, reset, delete).
- Tile area: `Container(color: tokens.paper, margin: EdgeInsets.fromLTRB(6, 0, 6, 6), decoration: BoxDecoration(border: Border(left/right/bottom: BorderSide(color: MillenniumColors.tabLine))), padding: EdgeInsets.all(10), child: …)`.
- `_TileCard`: outer `DecoratedBox(decoration: BoxDecoration(color: tokens.paper, border: Border.all(color: MillenniumColors.groupRowRule), borderRadius: BorderRadius.vertical(top: Radius.circular(5))))` with `clipBehavior` via `ClipRRect`; header `CaptionBar(title: content.title, leading: area == null ? null : AreaKey(area: area), trailing: [<the existing PopupMenuButton with child: Text('▾', style: body headInk)>], onClose: onRemove, closeLabel: 'Close ${content.title}')`. Remove the old `Icons.more_horiz`/`Icons.close`.

`desk_host.dart`: build the Desk tasks next to `DeskView` and pass them to `ShellFrame`:

```dart
    return ShellFrame(
      inspectorOpen: false,
      onBackToList: () {},
      desk: desk,
      tasks: [
        if (actions case final actions?)
          TaskGroup(
            title: 'Desk tasks',
            special: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskLink(label: 'New desk', onPressed: actions.newDesk),
                TaskLink(label: 'Rename desk…', onPressed: actions.rename),
                TaskLink(label: 'Reset desk', onPressed: actions.reset),
                TaskLink(label: 'Delete desk', onPressed: actions.delete),
              ],
            ),
          ),
      ],
    );
```

where `actions` is a record `({VoidCallback newDesk, VoidCallback rename, VoidCallback? reset, VoidCallback? delete})?` built from the same closures `_desk(...)` passes as `onNewDesk`, `onRename`, `onReset`, `onDelete` today (extract those closures into a helper `_deskActions(context, ref, desks, selected)` that both `_desk` and `build` call; `null` while desks are loading).

`journal_sheet.dart`: the range row becomes a toolbar strip (`decoration: skin.painters.toolbar(skin.tokens)`, padding 6/4) with the two `KeyButton(kind: KeyKind.small)` keys; the register sits in a sunken white box (`margin: EdgeInsets.all(4)`, border `MillenniumColors.fieldLine`), like Task 8's list. The day group rows come from Task 7.

`work_desk_tiles.dart`: replace any `tokens.head` band fill with the Task 7 group-row look (`tokens.head` text on `tokens.paper` with a `MillenniumColors.groupRowRule` bottom rule); progress bars, if any, use `MillenniumColors.progress` segments.

- [ ] **Step 4: Run tests**

Run: `$F/flutter test`
Expected: PASS (update `desk_view_test.dart` finders: the close key is found by `find.bySemanticsLabel('Close <title>')`, the tile menu by tooltip `'Tile menu'`).

Add a Today golden to `test/goldens/shell_goldens_test.dart`: same setup, `initialLocation: '/today'`, files `today_1280x800` and `today_960x760`. Run `$F/flutter test --update-goldens test/goldens` and look at them.

- [ ] **Step 5: Commit**

```bash
$F/flutter analyze lib test tool && $F/dart format lib test tool
git add -A lib test
git commit -m "feat: dress desks as tabbed windows with Desk tasks; restyle the Journal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Real-font check, semantics sweep and docs

Spec §6, §7, §9.

**Files:**
- Create: `test/goldens/real_font_check_test.dart` (tagged, not part of the default run)
- Modify: `test/goldens/shell_goldens_test.dart` (form golden), `DESIGN.md`, `PRODUCT.md`, `README.md`, `.impeccable/design.json` (regenerated), `dart_test.yaml` (create if absent)
- Test: `test/shared/shell/shell_semantics_test.dart` (new)

- [ ] **Step 1: Semantics test**

Create `test/shared/shell/shell_semantics_test.dart` using the golden test's synthetic setup (copy its database seeding into a local `pumpShell(tester, size)` helper):

```dart
  for (final size in const [Size(1280, 800), Size(960, 760)]) {
    testWidgets('every region and key keeps its label at $size', (
      tester,
    ) async {
      await pumpShell(tester, size);
      for (final label in [
        'Menu bar',
        'Toolbar',
        'Address',
        'Desk workspace',
        'Status line',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      if (size.width >= 1024) {
        expect(find.bySemanticsLabel('Task pane'), findsOneWidget);
      } else {
        expect(find.text('Tasks'), findsOneWidget);
      }
      for (final key in ['Back, unavailable', 'Forward, unavailable', 'Go']) {
        expect(find.bySemanticsLabel(key), findsOneWidget, reason: key);
      }
    });
  }
```

- [ ] **Step 2: Form golden and real-font check**

In `shell_goldens_test.dart` add a case that opens the manual-shift form (`initialLocation: '/work?employment=<id>&mode=edit'`) and saves `form_1280x800`.

Create `test/goldens/real_font_check_test.dart` (`@Tags(['real-font'])` at the top) that loads `assets/fonts/noto_sans/*.ttf` with `FontLoader('NotoSans')` before pumping the same four screens (Work register, pay period open, form, Today) at 1280 × 800 and writes them with `matchesGoldenFile('real_font/<name>.png')`. Add to `dart_test.yaml`:

```yaml
tags:
  real-font:
    skip: "Run with: flutter test --run-skipped -t real-font --update-goldens test/goldens/real_font_check_test.dart"
```

Run: `$F/flutter test --run-skipped -t real-font --update-goldens test/goldens/real_font_check_test.dart`
Then open the four PNGs under `test/goldens/real_font/` and check against spec §4–§5: orb keys, Address bar, blue task pane with rounded groups, bevelled list headers with the amber sorted edge, blue selected row, property-sheet tabs with amber top edge, group boxes with blue legends, push buttons with the default ring, sunken status panels. Fix anything that differs before continuing. Commit the PNGs (synthetic data only).

- [ ] **Step 3: Docs**

Rewrite `DESIGN.md` from the shipped code and spec: frontmatter `colors` from `LifeOSTokens.millennium` and `MillenniumColors`, `typography` from `lifeOSTypography`, `rounded` (keys 3 px, task groups 5 px top, tabs 3 px top, panes 0), components (push button, toolbar key, orb, combo, group box, property-sheet tabs, task pane, details list, caption bar, status panel); body sections: Overview with north star **"The 2001 Office PC"**, the shipped shell at 1280 × 800 (menu 24, toolbar 38, Address 26, task pane 200, property sheet 300, status 22), Colors, Typography, Layout and width behaviour, Elevation (bevels and gradients only, no drop shadows), Components, Do's and Don'ts (keep: words-first, every figure explains itself in Working, focus distinct from selection, no vendor names/logos/icons/wallpapers/sounds, tokens and named colours only). Remove every Office Machine and Appearances section.

In `PRODUCT.md` replace the "approved shell direction" bullet with: "The approved shell is recorded in docs/superpowers/specs/2026-10-02-lifeos-millennium-shell-design.md: a 2001 office-PC file explorer with a task pane, Address bar, details lists, property sheets with a Working group box, and per-record history." In `README.md` replace any Office Machine / appearance wording the same way.

Regenerate the sidecar: run the `/impeccable document` flow (or the `impeccable-documenter` agent) so `.impeccable/design.json` matches the new `DESIGN.md`.

- [ ] **Step 4: Full verification**

```bash
$F/flutter analyze lib test tool
$F/dart format --output=none --set-exit-if-changed lib test tool
$F/dart run tool/schema_check.dart
$F/flutter test
printf '2\n4\n' | ./app.sh
```

Expected: no issues; format clean; schema check passes; `All tests passed!`; `app.sh` option 2 runs the tests and exits. Start the app once with `printf '1\n' | timeout 60 ./app.sh` (or `$F/flutter run -d linux`) and confirm the window opens in the new style; close it.

- [ ] **Step 5: Commit**

```bash
git add -A DESIGN.md PRODUCT.md README.md .impeccable dart_test.yaml test lib
git commit -m "docs: record the Millennium shell; add semantics and real-font checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
