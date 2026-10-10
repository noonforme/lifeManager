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
4. Generate and look at its goldens, for this demo only (its golden name is
   its id with `/` as `_`, for example `controls_key_button`):
   `flutter test --update-goldens --plain-name <golden name> test/ui/gallery/gallery_goldens_test.dart`
   and `flutter test --run-skipped -t real-font --update-goldens --plain-name real_font/<golden name> test/ui/gallery/gallery_real_font_test.dart`.
   Never update the whole gallery suite: that would accept every other
   demo's regressions too.
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
