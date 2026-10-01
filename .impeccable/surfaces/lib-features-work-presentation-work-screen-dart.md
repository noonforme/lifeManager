---
version: 1
slug: "lib-features-work-presentation-work-screen-dart"
primary_target: "lib/features/work/presentation/work_screen.dart"
related_targets: ["lib/shared/shell/shell_frame.dart","lib/shared/workbench/lifeos_tokens.dart","lib/shared/workbench/lifeos_skin.dart","lib/app/app_router.dart","lib/features/work/presentation/work_inspector.dart"]
---

## Scope

Mode: Operate. The LifeOS desktop shell and Work, its first surface. Later areas (Finance, Tracking, Knowledge) live inside the same shell. Two optional appearances, Millennium (2001 desktop) and One-bit (1984 black and white), reskin the same shell without changing structure or behaviour (spec 4.7); Office Machine stays the default.

## Direction contract

THESIS: LifeOS is a calculating machine for one person's records: every figure sits in a register and can show its working in the formula bar; it refuses the dashboard of detached KPI cards and the scaled-up tablet app.

OWN-WORLD: Office Machine. Grey casing (#cfd1cc) around paper-white registers, black keys for headers and the status line, one signal orange (#e8590c, #c2410c for filled actions) for the thing to press and anything running, and one coloured keycap per area (Work blue, Finance yellow, Tracking green, Knowledge violet). Archivo for words, Azeret Mono for figures. Buttons have a 2px pressable bottom edge; no shadows, gradients or glow. A night palette in charcoal with glowing orange, and a high-contrast variant.

STORY: The owner opens Today, sees what needs them, records a shift or entry from the toolbar with values prefilled from last time, selects any number to read how it was worked out, checks a record's history, and arranges sheets into desks for weekly review and month close.

FIRST VIEWPORT: At 1280×800: menu bar, toolbar (‹ › · + Add · from-last-time templates), formula bar; a 228px book tree with live values on the left; desk tabs (Today, Weekly review, Month close) over the Today desk — Journal of today and yesterday as the main tile, Needs you and the period tiles at the side; a 252px inspector with Record and History tabs on the right; a black status line with the running shift. Primary action: orange + Add in the toolbar.

FORM: Formula-bar Ledger (direction round seed 60e3d2a0, chosen by the owner from the pick card) rendered in the Office Machine colour world; layout merges the three dealt structures of surface round ca5bdafb (desks, book tree, daybook). Code-led. Signature interaction: selecting a derived cell shows its calculation with clickable operands that navigate to their source, and Back returns.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Unresolved

- Free-form tile resizing is deferred; Phase 1 desks use three fixed layouts.
- Finance, Tracking and Knowledge sheets are specified in later phases.
