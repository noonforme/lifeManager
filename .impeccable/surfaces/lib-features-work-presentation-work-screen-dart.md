---
version: 1
slug: "lib-features-work-presentation-work-screen-dart"
primary_target: "lib/features/work/presentation/work_screen.dart"
related_targets: ["lib/shared/shell/shell_frame.dart","lib/shared/shell/shell_dialog.dart","lib/features/work/presentation/work_tasks.dart","lib/shared/workbench/millennium_style.dart","lib/app/app_router.dart"]
---

## Scope

Mode: Operate. The LifeOS desktop shell and Work, its first surface. Later areas (Finance, Tracking, Knowledge) live inside the same shell. One style only: Millennium, the 2001 office PC (DESIGN.md); no appearance setting, no dark mode.

## Direction contract

THESIS: LifeOS is a 2001 office program for one person's records, arranged the way that era's file browser was: select a record to see it in the task pane, open it to see its Properties; every figure sits in a details list and can show its working. It refuses the docked inspector, the dashboard of KPI cards and the scaled-up tablet app.

OWN-WORLD: The XP-authentic Millennium shell in DESIGN.md: face-coloured chrome, white lists, Head-blue captions and selection, the blue task pane, EraSans (Wine's Tahoma-metric font) at 11 px, painted icons and orbs, era scrollbars, bevels only. The system window frame stays.

STORY: The owner opens Today, selects a row and reads its summary in Details, clicks a derived figure to read its Working, opens the record's Properties (Enter, double-click or the task link) to check facts and History, and records a shift or entry from the toolbar or task pane in a dialog box; the status bar confirms the save.

FIRST VIEWPORT: At 1280 × 800: menu bar; toolbar bands (Back, Forward · Add · from last time); the Address path combo; the 200 px task pane (selection's tasks, Books, Details) beside the details list with its filter row; the status bar. No right-hand column.

FORM: File-explorer shell. Signature interaction: the task pane follows the selection, and a derived figure's Working appears in Details with operand links that open their source; Back returns.

FINISH: unreviewed is unfinished: goldens and the real-font renders under test/goldens/real_font/ are looked at before merge, and DESIGN.md describes what shipped.

## Unresolved

- Free-form tile resizing is deferred; desks use fixed layouts.
- Finance, Tracking and Knowledge sheets are specified in later phases.
